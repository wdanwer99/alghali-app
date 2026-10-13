-- M1 inventory: listings, listing images, price history, Excel imports, and the per-part
-- search documents that search_parts() reads (D-066).

create type public.listing_condition as enum ('NEW_OEM', 'NEW_AFTERMARKET', 'USED');

-- ------------------------------------------------------------------ listings
create table public.listings (
  id               uuid primary key default gen_random_uuid(),
  shop_id          uuid not null references public.shops (id) on delete cascade,
  part_id          uuid not null references public.parts (id),
  sku              text check (char_length(sku) between 1 and 40),  -- the shop's own code, for imports
  condition        public.listing_condition not null,
  price_sdg        bigint check (price_sdg between 1 and 1000000000),
  price_on_request boolean not null default false,
  was_sdg          bigint,          -- the higher price before the last cut, shown as a deal
  price_changed_at timestamptz,
  stock_qty        integer not null default 0 check (stock_qty between 0 and 100000),
  reserved_qty     integer not null default 0 check (reserved_qty >= 0),
  warranty_days    integer not null default 0 check (warranty_days between 0 and 1825),
  brand            text check (char_length(brand) <= 40),
  note_ar          text check (char_length(note_ar) <= 300),
  is_active        boolean not null default true,
  archived_at      timestamptz,
  version          integer not null default 1,   -- optimistic concurrency for offline edits
  created_by       uuid references auth.users (id) on delete set null,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  check (price_on_request or price_sdg is not null),
  constraint listings_reserved_within_stock check (reserved_qty <= stock_qty),
  unique (shop_id, sku)
);
create index listings_part_idx on public.listings (part_id) where is_active and archived_at is null;
create index listings_shop_idx on public.listings (shop_id);

create table public.listing_images (
  id         uuid primary key default gen_random_uuid(),
  listing_id uuid not null references public.listings (id) on delete cascade,
  -- Storage prefix in media-public; the client uploads thumb.webp, medium.webp, large.webp, orig.jpg (D-008).
  base_key   text not null check (base_key ~ '^shops/[0-9a-f-]{36}/listings/[0-9a-f-]{36}$'),
  sort       integer not null default 0,
  created_at timestamptz not null default now()
);
create index listing_images_listing_idx on public.listing_images (listing_id, sort);

create table public.listing_price_history (
  id         bigint generated always as identity primary key,
  listing_id uuid not null references public.listings (id) on delete cascade,
  old_sdg    bigint,
  new_sdg    bigint,
  changed_by uuid references auth.users (id) on delete set null,
  changed_at timestamptz not null default now()
);
create index listing_price_history_listing_idx on public.listing_price_history (listing_id, changed_at desc);

create table public.import_jobs (
  id         uuid primary key default gen_random_uuid(),
  shop_id    uuid not null references public.shops (id) on delete cascade,
  file_name  text check (char_length(file_name) <= 200),
  total      integer not null,
  created    integer not null,
  updated    integer not null,
  failed     integer not null,
  report     jsonb not null,
  created_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now()
);
create index import_jobs_shop_idx on public.import_jobs (shop_id, created_at desc);

-- Bumps the version when the shop-visible fields change (not when checkout reserves stock),
-- and records price changes.
create function public.tg_listings_before_update()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if (new.part_id, new.sku, new.condition, new.price_sdg, new.price_on_request, new.stock_qty,
      new.warranty_days, new.brand, new.note_ar, new.is_active, new.archived_at)
     is distinct from
     (old.part_id, old.sku, old.condition, old.price_sdg, old.price_on_request, old.stock_qty,
      old.warranty_days, old.brand, old.note_ar, old.is_active, old.archived_at) then
    new.version := old.version + 1;
  end if;
  if new.price_sdg is distinct from old.price_sdg then
    new.was_sdg := case when old.price_sdg is not null and new.price_sdg < old.price_sdg
                        then greatest(old.price_sdg, coalesce(old.was_sdg, 0)) end;
    new.price_changed_at := now();
    insert into public.listing_price_history (listing_id, old_sdg, new_sdg, changed_by)
    values (old.id, old.price_sdg, new.price_sdg, auth.uid());
  end if;
  return new;
end
$$;

create trigger listings_before_update before update on public.listings
  for each row execute function public.tg_listings_before_update();
create trigger listings_updated_at before update on public.listings
  for each row execute function public.tg_set_updated_at();

-- ------------------------------------------------------------------ search documents
create table public.part_search_docs (
  part_id    uuid primary key references public.parts (id) on delete cascade,
  terms      text[] not null,
  doc        text not null,
  tsv        tsvector not null,
  updated_at timestamptz not null default now()
);
create index part_search_docs_tsv_idx on public.part_search_docs using gin (tsv);
create index part_search_docs_trgm_idx on public.part_search_docs using gin (doc extensions.gin_trgm_ops);

-- Part and category names (with the parent category), keywords, OEM numbers (with and
-- without dashes) and the brands shops list it under.
create function public.refresh_part_search_doc(p_part_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_terms text[];
begin
  select array(
    select distinct t from (
      select unnest(public.search_terms(concat_ws(' ',
               p.name_ar, p.name_en, c.name_ar, c.name_en, pc.name_ar, pc.name_en,
               array_to_string(p.keywords, ' '),
               (select string_agg(distinct l.brand, ' ') from public.listings l
                where l.part_id = p.id and l.brand is not null and l.archived_at is null)))) as t
      union all
      select o from unnest(public.search_terms(array_to_string(p.oem_numbers, ' '))) o
      union all
      select replace(o, '-', '') from unnest(public.search_terms(array_to_string(p.oem_numbers, ' '))) o
    ) x
    where t <> ''
  )
  into v_terms
  from public.parts p
  join public.part_categories c on c.id = p.category_id
  left join public.part_categories pc on pc.id = c.parent_id
  where p.id = p_part_id;

  if v_terms is null then
    delete from public.part_search_docs where part_id = p_part_id;
    return;
  end if;
  insert into public.part_search_docs (part_id, terms, doc, tsv, updated_at)
  values (p_part_id, v_terms, array_to_string(v_terms, ' '), array_to_tsvector(v_terms), now())
  on conflict (part_id) do update
    set terms = excluded.terms, doc = excluded.doc, tsv = excluded.tsv, updated_at = now();
end
$$;

create function public.tg_parts_search_doc()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.refresh_part_search_doc(new.id);
  return null;
end
$$;

create function public.tg_categories_search_doc()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.refresh_part_search_doc(p.id)
  from public.parts p
  where p.category_id = new.id
     or p.category_id in (select c.id from public.part_categories c where c.parent_id = new.id);
  return null;
end
$$;

create function public.tg_listings_search_doc()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op in ('INSERT', 'UPDATE') then
    perform public.refresh_part_search_doc(new.part_id);
  end if;
  if tg_op in ('UPDATE', 'DELETE') and (tg_op = 'DELETE' or old.part_id <> new.part_id) then
    perform public.refresh_part_search_doc(old.part_id);
  end if;
  return null;
end
$$;

create trigger parts_search_doc
  after insert or update of name_ar, name_en, keywords, oem_numbers, category_id on public.parts
  for each row execute function public.tg_parts_search_doc();
create trigger part_categories_search_doc
  after update of name_ar, name_en, parent_id on public.part_categories
  for each row execute function public.tg_categories_search_doc();
create trigger listings_search_doc_ins after insert on public.listings
  for each row when (new.brand is not null) execute function public.tg_listings_search_doc();
create trigger listings_search_doc_upd after update of brand, part_id, archived_at on public.listings
  for each row execute function public.tg_listings_search_doc();
create trigger listings_search_doc_del after delete on public.listings
  for each row when (old.brand is not null) execute function public.tg_listings_search_doc();

-- ------------------------------------------------------------------ helpers
create function public.listing_json(p_listing_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select to_jsonb(l)
    || jsonb_build_object(
         'available_qty', l.stock_qty - l.reserved_qty,
         'part', jsonb_build_object(
            'id', p.id, 'name_ar', p.name_ar, 'name_en', p.name_en, 'category_id', p.category_id,
            'installable', p.installable, 'is_verified', p.is_verified,
            'own', coalesce(p.created_by_shop_id = l.shop_id and not p.is_verified, false),
            'model_ids', coalesce((select jsonb_agg(distinct v.model_id) from public.part_fitments f
                                   join public.vehicle_variants v on v.id = f.variant_id
                                   where f.part_id = p.id), '[]')),
         'images', coalesce((select jsonb_agg(i.base_key order by i.sort, i.created_at)
                             from public.listing_images i where i.listing_id = l.id), '[]'))
  from public.listings l join public.parts p on p.id = l.part_id
  where l.id = p_listing_id;
$$;

-- Shops may write while PENDING (to prepare stock) or APPROVED; not when suspended or rejected.
create function public.require_shop_writable(p_shop_id uuid)
returns uuid
language plpgsql
stable
set search_path = ''
as $$
declare
  v_uid    uuid := public.require_shop(p_shop_id);
  v_status public.partner_status;
begin
  select s.status into v_status from public.shops s where s.id = p_shop_id;
  if v_status is null then raise exception 'SHOP_NOT_FOUND' using errcode = 'P0002'; end if;
  if v_status not in ('PENDING', 'APPROVED') and not public.is_admin() then
    raise exception 'SHOP_NOT_ACTIVE' using errcode = '42501';
  end if;
  return v_uid;
end
$$;

-- Replaces a part's fitment with every variant of the given models (empty = unknown).
create function public.set_part_fitment_by_models(p_part_id uuid, p_model_ids uuid[])
returns void
language sql
set search_path = ''
as $$
  delete from public.part_fitments where part_id = p_part_id;
  insert into public.part_fitments (part_id, variant_id)
  select p_part_id, v.id from public.vehicle_variants v
  where v.model_id = any (coalesce(p_model_ids, '{}')) and v.is_active
  on conflict do nothing;
$$;

-- Creates a shop's own (unverified) part, or edits it while it is still unverified (D-067).
-- p: {name_ar, name_en?, category_id, model_ids?, oem_numbers?}
create function public.shop_write_part(p_shop_id uuid, p_part_id uuid, p jsonb)
returns uuid
language plpgsql
set search_path = ''
as $$
declare
  v_id   uuid := p_part_id;
  v_cat  uuid := (p ->> 'category_id')::uuid;
  v_inst boolean;
begin
  if nullif(btrim(coalesce(p ->> 'name_ar', '')), '') is null then
    raise exception 'PART_NAME_REQUIRED' using errcode = '22023';
  end if;
  if char_length(btrim(p ->> 'name_ar')) not between 2 and 120
     or char_length(btrim(coalesce(p ->> 'name_en', ''))) > 120 then
    raise exception 'PART_NAME_INVALID' using errcode = '22023';
  end if;
  select c.job_type_id is not null into v_inst from public.part_categories c where c.id = v_cat and c.is_active;
  if v_inst is null then raise exception 'CATEGORY_NOT_FOUND' using errcode = '22023'; end if;

  if v_id is null then
    insert into public.parts (category_id, name_ar, name_en, installable, oem_numbers,
                              created_by_shop_id, is_verified)
    values (v_cat, btrim(p ->> 'name_ar'), btrim(coalesce(p ->> 'name_en', '')), v_inst,
            coalesce(array(select jsonb_array_elements_text(p -> 'oem_numbers')), '{}'), p_shop_id, false)
    returning id into v_id;
  else
    update public.parts set
      category_id = v_cat,
      name_ar     = btrim(p ->> 'name_ar'),
      name_en     = btrim(coalesce(p ->> 'name_en', name_en)),
      installable = v_inst,
      oem_numbers = case when p ? 'oem_numbers'
                         then coalesce(array(select jsonb_array_elements_text(p -> 'oem_numbers')), '{}')
                         else oem_numbers end
    where id = v_id;
  end if;
  if p ? 'model_ids' or p_part_id is null then
    perform public.set_part_fitment_by_models(
      v_id, coalesce(array(select jsonb_array_elements_text(p -> 'model_ids')::uuid), '{}'));
  end if;
  return v_id;
end
$$;

-- ------------------------------------------------------------------ RPCs: listings
-- Creates (no p_listing_id) or edits a listing. The part is either an existing one
-- (p_part_id: a verified part or one of the shop's own) or typed in by the shop
-- (p_new_part: {name_ar, name_en?, category_id, model_ids?, oem_numbers?}). Editing needs
-- the version the app last saw; a newer version on the server returns VERSION_CONFLICT.
create function public.shop_upsert_listing(
  p_shop_id          uuid,
  p_condition        public.listing_condition,
  p_stock_qty        integer,
  p_price_sdg        bigint default null,
  p_price_on_request boolean default false,
  p_warranty_days    integer default 0,
  p_brand            text default null,
  p_sku              text default null,
  p_note_ar          text default null,
  p_is_active        boolean default true,
  p_part_id          uuid default null,
  p_new_part         jsonb default null,
  p_listing_id       uuid default null,
  p_version          integer default null,
  p_idem             uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid  uuid := public.require_shop_writable(p_shop_id);
  v_prev jsonb := public.idem_begin(p_idem, 'shop_upsert_listing');
  v_old  public.listings;
  v_part uuid;
  v_own  boolean;
  v_id   uuid := p_listing_id;
begin
  if v_prev is not null then return v_prev; end if;
  if not coalesce(p_price_on_request, false) and coalesce(p_price_sdg, 0) <= 0 then
    raise exception 'PRICE_REQUIRED' using errcode = '22023';
  end if;
  if coalesce(p_stock_qty, -1) < 0 then
    raise exception 'INVALID_QTY' using errcode = '22023';
  end if;

  if v_id is not null then
    select * into v_old from public.listings l where l.id = v_id and l.shop_id = p_shop_id for update;
    if not found then raise exception 'LISTING_NOT_FOUND' using errcode = 'P0002'; end if;
    if p_version is distinct from v_old.version then
      raise exception 'VERSION_CONFLICT' using errcode = 'PT409', detail = v_old.version::text;
    end if;
  end if;

  if p_part_id is not null then
    select coalesce(p.merged_into, p.id), (p.created_by_shop_id = p_shop_id and not p.is_verified)
      into v_part, v_own
    from public.parts p
    where p.id = p_part_id and p.is_active and (p.is_verified or p.created_by_shop_id = p_shop_id);
    if v_part is null then raise exception 'PART_NOT_FOUND' using errcode = 'P0002'; end if;
    if p_new_part is not null then
      if not v_own then raise exception 'PART_NOT_EDITABLE' using errcode = '42501'; end if;
      perform public.shop_write_part(p_shop_id, v_part, p_new_part);
    end if;
  elsif p_new_part is not null then
    -- Editing a listing whose part the shop typed in edits that part instead of making a new one.
    if v_old.id is not null and exists (select 1 from public.parts p where p.id = v_old.part_id
                                        and p.created_by_shop_id = p_shop_id and not p.is_verified) then
      v_part := public.shop_write_part(p_shop_id, v_old.part_id, p_new_part);
    else
      v_part := public.shop_write_part(p_shop_id, null, p_new_part);
    end if;
  elsif v_old.id is not null then
    v_part := v_old.part_id;
  else
    raise exception 'PART_REQUIRED' using errcode = '22023';
  end if;

  if v_id is null then
    insert into public.listings (shop_id, part_id, sku, condition, price_sdg, price_on_request,
                                 stock_qty, warranty_days, brand, note_ar, is_active, created_by)
    values (p_shop_id, v_part, nullif(btrim(coalesce(p_sku, '')), ''), p_condition,
            case when coalesce(p_price_sdg, 0) > 0 then p_price_sdg end, coalesce(p_price_on_request, false),
            p_stock_qty, coalesce(p_warranty_days, 0), nullif(btrim(coalesce(p_brand, '')), ''),
            nullif(btrim(coalesce(p_note_ar, '')), ''), coalesce(p_is_active, true), v_uid)
    returning id into v_id;
  else
    update public.listings set
      part_id          = v_part,
      sku              = nullif(btrim(coalesce(p_sku, '')), ''),
      condition        = p_condition,
      price_sdg        = case when coalesce(p_price_sdg, 0) > 0 then p_price_sdg end,
      price_on_request = coalesce(p_price_on_request, false),
      stock_qty        = p_stock_qty,
      warranty_days    = coalesce(p_warranty_days, 0),
      brand            = nullif(btrim(coalesce(p_brand, '')), ''),
      note_ar          = nullif(btrim(coalesce(p_note_ar, '')), ''),
      is_active        = coalesce(p_is_active, true)
    where id = v_id;
  end if;

  return public.idem_finish(p_idem, 'shop_upsert_listing', public.listing_json(v_id));
exception
  when unique_violation then
    raise exception 'SKU_TAKEN' using errcode = 'PT409';
  when check_violation then
    if sqlerrm like '%listings_reserved_within_stock%' then
      raise exception 'STOCK_BELOW_RESERVED' using errcode = '22023';
    end if;
    raise exception 'INVALID_LISTING' using errcode = '22023', detail = sqlerrm;
  when not_null_violation then
    raise exception 'INVALID_LISTING' using errcode = '22023', detail = sqlerrm;
  when invalid_text_representation then
    raise exception 'INVALID_VALUE' using errcode = '22023', detail = sqlerrm;
end
$$;

-- Quick price/stock edits for many listings at once. Each item:
-- {listing_id, version, price_sdg?, stock_qty?, is_active?}. Items succeed or fail one by one;
-- a conflict returns the server's current values so the app can show them.
create function public.shop_bulk_update(p_shop_id uuid, p_items jsonb, p_idem uuid default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid     uuid := public.require_shop_writable(p_shop_id);
  v_prev    jsonb := public.idem_begin(p_idem, 'shop_bulk_update');
  v_item    jsonb;
  v_row     public.listings;
  v_results jsonb := '[]';
  v_err     text;
begin
  if v_prev is not null then return v_prev; end if;
  if jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) > 500 then
    raise exception 'INVALID_ITEMS' using errcode = '22023';
  end if;

  for v_item in select * from jsonb_array_elements(p_items) loop
    v_err := null;
    begin
      select * into v_row from public.listings l
       where l.id = (v_item ->> 'listing_id')::uuid and l.shop_id = p_shop_id
       for update;
      if not found then
        v_err := 'LISTING_NOT_FOUND';
      elsif (v_item ->> 'version')::integer is distinct from v_row.version then
        v_err := 'VERSION_CONFLICT';
      elsif v_item ? 'price_sdg' and coalesce((v_item ->> 'price_sdg')::bigint, 0) <= 0
            and not v_row.price_on_request then
        v_err := 'PRICE_REQUIRED';
      elsif v_item ? 'stock_qty' and coalesce((v_item ->> 'stock_qty')::integer, -1) < 0 then
        v_err := 'INVALID_QTY';
      else
        update public.listings l set
          price_sdg = case when v_item ? 'price_sdg' then nullif((v_item ->> 'price_sdg')::bigint, 0) else l.price_sdg end,
          stock_qty = case when v_item ? 'stock_qty' then (v_item ->> 'stock_qty')::integer else l.stock_qty end,
          is_active = case when v_item ? 'is_active' then (v_item ->> 'is_active')::boolean else l.is_active end
        where l.id = v_row.id
        returning * into v_row;
      end if;
    exception
      when check_violation then
        v_err := case when sqlerrm like '%listings_reserved_within_stock%' then 'STOCK_BELOW_RESERVED' else 'INVALID_VALUE' end;
      when invalid_text_representation or numeric_value_out_of_range then
        v_err := 'INVALID_VALUE';
    end;

    v_results := v_results || jsonb_build_object(
      'listing_id', v_item ->> 'listing_id',
      'ok', v_err is null,
      'error', v_err,
      'version', v_row.version,
      'current', case when v_err = 'VERSION_CONFLICT' then jsonb_build_object(
                   'price_sdg', v_row.price_sdg, 'stock_qty', v_row.stock_qty, 'is_active', v_row.is_active) end
    );
  end loop;

  return public.idem_finish(p_idem, 'shop_bulk_update', jsonb_build_object('results', v_results));
end
$$;

-- Hides a listing for good (it stays for past orders).
create function public.shop_archive_listing(p_shop_id uuid, p_listing_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.require_shop_writable(p_shop_id);
  update public.listings set archived_at = now(), is_active = false
   where id = p_listing_id and shop_id = p_shop_id and archived_at is null;
  if not found then raise exception 'LISTING_NOT_FOUND' using errcode = 'P0002'; end if;
end
$$;

-- Sets a listing's photos (already uploaded to media-public) in display order. At most 6.
create function public.shop_set_listing_images(p_shop_id uuid, p_listing_id uuid, p_base_keys text[])
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_key text;
begin
  perform public.require_shop_writable(p_shop_id);
  if not exists (select 1 from public.listings l where l.id = p_listing_id and l.shop_id = p_shop_id) then
    raise exception 'LISTING_NOT_FOUND' using errcode = 'P0002';
  end if;
  if cardinality(coalesce(p_base_keys, '{}')) > 6 then
    raise exception 'TOO_MANY_IMAGES' using errcode = '22023';
  end if;
  foreach v_key in array coalesce(p_base_keys, '{}') loop
    if v_key !~ ('^shops/' || p_shop_id || '/listings/[0-9a-f-]{36}$') then
      raise exception 'INVALID_IMAGE_KEY' using errcode = '22023';
    end if;
  end loop;
  delete from public.listing_images where listing_id = p_listing_id;
  insert into public.listing_images (listing_id, base_key, sort)
  select p_listing_id, k, o::integer - 1 from unnest(p_base_keys) with ordinality as t(k, o);
  return public.listing_json(p_listing_id);
end
$$;

-- The shop's stock list, newest change first. Archived listings are left out.
create function public.shop_listings(p_shop_id uuid, p_q text default '', p_limit integer default 50, p_offset integer default 0)
returns setof jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_query tsquery := public.search_query(p_q);
begin
  perform public.require_shop(p_shop_id);
  return query
    select public.listing_json(l.id)
    from public.listings l
    left join public.part_search_docs d on d.part_id = l.part_id
    where l.shop_id = p_shop_id and l.archived_at is null
      and (v_query is null or d.tsv @@ v_query or l.sku ilike btrim(p_q) || '%')
    order by l.updated_at desc
    limit least(greatest(coalesce(p_limit, 50), 1), 200) offset greatest(coalesce(p_offset, 0), 0);
end
$$;

-- ------------------------------------------------------------------ RPCs: import
-- Rows come from the inventory-import Edge Function, already parsed from the sheet:
-- {row, sku?, name_ar, name_en?, category, condition, price_sdg?, price_on_request?,
--  stock_qty, warranty_days?, brand?, models?: text[], oem?}.
-- A row matches an existing listing by SKU, or else by part name + condition + brand;
-- otherwise it creates the shop's own part and a listing. Bad rows are skipped and reported.
create function public.shop_import_rows(
  p_shop_id   uuid,
  p_rows      jsonb,
  p_dry_run   boolean default false,
  p_file_name text default null,
  p_idem      uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid      uuid := public.require_shop_writable(p_shop_id);
  v_prev     jsonb := public.idem_begin(p_idem, 'shop_import_rows');
  v_row      jsonb;
  v_n        integer;
  v_cat      uuid;
  v_cond     public.listing_condition;
  v_models   uuid[];
  v_model    text;
  v_mid      uuid;
  v_listing  public.listings;
  v_part     uuid;
  v_price    bigint;
  v_por      boolean;
  v_created  integer := 0;
  v_updated  integer := 0;
  v_errors   jsonb := '[]';
  v_warnings jsonb := '[]';
  v_report   jsonb;
  v_job      uuid;
begin
  if v_prev is not null then return v_prev; end if;
  if jsonb_typeof(p_rows) <> 'array' or jsonb_array_length(p_rows) > 2000 then
    raise exception 'TOO_MANY_ROWS' using errcode = '22023';
  end if;

  begin  -- everything in here is rolled back for a dry run
    for v_row in select * from jsonb_array_elements(p_rows) loop
      v_n := coalesce((v_row ->> 'row')::integer, 0);
      begin
        if nullif(btrim(coalesce(v_row ->> 'name_ar', '')), '') is null then
          raise exception 'NAME_REQUIRED';
        end if;

        -- Exact name, slug or English name first; else any shared search word ("اضاءة" → الإضاءة).
        select c.id into v_cat from public.part_categories c
         where c.is_active and (c.slug = lower(btrim(v_row ->> 'category'))
            or public.ar_normalize(c.name_ar) = public.ar_normalize(v_row ->> 'category')
            or lower(c.name_en) = lower(btrim(v_row ->> 'category'))
            or public.search_terms(c.name_ar || ' ' || c.name_en) && public.search_terms(v_row ->> 'category'))
         order by (public.ar_normalize(c.name_ar) = public.ar_normalize(v_row ->> 'category')
                   or c.slug = lower(btrim(v_row ->> 'category'))
                   or lower(c.name_en) = lower(btrim(v_row ->> 'category'))) desc,
                  c.sort
         limit 1;
        if v_cat is null then raise exception 'CATEGORY_NOT_FOUND'; end if;

        begin
          v_cond := (v_row ->> 'condition')::public.listing_condition;
        exception when invalid_text_representation then
          raise exception 'INVALID_CONDITION';
        end;
        if v_cond is null then raise exception 'INVALID_CONDITION'; end if;

        v_por := coalesce((v_row ->> 'price_on_request')::boolean, false);
        v_price := nullif((v_row ->> 'price_sdg')::bigint, 0);
        if not v_por and coalesce(v_price, 0) <= 0 then raise exception 'PRICE_REQUIRED'; end if;
        if coalesce((v_row ->> 'stock_qty')::integer, -1) < 0 then raise exception 'INVALID_QTY'; end if;

        v_models := null;
        if jsonb_typeof(v_row -> 'models') = 'array' and jsonb_array_length(v_row -> 'models') > 0 then
          v_models := '{}';
          for v_model in select jsonb_array_elements_text(v_row -> 'models') loop
            select m.id into v_mid from public.vehicle_models m join public.vehicle_makes mk on mk.id = m.make_id
             where m.is_active and (
                   public.ar_normalize(m.name_ar) = public.ar_normalize(v_model)
                or lower(m.name_en) = lower(btrim(v_model))
                or m.slug = lower(btrim(v_model))
                or public.ar_normalize(mk.name_ar || ' ' || m.name_ar) = public.ar_normalize(v_model)
                or lower(mk.name_en || ' ' || m.name_en) = lower(btrim(v_model)))
             limit 1;
            if v_mid is null then
              v_warnings := v_warnings || jsonb_build_object('row', v_n, 'code', 'MODEL_NOT_FOUND', 'value', v_model);
            else
              v_models := v_models || v_mid;
            end if;
          end loop;
        end if;

        -- Find the listing this row updates.
        v_listing := null;
        if nullif(btrim(coalesce(v_row ->> 'sku', '')), '') is not null then
          select * into v_listing from public.listings l
           where l.shop_id = p_shop_id and l.sku = btrim(v_row ->> 'sku') for update;
        else
          select l.* into v_listing from public.listings l join public.parts p on p.id = l.part_id
           where l.shop_id = p_shop_id and l.archived_at is null and l.sku is null
             and public.ar_normalize(p.name_ar) = public.ar_normalize(v_row ->> 'name_ar')
             and l.condition = v_cond
             and lower(coalesce(l.brand, '')) = lower(btrim(coalesce(v_row ->> 'brand', '')))
           limit 1 for update of l;
        end if;

        if v_listing.id is null then
          v_part := public.shop_write_part(p_shop_id, null, jsonb_build_object(
            'name_ar', v_row ->> 'name_ar', 'name_en', v_row ->> 'name_en', 'category_id', v_cat,
            'model_ids', to_jsonb(coalesce(v_models, '{}')),
            'oem_numbers', case when nullif(btrim(coalesce(v_row ->> 'oem', '')), '') is not null
                                then jsonb_build_array(btrim(v_row ->> 'oem')) else '[]' end));
          insert into public.listings (shop_id, part_id, sku, condition, price_sdg, price_on_request,
                                       stock_qty, warranty_days, brand, created_by)
          values (p_shop_id, v_part, nullif(btrim(coalesce(v_row ->> 'sku', '')), ''), v_cond, v_price, v_por,
                  (v_row ->> 'stock_qty')::integer, coalesce((v_row ->> 'warranty_days')::integer, 0),
                  nullif(btrim(coalesce(v_row ->> 'brand', '')), ''), v_uid);
          v_created := v_created + 1;
        else
          update public.listings l set
            condition        = v_cond,
            price_sdg        = v_price,
            price_on_request = v_por,
            stock_qty        = (v_row ->> 'stock_qty')::integer,
            warranty_days    = coalesce((v_row ->> 'warranty_days')::integer, l.warranty_days),
            brand            = nullif(btrim(coalesce(v_row ->> 'brand', '')), ''),
            archived_at      = null,
            is_active        = true
          where l.id = v_listing.id;
          if v_models is not null and exists (select 1 from public.parts p where p.id = v_listing.part_id
                                              and p.created_by_shop_id = p_shop_id and not p.is_verified) then
            perform public.set_part_fitment_by_models(v_listing.part_id, v_models);
          end if;
          v_updated := v_updated + 1;
        end if;
      exception
        when raise_exception or invalid_parameter_value then
          v_errors := v_errors || jsonb_build_object('row', v_n, 'code', sqlerrm);
        when check_violation then
          v_errors := v_errors || jsonb_build_object('row', v_n, 'code',
                        case when sqlerrm like '%listings_reserved_within_stock%' then 'STOCK_BELOW_RESERVED' else 'INVALID_VALUE' end);
        when invalid_text_representation or numeric_value_out_of_range or not_null_violation then
          v_errors := v_errors || jsonb_build_object('row', v_n, 'code', 'INVALID_VALUE');
        when unique_violation then
          v_errors := v_errors || jsonb_build_object('row', v_n, 'code', 'DUPLICATE_SKU');
      end;
    end loop;

    v_report := jsonb_build_object(
      'total', jsonb_array_length(p_rows), 'created', v_created, 'updated', v_updated,
      'failed', jsonb_array_length(v_errors), 'errors', v_errors, 'warnings', v_warnings,
      'dry_run', coalesce(p_dry_run, false));
    if coalesce(p_dry_run, false) then
      raise exception 'DRY_RUN_ROLLBACK';
    end if;
  exception
    when raise_exception then
      if sqlerrm <> 'DRY_RUN_ROLLBACK' then raise; end if;
      return v_report;  -- dry run: nothing kept, nothing stored for replay
  end;

  insert into public.import_jobs (shop_id, file_name, total, created, updated, failed, report, created_by)
  values (p_shop_id, p_file_name, jsonb_array_length(p_rows), v_created, v_updated,
          jsonb_array_length(v_errors), v_report, v_uid)
  returning id into v_job;
  return public.idem_finish(p_idem, 'shop_import_rows', v_report || jsonb_build_object('job_id', v_job));
end
$$;

-- ------------------------------------------------------------------ RPCs: admin
-- Moves every listing of a duplicate part onto the catalogue part and retires the duplicate.
create function public.admin_merge_parts(p_from uuid, p_into uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.require_admin();
  if p_from = p_into then raise exception 'SAME_PART' using errcode = '22023'; end if;
  if not exists (select 1 from public.parts where id = p_into and is_active and merged_into is null) then
    raise exception 'PART_NOT_FOUND' using errcode = 'P0002';
  end if;
  update public.parts set merged_into = p_into, is_active = false where id = p_from and merged_into is null;
  if not found then raise exception 'PART_NOT_FOUND' using errcode = 'P0002'; end if;
  update public.listings set part_id = p_into where part_id = p_from;
  -- Keep the target's fitment; borrow the duplicate's only when the target has none.
  if not exists (select 1 from public.part_fitments where part_id = p_into) then
    insert into public.part_fitments (part_id, variant_id, note_ar, note_en)
    select p_into, f.variant_id, f.note_ar, f.note_en from public.part_fitments f where f.part_id = p_from
    on conflict do nothing;
  end if;
  perform public.audit('MERGE', 'part', p_from::text, jsonb_build_object('into', p_into));
end
$$;

-- ------------------------------------------------------------------ RLS + grants
alter table public.listings enable row level security;
alter table public.listing_images enable row level security;
alter table public.listing_price_history enable row level security;
alter table public.import_jobs enable row level security;
alter table public.part_search_docs enable row level security;

revoke all on public.listings, public.listing_images, public.listing_price_history, public.import_jobs,
              public.part_search_docs
  from anon, authenticated;
grant select on public.listings, public.listing_images to anon, authenticated;
grant select on public.listing_price_history, public.import_jobs to authenticated;

create policy listings_read on public.listings for select to anon, authenticated
  using (
    (is_active and archived_at is null
     and exists (select 1 from public.shops s where s.id = shop_id and s.status = 'APPROVED'))
    or public.is_shop_member(shop_id)
    or (select public.is_admin())
  );
create policy listing_images_read on public.listing_images for select to anon, authenticated
  using (exists (select 1 from public.listings l where l.id = listing_id));  -- inherits listings_read
create policy listing_price_history_read on public.listing_price_history for select to authenticated
  using (exists (select 1 from public.listings l where l.id = listing_id
                 and (public.is_shop_member(l.shop_id) or (select public.is_admin()))));
create policy import_jobs_read on public.import_jobs for select to authenticated
  using (public.is_shop_member(shop_id) or (select public.is_admin()));

revoke all on function
  public.tg_listings_before_update(), public.refresh_part_search_doc(uuid), public.tg_parts_search_doc(),
  public.tg_categories_search_doc(), public.tg_listings_search_doc(), public.listing_json(uuid),
  public.require_shop_writable(uuid), public.set_part_fitment_by_models(uuid, uuid[]),
  public.shop_write_part(uuid, uuid, jsonb),
  public.shop_upsert_listing(uuid, public.listing_condition, integer, bigint, boolean, integer, text, text,
                             text, boolean, uuid, jsonb, uuid, integer, uuid),
  public.shop_bulk_update(uuid, jsonb, uuid), public.shop_archive_listing(uuid, uuid),
  public.shop_set_listing_images(uuid, uuid, text[]), public.shop_listings(uuid, text, integer, integer),
  public.shop_import_rows(uuid, jsonb, boolean, text, uuid), public.admin_merge_parts(uuid, uuid)
from public, anon, authenticated;

grant execute on function
  public.shop_upsert_listing(uuid, public.listing_condition, integer, bigint, boolean, integer, text, text,
                             text, boolean, uuid, jsonb, uuid, integer, uuid),
  public.shop_bulk_update(uuid, jsonb, uuid), public.shop_archive_listing(uuid, uuid),
  public.shop_set_listing_images(uuid, uuid, text[]), public.shop_listings(uuid, text, integer, integer),
  public.shop_import_rows(uuid, jsonb, boolean, text, uuid), public.admin_merge_parts(uuid, uuid)
to authenticated;
