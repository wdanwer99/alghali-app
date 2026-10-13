-- M2 payouts and statements. A shop's ledger balance says who owes whom: credit = the
-- platform owes the shop (paid in the next payout), debit = the shop owes the platform
-- (commission on cash it kept), carried forward and netted later (D-018).

create table public.payout_runs (
  id          uuid primary key default gen_random_uuid(),
  period_from timestamptz,
  period_to   timestamptz not null,
  created_by  uuid references auth.users (id) on delete set null,
  created_at  timestamptz not null default now()
);

create table public.payouts (
  id             uuid primary key default gen_random_uuid(),
  run_id         uuid not null references public.payout_runs (id),
  shop_id        uuid references public.shops (id) on delete set null,
  technician_id  uuid,                 -- M3
  amount_sdg     bigint not null check (amount_sdg > 0),
  sales_sdg      bigint not null default 0,   -- credited in the period
  deductions_sdg bigint not null default 0,   -- commission, cash kept, balances carried: sales − amount
  status         text not null default 'DRAFT' check (status in ('DRAFT', 'APPROVED', 'PAID', 'CANCELLED')),
  bankak_txn_no  text check (bankak_txn_no ~ '^[0-9]{6,20}$'),
  approved_by    uuid references auth.users (id) on delete set null,
  approved_at    timestamptz,
  paid_by        uuid references auth.users (id) on delete set null,
  paid_at        timestamptz,
  cancel_reason  text,
  created_at     timestamptz not null default now(),
  check ((status = 'PAID') = (bankak_txn_no is not null and paid_at is not null))
);
create unique index payouts_txn_once on public.payouts (bankak_txn_no) where bankak_txn_no is not null;
create unique index payouts_one_open on public.payouts (shop_id) where status in ('DRAFT', 'APPROVED');
create index payouts_run_idx on public.payouts (run_id);

-- Shops that owed the platform at each run, for "unpaid for N cycles" (D-018).
create table public.payout_run_balances (
  run_id      uuid not null references public.payout_runs (id) on delete cascade,
  shop_id     uuid not null references public.shops (id) on delete cascade,
  balance_sdg bigint not null check (balance_sdg > 0),   -- what the shop owes
  primary key (run_id, shop_id)
);

-- What the platform owes the shop now (positive) or the shop owes (negative).
create function public.shop_balance(p_shop_id uuid)
returns bigint
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(-sum(e.amount_sdg), 0)::bigint
  from public.ledger_entries e join public.ledger_accounts a on a.id = e.account_id
  where a.shop_id = p_shop_id;
$$;

-- Creates a draft payout for every shop the platform owes, up to p_period_to, minus any
-- payout already waiting; records the shops that owe the platform.
create function public.admin_generate_payouts(p_period_to timestamptz default now())
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_admin uuid := public.require_admin();
  v_run   uuid;
  v_from  timestamptz := (select max(r.period_to) from public.payout_runs r);
  v_to    timestamptz := least(coalesce(p_period_to, now()), now());
  a       record;
  v_owed  bigint;
  v_sales bigint;
  v_n     integer := 0;
  v_total bigint := 0;
begin
  if v_from is not null and v_to <= v_from then
    raise exception 'PERIOD_ALREADY_PAID' using errcode = 'PT409';
  end if;
  insert into public.payout_runs (period_from, period_to, created_by) values (v_from, v_to, v_admin)
  returning id into v_run;

  for a in
    select la.id as account_id, la.shop_id,
           coalesce(-sum(e.amount_sdg) filter (where j.created_at <= v_to), 0)::bigint as owed
    from public.ledger_accounts la
    join public.ledger_entries e on e.account_id = la.id
    join public.ledger_journals j on j.id = e.journal_id
    where la.shop_id is not null
    group by la.id, la.shop_id
  loop
    if a.owed < 0 then
      insert into public.payout_run_balances (run_id, shop_id, balance_sdg) values (v_run, a.shop_id, -a.owed);
      continue;
    end if;
    v_owed := a.owed - coalesce((select sum(p.amount_sdg) from public.payouts p
                                 where p.shop_id = a.shop_id and p.status in ('DRAFT', 'APPROVED')), 0);
    if v_owed <= 0 or exists (select 1 from public.payouts p where p.shop_id = a.shop_id and p.status in ('DRAFT', 'APPROVED')) then
      continue;
    end if;
    select coalesce(-sum(e.amount_sdg), 0) into v_sales
    from public.ledger_entries e join public.ledger_journals j on j.id = e.journal_id
    where e.account_id = a.account_id and j.kind = 'SALE'
      and j.created_at <= v_to and (v_from is null or j.created_at > v_from);
    insert into public.payouts (run_id, shop_id, amount_sdg, sales_sdg, deductions_sdg)
    values (v_run, a.shop_id, v_owed, v_sales, greatest(v_sales - v_owed, 0));
    v_n := v_n + 1;
    v_total := v_total + v_owed;
  end loop;

  perform public.audit('GENERATE', 'payout_run', v_run::text, jsonb_build_object('payouts', v_n, 'total', v_total));
  return jsonb_build_object('run_id', v_run, 'period_from', v_from, 'period_to', v_to, 'payouts', v_n, 'total_sdg', v_total);
end
$$;

create function public.admin_approve_payouts(p_ids uuid[])
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_admin uuid := public.require_admin();
  v_n     integer;
begin
  update public.payouts set status = 'APPROVED', approved_by = v_admin, approved_at = now()
   where id = any (p_ids) and status = 'DRAFT';
  get diagnostics v_n = row_count;
  perform public.audit('APPROVE', 'payout', array_to_string(p_ids, ','), jsonb_build_object('count', v_n));
  return v_n;
end
$$;

-- Admin sent the money by Bankak. Posts PAYOUT: Dr SHOP / Cr PLATFORM_BANKAK.
create function public.admin_mark_payout_paid(p_payout_id uuid, p_txn_no text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_admin uuid := public.require_admin();
  v_txn   text := public.clean_txn(p_txn_no);
  p       public.payouts;
begin
  if v_txn is null then raise exception 'INVALID_TXN' using errcode = '22023'; end if;
  select * into p from public.payouts where id = p_payout_id for update;
  if p.id is null then raise exception 'PAYOUT_NOT_FOUND' using errcode = 'P0002'; end if;
  if p.status <> 'APPROVED' then raise exception 'NOT_APPROVED' using errcode = 'PT409'; end if;
  begin
    update public.payouts set status = 'PAID', bankak_txn_no = v_txn, paid_by = v_admin, paid_at = now()
     where id = p.id;
  exception when unique_violation then
    raise exception 'DUPLICATE_TXN' using errcode = 'PT409';
  end;
  perform public.post_journal('PAYOUT', public.shop_account(p.shop_id), public.ledger_account('PLATFORM_BANKAK'),
                              p.amount_sdg, null, null, null, p.id);
  perform public.notify_shop(p.shop_id, 'PAYOUT_PAID', jsonb_build_object('payout_id', p.id, 'amount_sdg', p.amount_sdg,
                                                                          'txn', v_txn));
  perform public.audit('PAID', 'payout', p.id::text, jsonb_build_object('txn', v_txn, 'amount', p.amount_sdg));
end
$$;

create function public.admin_cancel_payout(p_payout_id uuid, p_reason text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.require_admin();
  if nullif(btrim(coalesce(p_reason, '')), '') is null then
    raise exception 'REASON_REQUIRED' using errcode = '22023';
  end if;
  update public.payouts set status = 'CANCELLED', cancel_reason = btrim(p_reason)
   where id = p_payout_id and status in ('DRAFT', 'APPROVED');
  if not found then raise exception 'PAYOUT_NOT_FOUND' using errcode = 'P0002'; end if;
  perform public.audit('CANCEL', 'payout', p_payout_id::text, jsonb_build_object('reason', p_reason));
end
$$;

-- For the admin Cash page: every shop with ledger activity — what it owes or is owed,
-- cash it collected since its last paid payout, any payout waiting, and how many runs in
-- a row it ended owing the platform.
create function public.admin_partner_balances()
returns setof jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform public.require_admin();
  return query
    with last_paid as (
      select p.shop_id, max(p.paid_at) as at from public.payouts p where p.status = 'PAID' group by p.shop_id
    ),
    runs as (
      select r.id, row_number() over (order by r.period_to desc) as n from public.payout_runs r
    )
    select jsonb_build_object(
      'shop_id', sh.id, 'name_ar', sh.name_ar, 'name_en', sh.name_en, 'status', sh.status,
      'balance_sdg', public.shop_balance(sh.id),
      'cash_collected_sdg', coalesce((
        select sum(e.amount_sdg) from public.ledger_entries e join public.ledger_journals j on j.id = e.journal_id
        where e.account_id = la.id and j.kind = 'CASH_COLLECTED'
          and (lp.at is null or j.created_at > lp.at)), 0),
      'open_payout_sdg', (select p.amount_sdg from public.payouts p
                          where p.shop_id = sh.id and p.status in ('DRAFT', 'APPROVED')),
      -- Runs in a row, newest first, that found the shop owing.
      'cycles_owing', coalesce(
        (select min(r2.n) - 1 from runs r2
         where not exists (select 1 from public.payout_run_balances b where b.run_id = r2.id and b.shop_id = sh.id)),
        (select count(*) from runs)))
    from public.ledger_accounts la
    join public.shops sh on sh.id = la.shop_id
    left join last_paid lp on lp.shop_id = sh.id
    order by public.shop_balance(sh.id);
end
$$;

-- A shop's statement: every ledger line on its account between two dates, with the
-- opening and closing balance (positive = the platform owes the shop).
create function public.shop_statement(p_shop_id uuid, p_from timestamptz default null, p_to timestamptz default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_acc  uuid;
  v_from timestamptz := coalesce(p_from, now() - interval '30 days');
  v_to   timestamptz := coalesce(p_to, now());
begin
  perform public.require_shop(p_shop_id);
  select a.id into v_acc from public.ledger_accounts a where a.shop_id = p_shop_id;
  return jsonb_build_object(
    'shop_id', p_shop_id, 'from', v_from, 'to', v_to,
    'opening_sdg', coalesce((select -sum(e.amount_sdg) from public.ledger_entries e
                             join public.ledger_journals j on j.id = e.journal_id
                             where e.account_id = v_acc and j.created_at < v_from), 0),
    'closing_sdg', coalesce((select -sum(e.amount_sdg) from public.ledger_entries e
                             join public.ledger_journals j on j.id = e.journal_id
                             where e.account_id = v_acc and j.created_at <= v_to), 0),
    'lines', coalesce((
      select jsonb_agg(jsonb_build_object(
               'id', j.id, 'kind', j.kind, 'amount_sdg', -e.amount_sdg, 'at', j.created_at,
               'ref', (select o.ref from public.orders o where o.id = j.order_id),
               'payout_id', j.payout_id)
             order by j.created_at, e.id)
      from public.ledger_entries e join public.ledger_journals j on j.id = e.journal_id
      where e.account_id = v_acc and j.created_at >= v_from and j.created_at <= v_to), '[]'),
    'payouts', coalesce((select jsonb_agg(jsonb_build_object('id', p.id, 'amount_sdg', p.amount_sdg, 'status', p.status,
                                                             'paid_at', p.paid_at, 'created_at', p.created_at)
                                          order by p.created_at desc)
                         from public.payouts p where p.shop_id = p_shop_id and p.status <> 'CANCELLED'), '[]'));
end
$$;

alter table public.payout_runs enable row level security;
alter table public.payouts enable row level security;
alter table public.payout_run_balances enable row level security;
revoke all on public.payout_runs, public.payouts, public.payout_run_balances from anon, authenticated;
grant select on public.payout_runs, public.payouts, public.payout_run_balances to authenticated;

create policy payout_runs_admin on public.payout_runs for select to authenticated
  using ((select public.is_admin()));
create policy payouts_read on public.payouts for select to authenticated
  using (public.is_shop_member(shop_id) or (select public.is_admin()));
create policy payout_run_balances_admin on public.payout_run_balances for select to authenticated
  using ((select public.is_admin()));

revoke all on function
  public.shop_balance(uuid), public.admin_generate_payouts(timestamptz), public.admin_approve_payouts(uuid[]),
  public.admin_mark_payout_paid(uuid, text), public.admin_cancel_payout(uuid, text),
  public.admin_partner_balances(), public.shop_statement(uuid, timestamptz, timestamptz)
from public, anon, authenticated;

grant execute on function
  public.admin_generate_payouts(timestamptz), public.admin_approve_payouts(uuid[]),
  public.admin_mark_payout_paid(uuid, text), public.admin_cancel_payout(uuid, text),
  public.admin_partner_balances(), public.shop_statement(uuid, timestamptz, timestamptz)
to authenticated;
