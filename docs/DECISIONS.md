# Decisions log

Format: **D-nnn · date · status** — decision. *Why.* `Owner` = decided by the product owner; `Default` = my sensible default (change any of these by telling me); `Pending Qn` = default in use until the owner answers question n in PLAN §7.

---

### Stack and environment
- **D-001 · 2026-10-10 · Owner** — **Hosted Supabase replaces NestJS + Prisma + Redis/BullMQ + Meilisearch + MinIO + docker-compose.** Business rules live in Postgres RPCs/triggers; Edge Functions (TypeScript) handle the slot engine, xlsx import and messaging. *There's no Docker on the dev machine and the owner chose hosted Supabase.*
- **D-002 · 2026-10-10 · Owner** — **Two Flutter apps** (`apps/buyer`, `apps/partner`) plus **Next.js admin** (`apps/admin`), sharing `packages/core`.
- **D-003 · 2026-10-10 · Owner** — Flutter switched globally from the `master` pre-release to the **stable** channel.
- **D-004 · 2026-10-10 · Default** — **Environments:** hosted `alghali-dev` (apps) and `alghali-test` (automated tests, wiped per run); CI runs `supabase start` on GitHub runners. *Without Docker locally this is the only way to get an isolated test DB.*
- **D-005 · 2026-10-10 · Default** — **API contract:** `supabase gen types` → `packages/db-types` (TS). Dart models are hand-declared with `freezed` + `json_serializable` in `packages/core`, with typed RPC wrappers. **Dio dropped**, since `supabase_flutter` covers HTTP. *There's no REST controller layer to generate OpenAPI from.*
- **D-006 · 2026-10-10 · Default** — **Search** uses Postgres FTS (`simple` config) + `pg_trgm` over a denormalised `listing_search_docs` table maintained by triggers. Normaliser `ar_normalize()`: أ/إ/آ/ٱ→ا, ة→ه, ى→ي, strips tashkeel (U+064B–U+0652, U+0670) and tatweel (U+0640), lower-cases Latin, collapses whitespace. Synonym groups are expanded at query time. *Meilisearch can be put behind the same `search_listings` RPC later if needed.*
- **D-007 · 2026-10-10 · Default** — **Jobs:** pgmq queue + pg_cron (+ `pg_net` to invoke Edge Functions) replace BullMQ.
- **D-008 · 2026-10-10 · Default** — **Images:** the client produces `thumb` 160px, `medium` 480px, `large` 1080px (WebP) and an `orig` JPEG capped at 2048px, then uploads all four under one base key. Buckets enforce MIME types and size. *Server-side transforms need a paid Supabase plan; doing it on the client also saves upload data.*

### Money and payments
- **D-010 · 2026-10-10 · Owner** — **Labour price** is set by each technician per job type (`technician_job_types.labour_sdg`), with optional admin min/max in `labour_price_bounds`. "Any available technician" shows a price range, and the assigned technician's price is locked when the booking is created.
- **D-011 · 2026-10-10 · Owner** — **Cash to technician:** the technician collects all cash and hands the part money to the shop at pickup. Both confirm in the app (`confirm_cash_handover`). The shop's commission is netted from its next payout, and the booking fee from the technician's.
- **D-012 · 2026-10-10 · Default** — **Who earns what:**
  - The booking fee goes to the platform.
  - Labour and travel fee go 100% to the technician.
  - The delivery fee goes to the shop, which does its own delivery.
  - Commission is charged on part sales only, not on delivery, labour or travel.
- **D-013 · 2026-10-10 · Default** — **Ledger model and worked examples** (acceptance journey; numbers are illustrative): bulbs 12,000, labour 6,000, travel 3,000 (≤3 km band), booking fee 2,000, commission 5% = 600.

  *Bankak (everything paid by transfer, 23,000):*
  | Journal | Dr | Cr | Amount |
  |---|---|---|---|
  | DEPOSIT/payment confirmed | PLATFORM_BANKAK | BUYER_FUNDS_HELD | 23,000 |
  | SALE (sub-order completed) | BUYER_FUNDS_HELD | SHOP:x | 12,000 |
  | COMMISSION | SHOP:x | REVENUE_COMMISSION | 600 |
  | LABOUR + TRAVEL_FEE (booking completed) | BUYER_FUNDS_HELD | TECH:y | 9,000 |
  | BOOKING_FEE | BUYER_FUNDS_HELD | REVENUE_BOOKING_FEE | 2,000 |

  Result: bank 23,000 = shop payable 11,400 + tech payable 9,000 + revenue 2,600 ✔

  *Cash to technician (Bankak deposit 5,000; cash 18,000):*
  | Journal | Dr | Cr | Amount |
  |---|---|---|---|
  | DEPOSIT confirmed | PLATFORM_BANKAK | BUYER_FUNDS_HELD | 5,000 |
  | CASH_COLLECTED by tech | TECH:y | BUYER_FUNDS_HELD | 18,000 |
  | CASH_HANDOVER tech → shop | SHOP:x | TECH:y | 12,000 |
  | SALE | BUYER_FUNDS_HELD | SHOP:x | 12,000 |
  | COMMISSION | SHOP:x | REVENUE_COMMISSION | 600 |
  | LABOUR + TRAVEL_FEE | BUYER_FUNDS_HELD | TECH:y | 9,000 |
  | BOOKING_FEE | BUYER_FUNDS_HELD | REVENUE_BOOKING_FEE | 2,000 |

  Result:
  - The shop owes 600, netted from its next payout.
  - The platform owes the technician 3,000.
  - Revenue is 2,600.
  - The bank holds 5,000 = 3,000 + 2,600 − 600 ✔
  - `BUYER_FUNDS_HELD` ends at 0 ✔
- **D-014 · 2026-10-10 · Default** — **Rounding:** `commission_sdg = round_half_up(items_sdg × bp / 10000)`, calculated per sub-order. All amounts are whole SDG.
- **D-015 · 2026-10-10 · Default** — **Price lock at checkout**, not "once paid". `order_items` are immutable after checkout, stock is reserved (`reserved_qty`), and unpaid Bankak orders expire after `payment_window_minutes` (120), releasing stock and holds. `cart_validate` / `checkout` return any price or stock changes for the buyer to accept.
- **D-016 · 2026-10-10 · Default** — **Order reference** is 8 digits including a Luhn check digit (e.g. `4815 1627`). *Easier and less error-prone to type into a Bankak note than letters.*
- **D-017 · 2026-10-10 · Default** — **Duplicate receipts:** a partial unique index on `payments.bankak_txn_no` for submitted/confirmed payments blocks reusing a transaction number. Only an admin can move a payment to `CONFIRMED`; a screenshot alone never does.
- **D-018 · 2026-10-10 · Default** — **Negative balances** (e.g. a cash-only shop) carry forward and are netted from future payouts. The admin sees a "balance owed" report and is alerted when an amount is unpaid for 2 payout cycles. There's no automatic suspension in the MVP.
- **D-019 · 2026-10-10 · Default** — **Deposit and cancellation:**
  - Cancelling before `cancel_cutoff_hours` gets a full refund.
  - After the cutoff, the deposit is kept: the booking-fee part goes to the platform and the remainder to the technician as travel compensation.
  - If the technician cancels, the job is reassigned or the buyer gets a full refund.
  - "Part does not fit" at check-in: the buyer pays the travel fee only (taken from the deposit, with any rest refunded) and a return opens on the linked sub-order.

### Orders and bookings
- **D-020 · 2026-10-10 · Default** — **Shop acknowledgement** is a timestamp (`shop_ack_at`), not a state, so the brief's SubOrder enum is unchanged. The admin is alerted if a confirmed sub-order isn't acknowledged within 30 minutes during opening hours.
- **D-021 · 2026-10-10 · Default** — **Completion:** a `TO_TECHNICIAN` sub-order completes when its booking completes. `PICKED_UP`/`DELIVERED` sub-orders auto-complete after `auto_complete_days` unless a return is requested.
- **D-022 · 2026-10-10 · Default** — **Slot holds** are `HELD` booking rows with `hold_expires_at`, covered by the `EXCLUDE` constraint. The cron sweeper expires them, and `booking-hold` also expires stale holds for the technician before inserting.
- **D-023 · 2026-10-10 · Owner (Q2 default)** — **The hold becomes `AWAITING_PAYMENT`** on receipt submission and keeps blocking the slot. The technician is offered the job **after the admin confirms payment** (immediately for cash).
- **D-024 · 2026-10-10 · Default** — **Decline/timeout are offer statuses** (`booking_offers`). The booking stays `PENDING_TECH_ACCEPT` while the next match for the **same time window** is offered. If nobody is free it becomes `NEEDS_RESCHEDULE`. The buyer is notified at each step.
- **D-025 · 2026-10-10 · Default** — **Travel buffer:** the exclusion range is `block_from..block_to` = the job ± `travel_buffer_minutes` (30) for mobile jobs and the bare job for bay jobs. That way the DB constraint itself enforces travel time.
- **D-026 · 2026-10-10 · Default** — **Distance** is straight-line (`ST_Distance` on geography) from the street origin for fee bands and from the technician's home point for radius. Road distance can come later.
- **D-027 · 2026-10-10 · Default** — **Earliest slot** = `now + part_ready_buffer_minutes`, rounded up to 15 minutes, and shifted to the next admin working period for unconfirmed Bankak orders. The grid is 30 minutes; duration is the sum of part → category standard minutes.
- **D-028 · 2026-10-10 · Default** — **Job code:** 4 random digits, visible only to the buyer (RLS). The technician submits it via `tech_complete`. Five wrong attempts lock completion and alert the admin.
- **D-029 · 2026-10-10 · Default** — **Technician location** is stored in `tech_locations` only while `EN_ROUTE`, is readable only by that booking's buyer, and is deleted at check-in.

### Apps and content
- **D-030 · 2026-10-10 · Owner** — **Everyone logs in with email + password** (Supabase Auth): buyers, shop owners/staff, technicians and admins. Admin access is the `ADMIN` role, not a separate login. **Phone OTP is deferred**; `profiles.phone` is collected unverified so shops and technicians can call buyers. When OTP is added, it'll be a second sign-in method on the same accounts (`phone_verified_at`), not a migration.
- **D-031 · 2026-10-10 · Default** — **Email delivery:**
  - In dev, "Confirm email" is **off**. Supabase's built-in mailer only delivers to project team members and is heavily rate-limited.
  - Before launch we add a custom SMTP provider for confirmation and password-reset emails. The SMS provider interface stays in the notifications module for alerts.
  - Risk: many target users may not use email regularly. Phone OTP is the fix and should be the first post-MVP item.
- **D-032 · 2026-10-10 · Default** — **Arabic copy** is plain Modern Standard Arabic for the UI. Colloquial and Sudanese part names go into `search_synonyms` (the team will supply them). Zone names are placeholders marked `TODO: confirm local names`.
- **D-033 · 2026-10-10 · Default** — **Chat** uses Supabase Realtime on `messages` rather than polling. Voice notes are AAC/m4a, max 60 seconds, in the private `voice-notes` bucket.
- **D-034 · 2026-10-10 · Default** — **Settings SDG defaults** are placeholders (`TODO: confirm` with real market prices before launch). The added keys are listed in PLAN §3.11.
- **D-035 · 2026-10-10 · Owner (Q3 default)** — **Supabase region:** Frankfurt (`eu-central-1`).
- **D-036 · 2026-10-10 · Owner (Q1 default)** — **Stock is reserved at checkout and the buyer pays immediately.** The shop doesn't confirm stock before payment; it acknowledges afterwards (D-020).
- **D-037 · 2026-10-10 · Owner (Q5 default)** — **Git is local for now.** The CI workflow is committed and runs once the owner adds a GitHub remote.

### M0 scaffold (2026-10-10)
- **D-038 · Default** — **pnpm 10.34 installed via `npm i -g pnpm`**: `corepack enable` needs admin rights on this machine. The version is pinned in `packageManager`.
- **D-039 · Default** — **Admin i18n uses Next 16's built-in pattern** (`app/[lang]`, JSON dictionaries, `next/root-params`, `proxy.ts`) instead of next-intl. It's one less dependency on a brand-new Next major, and a test enforces identical ar/en keys.
- **D-040 · Default** — **Flutter code imports `package:material_ui`**, not `package:flutter/material.dart`. Material was decoupled from the SDK, and go_router 18 already uses `material_ui`; mixing the two would give two `ThemeData`/`MaterialLocalizations` types. Localization delegates come from `GlobalMaterialLocalizations.delegates` (material_ui).
- **D-041 · Default** — **No bundled fonts in the apps:** they use the Android system Arabic font to keep APKs small. The admin uses IBM Plex Sans Arabic via `next/font` (self-hosted at build time).
- **D-042 · Default** — **Generated Dart code is committed** (gen-l10n output, Drift `.g.dart`). CI regenerates it and fails on any diff. Hand-written Dart uses page width 100; `.g.dart` keeps its generator's formatting (`infra/scripts/dart-format.mjs` skips it).
- **D-043 · Default** — **Sentry is deferred:** wired in M4 (Flutter) and M6 (admin) rather than M0. The `SENTRY_DSN` / `NEXT_PUBLIC_SENTRY_DSN` placeholders already flow through `pnpm env:sync`, and Sentry stays disabled while they're empty.
- **D-044 · Default** — **Single source for config:** the root `.env` is the only file you edit. `pnpm env:sync` writes `apps/admin/.env.local` and `apps/*/env/dev.json` with client-safe values only (URL, publishable key, public DSN); a test enforces that secret keys and DB URLs never leave it.
- **D-045 · Default** — **The supabase-js publishable key** (`sb_publishable_…`) is used in clients, and the secret key only in scripts/tests. The legacy anon/service_role keys work too if that's what the dashboard shows.
- **D-046 · Default** — **Auth config (`supabase/config.toml`, used by CI's local stack):** email sign-up on, confirmations off, minimum password 8 characters with letters + digits. The hosted projects must be set the same way in the dashboard (README).
