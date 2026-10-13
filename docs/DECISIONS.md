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

### UI pass on sample data (2026-10-11)
- **D-047 · Owner** — **The apps bundle IBM Plex Sans Arabic** (Regular, Medium, SemiBold, Bold; about 0.4 MB, SIL OFL) in `packages/core`, the same family the admin loads through `next/font`. **Supersedes D-041.** *Android's system Arabic font differs by phone maker; the owner chose one consistent look over a smaller APK.* The font licence is registered with Flutter's licence page.
- **D-048 · Default** — **Western digits (0–9) in both languages**, including the Arabic UI, for prices, times, order numbers and phone numbers. *Bankak receipts, phone numbers and order references are written with Western digits, so matching them avoids copying mistakes.*
- **D-049 · Owner (placeholder)** — **Placeholder logo:** a "غ" mark (ع + dot) in white on brand colour, drawn in code (`MarkPainter` in `packages/core`, `Mark` SVG in the admin, positions matched to the app icon). The buyer icon is on charcoal and the partner icon on red, so the two apps are easy to tell apart. To change it, see the README's "Logo, icons and splash" section. Replace it when a real logo exists.
- **D-050 · Owner** — **Brand colours: charcoal `#1F2937` is the brand, red `#B91C1C` is only for the main action on a screen.**
  - Focus rings, checkboxes, switches and selected chips are charcoal, so they never read as errors.
  - Status colours (success, warning, info) never use the brand red. A failed or cancelled state uses the separate error red, always with a label or icon.
  - Charts use one validated blue (`#2a78d6` light / `#3987e5` dark), plus orange for a second series. Charcoal failed the colour-blind check.
- **D-051 · Owner** — **UI first, on sample data, before M1.** The owner asked for a professional look across all three apps before backend work. Every main screen of the buyer app, the partner app (shop and technician) and the admin console runs on sample data:
  - Flutter: `packages/core/lib/src/demo`.
  - Admin: `apps/admin/src/lib/demo`.

  The sample data uses the same models and shapes the backend will fill. Screens are marked "Sample data", and demo-only controls are labelled. M4–M6 swap sample data for Supabase without redesigning the screens, so these screens are the reference for those milestones. Sample working hours are Saturday–Thursday 09:00–13:00 and 16:00–21:00, Friday off, on a 30-minute grid.
- **D-052 · Default** — **Guests can browse and search the buyer app.** Sign-in is asked for only at checkout, when booking a fitting on its own, and when sending a part request; the Orders tab asks guests to sign in. After signing in, the buyer continues where they were. *Making people register before they've seen any parts loses them.*
- **D-053 · Default** — **The demo can't move money or contact anyone:**
  - The platform Bankak account shown is `0000000000`, labelled "Sample account — don't transfer".
  - Call and WhatsApp buttons say they're off in the demo.
  - All emails use `example.com`.
  - Admin actions change only the page you're on and send nothing.
- **D-054 · Default** — **Bankak review rules in the admin queue (to build for real in M2/M6):**
  - A wrong amount or a reused transaction number blocks "Confirm payment".
  - A missing order number in the transfer note is only a warning, because the transfer can still be matched by amount and transaction number.
  - The admin must tick "Transfer appears on the Bankak statement" before confirming.
  - The reject dialog pre-selects the reason from the failed check.
- **D-055 · Default** — **The admin demo uses a fixed "now"** (`DEMO_NOW`, Wednesday 14 Oct 2026, 09:30 Khartoum). Dates are formatted on the server and passed to client components. *Next 16's Cache Components refuses `new Date()` in prerendered pages, and server-formatted text avoids server/browser differences.*

### Going to production (owner's answers, 2026-10-13)
The owner asked for a production-ready app for real users, with every feature in the plan (M1–M7).
- **D-056 · Owner** — **Check in after every milestone**, as before. I stop after each of M1–M7 for the owner to try it and say "go".
- **D-057 · Owner** — **Android only at launch.** No iPhone build, Apple account or App Store review. The Flutter code stays cross-platform so iOS can be added later.
- **D-058 · Owner** — **The Android apps are installed from a download link, not Google Play.** What this means:
  - A release signing key is generated once. **The owner keeps a backup of it**: without it, users can't install updates over their existing app.
  - The APKs are served from a public storage bucket, with a small download page (ar/en) that explains Android's "unknown app" prompt.
  - Both apps check a `latest_app_versions` setting on start. They offer an update when a newer build exists and require one when a build is below the minimum.
- **D-059 · Owner** — **Email + password stays the sign-in for everyone at launch** (confirms D-030). Phone OTP remains the first post-launch item.
- **D-060 · Owner** — **The live server stays on Supabase's free plan for now.** Consequences:
  - The free plan allows two active projects, and dev and test use both. At launch (M7) a live project takes one of those places; which one gets paused is decided then.
  - The free plan has no automatic backups. M7 adds a nightly database backup job.
  - Free limits (500 MB database, 1 GB storage) are fine for a first launch. Upgrading to Pro later needs no code change.
- **D-061 · Owner** — **Push notifications are the only alert channel at launch** (Firebase Cloud Messaging; the owner creates a free Firebase project). SMS and WhatsApp stay as logged stubs behind the channel interface, so a provider can be plugged in later. Every alert also lands in the in-app notifications inbox.
- **D-062 · Owner** — **Starter catalogue from me; shops add their own stock.** I prepare common vehicles in Sudan and part categories with Arabic and English names. Shops sign up in the partner app and list stock by hand or by Excel upload. Fitment data is added over time from the admin.
- **D-063 · Owner** — **No domain name at launch.** The admin site and download page use free hosting addresses. The admin host must allow commercial use on its free tier (Vercel's free tier doesn't); the host is chosen in M6.
- **D-064 · Default** — **Password reset without a domain:**
  - Reset emails go through a free SMTP service from a dedicated sender mailbox that the owner creates before launch (for example a new Gmail account with an app password).
  - Admins can also set a temporary password for a user who calls support. This covers users who don't check email.
  - *Without our own domain, reset emails are more likely to land in spam, so the admin path matters.*

### M1 foundation (2026-10-13)
- **D-065 · Default** — **No custom JWT claims hook.** Row level security and every RPC read `user_roles` directly (`has_role()`, `is_admin()`), so revoking a role works at once. Apps call `me()` after sign-in to get roles and shops. *One less hosted setting to keep in sync, and nothing goes stale in a token.*
- **D-066 · Default** — **Search is grouped by part.** Each part has one search document (`part_search_docs`): its names, its category and parent category, keywords, OEM numbers with and without dashes, and the brands shops list it under. Triggers keep it current. `search_parts()` returns one card per part with up to 5 offers, cheapest first, which is what the buyer screens show. Details:
  - Every query word must match, as a prefix, directly or through a synonym group.
  - When nothing matches exactly, it falls back to fuzzy trigram matching for typos.
  - Replaces the per-listing `listing_search_docs` in PLAN §3.5.
- **D-067 · Default** — **Shops type part names; parts they create start unverified.** The quick-listing screen asks for a name, a category and car models, not a catalogue pick. So:
  - `shop_upsert_listing` creates the shop's own part (`created_by_shop_id`, `is_verified = false`), with fitment for every engine of the chosen models. "Not sure" means no fitment ("check fitment").
  - The shop can rename it while it is unverified. Other shops can't use it.
  - Admins merge duplicates into catalogue parts (`admin_merge_parts`), so offers group under one card.
  - `suggest_parts` offers matching catalogue parts while the shop types.
- **D-068 · Default** — **Admins edit the catalogue and street tables directly under RLS** (makes, models, variants, job types, categories, parts, fitment, synonyms, markets, streets, zones). These tables have no state machine. A trigger writes every admin change to `audit_log`. Shops, listings and roles still change only through RPCs.
- **D-069 · Default** — **RPC errors are machine codes.** The message is `UPPER_SNAKE_CASE` (for example `INVALID_PHONE`, `VERSION_CONFLICT`). The SQLSTATE sets the HTTP status: `42501` → 401/403, `P0002` → 404, `PT409` → 409, `22023` → 400. The apps translate the code. The full list is in API.md.
- **D-070 · Default** — **SheetJS 0.20.3 is vendored** in `supabase/functions/_shared/vendor/sheetjs/` (Apache-2.0, unchanged), for reading stock sheets. *The Edge Function bundler can't import from cdn.sheetjs.com, and npm only has the outdated 0.18.5.* The tests and the template script import the same file.
- **D-071 · Default** — **The starter catalogue is a migration; demo data is a dev-only script.**
  - `20261013100600_starter_catalogue.sql` loads into every environment, the live project included: 13 makes, 47 models, 147 engine variants, 12 categories, 9 job types, 76 everyday parts, 37 synonym groups, and the street with 4 placeholder zones.
  - The demo shops, accounts and stock (`supabase/seed/demo.json`) load only through `pnpm db:seed:dev`, which refuses any other target.
- **D-072 · Default** — **Applied migrations are never edited.** From M1 on, `alghali-dev` has the migrations, so every change is a new migration file. The test project is reset at will (`pnpm db:reset:test`).
- **D-073 · Default** — **Hosted project settings live in `infra/hosted/supabase/config.toml`** and are applied with `pnpm hosted:push <dev|test>`. Only the settings declared there change. Fixed on 2026-10-13: dev and test accepted 6-character passwords with no letter or digit rule. They now match D-046.
- **D-074 · Default** — **Dart models parse JSON with hand-written `fromJson` factories**, matching the existing plain immutable classes, instead of freezed (amends D-005). The parsers are tested against real responses captured from `alghali-dev` (`packages/core/test/fixtures`). The repositories are tested against a fake HTTP server, so function and parameter names can't drift from the SQL.
- **D-075 · Default** — **Categories are flat at launch** (12 top-level categories), matching the quick-listing chips and the home screen. The table supports a tree, and search includes child categories, so sub-categories can come later.
- **D-076 · Default** — **New job type `MECHANICAL` (ميكانيكا)** for engine, cooling, gearbox and clutch work, with new category icons `transmission` and `body`. *None of the 8 job types from the UI pass fitted a clutch job.* Body & glass and Accessories have no job type, so those parts can't be booked for fitting.
- **D-077 · Owner input needed** — **The street's city and GPS starting point are not set.** Travel and delivery fees are measured from that point, so the owner must give it before launch, along with the real zone names (the starter data says "القطاع 1…4"). Until then, fee calculations (M2/M3) report that the street location is missing.
- **D-078 · Default** — **Excel import is forgiving about wording, strict about meaning.** What the reader accepts:
  - Arabic or English headers, a title above the header row, and blank rows.
  - Prices like "45,000 ج", Arabic-Indic digits, and warranties like "6 أشهر" or "سنة".
  - Condition words like أصلي, جديد and مستعمل.
  - Categories matched by any shared word, so "اضاءة" finds الإضاءة.

  Rows still need a name, category, condition, price (or "عند الطلب") and quantity, and each problem row is reported with its Excel row number. A re-import updates a listing found by SKU, or else by name + condition + brand.
