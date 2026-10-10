-- M0 foundation: extensions, admin-editable settings, health check.
-- Conventions for every later migration (see docs/PLAN.md §3):
--   * RLS enabled on every table (a test fails otherwise).
--   * Functions: explicit `set search_path = ''`, EXECUTE revoked from public, granted per role.
--   * Money is bigint SDG; times are timestamptz (UTC).

-- ---------------------------------------------------------------- extensions
create extension if not exists postgis with schema extensions;     -- shop pins, distance bands
create extension if not exists btree_gist with schema extensions;  -- booking EXCLUDE constraint
create extension if not exists pg_trgm with schema extensions;     -- fuzzy Arabic search
create extension if not exists pg_net with schema extensions;      -- cron → Edge Functions
create extension if not exists pg_cron;                            -- timeouts, reminders, expiry
create extension if not exists pgmq;                               -- notification queue

-- ---------------------------------------------------------------- settings
create table public.app_settings (
  key         text primary key check (key ~ '^[a-z][a-z0-9_]*$'),
  value       jsonb not null,
  description text,
  is_public   boolean not null default false,  -- readable by apps via public_settings()
  updated_by  uuid references auth.users (id) on delete set null,
  updated_at  timestamptz not null default now()
);

comment on table public.app_settings is
  'Admin-editable configuration (brief §5). Read through public_settings() or server-side only.';

alter table public.app_settings enable row level security;
-- No policies yet: clients read the public subset through public_settings().
-- Admin read/write policies arrive with roles in M1.
revoke all on public.app_settings from anon, authenticated;

-- Defaults. SDG amounts are placeholders — TODO: confirm with real market prices before launch.
insert into public.app_settings (key, value, is_public, description) values
  ('commission_percent',          '5',     false, 'Platform commission on part sales, percent (maths in basis points)'),
  ('booking_fee_sdg',             '2000',  true,  'Platform fee per installation booking'),
  ('mobile_deposit_sdg',          '5000',  true,  'Bankak deposit for cash-paid mobile bookings; 0 disables'),
  ('slot_hold_minutes',           '10',    true,  'How long a chosen slot is held during checkout'),
  ('tech_accept_timeout_minutes', '20',    false, 'Technician must accept an offer within this time'),
  ('cancel_cutoff_hours',         '6',     true,  'Free cancellation until this many hours before start'),
  ('part_ready_buffer_minutes',   '120',   false, 'Earliest booking start after checkout'),
  ('travel_fee_bands',
     '[{"max_km":3,"sdg":3000},{"max_km":8,"sdg":6000},{"max_km":15,"sdg":10000}]',
                                           true,  'Travel fee by straight-line km from the street; beyond the last band is not served'),
  ('delivery_fee_bands',
     '[{"max_km":3,"sdg":2000},{"max_km":8,"sdg":4000},{"max_km":15,"sdg":7000}]',
                                           true,  'Delivery fee by km from the shop'),
  ('bankak_account_name',         '"TODO: platform account name"',   true, 'Shown to buyers on Bankak checkout'),
  ('bankak_account_number',       '"TODO: platform account number"', true, 'Shown to buyers on Bankak checkout'),
  ('payout_schedule',             '{"frequency":"weekly","weekday":0}', false, 'Partner payouts; weekday 0 = Sunday'),
  ('payment_window_minutes',      '120',   true,  'Unpaid Bankak orders auto-cancel after this'),
  ('return_window_days',          '3',     true,  'Days after hand-over that a return can be requested'),
  ('travel_buffer_minutes',       '30',    false, 'Gap kept around mobile jobs for travel'),
  ('booking_lookahead_days',      '7',     true,  'How far ahead technician availability is shown'),
  ('auto_complete_days',          '3',     false, 'Picked-up/delivered sub-orders complete after this if the buyer is silent'),
  ('labour_price_bounds',         '{}',    false, 'Optional min/max labour SDG per job type code')
on conflict (key) do nothing;

-- ---------------------------------------------------------------- functions
create or replace function public.ping()
returns jsonb
language sql
stable
set search_path = ''
as $$
  select jsonb_build_object('ok', true, 'server_time', now());
$$;

comment on function public.ping() is 'Health check used by the apps and admin.';
revoke all on function public.ping() from public;
grant execute on function public.ping() to anon, authenticated;

create or replace function public.public_settings()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(jsonb_object_agg(s.key, s.value), '{}'::jsonb)
  from public.app_settings s
  where s.is_public;
$$;

comment on function public.public_settings() is 'Settings that apps may show (fees, Bankak account, windows).';
revoke all on function public.public_settings() from public;
grant execute on function public.public_settings() to anon, authenticated;
