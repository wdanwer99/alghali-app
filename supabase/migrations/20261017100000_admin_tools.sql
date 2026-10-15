-- M6: what the admin console still needed (D-129–D-132).
--   * admin_report: sales, commission, fittings, payments and growth for a period.
--   * admin_ledger_adjustment: a manual correction of a shop's or technician's balance,
--     posted as an ADJUSTMENT journal against a new ADJUSTMENTS account and audited.
--   * Alert wording edits are audited (notification_templates).
--   * Complaints: the other parties hear when one is opened about them (DISPUTE_FILED), and
--     everyone hears the decision in the app they use (the buyer app or the partner app).

-- ------------------------------------------------------------------ reports
-- A period of Khartoum days, both ends included (at most a year). A sale counts as in
-- shop_insights (D-120): a sub-order the shop can see that wasn't cancelled, refused or
-- returned, on the day its order was placed. Fittings count by the day they were booked;
-- their fees count once completed.
create function public.admin_report(p_from date, p_to date)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_since timestamptz;
  v_until timestamptz;
begin
  perform public.require_admin();
  if p_from is null or p_to is null or p_from > p_to or p_to - p_from > 366 then
    raise exception 'INVALID_VALUE' using errcode = '22023';
  end if;
  v_since := p_from::timestamp at time zone 'Africa/Khartoum';
  v_until := (p_to + 1)::timestamp at time zone 'Africa/Khartoum';

  return (
    with subs as (
      select so.order_id, so.shop_id, so.items_sdg, so.commission_sdg, so.delivery_fee_sdg,
             o.buyer_id, o.payment_method, (o.created_at at time zone 'Africa/Khartoum')::date as day
      from public.sub_orders so
      join public.orders o on o.id = so.order_id
      where o.created_at >= v_since and o.created_at < v_until
        and so.status not in ('PENDING_PAYMENT', 'PAYMENT_REVIEW', 'CANCELLED', 'REJECTED_BY_SHOP', 'RETURNED')
    ),
    fits as (
      select b.status, b.booking_fee_sdg, b.labour_sdg, b.travel_fee_sdg,
             (b.created_at at time zone 'Africa/Khartoum')::date as day,
             b.status not in ('HELD', 'AWAITING_PAYMENT', 'EXPIRED') as booked
      from public.bookings b
      where b.created_at >= v_since and b.created_at < v_until
    ),
    days as (select g::date as day from generate_series(p_from, p_to, interval '1 day') g)
    select jsonb_build_object(
      'from', p_from,
      'to', p_to,
      'days', (
        select jsonb_agg(jsonb_build_object(
                 'day', d.day,
                 'orders', (select count(distinct s.order_id) from subs s where s.day = d.day),
                 'sales_sdg', coalesce((select sum(s.items_sdg) from subs s where s.day = d.day), 0),
                 'commission_sdg', coalesce((select sum(s.commission_sdg) from subs s where s.day = d.day), 0),
                 'fittings', (select count(*) from fits f where f.day = d.day and f.booked))
               order by d.day)
        from days d),
      'totals', jsonb_build_object(
        'orders', (select count(distinct order_id) from subs),
        'cash_orders', (select count(distinct order_id) from subs where payment_method = 'CASH'),
        'buyers', (select count(distinct buyer_id) from subs),
        'shops_selling', (select count(distinct shop_id) from subs),
        'sales_sdg', coalesce((select sum(items_sdg) from subs), 0),
        'commission_sdg', coalesce((select sum(commission_sdg) from subs), 0),
        'delivery_sdg', coalesce((select sum(delivery_fee_sdg) from subs), 0),
        'fittings_booked', (select count(*) from fits where booked),
        'fittings_done', (select count(*) from fits where status = 'COMPLETED'),
        'booking_fees_sdg', coalesce((select sum(booking_fee_sdg) from fits where status = 'COMPLETED'), 0),
        'labour_sdg', coalesce((select sum(labour_sdg) from fits where status = 'COMPLETED'), 0),
        'travel_sdg', coalesce((select sum(travel_fee_sdg) from fits where status = 'COMPLETED'), 0),
        'refunds_paid_sdg', coalesce((select sum(r.amount_sdg) from public.refunds r
                                      where r.paid_at >= v_since and r.paid_at < v_until), 0),
        'receipts_confirmed', (select count(*) from public.payments p
                               where p.method = 'BANKAK' and p.status = 'CONFIRMED'
                                 and p.reviewed_at >= v_since and p.reviewed_at < v_until),
        'receipts_rejected', (select count(*) from public.payments p
                              where p.method = 'BANKAK' and p.reject_reason is not null
                                and p.reviewed_at >= v_since and p.reviewed_at < v_until),
        'review_minutes', (select round(avg(extract(epoch from p.reviewed_at - p.submitted_at) / 60))::int
                           from public.payments p
                           where p.method = 'BANKAK' and p.status = 'CONFIRMED' and p.submitted_at is not null
                             and p.reviewed_at >= v_since and p.reviewed_at < v_until),
        'new_accounts', (select count(*) from public.profiles p where p.created_at >= v_since and p.created_at < v_until),
        'new_shops', (select count(*) from public.shops s where s.approved_at >= v_since and s.approved_at < v_until),
        'new_technicians', (select count(*) from public.technicians t
                            where t.approved_at >= v_since and t.approved_at < v_until)),
      'top_shops', coalesce((
        select jsonb_agg(t order by t.sales_sdg desc)
        from (
          select sh.id as shop_id, sh.name_ar, sh.name_en, count(distinct s.order_id)::int as orders,
                 sum(s.items_sdg) as sales_sdg, sum(s.commission_sdg) as commission_sdg,
                 sh.rating_avg, sh.rating_count
          from subs s join public.shops sh on sh.id = s.shop_id
          group by sh.id
          order by sum(s.items_sdg) desc
          limit 10) t), '[]'),
      'fittings', coalesce((
        select jsonb_object_agg(x.status, x.n)
        from (select f.status, count(*)::int as n from fits f group by f.status) x), '{}')));
end
$$;

-- ------------------------------------------------------------------ balance corrections
insert into public.ledger_accounts (code, kind) values ('ADJUSTMENTS', 'REVENUE') on conflict (code) do nothing;

-- A positive amount: the platform owes the partner more; negative: the partner owes more.
-- Goes into the next payout like any other line. Returns the partner's new balance.
create function public.admin_ledger_adjustment(
  p_amount_sdg    bigint,
  p_reason        text,
  p_shop_id       uuid default null,
  p_technician_id uuid default null
)
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_reason text := nullif(btrim(coalesce(p_reason, '')), '');
  v_party  uuid;
  v_adj    uuid;
begin
  perform public.require_admin();
  if num_nonnulls(p_shop_id, p_technician_id) <> 1 or p_amount_sdg is null or p_amount_sdg = 0
     or abs(p_amount_sdg) > 100000000 then
    raise exception 'INVALID_VALUE' using errcode = '22023';
  end if;
  if v_reason is null then raise exception 'REASON_REQUIRED' using errcode = '22023'; end if;
  if char_length(v_reason) > 500 then raise exception 'INVALID_VALUE' using errcode = '22023'; end if;
  if p_shop_id is not null then
    if not exists (select 1 from public.shops s where s.id = p_shop_id) then
      raise exception 'SHOP_NOT_FOUND' using errcode = 'P0002';
    end if;
    v_party := public.shop_account(p_shop_id);
  else
    if not exists (select 1 from public.technicians t where t.id = p_technician_id) then
      raise exception 'TECHNICIAN_NOT_FOUND' using errcode = 'P0002';
    end if;
    v_party := public.tech_account(p_technician_id);
  end if;
  v_adj := public.ledger_account('ADJUSTMENTS');
  if p_amount_sdg > 0 then
    perform public.post_journal('ADJUSTMENT', v_adj, v_party, p_amount_sdg, p_memo => v_reason);
  else
    perform public.post_journal('ADJUSTMENT', v_party, v_adj, -p_amount_sdg, p_memo => v_reason);
  end if;
  perform public.audit('ADJUST_BALANCE', case when p_shop_id is not null then 'shop' else 'technician' end,
                       coalesce(p_shop_id, p_technician_id)::text,
                       jsonb_build_object('amount_sdg', p_amount_sdg, 'reason', v_reason));
  return case when p_shop_id is not null then public.shop_balance(p_shop_id)
              else public.tech_balance(p_technician_id) end;
end
$$;

-- ------------------------------------------------------------------ alert wording edits
create function public.tg_audit_template()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then return null; end if;  -- migrations and seed
  insert into public.audit_log (actor_id, action, entity, entity_id, data)
  values (auth.uid(), tg_op, 'notification_template', new.code || ':' || new.locale,
          jsonb_build_object('old', case when tg_op = 'UPDATE' then jsonb_build_object('title', old.title, 'body', old.body) end,
                             'new', jsonb_build_object('title', new.title, 'body', new.body)));
  return null;
end
$$;
create trigger notification_templates_audit after insert or update on public.notification_templates
  for each row execute function public.tg_audit_template();

-- ------------------------------------------------------------------ complaints
insert into public.notification_codes (code, app, sms) values ('DISPUTE_FILED', 'partner', false);
insert into public.notification_templates (code, locale, title, body) values
  ('DISPUTE_FILED', 'ar', 'شكوى جديدة', 'فُتحت شكوى بخصوص {ref}. اطّلع عليها ورُدّ عليها.'),
  ('DISPUTE_FILED', 'en', 'New complaint', 'A complaint was opened about {ref}. See it and reply.');

-- Which app a party of a complaint reads it in: the buyer of the order or the fitting the
-- buyer app; the shop's members and the technician the partner app.
create function public.dispute_party_app(p_dispute_id uuid, p_user_id uuid)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when exists (select 1 from public.disputes d join public.sub_orders s on s.id = d.sub_order_id
                 join public.orders o on o.id = s.order_id where d.id = p_dispute_id and o.buyer_id = p_user_id)
      or exists (select 1 from public.disputes d join public.bookings b on b.id = d.booking_id
                 where d.id = p_dispute_id and b.buyer_id = p_user_id)
    then 'buyer' else 'partner' end;
$$;

create or replace function public.open_dispute(
  p_category     text,
  p_description  text,
  p_sub_order_id uuid default null,
  p_booking_id   uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid   uuid := public.require_user();
  v_role  text;
  v_id    uuid;
  v_ref   text;
  v_party uuid;
begin
  if num_nonnulls(p_sub_order_id, p_booking_id) <> 1 then raise exception 'INVALID_VALUE' using errcode = '22023'; end if;
  if p_sub_order_id is not null then
    select case when o.buyer_id = v_uid then 'BUYER' when public.is_shop_member(s.shop_id) then 'SHOP' end, o.ref
      into v_role, v_ref
    from public.sub_orders s join public.orders o on o.id = s.order_id where s.id = p_sub_order_id;
  else
    select case when b.buyer_id = v_uid then 'BUYER' when b.technician_id = public.my_technician_id() then 'TECH' end, b.ref
      into v_role, v_ref
    from public.bookings b where b.id = p_booking_id;
  end if;
  if v_role is null then raise exception 'NOT_FOUND' using errcode = 'P0002'; end if;
  insert into public.disputes (opened_by, opener_role, sub_order_id, booking_id, category, description)
  values (v_uid, v_role, p_sub_order_id, p_booking_id, p_category, btrim(p_description))
  returning id into v_id;
  perform public.notify_admins('DISPUTE_OPENED', jsonb_build_object('dispute_id', v_id, 'category', p_category));
  -- M6: the other side hears about it too, in the app they use.
  for v_party in select x from public.dispute_parties(v_id) x where x <> v_uid loop
    insert into public.notifications (user_id, code, payload, app)
    values (v_party, 'DISPUTE_FILED', jsonb_build_object('dispute_id', v_id, 'ref', v_ref),
            public.dispute_party_app(v_id, v_party));
  end loop;
  return public.dispute_json(v_id);
exception
  when unique_violation then raise exception 'DISPUTE_EXISTS' using errcode = 'PT409';
  when check_violation then raise exception 'INVALID_DISPUTE' using errcode = '22023', detail = sqlerrm;
end
$$;

create or replace function public.admin_update_dispute(p_dispute_id uuid, p_status text, p_resolution text default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_admin uuid := public.require_admin();
  d       public.disputes;
  v_party uuid;
begin
  select * into d from public.disputes where id = p_dispute_id for update;
  if d.id is null then raise exception 'NOT_FOUND' using errcode = 'P0002'; end if;
  if p_status not in ('IN_REVIEW', 'RESOLVED', 'REJECTED') or d.status in ('RESOLVED', 'REJECTED') then
    raise exception 'INVALID_TRANSITION' using errcode = 'PT409';
  end if;
  if p_status in ('RESOLVED', 'REJECTED') and nullif(btrim(coalesce(p_resolution, '')), '') is null then
    raise exception 'REASON_REQUIRED' using errcode = '22023';
  end if;
  update public.disputes
     set status = p_status, assigned_to = coalesce(assigned_to, v_admin),
         resolution = case when p_status in ('RESOLVED', 'REJECTED') then btrim(p_resolution) end,
         resolved_at = case when p_status in ('RESOLVED', 'REJECTED') then now() end
   where id = d.id;
  if p_status in ('RESOLVED', 'REJECTED') then
    for v_party in select x from public.dispute_parties(d.id) x loop
      -- M6: each party in the app they use (shops and technicians: the partner app).
      insert into public.notifications (user_id, code, payload, app)
      values (v_party, 'DISPUTE_RESOLVED', jsonb_build_object('dispute_id', d.id, 'resolution', btrim(p_resolution)),
              public.dispute_party_app(d.id, v_party));
    end loop;
  end if;
  perform public.audit(p_status, 'dispute', d.id::text, jsonb_build_object('resolution', p_resolution));
  return public.dispute_json(d.id);
end
$$;

revoke all on function
  public.admin_report(date, date), public.admin_ledger_adjustment(bigint, text, uuid, uuid),
  public.tg_audit_template(), public.dispute_party_app(uuid, uuid)
  from public, anon, authenticated;
grant execute on function public.admin_report(date, date), public.admin_ledger_adjustment(bigint, text, uuid, uuid)
  to authenticated;
