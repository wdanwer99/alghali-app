-- M3 bookings: fitting jobs, the no-double-booking constraint, the booking state machine
-- (PLAN §3.10, the same pattern as sub-orders, D-082), what a job needs (items, duration,
-- fees), which technicians can take it, holds, and job offers with reassignment.
--
-- A booking blocks its technician's calendar from block_from to block_to: the job itself,
-- plus the travel buffer on both sides for jobs at the buyer's location (D-025). The
-- EXCLUDE constraint below is the final word on double booking: two active bookings of
-- one technician can never overlap, whatever the apps or Edge Functions computed.

create type public.booking_place as enum ('BAY', 'CUSTOMER_LOCATION');
create type public.booking_status as enum (
  'HELD', 'AWAITING_PAYMENT', 'PENDING_TECH_ACCEPT', 'ACCEPTED', 'EN_ROUTE', 'IN_PROGRESS', 'COMPLETED',
  'NEEDS_RESCHEDULE', 'EXPIRED', 'CANCELLED_BY_BUYER', 'CANCELLED_BY_TECH', 'CANCELLED_BY_ADMIN',
  'PART_DOES_NOT_FIT');
create type public.offer_status as enum ('OFFERED', 'ACCEPTED', 'DECLINED', 'TIMED_OUT', 'WITHDRAWN');

create table public.bookings (
  id               uuid primary key default gen_random_uuid(),
  ref              text not null unique references public.refs (ref),
  buyer_id         uuid not null references auth.users (id),
  order_id         uuid references public.orders (id) on delete set null,   -- set at checkout (D-097)
  technician_id    uuid not null references public.technicians (id),
  assignment_mode  text not null default 'CHOSEN' check (assignment_mode in ('CHOSEN', 'ANY')),
  place            public.booking_place not null,
  bay_shop_id      uuid references public.shops (id),
  address_id       uuid references public.addresses (id) on delete set null,
  address_snapshot jsonb,
  lat              double precision check (lat between -90 and 90),
  lng              double precision check (lng between -180 and 180),
  point            extensions.geography(Point, 4326) generated always as (
                     case when lat is not null and lng is not null then
                       extensions.st_setsrid(extensions.st_makepoint(lng, lat), 4326)::extensions.geography
                     end) stored,
  location_note    text check (char_length(location_note) <= 300),
  make_id          uuid references public.vehicle_makes (id),
  variant_id       uuid references public.vehicle_variants (id),
  start_at         timestamptz not null,
  end_at           timestamptz not null,
  block_from       timestamptz not null,
  block_to         timestamptz not null,
  duration_min     integer not null check (duration_min between 5 and 720),
  status           public.booking_status not null default 'HELD',
  hold_expires_at  timestamptz,
  labour_sdg       bigint not null check (labour_sdg >= 0),
  travel_fee_sdg   bigint not null default 0 check (travel_fee_sdg >= 0),
  booking_fee_sdg  bigint not null default 0 check (booking_fee_sdg >= 0),
  deposit_sdg      bigint not null default 0 check (deposit_sdg >= 0),
  payment_method   public.payment_method,
  accepted_at      timestamptz,
  en_route_at      timestamptz,
  checked_in_at    timestamptz,
  completed_at     timestamptz,
  cancelled_at     timestamptz,
  cancel_reason    text check (char_length(cancel_reason) <= 500),
  reminded_day_at  timestamptz,
  reminded_hour_at timestamptz,
  status_changed_at timestamptz not null default now(),
  created_at       timestamptz not null default now(),
  check (end_at > start_at and block_from <= start_at and block_to >= end_at),
  check (place = 'BAY' or (lat is not null and lng is not null)),
  check (place = 'CUSTOMER_LOCATION' or bay_shop_id is not null),
  constraint bookings_no_overlap exclude using gist (
    technician_id with =,
    tstzrange(block_from, block_to, '[)') with &&
  ) where (status in ('HELD', 'AWAITING_PAYMENT', 'PENDING_TECH_ACCEPT', 'ACCEPTED', 'EN_ROUTE', 'IN_PROGRESS'))
);
create index bookings_buyer_idx on public.bookings (buyer_id, created_at desc);
create index bookings_tech_idx on public.bookings (technician_id, start_at);
create index bookings_status_idx on public.bookings (status, start_at);
create index bookings_order_idx on public.bookings (order_id);

-- The 4-digit job code (D-028) lives apart so that only the buyer can read it.
create table public.booking_codes (
  booking_id uuid primary key references public.bookings (id) on delete cascade,
  code       text not null check (code ~ '^[0-9]{4}$'),
  attempts   integer not null default 0,
  locked_at  timestamptz
);

-- What is being fitted. Exactly one source: a cart line (listing or offer, linked to its
-- order item at checkout), an item of an earlier order, or a part bought elsewhere
-- (a catalogue part or just a category, with the buyer's description).
create table public.booking_items (
  id            uuid primary key default gen_random_uuid(),
  booking_id    uuid not null references public.bookings (id) on delete cascade,
  listing_id    uuid references public.listings (id) on delete set null,
  offer_id      uuid references public.part_offers (id) on delete set null,
  order_item_id uuid references public.order_items (id) on delete set null,
  part_id       uuid references public.parts (id),
  category_id   uuid references public.part_categories (id),
  job_type_id   uuid not null references public.job_types (id),
  minutes       integer not null check (minutes between 5 and 600),
  title_ar      text not null,
  title_en      text not null,
  description   text check (char_length(description) <= 300)
);
create index booking_items_booking_idx on public.booking_items (booking_id);
create index booking_items_order_item_idx on public.booking_items (order_item_id);

-- Each technician the job was offered to (D-024): decline and timeout are offer
-- statuses; the booking stays PENDING_TECH_ACCEPT while the next technician is asked.
create table public.booking_offers (
  id            uuid primary key default gen_random_uuid(),
  booking_id    uuid not null references public.bookings (id) on delete cascade,
  technician_id uuid not null references public.technicians (id),
  status        public.offer_status not null default 'OFFERED',
  offered_at    timestamptz not null default now(),
  expires_at    timestamptz not null,
  responded_at  timestamptz,
  reason        text check (char_length(reason) <= 300)
);
create unique index booking_offers_one_open on public.booking_offers (booking_id) where status = 'OFFERED';
create index booking_offers_tech_idx on public.booking_offers (technician_id, status);
create index booking_offers_expiry_idx on public.booking_offers (expires_at) where status = 'OFFERED';

create table public.booking_events (
  id          bigint generated always as identity primary key,
  booking_id  uuid not null references public.bookings (id) on delete cascade,
  from_status public.booking_status,
  to_status   public.booking_status not null,
  actor_kind  text not null check (actor_kind in ('BUYER', 'TECH', 'SHOP', 'ADMIN', 'SYSTEM')),
  actor_id    uuid references auth.users (id) on delete set null,
  reason      text,
  at          timestamptz not null default now()
);
create index booking_events_booking_idx on public.booking_events (booking_id, at);

create table public.booking_photos (
  id         uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.bookings (id) on delete cascade,
  kind       text not null check (kind in ('BEFORE', 'AFTER')),
  image_key  text not null check (char_length(image_key) <= 300),
  created_by uuid references auth.users (id) on delete set null,
  taken_at   timestamptz not null default now()
);
create index booking_photos_booking_idx on public.booking_photos (booking_id);

-- The technician's position while EN_ROUTE only (D-029); deleted at check-in.
create table public.tech_locations (
  booking_id    uuid primary key references public.bookings (id) on delete cascade,
  technician_id uuid not null references public.technicians (id) on delete cascade,
  lat           double precision not null check (lat between -90 and 90),
  lng           double precision not null check (lng between -180 and 180),
  updated_at    timestamptz not null default now()
);

-- Like the other ids on journals, no foreign key: the ledger outlives what it records.
alter table public.ledger_journals add column booking_id uuid;
create index ledger_journals_booking_idx on public.ledger_journals (booking_id);
alter table public.payments
  add constraint payments_booking_fk foreign key (booking_id) references public.bookings (id);
create index payments_booking_idx on public.payments (booking_id);

-- ------------------------------------------------------------------ state machine
create table public.booking_transitions (
  from_status public.booking_status not null,
  to_status   public.booking_status not null,
  actor       text not null check (actor in ('BUYER', 'TECH', 'SHOP', 'ADMIN', 'SYSTEM')),
  primary key (from_status, to_status, actor)
);

insert into public.booking_transitions (from_status, to_status, actor) values
  ('HELD',                'AWAITING_PAYMENT',    'BUYER'),    -- checkout with a Bankak payment or deposit
  ('HELD',                'PENDING_TECH_ACCEPT', 'BUYER'),    -- checkout in cash with nothing to pay first
  ('HELD',                'EXPIRED',             'SYSTEM'),   -- the hold lapsed
  ('HELD',                'CANCELLED_BY_BUYER',  'BUYER'),    -- released, or replaced by a new hold
  ('AWAITING_PAYMENT',    'PENDING_TECH_ACCEPT', 'ADMIN'),    -- the payment was confirmed (D-023)
  ('AWAITING_PAYMENT',    'NEEDS_RESCHEDULE',    'ADMIN'),    -- confirmed too late for the slot
  ('AWAITING_PAYMENT',    'EXPIRED',             'SYSTEM'),   -- not paid by pay_by
  ('AWAITING_PAYMENT',    'CANCELLED_BY_BUYER',  'BUYER'),
  ('AWAITING_PAYMENT',    'CANCELLED_BY_ADMIN',  'ADMIN'),
  ('PENDING_TECH_ACCEPT', 'ACCEPTED',            'TECH'),
  ('PENDING_TECH_ACCEPT', 'NEEDS_RESCHEDULE',    'TECH'),     -- declined, and nobody else is free
  ('PENDING_TECH_ACCEPT', 'NEEDS_RESCHEDULE',    'SYSTEM'),   -- timed out, and nobody else is free
  ('PENDING_TECH_ACCEPT', 'NEEDS_RESCHEDULE',    'ADMIN'),
  ('PENDING_TECH_ACCEPT', 'CANCELLED_BY_BUYER',  'BUYER'),
  ('PENDING_TECH_ACCEPT', 'CANCELLED_BY_ADMIN',  'ADMIN'),
  ('ACCEPTED',            'EN_ROUTE',            'TECH'),     -- jobs at the buyer's location only
  ('ACCEPTED',            'IN_PROGRESS',         'TECH'),     -- check-in at the bay
  ('ACCEPTED',            'PENDING_TECH_ACCEPT', 'TECH'),     -- the technician dropped out: offered to the next
  ('ACCEPTED',            'NEEDS_RESCHEDULE',    'TECH'),     -- … and nobody else is free
  ('ACCEPTED',            'PENDING_TECH_ACCEPT', 'ADMIN'),
  ('ACCEPTED',            'NEEDS_RESCHEDULE',    'ADMIN'),
  ('ACCEPTED',            'CANCELLED_BY_BUYER',  'BUYER'),
  ('ACCEPTED',            'CANCELLED_BY_ADMIN',  'ADMIN'),
  ('EN_ROUTE',            'IN_PROGRESS',         'TECH'),
  ('EN_ROUTE',            'CANCELLED_BY_BUYER',  'BUYER'),
  ('EN_ROUTE',            'CANCELLED_BY_ADMIN',  'ADMIN'),
  ('IN_PROGRESS',         'COMPLETED',           'TECH'),     -- with the buyer's job code
  ('IN_PROGRESS',         'COMPLETED',           'ADMIN'),    -- e.g. after the code locked
  ('IN_PROGRESS',         'PART_DOES_NOT_FIT',   'TECH'),
  ('IN_PROGRESS',         'CANCELLED_BY_ADMIN',  'ADMIN'),
  ('NEEDS_RESCHEDULE',    'PENDING_TECH_ACCEPT', 'BUYER'),    -- picked a new time
  ('NEEDS_RESCHEDULE',    'CANCELLED_BY_BUYER',  'BUYER'),
  ('NEEDS_RESCHEDULE',    'CANCELLED_BY_ADMIN',  'ADMIN'),
  ('NEEDS_RESCHEDULE',    'EXPIRED',             'SYSTEM');   -- the buyer never picked a new time

create function public.booking_transition_allowed(p_from public.booking_status, p_to public.booking_status, p_actor text)
returns boolean
language sql
stable
set search_path = ''
as $$
  select exists (select 1 from public.booking_transitions t
                 where t.from_status = p_from and t.to_status = p_to and t.actor = p_actor);
$$;

create function public.tg_booking_status_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.status is distinct from old.status then
    if not public.booking_transition_allowed(old.status, new.status, nullif(current_setting('app.actor', true), '')) then
      raise exception 'INVALID_TRANSITION' using errcode = 'PT409', detail = old.status || ' -> ' || new.status;
    end if;
    new.status_changed_at := now();
  end if;
  return new;
end
$$;
create trigger bookings_status_guard before update of status on public.bookings
  for each row execute function public.tg_booking_status_guard();

create function public.booking_is_active(p_status public.booking_status)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select p_status in ('HELD', 'AWAITING_PAYMENT', 'PENDING_TECH_ACCEPT', 'ACCEPTED', 'EN_ROUTE', 'IN_PROGRESS');
$$;

-- ------------------------------------------------------------------ what a job needs
-- Wall-clock minutes after midnight in Khartoum.
create function public.khartoum_minutes(p_at timestamptz)
returns integer
language sql
immutable
set search_path = ''
as $$
  select (extract(hour from p_at at time zone 'Africa/Khartoum') * 60
          + extract(minute from p_at at time zone 'Africa/Khartoum'))::integer;
$$;

create function public.khartoum_weekday(p_at timestamptz)
returns integer
language sql
immutable
set search_path = ''
as $$
  select extract(dow from p_at at time zone 'Africa/Khartoum')::integer;
$$;

-- The earliest start for a new job: now + part_ready_buffer_minutes on a quarter hour (D-027).
create function public.booking_earliest()
returns timestamptz
language sql
stable
set search_path = ''
as $$
  select to_timestamp(ceil(extract(epoch from now() + make_interval(mins => public.setting_int('part_ready_buffer_minutes')::integer))
                           / 900) * 900);
$$;

-- Travel fee from the street's starting point (D-026) by travel_fee_bands.
create function public.travel_fee(p_point extensions.geography)
returns bigint
language plpgsql
stable
set search_path = ''
as $$
declare
  v_origin extensions.geography;
  v_km     numeric;
  v_fee    bigint;
begin
  select st.origin into v_origin from public.streets st where st.is_active and st.origin is not null
  order by st.updated_at limit 1;
  if v_origin is null then raise exception 'TRAVEL_UNAVAILABLE' using errcode = '22023'; end if;
  v_km := extensions.st_distance(v_origin, p_point) / 1000.0;
  select (b ->> 'sdg')::bigint into v_fee
  from jsonb_array_elements(public.setting('travel_fee_bands')) b
  where (b ->> 'max_km')::numeric >= v_km
  order by (b ->> 'max_km')::numeric
  limit 1;
  if v_fee is null then raise exception 'TRAVEL_OUT_OF_RANGE' using errcode = '22023'; end if;
  return v_fee;
end
$$;

-- Resolves what is to be fitted into job types and minutes. p_items (1–10):
--   {listing_id} | {offer_id} | {order_item_id}  — parts bought here (the last from an earlier order)
--   {part_id, description?} | {category_id, description}  — parts bought elsewhere
-- Minutes come from the part, else its category, else 60 (PLAN §5). Returns
-- [{listing_id?, offer_id?, order_item_id?, part_id?, category_id, job_type_id, minutes, title_ar, title_en, description?}].
create function public.resolve_booking_items(p_items jsonb, p_buyer uuid)
returns jsonb
language plpgsql
stable
set search_path = ''
as $$
declare
  v_item jsonb;
  v_out  jsonb := '[]';
  v_part uuid;
  v_cat  uuid;
  v_desc text;
  v_pmin integer;
  v_par  text;
  v_pen  text;
  v_inst boolean;
  c      record;
begin
  if jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) not between 1 and 10 then
    raise exception 'ITEMS_REQUIRED' using errcode = '22023';
  end if;
  for v_item in select * from jsonb_array_elements(p_items) loop
    v_part := null;
    v_cat := null;
    v_pmin := null;
    v_par := null;
    v_pen := null;
    v_desc := nullif(btrim(coalesce(v_item ->> 'description', '')), '');
    if v_item ? 'listing_id' then
      select l.part_id into v_part from public.listings l join public.shops s on s.id = l.shop_id
      where l.id = (v_item ->> 'listing_id')::uuid and l.archived_at is null and s.status = 'APPROVED';
      if v_part is null then raise exception 'ITEM_NOT_FOUND' using errcode = 'P0002'; end if;
    elsif v_item ? 'offer_id' then
      select o.part_id, rq.category_id into v_part, v_cat
      from public.part_offers o join public.part_requests rq on rq.id = o.request_id
      where o.id = (v_item ->> 'offer_id')::uuid and rq.buyer_id = p_buyer;
      if not found then raise exception 'ITEM_NOT_FOUND' using errcode = 'P0002'; end if;
    elsif v_item ? 'order_item_id' then
      select i.part_id, rq.category_id into v_part, v_cat
      from public.order_items i
      join public.sub_orders s on s.id = i.sub_order_id
      join public.orders o on o.id = s.order_id
      left join public.part_offers po on po.id = i.offer_id
      left join public.part_requests rq on rq.id = po.request_id
      where i.id = (v_item ->> 'order_item_id')::uuid and o.buyer_id = p_buyer;
      if not found then raise exception 'ITEM_NOT_FOUND' using errcode = 'P0002'; end if;
    elsif v_item ? 'part_id' then
      v_part := (v_item ->> 'part_id')::uuid;
    elsif v_item ? 'category_id' then
      v_cat := (v_item ->> 'category_id')::uuid;
      if v_desc is null then raise exception 'DESCRIPTION_REQUIRED' using errcode = '22023'; end if;
    else
      raise exception 'INVALID_ITEMS' using errcode = '22023';
    end if;

    if v_part is not null then
      select p.category_id, p.name_ar, p.name_en, p.installable, p.std_job_minutes
        into v_cat, v_par, v_pen, v_inst, v_pmin
      from public.parts p where p.id = v_part;
      if v_par is null then raise exception 'ITEM_NOT_FOUND' using errcode = 'P0002'; end if;
      if not v_inst then raise exception 'NOT_INSTALLABLE' using errcode = '22023'; end if;
    end if;
    select pc.id, pc.job_type_id, pc.std_job_minutes, pc.name_ar, pc.name_en into c
    from public.part_categories pc where pc.id = v_cat;
    if c.id is null or c.job_type_id is null then raise exception 'NOT_INSTALLABLE' using errcode = '22023'; end if;

    v_out := v_out || jsonb_build_array(jsonb_strip_nulls(jsonb_build_object(
      'listing_id', v_item ->> 'listing_id', 'offer_id', v_item ->> 'offer_id',
      'order_item_id', v_item ->> 'order_item_id', 'part_id', v_part, 'category_id', c.id,
      'job_type_id', c.job_type_id,
      'minutes', coalesce(v_pmin, c.std_job_minutes, 60),
      'title_ar', coalesce(v_par, c.name_ar),
      'title_en', coalesce(nullif(v_pen, ''), c.name_en),
      'description', v_desc)));
  end loop;
  return v_out;
exception
  when invalid_text_representation then
    raise exception 'INVALID_ITEMS' using errcode = '22023';
end
$$;

-- Labour for a set of job types at this technician's prices (one price per job type, D-010).
create function public.tech_labour(p_technician_id uuid, p_job_type_ids uuid[])
returns bigint
language sql
stable
set search_path = ''
as $$
  select case when count(*) = cardinality(p_job_type_ids) then sum(tj.labour_sdg)::bigint end
  from public.technician_job_types tj
  where tj.technician_id = p_technician_id and tj.job_type_id = any (p_job_type_ids);
$$;

-- Whether a technician can do this kind of job at all (skills, makes, mode, coverage),
-- before looking at their calendar.
create function public.tech_suits(
  p_technician_id uuid,
  p_job_type_ids  uuid[],
  p_make_id       uuid,
  p_place         public.booking_place,
  p_point         extensions.geography
)
returns boolean
language sql
stable
set search_path = ''
as $$
  select exists (
    select 1 from public.technicians t
    where t.id = p_technician_id and t.status = 'APPROVED'
      and case p_place
            when 'BAY' then t.work_mode in ('BAY', 'BOTH') and t.home_bay_shop_id is not null
            else t.work_mode in ('MOBILE', 'BOTH') and p_point is not null
                 and extensions.st_dwithin(t.home_point, p_point, t.radius_km * 1000.0)
          end
      and public.tech_labour(t.id, p_job_type_ids) is not null
      and (p_make_id is null
           or not exists (select 1 from public.technician_makes m where m.technician_id = t.id)
           or exists (select 1 from public.technician_makes m where m.technician_id = t.id and m.make_id = p_make_id)));
$$;

-- Whether the technician is free for this job: inside one of their weekly windows for
-- this kind of job, clear of time off, and its block clear of their other bookings
-- (holds that lapsed don't count).
create function public.tech_free(
  p_technician_id uuid,
  p_place         public.booking_place,
  p_start         timestamptz,
  p_end           timestamptz,
  p_block_from    timestamptz,
  p_block_to      timestamptz,
  p_except        uuid default null
)
returns boolean
language sql
stable
set search_path = ''
as $$
  select exists (
           select 1 from public.availability_rules r
           where r.technician_id = p_technician_id
             and r.weekday = public.khartoum_weekday(p_start)
             and (r.modes = 'BOTH' or r.modes::text = case p_place when 'BAY' then 'BAY' else 'MOBILE' end)
             and r.start_min <= public.khartoum_minutes(p_start)
             and public.khartoum_minutes(p_start) + extract(epoch from p_end - p_start) / 60 <= r.end_min)
     and not exists (
           select 1 from public.time_off o
           where o.technician_id = p_technician_id and o.period && tstzrange(p_start, p_end, '[)'))
     and not exists (
           select 1 from public.bookings b
           where b.technician_id = p_technician_id and b.id is distinct from p_except
             and public.booking_is_active(b.status)
             and not (b.status = 'HELD' and b.hold_expires_at < now())
             and tstzrange(b.block_from, b.block_to, '[)') && tstzrange(p_block_from, p_block_to, '[)'));
$$;

-- The block a job occupies (D-025).
create function public.booking_block(p_place public.booking_place, p_start timestamptz, p_end timestamptz)
returns tstzrange
language sql
stable
set search_path = ''
as $$
  select case p_place
           when 'CUSTOMER_LOCATION' then
             tstzrange(p_start - make_interval(mins => public.setting_int('travel_buffer_minutes')::integer),
                       p_end + make_interval(mins => public.setting_int('travel_buffer_minutes')::integer), '[)')
           else tstzrange(p_start, p_end, '[)')
         end;
$$;

-- Everything about a job before a technician is chosen: items, duration, job types,
-- the car's make, where, and the fees. p_point is the buyer's location for mobile jobs.
create function public.booking_quote(
  p_items      jsonb,
  p_place      public.booking_place,
  p_point      extensions.geography,
  p_variant_id uuid,
  p_buyer      uuid
)
returns jsonb
language plpgsql
stable
set search_path = ''
as $$
declare
  v_items jsonb := public.resolve_booking_items(p_items, p_buyer);
  v_make  uuid;
begin
  if p_place is null then raise exception 'INVALID_PLACE' using errcode = '22023'; end if;
  if p_place = 'CUSTOMER_LOCATION' and p_point is null then
    raise exception 'ADDRESS_REQUIRED' using errcode = '22023';
  end if;
  if p_variant_id is not null then
    select md.make_id into v_make from public.vehicle_variants v join public.vehicle_models md on md.id = v.model_id
    where v.id = p_variant_id;
    if v_make is null then raise exception 'VARIANT_NOT_FOUND' using errcode = 'P0002'; end if;
  end if;
  return jsonb_build_object(
    'items', v_items,
    'job_type_ids', (select jsonb_agg(distinct x ->> 'job_type_id') from jsonb_array_elements(v_items) x),
    'duration_min', least((select sum((x ->> 'minutes')::integer) from jsonb_array_elements(v_items) x), 720),
    'make_id', v_make,
    'travel_fee_sdg', case when p_place = 'CUSTOMER_LOCATION' then public.travel_fee(p_point) else 0 end,
    'booking_fee_sdg', public.setting_int('booking_fee_sdg'),
    'mobile_deposit_sdg', case when p_place = 'CUSTOMER_LOCATION' then public.setting_int('mobile_deposit_sdg') else 0 end);
end
$$;

create function public.jsonb_uuids(p jsonb)
returns uuid[]
language sql
immutable
set search_path = ''
as $$
  select coalesce(array_agg(x::uuid), '{}') from jsonb_array_elements_text(coalesce(p, '[]')) x;
$$;

-- ------------------------------------------------------------------ booking options
-- What the `booking-slots` Edge Function needs to run the slot engine (PLAN §5): the job
-- (duration, fees) and every technician who suits it, with their public profile, labour
-- price, weekly hours, time off and busy blocks over the next booking_lookahead_days.
-- Only the caller's own items are resolved; guests can look too (D-052). For a mobile job,
-- give a saved address (p_address_id) or a point (p_lat, p_lng).
create function public.booking_context(
  p_items         jsonb,
  p_place         public.booking_place,
  p_address_id    uuid default null,
  p_lat           double precision default null,
  p_lng           double precision default null,
  p_variant_id    uuid default null,
  p_technician_id uuid default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_point extensions.geography;
  v_quote jsonb;
  v_types uuid[];
  v_days  integer := public.setting_int('booking_lookahead_days')::integer;
  v_until timestamptz;
begin
  if p_address_id is not null then
    select a.location into v_point from public.addresses a where a.id = p_address_id and a.user_id = auth.uid();
    if v_point is null then raise exception 'ADDRESS_NOT_FOUND' using errcode = 'P0002'; end if;
  elsif p_lat is not null and p_lng is not null then
    v_point := extensions.st_setsrid(extensions.st_makepoint(p_lng, p_lat), 4326)::extensions.geography;
  end if;
  v_quote := public.booking_quote(p_items, p_place, v_point, p_variant_id, auth.uid());
  v_types := public.jsonb_uuids(v_quote -> 'job_type_ids');
  v_until := now() + make_interval(days => v_days + 1);

  return v_quote - 'items'
    || jsonb_build_object(
         'items', (select jsonb_agg(x - 'listing_id' - 'offer_id' - 'order_item_id') from jsonb_array_elements(v_quote -> 'items') x),
         'now', now(),
         'settings', jsonb_build_object(
           'grid_min', 30, 'tz_offset_min', 120, 'horizon_days', v_days,
           'travel_buffer_min', public.setting_int('travel_buffer_minutes'),
           'part_ready_buffer_min', public.setting_int('part_ready_buffer_minutes')),
         'technicians', coalesce((
           select jsonb_agg(jsonb_build_object(
             'id', t.id, 'name', p.display_name, 'avatar_key', t.avatar_key, 'verified', t.verified,
             'rating_avg', t.rating_avg, 'rating_count', t.rating_count, 'completed_jobs', t.completed_jobs,
             'years_experience', t.years_experience, 'bio_ar', t.bio_ar, 'bio_en', t.bio_en,
             'work_mode', t.work_mode, 'radius_km', t.radius_km,
             'distance_km', case when p_place = 'CUSTOMER_LOCATION'
                                 then round((extensions.st_distance(t.home_point, v_point) / 1000.0)::numeric, 1) end,
             'bay', case when p_place = 'BAY' then (
                       select jsonb_build_object('shop_id', s.id, 'name_ar', s.name_ar, 'name_en', s.name_en,
                                                 'plot_no', s.plot_no, 'zone_id', s.zone_id)
                       from public.shops s where s.id = t.home_bay_shop_id) end,
             'labour_sdg', public.tech_labour(t.id, v_types),
             'rules', coalesce((select jsonb_agg(jsonb_build_object('weekday', r.weekday, 'start_min', r.start_min,
                                                                    'end_min', r.end_min, 'modes', r.modes))
                                from public.availability_rules r where r.technician_id = t.id), '[]'),
             'time_off', coalesce((select jsonb_agg(jsonb_build_array(lower(o.period), upper(o.period)))
                                   from public.time_off o
                                   where o.technician_id = t.id and o.period && tstzrange(now(), v_until)), '[]'),
             'busy', coalesce((select jsonb_agg(jsonb_build_array(b.block_from, b.block_to))
                               from public.bookings b
                               where b.technician_id = t.id and public.booking_is_active(b.status)
                                 and not (b.status = 'HELD' and b.hold_expires_at < now())
                                 and b.block_to > now() and b.block_from < v_until), '[]'))
             order by t.rating_avg desc, t.completed_jobs desc)
           from public.technicians t join public.profiles p on p.id = t.user_id
           where (p_technician_id is null or t.id = p_technician_id)
             and public.tech_suits(t.id, v_types, (v_quote ->> 'make_id')::uuid, p_place, v_point)), '[]'));
end
$$;

-- ------------------------------------------------------------------ booking json
-- One booking as its buyer, its technician or an admin sees it. Only the buyer gets the
-- job code; the technician gets the buyer's phone and directions.
create function public.booking_json(p_booking_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select to_jsonb(b) - 'point'
    || jsonb_build_object(
         'order_ref', (select o.ref from public.orders o where o.id = b.order_id),
         'job_code', case when b.buyer_id = auth.uid() then (select c.code from public.booking_codes c where c.booking_id = b.id) end,
         'job_code_locked', (select c.locked_at is not null from public.booking_codes c where c.booking_id = b.id),
         'technician', (select jsonb_build_object(
                          'id', t.id, 'name', tp.display_name, 'avatar_key', t.avatar_key, 'verified', t.verified,
                          'rating_avg', t.rating_avg, 'rating_count', t.rating_count,
                          'phone', case when b.status in ('ACCEPTED', 'EN_ROUTE', 'IN_PROGRESS') or auth.uid() <> b.buyer_id
                                        then tp.phone end)
                        from public.technicians t join public.profiles tp on tp.id = t.user_id where t.id = b.technician_id),
         'buyer', case when auth.uid() <> b.buyer_id then (
                    select jsonb_build_object('name', bp.display_name, 'phone', bp.phone)
                    from public.profiles bp where bp.id = b.buyer_id) end,
         'bay', (select jsonb_build_object('shop_id', s.id, 'name_ar', s.name_ar, 'name_en', s.name_en,
                                           'plot_no', s.plot_no, 'zone_id', s.zone_id, 'lat', s.lat, 'lng', s.lng)
                 from public.shops s where s.id = b.bay_shop_id),
         'items', coalesce((select jsonb_agg(to_jsonb(i) - 'booking_id' order by i.title_ar)
                            from public.booking_items i where i.booking_id = b.id), '[]'),
         'events', coalesce((select jsonb_agg(jsonb_build_object('from', e.from_status, 'to', e.to_status,
                                                                 'actor', e.actor_kind, 'at', e.at, 'reason', e.reason)
                                              order by e.at, e.id)
                             from public.booking_events e where e.booking_id = b.id), '[]'),
         'photos', coalesce((select jsonb_agg(jsonb_build_object('id', ph.id, 'kind', ph.kind, 'image_key', ph.image_key,
                                                                 'taken_at', ph.taken_at) order by ph.taken_at)
                             from public.booking_photos ph where ph.booking_id = b.id), '[]'),
         'offer', (select jsonb_build_object('id', f.id, 'status', f.status, 'expires_at', f.expires_at)
                   from public.booking_offers f where f.booking_id = b.id and f.technician_id = b.technician_id
                   order by f.offered_at desc limit 1),
         'payments', coalesce((select jsonb_agg(jsonb_build_object('id', p.id, 'method', p.method, 'purpose', p.purpose,
                                                                   'status', p.status, 'amount_sdg', p.amount_sdg))
                               from public.payments p where p.booking_id = b.id
                                  or (p.order_id = b.order_id and p.method = 'BANKAK')), '[]'))
  from public.bookings b
  where b.id = p_booking_id;
$$;

-- ------------------------------------------------------------------ offers
-- Offers the job to the booking's current technician (D-024), for tech_accept_timeout_minutes.
create function public.offer_booking(p_booking_id uuid)
returns void
language plpgsql
set search_path = ''
as $$
declare
  b public.bookings;
begin
  select * into b from public.bookings where id = p_booking_id;
  update public.booking_offers set status = 'WITHDRAWN', responded_at = now()
   where booking_id = b.id and status = 'OFFERED';
  insert into public.booking_offers (booking_id, technician_id, expires_at)
  values (b.id, b.technician_id, now() + make_interval(mins => public.setting_int('tech_accept_timeout_minutes')::integer));
  perform public.notify_partner((select t.user_id from public.technicians t where t.id = b.technician_id), 'NEW_JOB_OFFER',
                        jsonb_build_object('booking_id', b.id, 'ref', b.ref, 'start_at', b.start_at, 'place', b.place));
end
$$;

-- The best other technician who suits the job and is free for the same time window and
-- hasn't been asked yet; null if nobody is. Ranked as PLAN §5.
create function public.next_technician(p_booking_id uuid)
returns uuid
language sql
stable
set search_path = ''
as $$
  with b as (select * from public.bookings where id = p_booking_id),
  types as (select coalesce(array_agg(distinct i.job_type_id), '{}') as ids
            from public.booking_items i where i.booking_id = p_booking_id),
  c as (
    select t.id, t.rating_avg, t.completed_jobs,
           case when b.place = 'CUSTOMER_LOCATION'
                then greatest(0, 1 - extensions.st_distance(t.home_point, b.point) / (t.radius_km * 1000.0)) else 1 end as closeness
    from public.technicians t, b, types
    where t.id <> b.technician_id
      and not exists (select 1 from public.booking_offers f where f.booking_id = b.id and f.technician_id = t.id)
      and public.tech_suits(t.id, types.ids, b.make_id, b.place, b.point)
      and public.tech_free(t.id, b.place, b.start_at, b.end_at, b.block_from, b.block_to, b.id))
  select c.id from c
  order by 0.5 * least(c.rating_avg, 5) / 5
         + 0.3 * coalesce(ln(c.completed_jobs + 1) / nullif(ln(max(c.completed_jobs) over () + 1), 0), 0)
         + 0.2 * c.closeness desc,
           c.completed_jobs desc, c.id
  limit 1;
$$;

-- Moves the job to the next technician for the same time (keeping the buyer's price,
-- D-010), or to NEEDS_RESCHEDULE when nobody is free (D-024).
create function public.reassign_booking(p_booking_id uuid, p_actor text, p_reason text)
returns public.booking_status
language plpgsql
set search_path = ''
as $$
declare
  b      public.bookings;
  v_next uuid;
  v_bay  uuid;
begin
  select * into b from public.bookings where id = p_booking_id for update;
  loop
    v_next := public.next_technician(b.id);
    exit when v_next is null;
    select t.home_bay_shop_id into v_bay from public.technicians t where t.id = v_next;
    begin
      update public.bookings
         set technician_id = v_next, assignment_mode = 'ANY',
             bay_shop_id = case when place = 'BAY' then v_bay else bay_shop_id end
       where id = b.id;
      exit;
    exception when exclusion_violation then
      -- Taken a moment ago: record the miss so the next pass skips them.
      insert into public.booking_offers (booking_id, technician_id, status, expires_at, responded_at, reason)
      values (b.id, v_next, 'WITHDRAWN', now(), now(), 'SLOT_TAKEN');
    end;
  end loop;

  if v_next is null then
    perform public.transition_booking(b.id, 'NEEDS_RESCHEDULE', p_actor, p_reason);
    return 'NEEDS_RESCHEDULE';
  end if;
  if b.status = 'PENDING_TECH_ACCEPT' then
    perform public.offer_booking(b.id);
  else
    perform public.transition_booking(b.id, 'PENDING_TECH_ACCEPT', p_actor, p_reason);
  end if;
  perform public.notify(b.buyer_id, 'BOOKING_REASSIGNED', jsonb_build_object('booking_id', b.id, 'ref', b.ref));
  return 'PENDING_TECH_ACCEPT';
end
$$;

-- ------------------------------------------------------------------ transitions
-- Moves a booking to `p_to` as `p_actor` (BUYER, TECH, SHOP, ADMIN, SYSTEM), records the
-- event and applies the side effects: offers, money (settle_booking), the parts bought
-- for the job (booking_parts_follow) and notifications.
create function public.transition_booking(p_id uuid, p_to public.booking_status, p_actor text, p_reason text default null)
returns public.booking_status
language plpgsql
set search_path = ''
as $$
declare
  v_from public.booking_status;
  b      public.bookings;
  v_tech uuid;
  v_info jsonb;
begin
  select x.status into v_from from public.bookings x where x.id = p_id for update;
  if not found then raise exception 'BOOKING_NOT_FOUND' using errcode = 'P0002'; end if;

  perform set_config('app.actor', p_actor, true);
  update public.bookings set status = p_to where id = p_id;
  perform set_config('app.actor', '', true);
  insert into public.booking_events (booking_id, from_status, to_status, actor_kind, actor_id, reason)
  values (p_id, v_from, p_to, p_actor, auth.uid(), p_reason);

  select * into b from public.bookings where id = p_id;
  select t.user_id into v_tech from public.technicians t where t.id = b.technician_id;
  v_info := jsonb_build_object('booking_id', b.id, 'ref', b.ref, 'start_at', b.start_at, 'status', p_to);

  case p_to
    when 'AWAITING_PAYMENT' then
      update public.bookings set hold_expires_at = null where id = b.id;
    when 'PENDING_TECH_ACCEPT' then
      update public.bookings set hold_expires_at = null where id = b.id;
      perform public.offer_booking(b.id);
    when 'ACCEPTED' then
      update public.bookings set accepted_at = now() where id = b.id;
      perform public.notify(b.buyer_id, 'BOOKING_ACCEPTED', v_info);
      perform public.booking_parts_follow(b.id, p_to);
    when 'EN_ROUTE' then
      update public.bookings set en_route_at = now() where id = b.id;
      perform public.notify(b.buyer_id, 'TECH_EN_ROUTE', v_info);
    when 'IN_PROGRESS' then
      update public.bookings set checked_in_at = now() where id = b.id;
      delete from public.tech_locations where booking_id = b.id;
      perform public.notify(b.buyer_id, 'TECH_ARRIVED', v_info);
    when 'COMPLETED' then
      update public.bookings set completed_at = now() where id = b.id;
      update public.technicians set completed_jobs = completed_jobs + 1 where id = b.technician_id;
      perform public.settle_booking(b.id);
      perform public.booking_parts_follow(b.id, p_to);
      perform public.notify(b.buyer_id, 'BOOKING_COMPLETED', v_info);
    when 'PART_DOES_NOT_FIT' then
      update public.bookings set completed_at = now(), cancel_reason = nullif(btrim(coalesce(p_reason, '')), '')
       where id = b.id;
      perform public.settle_booking(b.id);
      perform public.booking_parts_follow(b.id, p_to);
      perform public.notify(b.buyer_id, 'PART_DOES_NOT_FIT', v_info || jsonb_build_object('reason', p_reason));
    when 'NEEDS_RESCHEDULE' then
      update public.booking_offers set status = 'WITHDRAWN', responded_at = now()
       where booking_id = b.id and status = 'OFFERED';
      perform public.notify(b.buyer_id, 'BOOKING_NEEDS_RESCHEDULE', v_info);
    else  -- EXPIRED, CANCELLED_*
      update public.bookings set cancelled_at = now(), cancel_reason = nullif(btrim(coalesce(p_reason, '')), ''),
                                 hold_expires_at = null
       where id = b.id;
      update public.booking_offers set status = 'WITHDRAWN', responded_at = now()
       where booking_id = b.id and status = 'OFFERED';
      delete from public.tech_locations where booking_id = b.id;
      if v_from <> 'HELD' then
        perform public.settle_booking(b.id);
        perform public.booking_parts_follow(b.id, p_to);
        if p_actor <> 'BUYER' then
          perform public.notify(b.buyer_id, 'BOOKING_CANCELLED', v_info || jsonb_build_object('reason', p_reason));
        end if;
        if v_from in ('PENDING_TECH_ACCEPT', 'ACCEPTED', 'EN_ROUTE', 'IN_PROGRESS') and p_actor <> 'TECH' then
          perform public.notify_partner(v_tech, 'BOOKING_CANCELLED', v_info);
        end if;
      end if;
  end case;
  return v_from;
end
$$;

-- ------------------------------------------------------------------ holds
-- The buyer holds a start time with one technician for slot_hold_minutes while checking
-- out (D-022). Everything the slot engine checked is checked again here, and the EXCLUDE
-- constraint settles races: the loser gets SLOT_TAKEN. A buyer holds one slot at a time;
-- a new hold releases the previous one. For "any available", pass the technician the
-- slot list gave that time and p_assignment_mode = 'ANY'.
create function public.create_booking_hold(
  p_technician_id   uuid,
  p_start_at        timestamptz,
  p_items           jsonb,
  p_place           public.booking_place,
  p_address_id      uuid default null,
  p_location_note   text default null,
  p_variant_id      uuid default null,
  p_assignment_mode text default 'CHOSEN',
  p_idem            uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid   uuid := public.require_user();
  v_prev  jsonb := public.idem_begin(p_idem, 'create_booking_hold');
  v_addr  public.addresses;
  v_point extensions.geography;
  v_quote jsonb;
  v_types uuid[];
  v_end   timestamptz;
  v_block tstzrange;
  v_bay   uuid;
  v_id    uuid;
  v_old   record;
  v_item  jsonb;
begin
  if v_prev is not null then return v_prev; end if;
  if p_assignment_mode not in ('CHOSEN', 'ANY') then raise exception 'INVALID_VALUE' using errcode = '22023'; end if;
  if p_place = 'CUSTOMER_LOCATION' then
    select * into v_addr from public.addresses a where a.id = p_address_id and a.user_id = v_uid;
    if v_addr.id is null then raise exception 'ADDRESS_REQUIRED' using errcode = '22023'; end if;
    v_point := v_addr.location;
  end if;
  v_quote := public.booking_quote(p_items, p_place, v_point, p_variant_id, v_uid);
  v_types := public.jsonb_uuids(v_quote -> 'job_type_ids');

  if p_start_at is null or p_start_at < public.booking_earliest()
     or p_start_at > now() + make_interval(days => public.setting_int('booking_lookahead_days')::integer + 1)
     or public.khartoum_minutes(p_start_at) % 30 <> 0 or extract(second from p_start_at) <> 0 then
    raise exception 'INVALID_START' using errcode = '22023';
  end if;
  v_end := p_start_at + make_interval(mins => (v_quote ->> 'duration_min')::integer);
  v_block := public.booking_block(p_place, p_start_at, v_end);

  if not public.tech_suits(p_technician_id, v_types, (v_quote ->> 'make_id')::uuid, p_place, v_point) then
    raise exception 'TECHNICIAN_UNSUITABLE' using errcode = '22023';
  end if;

  -- Lapsed holds stop blocking (D-022); the buyer's earlier hold is let go.
  for v_old in select x.id, x.buyer_id = v_uid as mine from public.bookings x
               where x.status = 'HELD' and (x.buyer_id = v_uid or (x.technician_id = p_technician_id and x.hold_expires_at < now()))
               for update loop
    if v_old.mine then
      perform public.transition_booking(v_old.id, 'CANCELLED_BY_BUYER', 'BUYER', 'REPLACED');
    else
      perform public.transition_booking(v_old.id, 'EXPIRED', 'SYSTEM', 'HOLD_LAPSED');
    end if;
  end loop;

  if not public.tech_free(p_technician_id, p_place, p_start_at, v_end, lower(v_block), upper(v_block)) then
    raise exception 'SLOT_TAKEN' using errcode = 'PT409';
  end if;
  select t.home_bay_shop_id into v_bay from public.technicians t where t.id = p_technician_id;

  begin
    insert into public.bookings (ref, buyer_id, technician_id, assignment_mode, place, bay_shop_id, address_id,
                                 address_snapshot, lat, lng, location_note, make_id, variant_id, start_at, end_at,
                                 block_from, block_to, duration_min, hold_expires_at, labour_sdg, travel_fee_sdg,
                                 booking_fee_sdg)
    values (public.new_ref('BOOKING'), v_uid, p_technician_id, p_assignment_mode, p_place,
            case when p_place = 'BAY' then v_bay end, v_addr.id,
            case when v_addr.id is not null then jsonb_build_object('label', v_addr.label,
                   'description_ar', v_addr.description_ar, 'lat', v_addr.lat, 'lng', v_addr.lng) end,
            v_addr.lat, v_addr.lng, nullif(btrim(coalesce(p_location_note, '')), ''),
            (v_quote ->> 'make_id')::uuid, p_variant_id, p_start_at, v_end, lower(v_block), upper(v_block),
            (v_quote ->> 'duration_min')::integer,
            now() + make_interval(mins => public.setting_int('slot_hold_minutes')::integer),
            public.tech_labour(p_technician_id, v_types), (v_quote ->> 'travel_fee_sdg')::bigint,
            (v_quote ->> 'booking_fee_sdg')::bigint)
    returning id into v_id;
  exception when exclusion_violation then
    raise exception 'SLOT_TAKEN' using errcode = 'PT409';
  end;

  insert into public.booking_events (booking_id, from_status, to_status, actor_kind, actor_id)
  values (v_id, null, 'HELD', 'BUYER', v_uid);
  insert into public.booking_codes (booking_id, code) values (v_id, lpad(floor(random() * 10000)::integer::text, 4, '0'));
  for v_item in select * from jsonb_array_elements(v_quote -> 'items') loop
    insert into public.booking_items (booking_id, listing_id, offer_id, order_item_id, part_id, category_id, job_type_id,
                                      minutes, title_ar, title_en, description)
    values (v_id, (v_item ->> 'listing_id')::uuid, (v_item ->> 'offer_id')::uuid, (v_item ->> 'order_item_id')::uuid,
            (v_item ->> 'part_id')::uuid, (v_item ->> 'category_id')::uuid, (v_item ->> 'job_type_id')::uuid,
            (v_item ->> 'minutes')::integer, v_item ->> 'title_ar', v_item ->> 'title_en', v_item ->> 'description');
  end loop;
  return public.idem_finish(p_idem, 'create_booking_hold', public.booking_json(v_id));
end
$$;

-- Lets go of a hold before checkout.
create function public.release_booking_hold(p_booking_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not exists (select 1 from public.bookings b where b.id = p_booking_id and b.buyer_id = public.require_user()
                 and b.status = 'HELD') then
    raise exception 'BOOKING_NOT_FOUND' using errcode = 'P0002';
  end if;
  perform public.transition_booking(p_booking_id, 'CANCELLED_BY_BUYER', 'BUYER', 'RELEASED');
end
$$;

-- The technician answers an offer. Declining (with a reason) passes the job to the next
-- technician for the same time, or to NEEDS_RESCHEDULE.
create function public.tech_respond_offer(p_offer_id uuid, p_accept boolean, p_reason text default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tech uuid := public.require_technician(true);
  f      public.booking_offers;
begin
  select * into f from public.booking_offers where id = p_offer_id and technician_id = v_tech for update;
  if f.id is null then raise exception 'OFFER_NOT_FOUND' using errcode = 'P0002'; end if;
  if f.status <> 'OFFERED' or f.expires_at < now() then
    raise exception 'OFFER_CLOSED' using errcode = 'PT409';
  end if;
  update public.booking_offers
     set status = case when p_accept then 'ACCEPTED' else 'DECLINED' end::public.offer_status,
         responded_at = now(), reason = nullif(btrim(coalesce(p_reason, '')), '')
   where id = f.id;
  if p_accept then
    perform public.transition_booking(f.booking_id, 'ACCEPTED', 'TECH');
  else
    perform public.reassign_booking(f.booking_id, 'TECH', coalesce(nullif(btrim(coalesce(p_reason, '')), ''), 'DECLINED'));
  end if;
  return public.booking_json(f.booking_id);
end
$$;

-- ------------------------------------------------------------------ RLS + grants
alter table public.bookings enable row level security;
alter table public.booking_codes enable row level security;
alter table public.booking_items enable row level security;
alter table public.booking_offers enable row level security;
alter table public.booking_events enable row level security;
alter table public.booking_photos enable row level security;
alter table public.tech_locations enable row level security;
alter table public.booking_transitions enable row level security;
revoke all on public.bookings, public.booking_codes, public.booking_items, public.booking_offers,
  public.booking_events, public.booking_photos, public.tech_locations, public.booking_transitions
from anon, authenticated;
grant select on public.bookings, public.booking_codes, public.booking_items, public.booking_offers,
  public.booking_events, public.booking_photos, public.tech_locations, public.booking_transitions to authenticated;

create function public.can_see_booking(p_booking_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select 1 from public.bookings b
                 where b.id = p_booking_id
                   and (b.buyer_id = auth.uid()
                        or b.technician_id = public.my_technician_id()
                        or public.is_admin()));
$$;

create policy bookings_read on public.bookings for select to authenticated
  using (buyer_id = (select auth.uid()) or technician_id = (select public.my_technician_id()) or (select public.is_admin()));
-- The job code: the buyer only (D-028), and admins.
create policy booking_codes_read on public.booking_codes for select to authenticated
  using (exists (select 1 from public.bookings b where b.id = booking_id and b.buyer_id = (select auth.uid()))
         or (select public.is_admin()));
create policy booking_items_read on public.booking_items for select to authenticated
  using (public.can_see_booking(booking_id));
create policy booking_events_read on public.booking_events for select to authenticated
  using (public.can_see_booking(booking_id));
create policy booking_photos_read on public.booking_photos for select to authenticated
  using (public.can_see_booking(booking_id));
-- Offers: the technician they were made to, and admins.
create policy booking_offers_read on public.booking_offers for select to authenticated
  using (technician_id = (select public.my_technician_id()) or (select public.is_admin()));
-- The live position: the booking's buyer only while EN_ROUTE (D-029); the technician; admins.
create policy tech_locations_read on public.tech_locations for select to authenticated
  using (technician_id = (select public.my_technician_id())
         or (select public.is_admin())
         or exists (select 1 from public.bookings b where b.id = booking_id and b.buyer_id = (select auth.uid())
                    and b.status = 'EN_ROUTE'));
create policy booking_transitions_read on public.booking_transitions for select to authenticated using (true);

revoke all on function
  public.booking_transition_allowed(public.booking_status, public.booking_status, text),
  public.tg_booking_status_guard(), public.booking_is_active(public.booking_status),
  public.khartoum_minutes(timestamptz), public.khartoum_weekday(timestamptz), public.booking_earliest(),
  public.travel_fee(extensions.geography), public.resolve_booking_items(jsonb, uuid),
  public.tech_labour(uuid, uuid[]),
  public.tech_suits(uuid, uuid[], uuid, public.booking_place, extensions.geography),
  public.tech_free(uuid, public.booking_place, timestamptz, timestamptz, timestamptz, timestamptz, uuid),
  public.booking_block(public.booking_place, timestamptz, timestamptz),
  public.booking_quote(jsonb, public.booking_place, extensions.geography, uuid, uuid), public.jsonb_uuids(jsonb),
  public.booking_context(jsonb, public.booking_place, uuid, double precision, double precision, uuid, uuid),
  public.booking_json(uuid), public.offer_booking(uuid), public.next_technician(uuid),
  public.reassign_booking(uuid, text, text),
  public.transition_booking(uuid, public.booking_status, text, text),
  public.create_booking_hold(uuid, timestamptz, jsonb, public.booking_place, uuid, text, uuid, text, uuid),
  public.release_booking_hold(uuid), public.tech_respond_offer(uuid, boolean, text), public.can_see_booking(uuid)
from public, anon, authenticated;

grant execute on function
  public.booking_context(jsonb, public.booking_place, uuid, double precision, double precision, uuid, uuid)
to anon, authenticated;
grant execute on function
  public.can_see_booking(uuid),
  public.create_booking_hold(uuid, timestamptz, jsonb, public.booking_place, uuid, text, uuid, text, uuid),
  public.release_booking_hold(uuid), public.tech_respond_offer(uuid, boolean, text)
to authenticated;
