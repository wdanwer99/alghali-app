-- M2 checkout: photo requests and shop offers, the cart, delivery fees, checkout
-- (price re-check, price lock, stock reservation, payment window) and cancellation.

-- ------------------------------------------------------------------ requests and offers
create table public.part_requests (
  id          uuid primary key default gen_random_uuid(),
  buyer_id    uuid not null default auth.uid() references auth.users (id) on delete cascade,
  variant_id  uuid references public.vehicle_variants (id),
  category_id uuid references public.part_categories (id),
  note        text not null check (char_length(btrim(note)) between 3 and 1000),
  image_keys  text[] not null default '{}' check (cardinality(image_keys) <= 4),
  status      text not null default 'OPEN' check (status in ('OPEN', 'CLOSED', 'EXPIRED')),
  expires_at  timestamptz not null default now() + interval '3 days',
  created_at  timestamptz not null default now()
);
create index part_requests_open_idx on public.part_requests (status, created_at desc);
create index part_requests_buyer_idx on public.part_requests (buyer_id, created_at desc);

create table public.part_offers (
  id            uuid primary key default gen_random_uuid(),
  request_id    uuid not null references public.part_requests (id) on delete cascade,
  shop_id       uuid not null references public.shops (id) on delete cascade,
  part_id       uuid references public.parts (id),
  title_ar      text not null check (char_length(btrim(title_ar)) between 2 and 120),
  title_en      text not null default '' check (char_length(title_en) <= 120),
  condition     public.listing_condition not null,
  price_sdg     bigint not null check (price_sdg between 1 and 1000000000),
  warranty_days integer not null default 0 check (warranty_days between 0 and 1825),
  note_ar       text check (char_length(note_ar) <= 300),
  image_key     text check (char_length(image_key) <= 300),
  status        text not null default 'OFFERED' check (status in ('OFFERED', 'ORDERED', 'WITHDRAWN', 'EXPIRED')),
  valid_until   timestamptz not null default now() + interval '2 days',
  created_by    uuid references auth.users (id) on delete set null,
  created_at    timestamptz not null default now()
);
create index part_offers_request_idx on public.part_offers (request_id);
create unique index part_offers_one_active on public.part_offers (request_id, shop_id) where status = 'OFFERED';

alter table public.order_items
  add constraint order_items_offer_fk foreign key (offer_id) references public.part_offers (id);

-- ------------------------------------------------------------------ cart
-- Buyers write their own cart rows directly (RLS). The price the buyer saw is kept so
-- checkout can show what changed.
create table public.cart_items (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null default auth.uid() references auth.users (id) on delete cascade,
  listing_id     uuid references public.listings (id) on delete cascade,
  offer_id       uuid references public.part_offers (id) on delete cascade,
  qty            integer not null default 1 check (qty between 1 and 99),
  seen_price_sdg bigint not null check (seen_price_sdg > 0),
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  check (num_nonnulls(listing_id, offer_id) = 1)
);
create unique index cart_items_listing on public.cart_items (user_id, listing_id) where listing_id is not null;
create unique index cart_items_offer on public.cart_items (user_id, offer_id) where offer_id is not null;

create function public.tg_cart_items_before()
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
  return new;
end
$$;

create trigger cart_items_before before insert or update on public.cart_items
  for each row execute function public.tg_cart_items_before();
create trigger cart_items_updated_at before update on public.cart_items
  for each row execute function public.tg_set_updated_at();

-- ------------------------------------------------------------------ fees
-- Delivery fee from the shop (or, when the shop has no pin, the street's starting point)
-- to the buyer's address, by straight-line km (D-026) and the delivery fee bands.
create function public.delivery_fee(p_shop_id uuid, p_address_id uuid)
returns bigint
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_from extensions.geography;
  v_to   extensions.geography;
  v_km   numeric;
  v_fee  bigint;
begin
  select coalesce(s.location, st.origin) into v_from
  from public.shops s join public.zones z on z.id = s.zone_id join public.streets st on st.id = z.street_id
  where s.id = p_shop_id;
  if v_from is null then raise exception 'DELIVERY_UNAVAILABLE' using errcode = '22023'; end if;
  select a.location into v_to from public.addresses a where a.id = p_address_id;
  if v_to is null then raise exception 'ADDRESS_NOT_FOUND' using errcode = 'P0002'; end if;
  v_km := extensions.st_distance(v_from, v_to) / 1000.0;
  select (b ->> 'sdg')::bigint into v_fee
  from jsonb_array_elements(public.setting('delivery_fee_bands')) b
  where (b ->> 'max_km')::numeric >= v_km
  order by (b ->> 'max_km')::numeric
  limit 1;
  if v_fee is null then raise exception 'DELIVERY_OUT_OF_RANGE' using errcode = '22023'; end if;
  return v_fee;
end
$$;

-- Commission rounded half up to whole SDG (D-014).
create function public.commission_of(p_items_sdg bigint, p_bp integer)
returns bigint
language sql
immutable
set search_path = ''
as $$
  select (p_items_sdg * p_bp + 5000) / 10000;
$$;

-- ------------------------------------------------------------------ cart check
-- What the buyer is about to buy, checked against the shops' current prices and stock.
-- p_items: [{listing_id | offer_id, qty, seen_price_sdg}]. Each line comes back with
-- {ok, problem: PRICE_CHANGED | NOT_ENOUGH_STOCK | UNAVAILABLE, price_sdg, available_qty, shop_id, ...}.
create function public.cart_check(p_items jsonb, p_lock boolean default false)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_item  jsonb;
  v_out   jsonb := '[]';
  v_qty   integer;
  v_seen  bigint;
  v_line  jsonb;
  v_lid   uuid;
  v_oid   uuid;
  l       record;
  v_uid   uuid := auth.uid();
begin
  if jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 or jsonb_array_length(p_items) > 50 then
    raise exception 'INVALID_ITEMS' using errcode = '22023';
  end if;
  -- Lock in a fixed order so two checkouts never wait on each other in a circle.
  for v_item in
    select x from jsonb_array_elements(p_items) x
    order by coalesce(x ->> 'listing_id', x ->> 'offer_id')
  loop
    v_qty := (v_item ->> 'qty')::integer;
    v_seen := (v_item ->> 'seen_price_sdg')::bigint;
    v_lid := (v_item ->> 'listing_id')::uuid;
    v_oid := (v_item ->> 'offer_id')::uuid;
    if num_nonnulls(v_lid, v_oid) <> 1 or v_qty is null or v_qty not between 1 and 99 then
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
    else
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
    end if;
    v_out := v_out || v_line;
  end loop;

  if (select count(*) from jsonb_array_elements(v_out) x)
     <> (select count(distinct coalesce(x ->> 'listing_id', x ->> 'offer_id')) from jsonb_array_elements(v_out) x) then
    raise exception 'INVALID_ITEMS' using errcode = '22023', detail = 'duplicate line';
  end if;
  return v_out;
exception
  when invalid_text_representation or numeric_value_out_of_range then
    raise exception 'INVALID_ITEMS' using errcode = '22023';
end
$$;

-- For the cart and checkout screens (guests too): the same check, without locking.
create function public.cart_validate(p_items jsonb)
returns jsonb
language sql
security definer
set search_path = ''
as $$
  select public.cart_check(p_items, false);
$$;

-- ------------------------------------------------------------------ checkout
-- Places the order. p_items as in cart_validate; p_fulfilment: {"<shop_id>": "PICKUP" |
-- "DELIVERY"} (pickup when missing); p_address_id is needed for delivery. When a price or
-- stock changed since the buyer saw it, nothing is placed: CART_CHANGED (409) with the
-- checked lines (as in cart_validate) in the error detail, so the app can show them.
-- Bankak orders wait for the transfer until pay_by; cash orders go straight to the shops.
create function public.checkout(
  p_items       jsonb,
  p_method      public.payment_method,
  p_fulfilment  jsonb default '{}',
  p_address_id  uuid default null,
  p_idem        uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid      uuid := public.require_user();
  v_prev     jsonb := public.idem_begin(p_idem, 'checkout');
  v_lines    jsonb;
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
begin
  if v_prev is not null then return v_prev; end if;
  if p_method is null then raise exception 'INVALID_METHOD' using errcode = '22023'; end if;
  if (select p.phone from public.profiles p where p.id = v_uid) is null then
    raise exception 'PHONE_REQUIRED' using errcode = '22023';
  end if;

  v_lines := public.cart_check(p_items, true);
  if exists (select 1 from jsonb_array_elements(v_lines) x where not (x ->> 'ok')::boolean) then
    raise exception 'CART_CHANGED' using errcode = 'PT409', detail = v_lines::text;
  end if;

  -- Fulfilment per shop, checked before anything is written.
  for v_shop in select distinct (x ->> 'shop_id')::uuid from jsonb_array_elements(v_lines) x loop
    begin
      v_ful := coalesce(p_fulfilment ->> v_shop::text, 'PICKUP')::public.fulfilment_type;
    exception when invalid_text_representation then
      raise exception 'INVALID_FULFILMENT' using errcode = '22023';
    end;
    if v_ful = 'TO_TECHNICIAN' then
      raise exception 'INVALID_FULFILMENT' using errcode = '22023', detail = 'fitting bookings arrive in M3';
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
          case when p_method = 'BANKAK' then now() + make_interval(mins => public.setting_int('payment_window_minutes')::integer) end,
          case when v_addr is not null then p_address_id end, v_addr, p_idem)
  returning id into v_order;

  v_status := case when p_method = 'CASH' then 'CONFIRMED' else 'PENDING_PAYMENT' end;
  for v_shop in select distinct (x ->> 'shop_id')::uuid from jsonb_array_elements(v_lines) x loop
    v_ful := coalesce(p_fulfilment ->> v_shop::text, 'PICKUP')::public.fulfilment_type;
    select sum((x ->> 'price_sdg')::bigint * (x ->> 'qty')::bigint) into v_items
    from jsonb_array_elements(v_lines) x where (x ->> 'shop_id')::uuid = v_shop;
    v_delivery := case when v_ful = 'DELIVERY' then public.delivery_fee(v_shop, p_address_id) else 0 end;

    insert into public.sub_orders (order_id, shop_id, status, fulfilment, items_sdg, delivery_fee_sdg,
                                   commission_bp, commission_sdg)
    values (v_order, v_shop, v_status, v_ful, v_items, v_delivery, v_bp, public.commission_of(v_items, v_bp))
    returning id into v_sub;
    insert into public.suborder_events (sub_order_id, from_status, to_status, actor_kind, actor_id)
    values (v_sub, null, v_status, 'BUYER', v_uid);

    insert into public.order_items (sub_order_id, listing_id, offer_id, part_id, title_ar, title_en, condition,
                                    brand, warranty_days, unit_price_sdg, qty, line_sdg)
    select v_sub, (x ->> 'listing_id')::uuid, (x ->> 'offer_id')::uuid, (x ->> 'part_id')::uuid,
           x ->> 'title_ar', coalesce(nullif(x ->> 'title_en', ''), x ->> 'title_ar'),
           (x ->> 'condition')::public.listing_condition, x ->> 'brand', coalesce((x ->> 'warranty_days')::integer, 0),
           (x ->> 'price_sdg')::bigint, (x ->> 'qty')::integer,
           (x ->> 'price_sdg')::bigint * (x ->> 'qty')::integer
    from jsonb_array_elements(v_lines) x where (x ->> 'shop_id')::uuid = v_shop;

    -- Reserve stock; mark offers as taken.
    update public.listings l set reserved_qty = l.reserved_qty + (x ->> 'qty')::integer
    from jsonb_array_elements(v_lines) x
    where (x ->> 'shop_id')::uuid = v_shop and l.id = (x ->> 'listing_id')::uuid;
    update public.part_offers o set status = 'ORDERED'
    from jsonb_array_elements(v_lines) x
    where (x ->> 'shop_id')::uuid = v_shop and o.id = (x ->> 'offer_id')::uuid;

    if p_method = 'CASH' then
      insert into public.payments (order_id, sub_order_id, method, status, amount_sdg)
      values (v_order, v_sub, 'CASH', 'DUE', v_items + v_delivery);
      perform public.notify_shop(v_shop, 'NEW_ORDER',
                                 jsonb_build_object('order_id', v_order, 'sub_order_id', v_sub, 'ref', v_ref));
    end if;
    v_total_i := v_total_i + v_items;
    v_total_d := v_total_d + v_delivery;
  end loop;

  update public.orders set items_sdg = v_total_i, delivery_sdg = v_total_d, total_sdg = v_total_i + v_total_d
   where id = v_order;
  if p_method = 'BANKAK' then
    insert into public.payments (order_id, method, status, amount_sdg)
    values (v_order, 'BANKAK', 'AWAITING_TRANSFER', v_total_i + v_total_d);
  end if;

  delete from public.cart_items c
   where c.user_id = v_uid
     and (c.listing_id in (select (x ->> 'listing_id')::uuid from jsonb_array_elements(v_lines) x)
          or c.offer_id in (select (x ->> 'offer_id')::uuid from jsonb_array_elements(v_lines) x));
  perform public.notify(v_uid, 'ORDER_PLACED', jsonb_build_object('order_id', v_order, 'ref', v_ref));

  return public.idem_finish(p_idem, 'checkout', public.order_json(v_order));
end
$$;

-- The buyer cancels before any shop has started: every sub-order still waiting for
-- payment, or a cash order no shop has accepted yet. Under review → contact support.
create function public.cancel_order(p_order_id uuid, p_reason text default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := public.require_user();
  o     public.orders;
  s     public.sub_orders;
  v_pay public.payments;
begin
  select * into o from public.orders where id = p_order_id and buyer_id = v_uid for update;
  if o.id is null then raise exception 'ORDER_NOT_FOUND' using errcode = 'P0002'; end if;
  if exists (select 1 from public.sub_orders x where x.order_id = o.id
             and not (x.status = 'PENDING_PAYMENT'
                      or (x.status = 'CONFIRMED' and o.payment_method = 'CASH' and x.shop_ack_at is null)
                      or x.status = 'CANCELLED')) then
    raise exception 'CANNOT_CANCEL' using errcode = 'PT409';
  end if;
  select * into v_pay from public.payments p
   where p.order_id = o.id and p.method = 'BANKAK' and p.purpose = 'ORDER' for update;
  if v_pay.id is not null then
    if v_pay.status in ('AWAITING_TRANSFER', 'REJECTED') then
      perform public.transition_payment(v_pay.id, 'CANCELLED', 'BUYER', p_reason);
    elsif v_pay.status not in ('CANCELLED', 'EXPIRED') then
      raise exception 'CANNOT_CANCEL' using errcode = 'PT409';
    end if;
  end if;
  for s in select * from public.sub_orders x where x.order_id = o.id and x.status <> 'CANCELLED' loop
    perform public.transition_suborder(s.id, 'CANCELLED', 'BUYER', coalesce(nullif(btrim(p_reason), ''), 'BUYER_CANCELLED'));
  end loop;
  return public.order_json(o.id);
end
$$;

-- ------------------------------------------------------------------ requests RPCs
-- Photos are uploaded first to request-photos/{user id}/….
create function public.create_part_request(
  p_note        text,
  p_variant_id  uuid default null,
  p_category_id uuid default null,
  p_image_keys  text[] default '{}',
  p_idem        uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid  uuid := public.require_user();
  v_prev jsonb := public.idem_begin(p_idem, 'create_part_request');
  v_key  text;
  v_row  public.part_requests;
begin
  if v_prev is not null then return v_prev; end if;
  if (select count(*) from public.part_requests r where r.buyer_id = v_uid and r.status = 'OPEN') >= 10 then
    raise exception 'TOO_MANY_REQUESTS' using errcode = '22023';
  end if;
  foreach v_key in array coalesce(p_image_keys, '{}') loop
    if v_key not like v_uid::text || '/%' then
      raise exception 'INVALID_IMAGE_KEY' using errcode = '22023';
    end if;
  end loop;
  insert into public.part_requests (buyer_id, variant_id, category_id, note, image_keys)
  values (v_uid, p_variant_id, p_category_id, btrim(p_note), coalesce(p_image_keys, '{}'))
  returning * into v_row;

  -- Tell the shops that deal in this category or make (or every shop, when none do).
  insert into public.notifications (user_id, code, payload)
  select distinct m.user_id, 'NEW_PART_REQUEST', jsonb_build_object('request_id', v_row.id, 'shop_id', s.id)
  from public.shops s join public.shop_members m on m.shop_id = s.id
  where s.status = 'APPROVED'
    and public.request_matches_shop(v_row.id, s.id);

  return public.idem_finish(p_idem, 'create_part_request', to_jsonb(v_row));
exception
  when check_violation or foreign_key_violation then
    raise exception 'INVALID_REQUEST' using errcode = '22023', detail = sqlerrm;
end
$$;

create function public.close_part_request(p_request_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.part_requests set status = 'CLOSED'
   where id = p_request_id and buyer_id = public.require_user() and status = 'OPEN';
  if not found then raise exception 'REQUEST_NOT_FOUND' using errcode = 'P0002'; end if;
  update public.part_offers set status = 'EXPIRED' where request_id = p_request_id and status = 'OFFERED';
end
$$;

-- A shop sees requests in its specialities (category or make); a shop with no
-- specialities, or a request with no category and car, matches every shop.
create function public.request_matches_shop(p_request_id uuid, p_shop_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select not exists (select 1 from public.shop_specialities sp where sp.shop_id = p_shop_id)
      or (r.category_id is null and r.variant_id is null)
      or exists (select 1 from public.shop_specialities sp where sp.shop_id = p_shop_id and sp.category_id = r.category_id)
      or exists (select 1 from public.shop_specialities sp
                 join public.vehicle_models md on md.make_id = sp.make_id
                 join public.vehicle_variants v on v.model_id = md.id
                 where sp.shop_id = p_shop_id and v.id = r.variant_id)
  from public.part_requests r where r.id = p_request_id;
$$;

create function public.shop_open_requests(p_shop_id uuid, p_limit integer default 30, p_offset integer default 0)
returns setof jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform public.require_shop(p_shop_id);
  return query
    select to_jsonb(r) - 'buyer_id'
      || jsonb_build_object(
           'buyer_name', split_part(coalesce(nullif(pr.display_name, ''), '…'), ' ', 1),
           'my_offer', (select to_jsonb(o) from public.part_offers o
                        where o.request_id = r.id and o.shop_id = p_shop_id
                        order by o.created_at desc limit 1),
           'offer_count', (select count(*) from public.part_offers o where o.request_id = r.id and o.status = 'OFFERED'))
    from public.part_requests r
    join public.profiles pr on pr.id = r.buyer_id
    where r.status = 'OPEN' and r.expires_at > now() and public.request_matches_shop(r.id, p_shop_id)
    order by r.created_at desc
    limit least(greatest(coalesce(p_limit, 30), 1), 100) offset greatest(coalesce(p_offset, 0), 0);
end
$$;

-- One live offer per shop per request; a new one replaces the shop's previous offer.
create function public.shop_make_offer(
  p_shop_id       uuid,
  p_request_id    uuid,
  p_title_ar      text,
  p_condition     public.listing_condition,
  p_price_sdg     bigint,
  p_warranty_days integer default 0,
  p_note_ar       text default null,
  p_part_id       uuid default null,
  p_image_key     text default null,
  p_valid_hours   integer default 48,
  p_idem          uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid   uuid := public.require_shop_writable(p_shop_id);
  v_prev  jsonb := public.idem_begin(p_idem, 'shop_make_offer');
  v_buyer uuid;
  v_row   public.part_offers;
begin
  if v_prev is not null then return v_prev; end if;
  if (select s.status from public.shops s where s.id = p_shop_id) <> 'APPROVED' then
    raise exception 'SHOP_NOT_ACTIVE' using errcode = '42501';
  end if;
  select r.buyer_id into v_buyer from public.part_requests r
   where r.id = p_request_id and r.status = 'OPEN' and r.expires_at > now()
     and public.request_matches_shop(r.id, p_shop_id);
  if v_buyer is null then raise exception 'REQUEST_NOT_FOUND' using errcode = 'P0002'; end if;
  if p_image_key is not null and p_image_key not like 'shops/' || p_shop_id || '/%' then
    raise exception 'INVALID_IMAGE_KEY' using errcode = '22023';
  end if;
  update public.part_offers set status = 'WITHDRAWN'
   where request_id = p_request_id and shop_id = p_shop_id and status = 'OFFERED';
  insert into public.part_offers (request_id, shop_id, part_id, title_ar, condition, price_sdg, warranty_days,
                                  note_ar, image_key, valid_until, created_by)
  values (p_request_id, p_shop_id, p_part_id, btrim(p_title_ar), p_condition, p_price_sdg, coalesce(p_warranty_days, 0),
          nullif(btrim(coalesce(p_note_ar, '')), ''), p_image_key,
          now() + make_interval(hours => least(greatest(coalesce(p_valid_hours, 48), 1), 168)), v_uid)
  returning * into v_row;
  perform public.notify(v_buyer, 'NEW_OFFER', jsonb_build_object('request_id', p_request_id, 'offer_id', v_row.id,
                                                                  'shop_id', p_shop_id, 'price_sdg', p_price_sdg));
  return public.idem_finish(p_idem, 'shop_make_offer', to_jsonb(v_row));
exception
  when check_violation or foreign_key_violation then
    raise exception 'INVALID_OFFER' using errcode = '22023', detail = sqlerrm;
end
$$;

create function public.shop_withdraw_offer(p_shop_id uuid, p_offer_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.require_shop_writable(p_shop_id);
  update public.part_offers set status = 'WITHDRAWN'
   where id = p_offer_id and shop_id = p_shop_id and status = 'OFFERED';
  if not found then raise exception 'OFFER_NOT_FOUND' using errcode = 'P0002'; end if;
end
$$;

-- ------------------------------------------------------------------ RLS + grants
alter table public.part_requests enable row level security;
alter table public.part_offers enable row level security;
alter table public.cart_items enable row level security;
revoke all on public.part_requests, public.part_offers, public.cart_items from anon, authenticated;

grant select on public.part_requests, public.part_offers to authenticated;
grant select, insert, update, delete on public.cart_items to authenticated;

create policy part_requests_read on public.part_requests for select to authenticated
  using (buyer_id = (select auth.uid()) or (select public.is_admin()));
create policy part_offers_read on public.part_offers for select to authenticated
  using (exists (select 1 from public.part_requests r where r.id = request_id and r.buyer_id = (select auth.uid()))
         or public.is_shop_member(shop_id) or (select public.is_admin()));
create policy cart_items_own on public.cart_items for all to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

revoke all on function
  public.tg_cart_items_before(), public.delivery_fee(uuid, uuid), public.commission_of(bigint, integer),
  public.cart_check(jsonb, boolean), public.cart_validate(jsonb),
  public.checkout(jsonb, public.payment_method, jsonb, uuid, uuid), public.cancel_order(uuid, text),
  public.create_part_request(text, uuid, uuid, text[], uuid), public.close_part_request(uuid),
  public.request_matches_shop(uuid, uuid), public.shop_open_requests(uuid, integer, integer),
  public.shop_make_offer(uuid, uuid, text, public.listing_condition, bigint, integer, text, uuid, text, integer, uuid),
  public.shop_withdraw_offer(uuid, uuid)
from public, anon, authenticated;

grant execute on function public.cart_validate(jsonb) to anon, authenticated;
grant execute on function
  public.checkout(jsonb, public.payment_method, jsonb, uuid, uuid), public.cancel_order(uuid, text),
  public.create_part_request(text, uuid, uuid, text[], uuid), public.close_part_request(uuid),
  public.shop_open_requests(uuid, integer, integer),
  public.shop_make_offer(uuid, uuid, text, public.listing_condition, bigint, integer, text, uuid, text, integer, uuid),
  public.shop_withdraw_offer(uuid, uuid)
to authenticated;
