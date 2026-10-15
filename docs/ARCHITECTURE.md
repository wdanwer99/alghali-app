# Architecture

Status: M6. M1 (identity, catalogue, street and shops, stock, search, storage), M2 (cart, checkout, payments, fulfilment, returns, ledger, payouts, photo requests, chat) M3 (technicians, slots, bookings, notifications, reviews, disputes), M4 (the buyer app on the real backend, offline cache and outbox, push), M5 (the partner app on the real backend) and M6 (the rest of the admin console). The rules every change follows are in [BRIEF.md](BRIEF.md). See [PLAN.md](PLAN.md) for the full design, [DECISIONS.md](DECISIONS.md) for why and [API.md](API.md) for every call.

```
 Buyer app (Flutter) ──┐                        ┌── Edge Functions (TypeScript): inventory-import, booking-slots, notify-dispatch, admin-set-password
 Partner app (Flutter) ├── supabase SDKs ──► Supabase ──┤
 Admin (Next.js) ──────┘   Auth · PostgREST ·   └── Postgres: tables + RLS + RPC + triggers
                           Storage · Realtime        PostGIS · btree_gist · pg_trgm · pg_cron · pgmq · pg_net
```

## Backend (Supabase)

- **Migrations** live in `supabase/migrations/*.sql`, applied with `pnpm db:push:<dev|test>` (no Docker). CI applies them to a throwaway local Supabase. Applied migrations are never edited; changes go in new files (D-072).
  | File | What |
  |---|---|
  | `…foundation` | extensions, `app_settings`, `ping`, `public_settings` |
  | `…identity` | profiles, roles, devices, idempotency keys, audit log, admin role and settings RPCs, new-user trigger |
  | `…catalogue` | Arabic normaliser, vehicles, job types, categories, parts, fitment, synonyms, garage |
  | `…location` | markets, streets, zones, shops, staff, specialities, addresses, shop application and review |
  | `…inventory` | listings, photos, price history, imports, per-part search documents, shop stock RPCs |
  | `…search` | `search_parts`, `part_detail`, `suggest_parts`, `catalogue_snapshot` |
  | `…storage` | buckets and their policies |
  | `…starter_catalogue` | reference data for every environment (D-071) |
  | `…commerce_core` | references, in-app notifications, the ledger, orders, sub-orders, payments, transition tables |
  | `…order_flow` | refunds, returns, `transition_suborder()` and its side effects, `order_json` |
  | `…checkout` | photo requests and offers, cart, delivery fees, `cart_validate`, `checkout`, `cancel_order` |
  | `…payments` | Bankak receipts, the admin queue, refunds sent |
  | `…fulfilment` | shop, buyer and admin actions on a sub-order; timed jobs (pg_cron) |
  | `…payouts` | shop balances, payout runs, statements |
  | `…chat` | conversations, messages (Realtime), policies for the private buckets |
  | `…notifications` | alert codes and Arabic/English wording, the app each alert is for, the delivery queue, the dispatcher's cron kick |
  | `…technicians` | technicians, job types with labour prices, makes, weekly hours, time off, applying and review |
  | `…bookings` | bookings and the `EXCLUDE` constraint, the booking state machine, eligibility, `booking_context`, holds, offers and reassignment |
  | `…booking_checkout` | checkout with a fitting, parts that follow it, settlement, payment hooks |
  | `…job_day` | technician, buyer and admin actions; holds, offers, reminders and acknowledgement-alert jobs; booking-photos policies |
  | `…technician_money` | technicians in payouts and statements |
  | `…reviews_disputes` | reviews with rating roll-ups, disputes, public technician profiles |
  | `…partner_app` | "closed today" (`closed_until`, `shop_set_closed`), `shop_detail`, `shop_insights` (M5) |
  | `…booking_parts`, `…booking_parts_amounts` | `booking_json` lists where the fitting's parts are and what they cost (M5) |
  | `…admin_tools` | `admin_report`, balance corrections (`admin_ledger_adjustment`, `ADJUSTMENTS` account), audited alert wording, complaint alerts per app (M6) |
- **Rules:** every table has RLS on. Business writes go through `SECURITY DEFINER` functions with `set search_path = ''`, which check the caller's role and ownership. EXECUTE is revoked from `public`, `anon` and `authenticated` and granted per function. Roles are read from `user_roles` on every check (D-065). Admins edit the catalogue tables directly, with an audit trigger (D-068).
- **Errors** are machine codes with an SQLSTATE that sets the HTTP status (D-069); **mutations** that create things take an idempotency key.
- **Search** (D-066): `ar_normalize()` / `ar_stem()` / `search_terms()` turn text into normalised words. Each part keeps one `part_search_docs` row: a `tsvector` of its words plus a trigram index for typos. Synonym groups (`search_synonyms` → `search_synonym_terms`) expand each query word. The Dart twin is `packages/core/lib/src/data/arabic.dart`; both are tested on the same cases.
- **Shops' own parts** (D-067): quick listing creates unverified parts with model-level fitment. Admins merge them into catalogue parts.
- **Orders** (M2): an order splits into one sub-order per shop. Statuses change only along the transition tables, through `transition_suborder()` / `transition_payment()`, which write the event and apply the side effects: stock, cash, ledger, refunds and notifications (D-082). Prices are locked at checkout and stock is reserved (D-015). Bankak orders wait for the receipt, then for an admin to confirm it; cash orders go straight to the shops (D-083, D-084).
- **Money** (D-081): a double-entry, append-only ledger posted per sub-order. A shop's balance is what the platform owes it (or it owes the platform). Payouts and statements are read from the ledger (D-089).
- **Fittings** (M3): `booking-slots` runs the slot engine (pure TypeScript, `_shared/slots`) on `booking_context()`; `create_booking_hold()` re-checks in SQL and the `EXCLUDE` constraint on each technician's blocks (job ± travel buffer) stops double booking (D-096). A fitting is paid through an order and its parts follow it (D-097, D-098). Offers move to the next technician on decline or timeout (D-102). The booking ledger posts labour, travel and booking fees per D-013 and charges late cancellations per D-099.
- **Notifications** (D-101): every alert is a `notifications` row (code + payload + app); a trigger queues one push per device; pg_cron pokes `notify-dispatch` (pg_net, token in Vault), which words the alert in the reader's language and sends it by FCM (Firebase project `alghali-street`, D-109). SMS is a logged stub.
- **Timed jobs** (pg_cron): expire unpaid orders (every 5 minutes), complete delivered orders and expire photo requests (hourly) (D-090); expire holds and move unanswered offers on (every minute), reminders and the shop-acknowledgement alert (every 5 minutes), notification dispatch (every minute).
- **Chat:** `messages` rows under RLS, delivered with Supabase Realtime; voice notes in a private bucket (D-093).
- **Storage:** buckets with size and MIME limits. Public: `media-public` (shop photos under `shops/{shop_id}/`), `templates`, `app-releases`. Private: `imports` (stock sheets under `{shop_id}/`), `receipts` and `request-photos` (under the buyer's id), `voice-notes` (under the conversation id), and `booking-photos` (under the booking id).
- **Edge Functions** (`supabase/functions`, Deno): `admin-set-password` sets a temporary password for an admin (D-080); `inventory-import` reads stock sheets with the vendored SheetJS (D-070) and calls `shop_import_rows` as the caller. The sheet reader (`_shared/inventory/parse.ts`) is plain TypeScript tested with vitest. Deploy with `pnpm functions:deploy:<dev|test>` (bundled server-side, no Docker).
- **Settings** (`app_settings`): admin-editable config with seeded defaults, each value checked by `validate_setting()`. Clients read the safe subset via `public_settings()`.
- **Hosted project settings** (password rule, email confirmation) live in `infra/hosted/supabase/config.toml` (D-073).
- **Health:** `ping()` returns `{ok, server_time}` to anyone.

## Flutter (`apps/buyer`, `apps/partner`, `packages/core`)

- **Workspace:** a Dart pub workspace (root `pubspec.yaml`) gives one lockfile and one shared lint config (`analysis_options.yaml`, page width 100).
- **Material:** code imports `package:material_ui/material_ui.dart`, the decoupled Material library that go_router 18 also uses, not `package:flutter/material.dart`. This keeps a single `ThemeData` / `MaterialLocalizations` type in the app (D-040).
- **State and navigation:** Riverpod 3 for state; go_router 18 for navigation. The first launch redirects to the shared `LanguagePickerScreen` (Arabic preselected).
- **Strings:** each app has `lib/l10n/app_{ar,en}.arb`, with Arabic as the template. `packages/core` has its own `CoreLocalizations` for shared widgets. Generated code is committed, and CI checks it's current.
- **Config:** `AppEnv` reads `--dart-define-from-file=env/dev.json`, which `pnpm env:sync` writes. Without keys the app runs and backend status shows "not set up".
- **Backend layer** (`packages/core/lib/src/backend`): `AuthRepository`, `CatalogueRepository`, `GarageRepository`, `ShopRepository` (stock, the shop's orders and statement), `OrdersRepository` (cart check, checkout, receipts, cancel, returns), `RequestsRepository` (photo requests and offers), `ChatRepository` (conversations, live messages, voice notes), `NotificationsRepository`, `BookingsRepository` (slots, holds, cancel, reschedule, live technician location, reviews, disputes) and `TechnicianRepository` (applying, prices, hours, offers, job day, earnings) and `AddressesRepository` wrap the RPCs and tables with typed models, behind Riverpod providers (`*RepositoryProvider`). Every failure is a `BackendException(code)` (with `sqlState` for database errors; `offline` ones are what the outbox retries). The models parse JSON with `fromJson` factories (D-074). Both apps run on them; the sample data (`lib/src/demo`) is only a fallback for the catalogue.
- **Offline** (D-112): `AppDatabase` (Drift/SQLite) has `cache_entries` and `outbox_entries`.
  - *Reads:* repositories mix in `CachedReads`: network first, the last saved answer when offline (`DriftReadCache`, keys starting `@` stored per user). Table reads follow `ReadPolicy` (one retry, 20 s). `OfflineSeed` loads the catalogue snapshot and public settings before the first frame; `LiveCatalogue` / `LiveSettings` then sync, the catalogue by deltas merged with `mergeSnapshot`.
  - *Writes:* `Outbox` replays queued changes oldest first, each with its idempotency key; a connection problem keeps the change (back-off up to 5 minutes, nothing overtakes it), a refusal is dropped and reported on `results`; `queued()` lists what still waits. Each app supplies its handlers (`apps/*/lib/state/outbox.dart`).
  - *Shared app plumbing:* `onlineProvider` and `CachedList` (saved copy first, then the server) in `sync/connection.dart`; `AsyncBody`, `OfflineBanner`, `showError` and `thumbUrl` in `widgets/async_body.dart`.
- **Push** (D-113): `FirebasePush` behind `PushClient` (`NoPush` in tests and builds without Firebase); started from the `FIREBASE_*` values `pnpm env:sync` writes.
- **Device:** `Launch` (call, WhatsApp, directions, links), `Photos` (camera/gallery, shrunk to 1600 px), `Media` (listing photo sizes, D-126, and photos kept until the outbox uploads them), `Gps` (the phone's position, with clear errors), `VoiceRecordButton` / `VoiceNotePlayer`.

### Buyer app (`apps/buyer`)

- **State** (`lib/state`): `session` (Supabase auth plus the profile, kept for offline starts), `garage`, `cart` (lines kept on the phone and mirrored to `cart_items`; one held fitting at cart level, D-111), `orders` and `bookings` (lists that show the saved copy then refresh, a family provider per order or booking with its actions), `requests`, `account` (addresses, ratings, complaints), `inbox` (alerts, templates, chat), `catalogue` (search, deals, part and shop pages), `push`, `outbox`, `connection` (the offline banner).
- **Screens** keep the approved design (D-051) and read these providers; `AsyncBody` gives every server-backed list the same skeleton, error-with-retry, pull-to-refresh and offline banner.
### Partner app (`apps/partner`)

- **Session** (`state/session.dart`): Supabase auth plus the account from `me()` (shops with their review state, the technician record), kept on the phone; the open home (`role`, `shopId`, D-123). The router waits until the account is known, sends new partners to apply (D-125) and keeps each home's screens apart.
- **Shop** (`state/shop.dart`): the shop (`shop_detail`, "closed today"), orders and their steps, stock (edits and quick listings through the outbox, D-122, with `stockPendingProvider` for what still waits), photo requests and offers, statement, insights, staff. **Technician** (`state/tech.dart`): the record (prices, mode, home point, hours, time off and breaks, D-124), offers and upcoming and past jobs with the job-day steps, live location while on the way, earnings. `inbox.dart` (alerts for the partner app, where each leads, shop chat), `push.dart` (registers as `partner`), `outbox.dart` (`PartnerOps`, `PhotoStore`).
- **Screens** keep the approved design (D-051), plus sign-up, applying, the role picker, chats, alerts, the shop profile and complaints (`features/shared/complaints_screens.dart`, `state/complaints.dart`, D-132). The demo badges and controls are gone.

- **Theme:** `AppTheme.light()` uses large tap targets (52 px primary buttons) and the system Arabic font (nothing bundled; small APK).
- **Android:** minimum SDK 26 (Android 8.0); app IDs `sd.alghali.buyer` and `sd.alghali.partner`.

## Admin (`apps/admin`)

- **Stack:** Next.js 16 (App Router, `cacheComponents`), Tailwind 4, shadcn/ui (Base UI, RTL mode).
- **i18n:** routes live under `app/[lang]` (`ar` default, `en`). `src/proxy.ts` (Next 16's renamed middleware) redirects locale-less paths to the saved or default language. Dictionaries are in `src/i18n/dictionaries/*.json`, read through `next/root-params`, and a test enforces identical keys in both languages.
- **RTL:** `<html dir>` follows the locale, and Base UI's `DirectionProvider` wraps the app.
- **Sign-in:** Supabase Auth email + password with cookie sessions (`@supabase/ssr`). `src/proxy.ts` refreshes the session on every request and sends signed-out visitors to `/{lang}/login`. Only accounts with the `ADMIN` role stay signed in; a non-admin is signed straight back out.
- **Data:** `src/lib/auth.ts` (`requireAdmin()`) reads the session and checks `is_admin()` on every request. Queries in `src/lib/data/` run as that admin, so row level security applies as it does in the apps; no secret key is in the admin app. With `cacheComponents`, each page renders its header at once and streams its data behind `<Suspense>` with a skeleton.
- **Changes:** Server Actions in `src/lib/actions/` re-check the admin, call the same RPCs and tables the docs list, then `refresh()` the page. The UI updates optimistically and undoes the change if the server refuses. Temporary passwords go through the `admin-set-password` Edge Function, which holds the secret key (D-080).
- **Screens:** every page reads the database (D-094, D-106): overview, applications (shops and technicians), shops, users, catalogue, street & zones, settings, payments (receipts and refunds), orders and bookings (each with a detail page), cash and payouts (shops and technicians, with balance corrections, D-130), disputes, reports (D-129) and alert wording (D-131). Receipt and job photos open through 15-minute signed links.
- **Motion:** `motion` for layout and presence animation (sliding nav highlight, cards that leave when decided, toasts, save bars, count-up numbers); CSS `rise` entrances in `globals.css`. Everything honours the OS "reduce motion" setting.

## Tests

| Where | What | Runs |
|---|---|---|
| `tests/db` | Security baseline (RLS on every table; allow-lists of writable tables and callable functions; pinned search paths), every RPC's rules and permissions, search, import, normaliser; M2: the transition tables, checkout, payments, fulfilment, and the ledger balancing on every path; M3: technicians, holds and eligibility, offers and reassignment, the job day, booking money (D-013 examples, cancellations), notifications, reviews and disputes, and 20 parallel holds on one slot (exactly one wins); M5: closed today, a pending shop's detail, insights, a fitting's parts; M6: reports, balance corrections, audited alert wording, complaint alerts | Against `alghali-test` locally, local Supabase in CI |
| `tests/api` | End to end over HTTP as the apps call it: sign-up, password rule, RLS through PostgREST, storage policies, the `inventory-import` function; checkout through receipt, confirmation and fulfilment with the money checked, a reused transfer number, a changed price, guests, chat over Realtime; the whole fitting journey (slots, hold, pay, accept, hand-over, live location, photos, job code, ratings) and the dispatcher | Same; creates real accounts and deletes them afterwards |
| `tests/functions` | The stock-sheet reader on real .xlsx files; the template matches the reader and the starter categories; the slot engine and ranking; push wording and the FCM client | Always |
| `tests/infra` | Env sync never leaks secrets | Always |
| `apps/admin/src/**/*.test.ts` | Dictionary parity, locale/direction | Always |
| `apps/admin/e2e` | Playwright in Chromium (D-133): every page in Arabic and English (direction, data, no browser errors), detail pages, reports, the alert editor; the queue actions (technician approval, balance correction, alert wording, Bankak receipt) only on a throwaway database | CI with actions; `pnpm admin:e2e` read-only against dev |
| `packages/core/test` | JSON parsers on captured responses, repository requests against a fake server, error mapping, normaliser twin, outbox (order, back-off, refusals) and cache on real SQLite, snapshot merging, alert wording, language controller | Always |
| `apps/buyer/test` | Every screen in Arabic and English at 360 dp on answers captured from dev (`FakeBackend`); the fitting-to-checkout journey, a lost hold, chat written offline and replayed once, orders shown offline | Always |
| `apps/buyer/integration_test` | The happy path on an emulator or phone against dev (`pnpm buyer:e2e`) | By hand |
| `apps/partner/test` | Every screen in Arabic and English at 360 dp on answers captured from dev (`FakeBackend`, D-127); order steps, stock edits and a quick listing made offline and replayed, offers, closing for the day, a stock sheet, the job day, the online switch, weekly hours, push, sign-in and applying, complaints | Always |
| `apps/partner/integration_test` | The shop accepts and readies a real order and the technician accepts a real job, on an emulator against dev (`pnpm partner:e2e`; the script places them and cancels them) | By hand |

DB tests wrap each case in a transaction that is rolled back, and switch to `anon` / `authenticated` with JWT claims set exactly as PostgREST does. CI also loads the demo seed twice and checks the second run adds nothing.
