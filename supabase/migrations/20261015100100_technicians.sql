-- M3 technicians: who fits parts, for which jobs and car makes, at what labour price
-- (D-010), where (a workshop bay on the street, the buyer's location within a radius,
-- or both), and when (weekly hours and time off). Applying and admin review mirror
-- shops: a technician starts PENDING and an admin approves them.

create type public.work_mode as enum ('BAY', 'MOBILE', 'BOTH');

create table public.technicians (
  id               uuid primary key default gen_random_uuid(),
  user_id          uuid not null unique references auth.users (id) on delete cascade,
  status           public.partner_status not null default 'PENDING',
  status_reason    text check (char_length(status_reason) <= 500),
  verified         boolean not null default false,
  work_mode        public.work_mode not null,
  -- The workshop bay on the street where they work (BAY and BOTH).
  home_bay_shop_id uuid references public.shops (id),
  -- Where mobile jobs are measured from (MOBILE and BOTH), with the radius they cover.
  home_lat         double precision check (home_lat between -90 and 90),
  home_lng         double precision check (home_lng between -180 and 180),
  home_point       extensions.geography(Point, 4326) generated always as (
                     case when home_lat is not null and home_lng is not null then
                       extensions.st_setsrid(extensions.st_makepoint(home_lng, home_lat), 4326)::extensions.geography
                     end) stored,
  radius_km        integer not null default 10 check (radius_km between 1 and 50),
  employer_shop_id uuid references public.shops (id),
  years_experience integer not null default 0 check (years_experience between 0 and 60),
  bio_ar           text check (char_length(bio_ar) <= 500),
  bio_en           text check (char_length(bio_en) <= 500),
  avatar_key       text check (char_length(avatar_key) <= 300),
  rating_avg       numeric(3, 2) not null default 0,
  rating_count     integer not null default 0,
  completed_jobs   integer not null default 0,
  approved_at      timestamptz,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  check (work_mode = 'MOBILE' or home_bay_shop_id is not null),
  check (work_mode = 'BAY' or (home_lat is not null and home_lng is not null))
);
create index technicians_status_idx on public.technicians (status);
create trigger technicians_updated_at before update on public.technicians
  for each row execute function public.tg_set_updated_at();

-- Job types they do, each with their own labour price (D-010).
create table public.technician_job_types (
  technician_id uuid not null references public.technicians (id) on delete cascade,
  job_type_id   uuid not null references public.job_types (id),
  labour_sdg    bigint not null check (labour_sdg between 1 and 100000000),
  primary key (technician_id, job_type_id)
);

-- Car makes they work on; none = every make.
create table public.technician_makes (
  technician_id uuid not null references public.technicians (id) on delete cascade,
  make_id       uuid not null references public.vehicle_makes (id),
  primary key (technician_id, make_id)
);

-- Weekly hours in Khartoum wall-clock time: weekday 0 = Sunday, [start_min, end_min).
-- `modes` says which jobs a window is for (a BOTH technician may keep mornings for the bay).
create table public.availability_rules (
  id            uuid primary key default gen_random_uuid(),
  technician_id uuid not null references public.technicians (id) on delete cascade,
  weekday       smallint not null check (weekday between 0 and 6),
  start_min     integer not null check (start_min between 0 and 1439),
  end_min       integer not null check (end_min between 1 and 1440),
  modes         public.work_mode not null default 'BOTH',
  created_at    timestamptz not null default now(),
  check (end_min > start_min)
);
create index availability_rules_tech_idx on public.availability_rules (technician_id, weekday);

create table public.time_off (
  id            uuid primary key default gen_random_uuid(),
  technician_id uuid not null references public.technicians (id) on delete cascade,
  period        tstzrange not null check (not isempty(period) and not lower_inf(period) and not upper_inf(period)),
  reason        text check (char_length(reason) <= 200),
  created_at    timestamptz not null default now()
);
create index time_off_tech_idx on public.time_off using gist (technician_id, period);

-- ------------------------------------------------------------------ helpers
-- The caller's technician id (any status), or null.
create function public.my_technician_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select t.id from public.technicians t where t.user_id = auth.uid();
$$;

-- The caller's technician id. p_approved: only an approved technician may take jobs;
-- a pending or suspended one may still edit their profile and hours.
create function public.require_technician(p_approved boolean default false)
returns uuid
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  t public.technicians;
begin
  perform public.require_user();
  select * into t from public.technicians where user_id = auth.uid();
  if t.id is null then raise exception 'NOT_A_TECHNICIAN' using errcode = '42501'; end if;
  if p_approved and t.status <> 'APPROVED' then
    raise exception 'TECHNICIAN_NOT_ACTIVE' using errcode = '42501';
  end if;
  if not p_approved and t.status = 'REJECTED' then
    raise exception 'TECHNICIAN_NOT_ACTIVE' using errcode = '42501';
  end if;
  return t.id;
end
$$;

-- A technician's ledger account (D-013): credit = the platform owes them.
create function public.tech_account(p_technician_id uuid)
returns uuid
language plpgsql
set search_path = ''
as $$
declare
  v_id uuid;
begin
  select a.id into v_id from public.ledger_accounts a where a.technician_id = p_technician_id;
  if v_id is null then
    insert into public.ledger_accounts (code, kind, technician_id)
    values ('TECH:' || p_technician_id, 'PARTY', p_technician_id)
    on conflict (technician_id) do nothing
    returning id into v_id;
    if v_id is null then
      select a.id into v_id from public.ledger_accounts a where a.technician_id = p_technician_id;
    end if;
  end if;
  return v_id;
end
$$;

alter table public.ledger_accounts
  add constraint ledger_accounts_technician_fk foreign key (technician_id) references public.technicians (id) on delete set null;

-- Labour within the admin's optional bounds: labour_price_bounds = {"LIGHTING": {"min": 3000, "max": 20000}, …}.
create function public.labour_in_bounds(p_job_type_id uuid, p_labour bigint)
returns boolean
language sql
stable
set search_path = ''
as $$
  select coalesce((b ->> 'min')::bigint, 1) <= p_labour and p_labour <= coalesce((b ->> 'max')::bigint, 100000000)
  from (select public.setting('labour_price_bounds') -> jt.code as b
        from public.job_types jt where jt.id = p_job_type_id) x;
$$;

-- Replaces the technician's job types: p_items = [{job_type_id, labour_sdg}].
create function public.set_technician_job_types(p_technician_id uuid, p_items jsonb)
returns void
language plpgsql
set search_path = ''
as $$
declare
  v_item jsonb;
begin
  if jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'JOB_TYPES_REQUIRED' using errcode = '22023';
  end if;
  delete from public.technician_job_types where technician_id = p_technician_id;
  for v_item in select * from jsonb_array_elements(p_items) loop
    if not exists (select 1 from public.job_types j where j.id = (v_item ->> 'job_type_id')::uuid) then
      raise exception 'JOB_TYPE_NOT_FOUND' using errcode = 'P0002';
    end if;
    if not coalesce(public.labour_in_bounds((v_item ->> 'job_type_id')::uuid, (v_item ->> 'labour_sdg')::bigint), false) then
      raise exception 'LABOUR_OUT_OF_BOUNDS' using errcode = '22023',
        detail = jsonb_build_object('job_type_id', v_item ->> 'job_type_id')::text;
    end if;
    insert into public.technician_job_types (technician_id, job_type_id, labour_sdg)
    values (p_technician_id, (v_item ->> 'job_type_id')::uuid, (v_item ->> 'labour_sdg')::bigint)
    on conflict (technician_id, job_type_id) do update set labour_sdg = excluded.labour_sdg;
  end loop;
exception
  when invalid_text_representation or numeric_value_out_of_range or not_null_violation or check_violation then
    raise exception 'INVALID_JOB_TYPES' using errcode = '22023';
end
$$;

create function public.set_technician_makes(p_technician_id uuid, p_make_ids uuid[])
returns void
language plpgsql
set search_path = ''
as $$
begin
  delete from public.technician_makes where technician_id = p_technician_id;
  insert into public.technician_makes (technician_id, make_id)
  select p_technician_id, m from unnest(coalesce(p_make_ids, '{}')) m
  on conflict do nothing;
exception
  when foreign_key_violation then
    raise exception 'MAKE_NOT_FOUND' using errcode = 'P0002';
end
$$;

-- Everything the technician (or an admin) sees about one technician.
create function public.technician_json(p_technician_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select to_jsonb(t) - 'home_point'
    || jsonb_build_object(
         'name', p.display_name, 'email', p.email, 'phone', p.phone,
         'job_types', coalesce((select jsonb_agg(jsonb_build_object(
                                  'job_type_id', j.id, 'code', j.code, 'name_ar', j.name_ar, 'name_en', j.name_en,
                                  'labour_sdg', tj.labour_sdg) order by j.sort)
                                from public.technician_job_types tj join public.job_types j on j.id = tj.job_type_id
                                where tj.technician_id = t.id), '[]'),
         'make_ids', coalesce((select jsonb_agg(m.make_id) from public.technician_makes m
                               where m.technician_id = t.id), '[]'),
         'home_bay', (select jsonb_build_object('id', s.id, 'name_ar', s.name_ar, 'name_en', s.name_en,
                                                'plot_no', s.plot_no, 'zone_id', s.zone_id)
                      from public.shops s where s.id = t.home_bay_shop_id),
         'rules', coalesce((select jsonb_agg(jsonb_build_object('id', r.id, 'weekday', r.weekday,
                                  'start_min', r.start_min, 'end_min', r.end_min, 'modes', r.modes)
                                  order by r.weekday, r.start_min)
                            from public.availability_rules r where r.technician_id = t.id), '[]'),
         'time_off', coalesce((select jsonb_agg(jsonb_build_object('id', o.id, 'from', lower(o.period),
                                  'to', upper(o.period), 'reason', o.reason) order by lower(o.period))
                               from public.time_off o where o.technician_id = t.id and upper(o.period) > now()), '[]'))
  from public.technicians t join public.profiles p on p.id = t.user_id
  where t.id = p_technician_id;
$$;

create function public.check_technician_places(p_mode public.work_mode, p_bay uuid)
returns void
language plpgsql
stable
set search_path = ''
as $$
begin
  if p_mode in ('BAY', 'BOTH') and not exists (select 1 from public.shops s where s.id = p_bay and s.status = 'APPROVED') then
    raise exception 'BAY_REQUIRED' using errcode = '22023';
  end if;
end
$$;

-- ------------------------------------------------------------------ RPCs: technician
-- p_job_types = [{job_type_id, labour_sdg}]. The phone goes on the profile (buyers call it).
create function public.apply_as_technician(
  p_work_mode        public.work_mode,
  p_job_types        jsonb,
  p_phone            text,
  p_make_ids         uuid[] default '{}',
  p_home_bay_shop_id uuid default null,
  p_home_lat         double precision default null,
  p_home_lng         double precision default null,
  p_radius_km        integer default 10,
  p_years_experience integer default 0,
  p_bio_ar           text default null,
  p_employer_shop_id uuid default null,
  p_idem             uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid   uuid := public.require_user();
  v_prev  jsonb := public.idem_begin(p_idem, 'apply_as_technician');
  v_phone text := public.normalize_phone(p_phone);
  v_id    uuid;
begin
  if v_prev is not null then return v_prev; end if;
  if v_phone is null then raise exception 'INVALID_PHONE' using errcode = '22023'; end if;
  if exists (select 1 from public.technicians t where t.user_id = v_uid) then
    raise exception 'ALREADY_APPLIED' using errcode = 'PT409';
  end if;
  if p_work_mode is null then raise exception 'INVALID_WORK_MODE' using errcode = '22023'; end if;
  perform public.check_technician_places(p_work_mode, p_home_bay_shop_id);
  if p_work_mode in ('MOBILE', 'BOTH') and (p_home_lat is null or p_home_lng is null) then
    raise exception 'HOME_POINT_REQUIRED' using errcode = '22023';
  end if;

  update public.profiles set phone = v_phone where id = v_uid;
  insert into public.technicians (user_id, work_mode, home_bay_shop_id, home_lat, home_lng, radius_km,
                                  employer_shop_id, years_experience, bio_ar)
  values (v_uid, p_work_mode, case when p_work_mode <> 'MOBILE' then p_home_bay_shop_id end,
          case when p_work_mode <> 'BAY' then p_home_lat end, case when p_work_mode <> 'BAY' then p_home_lng end,
          coalesce(p_radius_km, 10), p_employer_shop_id, coalesce(p_years_experience, 0),
          nullif(btrim(coalesce(p_bio_ar, '')), ''))
  returning id into v_id;
  perform public.set_technician_job_types(v_id, p_job_types);
  perform public.set_technician_makes(v_id, p_make_ids);
  perform public.audit('APPLY', 'technician', v_id::text);
  return public.idem_finish(p_idem, 'apply_as_technician', public.technician_json(v_id));
exception
  when check_violation then
    raise exception 'INVALID_TECHNICIAN' using errcode = '22023', detail = sqlerrm;
  when foreign_key_violation then
    raise exception 'INVALID_REFERENCE' using errcode = '22023', detail = sqlerrm;
end
$$;

-- Changes only the keys present: work_mode, home_bay_shop_id, home_lat, home_lng,
-- radius_km, years_experience, bio_ar, bio_en, avatar_key, employer_shop_id.
create function public.tech_update_profile(p_patch jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id uuid := public.require_technician();
  t    public.technicians;
begin
  if jsonb_typeof(p_patch) <> 'object' then raise exception 'INVALID_VALUE' using errcode = '22023'; end if;
  update public.technicians x set
    work_mode        = case when p_patch ? 'work_mode' then (p_patch ->> 'work_mode')::public.work_mode else x.work_mode end,
    home_bay_shop_id = case when p_patch ? 'home_bay_shop_id' then (p_patch ->> 'home_bay_shop_id')::uuid else x.home_bay_shop_id end,
    home_lat         = case when p_patch ? 'home_lat' then (p_patch ->> 'home_lat')::double precision else x.home_lat end,
    home_lng         = case when p_patch ? 'home_lng' then (p_patch ->> 'home_lng')::double precision else x.home_lng end,
    radius_km        = case when p_patch ? 'radius_km' then (p_patch ->> 'radius_km')::integer else x.radius_km end,
    years_experience = case when p_patch ? 'years_experience' then (p_patch ->> 'years_experience')::integer else x.years_experience end,
    bio_ar           = case when p_patch ? 'bio_ar' then nullif(btrim(p_patch ->> 'bio_ar'), '') else x.bio_ar end,
    bio_en           = case when p_patch ? 'bio_en' then nullif(btrim(p_patch ->> 'bio_en'), '') else x.bio_en end,
    avatar_key       = case when p_patch ? 'avatar_key' then nullif(p_patch ->> 'avatar_key', '') else x.avatar_key end,
    employer_shop_id = case when p_patch ? 'employer_shop_id' then (p_patch ->> 'employer_shop_id')::uuid else x.employer_shop_id end
  where x.id = v_id
  returning * into t;
  if t.avatar_key is not null and t.avatar_key not like 'users/' || auth.uid() || '/%' then
    raise exception 'INVALID_IMAGE_KEY' using errcode = '22023';
  end if;
  perform public.check_technician_places(t.work_mode, t.home_bay_shop_id);
  return public.technician_json(v_id);
exception
  when invalid_text_representation or numeric_value_out_of_range then
    raise exception 'INVALID_VALUE' using errcode = '22023';
  when check_violation then
    raise exception 'INVALID_TECHNICIAN' using errcode = '22023', detail = sqlerrm;
  when foreign_key_violation then
    raise exception 'INVALID_REFERENCE' using errcode = '22023', detail = sqlerrm;
end
$$;

create function public.tech_set_job_types(p_items jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id uuid := public.require_technician();
begin
  perform public.set_technician_job_types(v_id, p_items);
  return public.technician_json(v_id);
end
$$;

create function public.tech_set_makes(p_make_ids uuid[])
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id uuid := public.require_technician();
begin
  perform public.set_technician_makes(v_id, p_make_ids);
  return public.technician_json(v_id);
end
$$;

-- "Busy for the next N minutes" (5 to 720): time off from now.
create function public.tech_quick_block(p_minutes integer, p_reason text default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id uuid := public.require_technician();
begin
  if p_minutes is null or p_minutes not between 5 and 720 then
    raise exception 'INVALID_VALUE' using errcode = '22023';
  end if;
  insert into public.time_off (technician_id, period, reason)
  values (v_id, tstzrange(now(), now() + make_interval(mins => p_minutes), '[)'),
          coalesce(nullif(btrim(coalesce(p_reason, '')), ''), 'QUICK_BLOCK'));
  return public.technician_json(v_id);
end
$$;

-- ------------------------------------------------------------------ RPCs: admin
create function public.admin_set_technician_status(p_technician_id uuid, p_status public.partner_status, p_reason text default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_admin uuid := public.require_admin();
  v_old   public.partner_status;
  v_user  uuid;
begin
  select t.status, t.user_id into v_old, v_user from public.technicians t where t.id = p_technician_id for update;
  if not found then raise exception 'TECHNICIAN_NOT_FOUND' using errcode = 'P0002'; end if;
  if not (
    (v_old = 'PENDING' and p_status in ('APPROVED', 'REJECTED'))
    or (v_old = 'APPROVED' and p_status = 'SUSPENDED')
    or (v_old in ('SUSPENDED', 'REJECTED') and p_status = 'APPROVED')
  ) then
    raise exception 'INVALID_TRANSITION' using errcode = 'PT409';
  end if;
  if p_status in ('REJECTED', 'SUSPENDED') and nullif(btrim(coalesce(p_reason, '')), '') is null then
    raise exception 'REASON_REQUIRED' using errcode = '22023';
  end if;
  update public.technicians t set
    status        = p_status,
    status_reason = nullif(btrim(coalesce(p_reason, '')), ''),
    approved_at   = case when p_status = 'APPROVED' then coalesce(t.approved_at, now()) else t.approved_at end
  where t.id = p_technician_id;
  if p_status = 'APPROVED' then
    insert into public.user_roles (user_id, role, granted_by) values (v_user, 'TECHNICIAN', v_admin)
    on conflict do nothing;
    perform public.tech_account(p_technician_id);
  end if;
  perform public.notify_partner(v_user, 'TECHNICIAN_STATUS',
                        jsonb_build_object('status', p_status, 'reason', nullif(btrim(coalesce(p_reason, '')), '')));
  perform public.audit('SET_STATUS', 'technician', p_technician_id::text,
                       jsonb_build_object('from', v_old, 'to', p_status, 'reason', p_reason));
  return public.technician_json(p_technician_id);
end
$$;

create function public.admin_verify_technician(p_technician_id uuid, p_verified boolean)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.require_admin();
  update public.technicians set verified = p_verified where id = p_technician_id;
  if not found then raise exception 'TECHNICIAN_NOT_FOUND' using errcode = 'P0002'; end if;
  perform public.audit('VERIFY', 'technician', p_technician_id::text, jsonb_build_object('verified', p_verified));
  return public.technician_json(p_technician_id);
end
$$;

-- ------------------------------------------------------------------ me()
-- Adds the caller's technician profile (or null) to what the apps read after sign-in.
create or replace function public.me()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'profile', to_jsonb(p),
    'roles', coalesce((select jsonb_agg(r.role order by r.role) from public.user_roles r where r.user_id = p.id), '[]'),
    'shops', coalesce((
      select jsonb_agg(jsonb_build_object(
               'shop_id', s.id, 'role', m.role, 'status', s.status, 'status_reason', s.status_reason,
               'name_ar', s.name_ar, 'name_en', s.name_en) order by m.created_at)
      from public.shop_members m join public.shops s on s.id = m.shop_id
      where m.user_id = p.id), '[]'),
    'technician', (select jsonb_build_object('technician_id', t.id, 'status', t.status,
                                             'status_reason', t.status_reason, 'work_mode', t.work_mode)
                   from public.technicians t where t.user_id = p.id)
  )
  from public.profiles p
  where p.id = auth.uid();
$$;

-- ------------------------------------------------------------------ RLS + grants
alter table public.technicians enable row level security;
alter table public.technician_job_types enable row level security;
alter table public.technician_makes enable row level security;
alter table public.availability_rules enable row level security;
alter table public.time_off enable row level security;
revoke all on public.technicians, public.technician_job_types, public.technician_makes,
  public.availability_rules, public.time_off from anon, authenticated;

grant select on public.technicians, public.technician_job_types, public.technician_makes to authenticated;
grant select, insert, update, delete on public.availability_rules, public.time_off to authenticated;

-- Buyers see technicians through booking_context() and technician_profile(), which
-- leave out the home point and contact details.
create policy technicians_read on public.technicians for select to authenticated
  using (user_id = (select auth.uid()) or (select public.is_admin()));
create policy technician_job_types_read on public.technician_job_types for select to authenticated
  using (technician_id = (select public.my_technician_id()) or (select public.is_admin()));
create policy technician_makes_read on public.technician_makes for select to authenticated
  using (technician_id = (select public.my_technician_id()) or (select public.is_admin()));
-- The technician keeps their own hours and time off.
create policy availability_rules_own on public.availability_rules for all to authenticated
  using (technician_id = (select public.my_technician_id()) or (select public.is_admin()))
  with check (technician_id = (select public.my_technician_id()));
create policy time_off_own on public.time_off for all to authenticated
  using (technician_id = (select public.my_technician_id()) or (select public.is_admin()))
  with check (technician_id = (select public.my_technician_id()));

-- At most 30 weekly windows; time off up to 60 days long.
create function public.tg_availability_limits()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_table_name = 'availability_rules' then
    if (select count(*) from public.availability_rules r where r.technician_id = new.technician_id) > 30 then
      raise exception 'TOO_MANY_RULES' using errcode = '22023';
    end if;
  elsif upper(new.period) - lower(new.period) > interval '60 days' then
    raise exception 'TIME_OFF_TOO_LONG' using errcode = '22023';
  end if;
  return null;
end
$$;
create trigger availability_rules_limits after insert or update on public.availability_rules
  for each row execute function public.tg_availability_limits();
create trigger time_off_limits after insert or update on public.time_off
  for each row execute function public.tg_availability_limits();

revoke all on function
  public.my_technician_id(), public.require_technician(boolean), public.tech_account(uuid),
  public.labour_in_bounds(uuid, bigint), public.set_technician_job_types(uuid, jsonb),
  public.set_technician_makes(uuid, uuid[]), public.technician_json(uuid),
  public.check_technician_places(public.work_mode, uuid),
  public.apply_as_technician(public.work_mode, jsonb, text, uuid[], uuid, double precision, double precision,
                             integer, integer, text, uuid, uuid),
  public.tech_update_profile(jsonb), public.tech_set_job_types(jsonb), public.tech_set_makes(uuid[]),
  public.tech_quick_block(integer, text), public.admin_set_technician_status(uuid, public.partner_status, text),
  public.admin_verify_technician(uuid, boolean), public.tg_availability_limits()
from public, anon, authenticated;

grant execute on function
  public.my_technician_id(),
  public.apply_as_technician(public.work_mode, jsonb, text, uuid[], uuid, double precision, double precision,
                             integer, integer, text, uuid, uuid),
  public.tech_update_profile(jsonb), public.tech_set_job_types(jsonb), public.tech_set_makes(uuid[]),
  public.tech_quick_block(integer, text), public.admin_set_technician_status(uuid, public.partner_status, text),
  public.admin_verify_technician(uuid, boolean)
to authenticated;
