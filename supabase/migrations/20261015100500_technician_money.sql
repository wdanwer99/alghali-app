-- M3 technicians' money: payouts and statements work for technicians as they do for
-- shops (D-089). A technician's credit balance is labour and travel fees earned; a debit
-- balance is booking fees on cash jobs they kept (D-013), netted from later payouts.

alter table public.payouts
  add constraint payouts_technician_fk foreign key (technician_id) references public.technicians (id) on delete set null,
  add constraint payouts_one_party check (num_nonnulls(shop_id, technician_id) <= 1);
create unique index payouts_one_open_tech on public.payouts (technician_id) where status in ('DRAFT', 'APPROVED');

-- Technicians that owed the platform at each run (D-018).
create table public.payout_run_tech_balances (
  run_id        uuid not null references public.payout_runs (id) on delete cascade,
  technician_id uuid not null references public.technicians (id) on delete cascade,
  balance_sdg   bigint not null check (balance_sdg > 0),
  primary key (run_id, technician_id)
);

create function public.tech_balance(p_technician_id uuid)
returns bigint
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(-sum(e.amount_sdg), 0)::bigint
  from public.ledger_entries e join public.ledger_accounts a on a.id = e.account_id
  where a.technician_id = p_technician_id;
$$;

-- admin_generate_payouts() from M2, for technicians too. "Sales" for a technician are
-- the labour and travel fees credited in the period.
create or replace function public.admin_generate_payouts(p_period_to timestamptz default now())
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
    select la.id as account_id, la.shop_id, la.technician_id,
           coalesce(-sum(e.amount_sdg) filter (where j.created_at <= v_to), 0)::bigint as owed
    from public.ledger_accounts la
    join public.ledger_entries e on e.account_id = la.id
    join public.ledger_journals j on j.id = e.journal_id
    where la.shop_id is not null or la.technician_id is not null
    group by la.id, la.shop_id, la.technician_id
  loop
    if a.owed < 0 then
      if a.shop_id is not null then
        insert into public.payout_run_balances (run_id, shop_id, balance_sdg) values (v_run, a.shop_id, -a.owed);
      else
        insert into public.payout_run_tech_balances (run_id, technician_id, balance_sdg) values (v_run, a.technician_id, -a.owed);
      end if;
      continue;
    end if;
    if exists (select 1 from public.payouts p where p.status in ('DRAFT', 'APPROVED')
               and (p.shop_id = a.shop_id or p.technician_id = a.technician_id)) then
      continue;
    end if;
    v_owed := a.owed;
    if v_owed <= 0 then continue; end if;
    select coalesce(-sum(e.amount_sdg), 0) into v_sales
    from public.ledger_entries e join public.ledger_journals j on j.id = e.journal_id
    where e.account_id = a.account_id and j.kind in ('SALE', 'LABOUR', 'TRAVEL_FEE')
      and j.created_at <= v_to and (v_from is null or j.created_at > v_from);
    insert into public.payouts (run_id, shop_id, technician_id, amount_sdg, sales_sdg, deductions_sdg)
    values (v_run, a.shop_id, a.technician_id, v_owed, v_sales, greatest(v_sales - v_owed, 0));
    v_n := v_n + 1;
    v_total := v_total + v_owed;
  end loop;

  perform public.audit('GENERATE', 'payout_run', v_run::text, jsonb_build_object('payouts', v_n, 'total', v_total));
  return jsonb_build_object('run_id', v_run, 'period_from', v_from, 'period_to', v_to, 'payouts', v_n, 'total_sdg', v_total);
end
$$;

-- admin_mark_payout_paid() from M2, for technicians too.
create or replace function public.admin_mark_payout_paid(p_payout_id uuid, p_txn_no text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_admin uuid := public.require_admin();
  v_txn   text := public.clean_txn(p_txn_no);
  p       public.payouts;
  v_info  jsonb;
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
  v_info := jsonb_build_object('payout_id', p.id, 'amount_sdg', p.amount_sdg, 'txn', v_txn);
  if p.shop_id is not null then
    perform public.post_journal('PAYOUT', public.shop_account(p.shop_id), public.ledger_account('PLATFORM_BANKAK'),
                                p.amount_sdg, null, null, null, p.id);
    perform public.notify_shop(p.shop_id, 'PAYOUT_PAID', v_info);
  else
    perform public.post_journal('PAYOUT', public.tech_account(p.technician_id), public.ledger_account('PLATFORM_BANKAK'),
                                p.amount_sdg, null, null, null, p.id);
    perform public.notify_partner((select t.user_id from public.technicians t where t.id = p.technician_id), 'PAYOUT_PAID', v_info);
  end if;
  perform public.audit('PAID', 'payout', p.id::text, jsonb_build_object('txn', v_txn, 'amount', p.amount_sdg));
end
$$;

-- admin_partner_balances() from M2, with technicians: every party with ledger activity.
-- Rows have `party` = SHOP (shop_id) or TECH (technician_id).
create or replace function public.admin_partner_balances()
returns setof jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform public.require_admin();
  return query
    with runs as (
      select r.id, row_number() over (order by r.period_to desc) as n from public.payout_runs r
    ),
    parties as (
      select la.id as account_id, la.shop_id, la.technician_id,
             coalesce(-(select sum(e.amount_sdg) from public.ledger_entries e where e.account_id = la.id), 0)::bigint as balance,
             (select max(p.paid_at) from public.payouts p where p.status = 'PAID'
                and (p.shop_id = la.shop_id or p.technician_id = la.technician_id)) as last_paid
      from public.ledger_accounts la
      where la.shop_id is not null or la.technician_id is not null
    )
    select jsonb_build_object(
      'party', case when pa.shop_id is not null then 'SHOP' else 'TECH' end,
      'shop_id', pa.shop_id, 'technician_id', pa.technician_id,
      'name_ar', coalesce(sh.name_ar, tp.display_name), 'name_en', coalesce(nullif(sh.name_en, ''), sh.name_ar, tp.display_name),
      'status', coalesce(sh.status, t.status),
      'balance_sdg', pa.balance,
      'cash_collected_sdg', coalesce((
        select sum(e.amount_sdg) from public.ledger_entries e join public.ledger_journals j on j.id = e.journal_id
        where e.account_id = pa.account_id and j.kind = 'CASH_COLLECTED'
          and (pa.last_paid is null or j.created_at > pa.last_paid)), 0),
      'open_payout_sdg', (select p.amount_sdg from public.payouts p
                          where p.status in ('DRAFT', 'APPROVED')
                            and (p.shop_id = pa.shop_id or p.technician_id = pa.technician_id)),
      'cycles_owing', coalesce(
        (select min(r2.n) - 1 from runs r2
         where not exists (select 1 from public.payout_run_balances b where b.run_id = r2.id and b.shop_id = pa.shop_id)
           and not exists (select 1 from public.payout_run_tech_balances b where b.run_id = r2.id
                           and b.technician_id = pa.technician_id)),
        (select count(*) from runs)))
    from parties pa
    left join public.shops sh on sh.id = pa.shop_id
    left join public.technicians t on t.id = pa.technician_id
    left join public.profiles tp on tp.id = t.user_id
    order by pa.balance;
end
$$;

-- The technician's statement: ledger lines on their account between two dates, with
-- opening and closing balances (positive = the platform owes them). `ref` is the booking's.
create function public.tech_statement(p_from timestamptz default null, p_to timestamptz default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_tech uuid := public.require_technician();
  v_acc  uuid;
  v_from timestamptz := coalesce(p_from, now() - interval '30 days');
  v_to   timestamptz := coalesce(p_to, now());
begin
  select a.id into v_acc from public.ledger_accounts a where a.technician_id = v_tech;
  return jsonb_build_object(
    'technician_id', v_tech, 'from', v_from, 'to', v_to,
    'opening_sdg', coalesce((select -sum(e.amount_sdg) from public.ledger_entries e
                             join public.ledger_journals j on j.id = e.journal_id
                             where e.account_id = v_acc and j.created_at < v_from), 0),
    'closing_sdg', coalesce((select -sum(e.amount_sdg) from public.ledger_entries e
                             join public.ledger_journals j on j.id = e.journal_id
                             where e.account_id = v_acc and j.created_at <= v_to), 0),
    'lines', coalesce((
      select jsonb_agg(jsonb_build_object(
               'id', j.id, 'kind', j.kind, 'amount_sdg', -e.amount_sdg, 'at', j.created_at,
               'ref', coalesce((select b.ref from public.bookings b where b.id = j.booking_id),
                               (select o.ref from public.orders o where o.id = j.order_id)),
               'payout_id', j.payout_id)
             order by j.created_at, e.id)
      from public.ledger_entries e join public.ledger_journals j on j.id = e.journal_id
      where e.account_id = v_acc and j.created_at >= v_from and j.created_at <= v_to), '[]'),
    'payouts', coalesce((select jsonb_agg(jsonb_build_object('id', p.id, 'amount_sdg', p.amount_sdg, 'status', p.status,
                                                             'paid_at', p.paid_at, 'created_at', p.created_at)
                                          order by p.created_at desc)
                         from public.payouts p where p.technician_id = v_tech and p.status <> 'CANCELLED'), '[]'));
end
$$;

drop policy payouts_read on public.payouts;
create policy payouts_read on public.payouts for select to authenticated
  using (public.is_shop_member(shop_id) or technician_id = (select public.my_technician_id()) or (select public.is_admin()));

alter table public.payout_run_tech_balances enable row level security;
revoke all on public.payout_run_tech_balances from anon, authenticated;
grant select on public.payout_run_tech_balances to authenticated;
create policy payout_run_tech_balances_admin on public.payout_run_tech_balances for select to authenticated
  using ((select public.is_admin()));

revoke all on function public.tech_balance(uuid), public.tech_statement(timestamptz, timestamptz)
from public, anon, authenticated;
grant execute on function public.tech_statement(timestamptz, timestamptz) to authenticated;
