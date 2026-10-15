# Alghali Street — شارع الغالي

Marketplace for car parts and accessories from the shops of Alghali Street (Sudan), plus booking of vetted technicians to fit them — at a workshop bay on the street or at the buyer's location.

Arabic first (RTL), offline-tolerant, light on data. Payments at launch: Bankak (confirmed transfer) and cash.

| Path                | What                                                                                                                                                    |
| ------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `apps/buyer`        | Flutter buyer app (Android first)                                                                                                                       |
| `apps/partner`      | Flutter app for shops and technicians                                                                                                                   |
| `apps/admin`        | Next.js admin panel (Arabic/English, RTL)                                                                                                               |
| `packages/core`     | Shared Dart: theme, language, backend client, offline cache + outbox                                                                                    |
| `packages/db-types` | Generated TypeScript types for the database                                                                                                             |
| `supabase`          | Migrations, Edge Functions, seed data (hosted Supabase backend)                                                                                         |
| `tests`             | Database, state-machine and end-to-end API tests (vitest)                                                                                               |
| `infra/scripts`     | Env sync, Supabase helpers, Flutter helpers                                                                                                             |
| `docs`              | [BRIEF](docs/BRIEF.md) (start here) · [PLAN](docs/PLAN.md) · [DECISIONS](docs/DECISIONS.md) · [ARCHITECTURE](docs/ARCHITECTURE.md) · [API](docs/API.md) |

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
pnpm db:seed:dev            # demo shops, stock, buyers, orders, technicians and fittings — dev only
pnpm notify:setup dev --fcm secrets/firebase-service-account.json   # connect the alert queue to its Edge Function (push is a stub without --fcm)
pnpm env:sync               # copies client-safe keys (and each app's Firebase entry from secrets/google-services.json) into the apps
```

**Demo accounts on alghali-dev** (after `pnpm db:seed:dev`): `admin@demo.alghali.invalid`; buyers `buyer@demo.alghali.invalid`, `buyer.mona@…`, `buyer.sara@…` and `buyer.omer@…`, who have 12 orders between them at different stages; one owner per shop, `owner.<shop>@demo.alghali.invalid` (for example `owner.nour@…`); and ten technicians, `tech.<name>@demo.alghali.invalid` (for example `tech.omar@…`; `tech.mujahid@` and `tech.faisal@` are still waiting for approval), with five fittings between the buyers. They all use the `DEMO_PASSWORD` that the seed saved in `.env`.

## Everyday commands

| Command                                          | Does                                                                                                   |
| ------------------------------------------------ | ------------------------------------------------------------------------------------------------------ |
| `pnpm dev`                                       | Sync env, start the admin at http://localhost:3000 (redirects to `/ar`)                                |
| `pnpm buyer` / `pnpm partner`                    | Run a Flutter app on the connected device/emulator against `alghali-dev`                               |
| `pnpm check`                                     | Everything CI runs: lint, typecheck, TS tests, Dart format, `flutter analyze`, Flutter tests           |
| `pnpm test`                                      | TypeScript tests (DB tests run when `SUPABASE_TEST_DB_URL` is set)                                     |
| `pnpm flutter:test`                              | Flutter tests in core, buyer and partner                                                               |
| `pnpm buyer:e2e [-- -d <device>]`                | The buyer's happy path on a running emulator or phone against `alghali-dev` (signs in as a demo buyer) |
| `pnpm partner:e2e [-- -d <device>]`              | The partner's happy path on an emulator or phone against `alghali-dev` (cleans up)                     |
| `pnpm admin:e2e`                                 | The admin console in Chromium against `alghali-dev`, every page in Arabic and English (read-only)      |
| `pnpm fixtures:buyer`                            | Re-capture the buyer app's test fixtures from `alghali-dev` (demo data)                                |
| `pnpm fixtures:partner`                          | Re-capture the partner app's test fixtures from `alghali-dev`                                          |
| `pnpm db:push:dev` / `pnpm db:push:test`         | Apply new migrations                                                                                   |
| `pnpm db:reset:test`                             | Wipe `alghali-test` and re-apply every migration                                                       |
| `pnpm db:types`                                  | Regenerate `packages/db-types` from `alghali-dev`                                                      |
| `pnpm db:seed:dev`                               | Load the demo shops, stock, buyers, orders, technicians and fittings into `alghali-dev` (dev only)     |
| `pnpm functions:deploy:<dev\|test>`              | Deploy the Edge Functions                                                                              |
| `pnpm hosted:diff <dev\|test>`                   | Compare the project's settings with `infra/hosted/supabase/config.toml` (`hosted:push` applies)        |
| `pnpm import-template`                           | Rebuild `supabase/templates/inventory-template.xlsx`; `pnpm templates:upload <dev\|test>` publishes it |
| `pnpm notify:setup <dev\|test> [--fcm key.json]` | Wire the alert queue to `notify-dispatch`; with a Firebase service account key, pushes really go out   |

Apps built without Supabase keys still run and show "not set up" for backend status.

**Real data.** Both apps (M4, M5) and the admin console read and write the real backend (`alghali-dev` during development). Built without keys, the apps still open, with an empty catalogue.

**Tests that hit Supabase** run against `alghali-test`. `pnpm test` includes end-to-end API tests that create real accounts there and delete them afterwards.

## Screen tests

Every screen of both apps is opened in Arabic and English on a 360 dp phone with answers captured from `alghali-dev` (`apps/<app>/test/screens_test.dart`); `pnpm flutter:test` runs them with the rest.

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
- Secrets live only in the root `.env` and the `secrets/` folder (both git-ignored). `pnpm env:sync` never copies secret keys into apps.
