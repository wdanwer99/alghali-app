# Architecture

Status: M1 (identity, catalogue, street and shops, stock, search, storage). See [PLAN.md](PLAN.md) for the full design, [DECISIONS.md](DECISIONS.md) for why and [API.md](API.md) for every call.

```
 Buyer app (Flutter) ──┐                        ┌── Edge Functions (TypeScript): inventory-import
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
- **Rules:** every table has RLS on. Business writes go through `SECURITY DEFINER` functions with `set search_path = ''`, which check the caller's role and ownership. EXECUTE is revoked from `public`, `anon` and `authenticated` and granted per function. Roles are read from `user_roles` on every check (D-065). Admins edit the catalogue tables directly, with an audit trigger (D-068).
- **Errors** are machine codes with an SQLSTATE that sets the HTTP status (D-069); **mutations** that create things take an idempotency key.
- **Search** (D-066): `ar_normalize()` / `ar_stem()` / `search_terms()` turn text into normalised words. Each part keeps one `part_search_docs` row: a `tsvector` of its words plus a trigram index for typos. Synonym groups (`search_synonyms` → `search_synonym_terms`) expand each query word. The Dart twin is `packages/core/lib/src/data/arabic.dart`; both are tested on the same cases.
- **Shops' own parts** (D-067): quick listing creates unverified parts with model-level fitment. Admins merge them into catalogue parts.
- **Storage:** buckets with size and MIME limits. Public: `media-public` (shop photos under `shops/{shop_id}/`), `templates`, `app-releases`. Private: `imports` (stock sheets under `{shop_id}/`), plus receipts and photos for M2/M3.
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
- **Backend layer** (`packages/core/lib/src/backend`): `AuthRepository`, `CatalogueRepository`, `GarageRepository` and `ShopRepository` wrap the RPCs with typed models, behind Riverpod providers (`*RepositoryProvider`). Every failure is a `BackendException(code)`; `offline` ones are what the outbox will retry (M4). The models parse JSON with `fromJson` factories (D-074). The screens still use sample data until M4/M5 wire them to these repositories.
- **Offline:** `AppDatabase` (Drift/SQLite) has `outbox_entries` (queued mutations keyed by idempotency key) and `cache_entries` (cached reads). The sync engine that replays the outbox is built in M4.
- **Theme:** `AppTheme.light()` uses large tap targets (52 px primary buttons) and the system Arabic font (nothing bundled; small APK).
- **Android:** minimum SDK 26 (Android 8.0); app IDs `sd.alghali.buyer` and `sd.alghali.partner`.

## Admin (`apps/admin`)

- **Stack:** Next.js 16 (App Router, `cacheComponents`), Tailwind 4, shadcn/ui (Base UI, RTL mode).
- **i18n:** routes live under `app/[lang]` (`ar` default, `en`). `src/proxy.ts` (Next 16's renamed middleware) redirects locale-less paths to the saved or default language. Dictionaries are in `src/i18n/dictionaries/*.json`, read through `next/root-params`, and a test enforces identical keys in both languages.
- **RTL:** `<html dir>` follows the locale, and Base UI's `DirectionProvider` wraps the app.
- **Sign-in:** Supabase Auth email + password with cookie sessions (`@supabase/ssr`). `src/proxy.ts` refreshes the session on every request and sends signed-out visitors to `/{lang}/login`. Only accounts with the `ADMIN` role stay signed in; a non-admin is signed straight back out.
- **Data:** `src/lib/auth.ts` (`requireAdmin()`) reads the session and checks `is_admin()` on every request. Queries in `src/lib/data/` run as that admin, so row level security applies as it does in the apps; no secret key is in the admin app. With `cacheComponents`, each page renders its header at once and streams its data behind `<Suspense>` with a skeleton.
- **Changes:** Server Actions in `src/lib/actions/` re-check the admin, call the same RPCs and tables the docs list, then `refresh()` the page. The UI updates optimistically and undoes the change if the server refuses. Temporary passwords go through the `admin-set-password` Edge Function, which holds the secret key (D-080).
- **Live and sample screens:** overview, applications (shops), shops, users, catalogue, street & zones and settings read the database. Payments, orders, bookings, cash, payouts, disputes and technician applications still show sample data from `src/lib/demo/data.ts` under a "Sample data" banner until M2/M3 build their tables (D-079).
- **Motion:** `motion` for layout and presence animation (sliding nav highlight, cards that leave when decided, toasts, save bars, count-up numbers); CSS `rise` entrances in `globals.css`. Everything honours the OS "reduce motion" setting.

## Tests

| Where | What | Runs |
|---|---|---|
| `tests/db` | Security baseline (RLS on every table; allow-lists of writable tables and callable functions; pinned search paths), every RPC's rules and permissions, search, import, normaliser | Against `alghali-test` locally, local Supabase in CI |
| `tests/api` | End to end over HTTP as the apps call it: sign-up, password rule, RLS through PostgREST, storage policies, the `inventory-import` function | Same; creates real accounts and deletes them afterwards |
| `tests/functions` | The stock-sheet reader on real .xlsx files; the template matches the reader and the starter categories | Always |
| `tests/infra` | Env sync never leaks secrets | Always |
| `apps/admin/src/**/*.test.ts` | Dictionary parity, locale/direction | Always |
| `packages/core/test` | JSON parsers on captured responses, repository requests against a fake server, error mapping, normaliser twin, outbox/cache on real SQLite, language controller | Always |
| `apps/*/test` | App opens in Arabic RTL, switches to English LTR | Always |

DB tests wrap each case in a transaction that is rolled back, and switch to `anon` / `authenticated` with JWT claims set exactly as PostgREST does. CI also loads the demo seed twice and checks the second run adds nothing.
