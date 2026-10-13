-- M2 order flow: refunds, returns, and transition_suborder(), the one place where a
-- sub-order changes status. It writes the event row, then applies the side effects of
-- the new status: stock, cash collection, ledger journals, refunds and notifications.
--
-- Money per sub-order (A = items + delivery fee, K = commission), D-013:
--   Bankak paid ............ PAYMENT          Dr PLATFORM_BANKAK / Cr BUYER_FUNDS_HELD (whole order)
--   cash collected by shop . CASH_COLLECTED   Dr SHOP            / Cr BUYER_FUNDS_HELD  A
--   completed .............. SALE             Dr BUYER_FUNDS_HELD / Cr SHOP              A
--                            COMMISSION       Dr SHOP            / Cr REVENUE_COMMISSION K
--   refunded (Bankak) ...... REFUND           Dr BUYER_FUNDS_HELD / Cr REFUNDS_PAYABLE   A
--   cash given back ........ CASH_RETURNED    Dr BUYER_FUNDS_HELD / Cr SHOP              A
--   returned after sale .... SALE_REVERSAL + COMMISSION_REVERSAL, then the refund above
-- Whatever path an order takes, BUYER_FUNDS_HELD ends at zero for it.

create table public.refunds (
  id            uuid primary key default gen_random_uuid(),
  order_id      uuid not null references public.orders (id) on delete cascade,
  sub_order_id  uuid unique references public.sub_orders (id) on delete cascade,
  buyer_id      uuid not null references auth.users (id),
  amount_sdg    bigint not null check (amount_sdg > 0),
  reason        text,
  status        text not null default 'PENDING' check (status in ('PENDING', 'PAID')),
  bankak_txn_no text check (bankak_txn_no ~ '^[0-9]{6,20}$'),
  paid_by       uuid references auth.users (id) on delete set null,
  paid_at       timestamptz,
  created_at    timestamptz not null default now(),
  check ((status = 'PAID') = (bankak_txn_no is not null and paid_at is not null))
);
create unique index refunds_txn_once on public.refunds (bankak_txn_no) where bankak_txn_no is not null;
create index refunds_status_idx on public.refunds (status, created_at);

-- Buyers say where refunds go (their own Bankak account).
alter table public.profiles add column refund_account text check (refund_account ~ '^[0-9]{6,20}$');

-- A whole sub-order goes back; the buyer gets the full amount (D-085).
create table public.returns (
  id            uuid primary key default gen_random_uuid(),
  sub_order_id  uuid not null unique references public.sub_orders (id) on delete cascade,
  reason        text not null check (char_length(btrim(reason)) between 3 and 500),
  status        text not null default 'REQUESTED' check (status in ('REQUESTED', 'APPROVED', 'DECLINED')),
  decided_by    uuid references auth.users (id) on delete set null,
  decided_at    timestamptz,
  decision_note text check (char_length(decision_note) <= 500),
  created_at    timestamptz not null default now()
);

-- ------------------------------------------------------------------ money helpers
create function public.sale_posted(p_sub_order_id uuid)
returns boolean
language sql
stable
set search_path = ''
as $$
  select exists (select 1 from public.ledger_journals j where j.sub_order_id = p_sub_order_id and j.kind = 'SALE')
     and not exists (select 1 from public.ledger_journals j where j.sub_order_id = p_sub_order_id and j.kind = 'SALE_REVERSAL');
$$;

-- The buyer's money for this sub-order goes to the shop, minus commission.
create function public.post_sale(p_sub_order_id uuid)
returns void
language plpgsql
set search_path = ''
as $$
declare
  s public.sub_orders;
begin
  select * into s from public.sub_orders where id = p_sub_order_id;
  if public.sale_posted(s.id) then return; end if;
  perform public.post_journal('SALE', public.ledger_account('BUYER_FUNDS_HELD'), public.shop_account(s.shop_id),
                              s.items_sdg + s.delivery_fee_sdg, s.order_id, s.id);
  perform public.post_journal('COMMISSION', public.shop_account(s.shop_id), public.ledger_account('REVENUE_COMMISSION'),
                              s.commission_sdg, s.order_id, s.id);
end
$$;

create function public.reverse_sale(p_sub_order_id uuid)
returns void
language plpgsql
set search_path = ''
as $$
declare
  s public.sub_orders;
begin
  select * into s from public.sub_orders where id = p_sub_order_id;
  if not public.sale_posted(s.id) then return; end if;
  perform public.post_journal('SALE_REVERSAL', public.shop_account(s.shop_id), public.ledger_account('BUYER_FUNDS_HELD'),
                              s.items_sdg + s.delivery_fee_sdg, s.order_id, s.id);
  perform public.post_journal('COMMISSION_REVERSAL', public.ledger_account('REVENUE_COMMISSION'), public.shop_account(s.shop_id),
                              s.commission_sdg, s.order_id, s.id);
end
$$;

-- The shop took the buyer's cash for this sub-order.
create function public.collect_cash(p_sub_order_id uuid)
returns void
language plpgsql
set search_path = ''
as $$
declare
  s public.sub_orders;
  v_pay public.payments;
begin
  select * into s from public.sub_orders where id = p_sub_order_id;
  select * into v_pay from public.payments p
   where p.sub_order_id = s.id and p.method = 'CASH' and p.status = 'DUE' for update;
  if v_pay.id is null then return; end if;
  perform public.transition_payment(v_pay.id, 'COLLECTED', 'SHOP');
  update public.payments set collected_by = auth.uid(), collected_at = now() where id = v_pay.id;
  perform public.post_journal('CASH_COLLECTED', public.shop_account(s.shop_id), public.ledger_account('BUYER_FUNDS_HELD'),
                              v_pay.amount_sdg, s.order_id, s.id, v_pay.id);
end
$$;

-- Gives the buyer their money back for one sub-order: a Bankak refund to send
-- (admins see it under Payments → Refunds), or the shop hands the cash back.
create function public.refund_sub_order(p_sub_order_id uuid, p_reason text)
returns void
language plpgsql
set search_path = ''
as $$
declare
  s        public.sub_orders;
  o        public.orders;
  v_amount bigint;
  v_refund uuid;
  v_pay    public.payments;
begin
  select * into s from public.sub_orders where id = p_sub_order_id;
  select * into o from public.orders where id = s.order_id;
  v_amount := s.items_sdg + s.delivery_fee_sdg;
  if o.payment_method = 'BANKAK' then
    if exists (select 1 from public.payments p where p.order_id = o.id and p.method = 'BANKAK'
               and p.purpose = 'ORDER' and p.status = 'CONFIRMED') then
      insert into public.refunds (order_id, sub_order_id, buyer_id, amount_sdg, reason)
      values (o.id, s.id, o.buyer_id, v_amount, p_reason)
      on conflict (sub_order_id) do nothing
      returning id into v_refund;
      if v_refund is not null then
        perform public.post_journal('REFUND', public.ledger_account('BUYER_FUNDS_HELD'), public.ledger_account('REFUNDS_PAYABLE'),
                                    v_amount, o.id, s.id, null, null, v_refund);
        perform public.notify(o.buyer_id, 'REFUND_CREATED',
                              jsonb_build_object('order_id', o.id, 'ref', o.ref, 'amount_sdg', v_amount));
      end if;
    end if;
  else
    select * into v_pay from public.payments p where p.sub_order_id = s.id and p.method = 'CASH' for update;
    if v_pay.status = 'COLLECTED' then
      perform public.post_journal('CASH_RETURNED', public.ledger_account('BUYER_FUNDS_HELD'), public.shop_account(s.shop_id),
                                  v_pay.amount_sdg, o.id, s.id, v_pay.id);
    elsif v_pay.status = 'DUE' then
      perform public.transition_payment(v_pay.id, 'CANCELLED', 'SYSTEM', p_reason);
    end if;
  end if;
end
$$;

-- Stock reserved at checkout goes back on sale (cancelled before the part left the shop).
create function public.release_reservation(p_sub_order_id uuid)
returns void
language sql
set search_path = ''
as $$
  update public.listings l
     set reserved_qty = greatest(l.reserved_qty - i.qty, 0)
    from (select listing_id, sum(qty)::integer as qty from public.order_items
          where sub_order_id = p_sub_order_id and listing_id is not null group by listing_id) i
   where l.id = i.listing_id;
$$;

-- The part left the shop: reserved stock becomes sold stock.
create function public.take_stock(p_sub_order_id uuid)
returns void
language sql
set search_path = ''
as $$
  update public.listings l
     set reserved_qty = greatest(l.reserved_qty - i.qty, 0),
         stock_qty = greatest(l.stock_qty - i.qty, greatest(l.reserved_qty - i.qty, 0))
    from (select listing_id, sum(qty)::integer as qty from public.order_items
          where sub_order_id = p_sub_order_id and listing_id is not null group by listing_id) i
   where l.id = i.listing_id;
$$;

-- A delivery that never arrived: the part is back in the shop.
create function public.restock(p_sub_order_id uuid)
returns void
language sql
set search_path = ''
as $$
  update public.listings l
     set stock_qty = l.stock_qty + i.qty
    from (select listing_id, sum(qty)::integer as qty from public.order_items
          where sub_order_id = p_sub_order_id and listing_id is not null group by listing_id) i
   where l.id = i.listing_id;
$$;

-- ------------------------------------------------------------------ transitions
-- Moves a sub-order to `p_to` as `p_actor` (BUYER, SHOP, ADMIN, SYSTEM), records the
-- event and applies the side effects. Callers check who may act; the transition table
-- checks the move itself.
create function public.transition_suborder(p_id uuid, p_to public.suborder_status, p_actor text, p_reason text default null)
returns public.suborder_status
language plpgsql
set search_path = ''
as $$
declare
  v_from public.suborder_status;
  s      public.sub_orders;
  o      public.orders;
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
  v_info := jsonb_build_object('order_id', o.id, 'sub_order_id', s.id, 'ref', o.ref, 'status', p_to);

  case p_to
    when 'CANCELLED', 'REJECTED_BY_SHOP' then
      if v_from = 'OUT_FOR_DELIVERY' then
        perform public.restock(s.id);
      else
        perform public.release_reservation(s.id);
      end if;
      update public.sub_orders set cancelled_at = now(), cancel_reason = nullif(btrim(coalesce(p_reason, '')), '')
       where id = s.id;
      perform public.refund_sub_order(s.id, coalesce(p_reason, p_to::text));
      perform public.notify(o.buyer_id, case p_to when 'CANCELLED' then 'ORDER_CANCELLED' else 'ORDER_REJECTED_BY_SHOP' end,
                            v_info || jsonb_build_object('reason', p_reason));
      if p_actor <> 'SHOP' and v_from not in ('PENDING_PAYMENT', 'PAYMENT_REVIEW') then
        perform public.notify_shop(s.shop_id, 'ORDER_CANCELLED', v_info);
      end if;
    when 'CONFIRMED' then
      perform public.notify_shop(s.shop_id, 'NEW_ORDER', v_info);
    when 'READY' then
      update public.sub_orders set ready_at = now() where id = s.id;
      perform public.notify(o.buyer_id, 'ORDER_READY', v_info);
    when 'PICKED_UP', 'OUT_FOR_DELIVERY', 'HANDED_TO_TECHNICIAN' then
      perform public.take_stock(s.id);
      update public.sub_orders set handed_over_at = now() where id = s.id;
      if p_to = 'PICKED_UP' then perform public.collect_cash(s.id); end if;
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
      perform public.notify(o.buyer_id, 'RETURN_APPROVED', v_info);
      perform public.notify_shop(s.shop_id, 'RETURN_APPROVED', v_info);
    else
      null;  -- PAYMENT_REVIEW, PENDING_PAYMENT: the payment RPCs notify
  end case;
  return v_from;
end
$$;

-- Buyer-facing summary of one order, used as the return value of order RPCs.
create function public.order_json(p_order_id uuid)
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
                               'amount_sdg', r.amount_sdg, 'status', r.status, 'paid_at', r.paid_at))
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
           where s.order_id = o.id), '[]'))
  from public.orders o
  where o.id = p_order_id;
$$;

alter table public.refunds enable row level security;
alter table public.returns enable row level security;
revoke all on public.refunds, public.returns from anon, authenticated;
grant select on public.refunds, public.returns to authenticated;

create policy refunds_read on public.refunds for select to authenticated
  using (buyer_id = (select auth.uid()) or (select public.is_admin()));
create policy returns_read on public.returns for select to authenticated
  using (public.can_see_sub_order(sub_order_id));

revoke all on function
  public.sale_posted(uuid), public.post_sale(uuid), public.reverse_sale(uuid), public.collect_cash(uuid),
  public.refund_sub_order(uuid, text), public.release_reservation(uuid), public.take_stock(uuid),
  public.restock(uuid), public.transition_suborder(uuid, public.suborder_status, text, text),
  public.order_json(uuid)
from public, anon, authenticated;
