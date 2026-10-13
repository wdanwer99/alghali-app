-- M1 identity: profiles, roles, devices, idempotency keys, audit log, admin settings.
--
-- Error convention for every RPC (PostgREST turns the SQLSTATE into the HTTP status):
--   42501 → 401/403  NOT_AUTHENTICATED, FORBIDDEN
--   P0002 → 404      NOT_FOUND
--   PT409 → 409      VERSION_CONFLICT, ALREADY_EXISTS, ...
--   22023 → 400      validation codes (INVALID_PHONE, ...)
-- The message is always a machine code in UPPER_SNAKE_CASE; apps translate it.

create type public.app_role as enum ('BUYER', 'SHOP_OWNER', 'SHOP_STAFF', 'TECHNICIAN', 'ADMIN');
create type public.partner_status as enum ('PENDING', 'APPROVED', 'REJECTED', 'SUSPENDED');

-- ------------------------------------------------------------------ helpers
create function public.tg_set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end
$$;

-- Sudanese numbers are stored in E.164 (+2499xxxxxxxx). Accepts 09…, 9…, 2499…, +2499…,
-- spaces/dashes and Arabic-Indic digits. Returns null when the input isn't a phone number.
create function public.normalize_phone(p text)
returns text
language plpgsql
immutable
set search_path = ''
as $$
declare
  v text := translate(coalesce(p, ''), '٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹', '01234567890123456789');
begin
  v := regexp_replace(v, '[\s().-]', '', 'g');
  if v = '' then return null; end if;
  if v ~ '^00' then v := '+' || substr(v, 3); end if;
  if v ~ '^0[0-9]{9}$' then v := '+249' || substr(v, 2);
  elsif v ~ '^[1-9][0-9]{8}$' then v := '+249' || v;
  elsif v ~ '^249[0-9]{9}$' then v := '+' || v;
  end if;
  if v !~ '^\+[1-9][0-9]{7,14}$' then return null; end if;
  return v;
end
$$;

create function public.require_user()
returns uuid
language plpgsql
stable
set search_path = ''
as $$
declare
  v uuid := auth.uid();
begin
  if v is null then
    raise exception 'NOT_AUTHENTICATED' using errcode = '42501';
  end if;
  return v;
end
$$;

-- ------------------------------------------------------------------ profiles
create table public.profiles (
  id                uuid primary key references auth.users (id) on delete cascade,
  email             text,
  phone             text check (phone is null or phone ~ '^\+[1-9][0-9]{7,14}$'),
  phone_verified_at timestamptz,          -- stays null until phone OTP exists (D-030)
  display_name      text not null default '' check (char_length(display_name) <= 80),
  locale            text not null default 'ar' check (locale in ('ar', 'en')),
  data_saver        boolean not null default true,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);
comment on table public.profiles is 'One row per auth user. Changed through update_profile().';
create trigger profiles_updated_at before update on public.profiles
  for each row execute function public.tg_set_updated_at();

-- ------------------------------------------------------------------ roles
create table public.user_roles (
  user_id    uuid not null references auth.users (id) on delete cascade,
  role       public.app_role not null,
  granted_by uuid references auth.users (id) on delete set null,
  granted_at timestamptz not null default now(),
  primary key (user_id, role)
);
comment on table public.user_roles is
  'Roles per user. RLS checks this table (not JWT claims), so a revoke takes effect at once.';

create function public.has_role(p_role public.app_role)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.user_roles r where r.user_id = auth.uid() and r.role = p_role
  );
$$;

create function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.has_role('ADMIN');
$$;

create function public.require_admin()
returns uuid
language plpgsql
stable
set search_path = ''
as $$
declare
  v uuid := public.require_user();
begin
  if not public.is_admin() then
    raise exception 'FORBIDDEN' using errcode = '42501';
  end if;
  return v;
end
$$;

-- ------------------------------------------------------------------ devices
create table public.devices (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references auth.users (id) on delete cascade,
  app          text not null check (app in ('buyer', 'partner', 'admin')),
  platform     text not null check (platform in ('android', 'ios', 'web')),
  fcm_token    text not null unique check (char_length(fcm_token) between 10 and 4096),
  app_build    integer check (app_build > 0),
  locale       text check (locale in ('ar', 'en')),
  last_seen_at timestamptz not null default now(),
  created_at   timestamptz not null default now()
);
create index devices_user_idx on public.devices (user_id);

-- ------------------------------------------------------------------ idempotency
create table public.idempotency_keys (
  user_id    uuid not null references auth.users (id) on delete cascade,
  key        uuid not null,
  op         text not null,
  response   jsonb not null,
  created_at timestamptz not null default now(),
  primary key (user_id, key)
);
comment on table public.idempotency_keys is
  'Stored results of mutating RPCs, so an offline outbox can replay safely. Kept 7 days.';

-- Call at the top of a mutating RPC. Returns the stored response for a replay, else null.
-- Holds a transaction lock on the key so two concurrent replays can't both run.
create function public.idem_begin(p_idem uuid, p_op text)
returns jsonb
language plpgsql
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_row public.idempotency_keys;
begin
  if p_idem is null or v_uid is null then return null; end if;
  perform pg_advisory_xact_lock(hashtextextended(v_uid::text || ':' || p_idem::text, 0));
  select * into v_row from public.idempotency_keys k where k.user_id = v_uid and k.key = p_idem;
  if not found then return null; end if;
  if v_row.op <> p_op then
    raise exception 'IDEMPOTENCY_KEY_REUSED' using errcode = '22023';
  end if;
  return v_row.response;
end
$$;

create function public.idem_finish(p_idem uuid, p_op text, p_response jsonb)
returns jsonb
language plpgsql
set search_path = ''
as $$
begin
  if p_idem is not null and auth.uid() is not null then
    insert into public.idempotency_keys (user_id, key, op, response)
    values (auth.uid(), p_idem, p_op, p_response);
  end if;
  return p_response;
end
$$;

-- ------------------------------------------------------------------ audit
create table public.audit_log (
  id         bigint generated always as identity primary key,
  actor_id   uuid references auth.users (id) on delete set null,
  action     text not null,
  entity     text not null,
  entity_id  text,
  data       jsonb,
  created_at timestamptz not null default now()
);
create index audit_log_entity_idx on public.audit_log (entity, entity_id);

create function public.audit(p_action text, p_entity text, p_entity_id text, p_data jsonb default null)
returns void
language sql
set search_path = ''
as $$
  insert into public.audit_log (actor_id, action, entity, entity_id, data)
  values (auth.uid(), p_action, p_entity, p_entity_id, p_data);
$$;

-- ------------------------------------------------------------------ new users
-- Sign-up metadata (supabase.auth.signUp options.data): display_name, phone, locale.
create function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, email, display_name, phone, locale)
  values (
    new.id,
    new.email,
    left(btrim(coalesce(new.raw_user_meta_data ->> 'display_name', '')), 80),
    public.normalize_phone(new.raw_user_meta_data ->> 'phone'),
    case when new.raw_user_meta_data ->> 'locale' = 'en' then 'en' else 'ar' end
  );
  insert into public.user_roles (user_id, role) values (new.id, 'BUYER');
  return new;
end
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

create function public.handle_user_email_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.profiles set email = new.email where id = new.id;
  return new;
end
$$;

create trigger on_auth_user_email_changed
  after update of email on auth.users
  for each row when (old.email is distinct from new.email)
  execute function public.handle_user_email_change();

-- ------------------------------------------------------------------ RPCs: self
-- Null arguments leave a field unchanged; an empty phone clears it.
create function public.update_profile(
  p_display_name text default null,
  p_phone        text default null,
  p_locale       text default null,
  p_data_saver   boolean default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid   uuid := public.require_user();
  v_phone text;
  v_row   public.profiles;
begin
  if p_display_name is not null and char_length(btrim(p_display_name)) > 80 then
    raise exception 'NAME_TOO_LONG' using errcode = '22023';
  end if;
  if p_locale is not null and p_locale not in ('ar', 'en') then
    raise exception 'INVALID_LOCALE' using errcode = '22023';
  end if;
  if p_phone is not null and btrim(p_phone) <> '' then
    v_phone := public.normalize_phone(p_phone);
    if v_phone is null then
      raise exception 'INVALID_PHONE' using errcode = '22023';
    end if;
  end if;

  update public.profiles p set
    display_name      = coalesce(btrim(p_display_name), p.display_name),
    phone             = case when p_phone is null then p.phone else v_phone end,
    phone_verified_at = case when p_phone is null or v_phone = p.phone then p.phone_verified_at end,
    locale            = coalesce(p_locale, p.locale),
    data_saver        = coalesce(p_data_saver, p.data_saver)
  where p.id = v_uid
  returning * into v_row;

  return to_jsonb(v_row);
end
$$;

-- Upserts by FCM token: a phone that signs in to another account moves to that account.
create function public.register_device(
  p_app       text,
  p_platform  text,
  p_fcm_token text,
  p_app_build integer default null,
  p_locale    text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := public.require_user();
  v_row public.devices;
begin
  insert into public.devices as d (user_id, app, platform, fcm_token, app_build, locale)
  values (v_uid, p_app, p_platform, p_fcm_token, p_app_build, p_locale)
  on conflict (fcm_token) do update set
    user_id      = excluded.user_id,
    app          = excluded.app,
    platform     = excluded.platform,
    app_build    = excluded.app_build,
    locale       = excluded.locale,
    last_seen_at = now()
  returning * into v_row;
  return jsonb_build_object('id', v_row.id);
exception
  when check_violation then
    raise exception 'INVALID_DEVICE' using errcode = '22023';
end
$$;

-- Called on sign-out so the old account stops getting this phone's notifications.
create function public.unregister_device(p_fcm_token text)
returns void
language sql
security definer
set search_path = ''
as $$
  delete from public.devices where fcm_token = p_fcm_token and user_id = public.require_user();
$$;

-- ------------------------------------------------------------------ RPCs: admin
create function public.admin_grant_role(p_user_id uuid, p_role public.app_role)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_admin uuid := public.require_admin();
begin
  if not exists (select 1 from auth.users u where u.id = p_user_id) then
    raise exception 'USER_NOT_FOUND' using errcode = 'P0002';
  end if;
  insert into public.user_roles (user_id, role, granted_by)
  values (p_user_id, p_role, v_admin)
  on conflict do nothing;
  perform public.audit('GRANT_ROLE', 'user', p_user_id::text, jsonb_build_object('role', p_role));
end
$$;

create function public.admin_revoke_role(p_user_id uuid, p_role public.app_role)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_admin uuid := public.require_admin();
begin
  if p_role = 'ADMIN' and p_user_id = v_admin then
    raise exception 'CANNOT_REVOKE_OWN_ADMIN' using errcode = '22023';
  end if;
  if p_role = 'BUYER' then
    raise exception 'CANNOT_REVOKE_BUYER' using errcode = '22023';
  end if;
  delete from public.user_roles where user_id = p_user_id and role = p_role;
  perform public.audit('REVOKE_ROLE', 'user', p_user_id::text, jsonb_build_object('role', p_role));
end
$$;

-- Finds users by email, name or phone for the admin console.
create function public.admin_search_users(p_q text, p_limit integer default 20)
returns table (
  id           uuid,
  email        text,
  display_name text,
  phone        text,
  roles        public.app_role[],
  created_at   timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_q text := btrim(coalesce(p_q, ''));
begin
  perform public.require_admin();
  return query
    select p.id, p.email, p.display_name, p.phone,
           array(select r.role from public.user_roles r where r.user_id = p.id order by r.role),
           p.created_at
    from public.profiles p
    where v_q = ''
       or p.email ilike '%' || v_q || '%'
       or p.display_name ilike '%' || v_q || '%'
       or p.phone = public.normalize_phone(v_q)
    order by p.created_at desc
    limit least(greatest(coalesce(p_limit, 20), 1), 100);
end
$$;

-- ------------------------------------------------------------------ settings (admin)
insert into public.app_settings (key, value, is_public, description) values
  ('latest_app_versions',
     '{"buyer":{"latest_build":1,"min_build":1,"apk_url":null},"partner":{"latest_build":1,"min_build":1,"apk_url":null}}',
                                         true,  'Newest and minimum Android builds and where to download them (D-058)'),
  ('support_phone',             '""',   true,  'Support number shown in the apps; also for password help (D-064)'),
  ('support_whatsapp',          '""',   true,  'Support WhatsApp number shown in the apps')
on conflict (key) do nothing;

-- Checks a setting's shape before an admin saves it.
create function public.validate_setting(p_key text, p_value jsonb)
returns boolean
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_band jsonb;
  v_prev integer := 0;
  v_app  text;
begin
  case
    when p_key = 'commission_percent' then
      return jsonb_typeof(p_value) = 'number' and (p_value #>> '{}')::numeric between 0 and 50;
    when p_key ~ '(_sdg|_minutes|_hours|_days)$' then
      return jsonb_typeof(p_value) = 'number'
         and (p_value #>> '{}')::numeric = trunc((p_value #>> '{}')::numeric)
         and (p_value #>> '{}')::numeric between 0 and 100000000;
    when p_key in ('travel_fee_bands', 'delivery_fee_bands') then
      if jsonb_typeof(p_value) <> 'array' or jsonb_array_length(p_value) = 0 then return false; end if;
      for v_band in select * from jsonb_array_elements(p_value) loop
        if jsonb_typeof(v_band -> 'max_km') <> 'number' or jsonb_typeof(v_band -> 'sdg') <> 'number'
           or (v_band ->> 'max_km')::numeric <= v_prev or (v_band ->> 'sdg')::numeric < 0
           or (v_band ->> 'sdg')::numeric <> trunc((v_band ->> 'sdg')::numeric) then
          return false;
        end if;
        v_prev := (v_band ->> 'max_km')::numeric;
      end loop;
      return true;
    when p_key in ('bankak_account_name', 'bankak_account_number', 'support_phone', 'support_whatsapp') then
      return jsonb_typeof(p_value) = 'string' and char_length(p_value #>> '{}') <= 100;
    when p_key = 'payout_schedule' then
      return jsonb_typeof(p_value) = 'object'
         and p_value ->> 'frequency' in ('weekly', 'biweekly', 'monthly')
         and jsonb_typeof(p_value -> 'weekday') = 'number'
         and (p_value ->> 'weekday')::numeric between 0 and 6;
    when p_key = 'labour_price_bounds' then
      return jsonb_typeof(p_value) = 'object';
    when p_key = 'latest_app_versions' then
      if jsonb_typeof(p_value) <> 'object' then return false; end if;
      foreach v_app in array array['buyer', 'partner'] loop
        if jsonb_typeof(p_value -> v_app -> 'latest_build') <> 'number'
           or jsonb_typeof(p_value -> v_app -> 'min_build') <> 'number'
           or (p_value -> v_app ->> 'min_build')::numeric > (p_value -> v_app ->> 'latest_build')::numeric
           or jsonb_typeof(p_value -> v_app -> 'apk_url') not in ('string', 'null') then
          return false;
        end if;
      end loop;
      return true;
    else
      return false;
  end case;
end
$$;

create function public.admin_settings()
returns setof public.app_settings
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform public.require_admin();
  return query select s.* from public.app_settings s order by s.key;
end
$$;

create function public.admin_update_setting(p_key text, p_value jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_admin uuid := public.require_admin();
  v_old   jsonb;
  v_row   public.app_settings;
begin
  select value into v_old from public.app_settings where key = p_key for update;
  if not found then
    raise exception 'UNKNOWN_SETTING' using errcode = 'P0002';
  end if;
  if not public.validate_setting(p_key, p_value) then
    raise exception 'INVALID_SETTING' using errcode = '22023';
  end if;
  update public.app_settings
     set value = p_value, updated_by = v_admin, updated_at = now()
   where key = p_key
  returning * into v_row;
  perform public.audit('UPDATE_SETTING', 'setting', p_key, jsonb_build_object('old', v_old, 'new', p_value));
  return to_jsonb(v_row);
end
$$;

-- ------------------------------------------------------------------ RLS + grants
alter table public.profiles enable row level security;
alter table public.user_roles enable row level security;
alter table public.devices enable row level security;
alter table public.idempotency_keys enable row level security;
alter table public.audit_log enable row level security;

revoke all on public.profiles, public.user_roles, public.devices, public.idempotency_keys,
              public.audit_log from anon, authenticated;
grant select on public.profiles, public.user_roles, public.devices, public.audit_log to authenticated;

create policy profiles_select on public.profiles for select to authenticated
  using (id = (select auth.uid()) or (select public.is_admin()));
create policy user_roles_select on public.user_roles for select to authenticated
  using (user_id = (select auth.uid()) or (select public.is_admin()));
create policy devices_select on public.devices for select to authenticated
  using (user_id = (select auth.uid()));
create policy audit_log_select on public.audit_log for select to authenticated
  using ((select public.is_admin()));

-- Functions: nothing is callable by default; grant what clients need.
revoke all on function
  public.tg_set_updated_at(), public.normalize_phone(text), public.require_user(),
  public.has_role(public.app_role), public.is_admin(), public.require_admin(),
  public.idem_begin(uuid, text), public.idem_finish(uuid, text, jsonb),
  public.audit(text, text, text, jsonb), public.handle_new_user(), public.handle_user_email_change(),
  public.update_profile(text, text, text, boolean),
  public.register_device(text, text, text, integer, text), public.unregister_device(text),
  public.admin_grant_role(uuid, public.app_role), public.admin_revoke_role(uuid, public.app_role),
  public.admin_search_users(text, integer), public.validate_setting(text, jsonb),
  public.admin_settings(), public.admin_update_setting(text, jsonb)
from public, anon, authenticated;

-- Used inside RLS policies, so callers need EXECUTE.
grant execute on function public.has_role(public.app_role), public.is_admin() to anon, authenticated;
grant execute on function
  public.update_profile(text, text, text, boolean),
  public.register_device(text, text, text, integer, text), public.unregister_device(text),
  public.admin_grant_role(uuid, public.app_role), public.admin_revoke_role(uuid, public.app_role),
  public.admin_search_users(text, integer), public.admin_settings(),
  public.admin_update_setting(text, jsonb)
to authenticated;

-- ------------------------------------------------------------------ housekeeping
select cron.schedule(
  'idempotency-keys-cleanup',
  '17 3 * * *',
  $$delete from public.idempotency_keys where created_at < now() - interval '7 days'$$
);
