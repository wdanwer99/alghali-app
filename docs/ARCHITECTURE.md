# Architecture

Status: M0. See [PLAN.md](PLAN.md) for the full design and [DECISIONS.md](DECISIONS.md) for why.

```
 Buyer app (Flutter) ──┐                        ┌── Edge Functions (TypeScript)   [M1+]
 Partner app (Flutter) ├── supabase SDKs ──► Supabase ──┤
 Admin (Next.js) ──────┘   Auth · PostgREST ·   └── Postgres: tables + RLS + RPC + triggers
                           Storage · Realtime        PostGIS · btree_gist · pg_trgm · pg_cron · pgmq · pg_net
```

## Backend (Supabase)

- **Migrations** live in `supabase/migrations/*.sql`, applied with `pnpm db:push:<dev|test>` (no Docker). CI applies them to a throwaway local Supabase.
- **Rules:** every table has RLS on. Business writes go through `SECURITY DEFINER` functions with `set search_path = ''`, which check the caller's role and ownership. EXECUTE is revoked from `public` and granted per role.
- **Settings** (`app_settings`): admin-editable config with seeded defaults. Clients read the safe subset via `public_settings()`.
- **Health:** `ping()` returns `{ok, server_time}` to anyone.

## Flutter (`apps/buyer`, `apps/partner`, `packages/core`)

- **Workspace:** a Dart pub workspace (root `pubspec.yaml`) gives one lockfile and one shared lint config (`analysis_options.yaml`, page width 100).
- **Material:** code imports `package:material_ui/material_ui.dart`, the decoupled Material library that go_router 18 also uses, not `package:flutter/material.dart`. This keeps a single `ThemeData` / `MaterialLocalizations` type in the app (D-040).
- **State and navigation:** Riverpod 3 for state; go_router 18 for navigation. The first launch redirects to the shared `LanguagePickerScreen` (Arabic preselected).
- **Strings:** each app has `lib/l10n/app_{ar,en}.arb`, with Arabic as the template. `packages/core` has its own `CoreLocalizations` for shared widgets. Generated code is committed, and CI checks it's current.
- **Config:** `AppEnv` reads `--dart-define-from-file=env/dev.json`, which `pnpm env:sync` writes. Without keys the app runs and backend status shows "not set up".
- **Offline:** `AppDatabase` (Drift/SQLite) has `outbox_entries` (queued mutations keyed by idempotency key) and `cache_entries` (cached reads). The sync engine that replays the outbox is built in M4.
- **Theme:** `AppTheme.light()` uses large tap targets (52 px primary buttons) and the system Arabic font (nothing bundled; small APK).
- **Android:** minimum SDK 26 (Android 8.0); app IDs `sd.alghali.buyer` and `sd.alghali.partner`.

## Admin (`apps/admin`)

- **Stack:** Next.js 16 (App Router, `cacheComponents`), Tailwind 4, shadcn/ui (Base UI, RTL mode).
- **i18n:** routes live under `app/[lang]` (`ar` default, `en`). `src/proxy.ts` (Next 16's renamed middleware) redirects locale-less paths to the saved or default language. Dictionaries are in `src/i18n/dictionaries/*.json`, read through `next/root-params`, and a test enforces identical keys in both languages.
- **RTL:** `<html dir>` follows the locale, and Base UI's `DirectionProvider` wraps the app.
- **Backend:** server components call Supabase with the publishable key. Cookie sessions for signed-in admins arrive in M1.

## Tests

| Where | What | Runs |
|---|---|---|
| `tests/db` | Migrations, RLS, functions, state machines (later), concurrency (M3) | Against `alghali-test` locally, local Supabase in CI |
| `tests/infra` | Env sync never leaks secrets | Always |
| `apps/admin/src/**/*.test.ts` | Dictionary parity, locale/direction | Always |
| `packages/core/test` | Outbox/cache on real SQLite, language controller | Always |
| `apps/*/test` | App opens in Arabic RTL, switches to English LTR | Always |

DB tests wrap each case in a transaction that is rolled back, and switch to `anon` / `authenticated` with JWT claims set exactly as PostgREST does.
