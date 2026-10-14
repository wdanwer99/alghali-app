# Development brief

Where the project stands and the rules every change follows. Read this before writing code; it is kept current at the end of every milestone. The details live in the other docs:

| Doc | What it holds |
|---|---|
| [`claude-code-prompt-alghali.md`](../claude-code-prompt-alghali.md) | The owner's original brief: product, users, booking rules, acceptance journey |
| [PLAN.md](PLAN.md) | The approved plan: changes from the brief (§0), milestones and their progress (§2), data model (§3), API surface (§4), slot engine (§5), risks (§6) |
| [DECISIONS.md](DECISIONS.md) | Every decision with its reason, numbered D-001… Add one whenever you choose something the plan doesn't say |
| [ARCHITECTURE.md](ARCHITECTURE.md) | How the code is laid out today |
| [API.md](API.md) | Every RPC, table, bucket and Edge Function, with error codes |

---

## 1. Status (2026-10-14)

| Milestone | State | Commit |
|---|---|---|
| M0 Scaffold | Done 2026-10-10 | `4781714` |
| UI pass on sample data (all three apps) | Done 2026-10-11 | part of `d8b921f` and earlier |
| M1 Foundation: identity, catalogue, street and shops, stock, search, storage | Done 2026-10-13 | `911ca7b` |
| Admin console on real data (M6 pulled forward) | Done 2026-10-14 | `fee1db2` |
| M2 Commerce: cart, checkout, payments, fulfilment, returns, ledger, payouts, photo requests, chat | Done 2026-10-14 | `a0a2d74` |
| M3 Installation: technicians, slots, bookings, notifications, reviews, disputes | Done 2026-10-14 | `921e149` |
| Push through Firebase (project `alghali-street`) | Done 2026-10-14 | `173979a` |
| M4 Buyer app on the real backend, offline cache and outbox, push | Done 2026-10-14 | see `git log` |
| M5 Partner app · M6 Admin rest · M7 Hardening and launch | Not started | — |

**Working state of each part:**
- **Backend (Supabase):** everything up to M3 is applied to `alghali-dev` and `alghali-test`, with the Edge Functions deployed and the alert dispatcher wired (`pnpm notify:setup`) with real Firebase push (D-109); phones receive pushes once the apps register their devices (M4/M5).
- **Admin console:** every page reads the real database (D-106); no sample data is left.
- **Buyer app:** every screen runs on the real backend (D-110), works offline for reading and queues safe changes (D-112), and receives push (D-113). Build `0.4.0+4`.
- **Partner app:** every screen exists, on sample data (`packages/core/lib/src/demo`); M5 wires it to the repositories the same way, **without redesigning** (the sample screens are the reference, D-051).

**Waiting on the owner before launch:** the street's city, GPS starting point and real zone names (D-077), the platform Bankak account, real fee amounts (D-034), and a sender mailbox for password-reset emails (D-064). The owner can enter the street, zones, Bankak account and fees in the admin console.

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

## 6. Tests

| Where | How |
|---|---|
| `tests/db/*.test.ts` | Each case in `withRollback`, switching identity with `asUser` / `asAnon` / `asSystem`. Expected failures through `failure(tx, sp => …)`, which uses a savepoint so the transaction survives. Use `must(x)` instead of `!`. Helpers in `tests/support/fixtures.ts` and `commerce.ts` |
| `tests/db/security.test.ts` | **Allow-lists**: every table writable by apps and every function callable by `anon` / `authenticated` is listed. Adding one means adding it here on purpose |
| `tests/api/*.test.ts` | Over HTTP like the apps, creating real users on `alghali-test` and cleaning up with `Fixtures` |
| `packages/core/test` | Parsers on fixtures, repositories on the fake server, outbox and cache on in-memory SQLite |
| `apps/buyer/test` | `FakeBackend` (test/support/backend.dart) answers from fixtures captured on dev (`pnpm fixtures:buyer`). New screens join `screens_test.dart` (Arabic and English at 360 dp); flows go in `journey_test.dart`. |
| `apps/buyer/integration_test` | `pnpm buyer:e2e` with an emulator running: the happy path against dev, cleaning up after itself |
| `apps/admin` | Dictionary parity, locale |

Each milestone's exit criteria in PLAN §2 must have a test. Before committing, `pnpm check` must pass (lint, Prettier, typecheck, TypeScript tests including DB and API, Dart format, `flutter analyze`, Flutter tests).

## 7. Environments, secrets and data

- `alghali-dev` (`mhnftcntnaqarzugwvhz`): the apps and admin during development, with demo data. `alghali-test` (`enyqkvordmzauxwbfwif`): automated tests only. CI runs its own local Supabase.
- **Secrets live only in the root `.env`**, and key files in the root `secrets/` folder (ignored by Git). `pnpm env:sync` copies client-safe values into the apps. Never print keys, never put them in commits or chat.
- **Firebase** (D-109): one project, `alghali-street`, for every environment. Its service account key is `secrets/firebase-service-account.json`, installed with `pnpm notify:setup <dev|test> --fcm secrets/firebase-service-account.json` (re-run after replacing the key). `secrets/google-services.json` (both Android apps, `sd.alghali.buyer` and `sd.alghali.partner`) is read by `pnpm env:sync`, which puts each app's Firebase values in its `env/dev.json` (D-113); no Gradle plugin.
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

- Prettier treats `[lang]` in a path as a glob; target those files with `apps/admin/src/app/**/<page>/page.tsx`.
- A `.catch()` inside a test transaction leaves Postgres in an aborted state; use `failure()`.
- Realtime tests can miss the first message right after a database reset: subscribe first, then send with retries.
- Mock HTTP responses for the Supabase Dart client must set `request: req`.
- `const []` defaults in Dart need explicit type arguments (`const <String>[]`).
- In Next 16, `usePathname()` in a client component outside `<Suspense>` breaks prerendering of a dynamic route; use `instant = false` there.

## 10. What comes next

- **M5 Partner app:** the shop and technician screens on the real backend (orders, stock, requests, chat, statements; offers, job day, hours, earnings), the same way as the buyer app: `liveDataOverrides`, `CachedReads`, an outbox with the partner's handlers (offline listing drafts), push registration with `app: 'partner'`, an `alerts` channel and icon in its Android project, fixtures captured from dev and screen tests in both languages. The technician's en-route location (`tech_update_location`) and job photos (`booking-photos`) are new device work.
- **M6:** the remaining admin work and Playwright smoke tests. **M7:** the acceptance journey end to end, low-end phone profiling, security review, release signing, the APK download page, and the live project.
