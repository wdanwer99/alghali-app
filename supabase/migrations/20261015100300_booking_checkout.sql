-- M3 bookings meet M2 commerce: a held booking is paid through an order at checkout
-- (D-097), with the parts bought for it sent to the technician (TO_TECHNICIAN), payments
-- moving the booking along, and the money settled when the booking ends (D-098, D-099).
--
-- Money for one booking (L = labour, T = travel fee, F = booking fee; D-013):
--   completed ............... LABOUR + TRAVEL_FEE  Dr BUYER_FUNDS_HELD / Cr TECH          L + T
--                             BOOKING_FEE         Dr BUYER_FUNDS_HELD / Cr REVENUE_BOOKING_FEE  F
--   cash taken at the job ... CASH_COLLECTED      Dr TECH / Cr BUYER_FUNDS_HELD
--   part money to the shop .. CASH_HANDOVER       Dr SHOP / Cr TECH  (cash orders, at hand-over)
--   part does not fit ....... TRAVEL_FEE only (D-019)
--   late buyer cancellation . BOOKING_FEE then TRAVEL_FEE, up to what was paid upfront (D-099)
--   anything not earned ..... REFUND (Bankak) back to the buyer
-- As with orders, BUYER_FUNDS_HELD ends at zero for every booking.

-- ------------------------------------------------------------------ schema additions
create unique index bookings_one_per_order on public.bookings (order_id) where order_id is not null;
alter table public.refunds add column booking_id uuid references public.bookings (id);
create unique index refunds_booking_once on public.refunds (booking_id) where booking_id is not null;

-- Cash a technician collects at the job is recorded by the system on completion.
insert into public.payment_transitions (from_status, to_status, actor) values ('DUE', 'COLLECTED', 'SYSTEM');

-- Parts bought for a fitting follow the booking (D-098).
insert into public.suborder_transitions (from_status, to_status, actor) values
  ('CONFIRMED',            'CANCELLED',        'SYSTEM'),
  ('READY',                'CANCELLED',        'SYSTEM'),
  ('HANDED_TO_TECHNICIAN', 'CANCELLED',        'SYSTEM'),
  ('HANDED_TO_TECHNICIAN', 'RETURN_REQUESTED', 'SYSTEM');   -- the part did not fit

-- The parts for a fitting were cancelled or declined by the shop.
insert into public.booking_transitions (from_status, to_status, actor) values
  ('AWAITING_PAYMENT',    'CANCELLED_BY_ADMIN', 'SYSTEM'),
  ('PENDING_TECH_ACCEPT', 'CANCELLED_BY_ADMIN', 'SYSTEM'),
  ('ACCEPTED',            'CANCELLED_BY_ADMIN', 'SYSTEM'),
  ('NEEDS_RESCHEDULE',    'CANCELLED_BY_ADMIN', 'SYSTEM');

-- ------------------------------------------------------------------ money helpers
create function public.post_booking_journal(
  p_kind       text,
  p_debit      uuid,
  p_credit     uuid,
  p_amount     bigint,
  p_booking_id uuid,
  p_payment_id uuid default null,
  p_refund_id  uuid default null
)
returns uuid
language plpgsql
set search_path = ''
as $$
declare
  v_id uuid;
begin
  if coalesce(p_amount, 0) = 0 then return null; end if;
  if p_amount < 0 then raise exception 'NEGATIVE_AMOUNT' using errcode = '22023'; end if;
  insert into public.ledger_journals (kind, order_id, booking_id, payment_id, refund_id, created_by)
  values (p_kind, (select b.order_id from public.bookings b where b.id = p_booking_id), p_booking_id,
          p_payment_id, p_refund_id, auth.uid())
  returning id into v_id;
  insert into public.ledger_entries (journal_id, account_id, amount_sdg)
  values (v_id, p_debit, p_amount), (v_id, p_credit, -p_amount);
  return v_id;
end
$$;

-- What the buyer paid upfront for the booking itself (not its parts): the booking's
-- share of a confirmed Bankak order payment, or a confirmed deposit.
create function public.booking_paid_upfront(p_booking_id uuid)
returns bigint
language sql
stable
set search_path = ''
as $$
  select coalesce((
    select case
             when o.payment_method = 'BANKAK' and exists (
                    select 1 from public.payments p where p.order_id = o.id and p.method = 'BANKAK'
                      and p.purpose = 'ORDER' and p.status = 'CONFIRMED')
               then b.labour_sdg + b.travel_fee_sdg + b.booking_fee_sdg
             else coalesce((select p.amount_sdg from public.payments p where p.booking_id = b.id
                              and p.purpose = 'BOOKING_DEPOSIT' and p.status = 'CONFIRMED'), 0)
           end
    from public.bookings b join public.orders o on o.id = b.order_id
    where b.id = p_booking_id), 0)::bigint;
$$;

-- The order's sub-orders whose parts go to the technician.
create function public.booking_sub_orders(p_booking_id uuid)
returns setof public.sub_orders
language sql
stable
set search_path = ''
as $$
  select s.* from public.sub_orders s join public.bookings b on b.order_id = s.order_id
  where b.id = p_booking_id and s.fulfilment = 'TO_TECHNICIAN';
$$;

-- Settles the booking's money once it has ended (D-098, D-099). Safe to call again: a
-- payment confirmed after a cancellation is refunded on the second call.
create function public.settle_booking(p_booking_id uuid)
returns void
language plpgsql
set search_path = ''
as $$
declare
  b         public.bookings;
  o         public.orders;
  v_tech    uuid;
  v_paid    bigint := public.booking_paid_upfront(p_booking_id);
  v_charge  bigint := 0;
  v_fee     bigint := 0;
  v_travel  bigint := 0;
  v_labour  bigint := 0;
  v_cash    public.payments;
  v_owed    bigint;
  v_parts   bigint;
  v_refund  bigint;
  v_rid     uuid;
  v_settled boolean;
begin
  select * into b from public.bookings where id = p_booking_id for update;
  if b.order_id is null then return; end if;
  select * into o from public.orders where id = b.order_id;
  v_tech := public.tech_account(b.technician_id);
  v_settled := exists (select 1 from public.ledger_journals j where j.booking_id = b.id
                       and j.kind in ('LABOUR', 'TRAVEL_FEE', 'BOOKING_FEE', 'CASH_COLLECTED'));

  case b.status
    when 'COMPLETED' then
      v_labour := b.labour_sdg; v_travel := b.travel_fee_sdg; v_fee := b.booking_fee_sdg;
    when 'PART_DOES_NOT_FIT' then
      v_travel := b.travel_fee_sdg;
    when 'CANCELLED_BY_BUYER' then
      -- Late: within cancel_cutoff_hours of the start, or once the technician set off.
      if b.cancelled_at > b.start_at - make_interval(hours => public.setting_int('cancel_cutoff_hours')::integer)
         or b.en_route_at is not null then
        v_charge := least(b.booking_fee_sdg + b.travel_fee_sdg,
                          case when o.payment_method = 'BANKAK' then v_paid else least(v_paid, b.deposit_sdg) end);
        v_fee := least(v_charge, b.booking_fee_sdg);
        v_travel := v_charge - v_fee;
      end if;
    else
      null;   -- cancelled by the technician or an admin, expired: nothing is owed
  end case;
  v_charge := v_labour + v_travel + v_fee;

  select * into v_cash from public.payments p
   where p.booking_id = b.id and p.method = 'CASH' and p.status = 'DUE' for update;

  if not v_settled then
    -- Cash the technician takes at the job: what is owed less what was paid upfront.
    if v_cash.id is not null then
      if b.status in ('COMPLETED', 'PART_DOES_NOT_FIT') then
        v_parts := case when b.status = 'COMPLETED'
                        then coalesce((select sum(s.items_sdg) from public.booking_sub_orders(b.id) s
                                       where s.status not in ('CANCELLED', 'REJECTED_BY_SHOP')), 0)
                        else 0 end;
        v_owed := v_parts + v_charge - v_paid;
      else
        v_owed := 0;
      end if;
      if v_owed > 0 then
        update public.payments set amount_sdg = v_owed, collected_by = (select t.user_id from public.technicians t
                                                                        where t.id = b.technician_id),
                                   collected_at = now()
         where id = v_cash.id;
        perform public.transition_payment(v_cash.id, 'COLLECTED', 'SYSTEM');
        perform public.post_booking_journal('CASH_COLLECTED', v_tech, public.ledger_account('BUYER_FUNDS_HELD'),
                                            v_owed, b.id, v_cash.id);
      else
        perform public.transition_payment(v_cash.id, 'CANCELLED', 'SYSTEM', b.status::text);
      end if;
    end if;
    perform public.post_booking_journal('LABOUR', public.ledger_account('BUYER_FUNDS_HELD'), v_tech, v_labour, b.id);
    perform public.post_booking_journal('TRAVEL_FEE', public.ledger_account('BUYER_FUNDS_HELD'), v_tech, v_travel, b.id);
    perform public.post_booking_journal('BOOKING_FEE', public.ledger_account('BUYER_FUNDS_HELD'),
                                        public.ledger_account('REVENUE_BOOKING_FEE'), v_fee, b.id);
  end if;

  -- Whatever was paid upfront and not earned goes back by Bankak (D-088).
  v_refund := v_paid - least(v_paid, v_charge);
  if v_refund > 0 and not exists (select 1 from public.refunds r where r.booking_id = b.id) then
    insert into public.refunds (order_id, booking_id, buyer_id, amount_sdg, reason)
    values (o.id, b.id, b.buyer_id, v_refund, b.status::text)
    returning id into v_rid;
    perform public.post_booking_journal('REFUND', public.ledger_account('BUYER_FUNDS_HELD'),
                                        public.ledger_account('REFUNDS_PAYABLE'), v_refund, b.id, null, v_rid);
    perform public.notify(b.buyer_id, 'REFUND_CREATED',
                          jsonb_build_object('order_id', o.id, 'ref', o.ref, 'booking_id', b.id, 'amount_sdg', v_refund));
  end if;
end
$$;

-- The parts bought for a fitting follow its booking (D-098): the shop learns who collects
-- them; they complete with the job, go back as a return if they don't fit, and are
-- cancelled (refunded, back in stock) if the fitting is cancelled.
create function public.booking_parts_follow(p_booking_id uuid, p_to public.booking_status)
returns void
language plpgsql
set search_path = ''
as $$
declare
  b   public.bookings;
  s   public.sub_orders;
  v_t jsonb;
begin
  select * into b from public.bookings where id = p_booking_id;
  select jsonb_build_object('booking_id', b.id, 'booking_ref', b.ref, 'start_at', b.start_at,
                            'technician', p.display_name, 'phone', p.phone)
    into v_t
  from public.technicians t join public.profiles p on p.id = t.user_id where t.id = b.technician_id;

  for s in select * from public.booking_sub_orders(p_booking_id) loop
    case
      when p_to = 'ACCEPTED' then
        perform public.notify_shop(s.shop_id, 'TECH_WILL_COLLECT',
                                   v_t || jsonb_build_object('order_id', s.order_id, 'sub_order_id', s.id));
      when p_to = 'COMPLETED' and s.status = 'HANDED_TO_TECHNICIAN' then
        perform public.transition_suborder(s.id, 'COMPLETED', 'SYSTEM', 'FITTED');
      when p_to = 'PART_DOES_NOT_FIT' and s.status = 'HANDED_TO_TECHNICIAN' then
        insert into public.returns (sub_order_id, reason)
        values (s.id, 'PART_DOES_NOT_FIT' || coalesce(': ' || b.cancel_reason, ''))
        on conflict (sub_order_id) do nothing;
        perform public.transition_suborder(s.id, 'RETURN_REQUESTED', 'SYSTEM', 'PART_DOES_NOT_FIT');
      when p_to in ('EXPIRED', 'CANCELLED_BY_BUYER', 'CANCELLED_BY_TECH', 'CANCELLED_BY_ADMIN')
           and s.status in ('PENDING_PAYMENT', 'CONFIRMED', 'READY', 'HANDED_TO_TECHNICIAN') then
        perform public.transition_suborder(s.id, 'CANCELLED', 'SYSTEM', 'BOOKING_' || p_to::text);
      else
        null;
    end case;
  end loop;
end
$$;

-- ------------------------------------------------------------------ sub-orders
-- transition_suborder() from M2, now also for parts handed to a technician:
-- the shop got the part money from the technician on cash orders (CASH_HANDOVER), a
-- cancelled hand-over puts the part back in stock and the money back with the
-- technician, and a sub-order cancelled under a live booking cancels that booking.
create or replace function public.transition_suborder(p_id uuid, p_to public.suborder_status, p_actor text, p_reason text default null)
returns public.suborder_status
language plpgsql
set search_path = ''
as $$
declare
  v_from public.suborder_status;
  s      public.sub_orders;
  o      public.orders;
  bk     public.bookings;
  v_info jsonb;
begin
  select so.status into v_from from public.sub_orders so where so.id = p_id for update;
  if not found then raise exception 'SUBORDER_NOT_FOUND' using errcode = 'P0002'; end if;

  perform set_config('app.actor', p_actor, true);
  update public.sub_orders set status = p_to where id = p_id;
  perform set_config('app.actor', '', true);
  insert into public.suborder_events (sub_order_id, from_status, to_status, actor_kind, actor_id, reason)
  values (p_id, v_from, p_to, p_actor, auth.uid(), p_reason);

  select * into s from public.sub_orders where id = p_id;
  select * into o from public.orders where id = s.order_id;
  if s.fulfilment = 'TO_TECHNICIAN' then
    select * into bk from public.bookings b where b.order_id = o.id;
  end if;
  v_info := jsonb_build_object('order_id', o.id, 'sub_order_id', s.id, 'ref', o.ref, 'status', p_to);

  case p_to
    when 'CANCELLED', 'REJECTED_BY_SHOP' then
      if v_from in ('OUT_FOR_DELIVERY', 'HANDED_TO_TECHNICIAN') then
        perform public.restock(s.id);
      else
        perform public.release_reservation(s.id);
      end if;
      if v_from = 'HANDED_TO_TECHNICIAN' and o.payment_method = 'CASH' then
        perform public.post_booking_journal('CASH_HANDOVER', public.tech_account(bk.technician_id),
                                            public.shop_account(s.shop_id), s.items_sdg, bk.id);
      end if;
      update public.sub_orders set cancelled_at = now(), cancel_reason = nullif(btrim(coalesce(p_reason, '')), '')
       where id = s.id;
      perform public.refund_sub_order(s.id, coalesce(p_reason, p_to::text));
      perform public.notify(o.buyer_id, case p_to when 'CANCELLED' then 'ORDER_CANCELLED' else 'ORDER_REJECTED_BY_SHOP' end,
                            v_info || jsonb_build_object('reason', p_reason));
      if p_actor <> 'SHOP' and v_from not in ('PENDING_PAYMENT', 'PAYMENT_REVIEW') then
        perform public.notify_shop(s.shop_id, 'ORDER_CANCELLED', v_info);
      end if;
      -- The parts for a fitting are gone: so is the fitting (unless it ended already).
      if bk.id is not null and bk.status in ('AWAITING_PAYMENT', 'PENDING_TECH_ACCEPT', 'ACCEPTED', 'NEEDS_RESCHEDULE')
         and not exists (select 1 from public.booking_sub_orders(bk.id) x where x.status not in ('CANCELLED', 'REJECTED_BY_SHOP')) then
        perform public.transition_booking(bk.id, 'CANCELLED_BY_ADMIN', 'SYSTEM', 'PARTS_CANCELLED');
      end if;
    when 'CONFIRMED' then
      perform public.notify_shop(s.shop_id, 'NEW_ORDER', v_info);
    when 'READY' then
      update public.sub_orders set ready_at = now() where id = s.id;
      perform public.notify(o.buyer_id, 'ORDER_READY', v_info);
      if bk.id is not null and bk.status = 'ACCEPTED' then
        perform public.notify_partner((select t.user_id from public.technicians t where t.id = bk.technician_id), 'PARTS_READY',
                              v_info || jsonb_build_object('booking_id', bk.id, 'shop_id', s.shop_id));
      end if;
    when 'PICKED_UP', 'OUT_FOR_DELIVERY', 'HANDED_TO_TECHNICIAN' then
      perform public.take_stock(s.id);
      update public.sub_orders set handed_over_at = now() where id = s.id;
      if p_to = 'PICKED_UP' then perform public.collect_cash(s.id); end if;
      if p_to = 'HANDED_TO_TECHNICIAN' and o.payment_method = 'CASH' then
        -- The technician paid the shop for the part (D-011); they collect it from the buyer at the job.
        perform public.post_booking_journal('CASH_HANDOVER', public.shop_account(s.shop_id),
                                            public.tech_account(bk.technician_id), s.items_sdg, bk.id);
      end if;
      perform public.notify(o.buyer_id, 'ORDER_HANDED_OVER', v_info);
    when 'DELIVERED' then
      update public.sub_orders set delivered_at = now() where id = s.id;
      perform public.collect_cash(s.id);
      perform public.notify(o.buyer_id, 'ORDER_DELIVERED', v_info);
    when 'COMPLETED' then
      update public.sub_orders set completed_at = coalesce(completed_at, now()) where id = s.id;
      perform public.post_sale(s.id);
      if v_from = 'RETURN_REQUESTED' then
        perform public.notify(o.buyer_id, 'RETURN_DECLINED', v_info || jsonb_build_object('reason', p_reason));
      end if;
    when 'RETURN_REQUESTED' then
      perform public.notify_shop(s.shop_id, 'RETURN_REQUESTED', v_info || jsonb_build_object('reason', p_reason));
    when 'RETURNED' then
      perform public.reverse_sale(s.id);
      perform public.refund_sub_order(s.id, coalesce(p_reason, 'RETURNED'));
      -- A part that never fitted goes back to the shop, which gives the technician their money back.
      if s.fulfilment = 'TO_TECHNICIAN' and o.payment_method = 'CASH' and s.completed_at is null then
        perform public.post_booking_journal('CASH_HANDOVER', public.tech_account(bk.technician_id),
                                            public.shop_account(s.shop_id), s.items_sdg, bk.id);
      end if;
      perform public.notify(o.buyer_id, 'RETURN_APPROVED', v_info);
      perform public.notify_shop(s.shop_id, 'RETURN_APPROVED', v_info);
    else
      null;  -- PAYMENT_REVIEW, PENDING_PAYMENT: the payment RPCs notify
  end case;
  return v_from;
end
$$;

-- The shop hands the parts to the technician once the job is accepted (D-011).
create or replace function public.shop_hand_over(p_sub_order_id uuid)
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
  if v_ful = 'TO_TECHNICIAN' and not exists (
       select 1 from public.sub_orders s join public.bookings b on b.order_id = s.order_id
       where s.id = p_sub_order_id and b.status = 'ACCEPTED') then
    raise exception 'TECHNICIAN_NOT_ASSIGNED' using errcode = 'PT409';
  end if;
  perform public.transition_suborder(p_sub_order_id,
    case v_ful when 'PICKUP' then 'PICKED_UP' when 'DELIVERY' then 'OUT_FOR_DELIVERY'
               else 'HANDED_TO_TECHNICIAN' end::public.suborder_status, 'SHOP');
  return public.shop_sub_order_json(p_sub_order_id);
end
$$;

-- shop_sub_order_json() from M2, plus the booking for parts going to a technician: who
-- collects them, when, and (cash) that the technician pays for them at hand-over.
create or replace function public.shop_sub_order_json(p_sub_order_id uuid)
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
            case when s.fulfilment = 'TO_TECHNICIAN' and o.payment_method = 'CASH' then
              (select case when s.handed_over_at is not null then 'COLLECTED' else 'DUE' end)::public.payment_status end,
            (select p.status from public.payments p where p.order_id = o.id and p.method = 'BANKAK'
               and p.purpose in ('ORDER', 'BOOKING_DEPOSIT') order by p.created_at limit 1)),
         'items', coalesce((select jsonb_agg(to_jsonb(i) order by i.title_ar)
                            from public.order_items i where i.sub_order_id = s.id), '[]'),
         'events', coalesce((select jsonb_agg(jsonb_build_object('from', e.from_status, 'to', e.to_status,
                                                                 'actor', e.actor_kind, 'at', e.at) order by e.at, e.id)
                             from public.suborder_events e where e.sub_order_id = s.id), '[]'),
         'return', (select to_jsonb(r) from public.returns r where r.sub_order_id = s.id),
         'booking', case when s.fulfilment = 'TO_TECHNICIAN' then (
                      select jsonb_build_object('id', b.id, 'ref', b.ref, 'status', b.status, 'start_at', b.start_at,
                                                'technician', jsonb_build_object('name', tp.display_name, 'phone', tp.phone))
                      from public.bookings b join public.technicians t on t.id = b.technician_id
                      join public.profiles tp on tp.id = t.user_id
                      where b.order_id = o.id) end)
  from public.sub_orders s
  join public.orders o on o.id = s.order_id
  join public.profiles pr on pr.id = o.buyer_id
  where s.id = p_sub_order_id;
$$;

-- order_json() from M2, plus the order's booking (as its buyer sees it).
create or replace function public.order_json(p_order_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select to_jsonb(o) - 'idem_key'
    || jsonb_build_object(
         'payments', coalesce((select jsonb_agg(to_jsonb(p) - 'receipt_key' order by p.created_at)
                               from public.payments p where p.order_id = o.id), '[]'),
         'refunds', coalesce((select jsonb_agg(jsonb_build_object('id', r.id, 'sub_order_id', r.sub_order_id,
                               'booking_id', r.booking_id, 'amount_sdg', r.amount_sdg, 'status', r.status,
                               'paid_at', r.paid_at))
                              from public.refunds r where r.order_id = o.id), '[]'),
         'sub_orders', coalesce((
           select jsonb_agg(to_jsonb(s)
             || jsonb_build_object(
                  'shop', jsonb_build_object('id', sh.id, 'name_ar', sh.name_ar, 'name_en', sh.name_en,
                                             'phone', sh.phone, 'whatsapp', sh.whatsapp, 'plot_no', sh.plot_no,
                                             'zone_id', sh.zone_id, 'pos_m', sh.pos_m),
                  'items', coalesce((select jsonb_agg(to_jsonb(i) order by i.title_ar)
                                     from public.order_items i where i.sub_order_id = s.id), '[]'),
                  'events', coalesce((select jsonb_agg(jsonb_build_object('from', e.from_status, 'to', e.to_status,
                                                                          'actor', e.actor_kind, 'at', e.at)
                                                       order by e.at, e.id)
                                      from public.suborder_events e where e.sub_order_id = s.id), '[]'),
                  'return', (select to_jsonb(r) from public.returns r where r.sub_order_id = s.id))
             order by sh.pos_m nulls last)
           from public.sub_orders s join public.shops sh on sh.id = s.shop_id
           where s.order_id = o.id), '[]'),
         'booking', (select public.booking_json(b.id) from public.bookings b where b.order_id = o.id))
  from public.orders o
  where o.id = p_order_id;
$$;

-- ------------------------------------------------------------------ checkout
-- checkout() from M2 with a held booking (D-097). p_booking_id: the buyer's HELD booking.
-- Its cart lines go to the technician (their shops' sub-orders are TO_TECHNICIAN), and
-- the order adds labour, travel and booking fees. p_items may be empty for a fitting on
-- its own (a part from an earlier order or bought elsewhere).
--   Bankak: everything is transferred; the booking waits in AWAITING_PAYMENT.
--   Cash at the buyer's location: a Bankak deposit first (mobile_deposit_sdg, D-019),
--     then the technician collects the rest at the job.
--   Cash at a bay: nothing upfront; the technician is offered the job at once.
drop function public.checkout(jsonb, public.payment_method, jsonb, uuid, uuid);
create function public.checkout(
  p_items       jsonb,
  p_method      public.payment_method,
  p_fulfilment  jsonb default '{}',
  p_address_id  uuid default null,
  p_idem        uuid default null,
  p_booking_id  uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid      uuid := public.require_user();
  v_prev     jsonb := public.idem_begin(p_idem, 'checkout');
  v_lines    jsonb := '[]';
  v_shop     uuid;
  v_ful      public.fulfilment_type;
  v_order    uuid;
  v_ref      text;
  v_sub      uuid;
  v_items    bigint;
  v_delivery bigint;
  v_total_i  bigint := 0;
  v_total_d  bigint := 0;
  v_bp       integer := round((public.setting('commission_percent') #>> '{}')::numeric * 100)::integer;
  v_addr     jsonb;
  v_status   public.suborder_status;
  bk         public.bookings;
  v_fees     bigint := 0;
  v_deposit  bigint := 0;
  v_tech_i   bigint := 0;
  v_tech     uuid[] := '{}';
  v_line     jsonb;
begin
  if v_prev is not null then return v_prev; end if;
  if p_method is null then raise exception 'INVALID_METHOD' using errcode = '22023'; end if;
  if (select p.phone from public.profiles p where p.id = v_uid) is null then
    raise exception 'PHONE_REQUIRED' using errcode = '22023';
  end if;

  if p_booking_id is not null then
    select * into bk from public.bookings b where b.id = p_booking_id and b.buyer_id = v_uid for update;
    if bk.id is null then raise exception 'BOOKING_NOT_FOUND' using errcode = 'P0002'; end if;
    if bk.status <> 'HELD' or bk.hold_expires_at < now() then
      raise exception 'HOLD_EXPIRED' using errcode = 'PT409';
    end if;
    v_fees := bk.labour_sdg + bk.travel_fee_sdg + bk.booking_fee_sdg;
    if p_method = 'CASH' and bk.place = 'CUSTOMER_LOCATION' then
      v_deposit := least(public.setting_int('mobile_deposit_sdg'), v_fees);
    end if;
  end if;

  if p_booking_id is null or jsonb_array_length(coalesce(p_items, '[]')) > 0 then
    v_lines := public.cart_check(p_items, true);
    if exists (select 1 from jsonb_array_elements(v_lines) x where not (x ->> 'ok')::boolean) then
      raise exception 'CART_CHANGED' using errcode = 'PT409', detail = v_lines::text;
    end if;
  end if;

  if bk.id is not null then
    -- Every cart line in the booking must be bought now; their shops send to the technician.
    if exists (select 1 from public.booking_items i where i.booking_id = bk.id
               and (i.listing_id is not null or i.offer_id is not null)
               and not exists (select 1 from jsonb_array_elements(v_lines) x
                               where (x ->> 'listing_id')::uuid is not distinct from i.listing_id
                                 and (x ->> 'offer_id')::uuid is not distinct from i.offer_id
                                 and (i.listing_id is not null or i.offer_id is not null))) then
      raise exception 'BOOKING_ITEMS_NOT_IN_CART' using errcode = '22023';
    end if;
    select coalesce(array_agg(distinct (x ->> 'shop_id')::uuid), '{}') into v_tech
    from jsonb_array_elements(v_lines) x
    where exists (select 1 from public.booking_items i where i.booking_id = bk.id
                  and ((x ->> 'listing_id')::uuid = i.listing_id or (x ->> 'offer_id')::uuid = i.offer_id));
  end if;

  -- Fulfilment per shop, checked before anything is written.
  for v_shop in select distinct (x ->> 'shop_id')::uuid from jsonb_array_elements(v_lines) x loop
    if v_shop = any (v_tech) then continue; end if;
    begin
      v_ful := coalesce(p_fulfilment ->> v_shop::text, 'PICKUP')::public.fulfilment_type;
    exception when invalid_text_representation then
      raise exception 'INVALID_FULFILMENT' using errcode = '22023';
    end;
    if v_ful = 'TO_TECHNICIAN' then
      raise exception 'INVALID_FULFILMENT' using errcode = '22023', detail = 'book a fitting for these parts';
    end if;
    if v_ful = 'DELIVERY' and v_addr is null then
      select jsonb_build_object('label', a.label, 'description_ar', a.description_ar, 'lat', a.lat, 'lng', a.lng)
        into v_addr
      from public.addresses a where a.id = p_address_id and a.user_id = v_uid;
      if v_addr is null then raise exception 'ADDRESS_REQUIRED' using errcode = '22023'; end if;
    end if;
  end loop;

  v_ref := public.new_ref('ORDER');
  insert into public.orders (ref, buyer_id, payment_method, items_sdg, total_sdg, pay_by, address_id,
                             address_snapshot, idem_key)
  values (v_ref, v_uid, p_method, 0, 0,
          case when p_method = 'BANKAK' or v_deposit > 0
               then now() + make_interval(mins => public.setting_int('payment_window_minutes')::integer) end,
          case when v_addr is not null then p_address_id end, v_addr, p_idem)
  returning id into v_order;

  for v_shop in select distinct (x ->> 'shop_id')::uuid from jsonb_array_elements(v_lines) x loop
    v_ful := case when v_shop = any (v_tech) then 'TO_TECHNICIAN'
                  else coalesce(p_fulfilment ->> v_shop::text, 'PICKUP')::public.fulfilment_type end;
    v_status := case when p_method = 'BANKAK' or (v_ful = 'TO_TECHNICIAN' and v_deposit > 0)
                     then 'PENDING_PAYMENT' else 'CONFIRMED' end;
    select sum((x ->> 'price_sdg')::bigint * (x ->> 'qty')::bigint) into v_items
    from jsonb_array_elements(v_lines) x where (x ->> 'shop_id')::uuid = v_shop;
    v_delivery := case when v_ful = 'DELIVERY' then public.delivery_fee(v_shop, p_address_id) else 0 end;

    insert into public.sub_orders (order_id, shop_id, status, fulfilment, items_sdg, delivery_fee_sdg,
                                   commission_bp, commission_sdg)
    values (v_order, v_shop, v_status, v_ful, v_items, v_delivery, v_bp, public.commission_of(v_items, v_bp))
    returning id into v_sub;
    insert into public.suborder_events (sub_order_id, from_status, to_status, actor_kind, actor_id)
    values (v_sub, null, v_status, 'BUYER', v_uid);

    insert into public.order_items (sub_order_id, listing_id, offer_id, part_id, title_ar, title_en, condition,
                                    brand, warranty_days, unit_price_sdg, qty, line_sdg)
    select v_sub, (x ->> 'listing_id')::uuid, (x ->> 'offer_id')::uuid, (x ->> 'part_id')::uuid,
           x ->> 'title_ar', coalesce(nullif(x ->> 'title_en', ''), x ->> 'title_ar'),
           (x ->> 'condition')::public.listing_condition, x ->> 'brand', coalesce((x ->> 'warranty_days')::integer, 0),
           (x ->> 'price_sdg')::bigint, (x ->> 'qty')::integer,
           (x ->> 'price_sdg')::bigint * (x ->> 'qty')::integer
    from jsonb_array_elements(v_lines) x where (x ->> 'shop_id')::uuid = v_shop;

    update public.listings l set reserved_qty = l.reserved_qty + (x ->> 'qty')::integer
    from jsonb_array_elements(v_lines) x
    where (x ->> 'shop_id')::uuid = v_shop and l.id = (x ->> 'listing_id')::uuid;
    update public.part_offers o set status = 'ORDERED'
    from jsonb_array_elements(v_lines) x
    where (x ->> 'shop_id')::uuid = v_shop and o.id = (x ->> 'offer_id')::uuid;

    if p_method = 'CASH' and v_ful <> 'TO_TECHNICIAN' then
      insert into public.payments (order_id, sub_order_id, method, status, amount_sdg)
      values (v_order, v_sub, 'CASH', 'DUE', v_items + v_delivery);
    end if;
    if v_status = 'CONFIRMED' then
      perform public.notify_shop(v_shop, 'NEW_ORDER',
                                 jsonb_build_object('order_id', v_order, 'sub_order_id', v_sub, 'ref', v_ref));
    end if;
    if v_ful = 'TO_TECHNICIAN' then v_tech_i := v_tech_i + v_items; end if;
    v_total_i := v_total_i + v_items;
    v_total_d := v_total_d + v_delivery;
  end loop;

  update public.orders
     set items_sdg = v_total_i, delivery_sdg = v_total_d,
         booking_fee_sdg = coalesce(bk.booking_fee_sdg, 0), labour_sdg = coalesce(bk.labour_sdg, 0),
         travel_sdg = coalesce(bk.travel_fee_sdg, 0),
         total_sdg = v_total_i + v_total_d + v_fees
   where id = v_order;
  if p_method = 'BANKAK' then
    insert into public.payments (order_id, booking_id, method, status, amount_sdg)
    values (v_order, bk.id, 'BANKAK', 'AWAITING_TRANSFER', v_total_i + v_total_d + v_fees);
  end if;

  if bk.id is not null then
    update public.bookings set order_id = v_order, payment_method = p_method, deposit_sdg = v_deposit where id = bk.id;
    -- Link the booked cart lines to the order items just written.
    for v_line in select x from jsonb_array_elements(v_lines) x loop
      update public.booking_items i set order_item_id = oi.id
        from public.order_items oi join public.sub_orders so on so.id = oi.sub_order_id
       where i.booking_id = bk.id and so.order_id = v_order
         and ((i.listing_id is not null and i.listing_id = oi.listing_id) or (i.offer_id is not null and i.offer_id = oi.offer_id));
    end loop;
    if p_method = 'CASH' then
      if v_tech_i + v_fees - v_deposit > 0 then
        insert into public.payments (order_id, booking_id, method, status, amount_sdg)
        values (v_order, bk.id, 'CASH', 'DUE', v_tech_i + v_fees - v_deposit);
      end if;
      if v_deposit > 0 then
        insert into public.payments (order_id, booking_id, purpose, method, status, amount_sdg)
        values (v_order, bk.id, 'BOOKING_DEPOSIT', 'BANKAK', 'AWAITING_TRANSFER', v_deposit);
      end if;
    end if;
    perform public.transition_booking(bk.id,
      case when p_method = 'BANKAK' or v_deposit > 0 then 'AWAITING_PAYMENT' else 'PENDING_TECH_ACCEPT' end::public.booking_status,
      'BUYER');
  end if;

  delete from public.cart_items c
   where c.user_id = v_uid
     and (c.listing_id in (select (x ->> 'listing_id')::uuid from jsonb_array_elements(v_lines) x)
          or c.offer_id in (select (x ->> 'offer_id')::uuid from jsonb_array_elements(v_lines) x));
  perform public.notify(v_uid, 'ORDER_PLACED', jsonb_build_object('order_id', v_order, 'ref', v_ref));

  return public.idem_finish(p_idem, 'checkout', public.order_json(v_order));
end
$$;

-- ------------------------------------------------------------------ payments
-- submit_bankak_receipt() from M2, for a booking deposit too.
create or replace function public.submit_bankak_receipt(
  p_order_id    uuid,
  p_txn_no      text default null,
  p_receipt_key text default null,
  p_idem        uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid  uuid := public.require_user();
  v_prev jsonb := public.idem_begin(p_idem, 'submit_bankak_receipt');
  o      public.orders;
  v_pay  public.payments;
  v_txn  text := public.clean_txn(p_txn_no);
  v_key  text := nullif(btrim(coalesce(p_receipt_key, '')), '');
  s      record;
begin
  if v_prev is not null then return v_prev; end if;
  select * into o from public.orders where id = p_order_id and buyer_id = v_uid;
  if o.id is null then raise exception 'ORDER_NOT_FOUND' using errcode = 'P0002'; end if;
  select * into v_pay from public.payments p
   where p.order_id = o.id and p.method = 'BANKAK' and p.purpose in ('ORDER', 'BOOKING_DEPOSIT') for update;
  if v_pay.id is null or v_pay.status not in ('AWAITING_TRANSFER', 'REJECTED') then
    raise exception 'NOT_AWAITING_PAYMENT' using errcode = 'PT409';
  end if;
  if o.pay_by < now() then raise exception 'PAYMENT_EXPIRED' using errcode = 'PT409'; end if;
  if nullif(btrim(coalesce(p_txn_no, '')), '') is not null and v_txn is null then
    raise exception 'INVALID_TXN' using errcode = '22023';
  end if;
  if v_txn is null and v_key is null then raise exception 'RECEIPT_REQUIRED' using errcode = '22023'; end if;
  if v_key is not null and (v_key not like v_uid::text || '/%'
     or not exists (select 1 from storage.objects so where so.bucket_id = 'receipts' and so.name = v_key)) then
    raise exception 'INVALID_RECEIPT_KEY' using errcode = '22023';
  end if;

  begin
    update public.payments set bankak_txn_no = v_txn, receipt_key = v_key, submitted_at = now(),
                               reject_reason = null
     where id = v_pay.id;
    perform public.transition_payment(v_pay.id, 'RECEIPT_SUBMITTED', 'BUYER');
  exception when unique_violation then
    raise exception 'DUPLICATE_TXN' using errcode = 'PT409';
  end;
  for s in select x.id from public.sub_orders x where x.order_id = o.id and x.status = 'PENDING_PAYMENT' loop
    perform public.transition_suborder(s.id, 'PAYMENT_REVIEW', 'BUYER');
  end loop;
  return public.idem_finish(p_idem, 'submit_bankak_receipt', public.order_json(o.id));
end
$$;

-- cancel_order() from M2: also a booking deposit, and the order's booking while it still
-- waits for payment or a technician (later on, buyer_cancel_booking applies).
create or replace function public.cancel_order(p_order_id uuid, p_reason text default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := public.require_user();
  o     public.orders;
  s     public.sub_orders;
  v_pay public.payments;
  bk    public.bookings;
begin
  select * into o from public.orders where id = p_order_id and buyer_id = v_uid for update;
  if o.id is null then raise exception 'ORDER_NOT_FOUND' using errcode = 'P0002'; end if;
  select * into bk from public.bookings b where b.order_id = o.id for update;
  if exists (select 1 from public.sub_orders x where x.order_id = o.id
             and not (x.status = 'PENDING_PAYMENT'
                      or (x.status = 'CONFIRMED' and o.payment_method = 'CASH' and x.shop_ack_at is null)
                      or x.status = 'CANCELLED'))
     or (bk.id is not null and bk.status not in ('AWAITING_PAYMENT', 'PENDING_TECH_ACCEPT')
         and public.booking_is_active(bk.status)) then
    raise exception 'CANNOT_CANCEL' using errcode = 'PT409';
  end if;
  select * into v_pay from public.payments p
   where p.order_id = o.id and p.method = 'BANKAK' and p.purpose in ('ORDER', 'BOOKING_DEPOSIT') for update;
  if v_pay.id is not null then
    if v_pay.status in ('AWAITING_TRANSFER', 'REJECTED') then
      perform public.transition_payment(v_pay.id, 'CANCELLED', 'BUYER', p_reason);
    elsif v_pay.status not in ('CANCELLED', 'EXPIRED') then
      raise exception 'CANNOT_CANCEL' using errcode = 'PT409';
    end if;
  end if;
  select * into bk from public.bookings b where b.order_id = o.id;
  if bk.id is not null and public.booking_is_active(bk.status) then
    perform public.transition_booking(bk.id, 'CANCELLED_BY_BUYER', 'BUYER', coalesce(nullif(btrim(p_reason), ''), 'BUYER_CANCELLED'));
  end if;
  for s in select * from public.sub_orders x where x.order_id = o.id and x.status <> 'CANCELLED' loop
    perform public.transition_suborder(s.id, 'CANCELLED', 'BUYER', coalesce(nullif(btrim(p_reason), ''), 'BUYER_CANCELLED'));
  end loop;
  return public.order_json(o.id);
end
$$;

-- expire_unpaid_orders() from M2, for booking deposits too.
create or replace function public.expire_unpaid_orders()
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
    where p.method = 'BANKAK' and p.purpose in ('ORDER', 'BOOKING_DEPOSIT') and p.status in ('AWAITING_TRANSFER', 'REJECTED')
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

-- A Bankak payment for a booking (the whole order, or the deposit) moves the booking:
-- confirmed → offered to the technician (D-023), or NEEDS_RESCHEDULE when the start is
-- too close; expired → EXPIRED; cancelled → cancelled by whoever cancelled the payment.
-- A payment confirmed after the booking ended is refunded (settle_booking).
create function public.tg_payment_booking()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  bk      public.bookings;
  v_actor text := nullif(current_setting('app.actor', true), '');
begin
  if new.booking_id is null or new.method <> 'BANKAK' or new.status is not distinct from old.status then
    return null;
  end if;
  select * into bk from public.bookings where id = new.booking_id for update;
  if new.status = 'CONFIRMED' then
    if bk.status = 'AWAITING_PAYMENT' then
      if bk.start_at < now() + interval '30 minutes' then
        perform public.transition_booking(bk.id, 'NEEDS_RESCHEDULE', 'ADMIN', 'PAID_TOO_LATE');
      else
        perform public.transition_booking(bk.id, 'PENDING_TECH_ACCEPT', 'ADMIN');
      end if;
    elsif not public.booking_is_active(bk.status) and bk.status <> 'NEEDS_RESCHEDULE' then
      perform public.settle_booking(bk.id);
    end if;
  elsif bk.status = 'AWAITING_PAYMENT' then
    if new.status = 'EXPIRED' then
      perform public.transition_booking(bk.id, 'EXPIRED', 'SYSTEM', 'PAYMENT_EXPIRED');
    elsif new.status = 'CANCELLED' then
      if v_actor = 'ADMIN' then
        perform public.transition_booking(bk.id, 'CANCELLED_BY_ADMIN', 'ADMIN', 'PAYMENT_CANCELLED');
      else
        perform public.transition_booking(bk.id, 'CANCELLED_BY_BUYER', 'BUYER', 'PAYMENT_CANCELLED');
      end if;
    end if;
  end if;
  return null;
end
$$;
create trigger payments_booking after update of status on public.payments
  for each row execute function public.tg_payment_booking();

revoke all on function
  public.post_booking_journal(text, uuid, uuid, bigint, uuid, uuid, uuid), public.booking_paid_upfront(uuid),
  public.booking_sub_orders(uuid), public.settle_booking(uuid),
  public.booking_parts_follow(uuid, public.booking_status), public.tg_payment_booking(),
  public.checkout(jsonb, public.payment_method, jsonb, uuid, uuid, uuid)
from public, anon, authenticated;

grant execute on function public.checkout(jsonb, public.payment_method, jsonb, uuid, uuid, uuid) to authenticated;
