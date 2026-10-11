# Alghali Street Platform — Plan

**Status:** v1.1 · approved by owner 2026-10-10 (with change: email login for everyone, phone OTP deferred) · M0 done · UI pass on sample data done 2026-10-11 · M1 not started
**Source brief:** [`claude-code-prompt-alghali.md`](../claude-code-prompt-alghali.md) · **Decisions log:** [`DECISIONS.md`](DECISIONS.md)

---

## 0. Changes from the brief (agreed with owner on 2026-10-10)

| Area | Brief | Now | Why |
|---|---|---|---|
| Backend | NestJS + Prisma + Redis/BullMQ + Meilisearch + MinIO on docker-compose | **Supabase (hosted)**: Postgres + PostGIS, Auth, Storage, Realtime, Edge Functions (TypeScript/Deno), pg_cron, pgmq queues | No Docker on the dev machine; owner chose hosted Supabase |
| Business logic | NestJS services | **Postgres RPC functions** (`SECURITY DEFINER`, explicit role + ownership checks) for every state change; **Edge Functions** for the slot engine, file parsing and outbound messaging | Keeps the rules next to the data, in one transaction |
| Search | Meilisearch | **Postgres full-text + `pg_trgm`** over an Arabic-normalised search document, with a synonyms table | One fewer service; good enough for ~10k listings |
| Slot holds | Redis | **`HELD` booking rows** covered by the same `EXCLUDE` constraint, with `hold_expires_at` and a cron sweeper | Holds can't race confirmed bookings |
| Jobs / retries | BullMQ | **pgmq** (Supabase Queues) + **pg_cron** (+ `pg_net` to call Edge Functions) | Built into Supabase |
| Image sizes | sharp on upload | The **client** makes thumb/medium/large + capped original before upload; storage policies enforce type and size | Supabase image transforms need a paid plan; this also saves buyers' data |
| API contract | OpenAPI + generated clients | `supabase gen types` → **`packages/db-types`** (TS) for admin and tests; **typed Dart models** (freezed) + RPC wrappers in `packages/core`; `docs/API.md` lists every RPC/function | PostgREST/RPC replaces REST controllers |
| Dio | HTTP client | Dropped; `supabase_flutter` handles HTTP | Fewer dependencies |
| Labour price | Not specified | **Each technician sets a labour price per job type** (admin can set min/max) | Owner decision |
| Cash to technician | Not specified | **The technician collects the cash and hands the part money to the shop at pickup** (both confirm in the app); commission is netted from the shop's payout, the booking fee from the technician's | Owner decision |
| Apps | Buyer + partner | Unchanged: **two Flutter apps** sharing `packages/core` | Owner decision |
| Login | Phone + OTP | **Email + password for everyone**. Phone number is collected as an unverified profile field (shops/technicians call buyers; SMS alerts later). **Phone OTP is deferred** past the MVP, behind the same auth screens | Owner decision (D-030) |

Everything else in the brief stands: Arabic-first RTL, offline outbox, Bankak confirmed-transfer, SMS fallback, integer SDG, UTC storage with `Africa/Khartoum` display, all milestones and the acceptance journey.

---

## 1. Architecture

```
 Buyer app (Flutter) ──┐                        ┌── Edge Functions (TypeScript)
 Partner app (Flutter) ├── supabase SDKs ──► Supabase ──┤    booking-technicians · booking-slots · booking-hold
 Admin (Next.js) ──────┘   Auth · PostgREST ·   │    inventory-import · notify-dispatch
                           Storage · Realtime    └── Postgres: tables + RLS + RPC + triggers
                                                      PostGIS · btree_gist · pg_trgm · pg_cron · pgmq · pg_net
```

**Rules of the road**
1. **Postgres holds the truth and the rules.** Status columns can only change through RPCs that (a) check the caller's role and ownership and (b) check the transition against the state machine's transition table. A trigger rejects any other status update, including ones from admin tools.
2. **Reads** go through PostgREST with Row Level Security. **Business writes** go through RPCs. **Simple owned rows** (garage, addresses, availability rules, devices, chat messages) are written directly under RLS.
3. **Edge Functions** are only for logic we want as pure, unit-tested TypeScript (the slot engine, fee maths), external I/O (SMS/push/WhatsApp), and file parsing (xlsx).
4. **Money** is `bigint` SDG everywhere. Percentages are stored as basis points, and rounding is half-up to whole SDG. **Time** is `timestamptz` in UTC. Weekly availability is local wall-clock time in `Africa/Khartoum` (UTC+2, no DST).
5. **Idempotency:** every mutating RPC and Edge Function takes an idempotency key (`p_idem uuid`, or the `Idempotency-Key` header for functions). Replays return the stored result. This is what makes the offline outbox safe.
6. **Extensibility hooks for out-of-scope items:** `payment_method` enum (card/USD later), `markets`/`streets` (multiple cities), fulfilment providers (fleet), and a notification channel interface.

### Repo layout
```
/supabase
  config.toml
  migrations/              timestamped SQL: schema, RLS, RPCs, triggers, cron
  functions/
    _shared/               pure TS domain code (slot engine, fees, Arabic normaliser) — no runtime APIs
    booking-technicians/  booking-slots/  booking-hold/
    inventory-import/  notify-dispatch/
  seed/                    JSON sources + generator → seed SQL / auth users via admin API
/apps/buyer                Flutter buyer app
/apps/partner              Flutter shop + technician app
/apps/admin                Next.js admin (App Router, Tailwind, shadcn/ui, next-intl)
/packages/core             Dart: models, Supabase repositories, Drift cache + outbox/sync, theme, RTL widgets, shared l10n
/packages/db-types         generated TS types for Supabase schema
/tests                     vitest: DB/RLS integration, state machines, concurrency, API journey e2e
/infra                     scripts: bootstrap, seed, gen-types, reset-test-db
/docs                      PLAN, ARCHITECTURE, API, DECISIONS
```

### Environments and the one-command experience
| Env | What | Used by |
|---|---|---|
| `alghali-dev` (Supabase project) | Shared dev backend with seed data | Apps while developing |
| `alghali-test` (Supabase project) | Wiped and re-migrated before test runs | `pnpm test` locally |
| CI | `supabase start` inside GitHub Actions (Docker exists on GitHub runners) | Pull requests; no hosted project touched |

- `pnpm dev` pushes pending migrations to dev, regenerates types and starts the admin on `:3000`.
- `pnpm buyer` / `pnpm partner` wrap `flutter run`.
- `pnpm test` runs vitest (DB + domain), then `flutter test` for all packages.
- The free plan allows 2 active projects, and inactive free projects pause after about a week (see Risks).

---

## 2. Milestones

Every milestone ends with: lint + tests green, docs updated, a commit, and a short summary to the owner. **I wait for the go-ahead before starting the next one.**

**Progress**
- **M0 — done 2026-10-10** (`4781714`). First CI run green on 2026-10-12 (private repo `wdanwer99/alghali-app`).
  - 2026-10-11: `alghali-dev` and `alghali-test` created (Frankfurt, free plan), migrations pushed, email confirmation off, DB tests green against `alghali-test` — so every extension we need is available on the free plan.

  The custom-access-token hook and Edge Function deploy checks move to M1 and M3, where they're first used.
- **UI pass on sample data — done 2026-10-11** (owner's request, before M1; D-047–D-055):
  - Brand look: charcoal + red, bundled Arabic font, placeholder logo, app icons and splash screens.
  - Buyer app: welcome, home, street strip, search, part, shop, cart, checkout, Bankak transfer, fitting booking, orders, bookings, part requests, chat, garage, notifications, account.
  - Partner app: shop (orders, stock, quick listing, quotes, money, staff, insights) and technician (job offers, jobs with job code, schedule, earnings, profile).
  - Admin: overview, Bankak queue, applications, orders, bookings, cash reconciliation, payouts, disputes, catalogue, settings, sign-in.

  M4–M6 connect these screens to the backend instead of building them from scratch.

| # | Scope | Exit criteria |
|---|---|---|
| **M0 Scaffold** | `git init`. pnpm workspace (admin, tests, db-types). Dart pub workspace (buyer, partner, core). Supabase CLI as a dev dependency, linked to dev. First migration (extensions + `app_settings`). Empty buyer/partner apps with Arabic default, RTL, language switch, theme, go_router, Riverpod, Drift, plus a "ping" against Supabase. Empty admin with ar/en, RTL and a login shell. ESLint/Prettier, `flutter analyze` (strict lints), vitest. GitHub Actions CI. **Spike** to confirm free-plan support for: custom-access-token hook, pg_cron, pgmq, PostGIS, btree_gist, and Edge Function deploy without Docker. | All three apps build and open in Arabic RTL; CI green; spike results written to DECISIONS |
| **M1 Foundation** | **Identity:** email + password sign-up/sign-in (Supabase Auth), password reset (once custom SMTP is set up). Roles table and JWT claims. Profiles (with unverified phone), devices. Supabase Auth rate limits on sign-in/sign-up. **Catalogue:** makes/models/variants (year range, engine), category tree, job types, standard durations, parts with OEM numbers, fitment. **Location:** market/street/zones/shops/staff. **Inventory:** listings, images, bulk price/stock RPC, xlsx import function plus downloadable template, price history. **Settings.** **Search:** normaliser, synonyms, `FITS`/`CHECK_FITMENT`. **Garage.** Storage buckets + policies. **Seed data.** Generated TS types and Dart models. | RLS/authz test matrix for every M1 table; normaliser and search tests ("لمبات" finds لمبة/لمبه/bulb); bulk update + import tests; seed loads cleanly |
| **M2 Commerce** | Cart; checkout (multi-shop split, price re-check, price lock, stock reservation, payment window); SubOrder state machine; Bankak receipts + admin queue; cash payments; ledger + statements + payouts; returns; photo requests + offers; chat (messages, Realtime, voice notes). | Table-driven state-machine tests; e2e checkout + payment confirmation; ledger balances to zero for every journal; a reused Bankak transaction number is rejected |
| **M3 Installation** | Technicians (skills, makes, labour price, work mode, home bay, radius); availability + time off + quick block; **slot engine** (TS); ranking; holds; `EXCLUDE` constraint; booking lifecycle with offers, timeouts and reassignment; deposits; cancellation rules; part-does-not-fit; job code; photos; en-route location; **notifications dispatcher** (pgmq, templates ar/en, push/SMS/WhatsApp stubs, retries); reminders; reviews; disputes. | Slot engine unit tests (wide coverage); booking state machine tests; **concurrency test: 20 parallel holds on one technician slot → exactly 1 succeeds**; timeout/reassign tests; cancellation fee maths |
| **M4 Buyer app** | Every screen in brief §8 against the real backend, offline cache + outbox, data saver, street strip (CustomPainter). | Widget tests per screen in RTL + LTR; outbox replay test; integration test of the happy path on emulator |
| **M5 Partner app** | Shop + technician screens in brief §8; offline drafts for quick listing. | Same bar as M4 |
| **M6 Admin** | Approvals, Bankak queue (receipt beside order), cash reconciliation, catalogue/fitment, synonyms, orders/bookings browser, disputes, settings, payouts, basic reports. | Playwright smoke tests for each queue; ar/en RTL check |
| **M7 Hardening** | Full acceptance journey e2e (API level + one Flutter integration run); low-end Android emulator profiling (Android 8, 2 GB RAM); security review (RLS on every table, every RPC's authz, login brute-force/sign-up abuse, upload checks); deployment README. | Journey steps 1–9 pass; security checklist signed off |

---

## 3. Data model draft (Postgres / Supabase)

Conventions: `id uuid default gen_random_uuid()`, `created_at/updated_at timestamptz default now()`. Money columns end in `_sdg` and are `bigint`. Bilingual text uses `*_ar` (required) + `*_en`. All tables have RLS **enabled**, and a CI test fails if any table has RLS off.

### 3.1 Enums
```sql
app_role            : BUYER, SHOP_OWNER, SHOP_STAFF, TECHNICIAN, ADMIN
partner_status      : PENDING, APPROVED, REJECTED, SUSPENDED
listing_condition   : NEW_OEM, NEW_AFTERMARKET, USED
fulfilment_type     : PICKUP, DELIVERY, TO_TECHNICIAN
suborder_status     : PENDING_PAYMENT, PAYMENT_REVIEW, CONFIRMED, READY, PICKED_UP, OUT_FOR_DELIVERY,
                      DELIVERED, HANDED_TO_TECHNICIAN, COMPLETED, CANCELLED, REJECTED_BY_SHOP,
                      RETURN_REQUESTED, RETURNED
payment_method      : BANKAK, CASH
payment_purpose     : ORDER, BOOKING_DEPOSIT
payment_status      : AWAITING_TRANSFER, RECEIPT_SUBMITTED, CONFIRMED, REJECTED, DUE, COLLECTED, EXPIRED
work_mode           : BAY, MOBILE, BOTH
booking_location    : BAY, CUSTOMER_LOCATION
booking_status      : HELD, AWAITING_PAYMENT, PENDING_TECH_ACCEPT, ACCEPTED, EN_ROUTE, IN_PROGRESS, COMPLETED,
                      NEEDS_RESCHEDULE, EXPIRED, CANCELLED_BY_BUYER, CANCELLED_BY_TECH, CANCELLED_BY_ADMIN,
                      PART_DOES_NOT_FIT
offer_status        : OFFERED, ACCEPTED, DECLINED, TIMED_OUT, WITHDRAWN
notify_channel      : PUSH, SMS, WHATSAPP
```

### 3.2 Identity
```sql
profiles        (id uuid pk → auth.users, email text, phone text null,  -- phone unverified until OTP is added
                 phone_verified_at null, display_name, locale text default 'ar',
                 data_saver bool default true, created_at)
user_roles      (user_id, role app_role, granted_by, granted_at, pk(user_id, role))
devices         (id, user_id, app text check in ('buyer','partner','admin'), platform, fcm_token, last_seen_at)
idempotency_keys(user_id, key uuid, op text, response jsonb, created_at, pk(user_id, key))
audit_log       (id, actor_id, action, entity, entity_id, data jsonb, created_at)
-- custom_access_token_hook(event) adds "app_roles": [...] to the JWT; RLS still checks user_roles for revocation
```

### 3.3 Catalogue and garage
```sql
vehicle_makes    (id, slug unique, name_ar, name_en)
vehicle_models   (id, make_id, slug, name_ar, name_en)
vehicle_variants (id, model_id, year_from int, year_to int, engine_ar, engine_en, engine_code, fuel)
job_types        (id, code unique, name_ar, name_en)                         -- LIGHTING, AC, ELECTRICAL, ...
part_categories  (id, parent_id, slug, name_ar, name_en, job_type_id null, std_job_minutes int null, sort, icon)
parts            (id, category_id, name_ar, name_en, desc_ar, desc_en, oem_numbers text[], installable bool,
                  std_job_minutes int null)                     -- overrides category duration
part_fitments    (part_id, variant_id, note_ar, note_en, pk(part_id, variant_id))
search_synonyms  (id, terms text[] not null, updated_by, updated_at)   -- one row = one synonym group
garage_vehicles  (id, user_id, variant_id, nickname, vin, plate, is_default bool)
```

### 3.4 Location and shops
```sql
markets   (id, name_ar, name_en, city_ar, city_en, tz text default 'Africa/Khartoum')
streets   (id, market_id, name_ar, name_en, path geography(LineString,4326), origin geography(Point,4326))
zones     (id, street_id, seq int, name_ar, name_en, from_m int, to_m int, unique(street_id, seq))  -- metres along street
shops     (id, zone_id, name_ar, name_en, plot_no text, side text check in ('A','B'), landmark_ar, landmark_en,
           location geography(Point,4326), pos_m int,     -- position along street, for ordering pickup stops
           storefront_key, phone, whatsapp, opening_hours jsonb, status partner_status, verified bool,
           rating_avg numeric(3,2), rating_count int)
shop_members      (shop_id, user_id, role text check in ('OWNER','STAFF'), pk(shop_id, user_id))
shop_specialities (shop_id, category_id null, make_id null)
addresses (id, user_id, label, description_ar, location geography(Point,4326))
```

### 3.5 Inventory and requests
```sql
listings (id, shop_id, part_id, condition listing_condition, price_sdg bigint null, price_on_request bool,
          stock_qty int check >= 0, reserved_qty int default 0, warranty_days int default 0, note_ar,
          is_active bool, version int,                        -- optimistic concurrency for quick edits
          check (price_on_request or price_sdg > 0))
listing_images        (id, listing_id, base_key text, sort)   -- {base}/thumb.webp, medium.webp, large.webp, orig.jpg
listing_price_history (id, listing_id, old_sdg, new_sdg, changed_by, changed_at)
listing_search_docs   (listing_id pk, doc text, tsv tsvector, variant_ids int[], has_fitment bool,
                       category_path uuid[], shop_id, price_sdg, condition, is_active)
                       -- maintained by triggers on listings/parts/categories/shops/fitments
                       -- GIN(tsv), GIN(doc gin_trgm_ops), GIN(variant_ids)
import_jobs (id, shop_id, file_key, status, total int, ok int, errors jsonb, created_by)

part_requests (id, buyer_id, garage_vehicle_id, note, image_keys text[], category_id null,
               status text check in ('OPEN','CLOSED','EXPIRED'), expires_at)
part_offers   (id, request_id, shop_id, part_id null, title_ar, condition, price_sdg, warranty_days,
               image_key, status text check in ('OFFERED','IN_CART','ORDERED','WITHDRAWN','EXPIRED'), valid_until)
```

### 3.6 Cart, orders, returns, chat
```sql
cart_items (id, user_id, listing_id null, offer_id null, qty int, seen_price_sdg bigint,
            check (num_nonnulls(listing_id, offer_id) = 1))
orders     (id, ref text unique,               -- 8 digits with a Luhn check digit, typed into the Bankak note
            buyer_id, payment_method, items_sdg, delivery_sdg, booking_fee_sdg, labour_sdg, travel_sdg,
            total_sdg, pay_by timestamptz, idem_key uuid, created_at)
sub_orders (id, order_id, shop_id, status suborder_status, fulfilment fulfilment_type, address_id null,
            items_sdg, delivery_fee_sdg, commission_bp int, commission_sdg,     -- snapshot at checkout
            shop_ack_at, ready_at, handed_over_at, completed_at, status_changed_at)
order_items(id, sub_order_id, listing_id, offer_id, part_id, title_ar, title_en, condition, warranty_days,
            unit_price_sdg, qty, line_sdg)                  -- immutable after checkout = price lock
suborder_events (id, sub_order_id, from_status, to_status, actor_id, reason, at)
returns    (id, sub_order_id, order_item_id, reason, status text, refund_sdg, decided_by, decided_at)
conversations (id, buyer_id, shop_id, sub_order_id null, last_message_at, unique(buyer_id, shop_id, sub_order_id))
messages   (id, conversation_id, sender_id, body text, voice_key, voice_secs int, created_at, read_at)
```

### 3.7 Payments, ledger, payouts
```sql
payments (id, order_id, booking_id null, purpose payment_purpose, method payment_method, status payment_status,
          amount_sdg, bankak_txn_no text, receipt_key text, submitted_at, reviewed_by, reviewed_at,
          reject_reason, collected_by, collected_at)
          -- unique (bankak_txn_no) where status in ('RECEIPT_SUBMITTED','CONFIRMED')  → no reused receipts
payment_events (id, payment_id, from_status, to_status, actor_id, note, at)

ledger_accounts (id, code text unique, kind text check in ('ASSET','LIABILITY','REVENUE','CONTRA'),
                 shop_id null, technician_id null)
   -- PLATFORM_BANKAK, BUYER_FUNDS_HELD, REVENUE_COMMISSION, REVENUE_BOOKING_FEE, REFUNDS_PAYABLE,
   -- SHOP:<id>, TECH:<id>   (party balances: credit = platform owes them, debit = they owe platform)
ledger_journals (id, kind text, order_id, sub_order_id, booking_id, payment_id, payout_id, memo, created_by, created_at)
   -- kinds: SALE, COMMISSION, BOOKING_FEE, DEPOSIT, LABOUR, TRAVEL_FEE, CASH_COLLECTED, CASH_HANDOVER,
   --        REFUND, PAYOUT, ADJUSTMENT
ledger_entries  (id, journal_id, account_id, amount_sdg bigint)   -- +debit / −credit
   -- deferred constraint trigger: sum(amount_sdg) per journal = 0; entries are append-only
payouts (id, shop_id null, technician_id null, amount_sdg, period_from, period_to,
         status text check in ('DRAFT','APPROVED','PAID'), bankak_txn_no, paid_at, paid_by)
```
**Money flows (worked example in DECISIONS D-013):**
- Bankak payment confirmed → Dr `PLATFORM_BANKAK`, Cr `BUYER_FUNDS_HELD`.
- Sub-order completed → `BUYER_FUNDS_HELD` moves to `SHOP:x` (sale), and `SHOP:x` → `REVENUE_COMMISSION`.
- Booking completed → `BUYER_FUNDS_HELD` moves to `TECH:y` (labour + travel), and the booking fee goes to `REVENUE_BOOKING_FEE`.
- **Cash:** cash in a party's hand is debited to that party's account.
  - Technician collects cash → `TECH:y` is debited.
  - Technician hands part money to the shop → `SHOP:x` is debited and `TECH:y` credited.
  - Completion credits them as usual, so what's left is exactly the commission or booking fee they owe, or what the platform owes them. The next payout nets it.

### 3.8 Technicians and bookings
```sql
technicians (id, user_id unique, employer_shop_id null, status partner_status, work_mode work_mode,
             home_bay_shop_id null, home_point geography(Point,4326), radius_km int,
             rating_avg, rating_count, completed_jobs int, bio_ar, avatar_key)
technician_job_types (technician_id, job_type_id, labour_sdg bigint, pk(technician_id, job_type_id))
technician_makes     (technician_id, make_id, pk(...))          -- no rows = all makes
availability_rules   (id, technician_id, weekday smallint 0–6, start_local time, end_local time,
                      modes work_mode default 'BOTH')
time_off             (id, technician_id, period tstzrange, reason)

bookings (id, ref, buyer_id, order_id null, technician_id null, assignment_mode text check in ('CHOSEN','ANY'),
          location_type booking_location, bay_shop_id null, address_id null, point geography(Point,4326),
          location_note, start_at, end_at, block_from, block_to,     -- block_* = start/end ± travel buffer
          status booking_status, hold_expires_at, duration_min int,
          labour_sdg, travel_fee_sdg, booking_fee_sdg, deposit_sdg, payment_method,
          job_code text,                 -- 4 digits; readable only by buyer (RLS); verified by RPC
          checked_in_at, en_route_at, completed_at, cancel_reason, cancelled_by)

-- THE double-booking guard (raw SQL migration):
alter table bookings add constraint bookings_no_overlap
  exclude using gist (technician_id with =, tstzrange(block_from, block_to, '[)') with &&)
  where (status in ('HELD','AWAITING_PAYMENT','PENDING_TECH_ACCEPT','ACCEPTED','EN_ROUTE','IN_PROGRESS'));

booking_items  (id, booking_id, order_item_id null, external_desc text null, part_id null, job_type_id, minutes)
booking_offers (id, booking_id, technician_id, status offer_status, offered_at, expires_at, responded_at)
booking_photos (id, booking_id, kind text check in ('BEFORE','AFTER'), image_key, taken_at)
booking_events (id, booking_id, from_status, to_status, actor_id, reason, at)
tech_locations (booking_id pk, technician_id, point geography(Point,4326), updated_at)
               -- RLS: buyer can read only while booking.status = 'EN_ROUTE'; row deleted on check-in
```

### 3.9 Notifications, reviews, disputes, settings
```sql
notification_templates (code, channel notify_channel, locale, title, body, pk(code, channel, locale))
notifications          (id, user_id, code, payload jsonb, created_at, read_at)     -- in-app inbox
notification_deliveries(id, notification_id, channel, status text, attempts int, last_error, provider_ref, sent_at)
reviews  (id, author_id, sub_order_id null, booking_id null, shop_id null, technician_id null,
          rating smallint check 1–5, comment, created_at,
          unique(author_id, sub_order_id, shop_id), unique(author_id, booking_id, technician_id))
disputes (id, opened_by, sub_order_id null, booking_id null, category, description, status text,
          assigned_to, resolution, resolved_at)
dispute_messages (id, dispute_id, sender_id, body, attachment_key, created_at)
app_settings (key text pk, value jsonb, description, updated_by, updated_at)
```

### 3.10 State machines

Each machine has a transition table (`from`, `to`, allowed actor roles, extra guard) that a trigger enforces on every status change, and a single `transition_*()` function that writes the event row.

- **SubOrder:** `PENDING_PAYMENT → PAYMENT_REVIEW → CONFIRMED → READY → {PICKED_UP | OUT_FOR_DELIVERY → DELIVERED | HANDED_TO_TECHNICIAN} → COMPLETED`.
  - Side exits: `→ CANCELLED` (buyer before CONFIRMED; system when `pay_by` passes; admin), `CONFIRMED → REJECTED_BY_SHOP` (triggers a refund), `{PICKED_UP, DELIVERED, COMPLETED} → RETURN_REQUESTED → RETURNED` (within `return_window_days`).
  - Cash orders: `PENDING_PAYMENT → CONFIRMED` directly.
- **Payment:** `AWAITING_TRANSFER → RECEIPT_SUBMITTED → CONFIRMED | REJECTED` (after `REJECTED` the buyer may resubmit → `RECEIPT_SUBMITTED`); `AWAITING_TRANSFER → EXPIRED` when `pay_by` passes; cash `DUE → COLLECTED`.
- **Booking:** `HELD → AWAITING_PAYMENT → PENDING_TECH_ACCEPT → ACCEPTED → EN_ROUTE (mobile only) → IN_PROGRESS → COMPLETED`.
  - Cash bay bookings skip `AWAITING_PAYMENT`.
  - `HELD → EXPIRED` when the hold lapses.
  - Decline or timeout → the next match is offered **for the same time window** while status stays `PENDING_TECH_ACCEPT` (history in `booking_offers`). If nobody is free → `NEEDS_RESCHEDULE` (buyer picks a new slot or cancels for a full refund).
  - Other exits: `CANCELLED_BY_BUYER`, `CANCELLED_BY_TECH` (→ reassign, or `NEEDS_RESCHEDULE`), `CANCELLED_BY_ADMIN`, and `IN_PROGRESS → PART_DOES_NOT_FIT` (opens a return on the linked sub-order; buyer pays the travel fee only).
  - Guard: a booking with linked order items cannot leave `ACCEPTED` until its sub-order is `HANDED_TO_TECHNICIAN`.

### 3.11 Settings (seeded defaults; all SDG values are placeholders marked `TODO: confirm`)
| key | default | note |
|---|---|---|
| `commission_percent` | `5` | stored as a number; maths in basis points |
| `booking_fee_sdg` | `2000` | |
| `mobile_deposit_sdg` | `5000` | `0` disables the deposit |
| `slot_hold_minutes` | `10` | |
| `tech_accept_timeout_minutes` | `20` | |
| `cancel_cutoff_hours` | `6` | |
| `part_ready_buffer_minutes` | `120` | |
| `travel_fee_bands` | `[{"max_km":3,"sdg":3000},{"max_km":8,"sdg":6000},{"max_km":15,"sdg":10000}]` | beyond the last band is not served |
| `delivery_fee_bands` | same shape | |
| `bankak_account_name` / `bankak_account_number` | placeholders | |
| `payout_schedule` | `{"frequency":"weekly","weekday":0}` | Sunday |
| **added:** `payment_window_minutes` | `120` | unpaid Bankak orders auto-cancel and release stock and holds |
| **added:** `return_window_days` | `3` | |
| **added:** `travel_buffer_minutes` | `30` | between mobile jobs |
| **added:** `booking_lookahead_days` | `7` | the "N days" in the technician list |
| **added:** `auto_complete_days` | `3` | delivered/picked-up → completed if the buyer is silent |
| **added:** `labour_price_bounds` | `{}` | optional per-job-type min/max |

---

## 4. API surface

Full signatures will be in `docs/API.md`, generated as each milestone lands. **R** = read via PostgREST + RLS, **W** = direct write under RLS, **RPC** = Postgres function, **EF** = Edge Function. Every RPC/EF that mutates takes an idempotency key.

| Module | Reads (R) | Writes |
|---|---|---|
| **identity** | `profiles` (self), `user_roles` (self) | Supabase Auth `signUp`/`signInWithPassword`/`resetPasswordForEmail`; RPC `update_profile`, `register_device`, `apply_as_shop`, `apply_as_technician`; admin RPC `admin_grant_role`, `admin_revoke_role` |
| **catalogue** | makes/models/variants/categories/parts/fitments (public); RPC `catalogue_snapshot(since)` for the offline cache | admin RPC `admin_upsert_{make,model,variant,category,part}`, `admin_set_fitments`, `admin_upsert_synonyms` |
| **garage / addresses** | own rows | W own rows |
| **search** | RPC `search_listings(q, variant_id, category_id, conditions[], shop_id, price_min, price_max, sort, cursor)` → rows with `fit: FITS \| CHECK_FITMENT`; RPC `compare_part(part_id, variant_id)` | — |
| **shops / street** | `shops` (approved), RPC `street_strip(street_id)` (zones + shop dots, cacheable), RPC `pickup_route(order_id)` | RPC `shop_update_profile`, `shop_invite_staff`, `shop_remove_staff`; admin RPC `admin_set_shop_status`, `admin_verify_shop` |
| **inventory** | `listings` (public active; shop sees own) | RPC `shop_upsert_listing`, `shop_bulk_update(items[{listing_id, price_sdg?, stock_qty?, version}])`; EF `inventory-import` (xlsx → validated rows → bulk upsert, report); template in storage |
| **requests** | own requests; shops see open requests in their specialities | RPC `create_part_request`, `close_part_request`, `shop_make_offer`, `shop_withdraw_offer`, `offer_to_cart` |
| **cart / orders** | own orders, sub-orders, items; shop sees its sub-orders | RPC `cart_upsert`, `cart_remove`, `cart_validate` (returns price/stock changes), **`checkout(payload)`**, `cancel_order`, `shop_ack_suborder`, `shop_reject_suborder`, `shop_mark_ready`, `shop_hand_over(sub_order_id, to_status)`, `mark_delivered`, `confirm_received`, `request_return`; admin `admin_decide_return` |
| **payments** | own payments; admin queue view `v_payment_review_queue` | RPC `submit_bankak_receipt(payment_id, txn_no, receipt_key)`, `record_cash_collected(payment_id)`, `confirm_cash_handover(booking_id)` (tech → shop part money, both sides); admin `admin_confirm_payment`, `admin_reject_payment(reason)` |
| **ledger / payouts** | RPC `statement(party, from, to)` (shop/tech own; admin any) | admin RPC `admin_generate_payouts(period)`, `admin_mark_payout_paid(payout_id, txn_no)`, `admin_ledger_adjustment` |
| **bookings** | own bookings (buyer / assigned tech); `tech_locations` per RLS | EF `booking-technicians` (filter + score + labour price); EF `booking-slots` (slot engine); EF `booking-hold` (re-check + insert `HELD`); RPC `release_hold`, `buyer_cancel_booking`, `buyer_reschedule`; tech RPC `tech_respond_offer(accept)`, `tech_en_route`, `tech_update_location`, `tech_check_in`, `tech_add_photo`, `tech_complete(job_code)`, `tech_part_not_fit`, `tech_cancel`; W own `availability_rules`, `time_off`; RPC `tech_quick_block(minutes)`, `tech_update_profile`, `tech_set_job_types` |
| **notifications** | own `notifications` | internal `enqueue_notification(user, code, payload)`; EF `notify-dispatch` (pgmq consumer: picks channels, renders template, retries with backoff); cron reminders |
| **reviews / disputes** | public reviews; own disputes | RPC `create_review`, `open_dispute`, `dispute_reply`; admin `admin_update_dispute` |
| **chat** | own conversations/messages (Realtime) | W `messages` (RLS: participant only); RPC `start_conversation(shop_id, sub_order_id?)` |
| **settings** | RPC `public_settings()` (safe subset, incl. Bankak account) | admin RPC `admin_update_setting(key, value)` (schema-validated) |
| **admin reports** | views: `v_daily_gmv`, `v_commission_by_shop`, `v_bookings_funnel`, `v_cash_outstanding` | — |

**Cron jobs (pg_cron):**
- Expire holds (1 min).
- Expire unpaid orders (5 min).
- Tech-offer timeouts → reassign (1 min).
- Reminders: 24 h and 1 h before (5 min).
- Auto-complete (hourly).
- Dispatch the notification queue (30 s, via `pg_net` → `notify-dispatch`).

**Storage buckets:**
- **Public:** `media-public` (listing and storefront images), `templates`.
- **Private:** `receipts`, `booking-photos`, `request-photos`, `voice-notes`, `imports`.
- Every bucket has a size limit and a MIME allow-list.

---

## 5. Slot engine (M3) — summary

A pure function in `supabase/functions/_shared/slots/`:
```
slots(tech, rules, timeOff, existingBlocks, request{duration, location, earliest, horizonDays}, settings) → Slot[]
```
1. Expand the weekly rules (local time, Africa/Khartoum) into UTC intervals over the horizon.
2. Subtract time-off and the existing blocks. For mobile jobs, blocks are padded by `travel_buffer_minutes` on both sides.
3. Clip to `earliest = max(now, part_ready_estimate) + part_ready_buffer_minutes`, rounded up to 15 minutes.
4. Cut into candidate starts on a 30-minute grid where `[start, start+duration)` fits.
5. Duration = the sum of the standard job minutes of the booking items, each resolved part → category fallback.

"Any available" ranks candidates with:
```
score = 0.5·rating_norm + 0.3·log(completed_jobs+1)_norm + 0.2·(1 − distance/radius)
```
The best technician that has the chosen slot wins.

The **database constraint is the final arbiter**: `booking-hold` re-runs the engine for that technician and then inserts. An exclusion violation returns `409 SLOT_TAKEN`.

---

## 6. Things in the brief that I think are wrong or risky

1. **"Price lock once paid" is too late.** The buyer transfers the amount shown at checkout, so the price must lock **at checkout**. The fix: a payment window (`payment_window_minutes`). Unpaid orders auto-cancel, release reserved stock and drop holds.
2. **The 10-minute slot hold can't cover Bankak confirmation.** An admin may confirm hours later. The fix: the hold covers checkout until the receipt is submitted (or cash is chosen). Then the booking moves to `AWAITING_PAYMENT` and **keeps blocking the slot**. The technician is offered the job after the admin confirms (or straight away for cash). If the admin rejects the receipt, the buyer can resubmit until `pay_by`; after that the booking is cancelled.
3. **"Part ready time" isn't known at checkout.** For parts in the same order: `earliest = now + part_ready_buffer_minutes` (plus the expected confirmation delay outside admin hours). For parts bought elsewhere: `now + part_ready_buffer_minutes`. Once the shop marks the part ready, nothing reschedules automatically.
4. **TECH_DECLINED/TIMEOUT as booking statuses** make reassignment messy. I model them as **offer** statuses, and the booking stays `PENDING_TECH_ACCEPT` until someone accepts or nobody can (`NEEDS_RESCHEDULE`).
5. **Admin confirmation is a bottleneck** and a single point of failure for every Bankak order. Mitigations:
   - A queue with age alerts.
   - Duplicate transaction numbers blocked by a DB constraint.
   - Amount and reference shown side by side.
   - "Payment being checked" messaging that states admin working hours.
   - Automatic statement matching stays out of scope but is designed for.
6. **Refunds are manual Bankak transfers.** Every shop rejection after payment costs admin time and buyer trust. Stock accuracy matters, hence the open question below.
7. **Commission netting can go negative.** A cash-only shop may never have a payout to net against. The platform needs a "balance owed" screen and a policy (e.g. suspend listings when owed > X). Logged in DECISIONS as a default.
8. **Order reference typed into Bankak:** letters are error-prone for Arabic keyboards, so the ref is **8 digits with a Luhn check digit**.
9. **Regulatory (non-technical):** the platform holds buyer money before paying shops (escrow-like). Worth checking with a Sudanese lawyer or the bank before launch.
10. **Reachability (to verify in M0/M7):** confirm that Supabase (region: Frankfurt suggested), FCM and the admin host are reachable from Sudanese mobile networks (Zain, MTN, Sudani) without VPN. Some US SaaS has geo-restricted Sudan in the past; I haven't verified the current state.
11. **Supabase free plan:** projects pause after inactivity, there are 2 active projects, a 500 MB DB and 1 GB storage, and phone auth needs either an SMS provider or the Send-SMS hook. Fine for development; launch needs the Pro plan.
12. **No local backend without Docker:** development and tests hit hosted projects, so tests need internet and are slower. CI runs a local Supabase. If this becomes painful, installing Docker Desktop later is a drop-in change (`supabase start`).
13. **Fitment data quality** drives the "only parts that fit" promise. With sparse fitment most results will be `CHECK_FITMENT`. Admin tooling for fitment is therefore an M6 priority, and photo requests are the fallback.

---

## 7. Open questions — answered 2026-10-10

The owner approved the defaults for Q1, Q2, Q3 and Q5. Q4 was replaced by "everyone logs in with email; phone OTP later" (D-030).

<details><summary>Original questions</summary>


1. **Do shops confirm stock before the buyer pays?**
   - Default: **no.** Stock is reserved at checkout and the buyer pays right away. The shop must acknowledge within 30 minutes after payment confirmation, otherwise the admin is alerted.
   - Alternative: the buyer waits for a shop "in stock" tap before payment instructions appear. Fewer refunds, slower checkout.
2. **When is the technician offered the job for a Bankak booking?**
   - Default: **after the admin confirms payment.**
   - Alternative: as soon as the receipt is submitted, which is faster but technicians may lose jobs to rejected payments.
3. **Supabase region and accounts.** Default: **Frankfurt (eu-central-1)**. You need to create the Supabase account and two projects (`alghali-dev`, `alghali-test`), then put their keys into `.env` yourself. I'll give exact steps at the start of M0. Is there a region you prefer?
4. **Admin login:** default is **email + password** for staff, with phone OTP for everyone else. OK?
5. **GitHub:** do you want a GitHub repo for CI now? Default: I set up git and the CI workflow locally, and you add the remote when you're ready.

</details>
