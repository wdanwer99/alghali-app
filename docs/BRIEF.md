# Development brief

Where the project stands and the rules every change follows. Read this before writing code; it is kept current at the end of every milestone. The details live in the other docs:

| Doc | What it holds |
|---|---|
| [`claude-code-prompt-alghali.md`](../claude-code-prompt-alghali.md) | The owner's original brief: product, users, booking rules, acceptance journey |
| [PLAN.md](PLAN.md) | The approved plan: changes from the brief (§0), milestones and their progress (§2), data model (§3), API surface (§4), slot engine (§5), risks (§6) |
| [DECISIONS.md](DECISIONS.md) | Every decision with its reason, numbered D-001… Add one whenever you choose something the plan doesn't say |
| [ARCHITECTURE.md](ARCHITECTURE.md) | How the code is laid out today |
| [API.md](API.md) | Every RPC, table, bucket and Edge Function, with error codes |
| [DATABASE.md](DATABASE.md) | The schema in full: every table and column, keys, checks, indexes, triggers, status machines, ledger, settings, timed jobs |
| [DEPLOY.md](DEPLOY.md) | Going live and staying live: the owner's inputs, the live project, Netlify, releasing the apps, backups |
| [SECURITY.md](SECURITY.md) | The M7 security review: what is enforced, which test keeps it, the remaining risks |
| [PERFORMANCE.md](PERFORMANCE.md) | The apps on a low-end Android 8 phone (emulated) |

---

## 1. Status (2026-10-15, M7)

| Milestone | State | Commit |
|---|---|---|
| M0 Scaffold | Done 2026-10-10 | `4781714` |
| UI pass on sample data (all three apps) | Done 2026-10-11 | part of `d8b921f` and earlier |
| M1 Foundation: identity, catalogue, street and shops, stock, search, storage | Done 2026-10-13 | `911ca7b` |
| Admin console on real data (M6 pulled forward) | Done 2026-10-14 | `fee1db2` |
| M2 Commerce: cart, checkout, payments, fulfilment, returns, ledger, payouts, photo requests, chat | Done 2026-10-14 | `a0a2d74` |
| M3 Installation: technicians, slots, bookings, notifications, reviews, disputes | Done 2026-10-14 | `921e149` |
| Push through Firebase (project `alghali-street`) | Done 2026-10-14 | `173979a` |
| M4 Buyer app on the real backend, offline cache and outbox, push | Done 2026-10-14 | `fb20a5e` |
| M5 Partner app on the real backend: shops and technicians, joining, offline stock | Done 2026-10-15 | `a0142bd` |
| M6 Admin console: reports, balance corrections, alert wording, complaints for partners, browser tests | Done 2026-10-15 | `c8fd649` |
| M7 Hardening: the acceptance journey end to end, security review, release signing, download page, backups, deployment guide | Done 2026-10-15 | see `git log` |
| Launch: the live project | Waiting on the owner (DEPLOY §1–2) | — |

**Working state of each part:**
- **Backend (Supabase):** everything up to M7 and the fixes after it (D-142, D-143) is applied to `alghali-dev` and `alghali-test`, with the Edge Functions deployed and the alert dispatcher wired (`pnpm notify:setup`); both apps register their phones for push. Push goes out through Firebase on both since 2026-10-16 (D-146: before that the key couldn't be read and every push was a stub); open apps also get their alerts over Realtime (D-142).
- **Admin console:** every page reads the real database (D-106), plus reports (D-129), balance corrections (D-130) and the alert wording editor (D-131); every page is tested in a browser in both languages (D-133).
- **Buyer app:** every screen runs on the real backend (D-110), works offline for reading and queues safe changes (D-112), and receives push (D-113). Build `0.4.0+4`.
- **Partner app:** every screen runs on the real backend (D-119–D-128): joining as a shop or technician (shops can set a map pin when joining or later, D-145), one account with several homes, shop orders, stock with offline edits and quick listings, photo requests, chat, money, staff, insights, "closed today"; the technician's offers, job day with photos, the buyer's code and live location, hours, breaks and time off, earnings; complaints with replies and "Report a problem" (D-132); the update banner and screen (D-138). Build `0.6.0+6`.

**Releases** are signed with the key in `secrets/` (D-134), two APKs per version (D-135), published with `pnpm release:apk` and installed from the console's public download page (D-138).

**Waiting on the owner before launch** (DEPLOY §1): the street's city, GPS starting point and real zone names (D-077), the platform Bankak account, real fee amounts (D-034), a sender mailbox for password-reset emails (D-064), a new Firebase key (the old one was pasted in chat), backups of `secrets/`, a backup passphrase, a Netlify account, and which free project to pause for the live one (D-060). The owner can enter the street, zones, Bankak account and fees in the admin console.

---

## 2. Product rules that never change

- **Arabic first, full RTL;** English second. No hard-coded user-facing text: ARB files in Flutter, JSON dictionaries in the admin, with tests that both languages have the same keys. Western digits in both languages (D-048).
- **Users are on cheap Android phones with poor data.** Small payloads, thumbnails first, offline cache and an outbox for actions (M4).
- **Money is whole SDG in `bigint`** (`*_sdg` columns), never floats. Percentages in basis points, rounded half up (D-014).
- **Times are stored in UTC** and shown in `Africa/Khartoum` (UTC+2, no daylight saving). Weekly availability is local wall-clock time.
- **Bankak is a confirmed transfer.** A payment is confirmed only by an admin who found it on the bank statement, never from a screenshot alone. One transaction number pays one thing only (D-017, D-084).
- **Android only, installed from a download link** (D-057, D-058). **Email + password** sign-in for everyone (D-059). **Push only** for alerts at launch; SMS and WhatsApp are logged stubs (D-061). **Free Supabase plan** for now (D-060).

---

## 3. Backend rules (Supabase, Postgres)

**Where things go.** Postgres holds the truth and the rules (PLAN §1). Reads go through PostgREST under row level security. Business changes go through RPC functions. Simple owned rows (garage, addresses, cart, chat messages, availability) are written directly under RLS. Edge Functions only for pure TypeScript logic worth unit testing (slot engine, fee maths), outside services (push), and file parsing.

**Migrations**
- One file per topic: `supabase/migrations/<yyyymmddhhmmss>_<topic>.sql`, starting with a comment that says what it adds.
- **An applied migration is never edited** (D-072). Fix things in a new file. `alghali-test` can be wiped (`pnpm db:reset:test`); `alghali-dev` cannot.
- Apply with `pnpm db:push:test` and `pnpm db:push:dev`, then `pnpm db:types` to regenerate `packages/db-types`.
- Update [DATABASE.md](DATABASE.md) in the same change for any new or changed table, column, constraint, status, setting or timed job.

**Every function**
- `security definer` with `set search_path = ''`, and every name schema-qualified (`public.orders`, `extensions.st_distance`).
- Checks the caller first, with the existing helpers: `require_user()`, `require_admin()`, `require_shop(shop_id, owner_only)`, `require_shop_writable(shop_id)`, `require_sub_order_shop(id)`, `require_own_sub_order(id)`, `has_role(role)`, `is_admin()`, `is_shop_member(shop_id)`. Roles are read from `user_roles` on every check; there is no JWT claims hook (D-065).
- After creating it: `revoke all on function … from public, anon, authenticated;` then `grant execute … to authenticated` (or `anon`) only for functions the apps call. Internal helpers stay ungranted.
- **Errors are machine codes** (D-069): `raise exception 'SOME_CODE' using errcode = …` with `42501` (403), `P0002` (404), `PT409` (409) or `22023` (400). Put extra data for the app in `detail`. List every new code in API.md.
- **Calls that create things take `p_idem uuid`**: `v_prev := public.idem_begin(p_idem, 'fn_name'); if v_prev is not null then return v_prev; end if; … return public.idem_finish(p_idem, 'fn_name', result);`
- Admin actions write `public.audit(action, entity, entity_id, data)`.
- Settings are read with `public.setting(key)` / `public.setting_int(key)`. A new key needs a default row in `app_settings` (`is_public = true` if the apps may read it through `public_settings()`) and a shape check in `validate_setting()`.
- References a buyer may type into a Bankak note come from `public.new_ref('ORDER' | 'BOOKING')`: 8 digits with a Luhn check digit (D-016).

**State machines** (D-082). A status column changes only along a transition table (`from, to, actor`) checked by a trigger that reads `current_setting('app.actor')`. Only the matching `transition_*()` function sets the actor, writes the event row and applies side effects. New machines (bookings, booking offers) follow the same pattern: enum → transition table rows → guard trigger → one `transition_<thing>()` → callers that check who may act.

**Money** (D-081). Double-entry ledger, append-only. Post with `public.post_journal(kind, debit_account, credit_account, amount, order_id, sub_order_id, payment_id, …)`; accounts by `public.ledger_account('CODE')` and `public.shop_account(shop_id)` and `public.tech_account(technician_id)`; booking journals use `public.post_booking_journal(…)`. Every journal balances; `BUYER_FUNDS_HELD` ends at zero for every order. A party's credit balance = the platform owes them; debit = they owe the platform (netted from payouts, D-018). The worked examples in D-013 are the reference for bookings too.

**Alerts** (D-091). Write rows with `public.notify(user_id, CODE, payload)` / `public.notify_shop(shop_id, CODE, payload)`, `public.notify_partner(user_id, …)` (technicians) or `public.notify_admins(CODE, payload)`: a code plus data, never text, tagged with the app it's for. **Every new code needs a `notification_codes` row and Arabic and English `notification_templates`** (a test fails otherwise). The dispatcher turns the rows into pushes (D-101).

**Bookings** (D-096–D-102). The `EXCLUDE` constraint on `bookings` is the final word on double booking; the slot engine (`supabase/functions/_shared/slots`) only lists times. Booking statuses change through `transition_booking()`; money through `settle_booking()`; parts bought for a fitting follow it through `booking_parts_follow()`. Fittings are always paid through an order.

**Timed jobs** use pg_cron (`select cron.schedule('name', 'cron', $$select public.fn()$$)`) calling a plain SQL function that the tests can also call.

**RLS.** Every table has RLS on (a test fails otherwise). Policies use `(select auth.uid())` and the helper functions. A party sees its own rows only; shops never see another shop's part of an order (D-086). Private files live under a folder named after their owner (`receipts/{user_id}/…`, `voice-notes/{conversation_id}/…`).

---

## 4. Admin console rules (`apps/admin`)

- Next.js 16 App Router with `cacheComponents`. Pages: header first, data streamed behind `<Suspense>` with a skeleton. Call `connection()` before creating the Supabase session client. Dynamic `[id]` routes set `export const instant = false`.
- Reads in `src/lib/data/*.ts` run **as the signed-in admin** (`requireAdmin()`), so RLS applies; no secret key in the admin app.
- Changes are Server Actions in `src/lib/actions/*.ts` returning an `ActionResult`, used with `useAction` (optimistic update, toast, undo on refusal). They call the same RPCs the apps use.
- Text in `src/i18n/dictionaries/{ar,en}.json` (parity test). Status labels and colours come from `src/lib/tones.ts`, keyed by the database enum values.
- New screens read real data from the start; the old sample-data banner and menu tag are no longer used.

## 5. Flutter rules (`packages/core`, `apps/buyer`, `apps/partner`)

- Import `package:material_ui/material_ui.dart`, not Flutter's material (D-040). Riverpod 3, go_router 18. Page width 100.
- Models are plain immutable classes with hand-written `fromJson` (D-074). Enums map to database codes with `code` / `fromCode` (`screamingCase` / `camelCase` in `models/commerce.dart`).
- Repositories in `lib/src/backend/` wrap RPCs and tables, run every call through `guard()` so failures become `BackendException(code)`, pass `p_idem: idem ?? newIdempotencyKey()` on creating calls, and are exposed as `*RepositoryProvider`s.
- Parsers are tested against real responses saved in `test/fixtures/*.json` (captured from `alghali-dev`); repositories against the fake server in `test/support/fake_server.dart`, so function and parameter names can't drift from the SQL.
- Generated code (gen-l10n, Drift) is committed. Don't run `dart format` over `lib/src/db/app_database.g.dart`; use `pnpm flutter:format`, which skips it.
- Core class names must not clash with app classes: the core uses `CheckoutLine` and `ShopSubOrder` because the apps' sample state already has `CartLine` and `ShopOrder`.
- **Reads** go through repositories that mix in `CachedReads` (`cachedRead('@key', fetch, parse)`): keys starting `@` are per user. App lists are `AsyncNotifier`s with the `CachedList` mixin (saved copy first, then the server) or a family provider per item; screens show them with `AsyncBody` (skeleton, error with retry, pull-to-refresh, offline banner).
- **Writes** that can wait go through the app's outbox (`queue(ref, BuyerOps.x, payload)` or `ref.read(queueProvider)`): add an op and its handler in `state/outbox.dart`, pick an id on the phone for inserts and treat `BackendException.duplicate` as done. Anything that must be checked now calls the repository directly and shows `context.core.error(e)`.
- Every backend error code a user can meet needs a line in `ErrorLabels.errorCode` (core `labels.dart`) and its Arabic and English text.
- The apps' catalogue is `catalogueProvider` overridden with `liveCatalogueProvider` (`liveDataOverrides`); lookups never throw, so check `hasShop` / `hasVariant` where an empty placeholder would look wrong.
- **Partner app:** the open home is `partnerSessionProvider` (`role`, `shopId`); shop state reads `currentShopIdProvider`. Its outbox ops are `PartnerOps` (stock edits through `shop_bulk_update` with the version raised by one per change, quick listings with their photo kept by `PhotoStore`). Device plugins that tests can't run are behind providers: `photoPickerProvider`, `sheetPickerProvider`, `photoStoreProvider`, `locationSharingEnabledProvider`, and map tiles behind `mapTilesEnabledProvider` (D-145).
- `onlineProvider`, `CachedList`, `AsyncBody`, `OfflineBanner`, `showError` and `thumbUrl` are in the core package, shared by both apps.
- **Splash and welcome** (D-144): `SplashGate` (in each app's `MaterialApp.builder`) and `WelcomeTour` (the `/welcome` route) are in the core. Widget tests turn the splash off (`splashEnabledProvider`); device tests wait for the tour's Skip to be tappable (`find.text('تخطي').hitTestable()`). If the mark changes, re-export the icons (`export_icons_test.dart`) and run `flutter_native_splash:create`: the splash's first frame must match the launch screen.

## 6. Tests

| Where | How |
|---|---|
| `tests/db/*.test.ts` | Each case in `withRollback`, switching identity with `asUser` / `asAnon` / `asSystem`. Expected failures through `failure(tx, sp => …)`, which uses a savepoint so the transaction survives. Use `must(x)` instead of `!`. Helpers in `tests/support/fixtures.ts` and `commerce.ts` |
| `tests/db/security.test.ts` | **Allow-lists**: every table writable by apps and every function callable by `anon` / `authenticated` is listed. Adding one means adding it here on purpose |
| `tests/api/*.test.ts` | Over HTTP like the apps, creating real users on `alghali-test` and cleaning up with `Fixtures` |
| `packages/core/test` | Parsers on fixtures, repositories on the fake server, outbox and cache on in-memory SQLite |
| `apps/buyer/test` | `FakeBackend` (test/support/backend.dart) answers from fixtures captured on dev (`pnpm fixtures:buyer`). New screens join `screens_test.dart` (Arabic and English at 360 dp); flows go in `journey_test.dart`. |
| `apps/buyer/integration_test` | `pnpm buyer:e2e` with an emulator running: the happy path against dev, cleaning up after itself |
| `apps/partner/test` | Like the buyer's: `FakeBackend` on fixtures from dev (`pnpm fixtures:partner`, signed in as the demo owner and technician; non-demo people are replaced), plus a new order, a photo request and a job offer it adds. New screens join `screens_test.dart`; flows go in `journey_test.dart`. |
| `apps/partner/integration_test` | `pnpm partner:e2e` with an emulator running: the script places a cash order and a fitting as a demo buyer, the shop and the technician act on them, and an admin cancels both |
| `apps/admin` | Dictionary parity, locale, every Server Action checks the admin (vitest) |
| `tests/api/journey.test.ts` | The acceptance journey, steps 1–9 over HTTP (D-139). Changing a flow it covers means updating it |
| `tests/device/acceptance.device.ts` | `pnpm journey:e2e` with an emulator running: the acceptance journey with both apps (`apps/*/integration_test/acceptance_test.dart`) against alghali-test, with fresh accounts deleted afterwards. Run it before a release |
| `apps/*/integration_test/perf_test.dart` | `pnpm perf:e2e`: start-up, frame times and memory in profile mode ([PERFORMANCE.md](PERFORMANCE.md)) |
| `apps/admin/e2e` | Playwright (D-133). `pages.spec.ts` opens every page in both languages; `actions.spec.ts` changes data and is skipped unless `E2E_WRITES=1` (CI only). New pages join `PAGES`; find buttons by their dictionary text or `aria-label`, never by position. `pnpm admin:e2e` runs it read-only against dev (`-- --fresh` builds and serves the console on port 3101, for `next.config.ts` changes a running dev server hasn't picked up) |

Each milestone's exit criteria in PLAN §2 must have a test. Before committing, `pnpm check` must pass (lint, Prettier, typecheck, TypeScript tests including DB and API, Dart format, `flutter analyze`, Flutter tests).

## 7. Environments, secrets and data

- `alghali-dev` (`mhnftcntnaqarzugwvhz`): the apps and admin during development, with demo data. `alghali-test` (`enyqkvordmzauxwbfwif`): automated tests only. CI runs its own local Supabase.
- **Secrets live only in the root `.env`**, and key files in the root `secrets/` folder (ignored by Git). `pnpm env:sync` copies client-safe values into the apps. Never print keys, never put them in commits or chat.
- **Firebase** (D-109): one project, `alghali-street`, for every environment. Its service account key is `secrets/firebase-service-account.json`, installed with `pnpm notify:setup <dev|test> --fcm secrets/firebase-service-account.json` (re-run after replacing the key). `secrets/google-services.json` (both Android apps, `sd.alghali.buyer` and `sd.alghali.partner`) is read by `pnpm env:sync`, which puts each app's Firebase values in its `env/dev.json` (D-113); no Gradle plugin.
- **The release signing key** is `secrets/alghali-release.jks` with `secrets/android-release.properties` (D-134). Never regenerate it: a new key can't update installed apps.
- **The live project** is `SUPABASE_LIVE_*` in `.env`. Only `db:push:live`, `functions:deploy:live`, `hosted:push live`, `notify:setup live`, `templates:upload live` and `release:apk … live` target it.
- **Demo data never reaches a live project.** `pnpm db:seed:dev` refuses any target except dev. The starter catalogue is a migration and goes everywhere (D-071).
- Hosted auth settings are changed only through `infra/hosted/supabase/config.toml` and `pnpm hosted:push` (D-073). Don't push the repo's `supabase/config.toml` to a hosted project.
- Edge Functions deploy with `pnpm functions:deploy:<dev|test>` (bundled by Supabase, no Docker).

## 8. Working with the owner

- The owner reads short plain-language summaries; they are not a developer.
- **Stop after each milestone** with a summary and wait for "go" (D-056). Every milestone ends with `pnpm check` green, docs updated (PLAN progress, DECISIONS, API, ARCHITECTURE, this brief) and a local commit. **Push only when the owner asks.**
- Some uncommitted files in the working tree are the owner's own work: `packages/core/lib/src/widgets/{brand,common,language_picker}.dart`, `apps/buyer/lib/features/orders/order_screen.dart`, `apps/partner/.metadata`, `apps/partner/analysis_options.yaml`, `apps/partner/web/`, `docs/business/`. Leave them out of commits unless the owner says otherwise.

## 9. Known traps

- The test project's session pooler allows 15 connections; tests needing more go through the transaction pooler (port 6543, `prepare: false`), as `tests/db/concurrency.test.ts` does.
- Run Prettier from the repo root (or with `--list-different` there): from `apps/admin` it misses the root `.prettierignore` and rewrites the vendored `components/ui` files.
- `pnpm db:seed:dev` only targets dev or a `127.0.0.1` stack, on purpose.
- In plpgsql, a `record` variable that was never assigned can't be read, even inside a `case`; use plain variables when a branch may skip the `select … into`.
- The Supabase Dart client applies `postgrestOptions` (retries, timeout) to `rpc()` only, not to `from()` table queries; `CachedReads` sets them per query (`ReadPolicy`). Tests set `ReadPolicy.retries = 0`, or a retry timer outlives the test.
- In the bash tool, heredocs lose backslashes (`\n` becomes a newline): write Python edit scripts to a file first when the text has backslashes.
- Widget tests only build what is on screen: a `ListView` item below the fold isn't found. Order numbers are wrapped in invisible direction marks (`formatRef`), so match on part of the digits.
- Plugins that touch the platform at construction (the microphone recorder) must be created on first use, or widget tests fail with `MissingPluginException`.
- An order for a fitting alone has no sub-orders: never take `subOrders.first` unguarded.
- Device tests (`integration_test`): `tester.pageBack()` can't see the `material_ui` back button, so use `tester.binding.handlePopRoute()`; parts of a page load a moment later and push items out of the built part of a list, so wait for them before `scrollUntilVisible`; the run leaves the demo buyer's garage changed, and cancels the order it places (if a run stops half-way, cancel what it left as that demo buyer).

- Phones' clocks can be hours out (automatic time switched off). Compare server times with `ref.read(clockProvider)()`, which follows the server (D-143), never `DateTime.now()`.
- The Firebase key is installed base64-encoded (`FCM_SERVICE_ACCOUNT_B64`, D-146); as raw JSON in the secrets file it broke. `notify-dispatch` answers `{fcm, account}`: `account: 'unreadable'` means the key is installed but broken. The M3 dispatcher test fails then, and requires a real Firebase refusal whenever a key is there.
- Prettier treats `[lang]` in a path as a glob; target those files with `apps/admin/src/app/**/<page>/page.tsx`.
- A `.catch()` inside a test transaction leaves Postgres in an aborted state; use `failure()`.
- Realtime tests can miss the first message right after a database reset: subscribe first, then send with retries.
- Mock HTTP responses for the Supabase Dart client must set `request: req`.
- `const []` defaults in Dart need explicit type arguments (`const <String>[]`).
- In Next 16, `usePathname()` in a client component outside `<Suspense>` breaks prerendering of a dynamic route; use `instant = false` there.
- A provider that watches another can't be invalidated from that other one (Riverpod's circular dependency): let it recompute by watching.
- The partner router waits for the account (`PartnerSession.loaded`): publishing a session with the user but not yet their shops sent partners to "apply" and left them there.
- Device tests: a snack bar from the last step can cover the next button (clear them before tapping); a switch that waits for data is disabled until it arrives; "open now" depends on the time of day, so check the switch's value, not its words.
- Device tests: a list builds only what is on screen, so scroll to a section before waiting for it (`scrollUntilVisible`); `Gps.here()` waits on Android's permission prompt, which a test can't answer (use `gpsProvider`); `flutter test --plain-name` gets one word through the shell, so test names carry a single-word tag (`order`, `rate`, `offer`, `jobday`); reminders go out only for accepted jobs.
- Release APKs from before M7 (debug key, split version codes like 4005) block installing a test build over them (`INSTALL_FAILED_VERSION_DOWNGRADE`); Flutter uninstalls and retries.
- `file_picker` 13 has a static API (`FilePicker.pickFile`, `PlatformFile.xFile`); 10.x clashes with another package's `win32`.
- The partner fixtures include whoever used dev; the capture script replaces non-demo people. Never commit fixtures captured without it.
- Playwright failure traces and page snapshots can contain the admin password typed at sign-in. `pnpm admin:e2e` deletes `test-results/`, `playwright-report/` and `e2e/.auth/` afterwards, and they are ignored by Git; don't attach them anywhere.
- `pnpm admin:e2e` reuses a dev server already on port 3000 (two `next dev` in one folder clash); the first visit to each page compiles it, hence the long timeouts.

## 10. What comes next

- **Launch** (DEPLOY.md): the owner's inputs (§1), the live project and pausing dev or test (§2), Netlify (§3), the first releases (§4), backups (§5). Then phone OTP sign-in (D-059) and SMS (D-061) when the owner chooses providers.
- **Not built yet:** upload screens for a shop's storefront photo and a technician's avatar (the backend takes both; the buyer app doesn't show them); photos on offers for photo requests; a CAPTCHA if fake sign-ups appear (SECURITY.md).
