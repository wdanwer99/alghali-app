-- M3 job day and after: what technicians, buyers and admins do with a booking once it is
-- placed (en route with live location, check-in, photos, the job code, part does not
-- fit, cancelling and rescheduling), and the timed jobs (lapsed holds, unanswered
-- offers, reminders, the shop-acknowledgement alert).

alter table public.sub_orders add column ack_alert_at timestamptz;   -- D-020 alert sent

-- ------------------------------------------------------------------ reading
-- The caller's booking as they may see it (buyer, its technician, admin).
create function public.booking_detail(p_booking_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform public.require_user();
  if not public.can_see_booking(p_booking_id) then
    raise exception 'BOOKING_NOT_FOUND' using errcode = 'P0002';
  end if;
  return public.booking_json(p_booking_id);
end
$$;

-- The buyer's bookings, newest first (HELD ones that never reached checkout left out).
create function public.my_bookings(p_limit integer default 30, p_offset integer default 0)
returns setof jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  return query
    select public.booking_json(b.id) from public.bookings b
    where b.buyer_id = public.require_user() and b.order_id is not null
    order by b.start_at desc
    limit least(greatest(coalesce(p_limit, 30), 1), 100) offset greatest(coalesce(p_offset, 0), 0);
end
$$;

-- The technician's work: OFFERS (waiting for their answer), UPCOMING (accepted, on the
-- way, in progress) or PAST.
create function public.tech_bookings(p_scope text default 'UPCOMING', p_limit integer default 50)
returns setof jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_tech uuid := public.require_technician();
begin
  if p_scope not in ('OFFERS', 'UPCOMING', 'PAST') then raise exception 'INVALID_VALUE' using errcode = '22023'; end if;
  return query
    select public.booking_json(b.id) from public.bookings b
    where b.technician_id = v_tech
      and case p_scope
            when 'OFFERS' then b.status = 'PENDING_TECH_ACCEPT'
                               and exists (select 1 from public.booking_offers f where f.booking_id = b.id
                                           and f.technician_id = v_tech and f.status = 'OFFERED')
            when 'UPCOMING' then b.status in ('ACCEPTED', 'EN_ROUTE', 'IN_PROGRESS')
            else b.status in ('COMPLETED', 'PART_DOES_NOT_FIT', 'CANCELLED_BY_BUYER', 'CANCELLED_BY_ADMIN')
          end
    order by case when p_scope = 'PAST' then null else b.start_at end, b.start_at desc
    limit least(greatest(coalesce(p_limit, 50), 1), 200);
end
$$;

-- ------------------------------------------------------------------ technician actions
-- The technician's own active booking, locked.
create function public.require_tech_booking(p_booking_id uuid)
returns public.bookings
language plpgsql
set search_path = ''
as $$
declare
  b public.bookings;
begin
  select * into b from public.bookings where id = p_booking_id and technician_id = public.require_technician(true) for update;
  if b.id is null then raise exception 'BOOKING_NOT_FOUND' using errcode = 'P0002'; end if;
  return b;
end
$$;

-- PLAN §3.10 guard: parts bought for the job must be in the technician's hands first.
create function public.require_parts_collected(p_booking_id uuid)
returns void
language plpgsql
stable
set search_path = ''
as $$
begin
  if exists (select 1 from public.booking_sub_orders(p_booking_id) s
             where s.status not in ('HANDED_TO_TECHNICIAN', 'CANCELLED', 'REJECTED_BY_SHOP')) then
    raise exception 'PARTS_NOT_COLLECTED' using errcode = 'PT409';
  end if;
end
$$;

create function public.tech_en_route(p_booking_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  b public.bookings := public.require_tech_booking(p_booking_id);
begin
  if b.place <> 'CUSTOMER_LOCATION' then raise exception 'INVALID_TRANSITION' using errcode = 'PT409'; end if;
  perform public.require_parts_collected(b.id);
  perform public.transition_booking(b.id, 'EN_ROUTE', 'TECH');
  return public.booking_json(b.id);
end
$$;

-- While EN_ROUTE only (D-029); the buyer reads it live.
create function public.tech_update_location(p_booking_id uuid, p_lat double precision, p_lng double precision)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  b public.bookings := public.require_tech_booking(p_booking_id);
begin
  if b.status <> 'EN_ROUTE' then raise exception 'NOT_EN_ROUTE' using errcode = 'PT409'; end if;
  insert into public.tech_locations (booking_id, technician_id, lat, lng)
  values (b.id, b.technician_id, p_lat, p_lng)
  on conflict (booking_id) do update set lat = excluded.lat, lng = excluded.lng, updated_at = now();
exception
  when check_violation or not_null_violation then raise exception 'INVALID_LOCATION' using errcode = '22023';
end
$$;

-- Arrived (or the buyer arrived at the bay): the job starts. Not more than two hours early.
create function public.tech_check_in(p_booking_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  b public.bookings := public.require_tech_booking(p_booking_id);
begin
  if b.start_at > now() + interval '2 hours' then raise exception 'TOO_EARLY' using errcode = 'PT409'; end if;
  perform public.require_parts_collected(b.id);
  perform public.transition_booking(b.id, 'IN_PROGRESS', 'TECH');
  return public.booking_json(b.id);
end
$$;

-- Photos are uploaded first to booking-photos/{booking id}/…; up to 10 per booking.
create function public.tech_add_photo(p_booking_id uuid, p_kind text, p_image_key text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  b public.bookings := public.require_tech_booking(p_booking_id);
begin
  if b.status not in ('IN_PROGRESS', 'COMPLETED', 'PART_DOES_NOT_FIT') then
    raise exception 'INVALID_TRANSITION' using errcode = 'PT409';
  end if;
  if p_kind not in ('BEFORE', 'AFTER') then raise exception 'INVALID_VALUE' using errcode = '22023'; end if;
  if p_image_key is null or p_image_key not like b.id::text || '/%'
     or not exists (select 1 from storage.objects so where so.bucket_id = 'booking-photos' and so.name = p_image_key) then
    raise exception 'INVALID_IMAGE_KEY' using errcode = '22023';
  end if;
  if (select count(*) from public.booking_photos ph where ph.booking_id = b.id) >= 10 then
    raise exception 'TOO_MANY_IMAGES' using errcode = '22023';
  end if;
  insert into public.booking_photos (booking_id, kind, image_key, created_by) values (b.id, p_kind, p_image_key, auth.uid());
  return public.booking_json(b.id);
end
$$;

-- The technician types the buyer's 4-digit code to close the job (D-028). A wrong code
-- is not an error (the attempt must be counted): the answer is {ok: false, error:
-- WRONG_JOB_CODE, attempts_left}. After 5 wrong codes completion locks and admins are told.
create function public.tech_complete(p_booking_id uuid, p_code text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  b public.bookings := public.require_tech_booking(p_booking_id);
  c public.booking_codes;
begin
  if b.status <> 'IN_PROGRESS' then raise exception 'INVALID_TRANSITION' using errcode = 'PT409'; end if;
  select * into c from public.booking_codes where booking_id = b.id for update;
  if c.locked_at is not null then raise exception 'JOB_CODE_LOCKED' using errcode = 'PT409'; end if;
  if btrim(coalesce(p_code, '')) <> c.code then
    update public.booking_codes set attempts = attempts + 1,
           locked_at = case when attempts + 1 >= 5 then now() end
     where booking_id = b.id
    returning * into c;
    if c.locked_at is not null then
      perform public.notify_admins('JOB_CODE_LOCKED', jsonb_build_object('booking_id', b.id, 'ref', b.ref));
    end if;
    return jsonb_build_object('ok', false, 'error', case when c.locked_at is null then 'WRONG_JOB_CODE' else 'JOB_CODE_LOCKED' end,
                              'attempts_left', greatest(5 - c.attempts, 0));
  end if;
  perform public.transition_booking(b.id, 'COMPLETED', 'TECH');
  return jsonb_build_object('ok', true, 'booking', public.booking_json(b.id));
end
$$;

-- At check-in the part turns out not to fit: the buyer pays the travel fee only and the
-- parts bought for the job go back as a return (D-019).
create function public.tech_part_not_fit(p_booking_id uuid, p_reason text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  b public.bookings := public.require_tech_booking(p_booking_id);
begin
  if nullif(btrim(coalesce(p_reason, '')), '') is null then raise exception 'REASON_REQUIRED' using errcode = '22023'; end if;
  perform public.transition_booking(b.id, 'PART_DOES_NOT_FIT', 'TECH', btrim(p_reason));
  return public.booking_json(b.id);
end
$$;

-- The technician drops an accepted job before starting: it goes to the next technician
-- for the same time, or to NEEDS_RESCHEDULE (D-019).
create function public.tech_cancel(p_booking_id uuid, p_reason text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  b public.bookings := public.require_tech_booking(p_booking_id);
begin
  if b.status <> 'ACCEPTED' then raise exception 'INVALID_TRANSITION' using errcode = 'PT409'; end if;
  if nullif(btrim(coalesce(p_reason, '')), '') is null then raise exception 'REASON_REQUIRED' using errcode = '22023'; end if;
  if exists (select 1 from public.booking_sub_orders(b.id) s where s.status = 'HANDED_TO_TECHNICIAN') then
    raise exception 'PARTS_WITH_TECHNICIAN' using errcode = 'PT409';   -- return them first, or ask an admin
  end if;
  perform public.reassign_booking(b.id, 'TECH', 'TECH_CANCELLED: ' || btrim(p_reason));
  return jsonb_build_object('ok', true);
end
$$;

-- ------------------------------------------------------------------ buyer actions
create function public.require_buyer_booking(p_booking_id uuid)
returns public.bookings
language plpgsql
set search_path = ''
as $$
declare
  b public.bookings;
begin
  select * into b from public.bookings where id = p_booking_id and buyer_id = public.require_user() for update;
  if b.id is null then raise exception 'BOOKING_NOT_FOUND' using errcode = 'P0002'; end if;
  return b;
end
$$;

-- Free until cancel_cutoff_hours before the start; later, the booking fee and travel
-- fee are kept from what was paid upfront (D-019, D-099). While still waiting for
-- payment, the whole order is cancelled.
create function public.buyer_cancel_booking(p_booking_id uuid, p_reason text default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  b public.bookings := public.require_buyer_booking(p_booking_id);
begin
  case
    when b.status = 'HELD' then
      perform public.transition_booking(b.id, 'CANCELLED_BY_BUYER', 'BUYER', 'RELEASED');
    when b.status = 'AWAITING_PAYMENT' then
      perform public.cancel_order(b.order_id, p_reason);
    when b.status in ('PENDING_TECH_ACCEPT', 'ACCEPTED', 'EN_ROUTE', 'NEEDS_RESCHEDULE') then
      perform public.transition_booking(b.id, 'CANCELLED_BY_BUYER', 'BUYER',
                                        coalesce(nullif(btrim(coalesce(p_reason, '')), ''), 'BUYER_CANCELLED'));
    else
      raise exception 'CANNOT_CANCEL' using errcode = 'PT409';
  end case;
  return public.booking_json(b.id);
end
$$;

-- After NEEDS_RESCHEDULE the buyer picks a new start (and maybe another technician)
-- from the slot list; the job is offered again at the price already paid (D-010).
create function public.buyer_reschedule(p_booking_id uuid, p_start_at timestamptz, p_technician_id uuid default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  b       public.bookings := public.require_buyer_booking(p_booking_id);
  v_tech  uuid;
  v_end   timestamptz;
  v_block tstzrange;
  v_types uuid[];
  v_bay   uuid;
begin
  if b.status <> 'NEEDS_RESCHEDULE' then raise exception 'INVALID_TRANSITION' using errcode = 'PT409'; end if;
  v_tech := coalesce(p_technician_id, b.technician_id);
  if p_start_at is null or p_start_at < public.booking_earliest()
     or public.khartoum_minutes(p_start_at) % 30 <> 0 or extract(second from p_start_at) <> 0 then
    raise exception 'INVALID_START' using errcode = '22023';
  end if;
  select coalesce(array_agg(distinct i.job_type_id), '{}') into v_types from public.booking_items i where i.booking_id = b.id;
  if not public.tech_suits(v_tech, v_types, b.make_id, b.place, b.point) then
    raise exception 'TECHNICIAN_UNSUITABLE' using errcode = '22023';
  end if;
  v_end := p_start_at + make_interval(mins => b.duration_min);
  v_block := public.booking_block(b.place, p_start_at, v_end);
  if not public.tech_free(v_tech, b.place, p_start_at, v_end, lower(v_block), upper(v_block), b.id) then
    raise exception 'SLOT_TAKEN' using errcode = 'PT409';
  end if;
  select t.home_bay_shop_id into v_bay from public.technicians t where t.id = v_tech;
  -- Technicians asked about the old time may be free at the new one.
  delete from public.booking_offers where booking_id = b.id and status in ('DECLINED', 'TIMED_OUT', 'WITHDRAWN');
  begin
    update public.bookings
       set technician_id = v_tech, start_at = p_start_at, end_at = v_end, block_from = lower(v_block),
           block_to = upper(v_block), bay_shop_id = case when place = 'BAY' then v_bay else bay_shop_id end,
           reminded_day_at = null, reminded_hour_at = null
     where id = b.id;
    perform public.transition_booking(b.id, 'PENDING_TECH_ACCEPT', 'BUYER', 'RESCHEDULED');
  exception when exclusion_violation then
    raise exception 'SLOT_TAKEN' using errcode = 'PT409';
  end;
  return public.booking_json(b.id);
end
$$;

-- ------------------------------------------------------------------ admin actions
create function public.admin_cancel_booking(p_booking_id uuid, p_reason text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_admin uuid := public.require_admin();
begin
  if nullif(btrim(coalesce(p_reason, '')), '') is null then raise exception 'REASON_REQUIRED' using errcode = '22023'; end if;
  if not exists (select 1 from public.bookings b where b.id = p_booking_id) then
    raise exception 'BOOKING_NOT_FOUND' using errcode = 'P0002';
  end if;
  perform public.transition_booking(p_booking_id, 'CANCELLED_BY_ADMIN', 'ADMIN', btrim(p_reason));
  perform public.audit('CANCEL', 'booking', p_booking_id::text, jsonb_build_object('reason', p_reason));
  return public.booking_json(p_booking_id);
end
$$;

-- Moves a pending or accepted job to the next free technician (or NEEDS_RESCHEDULE).
create function public.admin_reassign_booking(p_booking_id uuid, p_reason text default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_admin uuid := public.require_admin();
  b       public.bookings;
begin
  select * into b from public.bookings where id = p_booking_id for update;
  if b.id is null then raise exception 'BOOKING_NOT_FOUND' using errcode = 'P0002'; end if;
  if b.status not in ('PENDING_TECH_ACCEPT', 'ACCEPTED') then raise exception 'INVALID_TRANSITION' using errcode = 'PT409'; end if;
  update public.booking_offers set status = 'WITHDRAWN', responded_at = now(), reason = 'ADMIN_REASSIGNED'
   where booking_id = b.id and status = 'OFFERED';
  if b.status = 'PENDING_TECH_ACCEPT' then
    -- The current technician counts as asked.
    insert into public.booking_offers (booking_id, technician_id, status, expires_at, responded_at, reason)
    select b.id, b.technician_id, 'WITHDRAWN', now(), now(), 'ADMIN_REASSIGNED'
    where not exists (select 1 from public.booking_offers f where f.booking_id = b.id and f.technician_id = b.technician_id);
  end if;
  perform public.reassign_booking(b.id, 'ADMIN', coalesce(nullif(btrim(coalesce(p_reason, '')), ''), 'ADMIN_REASSIGNED'));
  perform public.audit('REASSIGN', 'booking', b.id::text, jsonb_build_object('reason', p_reason));
  return public.booking_json(b.id);
end
$$;

-- Closes a job in progress, e.g. after the job code locked.
create function public.admin_complete_booking(p_booking_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_admin uuid := public.require_admin();
begin
  perform public.transition_booking(p_booking_id, 'COMPLETED', 'ADMIN');
  perform public.audit('COMPLETE', 'booking', p_booking_id::text);
  return public.booking_json(p_booking_id);
end
$$;

-- ------------------------------------------------------------------ timed jobs
-- Holds not checked out within slot_hold_minutes (D-022).
create function public.expire_booking_holds()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  b   record;
  v_n integer := 0;
begin
  for b in select x.id from public.bookings x where x.status = 'HELD' and x.hold_expires_at < now()
           for update skip locked loop
    perform public.transition_booking(b.id, 'EXPIRED', 'SYSTEM', 'HOLD_LAPSED');
    v_n := v_n + 1;
  end loop;
  return v_n;
end
$$;

-- Offers not answered in tech_accept_timeout_minutes go to the next technician (D-024);
-- jobs nobody accepted before their start need a new time; NEEDS_RESCHEDULE left for
-- 3 days expires with a full refund.
create function public.expire_booking_offers()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  f   record;
  b   record;
  v_n integer := 0;
begin
  for f in select o.id, o.booking_id from public.booking_offers o
           where o.status = 'OFFERED' and o.expires_at < now()
           for update skip locked loop
    update public.booking_offers set status = 'TIMED_OUT', responded_at = now() where id = f.id;
    if exists (select 1 from public.bookings x where x.id = f.booking_id and x.status = 'PENDING_TECH_ACCEPT') then
      if (select x.start_at from public.bookings x where x.id = f.booking_id) < now() + interval '30 minutes' then
        perform public.transition_booking(f.booking_id, 'NEEDS_RESCHEDULE', 'SYSTEM', 'NOT_ACCEPTED_IN_TIME');
      else
        perform public.reassign_booking(f.booking_id, 'SYSTEM', 'TIMED_OUT');
      end if;
    end if;
    v_n := v_n + 1;
  end loop;
  for b in select x.id from public.bookings x
           where x.status = 'NEEDS_RESCHEDULE' and x.status_changed_at < now() - interval '3 days'
           for update skip locked loop
    perform public.transition_booking(b.id, 'EXPIRED', 'SYSTEM', 'NOT_RESCHEDULED');
    v_n := v_n + 1;
  end loop;
  return v_n;
end
$$;

-- A day and an hour before an accepted job (brief §4), to the buyer and the technician.
create function public.send_booking_reminders()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  b   record;
  v_n integer := 0;
  v_code text;
begin
  for b in select x.id, x.ref, x.buyer_id, x.start_at, x.reminded_day_at, x.reminded_hour_at, t.user_id as tech_user
           from public.bookings x join public.technicians t on t.id = x.technician_id
           where x.status = 'ACCEPTED' and x.start_at > now() and x.start_at < now() + interval '24 hours'
             and (x.reminded_hour_at is null and x.start_at < now() + interval '1 hour'
                  or x.reminded_day_at is null and x.start_at >= now() + interval '1 hour')
           for update of x skip locked loop
    v_code := case when b.start_at < now() + interval '1 hour' then 'BOOKING_REMINDER_HOUR' else 'BOOKING_REMINDER_DAY' end;
    perform public.notify(b.buyer_id, v_code, jsonb_build_object('booking_id', b.id, 'ref', b.ref, 'start_at', b.start_at));
    perform public.notify_partner(b.tech_user, v_code, jsonb_build_object('booking_id', b.id, 'ref', b.ref, 'start_at', b.start_at));
    if v_code = 'BOOKING_REMINDER_HOUR' then
      update public.bookings set reminded_hour_at = now(), reminded_day_at = coalesce(reminded_day_at, now()) where id = b.id;
    else
      update public.bookings set reminded_day_at = now() where id = b.id;
    end if;
    v_n := v_n + 1;
  end loop;
  return v_n;
end
$$;

-- D-020: a confirmed sub-order the shop hasn't accepted within 30 minutes alerts the admins once.
create function public.alert_unacknowledged_orders()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  s   record;
  v_n integer := 0;
begin
  for s in select x.id, x.order_id, x.shop_id, o.ref from public.sub_orders x join public.orders o on o.id = x.order_id
           where x.status = 'CONFIRMED' and x.shop_ack_at is null and x.ack_alert_at is null
             and x.status_changed_at < now() - interval '30 minutes'
           for update of x skip locked loop
    update public.sub_orders set ack_alert_at = now() where id = s.id;
    perform public.notify_admins('SHOP_NOT_ACKNOWLEDGED',
                                 jsonb_build_object('order_id', s.order_id, 'sub_order_id', s.id, 'shop_id', s.shop_id, 'ref', s.ref));
    v_n := v_n + 1;
  end loop;
  return v_n;
end
$$;

select cron.schedule('expire-booking-holds', '* * * * *', $$select public.expire_booking_holds()$$);
select cron.schedule('expire-booking-offers', '* * * * *', $$select public.expire_booking_offers()$$);
select cron.schedule('booking-reminders', '*/5 * * * *', $$select public.send_booking_reminders()$$);
select cron.schedule('alert-unacknowledged-orders', '*/5 * * * *', $$select public.alert_unacknowledged_orders()$$);

-- Live position for the buyer's tracking screen (RLS decides who receives it).
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    alter publication supabase_realtime add table public.tech_locations;
  end if;
end
$$;

-- ------------------------------------------------------------------ storage
-- booking-photos/{booking id}/…: the booking's technician uploads; its buyer and admins read.
create policy booking_photos_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'booking-photos'
              and exists (select 1 from public.bookings b
                          where b.id = public.try_uuid((storage.foldername(name))[1])
                            and b.technician_id = (select public.my_technician_id())));
create policy booking_photos_select on storage.objects for select to authenticated
  using (bucket_id = 'booking-photos' and public.can_see_booking(public.try_uuid((storage.foldername(name))[1])));

revoke all on function
  public.booking_detail(uuid), public.my_bookings(integer, integer), public.tech_bookings(text, integer),
  public.require_tech_booking(uuid), public.require_parts_collected(uuid), public.tech_en_route(uuid),
  public.tech_update_location(uuid, double precision, double precision), public.tech_check_in(uuid),
  public.tech_add_photo(uuid, text, text), public.tech_complete(uuid, text), public.tech_part_not_fit(uuid, text),
  public.tech_cancel(uuid, text), public.require_buyer_booking(uuid), public.buyer_cancel_booking(uuid, text),
  public.buyer_reschedule(uuid, timestamptz, uuid), public.admin_cancel_booking(uuid, text),
  public.admin_reassign_booking(uuid, text), public.admin_complete_booking(uuid),
  public.expire_booking_holds(), public.expire_booking_offers(), public.send_booking_reminders(),
  public.alert_unacknowledged_orders()
from public, anon, authenticated;

grant execute on function
  public.booking_detail(uuid), public.my_bookings(integer, integer), public.tech_bookings(text, integer),
  public.tech_en_route(uuid), public.tech_update_location(uuid, double precision, double precision),
  public.tech_check_in(uuid), public.tech_add_photo(uuid, text, text), public.tech_complete(uuid, text),
  public.tech_part_not_fit(uuid, text), public.tech_cancel(uuid, text), public.buyer_cancel_booking(uuid, text),
  public.buyer_reschedule(uuid, timestamptz, uuid), public.admin_cancel_booking(uuid, text),
  public.admin_reassign_booking(uuid, text), public.admin_complete_booking(uuid)
to authenticated;
