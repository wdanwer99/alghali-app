-- M1 location: market → streets → zones → shops, shop staff, specialities, buyer addresses.
-- Lat/lng are plain columns that clients write; the geography point is generated from them.

-- ------------------------------------------------------------------ market, street, zones
create table public.markets (
  id         uuid primary key default gen_random_uuid(),
  slug       text not null unique check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  name_ar    text not null,
  name_en    text not null,
  city_ar    text not null default '',
  city_en    text not null default '',
  tz         text not null default 'Africa/Khartoum',
  is_active  boolean not null default true,
  updated_at timestamptz not null default now()
);

create table public.streets (
  id         uuid primary key default gen_random_uuid(),
  market_id  uuid not null references public.markets (id),
  slug       text not null check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  name_ar    text not null,
  name_en    text not null,
  length_m   integer not null default 1000 check (length_m > 0),
  -- Where travel and delivery distances are measured from. Set by an admin before launch.
  origin_lat double precision check (origin_lat between -90 and 90),
  origin_lng double precision check (origin_lng between -180 and 180),
  origin     extensions.geography(Point, 4326) generated always as (
               case when origin_lat is not null and origin_lng is not null then
                 extensions.st_setsrid(extensions.st_makepoint(origin_lng, origin_lat), 4326)::extensions.geography
               end) stored,
  is_active  boolean not null default true,
  updated_at timestamptz not null default now(),
  unique (market_id, slug)
);

-- A stretch of the street, in metres from its start.
create table public.zones (
  id         uuid primary key default gen_random_uuid(),
  street_id  uuid not null references public.streets (id),
  seq        integer not null check (seq > 0),
  name_ar    text not null,
  name_en    text not null,
  from_m     integer not null check (from_m >= 0),
  to_m       integer not null,
  is_active  boolean not null default true,
  updated_at timestamptz not null default now(),
  unique (street_id, seq),
  check (to_m > from_m)
);

-- ------------------------------------------------------------------ shops
-- Opening hours: {"0": [[480, 1200]], …} — weekday 0 = Sunday (Africa/Khartoum), each
-- window [start, end) in minutes after midnight, in order. A missing weekday = closed.
create function public.valid_opening_hours(p jsonb)
returns boolean
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_key  text;
  v_val  jsonb;
  v_win  jsonb;
  v_prev numeric;
  v_from numeric;
  v_to   numeric;
begin
  if jsonb_typeof(p) is distinct from 'object' then return false; end if;
  for v_key, v_val in select * from jsonb_each(p) loop
    if v_key !~ '^[0-6]$' or jsonb_typeof(v_val) <> 'array' or jsonb_array_length(v_val) > 4 then
      return false;
    end if;
    v_prev := 0;
    for v_win in select * from jsonb_array_elements(v_val) loop
      if jsonb_typeof(v_win) <> 'array' or jsonb_array_length(v_win) <> 2
         or jsonb_typeof(v_win -> 0) <> 'number' or jsonb_typeof(v_win -> 1) <> 'number' then
        return false;
      end if;
      v_from := (v_win ->> 0)::numeric;
      v_to := (v_win ->> 1)::numeric;
      if v_from <> trunc(v_from) or v_to <> trunc(v_to) or v_from < v_prev or v_to > 1440 or v_from >= v_to then
        return false;
      end if;
      v_prev := v_to;
    end loop;
  end loop;
  return true;
end
$$;

create function public.is_open_at(p_hours jsonb, p_at timestamptz)
returns boolean
language sql
immutable
set search_path = ''
as $$
  with t as (select p_at at time zone 'Africa/Khartoum' as local)
  select exists (
    select 1
    from t, jsonb_array_elements(coalesce(p_hours -> extract(dow from t.local)::int::text, '[]')) w
    where (extract(hour from t.local) * 60 + extract(minute from t.local)) >= (w ->> 0)::numeric
      and (extract(hour from t.local) * 60 + extract(minute from t.local)) < (w ->> 1)::numeric
  );
$$;

create table public.shops (
  id             uuid primary key default gen_random_uuid(),
  zone_id        uuid not null references public.zones (id),
  name_ar        text not null check (char_length(btrim(name_ar)) between 2 and 80),
  name_en        text not null default '' check (char_length(name_en) <= 80),
  plot_no        text check (char_length(plot_no) <= 20),
  side           text check (side in ('A', 'B')),
  landmark_ar    text check (char_length(landmark_ar) <= 200),
  landmark_en    text check (char_length(landmark_en) <= 200),
  about_ar       text check (char_length(about_ar) <= 500),
  about_en       text check (char_length(about_en) <= 500),
  lat            double precision check (lat between -90 and 90),
  lng            double precision check (lng between -180 and 180),
  location       extensions.geography(Point, 4326) generated always as (
                   case when lat is not null and lng is not null then
                     extensions.st_setsrid(extensions.st_makepoint(lng, lat), 4326)::extensions.geography
                   end) stored,
  pos_m          integer check (pos_m >= 0),   -- position along the street; orders pickup stops
  storefront_key text check (char_length(storefront_key) <= 300),
  phone          text check (phone ~ '^\+[1-9][0-9]{7,14}$'),
  whatsapp       text check (whatsapp ~ '^\+[1-9][0-9]{7,14}$'),
  opening_hours  jsonb not null default '{}' check (public.valid_opening_hours(opening_hours)),
  status         public.partner_status not null default 'PENDING',
  status_reason  text check (char_length(status_reason) <= 500),
  verified       boolean not null default false,
  rating_avg     numeric(3, 2) not null default 0,
  rating_count   integer not null default 0,
  created_by     uuid references auth.users (id) on delete set null,
  approved_at    timestamptz,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);
create index shops_zone_idx on public.shops (zone_id);
create index shops_status_idx on public.shops (status);

create table public.shop_members (
  shop_id    uuid not null references public.shops (id) on delete cascade,
  user_id    uuid not null references auth.users (id) on delete cascade,
  role       text not null check (role in ('OWNER', 'STAFF')),
  added_by   uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  primary key (shop_id, user_id)
);
create index shop_members_user_idx on public.shop_members (user_id);

create table public.shop_specialities (
  shop_id     uuid not null references public.shops (id) on delete cascade,
  category_id uuid references public.part_categories (id),
  make_id     uuid references public.vehicle_makes (id),
  check (num_nonnulls(category_id, make_id) = 1),
  unique nulls not distinct (shop_id, category_id, make_id)
);

alter table public.parts
  add constraint parts_created_by_shop_fk
  foreign key (created_by_shop_id) references public.shops (id) on delete set null;

create function public.is_shop_member(p_shop_id uuid, p_owner_only boolean default false)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.shop_members m
    where m.shop_id = p_shop_id and m.user_id = auth.uid() and (not p_owner_only or m.role = 'OWNER')
  );
$$;

-- Raises unless the caller works at the shop (or owns it), or is an admin.
create function public.require_shop(p_shop_id uuid, p_owner_only boolean default false)
returns uuid
language plpgsql
stable
set search_path = ''
as $$
declare
  v_uid uuid := public.require_user();
begin
  if not public.is_shop_member(p_shop_id, p_owner_only) and not public.is_admin() then
    raise exception 'FORBIDDEN' using errcode = '42501';
  end if;
  return v_uid;
end
$$;

-- ------------------------------------------------------------------ addresses
create table public.addresses (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null default auth.uid() references auth.users (id) on delete cascade,
  label          text not null check (char_length(btrim(label)) between 1 and 40),
  description_ar text check (char_length(description_ar) <= 300),   -- written directions
  lat            double precision not null check (lat between -90 and 90),
  lng            double precision not null check (lng between -180 and 180),
  location       extensions.geography(Point, 4326) generated always as (
                   extensions.st_setsrid(extensions.st_makepoint(lng, lat), 4326)::extensions.geography
                 ) stored,
  is_default     boolean not null default false,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);
create unique index addresses_one_default on public.addresses (user_id) where is_default;
create index addresses_user_idx on public.addresses (user_id);

create function public.tg_addresses_before()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    if (select count(*) from public.addresses a where a.user_id = new.user_id) >= 10 then
      raise exception 'ADDRESS_BOOK_FULL' using errcode = '22023';
    end if;
    if not exists (select 1 from public.addresses a where a.user_id = new.user_id) then
      new.is_default := true;
    end if;
  end if;
  if new.is_default then
    update public.addresses a set is_default = false
     where a.user_id = new.user_id and a.id <> new.id and a.is_default;
  end if;
  return new;
end
$$;

create trigger addresses_before before insert or update on public.addresses
  for each row execute function public.tg_addresses_before();
create trigger addresses_updated_at before update on public.addresses
  for each row execute function public.tg_set_updated_at();

-- ------------------------------------------------------------------ shop JSON
create function public.shop_json(p_shop_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select to_jsonb(s) - 'location' - 'created_by'
         || jsonb_build_object(
              'category_ids', coalesce((select jsonb_agg(sp.category_id) from public.shop_specialities sp
                                        where sp.shop_id = s.id and sp.category_id is not null), '[]'),
              'make_ids', coalesce((select jsonb_agg(sp.make_id) from public.shop_specialities sp
                                    where sp.shop_id = s.id and sp.make_id is not null), '[]'),
              'open_now', public.is_open_at(s.opening_hours, now()))
  from public.shops s where s.id = p_shop_id;
$$;

create function public.set_shop_specialities(p_shop_id uuid, p_category_ids uuid[], p_make_ids uuid[])
returns void
language plpgsql
set search_path = ''
as $$
begin
  if p_category_ids is not null then
    delete from public.shop_specialities where shop_id = p_shop_id and category_id is not null;
    insert into public.shop_specialities (shop_id, category_id)
    select p_shop_id, c from unnest(p_category_ids) c on conflict do nothing;
  end if;
  if p_make_ids is not null then
    delete from public.shop_specialities where shop_id = p_shop_id and make_id is not null;
    insert into public.shop_specialities (shop_id, make_id)
    select p_shop_id, m from unnest(p_make_ids) m on conflict do nothing;
  end if;
end
$$;

-- ------------------------------------------------------------------ RPCs: shops
-- A signed-in user applies to list a shop. It stays PENDING until an admin approves it.
create function public.apply_as_shop(
  p_name_ar       text,
  p_zone_id       uuid,
  p_phone         text,
  p_name_en       text default '',
  p_plot_no       text default null,
  p_side          text default null,
  p_landmark_ar   text default null,
  p_whatsapp      text default null,
  p_lat           double precision default null,
  p_lng           double precision default null,
  p_about_ar      text default null,
  p_opening_hours jsonb default '{}',
  p_category_ids  uuid[] default '{}',
  p_make_ids      uuid[] default '{}',
  p_idem          uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid   uuid := public.require_user();
  v_prev  jsonb := public.idem_begin(p_idem, 'apply_as_shop');
  v_phone text := public.normalize_phone(p_phone);
  v_wa    text := public.normalize_phone(p_whatsapp);
  v_id    uuid;
begin
  if v_prev is not null then return v_prev; end if;
  if v_phone is null then raise exception 'INVALID_PHONE' using errcode = '22023'; end if;
  if nullif(btrim(coalesce(p_whatsapp, '')), '') is not null and v_wa is null then
    raise exception 'INVALID_WHATSAPP' using errcode = '22023';
  end if;
  if not exists (select 1 from public.zones z where z.id = p_zone_id and z.is_active) then
    raise exception 'ZONE_NOT_FOUND' using errcode = 'P0002';
  end if;
  if exists (select 1 from public.shop_members m join public.shops s on s.id = m.shop_id
             where m.user_id = v_uid and m.role = 'OWNER' and s.status = 'PENDING') then
    raise exception 'APPLICATION_PENDING' using errcode = 'PT409';
  end if;
  if (select count(*) from public.shop_members m where m.user_id = v_uid and m.role = 'OWNER') >= 3 then
    raise exception 'TOO_MANY_SHOPS' using errcode = '22023';
  end if;
  if not public.valid_opening_hours(coalesce(p_opening_hours, '{}')) then
    raise exception 'INVALID_OPENING_HOURS' using errcode = '22023';
  end if;

  insert into public.shops (zone_id, name_ar, name_en, plot_no, side, landmark_ar, phone, whatsapp,
                            lat, lng, about_ar, opening_hours, created_by)
  values (p_zone_id, btrim(p_name_ar), btrim(coalesce(p_name_en, '')), nullif(btrim(coalesce(p_plot_no, '')), ''),
          p_side, nullif(btrim(coalesce(p_landmark_ar, '')), ''), v_phone, v_wa, p_lat, p_lng,
          nullif(btrim(coalesce(p_about_ar, '')), ''), coalesce(p_opening_hours, '{}'), v_uid)
  returning id into v_id;
  insert into public.shop_members (shop_id, user_id, role, added_by) values (v_id, v_uid, 'OWNER', v_uid);
  perform public.set_shop_specialities(v_id, coalesce(p_category_ids, '{}'), coalesce(p_make_ids, '{}'));
  perform public.audit('APPLY', 'shop', v_id::text);

  return public.idem_finish(p_idem, 'apply_as_shop', public.shop_json(v_id));
exception
  when check_violation then
    raise exception 'INVALID_SHOP' using errcode = '22023', detail = sqlerrm;
  when foreign_key_violation then
    raise exception 'INVALID_REFERENCE' using errcode = '22023', detail = sqlerrm;
end
$$;

-- Owners (and admins) change shop details. Only keys present in p_patch change.
-- Keys: name_ar, name_en, zone_id, plot_no, side, landmark_ar, landmark_en, about_ar, about_en,
-- phone, whatsapp, lat, lng, opening_hours, storefront_key, category_ids, make_ids; admins also pos_m.
create function public.shop_update_profile(p_shop_id uuid, p_patch jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid   uuid := public.require_shop(p_shop_id, true);
  v_admin boolean := public.is_admin();
  v_phone text;
  v_wa    text;
begin
  if not exists (select 1 from public.shops where id = p_shop_id) then
    raise exception 'SHOP_NOT_FOUND' using errcode = 'P0002';
  end if;
  if p_patch ? 'pos_m' and not v_admin then
    raise exception 'FORBIDDEN' using errcode = '42501';
  end if;
  if p_patch ? 'phone' then
    v_phone := public.normalize_phone(p_patch ->> 'phone');
    if v_phone is null then raise exception 'INVALID_PHONE' using errcode = '22023'; end if;
  end if;
  if p_patch ? 'whatsapp' and nullif(btrim(coalesce(p_patch ->> 'whatsapp', '')), '') is not null then
    v_wa := public.normalize_phone(p_patch ->> 'whatsapp');
    if v_wa is null then raise exception 'INVALID_WHATSAPP' using errcode = '22023'; end if;
  end if;
  if p_patch ? 'opening_hours' and not public.valid_opening_hours(p_patch -> 'opening_hours') then
    raise exception 'INVALID_OPENING_HOURS' using errcode = '22023';
  end if;
  if p_patch ? 'storefront_key'
     and nullif(p_patch ->> 'storefront_key', '') is not null
     and p_patch ->> 'storefront_key' not like 'shops/' || p_shop_id || '/%' then
    raise exception 'INVALID_IMAGE_KEY' using errcode = '22023';
  end if;

  update public.shops s set
    name_ar        = case when p_patch ? 'name_ar' then btrim(p_patch ->> 'name_ar') else s.name_ar end,
    name_en        = case when p_patch ? 'name_en' then btrim(coalesce(p_patch ->> 'name_en', '')) else s.name_en end,
    zone_id        = case when p_patch ? 'zone_id' then (p_patch ->> 'zone_id')::uuid else s.zone_id end,
    plot_no        = case when p_patch ? 'plot_no' then nullif(btrim(coalesce(p_patch ->> 'plot_no', '')), '') else s.plot_no end,
    side           = case when p_patch ? 'side' then p_patch ->> 'side' else s.side end,
    landmark_ar    = case when p_patch ? 'landmark_ar' then nullif(btrim(coalesce(p_patch ->> 'landmark_ar', '')), '') else s.landmark_ar end,
    landmark_en    = case when p_patch ? 'landmark_en' then nullif(btrim(coalesce(p_patch ->> 'landmark_en', '')), '') else s.landmark_en end,
    about_ar       = case when p_patch ? 'about_ar' then nullif(btrim(coalesce(p_patch ->> 'about_ar', '')), '') else s.about_ar end,
    about_en       = case when p_patch ? 'about_en' then nullif(btrim(coalesce(p_patch ->> 'about_en', '')), '') else s.about_en end,
    phone          = case when p_patch ? 'phone' then v_phone else s.phone end,
    whatsapp       = case when p_patch ? 'whatsapp' then v_wa else s.whatsapp end,
    lat            = case when p_patch ? 'lat' then (p_patch ->> 'lat')::double precision else s.lat end,
    lng            = case when p_patch ? 'lng' then (p_patch ->> 'lng')::double precision else s.lng end,
    opening_hours  = case when p_patch ? 'opening_hours' then p_patch -> 'opening_hours' else s.opening_hours end,
    storefront_key = case when p_patch ? 'storefront_key' then nullif(p_patch ->> 'storefront_key', '') else s.storefront_key end,
    pos_m          = case when p_patch ? 'pos_m' then (p_patch ->> 'pos_m')::integer else s.pos_m end
  where s.id = p_shop_id;

  perform public.set_shop_specialities(
    p_shop_id,
    case when p_patch ? 'category_ids' then array(select jsonb_array_elements_text(p_patch -> 'category_ids')::uuid) end,
    case when p_patch ? 'make_ids' then array(select jsonb_array_elements_text(p_patch -> 'make_ids')::uuid) end
  );
  perform public.audit('UPDATE', 'shop', p_shop_id::text, p_patch);
  return public.shop_json(p_shop_id);
exception
  when check_violation or not_null_violation then
    raise exception 'INVALID_SHOP' using errcode = '22023', detail = sqlerrm;
  when foreign_key_violation then
    raise exception 'INVALID_REFERENCE' using errcode = '22023', detail = sqlerrm;
  when invalid_text_representation then
    raise exception 'INVALID_VALUE' using errcode = '22023', detail = sqlerrm;
end
$$;

-- The owner adds a colleague who already has an account (signed up in the partner app).
create function public.shop_add_staff(p_shop_id uuid, p_email text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid    uuid := public.require_shop(p_shop_id, true);
  v_member uuid;
begin
  select p.id into v_member from public.profiles p where lower(p.email) = lower(btrim(p_email));
  if v_member is null then
    raise exception 'USER_NOT_FOUND' using errcode = 'P0002';
  end if;
  if exists (select 1 from public.shop_members m where m.shop_id = p_shop_id and m.user_id = v_member) then
    raise exception 'ALREADY_MEMBER' using errcode = 'PT409';
  end if;
  if (select count(*) from public.shop_members m where m.shop_id = p_shop_id) >= 15 then
    raise exception 'TOO_MANY_STAFF' using errcode = '22023';
  end if;
  insert into public.shop_members (shop_id, user_id, role, added_by) values (p_shop_id, v_member, 'STAFF', v_uid);
  if (select s.status from public.shops s where s.id = p_shop_id) = 'APPROVED' then
    insert into public.user_roles (user_id, role, granted_by) values (v_member, 'SHOP_STAFF', v_uid)
    on conflict do nothing;
  end if;
  perform public.audit('ADD_STAFF', 'shop', p_shop_id::text, jsonb_build_object('user_id', v_member));
  return jsonb_build_object('shop_id', p_shop_id, 'user_id', v_member, 'role', 'STAFF');
end
$$;

create function public.shop_remove_staff(p_shop_id uuid, p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := public.require_shop(p_shop_id, true);
begin
  if exists (select 1 from public.shop_members m
             where m.shop_id = p_shop_id and m.user_id = p_user_id and m.role = 'OWNER') then
    raise exception 'CANNOT_REMOVE_OWNER' using errcode = '22023';
  end if;
  delete from public.shop_members where shop_id = p_shop_id and user_id = p_user_id;
  if not found then
    raise exception 'NOT_A_MEMBER' using errcode = 'P0002';
  end if;
  if not exists (select 1 from public.shop_members m where m.user_id = p_user_id and m.role = 'STAFF') then
    delete from public.user_roles where user_id = p_user_id and role = 'SHOP_STAFF';
  end if;
  perform public.audit('REMOVE_STAFF', 'shop', p_shop_id::text, jsonb_build_object('user_id', p_user_id));
end
$$;

-- Members of a shop the caller belongs to (names and emails for the staff screen).
create function public.shop_staff(p_shop_id uuid)
returns table (user_id uuid, role text, email text, display_name text, added_at timestamptz)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform public.require_shop(p_shop_id);
  return query
    select m.user_id, m.role, p.email, p.display_name, m.created_at
    from public.shop_members m join public.profiles p on p.id = m.user_id
    where m.shop_id = p_shop_id
    order by m.role = 'OWNER' desc, m.created_at;
end
$$;

-- ------------------------------------------------------------------ RPCs: admin
-- PENDING → APPROVED | REJECTED; APPROVED ⇄ SUSPENDED; REJECTED → APPROVED.
-- Approval grants SHOP_OWNER / SHOP_STAFF and places the shop mid-zone if pos_m is unset.
create function public.admin_set_shop_status(p_shop_id uuid, p_status public.partner_status, p_reason text default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_admin uuid := public.require_admin();
  v_old   public.partner_status;
begin
  select s.status into v_old from public.shops s where s.id = p_shop_id for update;
  if not found then raise exception 'SHOP_NOT_FOUND' using errcode = 'P0002'; end if;
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

  update public.shops s set
    status        = p_status,
    status_reason = nullif(btrim(coalesce(p_reason, '')), ''),
    approved_at   = case when p_status = 'APPROVED' then coalesce(s.approved_at, now()) else s.approved_at end,
    pos_m         = case when p_status = 'APPROVED' and s.pos_m is null
                         then (select (z.from_m + z.to_m) / 2 from public.zones z where z.id = s.zone_id)
                         else s.pos_m end
  where s.id = p_shop_id;

  if p_status = 'APPROVED' then
    insert into public.user_roles (user_id, role, granted_by)
    select m.user_id, case m.role when 'OWNER' then 'SHOP_OWNER'::public.app_role else 'SHOP_STAFF'::public.app_role end, v_admin
    from public.shop_members m where m.shop_id = p_shop_id
    on conflict do nothing;
  end if;

  perform public.audit('SET_STATUS', 'shop', p_shop_id::text,
                       jsonb_build_object('from', v_old, 'to', p_status, 'reason', p_reason));
  return public.shop_json(p_shop_id);
end
$$;

create function public.admin_verify_shop(p_shop_id uuid, p_verified boolean)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.require_admin();
  update public.shops set verified = p_verified where id = p_shop_id;
  if not found then raise exception 'SHOP_NOT_FOUND' using errcode = 'P0002'; end if;
  perform public.audit('VERIFY', 'shop', p_shop_id::text, jsonb_build_object('verified', p_verified));
  return public.shop_json(p_shop_id);
end
$$;

-- ------------------------------------------------------------------ RPCs: me
-- Everything an app needs right after sign-in to decide where to go.
create function public.me()
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
      where m.user_id = p.id), '[]')
  )
  from public.profiles p
  where p.id = auth.uid();
$$;

-- ------------------------------------------------------------------ triggers
create trigger markets_updated_at before update on public.markets
  for each row execute function public.tg_set_updated_at();
create trigger streets_updated_at before update on public.streets
  for each row execute function public.tg_set_updated_at();
create trigger zones_updated_at before update on public.zones
  for each row execute function public.tg_set_updated_at();
create trigger shops_updated_at before update on public.shops
  for each row execute function public.tg_set_updated_at();
create trigger markets_audit after insert or update or delete on public.markets
  for each row execute function public.tg_audit_row();
create trigger streets_audit after insert or update or delete on public.streets
  for each row execute function public.tg_audit_row();
create trigger zones_audit after insert or update or delete on public.zones
  for each row execute function public.tg_audit_row();

-- ------------------------------------------------------------------ RLS + grants
alter table public.markets enable row level security;
alter table public.streets enable row level security;
alter table public.zones enable row level security;
alter table public.shops enable row level security;
alter table public.shop_members enable row level security;
alter table public.shop_specialities enable row level security;
alter table public.addresses enable row level security;

revoke all on public.markets, public.streets, public.zones, public.shops, public.shop_members,
              public.shop_specialities, public.addresses
  from anon, authenticated;

grant select on public.markets, public.streets, public.zones, public.shops, public.shop_specialities
  to anon, authenticated;
grant select on public.shop_members to authenticated;
grant insert, update, delete on public.markets, public.streets, public.zones to authenticated;  -- admins (RLS)

create policy markets_read on public.markets for select to anon, authenticated
  using (is_active or (select public.is_admin()));
create policy streets_read on public.streets for select to anon, authenticated
  using (is_active or (select public.is_admin()));
create policy zones_read on public.zones for select to anon, authenticated
  using (is_active or (select public.is_admin()));
create policy markets_admin on public.markets for all to authenticated
  using ((select public.is_admin())) with check ((select public.is_admin()));
create policy streets_admin on public.streets for all to authenticated
  using ((select public.is_admin())) with check ((select public.is_admin()));
create policy zones_admin on public.zones for all to authenticated
  using ((select public.is_admin())) with check ((select public.is_admin()));

create policy shops_read on public.shops for select to anon, authenticated
  using (status = 'APPROVED' or public.is_shop_member(id) or (select public.is_admin()));
create policy shop_specialities_read on public.shop_specialities for select to anon, authenticated
  using (true);
create policy shop_members_read on public.shop_members for select to authenticated
  using (user_id = (select auth.uid()) or public.is_shop_member(shop_id) or (select public.is_admin()));

grant select, insert, update, delete on public.addresses to authenticated;
create policy addresses_own on public.addresses for all to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

revoke all on function
  public.valid_opening_hours(jsonb), public.is_open_at(jsonb, timestamptz),
  public.is_shop_member(uuid, boolean), public.require_shop(uuid, boolean),
  public.tg_addresses_before(), public.shop_json(uuid),
  public.set_shop_specialities(uuid, uuid[], uuid[]),
  public.apply_as_shop(text, uuid, text, text, text, text, text, text, double precision, double precision,
                       text, jsonb, uuid[], uuid[], uuid),
  public.shop_update_profile(uuid, jsonb), public.shop_add_staff(uuid, text),
  public.shop_remove_staff(uuid, uuid), public.shop_staff(uuid),
  public.admin_set_shop_status(uuid, public.partner_status, text), public.admin_verify_shop(uuid, boolean),
  public.me()
from public, anon, authenticated;

grant execute on function public.is_shop_member(uuid, boolean), public.valid_opening_hours(jsonb)
  to anon, authenticated;
grant execute on function
  public.apply_as_shop(text, uuid, text, text, text, text, text, text, double precision, double precision,
                       text, jsonb, uuid[], uuid[], uuid),
  public.shop_update_profile(uuid, jsonb), public.shop_add_staff(uuid, text),
  public.shop_remove_staff(uuid, uuid), public.shop_staff(uuid),
  public.admin_set_shop_status(uuid, public.partner_status, text), public.admin_verify_shop(uuid, boolean),
  public.me()
to authenticated;
