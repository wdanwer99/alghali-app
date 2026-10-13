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
npx supabase login          # once, for type generation, deploys and project settings
pnpm db:push:dev            # apply migrations to alghali-dev
pnpm db:push:test           # apply migrations to alghali-test
pnpm hosted:push dev        # password rule + no confirmation emails (infra/hosted/supabase/config.toml)
pnpm hosted:push test
pnpm functions:deploy:dev   # Edge Functions (bundled by Supabase, no Docker)
pnpm functions:deploy:test
pnpm templates:upload dev   # the Excel stock template shops download
pnpm db:seed:dev            # demo shops, stock and accounts — dev only
pnpm env:sync               # copies client-safe keys into the apps
```

**Demo accounts on alghali-dev** (after `pnpm db:seed:dev`): `buyer@demo.alghali.invalid`, `admin@demo.alghali.invalid` and one owner per shop, `owner.<shop>@demo.alghali.invalid` (for example `owner.nour@…`). They all use the `DEMO_PASSWORD` that the seed saved in `.env`.

## Everyday commands

| Command                                  | Does                                                                                                   |
| ---------------------------------------- | ------------------------------------------------------------------------------------------------------ |
| `pnpm dev`                               | Sync env, start the admin at http://localhost:3000 (redirects to `/ar`)                                |
| `pnpm buyer` / `pnpm partner`            | Run a Flutter app on the connected device/emulator against `alghali-dev`                               |
| `pnpm check`                             | Everything CI runs: lint, typecheck, TS tests, Dart format, `flutter analyze`, Flutter tests           |
| `pnpm test`                              | TypeScript tests (DB tests run when `SUPABASE_TEST_DB_URL` is set)                                     |
| `pnpm flutter:test`                      | Flutter tests in core, buyer and partner                                                               |
| `pnpm db:push:dev` / `pnpm db:push:test` | Apply new migrations                                                                                   |
| `pnpm db:reset:test`                     | Wipe `alghali-test` and re-apply every migration                                                       |
| `pnpm db:types`                          | Regenerate `packages/db-types` from `alghali-dev`                                                      |
| `pnpm db:seed:dev`                       | Load the demo shops and stock into `alghali-dev` (refuses any other project)                           |
| `pnpm functions:deploy:<dev\|test>`      | Deploy the Edge Functions                                                                              |
| `pnpm hosted:diff <dev\|test>`           | Compare the project's settings with `infra/hosted/supabase/config.toml` (`hosted:push` applies)        |
| `pnpm import-template`                   | Rebuild `supabase/templates/inventory-template.xlsx`; `pnpm templates:upload <dev\|test>` publishes it |

Apps built without Supabase keys still run and show "not set up" for backend status.

**Sample data.** For now all three apps run on built-in sample data (PLAN §2, D-051), so every screen works without a backend. Nothing real happens: the Bankak account shown is a dummy, and calls and messages are switched off. The backend behind them is ready from M1; M4–M6 switch the screens over to it (`packages/core/lib/src/backend`).

**Tests that hit Supabase** run against `alghali-test`. `pnpm test` includes end-to-end API tests that create real accounts there and delete them afterwards.

## Screenshots

Flutter screens are rendered by golden tests with the real font. The PNGs go to `apps/<app>/build/screenshots/` (git-ignored):

```bash
cd apps/buyer   && flutter test test/screenshots --dart-define=SCREENSHOTS=true --update-goldens
cd apps/partner && flutter test test/screenshots --dart-define=SCREENSHOTS=true --update-goldens
```

These tests are skipped in a normal `flutter test` run.

## Logo, icons and splash

The logo is a placeholder drawn in code (D-049): `MarkPainter` in `packages/core/lib/src/widgets/brand.dart`, and the `Mark` SVG in `apps/admin/src/components/admin/ui.tsx`. After changing it:

1. Export the PNGs into `apps/*/assets/icon/`:
   ```bash
   cd packages/core && flutter test test/export_icons_test.dart --dart-define=EXPORT_ICONS=true --update-goldens
   ```
2. In `apps/buyer` and then `apps/partner`, run:
   ```bash
   dart run flutter_launcher_icons
   dart run flutter_native_splash:create
   ```
3. Undo two unrelated edits these tools make to the iOS project:
   ```bash
   git checkout -- apps/buyer/ios/Runner.xcodeproj/project.pbxproj apps/buyer/ios/Runner/Info.plist
   git checkout -- apps/partner/ios/Runner.xcodeproj/project.pbxproj apps/partner/ios/Runner/Info.plist
   ```
4. Update the admin `Mark` if the glyph or dot moved.

## Conventions

- Every user-facing string lives in ARB files (Flutter) or `apps/admin/src/i18n/dictionaries` (admin), Arabic and English both complete — tests enforce it.
- Money is integer SDG; times are stored in UTC and shown in `Africa/Khartoum`.
- Every table has row level security; status changes only through database functions that check the caller (see PLAN §1).
- Secrets live only in the root `.env` (git-ignored). `pnpm env:sync` never copies secret keys into apps.
