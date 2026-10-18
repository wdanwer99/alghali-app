-- Window tint (D-149): a new category the buyer configures instead of picking a part.
-- Each shop says whether it tints, which darkness levels and colours it offers, and a
-- price for each package and for a single window, per car size. The buyer chooses
--   {car_size, package | windows, darkness, colour}
-- and the line is priced from the shop's table at every check, like a listing's price.
-- One tint line per cart (one car per order), and it is always fitted: at the selling
-- shop's own bay (by a technician who works there) or by a mobile technician, with the
-- technician's labour added as for any fitting (TINT job type).

-- ------------------------------------------------------------------ catalogue
alter table public.part_categories drop constraint part_categories_icon_check;
alter table public.part_categories add constraint part_categories_icon_check check (icon in (
  'lighting', 'brakes', 'oil', 'battery', 'electrical', 'ac', 'suspension', 'tyres', 'engine',
  'transmission', 'body', 'accessories', 'tint'));

insert into public.job_types (code, name_ar, name_en, sort) values ('TINT', 'تظليل', 'Window tint', 10)
on conflict (code) do nothing;

insert into public.part_categories (slug, name_ar, name_en, icon, job_type_id, std_job_minutes, sort)
select 'window-tint', 'تظليل الزجاج', 'Window tint', 'tint', jt.id, 120, 13
from public.job_types jt where jt.code = 'TINT'
on conflict (slug) do nothing;

-- ------------------------------------------------------------------ the buyer's choice
-- The windows of each package, sorted, to recognise a package ticked window by window.
-- The windscreen strip is a package only.
create function public.tint_windows_of(p_package text)
returns text[]
language sql
immutable
set search_path = ''
as $$
  select case p_package
           when 'FULL' then array['BACK_GLASS', 'BACK_LEFT', 'BACK_RIGHT', 'FRONT_LEFT', 'FRONT_RIGHT', 'WINDSCREEN']
           when 'SIDES_BACK' then array['BACK_GLASS', 'BACK_LEFT', 'BACK_RIGHT', 'FRONT_LEFT', 'FRONT_RIGHT']
           when 'SIDES' then array['BACK_LEFT', 'BACK_RIGHT', 'FRONT_LEFT', 'FRONT_RIGHT']
         end;
$$;

-- Checks a choice and returns it in one canonical form (so two equal choices compare
-- equal): windows sorted and de-duplicated, and windows that make up a package become
-- that package. INVALID_TINT otherwise.
create function public.tint_choice(p jsonb)
returns jsonb
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_size    text;
  v_pkg     text;
  v_dark    integer;
  v_colour  text;
  v_windows text[];
begin
  if jsonb_typeof(p) is distinct from 'object' then
    raise exception 'INVALID_TINT' using errcode = '22023';
  end if;
  v_size := p ->> 'car_size';
  v_pkg := p ->> 'package';
  v_dark := (p ->> 'darkness')::integer;
  v_colour := p ->> 'colour';
  if v_size is null or v_size not in ('SMALL', 'SALOON', 'SUV', 'PICKUP', 'MINIBUS')
     or v_dark is null or v_dark not between 1 and 100
     or v_colour is null or v_colour not in ('BLACK', 'SMOKE', 'BLUE', 'GREEN', 'BRONZE', 'SILVER') then
    raise exception 'INVALID_TINT' using errcode = '22023';
  end if;
  if jsonb_typeof(p -> 'windows') = 'array' then
    select array_agg(distinct w order by w) into v_windows from jsonb_array_elements_text(p -> 'windows') w;
    if v_pkg is not null or v_windows is null
       or not v_windows <@ array['WINDSCREEN', 'BACK_GLASS', 'FRONT_LEFT', 'FRONT_RIGHT', 'BACK_LEFT',
                                 'BACK_RIGHT', 'SUNROOF'] then
      raise exception 'INVALID_TINT' using errcode = '22023';
    end if;
    select k into v_pkg from unnest(array['FULL', 'SIDES_BACK', 'SIDES']) k
    where public.tint_windows_of(k) = v_windows;
    if v_pkg is not null then v_windows := null; end if;
  elsif v_pkg is null or v_pkg not in ('FULL', 'SIDES', 'SIDES_BACK', 'WINDSCREEN_STRIP') then
    raise exception 'INVALID_TINT' using errcode = '22023';
  end if;
  return jsonb_strip_nulls(jsonb_build_object('car_size', v_size, 'package', v_pkg, 'windows', to_jsonb(v_windows),
                                              'darkness', v_dark, 'colour', v_colour));
exception
  when invalid_text_representation or numeric_value_out_of_range then
    raise exception 'INVALID_TINT' using errcode = '22023';
end
$$;

-- How long the fitting takes: the whole car two hours, a single window 20 minutes.
create function public.tint_minutes(p_choice jsonb)
returns integer
language sql
immutable
set search_path = ''
as $$
  select case p_choice ->> 'package'
           when 'FULL' then 120
           when 'SIDES_BACK' then 100
           when 'SIDES' then 80
           when 'WINDSCREEN_STRIP' then 30
           else 20 * greatest(jsonb_array_length(coalesce(p_choice -> 'windows', '[]')), 1)
         end;
$$;

-- The line's title in orders, bookings and statements, e.g.
-- "تظليل الزجاج: السيارة كاملة، 50%، أسود (صالون)".
create function public.tint_title(p_choice jsonb, p_lang text)
returns text
language sql
immutable
set search_path = ''
as $$
  select case when p_lang = 'ar' then
           'تظليل الزجاج: '
           || coalesce('{"FULL": "السيارة كاملة", "SIDES": "الجوانب فقط", "SIDES_BACK": "الجوانب والخلفي",
                         "WINDSCREEN_STRIP": "شريط الزجاج الأمامي"}'::jsonb ->> (p_choice ->> 'package'),
                       case jsonb_array_length(p_choice -> 'windows')
                         when 1 then 'نافذة واحدة' when 2 then 'نافذتان'
                         else jsonb_array_length(p_choice -> 'windows') || ' نوافذ' end)
           || '، ' || (p_choice ->> 'darkness') || '%، '
           || ('{"BLACK": "أسود", "SMOKE": "رمادي دخاني", "BLUE": "أزرق", "GREEN": "أخضر", "BRONZE": "برونزي",
                 "SILVER": "فضي عاكس"}'::jsonb ->> (p_choice ->> 'colour'))
           || ' (' || ('{"SMALL": "سيارة صغيرة", "SALOON": "صالون", "SUV": "دفع رباعي", "PICKUP": "بوكس",
                         "MINIBUS": "حافلة صغيرة"}'::jsonb ->> (p_choice ->> 'car_size')) || ')'
         else
           'Window tint: '
           || coalesce('{"FULL": "full car", "SIDES": "sides only", "SIDES_BACK": "sides and back",
                         "WINDSCREEN_STRIP": "windscreen strip"}'::jsonb ->> (p_choice ->> 'package'),
                       jsonb_array_length(p_choice -> 'windows')
                       || case when jsonb_array_length(p_choice -> 'windows') = 1 then ' window' else ' windows' end)
           || ', ' || (p_choice ->> 'darkness') || '%, '
           || ('{"BLACK": "black", "SMOKE": "smoke grey", "BLUE": "blue", "GREEN": "green", "BRONZE": "bronze",
                 "SILVER": "silver mirror"}'::jsonb ->> (p_choice ->> 'colour'))
           || ' (' || ('{"SMALL": "small car", "SALOON": "saloon", "SUV": "4x4", "PICKUP": "pickup",
                         "MINIBUS": "minibus"}'::jsonb ->> (p_choice ->> 'car_size')) || ')'
         end;
$$;

-- ------------------------------------------------------------------ the shop's offer
create table public.shop_tint (
  shop_id    uuid primary key references public.shops (id) on delete cascade,
  is_active  boolean not null default true,
  darkness   integer[] not null check (cardinality(darkness) <= 20 and 1 <= all (darkness) and 100 >= all (darkness)),
  colours    text[] not null check (colours <@ array['BLACK', 'SMOKE', 'BLUE', 'GREEN', 'BRONZE', 'SILVER']),
  updated_at timestamptz not null default now(),
  -- Offering tint needs a darkness level and a colour to choose from.
  check (not is_active or (cardinality(darkness) >= 1 and cardinality(colours) >= 1))
);
create trigger shop_tint_updated_at before update on public.shop_tint
  for each row execute function public.tg_set_updated_at();

-- A price for each package and for one window (WINDOW), per car size. No row: not offered.
create table public.shop_tint_prices (
  shop_id   uuid not null references public.shop_tint (shop_id) on delete cascade,
  car_size  text not null check (car_size in ('SMALL', 'SALOON', 'SUV', 'PICKUP', 'MINIBUS')),
  item      text not null check (item in ('FULL', 'SIDES', 'SIDES_BACK', 'WINDSCREEN_STRIP', 'WINDOW')),
  price_sdg bigint not null check (price_sdg between 1 and 1000000000),
  primary key (shop_id, car_size, item)
);

-- The shop's price for the car size and windows of a (canonical) choice, whatever its
-- darkness and colour: the package price, or the window price times the windows.
create function public.tint_base_price(p_shop_id uuid, p_choice jsonb)
returns bigint
language sql
stable
set search_path = ''
as $$
  select case when p_choice ? 'package' then
           (select pr.price_sdg from public.shop_tint_prices pr
            where pr.shop_id = p_shop_id and pr.car_size = p_choice ->> 'car_size' and pr.item = p_choice ->> 'package')
         else
           (select pr.price_sdg * jsonb_array_length(p_choice -> 'windows') from public.shop_tint_prices pr
            where pr.shop_id = p_shop_id and pr.car_size = p_choice ->> 'car_size' and pr.item = 'WINDOW')
         end;
$$;

-- What the buyer pays for the choice at this shop; null when the shop doesn't offer it
-- (not tinting, not approved, or not that size, windows, darkness or colour).
create function public.tint_price(p_shop_id uuid, p_choice jsonb)
returns bigint
language sql
stable
set search_path = ''
as $$
  select public.tint_base_price(t.shop_id, p_choice)
  from public.shop_tint t join public.shops s on s.id = t.shop_id
  where t.shop_id = p_shop_id and t.is_active and s.status = 'APPROVED'
    and (p_choice ->> 'darkness')::integer = any (t.darkness) and p_choice ->> 'colour' = any (t.colours);
$$;

-- Approved technicians who tint at the shop's bay: "at the shop" needs one.
create function public.tint_bay_technicians(p_shop_id uuid)
returns integer
language sql
stable
set search_path = ''
as $$
  select count(*)::integer
  from public.technicians t join public.technician_job_types tj on tj.technician_id = t.id
  join public.job_types jt on jt.id = tj.job_type_id
  where t.home_bay_shop_id = p_shop_id and t.status = 'APPROVED' and t.work_mode in ('BAY', 'BOTH')
    and jt.code = 'TINT';
$$;

-- For the buyer (guests too): every shop that tints this car size and these windows,
-- cheapest first, with its price, the darkness levels and colours it offers, and whether
-- it can fit it at its own bay. The darkness and colour are picked from these lists.
create function public.tint_offers(p_car_size text, p_package text default null, p_windows text[] default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_choice jsonb := public.tint_choice(jsonb_strip_nulls(jsonb_build_object(
                      'car_size', p_car_size, 'package', p_package, 'windows', to_jsonb(p_windows),
                      'darkness', 50, 'colour', 'BLACK')));
begin
  return jsonb_build_object(
    'choice', v_choice - 'darkness' - 'colour',
    'shops', coalesce((
      select jsonb_agg(jsonb_build_object('shop_id', x.shop_id, 'price_sdg', x.price, 'darkness', x.darkness,
                                          'colours', x.colours, 'at_shop', x.at_shop)
                       order by x.price, x.shop_id)
      from (select t.shop_id, public.tint_base_price(t.shop_id, v_choice) as price, to_jsonb(t.darkness) as darkness,
                   to_jsonb(t.colours) as colours, public.tint_bay_technicians(t.shop_id) > 0 as at_shop
            from public.shop_tint t join public.shops s on s.id = t.shop_id
            where t.is_active and s.status = 'APPROVED') x
      where x.price is not null), '[]'));
end
$$;

create function public.shop_tint_json(p_shop_id uuid)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select jsonb_build_object(
    'is_active', coalesce(t.is_active, false),
    'darkness', coalesce(to_jsonb(t.darkness), '[]'),
    'colours', coalesce(to_jsonb(t.colours), '[]'),
    'prices', coalesce((select jsonb_agg(jsonb_build_object('car_size', pr.car_size, 'item', pr.item,
                                                            'price_sdg', pr.price_sdg) order by pr.car_size, pr.item)
                        from public.shop_tint_prices pr where pr.shop_id = p_shop_id), '[]'),
    'bay_technicians', public.tint_bay_technicians(p_shop_id))
  from (select p_shop_id as id) s left join public.shop_tint t on t.shop_id = s.id;
$$;

-- The shop's tint offer, for its members.
create function public.shop_tint_settings(p_shop_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform public.require_shop(p_shop_id);
  return public.shop_tint_json(p_shop_id);
end
$$;

-- Replaces the shop's tint offer. p_prices: [{car_size, item, price_sdg}]. Offering tint
-- needs a darkness level, a colour and at least one price (TINT_PRICE_REQUIRED).
create function public.shop_set_tint(
  p_shop_id   uuid,
  p_is_active boolean,
  p_darkness  integer[],
  p_colours   text[],
  p_prices    jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.require_shop_writable(p_shop_id);
  if jsonb_typeof(coalesce(p_prices, '[]')) <> 'array' then
    raise exception 'INVALID_TINT' using errcode = '22023';
  end if;
  if coalesce(p_is_active, false) and jsonb_array_length(coalesce(p_prices, '[]')) = 0 then
    raise exception 'TINT_PRICE_REQUIRED' using errcode = '22023';
  end if;
  begin
    insert into public.shop_tint (shop_id, is_active, darkness, colours)
    values (p_shop_id, coalesce(p_is_active, false),
            (select coalesce(array_agg(distinct d order by d), '{}') from unnest(p_darkness) d),
            (select coalesce(array_agg(distinct c order by c), '{}') from unnest(p_colours) c))
    on conflict (shop_id) do update
      set is_active = excluded.is_active, darkness = excluded.darkness, colours = excluded.colours;
    delete from public.shop_tint_prices where shop_id = p_shop_id;
    insert into public.shop_tint_prices (shop_id, car_size, item, price_sdg)
    select p_shop_id, x ->> 'car_size', x ->> 'item', (x ->> 'price_sdg')::bigint
    from jsonb_array_elements(coalesce(p_prices, '[]')) x;
  exception
    when check_violation or not_null_violation or unique_violation or invalid_text_representation
         or numeric_value_out_of_range then
      raise exception 'INVALID_TINT' using errcode = '22023', detail = sqlerrm;
  end;
  return public.shop_tint_json(p_shop_id);
end
$$;

-- ------------------------------------------------------------------ cart, orders, bookings
-- A tint line names the shop and the choice; one per cart.
alter table public.cart_items
  add column tint_shop_id uuid references public.shops (id) on delete cascade,
  add column tint jsonb;
alter table public.cart_items drop constraint cart_items_check;
alter table public.cart_items add constraint cart_items_check
  check (num_nonnulls(listing_id, offer_id, tint_shop_id) = 1 and (tint_shop_id is null) = (tint is null));
create unique index cart_items_tint on public.cart_items (user_id) where tint_shop_id is not null;

-- The choice as bought (the shop is the sub-order's).
alter table public.order_items add column tint jsonb;
alter table public.order_items drop constraint order_items_check1;
alter table public.order_items add constraint order_items_check1 check (num_nonnulls(listing_id, offer_id, tint) = 1);

-- A tint being fitted: from the cart (no order item yet) or from an earlier order.
alter table public.booking_items
  add column tint_shop_id uuid references public.shops (id),
  add column tint jsonb;

-- tg_cart_items_before() from M2: tint lines hold one canonical choice.
create or replace function public.tg_cart_items_before()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' and (select count(*) from public.cart_items c where c.user_id = new.user_id) >= 50 then
    raise exception 'CART_FULL' using errcode = '22023';
  end if;
  if new.offer_id is not null then
    if new.qty <> 1 then raise exception 'INVALID_QTY' using errcode = '22023'; end if;
    if not exists (select 1 from public.part_offers o join public.part_requests r on r.id = o.request_id
                   where o.id = new.offer_id and r.buyer_id = new.user_id) then
      raise exception 'OFFER_NOT_FOUND' using errcode = 'P0002';
    end if;
  end if;
  if new.tint_shop_id is not null then
    if new.qty <> 1 then raise exception 'INVALID_QTY' using errcode = '22023'; end if;
    new.tint := public.tint_choice(new.tint);
  end if;
  return new;
end
$$;

-- cart_check() from M2, with tint lines: {tint_shop_id, tint, qty: 1, seen_price_sdg}.
-- A tint line comes back like an offer (one, no stock), priced from the shop's table.
create or replace function public.cart_check(p_items jsonb, p_lock boolean default false)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_item   jsonb;
  v_out    jsonb := '[]';
  v_qty    integer;
  v_seen   bigint;
  v_line   jsonb;
  v_lid    uuid;
  v_oid    uuid;
  v_tsid   uuid;
  v_choice jsonb;
  v_price  bigint;
  l        record;
  v_uid    uuid := auth.uid();
begin
  if jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 or jsonb_array_length(p_items) > 50 then
    raise exception 'INVALID_ITEMS' using errcode = '22023';
  end if;
  -- Lock in a fixed order so two checkouts never wait on each other in a circle.
  for v_item in
    select x from jsonb_array_elements(p_items) x
    order by coalesce(x ->> 'listing_id', x ->> 'offer_id', x ->> 'tint_shop_id')
  loop
    v_qty := (v_item ->> 'qty')::integer;
    v_seen := (v_item ->> 'seen_price_sdg')::bigint;
    v_lid := (v_item ->> 'listing_id')::uuid;
    v_oid := (v_item ->> 'offer_id')::uuid;
    v_tsid := (v_item ->> 'tint_shop_id')::uuid;
    if num_nonnulls(v_lid, v_oid, v_tsid) <> 1 or v_qty is null or v_qty not between 1 and 99 then
      raise exception 'INVALID_ITEMS' using errcode = '22023';
    end if;

    if v_lid is not null then
      if p_lock then
        select li.id, li.shop_id, li.part_id, li.price_sdg, li.price_on_request, li.is_active, li.archived_at,
               li.stock_qty - li.reserved_qty as available, li.condition, li.brand, li.warranty_days,
               p.name_ar, p.name_en, s.status as shop_status
          into l
        from public.listings li join public.parts p on p.id = li.part_id join public.shops s on s.id = li.shop_id
        where li.id = v_lid
        for update of li;
      else
        select li.id, li.shop_id, li.part_id, li.price_sdg, li.price_on_request, li.is_active, li.archived_at,
               li.stock_qty - li.reserved_qty as available, li.condition, li.brand, li.warranty_days,
               p.name_ar, p.name_en, s.status as shop_status
          into l
        from public.listings li join public.parts p on p.id = li.part_id join public.shops s on s.id = li.shop_id
        where li.id = v_lid;
      end if;
      v_line := jsonb_build_object('listing_id', v_lid, 'qty', v_qty, 'seen_price_sdg', v_seen);
      if l.id is null or not l.is_active or l.archived_at is not null or l.shop_status <> 'APPROVED'
         or l.price_on_request or l.price_sdg is null then
        v_line := v_line || jsonb_build_object('ok', false, 'problem', 'UNAVAILABLE');
      else
        v_line := v_line || jsonb_build_object(
          'shop_id', l.shop_id, 'part_id', l.part_id, 'price_sdg', l.price_sdg, 'available_qty', greatest(l.available, 0),
          'title_ar', l.name_ar, 'title_en', l.name_en, 'condition', l.condition, 'brand', l.brand,
          'warranty_days', l.warranty_days,
          'ok', l.price_sdg = v_seen and l.available >= v_qty,
          'problem', case when l.price_sdg <> v_seen then 'PRICE_CHANGED'
                          when l.available < v_qty then 'NOT_ENOUGH_STOCK' end);
      end if;
    elsif v_oid is not null then
      if p_lock then
        select o.id, o.shop_id, o.part_id, o.price_sdg, o.status, o.valid_until, o.title_ar, o.title_en,
               o.condition, o.warranty_days, r.buyer_id, s.status as shop_status
          into l
        from public.part_offers o join public.part_requests r on r.id = o.request_id join public.shops s on s.id = o.shop_id
        where o.id = v_oid
        for update of o;
      else
        select o.id, o.shop_id, o.part_id, o.price_sdg, o.status, o.valid_until, o.title_ar, o.title_en,
               o.condition, o.warranty_days, r.buyer_id, s.status as shop_status
          into l
        from public.part_offers o join public.part_requests r on r.id = o.request_id join public.shops s on s.id = o.shop_id
        where o.id = v_oid;
      end if;
      v_line := jsonb_build_object('offer_id', v_oid, 'qty', v_qty, 'seen_price_sdg', v_seen);
      if l.id is null or l.status <> 'OFFERED' or l.valid_until < now() or l.buyer_id is distinct from v_uid
         or l.shop_status <> 'APPROVED' or v_qty <> 1 then
        v_line := v_line || jsonb_build_object('ok', false, 'problem', 'UNAVAILABLE');
      else
        v_line := v_line || jsonb_build_object(
          'shop_id', l.shop_id, 'part_id', l.part_id, 'price_sdg', l.price_sdg, 'available_qty', 1,
          'title_ar', l.title_ar, 'title_en', l.title_en, 'condition', l.condition, 'brand', null,
          'warranty_days', l.warranty_days,
          'ok', l.price_sdg = v_seen,
          'problem', case when l.price_sdg <> v_seen then 'PRICE_CHANGED' end);
      end if;
    else
      v_choice := public.tint_choice(v_item -> 'tint');
      if p_lock then
        perform 1 from public.shop_tint t where t.shop_id = v_tsid for share;
      end if;
      v_price := public.tint_price(v_tsid, v_choice);
      v_line := jsonb_build_object('tint_shop_id', v_tsid, 'tint', v_choice, 'qty', v_qty, 'seen_price_sdg', v_seen);
      if v_price is null or v_qty <> 1 then
        v_line := v_line || jsonb_build_object('ok', false, 'problem', 'UNAVAILABLE');
      else
        v_line := v_line || jsonb_build_object(
          'shop_id', v_tsid, 'part_id', null, 'price_sdg', v_price, 'available_qty', 1,
          'title_ar', public.tint_title(v_choice, 'ar'), 'title_en', public.tint_title(v_choice, 'en'),
          'condition', 'NEW_AFTERMARKET', 'brand', null, 'warranty_days', 0,
          'ok', v_price = v_seen,
          'problem', case when v_price <> v_seen then 'PRICE_CHANGED' end);
      end if;
    end if;
    v_out := v_out || v_line;
  end loop;

  if (select count(*) from jsonb_array_elements(v_out) x)
     <> (select count(distinct coalesce(x ->> 'listing_id', x ->> 'offer_id', x ->> 'tint_shop_id'))
         from jsonb_array_elements(v_out) x) then
    raise exception 'INVALID_ITEMS' using errcode = '22023', detail = 'duplicate line';
  end if;
  return v_out;
exception
  when invalid_text_representation or numeric_value_out_of_range then
    raise exception 'INVALID_ITEMS' using errcode = '22023';
end
$$;

-- Whether a booking item is this checked cart line (a listing, an offer or a tint).
create function public.booking_item_is_line(p_item public.booking_items, p_line jsonb)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select (p_item.listing_id is not null and (p_line ->> 'listing_id')::uuid = p_item.listing_id)
      or (p_item.offer_id is not null and (p_line ->> 'offer_id')::uuid = p_item.offer_id)
      or (p_item.tint_shop_id is not null and p_item.order_item_id is null
          and (p_line ->> 'tint_shop_id')::uuid = p_item.tint_shop_id and p_line -> 'tint' = p_item.tint);
$$;

-- checkout() from M3, with tint lines: priced like the other lines, kept as the order
-- item's `tint`, and only with a fitting that covers them (TINT_NEEDS_FITTING).
create or replace function public.checkout(
  p_items       jsonb,
  p_method      public.payment_method,
  p_fulfilment  jsonb default '{}',
  p_address_id  uuid default null,
  p_idem        uuid default null,
  p_booking_id  uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid      uuid := public.require_user();
  v_prev     jsonb := public.idem_begin(p_idem, 'checkout');
  v_lines    jsonb := '[]';
  v_shop     uuid;
  v_ful      public.fulfilment_type;
  v_order    uuid;
  v_ref      text;
  v_sub      uuid;
  v_items    bigint;
  v_delivery bigint;
  v_total_i  bigint := 0;
  v_total_d  bigint := 0;
  v_bp       integer := round((public.setting('commission_percent') #>> '{}')::numeric * 100)::integer;
  v_addr     jsonb;
  v_status   public.suborder_status;
  bk         public.bookings;
  v_fees     bigint := 0;
  v_deposit  bigint := 0;
  v_tech_i   bigint := 0;
  v_tech     uuid[] := '{}';
begin
  if v_prev is not null then return v_prev; end if;
  if p_method is null then raise exception 'INVALID_METHOD' using errcode = '22023'; end if;
  if (select p.phone from public.profiles p where p.id = v_uid) is null then
    raise exception 'PHONE_REQUIRED' using errcode = '22023';
  end if;

  if p_booking_id is not null then
    select * into bk from public.bookings b where b.id = p_booking_id and b.buyer_id = v_uid for update;
    if bk.id is null then raise exception 'BOOKING_NOT_FOUND' using errcode = 'P0002'; end if;
    if bk.status <> 'HELD' or bk.hold_expires_at < now() then
      raise exception 'HOLD_EXPIRED' using errcode = 'PT409';
    end if;
    v_fees := bk.labour_sdg + bk.travel_fee_sdg + bk.booking_fee_sdg;
    if p_method = 'CASH' and bk.place = 'CUSTOMER_LOCATION' then
      v_deposit := least(public.setting_int('mobile_deposit_sdg'), v_fees);
    end if;
  end if;

  if p_booking_id is null or jsonb_array_length(coalesce(p_items, '[]')) > 0 then
    v_lines := public.cart_check(p_items, true);
    if exists (select 1 from jsonb_array_elements(v_lines) x where not (x ->> 'ok')::boolean) then
      raise exception 'CART_CHANGED' using errcode = 'PT409', detail = v_lines::text;
    end if;
  end if;

  -- Tint is always fitted: the booking must cover it.
  if exists (select 1 from jsonb_array_elements(v_lines) x
             where x ? 'tint_shop_id'
               and not exists (select 1 from public.booking_items i
                               where i.booking_id = bk.id and public.booking_item_is_line(i, x))) then
    raise exception 'TINT_NEEDS_FITTING' using errcode = '22023';
  end if;

  if bk.id is not null then
    -- Every cart line in the booking must be bought now; their shops send to the technician.
    if exists (select 1 from public.booking_items i where i.booking_id = bk.id
               and (i.listing_id is not null or i.offer_id is not null
                    or (i.tint_shop_id is not null and i.order_item_id is null))
               and not exists (select 1 from jsonb_array_elements(v_lines) x where public.booking_item_is_line(i, x))) then
      raise exception 'BOOKING_ITEMS_NOT_IN_CART' using errcode = '22023';
    end if;
    select coalesce(array_agg(distinct (x ->> 'shop_id')::uuid), '{}') into v_tech
    from jsonb_array_elements(v_lines) x
    where exists (select 1 from public.booking_items i where i.booking_id = bk.id and public.booking_item_is_line(i, x));
  end if;

  -- Fulfilment per shop, checked before anything is written.
  for v_shop in select distinct (x ->> 'shop_id')::uuid from jsonb_array_elements(v_lines) x loop
    if v_shop = any (v_tech) then continue; end if;
    begin
      v_ful := coalesce(p_fulfilment ->> v_shop::text, 'PICKUP')::public.fulfilment_type;
    exception when invalid_text_representation then
      raise exception 'INVALID_FULFILMENT' using errcode = '22023';
    end;
    if v_ful = 'TO_TECHNICIAN' then
      raise exception 'INVALID_FULFILMENT' using errcode = '22023', detail = 'book a fitting for these parts';
    end if;
    if v_ful = 'DELIVERY' and v_addr is null then
      select jsonb_build_object('label', a.label, 'description_ar', a.description_ar, 'lat', a.lat, 'lng', a.lng)
        into v_addr
      from public.addresses a where a.id = p_address_id and a.user_id = v_uid;
      if v_addr is null then raise exception 'ADDRESS_REQUIRED' using errcode = '22023'; end if;
    end if;
  end loop;

  v_ref := public.new_ref('ORDER');
  insert into public.orders (ref, buyer_id, payment_method, items_sdg, total_sdg, pay_by, address_id,
                             address_snapshot, idem_key)
  values (v_ref, v_uid, p_method, 0, 0,
          case when p_method = 'BANKAK' or v_deposit > 0
               then now() + make_interval(mins => public.setting_int('payment_window_minutes')::integer) end,
          case when v_addr is not null then p_address_id end, v_addr, p_idem)
  returning id into v_order;

  for v_shop in select distinct (x ->> 'shop_id')::uuid from jsonb_array_elements(v_lines) x loop
    v_ful := case when v_shop = any (v_tech) then 'TO_TECHNICIAN'
                  else coalesce(p_fulfilment ->> v_shop::text, 'PICKUP')::public.fulfilment_type end;
    v_status := case when p_method = 'BANKAK' or (v_ful = 'TO_TECHNICIAN' and v_deposit > 0)
                     then 'PENDING_PAYMENT' else 'CONFIRMED' end;
    select sum((x ->> 'price_sdg')::bigint * (x ->> 'qty')::bigint) into v_items
    from jsonb_array_elements(v_lines) x where (x ->> 'shop_id')::uuid = v_shop;
    v_delivery := case when v_ful = 'DELIVERY' then public.delivery_fee(v_shop, p_address_id) else 0 end;

    insert into public.sub_orders (order_id, shop_id, status, fulfilment, items_sdg, delivery_fee_sdg,
                                   commission_bp, commission_sdg)
    values (v_order, v_shop, v_status, v_ful, v_items, v_delivery, v_bp, public.commission_of(v_items, v_bp))
    returning id into v_sub;
    insert into public.suborder_events (sub_order_id, from_status, to_status, actor_kind, actor_id)
    values (v_sub, null, v_status, 'BUYER', v_uid);

    insert into public.order_items (sub_order_id, listing_id, offer_id, tint, part_id, title_ar, title_en, condition,
                                    brand, warranty_days, unit_price_sdg, qty, line_sdg)
    select v_sub, (x ->> 'listing_id')::uuid, (x ->> 'offer_id')::uuid, x -> 'tint', (x ->> 'part_id')::uuid,
           x ->> 'title_ar', coalesce(nullif(x ->> 'title_en', ''), x ->> 'title_ar'),
           (x ->> 'condition')::public.listing_condition, x ->> 'brand', coalesce((x ->> 'warranty_days')::integer, 0),
           (x ->> 'price_sdg')::bigint, (x ->> 'qty')::integer,
           (x ->> 'price_sdg')::bigint * (x ->> 'qty')::integer
    from jsonb_array_elements(v_lines) x where (x ->> 'shop_id')::uuid = v_shop;

    update public.listings l set reserved_qty = l.reserved_qty + (x ->> 'qty')::integer
    from jsonb_array_elements(v_lines) x
    where (x ->> 'shop_id')::uuid = v_shop and l.id = (x ->> 'listing_id')::uuid;
    update public.part_offers o set status = 'ORDERED'
    from jsonb_array_elements(v_lines) x
    where (x ->> 'shop_id')::uuid = v_shop and o.id = (x ->> 'offer_id')::uuid;

    if p_method = 'CASH' and v_ful <> 'TO_TECHNICIAN' then
      insert into public.payments (order_id, sub_order_id, method, status, amount_sdg)
      values (v_order, v_sub, 'CASH', 'DUE', v_items + v_delivery);
    end if;
    if v_status = 'CONFIRMED' then
      perform public.notify_shop(v_shop, 'NEW_ORDER',
                                 jsonb_build_object('order_id', v_order, 'sub_order_id', v_sub, 'ref', v_ref));
    end if;
    if v_ful = 'TO_TECHNICIAN' then v_tech_i := v_tech_i + v_items; end if;
    v_total_i := v_total_i + v_items;
    v_total_d := v_total_d + v_delivery;
  end loop;

  update public.orders
     set items_sdg = v_total_i, delivery_sdg = v_total_d,
         booking_fee_sdg = coalesce(bk.booking_fee_sdg, 0), labour_sdg = coalesce(bk.labour_sdg, 0),
         travel_sdg = coalesce(bk.travel_fee_sdg, 0),
         total_sdg = v_total_i + v_total_d + v_fees
   where id = v_order;
  if p_method = 'BANKAK' then
    insert into public.payments (order_id, booking_id, method, status, amount_sdg)
    values (v_order, bk.id, 'BANKAK', 'AWAITING_TRANSFER', v_total_i + v_total_d + v_fees);
  end if;

  if bk.id is not null then
    update public.bookings set order_id = v_order, payment_method = p_method, deposit_sdg = v_deposit where id = bk.id;
    -- Link the booked cart lines to the order items just written.
    update public.booking_items i set order_item_id = oi.id
      from public.order_items oi join public.sub_orders so on so.id = oi.sub_order_id
     where i.booking_id = bk.id and so.order_id = v_order and i.order_item_id is null
       and ((i.listing_id is not null and i.listing_id = oi.listing_id)
            or (i.offer_id is not null and i.offer_id = oi.offer_id)
            or (i.tint_shop_id is not null and so.shop_id = i.tint_shop_id and oi.tint = i.tint));
    if p_method = 'CASH' then
      if v_tech_i + v_fees - v_deposit > 0 then
        insert into public.payments (order_id, booking_id, method, status, amount_sdg)
        values (v_order, bk.id, 'CASH', 'DUE', v_tech_i + v_fees - v_deposit);
      end if;
      if v_deposit > 0 then
        insert into public.payments (order_id, booking_id, purpose, method, status, amount_sdg)
        values (v_order, bk.id, 'BOOKING_DEPOSIT', 'BANKAK', 'AWAITING_TRANSFER', v_deposit);
      end if;
    end if;
    perform public.transition_booking(bk.id,
      case when p_method = 'BANKAK' or v_deposit > 0 then 'AWAITING_PAYMENT' else 'PENDING_TECH_ACCEPT' end::public.booking_status,
      'BUYER');
  end if;

  delete from public.cart_items c
   where c.user_id = v_uid
     and (c.listing_id in (select (x ->> 'listing_id')::uuid from jsonb_array_elements(v_lines) x)
          or c.offer_id in (select (x ->> 'offer_id')::uuid from jsonb_array_elements(v_lines) x)
          or c.tint_shop_id in (select (x ->> 'tint_shop_id')::uuid from jsonb_array_elements(v_lines) x));
  perform public.notify(v_uid, 'ORDER_PLACED', jsonb_build_object('order_id', v_order, 'ref', v_ref));

  return public.idem_finish(p_idem, 'checkout', public.order_json(v_order));
end
$$;

-- ------------------------------------------------------------------ fitting tint
-- resolve_booking_items() from M3, with tint: {tint_shop_id, tint} from the cart, or an
-- earlier order's tint item ({order_item_id}). Both carry the shop and the choice.
create or replace function public.resolve_booking_items(p_items jsonb, p_buyer uuid)
returns jsonb
language plpgsql
stable
set search_path = ''
as $$
declare
  v_item  jsonb;
  v_out   jsonb := '[]';
  v_part  uuid;
  v_cat   uuid;
  v_desc  text;
  v_pmin  integer;
  v_par   text;
  v_pen   text;
  v_inst  boolean;
  v_tint  jsonb;
  v_tshop uuid;
  c       record;
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
    v_tint := null;
    v_tshop := null;
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
    elsif v_item ? 'tint_shop_id' then
      v_tshop := (v_item ->> 'tint_shop_id')::uuid;
      v_tint := public.tint_choice(v_item -> 'tint');
      if public.tint_price(v_tshop, v_tint) is null then raise exception 'ITEM_NOT_FOUND' using errcode = 'P0002'; end if;
    elsif v_item ? 'order_item_id' then
      select i.part_id, rq.category_id, i.tint, case when i.tint is not null then s.shop_id end
        into v_part, v_cat, v_tint, v_tshop
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

    if v_tint is not null then
      select pc.id into v_cat from public.part_categories pc where pc.slug = 'window-tint';
      v_pmin := public.tint_minutes(v_tint);
      v_par := public.tint_title(v_tint, 'ar');
      v_pen := public.tint_title(v_tint, 'en');
    elsif v_part is not null then
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
      'tint_shop_id', v_tshop, 'tint', v_tint,
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

-- tech_suits() from M3, plus the bay the job must be at: a tint fitted "at the shop"
-- happens at the shop that sold it, by a technician who works there.
drop function public.tech_suits(uuid, uuid[], uuid, public.booking_place, extensions.geography);
create function public.tech_suits(
  p_technician_id uuid,
  p_job_type_ids  uuid[],
  p_make_id       uuid,
  p_place         public.booking_place,
  p_point         extensions.geography,
  p_bay_shop_id   uuid default null
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
                            and (p_bay_shop_id is null or t.home_bay_shop_id = p_bay_shop_id)
            else t.work_mode in ('MOBILE', 'BOTH') and p_point is not null
                 and extensions.st_dwithin(t.home_point, p_point, t.radius_km * 1000.0)
          end
      and public.tech_labour(t.id, p_job_type_ids) is not null
      and (p_make_id is null
           or not exists (select 1 from public.technician_makes m where m.technician_id = t.id)
           or exists (select 1 from public.technician_makes m where m.technician_id = t.id and m.make_id = p_make_id)));
$$;

-- The bay a booking is tied to: the tint shop's, for a tint fitted at a bay.
create function public.booking_bay_lock(p_booking_id uuid)
returns uuid
language sql
stable
set search_path = ''
as $$
  select i.tint_shop_id from public.booking_items i join public.bookings b on b.id = i.booking_id
  where i.booking_id = p_booking_id and b.place = 'BAY' and i.tint_shop_id is not null
  limit 1;
$$;

-- booking_quote() from M3, plus bay_shop_id: the tint shop when tint is fitted at a bay.
create or replace function public.booking_quote(
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
  v_bays  uuid[];
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
  select coalesce(array_agg(distinct (x ->> 'tint_shop_id')::uuid), '{}') into v_bays
  from jsonb_array_elements(v_items) x where x ? 'tint_shop_id';
  if p_place = 'BAY' and cardinality(v_bays) > 1 then
    raise exception 'INVALID_ITEMS' using errcode = '22023', detail = 'tint from two shops';
  end if;
  return jsonb_build_object(
    'items', v_items,
    'job_type_ids', (select jsonb_agg(distinct x ->> 'job_type_id') from jsonb_array_elements(v_items) x),
    'duration_min', least((select sum((x ->> 'minutes')::integer) from jsonb_array_elements(v_items) x), 720),
    'make_id', v_make,
    'bay_shop_id', case when p_place = 'BAY' then v_bays[1] end,
    'travel_fee_sdg', case when p_place = 'CUSTOMER_LOCATION' then public.travel_fee(p_point) else 0 end,
    'booking_fee_sdg', public.setting_int('booking_fee_sdg'),
    'mobile_deposit_sdg', case when p_place = 'CUSTOMER_LOCATION' then public.setting_int('mobile_deposit_sdg') else 0 end);
end
$$;

-- booking_context() from M3: only technicians at the tint shop's bay for tint at a bay.
create or replace function public.booking_context(
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
             and public.tech_suits(t.id, v_types, (v_quote ->> 'make_id')::uuid, p_place, v_point,
                                   (v_quote ->> 'bay_shop_id')::uuid)), '[]'));
end
$$;

-- next_technician() from M3: a tint at a bay stays at the tint shop's bay.
create or replace function public.next_technician(p_booking_id uuid)
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
      and public.tech_suits(t.id, types.ids, b.make_id, b.place, b.point, public.booking_bay_lock(b.id))
      and public.tech_free(t.id, b.place, b.start_at, b.end_at, b.block_from, b.block_to, b.id))
  select c.id from c
  order by 0.5 * least(c.rating_avg, 5) / 5
         + 0.3 * coalesce(ln(c.completed_jobs + 1) / nullif(ln(max(c.completed_jobs) over () + 1), 0), 0)
         + 0.2 * c.closeness desc,
           c.completed_jobs desc, c.id
  limit 1;
$$;

-- create_booking_hold() from M3: the bay lock, and tint kept on the booking items.
create or replace function public.create_booking_hold(
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

  if not public.tech_suits(p_technician_id, v_types, (v_quote ->> 'make_id')::uuid, p_place, v_point,
                           (v_quote ->> 'bay_shop_id')::uuid) then
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
                                      tint_shop_id, tint, minutes, title_ar, title_en, description)
    values (v_id, (v_item ->> 'listing_id')::uuid, (v_item ->> 'offer_id')::uuid, (v_item ->> 'order_item_id')::uuid,
            (v_item ->> 'part_id')::uuid, (v_item ->> 'category_id')::uuid, (v_item ->> 'job_type_id')::uuid,
            (v_item ->> 'tint_shop_id')::uuid, v_item -> 'tint',
            (v_item ->> 'minutes')::integer, v_item ->> 'title_ar', v_item ->> 'title_en', v_item ->> 'description');
  end loop;
  return public.idem_finish(p_idem, 'create_booking_hold', public.booking_json(v_id));
end
$$;

-- buyer_reschedule() from M3: the new technician must suit the bay lock too.
create or replace function public.buyer_reschedule(p_booking_id uuid, p_start_at timestamptz, p_technician_id uuid default null)
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
  if not public.tech_suits(v_tech, v_types, b.make_id, b.place, b.point, public.booking_bay_lock(b.id)) then
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

-- ------------------------------------------------------------------ RLS + grants
-- Read and written through the functions above only.
alter table public.shop_tint enable row level security;
alter table public.shop_tint_prices enable row level security;
revoke all on public.shop_tint, public.shop_tint_prices from anon, authenticated;

revoke all on function
  public.tint_windows_of(text), public.tint_choice(jsonb), public.tint_minutes(jsonb), public.tint_title(jsonb, text),
  public.tint_base_price(uuid, jsonb), public.tint_price(uuid, jsonb), public.tint_bay_technicians(uuid),
  public.tint_offers(text, text, text[]), public.shop_tint_json(uuid), public.shop_tint_settings(uuid),
  public.shop_set_tint(uuid, boolean, integer[], text[], jsonb),
  public.booking_item_is_line(public.booking_items, jsonb),
  public.tech_suits(uuid, uuid[], uuid, public.booking_place, extensions.geography, uuid),
  public.booking_bay_lock(uuid)
from public, anon, authenticated;

-- Which shops tint at what price is public, like listings (no contact details).
grant execute on function public.tint_offers(text, text, text[]) to anon, authenticated;
grant execute on function
  public.shop_tint_settings(uuid), public.shop_set_tint(uuid, boolean, integer[], text[], jsonb)
to authenticated;
