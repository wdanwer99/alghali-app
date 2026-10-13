-- M1 search and catalogue reads: search_parts, part_detail, suggest_parts, catalogue_snapshot.

-- Parts with their offers, grouped by part (one card per part, "from N shops").
-- Fit (when p_variant_id is given): FITS, CHECK_FITMENT (no fitment data); parts with
-- fitment data that leaves this car out are hidden. When no part matches the words exactly,
-- falls back to fuzzy (trigram) matching for typos.
-- p_sort: relevance | price_low | price_high | rating | discount | newest.
create function public.search_parts(
  p_q             text default '',
  p_variant_id    uuid default null,
  p_category_id   uuid default null,
  p_only_fits     boolean default false,
  p_conditions    public.listing_condition[] default null,
  p_price_max     bigint default null,
  p_shop_id       uuid default null,
  p_in_stock_only boolean default true,
  p_deals_only    boolean default false,
  p_sort          text default 'relevance',
  p_limit         integer default 30,
  p_offset        integer default 0
)
returns table (
  part_id              uuid,
  category_id          uuid,
  name_ar              text,
  name_en              text,
  installable          boolean,
  std_job_minutes      integer,
  is_verified          boolean,
  fit                  text,
  from_sdg             bigint,
  shop_count           integer,
  conditions           public.listing_condition[],
  best_warranty_days   integer,
  max_discount_percent integer,
  image_key            text,
  listings             jsonb,
  rank                 real,
  total_count          bigint
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_query tsquery := public.search_query(p_q);
  v_norm  text := public.ar_normalize(p_q);
  v_fuzzy boolean := false;
begin
  if coalesce(p_sort, 'relevance') not in ('relevance', 'price_low', 'price_high', 'rating', 'discount', 'newest') then
    raise exception 'INVALID_SORT' using errcode = '22023';
  end if;
  if v_query is not null and char_length(v_norm) >= 3
     and not exists (select 1 from public.part_search_docs d where d.tsv @@ v_query) then
    v_fuzzy := true;
  end if;

  return query
  with recursive cats as (
    select c.id from public.part_categories c where c.id = p_category_id
    union all
    select c.id from public.part_categories c join cats on c.parent_id = cats.id
  ),
  matched as (
    select p.id, p.category_id, p.name_ar, p.name_en, p.installable,
           coalesce(p.std_job_minutes, c.std_job_minutes) as minutes, p.is_verified, p.created_at,
           case when v_query is null then 0::real
                when v_fuzzy then extensions.word_similarity(v_norm, d.doc)
                else ts_rank(d.tsv, v_query) end as rnk,
           case when p_variant_id is null then null
                when not exists (select 1 from public.part_fitments f where f.part_id = p.id) then 'CHECK_FITMENT'
                when exists (select 1 from public.part_fitments f
                             where f.part_id = p.id and f.variant_id = p_variant_id) then 'FITS'
                else 'NO_FIT' end as fit
    from public.parts p
    join public.part_categories c on c.id = p.category_id
    left join public.part_search_docs d on d.part_id = p.id
    where p.is_active and p.merged_into is null
      and (p_category_id is null or p.category_id in (select cats.id from cats))
      and (v_query is null
           or (not v_fuzzy and d.tsv @@ v_query)
           or (v_fuzzy and extensions.word_similarity(v_norm, d.doc) >= 0.4))
  ),
  offers as (
    select l.id, l.part_id, l.shop_id, l.condition, l.price_sdg, l.price_on_request, l.was_sdg,
           l.stock_qty - l.reserved_qty as avail, l.warranty_days, l.brand, l.created_at,
           s.rating_avg, s.name_ar as shop_name_ar, s.name_en as shop_name_en, s.verified as shop_verified,
           (select i.base_key from public.listing_images i where i.listing_id = l.id
            order by i.sort, i.created_at limit 1) as img,
           case when l.was_sdg > l.price_sdg and l.price_changed_at > now() - interval '14 days'
                then round((l.was_sdg - l.price_sdg) * 100.0 / l.was_sdg)::integer end as discount
    from public.listings l
    join public.shops s on s.id = l.shop_id
    where l.is_active and l.archived_at is null and s.status = 'APPROVED'
      and l.part_id in (select m.id from matched m
                        where m.fit is distinct from 'NO_FIT' and (not coalesce(p_only_fits, false) or m.fit = 'FITS'))
      and (not coalesce(p_in_stock_only, true) or l.stock_qty - l.reserved_qty > 0)
      and (p_conditions is null or cardinality(p_conditions) = 0 or l.condition = any (p_conditions))
      and (p_price_max is null or l.price_sdg <= p_price_max)
      and (p_shop_id is null or l.shop_id = p_shop_id)
  ),
  grouped as (
    select m.id, m.category_id, m.name_ar, m.name_en, m.installable, m.minutes, m.is_verified, m.fit, m.rnk,
           min(o.price_sdg) as from_sdg,
           count(distinct o.shop_id)::integer as shop_count,
           array_agg(distinct o.condition) as conds,
           max(o.warranty_days) as best_warranty,
           max(o.discount) as max_discount,
           max(o.rating_avg) as best_rating,
           max(greatest(o.created_at, m.created_at)) as newest,
           (array_agg(o.img order by o.price_sdg nulls last) filter (where o.img is not null))[1] as img,
           to_jsonb((array_agg(jsonb_build_object(
              'id', o.id, 'shop_id', o.shop_id, 'shop_name_ar', o.shop_name_ar, 'shop_name_en', o.shop_name_en,
              'shop_verified', o.shop_verified, 'shop_rating', o.rating_avg, 'condition', o.condition,
              'price_sdg', o.price_sdg, 'price_on_request', o.price_on_request,
              'was_sdg', case when o.discount is not null then o.was_sdg end,
              'discount_percent', o.discount, 'available_qty', o.avail, 'warranty_days', o.warranty_days,
              'brand', o.brand, 'image_key', o.img)
            order by o.price_sdg nulls last, o.rating_avg desc))[1:5]) as offers_json
    from matched m
    join offers o on o.part_id = m.id
    group by m.id, m.category_id, m.name_ar, m.name_en, m.installable, m.minutes, m.is_verified, m.fit, m.rnk
    having not coalesce(p_deals_only, false) or max(o.discount) is not null
  )
  select g.id, g.category_id, g.name_ar, g.name_en, g.installable, g.minutes, g.is_verified, g.fit,
         g.from_sdg, g.shop_count, g.conds, g.best_warranty, g.max_discount, g.img, g.offers_json, g.rnk,
         count(*) over ()
  from grouped g
  order by
    case when coalesce(p_sort, 'relevance') = 'relevance' then case when g.fit = 'FITS' then 0 else 1 end end,
    case when coalesce(p_sort, 'relevance') = 'relevance' then g.rnk end desc,
    case when p_sort = 'price_low' then g.from_sdg end asc nulls last,
    case when p_sort = 'price_high' then g.from_sdg end desc nulls last,
    case when p_sort = 'rating' then g.best_rating end desc nulls last,
    case when p_sort = 'discount' then g.max_discount end desc nulls last,
    case when p_sort = 'newest' then g.newest end desc,
    g.from_sdg asc nulls last,
    g.id
  limit least(greatest(coalesce(p_limit, 30), 1), 100)
  offset greatest(coalesce(p_offset, 0), 0);
end
$$;

-- One part with every shop's offer (compare across shops). A merged part answers with the
-- part it was merged into.
create function public.part_detail(p_part_id uuid, p_variant_id uuid default null)
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
                  'open_now', public.is_open_at(s.opening_hours, now())))
             order by l.stock_qty - l.reserved_qty > 0 desc, l.price_sdg nulls last, s.rating_avg desc)
      from public.listings l
      join public.shops s on s.id = l.shop_id
      where l.part_id = v_id and l.is_active and l.archived_at is null and s.status = 'APPROVED'), '[]')
  );
end
$$;

-- Part-name suggestions while a shop types a quick listing: verified catalogue parts plus
-- the shop's own parts.
create function public.suggest_parts(
  p_q           text,
  p_shop_id     uuid default null,
  p_category_id uuid default null,
  p_limit       integer default 8
)
returns table (id uuid, category_id uuid, name_ar text, name_en text, is_verified boolean, model_count integer)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_query tsquery := public.search_query(p_q);
begin
  if p_shop_id is not null then perform public.require_shop(p_shop_id); end if;
  if v_query is null then return; end if;
  return query
    select p.id, p.category_id, p.name_ar, p.name_en, p.is_verified,
           (select count(distinct v.model_id)::integer from public.part_fitments f
            join public.vehicle_variants v on v.id = f.variant_id where f.part_id = p.id)
    from public.parts p
    join public.part_search_docs d on d.part_id = p.id
    where p.is_active and p.merged_into is null
      and (p.is_verified or (p_shop_id is not null and p.created_by_shop_id = p_shop_id))
      and (p_category_id is null or p.category_id = p_category_id)
      and d.tsv @@ v_query
    order by ts_rank(d.tsv, v_query) desc, p.is_verified desc, char_length(p.name_ar)
    limit least(greatest(coalesce(p_limit, 8), 1), 20);
end
$$;

-- The data the apps cache for offline use: vehicles, job types, categories, the street and
-- its shops. With p_since, only rows changed since then — including deactivated ones (and
-- shops that are no longer approved, as {id, status}) so the cache can drop them.
create function public.catalogue_snapshot(p_since timestamptz default null)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'server_time', now(),
    'full', p_since is null,
    'makes', coalesce((select jsonb_agg(to_jsonb(x) order by x.sort, x.name_en) from public.vehicle_makes x
                       where (p_since is null and x.is_active) or x.updated_at > p_since), '[]'),
    'models', coalesce((select jsonb_agg(to_jsonb(x) order by x.sort, x.name_en) from public.vehicle_models x
                        where (p_since is null and x.is_active) or x.updated_at > p_since), '[]'),
    'variants', coalesce((select jsonb_agg(to_jsonb(x) order by x.sort, x.year_from) from public.vehicle_variants x
                          where (p_since is null and x.is_active) or x.updated_at > p_since), '[]'),
    'job_types', coalesce((select jsonb_agg(to_jsonb(x) order by x.sort) from public.job_types x
                           where p_since is null or x.updated_at > p_since), '[]'),
    'categories', coalesce((select jsonb_agg(to_jsonb(x) order by x.sort) from public.part_categories x
                            where (p_since is null and x.is_active) or x.updated_at > p_since), '[]'),
    'markets', coalesce((select jsonb_agg(to_jsonb(x)) from public.markets x
                         where (p_since is null and x.is_active) or x.updated_at > p_since), '[]'),
    'streets', coalesce((select jsonb_agg(to_jsonb(x) - 'origin') from public.streets x
                         where (p_since is null and x.is_active) or x.updated_at > p_since), '[]'),
    'zones', coalesce((select jsonb_agg(to_jsonb(x) order by x.street_id, x.seq) from public.zones x
                       where (p_since is null and x.is_active) or x.updated_at > p_since), '[]'),
    'shops', coalesce((select jsonb_agg(case when s.status = 'APPROVED' then public.shop_json(s.id)
                                             else jsonb_build_object('id', s.id, 'status', s.status) end
                                        order by s.pos_m nulls last)
                       from public.shops s
                       where (p_since is null and s.status = 'APPROVED')
                          or (p_since is not null and s.updated_at > p_since and s.approved_at is not null)), '[]')
  );
$$;

revoke all on function
  public.search_parts(text, uuid, uuid, boolean, public.listing_condition[], bigint, uuid, boolean, boolean,
                      text, integer, integer),
  public.part_detail(uuid, uuid), public.suggest_parts(text, uuid, uuid, integer),
  public.catalogue_snapshot(timestamptz)
from public, anon, authenticated;

grant execute on function
  public.search_parts(text, uuid, uuid, boolean, public.listing_condition[], bigint, uuid, boolean, boolean,
                      text, integer, integer),
  public.part_detail(uuid, uuid), public.catalogue_snapshot(timestamptz)
to anon, authenticated;
grant execute on function public.suggest_parts(text, uuid, uuid, integer) to authenticated;
