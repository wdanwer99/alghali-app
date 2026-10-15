-- M5: what the partner app needs on top of M1–M3 (D-119, D-120).
--   * "Closed today": a shop can close until a given time without changing its weekly hours
--     (shops.closed_until, shop_set_closed); buyers see it as closed.
--   * Members read their own shop whatever its review state (shop_detail), and its sales
--     per day with the best sellers (shop_insights).

alter table public.shops add column closed_until timestamptz;

-- Open at [p_at]: inside the weekly hours and not closed for the day.
create function public.shop_open_now(p_hours jsonb, p_closed_until timestamptz, p_at timestamptz)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select (p_closed_until is null or p_closed_until <= p_at) and public.is_open_at(p_hours, p_at);
$$;

create or replace function public.shop_json(p_shop_id uuid)
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
              'open_now', public.shop_open_now(s.opening_hours, s.closed_until, now()))
  from public.shops s where s.id = p_shop_id;
$$;

create or replace function public.part_detail(p_part_id uuid, p_variant_id uuid default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_id   uuid;
  v_fit  text;
  v_part jsonb;
begin
  select coalesce(p.merged_into, p.id) into v_id from public.parts p where p.id = p_part_id;
  if v_id is null or not exists (select 1 from public.parts p where p.id = v_id and p.is_active) then
    raise exception 'PART_NOT_FOUND' using errcode = 'P0002';
  end if;

  v_fit := case when p_variant_id is null then null
                when not exists (select 1 from public.part_fitments f where f.part_id = v_id) then 'CHECK_FITMENT'
                when exists (select 1 from public.part_fitments f where f.part_id = v_id and f.variant_id = p_variant_id)
                  then 'FITS'
                else 'NO_FIT' end;

  select jsonb_build_object(
           'id', p.id, 'category_id', p.category_id, 'name_ar', p.name_ar, 'name_en', p.name_en,
           'desc_ar', p.desc_ar, 'desc_en', p.desc_en, 'oem_numbers', to_jsonb(p.oem_numbers),
           'installable', p.installable, 'is_verified', p.is_verified,
           'std_job_minutes', coalesce(p.std_job_minutes, c.std_job_minutes),
           'job_type_code', jt.code,
           'fit', v_fit,
           'fitment_model_ids', coalesce((select jsonb_agg(distinct v.model_id) from public.part_fitments f
                                          join public.vehicle_variants v on v.id = f.variant_id
                                          where f.part_id = p.id), '[]'),
           'fitment_note_ar', (select f.note_ar from public.part_fitments f
                               where f.part_id = p.id and f.variant_id = p_variant_id),
           'fitment_note_en', (select f.note_en from public.part_fitments f
                               where f.part_id = p.id and f.variant_id = p_variant_id))
    into v_part
  from public.parts p
  join public.part_categories c on c.id = p.category_id
  left join public.job_types jt on jt.id = c.job_type_id
  where p.id = v_id;

  return jsonb_build_object(
    'part', v_part,
    'listings', coalesce((
      select jsonb_agg(jsonb_build_object(
               'id', l.id, 'condition', l.condition, 'price_sdg', l.price_sdg,
               'price_on_request', l.price_on_request,
               'was_sdg', case when l.was_sdg > l.price_sdg and l.price_changed_at > now() - interval '14 days'
                               then l.was_sdg end,
               'available_qty', l.stock_qty - l.reserved_qty, 'warranty_days', l.warranty_days,
               'brand', l.brand, 'note_ar', l.note_ar, 'version', l.version,
               'images', coalesce((select jsonb_agg(i.base_key order by i.sort, i.created_at)
                                   from public.listing_images i where i.listing_id = l.id), '[]'),
               'shop', jsonb_build_object(
                  'id', s.id, 'name_ar', s.name_ar, 'name_en', s.name_en, 'zone_id', s.zone_id,
                  'plot_no', s.plot_no, 'side', s.side, 'landmark_ar', s.landmark_ar, 'landmark_en', s.landmark_en,
                  'pos_m', s.pos_m, 'verified', s.verified, 'rating_avg', s.rating_avg,
                  'rating_count', s.rating_count, 'phone', s.phone, 'whatsapp', s.whatsapp,
                  'open_now', public.shop_open_now(s.opening_hours, s.closed_until, now())))
             order by l.stock_qty - l.reserved_qty > 0 desc, l.price_sdg nulls last, s.rating_avg desc)
      from public.listings l
      join public.shops s on s.id = l.shop_id
      where l.part_id = v_id and l.is_active and l.archived_at is null and s.status = 'APPROVED'), '[]')
  );
end
$$;

-- "Closed today": closed until [p_until] (at most a week ahead); null opens the shop again.
-- Orders still come in; buyers see the shop as closed.
create function public.shop_set_closed(p_shop_id uuid, p_until timestamptz)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.require_shop_writable(p_shop_id);
  if p_until is not null and (p_until <= now() or p_until > now() + interval '7 days') then
    raise exception 'INVALID_VALUE' using errcode = '22023';
  end if;
  update public.shops set closed_until = p_until, updated_at = now() where id = p_shop_id;
  return public.shop_json(p_shop_id);
end
$$;

-- The shop as its members see it, also while PENDING, REJECTED or SUSPENDED.
create function public.shop_detail(p_shop_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform public.require_shop(p_shop_id);
  if not exists (select 1 from public.shops s where s.id = p_shop_id) then
    raise exception 'SHOP_NOT_FOUND' using errcode = 'P0002';
  end if;
  return public.shop_json(p_shop_id);
end
$$;

-- Sales per Khartoum day for the last [p_days] days (oldest first, today last), the five
-- best sellers over the same days, and the shop's rating. A sale counts from when the shop
-- can see the order (paid, or a cash order placed) until it is cancelled, refused or returned.
create function public.shop_insights(p_shop_id uuid, p_days integer default 7)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_today date := (now() at time zone 'Africa/Khartoum')::date;
  v_from  date;
  v_since timestamptz;
begin
  perform public.require_shop(p_shop_id);
  if p_days is null or p_days not between 1 and 90 then
    raise exception 'INVALID_VALUE' using errcode = '22023';
  end if;
  v_from := v_today - (p_days - 1);
  v_since := v_from::timestamp at time zone 'Africa/Khartoum';

  return jsonb_build_object(
    'days', (
      select jsonb_agg(jsonb_build_object('day', d.day, 'sales_sdg', coalesce(x.sales, 0),
                                          'orders', coalesce(x.n, 0)) order by d.day)
      from (select g::date as day from generate_series(v_from, v_today, interval '1 day') g) d
      left join (
        select (o.created_at at time zone 'Africa/Khartoum')::date as day, sum(so.items_sdg) as sales,
               count(*)::int as n
        from public.sub_orders so
        join public.orders o on o.id = so.order_id
        where so.shop_id = p_shop_id and o.created_at >= v_since
          and so.status not in ('PENDING_PAYMENT', 'PAYMENT_REVIEW', 'CANCELLED', 'REJECTED_BY_SHOP', 'RETURNED')
        group by 1) x on x.day = d.day),
    'top', coalesce((
      select jsonb_agg(t order by t.qty desc, t.sales_sdg desc)
      from (
        select (array_agg(oi.part_id))[1] as part_id, max(oi.title_ar) as title_ar,
               max(oi.title_en) as title_en, sum(oi.qty)::int as qty, sum(oi.line_sdg) as sales_sdg
        from public.order_items oi
        join public.sub_orders so on so.id = oi.sub_order_id
        join public.orders o on o.id = so.order_id
        where so.shop_id = p_shop_id and o.created_at >= v_since
          and so.status not in ('PENDING_PAYMENT', 'PAYMENT_REVIEW', 'CANCELLED', 'REJECTED_BY_SHOP', 'RETURNED')
        group by coalesce(oi.part_id::text, oi.title_ar)
        order by 4 desc, 5 desc
        limit 5) t), '[]'),
    'rating_avg', (select s.rating_avg from public.shops s where s.id = p_shop_id),
    'rating_count', (select s.rating_count from public.shops s where s.id = p_shop_id));
end
$$;

revoke all on function
  public.shop_open_now(jsonb, timestamptz, timestamptz), public.shop_set_closed(uuid, timestamptz),
  public.shop_detail(uuid), public.shop_insights(uuid, integer)
  from public, anon, authenticated;
grant execute on function
  public.shop_set_closed(uuid, timestamptz), public.shop_detail(uuid), public.shop_insights(uuid, integer)
  to authenticated;
