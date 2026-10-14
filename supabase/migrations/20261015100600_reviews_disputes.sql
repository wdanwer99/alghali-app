-- M3 reviews and disputes. Buyers rate the shop for each sub-order and the technician
-- for each fitting (separately, brief §3.10); ratings feed the shop and technician
-- averages that rank technicians (PLAN §5). Disputes are tickets between the parties
-- of an order or fitting and the admins.

-- ------------------------------------------------------------------ reviews
create table public.reviews (
  id            uuid primary key default gen_random_uuid(),
  author_id     uuid not null references auth.users (id) on delete cascade,
  sub_order_id  uuid references public.sub_orders (id) on delete cascade,
  booking_id    uuid references public.bookings (id) on delete cascade,
  shop_id       uuid references public.shops (id) on delete cascade,
  technician_id uuid references public.technicians (id) on delete cascade,
  rating        smallint not null check (rating between 1 and 5),
  comment       text check (char_length(comment) <= 500),
  hidden_at     timestamptz,                -- hidden by an admin; not counted
  hidden_reason text check (char_length(hidden_reason) <= 300),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  check ((shop_id is not null and sub_order_id is not null and technician_id is null and booking_id is null)
      or (technician_id is not null and booking_id is not null and shop_id is null and sub_order_id is null))
);
create unique index reviews_one_per_sub_order on public.reviews (author_id, sub_order_id) where sub_order_id is not null;
create unique index reviews_one_per_booking on public.reviews (author_id, booking_id) where booking_id is not null;
create index reviews_shop_idx on public.reviews (shop_id, created_at desc) where shop_id is not null;
create index reviews_tech_idx on public.reviews (technician_id, created_at desc) where technician_id is not null;
create trigger reviews_updated_at before update on public.reviews
  for each row execute function public.tg_set_updated_at();

-- Keeps rating_avg / rating_count of the shop or technician current.
create function public.tg_reviews_rollup()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_shop uuid := coalesce(new.shop_id, old.shop_id);
  v_tech uuid := coalesce(new.technician_id, old.technician_id);
begin
  if v_shop is not null then
    update public.shops s set
      rating_avg = coalesce((select round(avg(r.rating), 2) from public.reviews r where r.shop_id = v_shop and r.hidden_at is null), 0),
      rating_count = (select count(*) from public.reviews r where r.shop_id = v_shop and r.hidden_at is null)
    where s.id = v_shop;
  end if;
  if v_tech is not null then
    update public.technicians t set
      rating_avg = coalesce((select round(avg(r.rating), 2) from public.reviews r where r.technician_id = v_tech and r.hidden_at is null), 0),
      rating_count = (select count(*) from public.reviews r where r.technician_id = v_tech and r.hidden_at is null)
    where t.id = v_tech;
  end if;
  return null;
end
$$;
create trigger reviews_rollup after insert or update or delete on public.reviews
  for each row execute function public.tg_reviews_rollup();

-- The buyer rates a shop for a sub-order they received, or a technician for a fitting
-- that finished. Rating again within 30 days changes the review.
create function public.create_review(
  p_rating       integer,
  p_sub_order_id uuid default null,
  p_booking_id   uuid default null,
  p_comment      text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid  uuid := public.require_user();
  v_shop uuid;
  v_tech uuid;
  r      public.reviews;
begin
  if num_nonnulls(p_sub_order_id, p_booking_id) <> 1 then raise exception 'INVALID_VALUE' using errcode = '22023'; end if;
  if p_rating is null or p_rating not between 1 and 5 then raise exception 'INVALID_RATING' using errcode = '22023'; end if;
  if p_sub_order_id is not null then
    select s.shop_id into v_shop from public.sub_orders s join public.orders o on o.id = s.order_id
    where s.id = p_sub_order_id and o.buyer_id = v_uid
      and s.status in ('PICKED_UP', 'DELIVERED', 'COMPLETED', 'RETURN_REQUESTED', 'RETURNED');
    if v_shop is null then raise exception 'NOT_REVIEWABLE' using errcode = 'PT409'; end if;
  else
    select b.technician_id into v_tech from public.bookings b
    where b.id = p_booking_id and b.buyer_id = v_uid and b.status in ('COMPLETED', 'PART_DOES_NOT_FIT');
    if v_tech is null then raise exception 'NOT_REVIEWABLE' using errcode = 'PT409'; end if;
  end if;

  select * into r from public.reviews x
  where x.author_id = v_uid and (x.sub_order_id = p_sub_order_id or x.booking_id = p_booking_id) for update;
  if r.id is not null then
    if r.created_at < now() - interval '30 days' then raise exception 'REVIEW_LOCKED' using errcode = 'PT409'; end if;
    update public.reviews set rating = p_rating, comment = nullif(btrim(coalesce(p_comment, '')), '')
     where id = r.id returning * into r;
  else
    insert into public.reviews (author_id, sub_order_id, booking_id, shop_id, technician_id, rating, comment)
    values (v_uid, p_sub_order_id, p_booking_id, v_shop, v_tech, p_rating, nullif(btrim(coalesce(p_comment, '')), ''))
    returning * into r;
    if v_shop is not null then
      perform public.notify_shop(v_shop, 'NEW_REVIEW', jsonb_build_object('review_id', r.id, 'rating', p_rating));
    else
      perform public.notify_partner((select t.user_id from public.technicians t where t.id = v_tech), 'NEW_REVIEW',
                                    jsonb_build_object('review_id', r.id, 'rating', p_rating));
    end if;
  end if;
  return to_jsonb(r) - 'author_id';
exception
  when check_violation then raise exception 'INVALID_VALUE' using errcode = '22023';
end
$$;

-- Public reviews of a shop or a technician, newest first, with the author's first name.
create function public.reviews_for(p_shop_id uuid default null, p_technician_id uuid default null, p_limit integer default 20)
returns setof jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object('id', r.id, 'rating', r.rating, 'comment', r.comment, 'created_at', r.created_at,
                            'author', split_part(coalesce(nullif(p.display_name, ''), '…'), ' ', 1))
  from public.reviews r join public.profiles p on p.id = r.author_id
  where r.hidden_at is null
    and ((p_shop_id is not null and r.shop_id = p_shop_id) or (p_technician_id is not null and r.technician_id = p_technician_id))
  order by r.created_at desc
  limit least(greatest(coalesce(p_limit, 20), 1), 100);
$$;

create function public.admin_hide_review(p_review_id uuid, p_hidden boolean, p_reason text default null)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.require_admin();
  if p_hidden and nullif(btrim(coalesce(p_reason, '')), '') is null then
    raise exception 'REASON_REQUIRED' using errcode = '22023';
  end if;
  update public.reviews set hidden_at = case when p_hidden then now() end,
                            hidden_reason = case when p_hidden then btrim(p_reason) end
   where id = p_review_id;
  if not found then raise exception 'REVIEW_NOT_FOUND' using errcode = 'P0002'; end if;
  perform public.audit(case when p_hidden then 'HIDE' else 'SHOW' end, 'review', p_review_id::text,
                       jsonb_build_object('reason', p_reason));
end
$$;

-- A technician's public profile: what a buyer sees before choosing them.
create function public.technician_profile(p_technician_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'id', t.id, 'name', p.display_name, 'avatar_key', t.avatar_key, 'verified', t.verified,
    'rating_avg', t.rating_avg, 'rating_count', t.rating_count, 'completed_jobs', t.completed_jobs,
    'years_experience', t.years_experience, 'bio_ar', t.bio_ar, 'bio_en', t.bio_en,
    'work_mode', t.work_mode, 'radius_km', t.radius_km,
    'bay', (select jsonb_build_object('shop_id', s.id, 'name_ar', s.name_ar, 'name_en', s.name_en,
                                      'plot_no', s.plot_no, 'zone_id', s.zone_id)
            from public.shops s where s.id = t.home_bay_shop_id),
    'job_types', coalesce((select jsonb_agg(jsonb_build_object('job_type_id', j.id, 'code', j.code,
                                    'name_ar', j.name_ar, 'name_en', j.name_en, 'labour_sdg', tj.labour_sdg) order by j.sort)
                           from public.technician_job_types tj join public.job_types j on j.id = tj.job_type_id
                           where tj.technician_id = t.id), '[]'),
    'make_ids', coalesce((select jsonb_agg(m.make_id) from public.technician_makes m where m.technician_id = t.id), '[]'),
    'reviews', coalesce((select jsonb_agg(x) from public.reviews_for(null, t.id, 10) x), '[]'))
  from public.technicians t join public.profiles p on p.id = t.user_id
  where t.id = p_technician_id and t.status = 'APPROVED';
$$;

-- ------------------------------------------------------------------ disputes
create table public.disputes (
  id            uuid primary key default gen_random_uuid(),
  opened_by     uuid not null references auth.users (id) on delete cascade,
  opener_role   text not null check (opener_role in ('BUYER', 'SHOP', 'TECH')),
  sub_order_id  uuid references public.sub_orders (id) on delete cascade,
  booking_id    uuid references public.bookings (id) on delete cascade,
  category      text not null check (category in ('NOT_RECEIVED', 'WRONG_PART', 'DAMAGED', 'NOT_FITTED',
                                                  'PAYMENT', 'BEHAVIOUR', 'OTHER')),
  description   text not null check (char_length(btrim(description)) between 10 and 2000),
  status        text not null default 'OPEN' check (status in ('OPEN', 'IN_REVIEW', 'RESOLVED', 'REJECTED')),
  assigned_to   uuid references auth.users (id) on delete set null,
  resolution    text check (char_length(resolution) <= 1000),
  resolved_at   timestamptz,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  check (num_nonnulls(sub_order_id, booking_id) = 1),
  check ((status in ('RESOLVED', 'REJECTED')) = (resolution is not null and resolved_at is not null))
);
create index disputes_status_idx on public.disputes (status, created_at);
create unique index disputes_one_open on public.disputes (opened_by, coalesce(sub_order_id, booking_id))
  where status in ('OPEN', 'IN_REVIEW');
create trigger disputes_updated_at before update on public.disputes
  for each row execute function public.tg_set_updated_at();

create table public.dispute_messages (
  id         uuid primary key default gen_random_uuid(),
  dispute_id uuid not null references public.disputes (id) on delete cascade,
  sender_id  uuid not null references auth.users (id) on delete cascade,
  from_admin boolean not null default false,
  body       text not null check (char_length(btrim(body)) between 1 and 2000),
  created_at timestamptz not null default now()
);
create index dispute_messages_dispute_idx on public.dispute_messages (dispute_id, created_at);

-- The buyer, the shop's members (sub-order) or the technician (booking), and admins.
create function public.dispute_parties(p_dispute_id uuid)
returns setof uuid
language sql
stable
security definer
set search_path = ''
as $$
  select o.buyer_id from public.disputes d join public.sub_orders s on s.id = d.sub_order_id
    join public.orders o on o.id = s.order_id where d.id = p_dispute_id
  union
  select m.user_id from public.disputes d join public.sub_orders s on s.id = d.sub_order_id
    join public.shop_members m on m.shop_id = s.shop_id where d.id = p_dispute_id
  union
  select b.buyer_id from public.disputes d join public.bookings b on b.id = d.booking_id where d.id = p_dispute_id
  union
  select t.user_id from public.disputes d join public.bookings b on b.id = d.booking_id
    join public.technicians t on t.id = b.technician_id where d.id = p_dispute_id;
$$;

create function public.can_see_dispute(p_dispute_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.is_admin() or auth.uid() in (select public.dispute_parties(p_dispute_id));
$$;

create function public.dispute_json(p_dispute_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select to_jsonb(d)
    || jsonb_build_object(
         'ref', coalesce((select o.ref from public.sub_orders s join public.orders o on o.id = s.order_id where s.id = d.sub_order_id),
                         (select b.ref from public.bookings b where b.id = d.booking_id)),
         'opener_name', (select p.display_name from public.profiles p where p.id = d.opened_by),
         'messages', coalesce((select jsonb_agg(jsonb_build_object(
                                        'id', m.id, 'body', m.body, 'from_admin', m.from_admin, 'at', m.created_at,
                                        'mine', m.sender_id = auth.uid(),
                                        'sender', case when m.from_admin then null
                                                       else (select p.display_name from public.profiles p where p.id = m.sender_id) end)
                                      order by m.created_at)
                               from public.dispute_messages m where m.dispute_id = d.id), '[]'))
  from public.disputes d where d.id = p_dispute_id;
$$;

-- Opened by the buyer, a member of the shop (sub-order) or the technician (booking).
create function public.open_dispute(
  p_category     text,
  p_description  text,
  p_sub_order_id uuid default null,
  p_booking_id   uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid  uuid := public.require_user();
  v_role text;
  v_id   uuid;
begin
  if num_nonnulls(p_sub_order_id, p_booking_id) <> 1 then raise exception 'INVALID_VALUE' using errcode = '22023'; end if;
  if p_sub_order_id is not null then
    select case when o.buyer_id = v_uid then 'BUYER' when public.is_shop_member(s.shop_id) then 'SHOP' end into v_role
    from public.sub_orders s join public.orders o on o.id = s.order_id where s.id = p_sub_order_id;
  else
    select case when b.buyer_id = v_uid then 'BUYER' when b.technician_id = public.my_technician_id() then 'TECH' end into v_role
    from public.bookings b where b.id = p_booking_id;
  end if;
  if v_role is null then raise exception 'NOT_FOUND' using errcode = 'P0002'; end if;
  insert into public.disputes (opened_by, opener_role, sub_order_id, booking_id, category, description)
  values (v_uid, v_role, p_sub_order_id, p_booking_id, p_category, btrim(p_description))
  returning id into v_id;
  perform public.notify_admins('DISPUTE_OPENED', jsonb_build_object('dispute_id', v_id, 'category', p_category));
  return public.dispute_json(v_id);
exception
  when unique_violation then raise exception 'DISPUTE_EXISTS' using errcode = 'PT409';
  when check_violation then raise exception 'INVALID_DISPUTE' using errcode = '22023', detail = sqlerrm;
end
$$;

-- A party or an admin adds a message; everyone else involved is told.
create function public.dispute_reply(p_dispute_id uuid, p_body text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid   uuid := public.require_user();
  v_admin boolean := public.is_admin();
  d       public.disputes;
  v_party uuid;
begin
  select * into d from public.disputes where id = p_dispute_id;
  if d.id is null or not public.can_see_dispute(d.id) then raise exception 'NOT_FOUND' using errcode = 'P0002'; end if;
  if d.status in ('RESOLVED', 'REJECTED') then raise exception 'DISPUTE_CLOSED' using errcode = 'PT409'; end if;
  insert into public.dispute_messages (dispute_id, sender_id, from_admin, body)
  values (d.id, v_uid, v_admin and v_uid not in (select public.dispute_parties(d.id)), btrim(coalesce(p_body, '')));
  for v_party in select x from public.dispute_parties(d.id) x where x <> v_uid loop
    insert into public.notifications (user_id, code, payload, app)
    values (v_party, 'DISPUTE_REPLY', jsonb_build_object('dispute_id', d.id),
            case when v_party = d.opened_by and d.opener_role <> 'BUYER' then 'partner'
                 when exists (select 1 from public.orders o join public.sub_orders s on s.order_id = o.id
                              where s.id = d.sub_order_id and o.buyer_id = v_party)
                   or exists (select 1 from public.bookings b where b.id = d.booking_id and b.buyer_id = v_party)
                   then 'buyer'
                 else 'partner' end);
  end loop;
  if not v_admin then
    update public.disputes set updated_at = now() where id = d.id;
  end if;
  return public.dispute_json(d.id);
exception
  when check_violation then raise exception 'INVALID_VALUE' using errcode = '22023';
end
$$;

-- The caller's disputes (as buyer, shop member or technician), newest first.
create function public.my_disputes(p_limit integer default 30)
returns setof jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select public.dispute_json(d.id) from public.disputes d
  where auth.uid() in (select public.dispute_parties(d.id))
  order by d.created_at desc
  limit least(greatest(coalesce(p_limit, 30), 1), 100);
$$;

-- Admins take a dispute (IN_REVIEW) and close it with a resolution (RESOLVED / REJECTED).
-- Money is put right with the existing tools (cancel, return, refund).
create function public.admin_update_dispute(p_dispute_id uuid, p_status text, p_resolution text default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_admin uuid := public.require_admin();
  d       public.disputes;
  v_party uuid;
begin
  select * into d from public.disputes where id = p_dispute_id for update;
  if d.id is null then raise exception 'NOT_FOUND' using errcode = 'P0002'; end if;
  if p_status not in ('IN_REVIEW', 'RESOLVED', 'REJECTED') or d.status in ('RESOLVED', 'REJECTED') then
    raise exception 'INVALID_TRANSITION' using errcode = 'PT409';
  end if;
  if p_status in ('RESOLVED', 'REJECTED') and nullif(btrim(coalesce(p_resolution, '')), '') is null then
    raise exception 'REASON_REQUIRED' using errcode = '22023';
  end if;
  update public.disputes
     set status = p_status, assigned_to = coalesce(assigned_to, v_admin),
         resolution = case when p_status in ('RESOLVED', 'REJECTED') then btrim(p_resolution) end,
         resolved_at = case when p_status in ('RESOLVED', 'REJECTED') then now() end
   where id = d.id;
  if p_status in ('RESOLVED', 'REJECTED') then
    for v_party in select x from public.dispute_parties(d.id) x loop
      perform public.notify(v_party, 'DISPUTE_RESOLVED', jsonb_build_object('dispute_id', d.id, 'resolution', btrim(p_resolution)));
    end loop;
  end if;
  perform public.audit(p_status, 'dispute', d.id::text, jsonb_build_object('resolution', p_resolution));
  return public.dispute_json(d.id);
end
$$;

-- ------------------------------------------------------------------ RLS + grants
alter table public.reviews enable row level security;
alter table public.disputes enable row level security;
alter table public.dispute_messages enable row level security;
revoke all on public.reviews, public.disputes, public.dispute_messages from anon, authenticated;
grant select on public.reviews, public.disputes, public.dispute_messages to authenticated;

-- Everyone reads reviews through reviews_for(); the table itself: the author, the
-- reviewed shop or technician, admins.
create policy reviews_read on public.reviews for select to authenticated
  using (author_id = (select auth.uid()) or public.is_shop_member(shop_id)
         or technician_id = (select public.my_technician_id()) or (select public.is_admin()));
create policy disputes_read on public.disputes for select to authenticated
  using (public.can_see_dispute(id));
create policy dispute_messages_read on public.dispute_messages for select to authenticated
  using (public.can_see_dispute(dispute_id));

revoke all on function
  public.tg_reviews_rollup(), public.create_review(integer, uuid, uuid, text),
  public.reviews_for(uuid, uuid, integer), public.admin_hide_review(uuid, boolean, text),
  public.technician_profile(uuid), public.dispute_parties(uuid), public.can_see_dispute(uuid),
  public.dispute_json(uuid), public.open_dispute(text, text, uuid, uuid), public.dispute_reply(uuid, text),
  public.my_disputes(integer), public.admin_update_dispute(uuid, text, text)
from public, anon, authenticated;

grant execute on function public.reviews_for(uuid, uuid, integer), public.technician_profile(uuid) to anon, authenticated;
grant execute on function
  public.create_review(integer, uuid, uuid, text), public.admin_hide_review(uuid, boolean, text),
  public.can_see_dispute(uuid), public.open_dispute(text, text, uuid, uuid), public.dispute_reply(uuid, text),
  public.my_disputes(integer), public.admin_update_dispute(uuid, text, text)
to authenticated;
