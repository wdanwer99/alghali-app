# Alghali Street — شارع الغالي

Marketplace for car parts and accessories from the shops of Alghali Street (Sudan), plus booking of vetted technicians to fit them — at a workshop bay on the street or at the buyer's location.

Arabic first (RTL), offline-tolerant, light on data. Payments at launch: Bankak (confirmed transfer) and cash.

| Path                | What                                                                                                              |
| ------------------- | ----------------------------------------------------------------------------------------------------------------- |
| `apps/buyer`        | Flutter buyer app (Android first)                                                                                 |
| `apps/partner`      | Flutter app for shops and technicians                                                                             |
| `apps/admin`        | Next.js admin panel (Arabic/English, RTL)                                                                         |
| `packages/core`     | Shared Dart: theme, language, backend client, offline cache + outbox                                              |
| `packages/db-types` | Generated TypeScript types for the database                                                                       |
| `supabase`          | Migrations, Edge Functions, seed data (hosted Supabase backend)                                                   |
| `tests`             | Database, state-machine and end-to-end API tests (vitest)                                                         |
| `infra/scripts`     | Env sync, Supabase helpers, Flutter helpers                                                                       |
| `docs`              | [PLAN](docs/PLAN.md) · [DECISIONS](docs/DECISIONS.md) · [ARCHITECTURE](docs/ARCHITECTURE.md) · [API](docs/API.md) |

## Prerequisites

- Node 22+, pnpm 10 (`npm i -g pnpm`)
- Flutter stable 3.47+ (Dart 3.13+) with the Android SDK — run `flutter doctor --android-licenses` once
- Two Supabase projects (`alghali-dev`, `alghali-test`), region Frankfurt. No Docker needed.

## First-time setup

```bash
pnpm install
flutter pub get
cp .env.example .env        # then fill in both Supabase projects (see comments in the file)
npx supabase login          # once, for type generation
pnpm db:push:dev            # apply migrations to alghali-dev
pnpm db:push:test           # apply migrations to alghali-test
pnpm env:sync               # copies client-safe keys into the apps
```

In each Supabase project, turn **Authentication → Sign In / Providers → Email → Confirm email** off for development (D-031).

## Everyday commands

| Command                                  | Does                                                                                         |
| ---------------------------------------- | -------------------------------------------------------------------------------------------- |
| `pnpm dev`                               | Sync env, start the admin at http://localhost:3000 (redirects to `/ar`)                      |
| `pnpm buyer` / `pnpm partner`            | Run a Flutter app on the connected device/emulator against `alghali-dev`                     |
| `pnpm check`                             | Everything CI runs: lint, typecheck, TS tests, Dart format, `flutter analyze`, Flutter tests |
| `pnpm test`                              | TypeScript tests (DB tests run when `SUPABASE_TEST_DB_URL` is set)                           |
| `pnpm flutter:test`                      | Flutter tests in core, buyer and partner                                                     |
| `pnpm db:push:dev` / `pnpm db:push:test` | Apply new migrations                                                                         |
| `pnpm db:types`                          | Regenerate `packages/db-types` from `alghali-dev`                                            |

Apps built without Supabase keys still run and show "not set up" for backend status.

## Conventions

- Every user-facing string lives in ARB files (Flutter) or `apps/admin/src/i18n/dictionaries` (admin), Arabic and English both complete — tests enforce it.
- Money is integer SDG; times are stored in UTC and shown in `Africa/Khartoum`.
- Every table has row level security; status changes only through database functions that check the caller (see PLAN §1).
- Secrets live only in the root `.env` (git-ignored). `pnpm env:sync` never copies secret keys into apps.
