-- M1 catalogue: vehicles, job types, part categories, parts, fitment, synonyms, garage,
-- and the Arabic search normaliser (twin of packages/core/lib/src/data/arabic.dart).
--
-- Admins edit catalogue tables directly under RLS (no state machine here); every admin
-- change lands in audit_log through tg_audit_row (D-068).

-- ------------------------------------------------------------------ normaliser
-- أ/إ/آ/ٱ→ا, ة→ه, ى/ی→ي, ک→ك, Arabic-Indic digits → 0-9; strips tashkeel and tatweel;
-- lower-cases Latin; collapses whitespace.
create function public.ar_normalize(p text)
returns text
language sql
immutable
parallel safe
set search_path = ''
as $$
  select btrim(regexp_replace(
    lower(translate(
      regexp_replace(coalesce(p, ''), '[ً-ْٰـ]', '', 'g'),
      'أإآٱةىیک٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹',
      'ااااهييك01234567890123456789'
    )),
    '\s+', ' ', 'g'
  ));
$$;

-- Strips the definite article and common plural endings so "اللمبات" reaches "لمبه".
create function public.ar_stem(p_word text)
returns text
language plpgsql
immutable
parallel safe
set search_path = ''
as $$
declare
  v text := p_word;
begin
  if char_length(v) > 4 and left(v, 2) = 'ال' then v := substr(v, 3); end if;
  if char_length(v) > 4 and right(v, 2) in ('ات', 'ين', 'ون') then return left(v, -2); end if;
  if char_length(v) > 3 and right(v, 1) = 'ه' then return left(v, -1); end if;
  return v;
end
$$;

-- Normalised, stemmed words. Keeps Arabic and Latin letters, digits and . / - inside words
-- (OEM numbers, "5w-30", "265/65r17"); anything else separates words.
create function public.search_terms(p text)
returns text[]
language sql
immutable
parallel safe
set search_path = ''
as $$
  select coalesce(array_agg(distinct public.ar_stem(w)), '{}')
  from (
    select btrim(t, './-') as w
    from unnest(string_to_array(
      regexp_replace(public.ar_normalize(p), '[^0-9a-zء-ي./-]+', ' ', 'g'), ' '
    )) as t
  ) x
  where w <> '';
$$;

-- ------------------------------------------------------------------ audit trigger
create function public.tg_audit_row()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_row jsonb := case when tg_op = 'DELETE' then to_jsonb(old) else to_jsonb(new) end;
begin
  if auth.uid() is null then return null; end if;  -- migrations, seed and service jobs
  insert into public.audit_log (actor_id, action, entity, entity_id, data)
  values (
    auth.uid(), tg_op, tg_table_name, v_row ->> 'id',
    case when tg_op = 'UPDATE' then jsonb_build_object('old', to_jsonb(old), 'new', v_row) else v_row end
  );
  return null;
end
$$;

-- ------------------------------------------------------------------ vehicles
create table public.vehicle_makes (
  id         uuid primary key default gen_random_uuid(),
  slug       text not null unique check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  name_ar    text not null check (btrim(name_ar) <> ''),
  name_en    text not null check (btrim(name_en) <> ''),
  sort       integer not null default 0,
  is_active  boolean not null default true,
  updated_at timestamptz not null default now()
);

create table public.vehicle_models (
  id         uuid primary key default gen_random_uuid(),
  make_id    uuid not null references public.vehicle_makes (id),
  slug       text not null check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  name_ar    text not null check (btrim(name_ar) <> ''),
  name_en    text not null check (btrim(name_en) <> ''),
  sort       integer not null default 0,
  is_active  boolean not null default true,
  updated_at timestamptz not null default now(),
  unique (make_id, slug)
);
create index vehicle_models_make_idx on public.vehicle_models (make_id);

create table public.vehicle_variants (
  id          uuid primary key default gen_random_uuid(),
  model_id    uuid not null references public.vehicle_models (id),
  slug        text not null check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  year_from   integer not null check (year_from between 1950 and 2100),
  year_to     integer not null,
  engine_ar   text not null default '',
  engine_en   text not null default '',
  engine_code text,
  fuel        text check (fuel in ('PETROL', 'DIESEL', 'HYBRID', 'ELECTRIC')),
  sort        integer not null default 0,
  is_active   boolean not null default true,
  updated_at  timestamptz not null default now(),
  unique (model_id, slug),
  check (year_to between year_from and 2100)
);
create index vehicle_variants_model_idx on public.vehicle_variants (model_id);

-- ------------------------------------------------------------------ job types, categories
create table public.job_types (
  id         uuid primary key default gen_random_uuid(),
  code       text not null unique check (code ~ '^[A-Z][A-Z_]*$'),
  name_ar    text not null,
  name_en    text not null,
  sort       integer not null default 0,
  updated_at timestamptz not null default now()
);

create table public.part_categories (
  id              uuid primary key default gen_random_uuid(),
  parent_id       uuid references public.part_categories (id),
  slug            text not null unique check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  name_ar         text not null check (btrim(name_ar) <> ''),
  name_en         text not null check (btrim(name_en) <> ''),
  icon            text not null default 'accessories' check (icon in (
                    'lighting', 'brakes', 'oil', 'battery', 'electrical', 'ac', 'suspension',
                    'tyres', 'engine', 'transmission', 'body', 'accessories')),
  job_type_id     uuid references public.job_types (id),
  std_job_minutes integer check (std_job_minutes between 5 and 600),
  sort            integer not null default 0,
  is_active       boolean not null default true,
  updated_at      timestamptz not null default now(),
  check (parent_id is distinct from id)
);
create index part_categories_parent_idx on public.part_categories (parent_id);

-- ------------------------------------------------------------------ parts
create table public.parts (
  id                 uuid primary key default gen_random_uuid(),
  category_id        uuid not null references public.part_categories (id),
  name_ar            text not null check (char_length(btrim(name_ar)) between 2 and 120),
  name_en            text not null default '' check (char_length(name_en) <= 120),
  desc_ar            text check (char_length(desc_ar) <= 1000),
  desc_en            text check (char_length(desc_en) <= 1000),
  oem_numbers        text[] not null default '{}' check (cardinality(oem_numbers) <= 20),
  keywords           text[] not null default '{}' check (cardinality(keywords) <= 30),
  installable        boolean not null default true,
  std_job_minutes    integer check (std_job_minutes between 5 and 600),  -- overrides the category's
  created_by_shop_id uuid,           -- set for parts a shop typed in (FK added with shops)
  is_verified        boolean not null default true,  -- false until an admin checks a shop's part
  merged_into        uuid references public.parts (id),
  is_active          boolean not null default true,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now(),
  check (merged_into is distinct from id)
);
create index parts_category_idx on public.parts (category_id);
create index parts_shop_idx on public.parts (created_by_shop_id) where created_by_shop_id is not null;
comment on column public.parts.is_verified is
  'Shop-created parts start unverified (D-067); admins merge duplicates into catalogue parts.';

-- No rows for a part = no fitment data (CHECK_FITMENT). Rows present but none for the
-- buyer's car = the part does not fit and is hidden.
create table public.part_fitments (
  part_id    uuid not null references public.parts (id) on delete cascade,
  variant_id uuid not null references public.vehicle_variants (id) on delete cascade,
  note_ar    text check (char_length(note_ar) <= 200),
  note_en    text check (char_length(note_en) <= 200),
  primary key (part_id, variant_id)
);
create index part_fitments_variant_idx on public.part_fitments (variant_id);

-- ------------------------------------------------------------------ synonyms
-- One row = one group of words that mean the same thing (Arabic, English, local terms).
create table public.search_synonyms (
  id         uuid primary key default gen_random_uuid(),
  terms      text[] not null check (cardinality(terms) between 2 and 40),
  updated_by uuid references auth.users (id) on delete set null,
  updated_at timestamptz not null default now()
);

-- Normalised words of each group, maintained by trigger; used to expand queries.
create table public.search_synonym_terms (
  synonym_id uuid not null references public.search_synonyms (id) on delete cascade,
  term       text not null,
  primary key (synonym_id, term)
);
create index search_synonym_terms_term_idx on public.search_synonym_terms (term text_pattern_ops);

create function public.tg_synonym_terms()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  delete from public.search_synonym_terms where synonym_id = new.id;
  insert into public.search_synonym_terms (synonym_id, term)
  select new.id, t from unnest(public.search_terms(array_to_string(new.terms, ' '))) t
  on conflict do nothing;
  return null;
end
$$;

create trigger search_synonyms_terms
  after insert or update of terms on public.search_synonyms
  for each row execute function public.tg_synonym_terms();

-- A query word plus every word in a synonym group that one of its words starts with
-- (or, for words of 3+ letters, that starts the query word).
create function public.search_expand(p_term text)
returns text[]
language sql
stable
set search_path = ''
as $$
  select array(
    select distinct a from (
      select p_term as a
      union all select replace(p_term, '-', '')
      union all
      select t.term
      from public.search_synonym_terms t
      where char_length(p_term) >= 2
        and t.synonym_id in (
          select s.synonym_id from public.search_synonym_terms s
          where s.term like p_term || '%'
             or (char_length(p_term) >= 3 and p_term like s.term || '%')
        )
    ) x
    where a <> ''
  );
$$;

-- Prefix query over search terms: every query word must match (directly or via a synonym).
create function public.search_query(p_q text)
returns tsquery
language plpgsql
stable
set search_path = ''
as $$
declare
  v_term  text;
  v_parts text[] := '{}';
begin
  foreach v_term in array (public.search_terms(p_q))[1:8] loop
    v_parts := v_parts || (
      '(' || (select string_agg(quote_literal(a) || ':*', ' | ') from unnest(public.search_expand(v_term)) a) || ')'
    );
  end loop;
  if cardinality(v_parts) = 0 then return null; end if;
  return array_to_string(v_parts, ' & ')::tsquery;
end
$$;

-- ------------------------------------------------------------------ garage
create table public.garage_vehicles (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null default auth.uid() references auth.users (id) on delete cascade,
  variant_id uuid not null references public.vehicle_variants (id),
  nickname   text check (char_length(nickname) <= 40),
  vin        text check (vin ~ '^[A-HJ-NPR-Z0-9]{17}$'),
  plate      text check (char_length(plate) <= 20),
  is_default boolean not null default false,
  created_at timestamptz not null default now()
);
create unique index garage_vehicles_one_default on public.garage_vehicles (user_id) where is_default;
create index garage_vehicles_user_idx on public.garage_vehicles (user_id);

-- First car becomes the default; a new default clears the old one; at most 10 cars.
create function public.tg_garage_before()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.vin := nullif(upper(btrim(coalesce(new.vin, ''))), '');
  new.nickname := nullif(btrim(coalesce(new.nickname, '')), '');
  new.plate := nullif(btrim(coalesce(new.plate, '')), '');
  if tg_op = 'INSERT' then
    if (select count(*) from public.garage_vehicles g where g.user_id = new.user_id) >= 10 then
      raise exception 'GARAGE_FULL' using errcode = '22023';
    end if;
    if not exists (select 1 from public.garage_vehicles g where g.user_id = new.user_id) then
      new.is_default := true;
    end if;
  end if;
  if new.is_default then
    update public.garage_vehicles g set is_default = false
     where g.user_id = new.user_id and g.id <> new.id and g.is_default;
  end if;
  return new;
end
$$;

create function public.tg_garage_after_delete()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if old.is_default then
    update public.garage_vehicles g set is_default = true
     where g.id = (select g2.id from public.garage_vehicles g2
                   where g2.user_id = old.user_id order by g2.created_at desc limit 1);
  end if;
  return null;
end
$$;

create trigger garage_vehicles_before before insert or update on public.garage_vehicles
  for each row execute function public.tg_garage_before();
create trigger garage_vehicles_after_delete after delete on public.garage_vehicles
  for each row execute function public.tg_garage_after_delete();

-- ------------------------------------------------------------------ triggers
create trigger vehicle_makes_updated_at before update on public.vehicle_makes
  for each row execute function public.tg_set_updated_at();
create trigger vehicle_models_updated_at before update on public.vehicle_models
  for each row execute function public.tg_set_updated_at();
create trigger vehicle_variants_updated_at before update on public.vehicle_variants
  for each row execute function public.tg_set_updated_at();
create trigger job_types_updated_at before update on public.job_types
  for each row execute function public.tg_set_updated_at();
create trigger part_categories_updated_at before update on public.part_categories
  for each row execute function public.tg_set_updated_at();
create trigger parts_updated_at before update on public.parts
  for each row execute function public.tg_set_updated_at();
create trigger search_synonyms_updated_at before update on public.search_synonyms
  for each row execute function public.tg_set_updated_at();

create trigger vehicle_makes_audit after insert or update or delete on public.vehicle_makes
  for each row execute function public.tg_audit_row();
create trigger vehicle_models_audit after insert or update or delete on public.vehicle_models
  for each row execute function public.tg_audit_row();
create trigger vehicle_variants_audit after insert or update or delete on public.vehicle_variants
  for each row execute function public.tg_audit_row();
create trigger job_types_audit after insert or update or delete on public.job_types
  for each row execute function public.tg_audit_row();
create trigger part_categories_audit after insert or update or delete on public.part_categories
  for each row execute function public.tg_audit_row();
create trigger parts_audit after insert or update or delete on public.parts
  for each row execute function public.tg_audit_row();
create trigger part_fitments_audit after insert or update or delete on public.part_fitments
  for each row execute function public.tg_audit_row();
create trigger search_synonyms_audit after insert or update or delete on public.search_synonyms
  for each row execute function public.tg_audit_row();

-- ------------------------------------------------------------------ RLS + grants
alter table public.vehicle_makes enable row level security;
alter table public.vehicle_models enable row level security;
alter table public.vehicle_variants enable row level security;
alter table public.job_types enable row level security;
alter table public.part_categories enable row level security;
alter table public.parts enable row level security;
alter table public.part_fitments enable row level security;
alter table public.search_synonyms enable row level security;
alter table public.search_synonym_terms enable row level security;
alter table public.garage_vehicles enable row level security;

revoke all on public.vehicle_makes, public.vehicle_models, public.vehicle_variants, public.job_types,
              public.part_categories, public.parts, public.part_fitments, public.search_synonyms,
              public.search_synonym_terms, public.garage_vehicles
  from anon, authenticated;

-- Public catalogue: anyone reads active rows; admins read and write everything.
grant select on public.vehicle_makes, public.vehicle_models, public.vehicle_variants, public.job_types,
                public.part_categories, public.parts, public.part_fitments, public.search_synonyms
  to anon, authenticated;
-- Writes are admin-only through the policies below; shops create parts through RPCs.
grant insert, update, delete on public.vehicle_makes, public.vehicle_models, public.vehicle_variants,
                                public.job_types, public.part_categories, public.parts,
                                public.part_fitments, public.search_synonyms
  to authenticated;

create policy vehicle_makes_read on public.vehicle_makes for select to anon, authenticated
  using (is_active or (select public.is_admin()));
create policy vehicle_models_read on public.vehicle_models for select to anon, authenticated
  using (is_active or (select public.is_admin()));
create policy vehicle_variants_read on public.vehicle_variants for select to anon, authenticated
  using (is_active or (select public.is_admin()));
create policy job_types_read on public.job_types for select to anon, authenticated using (true);
create policy part_categories_read on public.part_categories for select to anon, authenticated
  using (is_active or (select public.is_admin()));
create policy parts_read on public.parts for select to anon, authenticated
  using ((is_active and merged_into is null) or (select public.is_admin()));
create policy part_fitments_read on public.part_fitments for select to anon, authenticated using (true);
create policy search_synonyms_read on public.search_synonyms for select to anon, authenticated using (true);

create policy vehicle_makes_admin on public.vehicle_makes for all to authenticated
  using ((select public.is_admin())) with check ((select public.is_admin()));
create policy vehicle_models_admin on public.vehicle_models for all to authenticated
  using ((select public.is_admin())) with check ((select public.is_admin()));
create policy vehicle_variants_admin on public.vehicle_variants for all to authenticated
  using ((select public.is_admin())) with check ((select public.is_admin()));
create policy job_types_admin on public.job_types for all to authenticated
  using ((select public.is_admin())) with check ((select public.is_admin()));
create policy part_categories_admin on public.part_categories for all to authenticated
  using ((select public.is_admin())) with check ((select public.is_admin()));
create policy parts_admin on public.parts for all to authenticated
  using ((select public.is_admin())) with check ((select public.is_admin()));
create policy part_fitments_admin on public.part_fitments for all to authenticated
  using ((select public.is_admin())) with check ((select public.is_admin()));
create policy search_synonyms_admin on public.search_synonyms for all to authenticated
  using ((select public.is_admin())) with check ((select public.is_admin()));

-- Garage: each buyer owns their rows and writes them directly.
grant select, insert, update, delete on public.garage_vehicles to authenticated;
create policy garage_vehicles_own on public.garage_vehicles for all to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

revoke all on function
  public.ar_normalize(text), public.ar_stem(text), public.search_terms(text), public.tg_audit_row(),
  public.tg_synonym_terms(), public.search_expand(text), public.search_query(text),
  public.tg_garage_before(), public.tg_garage_after_delete()
from public, anon, authenticated;
grant execute on function public.ar_normalize(text), public.search_terms(text) to anon, authenticated;
