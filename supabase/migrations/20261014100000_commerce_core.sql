-- M2 core: commerce enums, in-app notifications, the ledger, orders, sub-orders and
-- payments, and the transition tables that guard every status change (PLAN §3.6–3.10).
--
-- Status changes: a trigger allows a change only when (from, to, actor) is in the
-- transition table, where the actor is what the calling RPC declared in `app.actor`
-- (BUYER, SHOP, ADMIN, SYSTEM). An UPDATE without a declared actor is refused, even from
-- the SQL editor, so every change goes through an RPC that writes its event row.

create type public.suborder_status as enum (
  'PENDING_PAYMENT', 'PAYMENT_REVIEW', 'CONFIRMED', 'READY', 'PICKED_UP', 'OUT_FOR_DELIVERY',
  'DELIVERED', 'HANDED_TO_TECHNICIAN', 'COMPLETED', 'CANCELLED', 'REJECTED_BY_SHOP',
  'RETURN_REQUESTED', 'RETURNED');
create type public.fulfilment_type as enum ('PICKUP', 'DELIVERY', 'TO_TECHNICIAN');
create type public.payment_method as enum ('BANKAK', 'CASH');
create type public.payment_purpose as enum ('ORDER', 'BOOKING_DEPOSIT');
create type public.payment_status as enum (
  'AWAITING_TRANSFER', 'RECEIPT_SUBMITTED', 'CONFIRMED', 'REJECTED', 'DUE', 'COLLECTED', 'EXPIRED',
  'CANCELLED');

-- ------------------------------------------------------------------ helpers
-- Reads one admin setting (server side only).
create function public.setting(p_key text)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select s.value from public.app_settings s where s.key = p_key;
$$;

create function public.setting_int(p_key text)
returns bigint
language sql
stable
security definer
set search_path = ''
as $$
  select (s.value #>> '{}')::numeric::bigint from public.app_settings s where s.key = p_key;
$$;

-- Luhn check digit for a string of digits (D-016); the rightmost digit is doubled.
create function public.luhn_check_digit(p_digits text)
returns integer
language sql
immutable
set search_path = ''
as $$
  select ((10 - (sum(case when (char_length(p_digits) - pos) % 2 = 0
                          then case when d * 2 > 9 then d * 2 - 9 else d * 2 end
                          else d end) % 10)) % 10)::integer
  from (select pos, substr(p_digits, pos, 1)::integer as d
        from generate_series(1, char_length(p_digits)) as pos) x;
$$;

-- Every reference a buyer may type into a Bankak note, orders and (M3) bookings alike.
create table public.refs (
  ref        text primary key check (ref ~ '^[1-9][0-9]{7}$'),
  kind       text not null check (kind in ('ORDER', 'BOOKING')),
  created_at timestamptz not null default now()
);

-- 7 random digits (no leading zero) plus a Luhn digit, unique across orders and bookings.
create function public.new_ref(p_kind text)
returns text
language plpgsql
set search_path = ''
as $$
declare
  v_seven text;
  v_ref   text;
begin
  loop
    v_seven := (1000000 + floor(random() * 9000000))::bigint::text;
    v_ref := v_seven || public.luhn_check_digit(v_seven)::text;
    insert into public.refs (ref, kind) values (v_ref, p_kind) on conflict do nothing;
    if found then return v_ref; end if;
  end loop;
end
$$;

-- ------------------------------------------------------------------ notifications
-- The in-app inbox. M3 adds push delivery; every alert lands here too (D-061).
create table public.notifications (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references auth.users (id) on delete cascade,
  code       text not null check (code ~ '^[A-Z][A-Z_]*$'),
  payload    jsonb not null default '{}',
  created_at timestamptz not null default now(),
  read_at    timestamptz
);
create index notifications_user_idx on public.notifications (user_id, created_at desc);

create function public.notify(p_user_id uuid, p_code text, p_payload jsonb default '{}')
returns void
language sql
security definer
set search_path = ''
as $$
  insert into public.notifications (user_id, code, payload) values (p_user_id, p_code, coalesce(p_payload, '{}'));
$$;

-- Every member of a shop.
create function public.notify_shop(p_shop_id uuid, p_code text, p_payload jsonb default '{}')
returns void
language sql
security definer
set search_path = ''
as $$
  insert into public.notifications (user_id, code, payload)
  select m.user_id, p_code, coalesce(p_payload, '{}') || jsonb_build_object('shop_id', p_shop_id)
  from public.shop_members m where m.shop_id = p_shop_id;
$$;

-- Marks the given notifications (or all of the caller's) as read.
create function public.mark_notifications_read(p_ids uuid[] default null)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_n integer;
begin
  update public.notifications
     set read_at = now()
   where user_id = public.require_user() and read_at is null
     and (p_ids is null or id = any (p_ids));
  get diagnostics v_n = row_count;
  return v_n;
end
$$;

-- ------------------------------------------------------------------ ledger
-- Double entry: every journal's entries sum to zero (+ debit, − credit). Append-only.
-- Party accounts: a credit balance means the platform owes the party; a debit balance
-- means the party owes the platform (D-013, D-018).
create table public.ledger_accounts (
  id            uuid primary key default gen_random_uuid(),
  code          text not null unique,
  kind          text not null check (kind in ('ASSET', 'LIABILITY', 'REVENUE', 'PARTY')),
  shop_id       uuid unique references public.shops (id) on delete set null,
  technician_id uuid unique,          -- FK added with technicians (M3)
  created_at    timestamptz not null default now(),
  check (num_nonnulls(shop_id, technician_id) <= 1)
);

insert into public.ledger_accounts (code, kind) values
  ('PLATFORM_BANKAK',     'ASSET'),       -- money in the platform's Bankak account
  ('BUYER_FUNDS_HELD',    'LIABILITY'),   -- buyers' money until the order completes
  ('REFUNDS_PAYABLE',     'LIABILITY'),   -- refunds the platform still has to send
  ('REVENUE_COMMISSION',  'REVENUE'),
  ('REVENUE_BOOKING_FEE', 'REVENUE');

create table public.ledger_journals (
  id          uuid primary key default gen_random_uuid(),
  kind        text not null check (kind in (
                'PAYMENT', 'CASH_COLLECTED', 'CASH_RETURNED', 'SALE', 'SALE_REVERSAL', 'COMMISSION',
                'COMMISSION_REVERSAL', 'REFUND', 'REFUND_PAID', 'PAYOUT', 'ADJUSTMENT',
                'BOOKING_FEE', 'DEPOSIT', 'LABOUR', 'TRAVEL_FEE', 'CASH_HANDOVER')),
  order_id    uuid,
  sub_order_id uuid,
  payment_id  uuid,
  payout_id   uuid,
  refund_id   uuid,
  memo        text,
  created_by  uuid references auth.users (id) on delete set null,
  created_at  timestamptz not null default now()
);
create index ledger_journals_sub_order_idx on public.ledger_journals (sub_order_id, kind);
create index ledger_journals_order_idx on public.ledger_journals (order_id);

create table public.ledger_entries (
  id         bigint generated always as identity primary key,
  journal_id uuid not null references public.ledger_journals (id),
  account_id uuid not null references public.ledger_accounts (id),
  amount_sdg bigint not null check (amount_sdg <> 0)
);
create index ledger_entries_account_idx on public.ledger_entries (account_id);
create index ledger_entries_journal_idx on public.ledger_entries (journal_id);

create function public.tg_append_only()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception 'APPEND_ONLY' using errcode = '42501';
end
$$;

create trigger ledger_journals_append_only before update or delete on public.ledger_journals
  for each row execute function public.tg_append_only();
create trigger ledger_entries_append_only before update or delete on public.ledger_entries
  for each row execute function public.tg_append_only();

-- Checked when the transaction commits, so a journal's entries can be inserted one by one.
create function public.tg_ledger_balanced()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if (select coalesce(sum(e.amount_sdg), 0) from public.ledger_entries e where e.journal_id = new.journal_id) <> 0 then
    raise exception 'LEDGER_UNBALANCED' using errcode = '23514', detail = new.journal_id::text;
  end if;
  return null;
end
$$;

create constraint trigger ledger_entries_balanced
  after insert on public.ledger_entries
  deferrable initially deferred
  for each row execute function public.tg_ledger_balanced();

create function public.ledger_account(p_code text)
returns uuid
language sql
stable
set search_path = ''
as $$
  select a.id from public.ledger_accounts a where a.code = p_code;
$$;

create function public.shop_account(p_shop_id uuid)
returns uuid
language plpgsql
set search_path = ''
as $$
declare
  v_id uuid;
begin
  select a.id into v_id from public.ledger_accounts a where a.shop_id = p_shop_id;
  if v_id is null then
    insert into public.ledger_accounts (code, kind, shop_id)
    values ('SHOP:' || p_shop_id, 'PARTY', p_shop_id)
    on conflict (shop_id) do nothing
    returning id into v_id;
    if v_id is null then
      select a.id into v_id from public.ledger_accounts a where a.shop_id = p_shop_id;
    end if;
  end if;
  return v_id;
end
$$;

-- Posts a two-line journal: debit one account, credit another. Zero amounts post nothing.
create function public.post_journal(
  p_kind         text,
  p_debit        uuid,
  p_credit       uuid,
  p_amount       bigint,
  p_order_id     uuid default null,
  p_sub_order_id uuid default null,
  p_payment_id   uuid default null,
  p_payout_id    uuid default null,
  p_refund_id    uuid default null,
  p_memo         text default null
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
  insert into public.ledger_journals (kind, order_id, sub_order_id, payment_id, payout_id, refund_id, memo, created_by)
  values (p_kind, p_order_id, p_sub_order_id, p_payment_id, p_payout_id, p_refund_id, p_memo, auth.uid())
  returning id into v_id;
  insert into public.ledger_entries (journal_id, account_id, amount_sdg)
  values (v_id, p_debit, p_amount), (v_id, p_credit, -p_amount);
  return v_id;
end
$$;

-- Balance of an account (+ debit, − credit).
create function public.account_balance(p_account_id uuid)
returns bigint
language sql
stable
set search_path = ''
as $$
  select coalesce(sum(e.amount_sdg), 0)::bigint from public.ledger_entries e where e.account_id = p_account_id;
$$;

-- ------------------------------------------------------------------ orders
create table public.orders (
  id              uuid primary key default gen_random_uuid(),
  ref             text not null unique references public.refs (ref),
  buyer_id        uuid not null references auth.users (id),
  payment_method  public.payment_method not null,
  items_sdg       bigint not null check (items_sdg >= 0),
  delivery_sdg    bigint not null default 0 check (delivery_sdg >= 0),
  booking_fee_sdg bigint not null default 0 check (booking_fee_sdg >= 0),
  labour_sdg      bigint not null default 0 check (labour_sdg >= 0),
  travel_sdg      bigint not null default 0 check (travel_sdg >= 0),
  total_sdg       bigint not null check (total_sdg = items_sdg + delivery_sdg + booking_fee_sdg + labour_sdg + travel_sdg),
  pay_by          timestamptz,          -- Bankak only: unpaid orders are cancelled after this (D-015)
  address_id      uuid references public.addresses (id) on delete set null,
  address_snapshot jsonb,               -- label, directions and point at checkout
  idem_key        uuid,
  created_at      timestamptz not null default now(),
  unique (buyer_id, idem_key)
);
create index orders_buyer_idx on public.orders (buyer_id, created_at desc);

create table public.sub_orders (
  id                uuid primary key default gen_random_uuid(),
  order_id          uuid not null references public.orders (id) on delete cascade,
  shop_id           uuid not null references public.shops (id),
  status            public.suborder_status not null,
  fulfilment        public.fulfilment_type not null,
  items_sdg         bigint not null check (items_sdg >= 0),
  delivery_fee_sdg  bigint not null default 0 check (delivery_fee_sdg >= 0),
  commission_bp     integer not null check (commission_bp between 0 and 5000),   -- snapshot at checkout
  commission_sdg    bigint not null check (commission_sdg >= 0),
  shop_ack_at       timestamptz,        -- D-020: the shop tapped "Accept"
  ready_at          timestamptz,
  handed_over_at    timestamptz,
  delivered_at      timestamptz,
  completed_at      timestamptz,
  cancelled_at      timestamptz,
  cancel_reason     text check (char_length(cancel_reason) <= 500),
  status_changed_at timestamptz not null default now(),
  created_at        timestamptz not null default now(),
  unique (order_id, shop_id)
);
create index sub_orders_shop_idx on public.sub_orders (shop_id, status);
create index sub_orders_status_idx on public.sub_orders (status, status_changed_at);

-- Immutable after checkout: the price lock.
create table public.order_items (
  id             uuid primary key default gen_random_uuid(),
  sub_order_id   uuid not null references public.sub_orders (id) on delete cascade,
  listing_id     uuid references public.listings (id),
  offer_id       uuid,                -- FK added with part_offers
  part_id        uuid references public.parts (id),
  title_ar       text not null,
  title_en       text not null,
  condition      public.listing_condition not null,
  brand          text,
  warranty_days  integer not null default 0,
  unit_price_sdg bigint not null check (unit_price_sdg > 0),
  qty            integer not null check (qty between 1 and 99),
  line_sdg       bigint not null check (line_sdg = unit_price_sdg * qty),
  check (num_nonnulls(listing_id, offer_id) = 1)
);
create index order_items_sub_order_idx on public.order_items (sub_order_id);

create table public.suborder_events (
  id           bigint generated always as identity primary key,
  sub_order_id uuid not null references public.sub_orders (id) on delete cascade,
  from_status  public.suborder_status,
  to_status    public.suborder_status not null,
  actor_kind   text not null check (actor_kind in ('BUYER', 'SHOP', 'ADMIN', 'SYSTEM')),
  actor_id     uuid references auth.users (id) on delete set null,
  reason       text,
  at           timestamptz not null default now()
);
create index suborder_events_sub_order_idx on public.suborder_events (sub_order_id, at);

-- ------------------------------------------------------------------ payments
create table public.payments (
  id                 uuid primary key default gen_random_uuid(),
  order_id           uuid not null references public.orders (id) on delete cascade,
  sub_order_id       uuid references public.sub_orders (id) on delete cascade,  -- cash: each shop collects its part
  booking_id         uuid,                                                       -- M3
  purpose            public.payment_purpose not null default 'ORDER',
  method             public.payment_method not null,
  status             public.payment_status not null,
  amount_sdg         bigint not null check (amount_sdg > 0),
  bankak_txn_no      text check (bankak_txn_no ~ '^[0-9]{6,20}$'),
  receipt_key        text,
  submitted_at       timestamptz,
  reviewed_by        uuid references auth.users (id) on delete set null,
  reviewed_at        timestamptz,
  reject_reason      text,
  ref_in_note        boolean,         -- the admin saw the order number in the transfer note
  collected_by       uuid references auth.users (id) on delete set null,
  collected_at       timestamptz,
  created_at         timestamptz not null default now(),
  check (method = 'CASH' or sub_order_id is null),
  check (method = 'BANKAK' or (bankak_txn_no is null and receipt_key is null))
);
create index payments_order_idx on public.payments (order_id);
create index payments_status_idx on public.payments (status, submitted_at);
-- D-017: one Bankak transfer can pay for one payment only.
create unique index payments_txn_once on public.payments (bankak_txn_no)
  where status in ('RECEIPT_SUBMITTED', 'CONFIRMED');

create table public.payment_events (
  id          bigint generated always as identity primary key,
  payment_id  uuid not null references public.payments (id) on delete cascade,
  from_status public.payment_status,
  to_status   public.payment_status not null,
  actor_kind  text not null check (actor_kind in ('BUYER', 'SHOP', 'ADMIN', 'SYSTEM')),
  actor_id    uuid references auth.users (id) on delete set null,
  note        text,
  at          timestamptz not null default now()
);
create index payment_events_payment_idx on public.payment_events (payment_id, at);

-- ------------------------------------------------------------------ state machines
create table public.suborder_transitions (
  from_status public.suborder_status not null,
  to_status   public.suborder_status not null,
  actor       text not null check (actor in ('BUYER', 'SHOP', 'ADMIN', 'SYSTEM')),
  primary key (from_status, to_status, actor)
);

insert into public.suborder_transitions (from_status, to_status, actor) values
  ('PENDING_PAYMENT',      'PAYMENT_REVIEW',       'BUYER'),
  ('PENDING_PAYMENT',      'CANCELLED',            'BUYER'),
  ('PENDING_PAYMENT',      'CANCELLED',            'SYSTEM'),
  ('PENDING_PAYMENT',      'CANCELLED',            'ADMIN'),
  ('PAYMENT_REVIEW',       'CONFIRMED',            'ADMIN'),
  ('PAYMENT_REVIEW',       'PENDING_PAYMENT',      'ADMIN'),
  ('PAYMENT_REVIEW',       'CANCELLED',            'ADMIN'),
  ('CONFIRMED',            'READY',                'SHOP'),
  ('CONFIRMED',            'REJECTED_BY_SHOP',     'SHOP'),
  ('CONFIRMED',            'CANCELLED',            'BUYER'),   -- cash orders the shop hasn't accepted yet
  ('CONFIRMED',            'CANCELLED',            'ADMIN'),
  ('READY',                'PICKED_UP',            'SHOP'),
  ('READY',                'OUT_FOR_DELIVERY',     'SHOP'),
  ('READY',                'HANDED_TO_TECHNICIAN', 'SHOP'),
  ('READY',                'REJECTED_BY_SHOP',     'SHOP'),
  ('READY',                'CANCELLED',            'ADMIN'),
  ('OUT_FOR_DELIVERY',     'DELIVERED',            'SHOP'),
  ('OUT_FOR_DELIVERY',     'CANCELLED',            'ADMIN'),
  ('PICKED_UP',            'COMPLETED',            'BUYER'),
  ('PICKED_UP',            'COMPLETED',            'SYSTEM'),
  ('PICKED_UP',            'COMPLETED',            'ADMIN'),
  ('DELIVERED',            'COMPLETED',            'BUYER'),
  ('DELIVERED',            'COMPLETED',            'SYSTEM'),
  ('DELIVERED',            'COMPLETED',            'ADMIN'),
  ('HANDED_TO_TECHNICIAN', 'COMPLETED',            'SYSTEM'),
  ('HANDED_TO_TECHNICIAN', 'COMPLETED',            'ADMIN'),
  ('PICKED_UP',            'RETURN_REQUESTED',     'BUYER'),
  ('DELIVERED',            'RETURN_REQUESTED',     'BUYER'),
  ('COMPLETED',            'RETURN_REQUESTED',     'BUYER'),
  ('RETURN_REQUESTED',     'RETURNED',             'ADMIN'),
  ('RETURN_REQUESTED',     'COMPLETED',            'ADMIN');   -- return declined

create table public.payment_transitions (
  from_status public.payment_status not null,
  to_status   public.payment_status not null,
  actor       text not null check (actor in ('BUYER', 'SHOP', 'ADMIN', 'SYSTEM')),
  primary key (from_status, to_status, actor)
);

insert into public.payment_transitions (from_status, to_status, actor) values
  ('AWAITING_TRANSFER', 'RECEIPT_SUBMITTED', 'BUYER'),
  ('AWAITING_TRANSFER', 'EXPIRED',           'SYSTEM'),
  ('AWAITING_TRANSFER', 'CANCELLED',         'BUYER'),
  ('AWAITING_TRANSFER', 'CANCELLED',         'ADMIN'),
  ('RECEIPT_SUBMITTED', 'CONFIRMED',         'ADMIN'),
  ('RECEIPT_SUBMITTED', 'REJECTED',          'ADMIN'),
  ('RECEIPT_SUBMITTED', 'CANCELLED',         'ADMIN'),
  ('REJECTED',          'RECEIPT_SUBMITTED', 'BUYER'),
  ('REJECTED',          'EXPIRED',           'SYSTEM'),
  ('REJECTED',          'CANCELLED',         'BUYER'),
  ('REJECTED',          'CANCELLED',         'ADMIN'),
  ('DUE',               'COLLECTED',         'SHOP'),
  ('DUE',               'CANCELLED',         'BUYER'),
  ('DUE',               'CANCELLED',         'SHOP'),
  ('DUE',               'CANCELLED',         'ADMIN'),
  ('DUE',               'CANCELLED',         'SYSTEM');

create function public.suborder_transition_allowed(p_from public.suborder_status, p_to public.suborder_status, p_actor text)
returns boolean
language sql
stable
set search_path = ''
as $$
  select exists (select 1 from public.suborder_transitions t
                 where t.from_status = p_from and t.to_status = p_to and t.actor = p_actor);
$$;

create function public.payment_transition_allowed(p_from public.payment_status, p_to public.payment_status, p_actor text)
returns boolean
language sql
stable
set search_path = ''
as $$
  select exists (select 1 from public.payment_transitions t
                 where t.from_status = p_from and t.to_status = p_to and t.actor = p_actor);
$$;

create function public.tg_suborder_status_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.status is distinct from old.status then
    if not public.suborder_transition_allowed(old.status, new.status, nullif(current_setting('app.actor', true), '')) then
      raise exception 'INVALID_TRANSITION' using errcode = 'PT409', detail = old.status || ' -> ' || new.status;
    end if;
    new.status_changed_at := now();
  end if;
  return new;
end
$$;

create function public.tg_payment_status_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.status is distinct from old.status
     and not public.payment_transition_allowed(old.status, new.status, nullif(current_setting('app.actor', true), '')) then
    raise exception 'INVALID_TRANSITION' using errcode = 'PT409', detail = old.status || ' -> ' || new.status;
  end if;
  return new;
end
$$;

create trigger sub_orders_status_guard before update of status on public.sub_orders
  for each row execute function public.tg_suborder_status_guard();
create trigger payments_status_guard before update of status on public.payments
  for each row execute function public.tg_payment_status_guard();

-- Order items never change after checkout.
create trigger order_items_append_only before update or delete on public.order_items
  for each row when (pg_trigger_depth() = 0) execute function public.tg_append_only();

-- Moves a payment to `p_to` as `p_actor` and records the event.
create function public.transition_payment(p_id uuid, p_to public.payment_status, p_actor text, p_note text default null)
returns public.payment_status
language plpgsql
set search_path = ''
as $$
declare
  v_from public.payment_status;
begin
  select p.status into v_from from public.payments p where p.id = p_id for update;
  if not found then raise exception 'PAYMENT_NOT_FOUND' using errcode = 'P0002'; end if;
  perform set_config('app.actor', p_actor, true);
  update public.payments set status = p_to where id = p_id;
  perform set_config('app.actor', '', true);
  insert into public.payment_events (payment_id, from_status, to_status, actor_kind, actor_id, note)
  values (p_id, v_from, p_to, p_actor, auth.uid(), p_note);
  return v_from;
end
$$;

-- ------------------------------------------------------------------ RLS + grants
alter table public.refs enable row level security;
alter table public.notifications enable row level security;
alter table public.ledger_accounts enable row level security;
alter table public.ledger_journals enable row level security;
alter table public.ledger_entries enable row level security;
alter table public.orders enable row level security;
alter table public.sub_orders enable row level security;
alter table public.order_items enable row level security;
alter table public.suborder_events enable row level security;
alter table public.payments enable row level security;
alter table public.payment_events enable row level security;
alter table public.suborder_transitions enable row level security;
alter table public.payment_transitions enable row level security;

revoke all on public.refs, public.notifications, public.ledger_accounts, public.ledger_journals,
              public.ledger_entries, public.orders, public.sub_orders, public.order_items,
              public.suborder_events, public.payments, public.payment_events,
              public.suborder_transitions, public.payment_transitions
  from anon, authenticated;

grant select on public.notifications, public.ledger_accounts, public.ledger_journals, public.ledger_entries,
                public.orders, public.sub_orders, public.order_items, public.suborder_events,
                public.payments, public.payment_events, public.suborder_transitions,
                public.payment_transitions
  to authenticated;

create policy notifications_own on public.notifications for select to authenticated
  using (user_id = (select auth.uid()));

create policy ledger_accounts_admin on public.ledger_accounts for select to authenticated
  using ((select public.is_admin()));
create policy ledger_journals_admin on public.ledger_journals for select to authenticated
  using ((select public.is_admin()));
create policy ledger_entries_admin on public.ledger_entries for select to authenticated
  using ((select public.is_admin()));

create policy transitions_read on public.suborder_transitions for select to authenticated using (true);
create policy payment_transitions_read on public.payment_transitions for select to authenticated using (true);

-- The buyer, the shop it belongs to, or an admin. A shop never sees another shop's part
-- of the same order, nor the order's totals (it gets the reference through shop_orders).
create function public.can_see_sub_order(p_sub_order_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select 1 from public.sub_orders s join public.orders o on o.id = s.order_id
                 where s.id = p_sub_order_id
                   and (o.buyer_id = auth.uid() or public.is_shop_member(s.shop_id)))
      or public.is_admin();
$$;

create policy orders_read on public.orders for select to authenticated
  using (buyer_id = (select auth.uid()) or (select public.is_admin()));
create policy sub_orders_read on public.sub_orders for select to authenticated
  using (public.is_shop_member(shop_id)
         or exists (select 1 from public.orders o where o.id = order_id and o.buyer_id = (select auth.uid()))
         or (select public.is_admin()));
create policy order_items_read on public.order_items for select to authenticated
  using (public.can_see_sub_order(sub_order_id));
create policy suborder_events_read on public.suborder_events for select to authenticated
  using (public.can_see_sub_order(sub_order_id));
-- Buyers see their payments; a shop sees only the cash payment of its own sub-order.
create policy payments_read on public.payments for select to authenticated
  using (exists (select 1 from public.orders o where o.id = order_id and o.buyer_id = (select auth.uid()))
         or (sub_order_id is not null and public.can_see_sub_order(sub_order_id))
         or (select public.is_admin()));
create policy payment_events_read on public.payment_events for select to authenticated
  using (exists (select 1 from public.payments p where p.id = payment_id));  -- inherits payments_read

revoke all on function
  public.setting(text), public.setting_int(text), public.luhn_check_digit(text), public.new_ref(text),
  public.notify(uuid, text, jsonb), public.notify_shop(uuid, text, jsonb),
  public.mark_notifications_read(uuid[]), public.tg_append_only(), public.tg_ledger_balanced(),
  public.ledger_account(text), public.shop_account(uuid),
  public.post_journal(text, uuid, uuid, bigint, uuid, uuid, uuid, uuid, uuid, text),
  public.account_balance(uuid),
  public.suborder_transition_allowed(public.suborder_status, public.suborder_status, text),
  public.payment_transition_allowed(public.payment_status, public.payment_status, text),
  public.tg_suborder_status_guard(), public.tg_payment_status_guard(),
  public.transition_payment(uuid, public.payment_status, text, text),
  public.can_see_sub_order(uuid)
from public, anon, authenticated;

grant execute on function public.can_see_sub_order(uuid),
                          public.mark_notifications_read(uuid[])
  to authenticated;
