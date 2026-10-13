-- M2 fulfilment: what shops, buyers and admins do with a sub-order after checkout, and
-- the timed jobs (unpaid orders expire, handed-over orders complete, requests expire).

-- The sub-order, checking the caller works at its shop. Returns the shop id.
create function public.require_sub_order_shop(p_sub_order_id uuid)
returns uuid
language plpgsql
stable
set search_path = ''
as $$
declare
  v_shop uuid;
begin
  select s.shop_id into v_shop from public.sub_orders s where s.id = p_sub_order_id;
  if v_shop is null then raise exception 'SUBORDER_NOT_FOUND' using errcode = 'P0002'; end if;
  perform public.require_shop(v_shop);
  return v_shop;
end
$$;

-- One sub-order as the shop sees it: items, buyer's name and phone (to call), payment,
-- and the delivery address when delivering.
create function public.shop_sub_order_json(p_sub_order_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select to_jsonb(s)
    || jsonb_build_object(
         'ref', o.ref, 'payment_method', o.payment_method, 'placed_at', o.created_at,
         'buyer', jsonb_build_object('name', pr.display_name, 'phone', pr.phone),
         'address', case when s.fulfilment = 'DELIVERY' then o.address_snapshot end,
         'payment_status', coalesce(
            (select p.status from public.payments p where p.sub_order_id = s.id),
            (select p.status from public.payments p where p.order_id = o.id and p.method = 'BANKAK' and p.purpose = 'ORDER')),
         'items', coalesce((select jsonb_agg(to_jsonb(i) order by i.title_ar)
                            from public.order_items i where i.sub_order_id = s.id), '[]'),
         'events', coalesce((select jsonb_agg(jsonb_build_object('from', e.from_status, 'to', e.to_status,
                                                                 'actor', e.actor_kind, 'at', e.at) order by e.at, e.id)
                             from public.suborder_events e where e.sub_order_id = s.id), '[]'),
         'return', (select to_jsonb(r) from public.returns r where r.sub_order_id = s.id))
  from public.sub_orders s
  join public.orders o on o.id = s.order_id
  join public.profiles pr on pr.id = o.buyer_id
  where s.id = p_sub_order_id;
$$;

-- The shop's orders, newest first; filter by status (e.g. the "to do" tab).
create function public.shop_orders(
  p_shop_id  uuid,
  p_statuses public.suborder_status[] default null,
  p_limit    integer default 50,
  p_offset   integer default 0
)
returns setof jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform public.require_shop(p_shop_id);
  return query
    select public.shop_sub_order_json(s.id)
    from public.sub_orders s
    where s.shop_id = p_shop_id
      and s.status not in ('PENDING_PAYMENT', 'PAYMENT_REVIEW')   -- not the shop's business until paid
      and (p_statuses is null or s.status = any (p_statuses))
    order by s.created_at desc
    limit least(greatest(coalesce(p_limit, 50), 1), 200) offset greatest(coalesce(p_offset, 0), 0);
end
$$;

-- ------------------------------------------------------------------ shop actions
create function public.shop_ack_suborder(p_sub_order_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.require_sub_order_shop(p_sub_order_id);
  update public.sub_orders set shop_ack_at = coalesce(shop_ack_at, now())
   where id = p_sub_order_id and status in ('CONFIRMED', 'READY');
  if not found then raise exception 'INVALID_TRANSITION' using errcode = 'PT409'; end if;
  return public.shop_sub_order_json(p_sub_order_id);
end
$$;

create function public.shop_reject_suborder(p_sub_order_id uuid, p_reason text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.require_sub_order_shop(p_sub_order_id);
  if nullif(btrim(coalesce(p_reason, '')), '') is null then
    raise exception 'REASON_REQUIRED' using errcode = '22023';
  end if;
  perform public.transition_suborder(p_sub_order_id, 'REJECTED_BY_SHOP', 'SHOP', btrim(p_reason));
  return public.shop_sub_order_json(p_sub_order_id);
end
$$;

create function public.shop_mark_ready(p_sub_order_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.require_sub_order_shop(p_sub_order_id);
  update public.sub_orders set shop_ack_at = coalesce(shop_ack_at, now()) where id = p_sub_order_id;
  perform public.transition_suborder(p_sub_order_id, 'READY', 'SHOP');
  return public.shop_sub_order_json(p_sub_order_id);
end
$$;

-- The buyer collected it (pickup) or the shop's driver left with it (delivery). For a
-- cash pickup the shop has the money now.
create function public.shop_hand_over(p_sub_order_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_ful public.fulfilment_type;
begin
  perform public.require_sub_order_shop(p_sub_order_id);
  select s.fulfilment into v_ful from public.sub_orders s where s.id = p_sub_order_id;
  if v_ful = 'TO_TECHNICIAN' then
    raise exception 'INVALID_TRANSITION' using errcode = 'PT409', detail = 'hand-over to a technician arrives in M3';
  end if;
  perform public.transition_suborder(p_sub_order_id,
    case v_ful when 'PICKUP' then 'PICKED_UP' else 'OUT_FOR_DELIVERY' end::public.suborder_status, 'SHOP');
  return public.shop_sub_order_json(p_sub_order_id);
end
$$;

-- Delivered to the buyer; a cash delivery's money is with the shop now.
create function public.shop_mark_delivered(p_sub_order_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.require_sub_order_shop(p_sub_order_id);
  perform public.transition_suborder(p_sub_order_id, 'DELIVERED', 'SHOP');
  return public.shop_sub_order_json(p_sub_order_id);
end
$$;

-- ------------------------------------------------------------------ buyer actions
create function public.require_own_sub_order(p_sub_order_id uuid)
returns public.sub_orders
language plpgsql
stable
set search_path = ''
as $$
declare
  s public.sub_orders;
begin
  select so.* into s from public.sub_orders so join public.orders o on o.id = so.order_id
   where so.id = p_sub_order_id and o.buyer_id = public.require_user();
  if s.id is null then raise exception 'SUBORDER_NOT_FOUND' using errcode = 'P0002'; end if;
  return s;
end
$$;

-- "I got it": the sale completes now instead of after auto_complete_days.
create function public.confirm_received(p_sub_order_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  s public.sub_orders := public.require_own_sub_order(p_sub_order_id);
begin
  perform public.transition_suborder(s.id, 'COMPLETED', 'BUYER');
  return public.order_json(s.order_id);
end
$$;

-- Within return_window_days of receiving the part. An admin decides (D-085).
create function public.request_return(p_sub_order_id uuid, p_reason text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  s        public.sub_orders := public.require_own_sub_order(p_sub_order_id);
  v_since  timestamptz := coalesce(s.delivered_at, s.handed_over_at, s.completed_at);
begin
  if s.status not in ('PICKED_UP', 'DELIVERED', 'COMPLETED') then
    raise exception 'INVALID_TRANSITION' using errcode = 'PT409';
  end if;
  if v_since < now() - make_interval(days => public.setting_int('return_window_days')::integer) then
    raise exception 'RETURN_WINDOW_CLOSED' using errcode = 'PT409';
  end if;
  insert into public.returns (sub_order_id, reason) values (s.id, btrim(coalesce(p_reason, '')));
  perform public.transition_suborder(s.id, 'RETURN_REQUESTED', 'BUYER', btrim(p_reason));
  return public.order_json(s.order_id);
exception
  when unique_violation then raise exception 'RETURN_EXISTS' using errcode = 'PT409';
  when check_violation then raise exception 'REASON_REQUIRED' using errcode = '22023';
end
$$;

-- ------------------------------------------------------------------ admin actions
create function public.admin_cancel_suborder(p_sub_order_id uuid, p_reason text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_admin uuid := public.require_admin();
  v_order uuid;
  v_pay   public.payments;
begin
  if nullif(btrim(coalesce(p_reason, '')), '') is null then
    raise exception 'REASON_REQUIRED' using errcode = '22023';
  end if;
  select s.order_id into v_order from public.sub_orders s where s.id = p_sub_order_id;
  if v_order is null then raise exception 'SUBORDER_NOT_FOUND' using errcode = 'P0002'; end if;
  perform public.transition_suborder(p_sub_order_id, 'CANCELLED', 'ADMIN', btrim(p_reason));
  -- When nothing is left to pay for, the Bankak payment is closed too.
  if not exists (select 1 from public.sub_orders s where s.order_id = v_order and s.status <> 'CANCELLED') then
    select * into v_pay from public.payments p
     where p.order_id = v_order and p.method = 'BANKAK' and p.purpose = 'ORDER'
       and p.status in ('AWAITING_TRANSFER', 'RECEIPT_SUBMITTED', 'REJECTED');
    if v_pay.id is not null then
      perform public.transition_payment(v_pay.id, 'CANCELLED', 'ADMIN', btrim(p_reason));
    end if;
  end if;
  perform public.audit('CANCEL', 'sub_order', p_sub_order_id::text, jsonb_build_object('reason', p_reason));
  return public.order_json(v_order);
end
$$;

create function public.admin_complete_suborder(p_sub_order_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_admin uuid := public.require_admin();
  v_order uuid;
begin
  select s.order_id into v_order from public.sub_orders s where s.id = p_sub_order_id;
  if v_order is null then raise exception 'SUBORDER_NOT_FOUND' using errcode = 'P0002'; end if;
  perform public.transition_suborder(p_sub_order_id, 'COMPLETED', 'ADMIN');
  perform public.audit('COMPLETE', 'sub_order', p_sub_order_id::text);
  return public.order_json(v_order);
end
$$;

-- Approve: the sub-order is RETURNED and the buyer refunded in full. Decline: COMPLETED.
create function public.admin_decide_return(p_sub_order_id uuid, p_approve boolean, p_note text default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_admin uuid := public.require_admin();
  v_order uuid;
begin
  select s.order_id into v_order from public.sub_orders s where s.id = p_sub_order_id;
  if v_order is null then raise exception 'SUBORDER_NOT_FOUND' using errcode = 'P0002'; end if;
  if not p_approve and nullif(btrim(coalesce(p_note, '')), '') is null then
    raise exception 'REASON_REQUIRED' using errcode = '22023';
  end if;
  update public.returns
     set status = case when p_approve then 'APPROVED' else 'DECLINED' end,
         decided_by = v_admin, decided_at = now(), decision_note = nullif(btrim(coalesce(p_note, '')), '')
   where sub_order_id = p_sub_order_id and status = 'REQUESTED';
  if not found then raise exception 'RETURN_NOT_FOUND' using errcode = 'P0002'; end if;
  perform public.transition_suborder(p_sub_order_id,
    case when p_approve then 'RETURNED' else 'COMPLETED' end::public.suborder_status, 'ADMIN', p_note);
  perform public.audit(case when p_approve then 'APPROVE_RETURN' else 'DECLINE_RETURN' end, 'sub_order',
                       p_sub_order_id::text, jsonb_build_object('note', p_note));
  return public.order_json(v_order);
end
$$;

-- ------------------------------------------------------------------ timed jobs
-- Bankak orders not paid by pay_by: payment EXPIRED, sub-orders CANCELLED, stock released.
-- Receipts still under review are left for the admin.
create function public.expire_unpaid_orders()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_pay record;
  s     record;
  v_n   integer := 0;
begin
  for v_pay in
    select p.id, p.order_id from public.payments p join public.orders o on o.id = p.order_id
    where p.method = 'BANKAK' and p.purpose = 'ORDER' and p.status in ('AWAITING_TRANSFER', 'REJECTED')
      and o.pay_by < now()
    for update of p skip locked
  loop
    perform public.transition_payment(v_pay.id, 'EXPIRED', 'SYSTEM');
    for s in select x.id from public.sub_orders x where x.order_id = v_pay.order_id and x.status = 'PENDING_PAYMENT' loop
      perform public.transition_suborder(s.id, 'CANCELLED', 'SYSTEM', 'PAYMENT_EXPIRED');
    end loop;
    v_n := v_n + 1;
  end loop;
  return v_n;
end
$$;

-- Picked up or delivered more than auto_complete_days ago, and no return asked: completed.
create function public.auto_complete_suborders()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  s   record;
  v_n integer := 0;
begin
  for s in
    select x.id from public.sub_orders x
    where x.status in ('PICKED_UP', 'DELIVERED')
      and coalesce(x.delivered_at, x.handed_over_at)
          < now() - make_interval(days => public.setting_int('auto_complete_days')::integer)
    for update skip locked
  loop
    perform public.transition_suborder(s.id, 'COMPLETED', 'SYSTEM', 'AUTO_COMPLETED');
    v_n := v_n + 1;
  end loop;
  return v_n;
end
$$;

create function public.expire_part_requests()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_n integer;
begin
  update public.part_offers set status = 'EXPIRED' where status = 'OFFERED' and valid_until < now();
  update public.part_requests set status = 'EXPIRED' where status = 'OPEN' and expires_at < now();
  get diagnostics v_n = row_count;
  update public.part_offers o set status = 'EXPIRED'
    from public.part_requests r
   where r.id = o.request_id and r.status <> 'OPEN' and o.status = 'OFFERED';
  return v_n;
end
$$;

select cron.schedule('expire-unpaid-orders', '*/5 * * * *', $$select public.expire_unpaid_orders()$$);
select cron.schedule('auto-complete-suborders', '7 * * * *', $$select public.auto_complete_suborders()$$);
select cron.schedule('expire-part-requests', '13 * * * *', $$select public.expire_part_requests()$$);

revoke all on function
  public.require_sub_order_shop(uuid), public.shop_sub_order_json(uuid),
  public.shop_orders(uuid, public.suborder_status[], integer, integer),
  public.shop_ack_suborder(uuid), public.shop_reject_suborder(uuid, text), public.shop_mark_ready(uuid),
  public.shop_hand_over(uuid), public.shop_mark_delivered(uuid), public.require_own_sub_order(uuid),
  public.confirm_received(uuid), public.request_return(uuid, text),
  public.admin_cancel_suborder(uuid, text), public.admin_complete_suborder(uuid),
  public.admin_decide_return(uuid, boolean, text),
  public.expire_unpaid_orders(), public.auto_complete_suborders(), public.expire_part_requests()
from public, anon, authenticated;

grant execute on function
  public.shop_orders(uuid, public.suborder_status[], integer, integer),
  public.shop_ack_suborder(uuid), public.shop_reject_suborder(uuid, text), public.shop_mark_ready(uuid),
  public.shop_hand_over(uuid), public.shop_mark_delivered(uuid),
  public.confirm_received(uuid), public.request_return(uuid, text),
  public.admin_cancel_suborder(uuid, text), public.admin_complete_suborder(uuid),
  public.admin_decide_return(uuid, boolean, text)
to authenticated;
