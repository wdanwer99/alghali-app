# Deploying Alghali Street

How to put the platform in front of real users, and keep it running. Every step is a command
in this repository or a page in a free online service; nothing needs a server of our own.
Decisions behind it: D-057–D-064 (launch choices), D-134–D-138 (M7).

| Part | Where it runs | Cost |
|---|---|---|
| Database, sign-in, files, server functions | Supabase project **alghali-live** (free plan) | Free |
| Push alerts | Firebase project **alghali-street** (already set up, D-109) | Free |
| Admin console and the app download page | Netlify (free plan, D-137) | Free |
| Android apps | APK files in alghali-live's `app-releases` bucket | Free |
| Nightly database backup | GitHub Actions, kept 30 days (D-136) | Free |

---

## 1. Before launch: what only the owner can provide

- [ ] **The street:** city, GPS starting point and the real zone names (admin console → Street & zones, D-077). Fittings at the buyer's place and delivery stay off until the starting point is set.
- [ ] **The platform's Bankak account** name and number, and the **real fees** (console → Settings, D-034).
- [ ] **Support phone and WhatsApp** shown in the apps (console → Settings).
- [ ] **A sender mailbox for password-reset emails** (D-064): a new Gmail account with 2-step verification and an *app password*. Until then, admins set temporary passwords from the console (Users).
- [ ] **A new Firebase key.** The one pasted in chat on 2026-10-14 (ID starting `bd697974`) must be deleted in Google Cloud → IAM → Service accounts → Keys, and a new one saved as `secrets/firebase-service-account.json`.
- [ ] **Backups of the secrets folder** on two places that are not this computer (a USB stick and a password manager):
  - `secrets/alghali-release.jks` and `secrets/android-release.properties` — the app signing key and its password (its SHA-256 fingerprint is `B4:64:31:FE:7A:25:C6:24:B8:8C:DF:F6:CB:8D:5E:CE:C3:7F:AC:08:8F:2C:00:9D:8E:E5:05:E4:5B:7B:42:33`; `keytool -list -v -keystore alghali-release.jks` shows it, to check a backup is the right key). **If they are lost, no installed app can ever be updated**; everyone would have to uninstall and reinstall.
  - `secrets/firebase-service-account.json` and `secrets/google-services.json`.
  - the root `.env` file.
- [ ] **A backup passphrase** (a long sentence only the owner knows), for the nightly backups.

## 2. The live Supabase project

The free plan allows two active projects, and `alghali-dev` and `alghali-test` use both (D-060).
Pause one of them first (Supabase dashboard → project → Settings → General → Pause project):

- pausing **alghali-test** stops `pnpm check`'s database tests on this computer (CI keeps its own database, so CI is unaffected);
- pausing **alghali-dev** stops the demo data the apps and console use during development.

A paused free project can be restored from the dashboard later.

1. Create the project: <https://supabase.com/dashboard> → New project, name `alghali-live`, region **Central EU (Frankfurt)**, a strong database password (keep it in the password manager).
2. Copy its values into the root `.env` (`SUPABASE_LIVE_*`, see `.env.example`): Project Settings → API keys for the publishable and secret keys; Connect → Session pooler for `SUPABASE_LIVE_DB_URL`.
3. Apply everything:

   ```sh
   pnpm db:push:live                 # every migration, including the starter catalogue
   pnpm hosted:push live             # password rule, sign-in limits, no confirmation emails
   pnpm functions:deploy:live        # booking-slots, notify-dispatch, inventory-import, admin-set-password
   pnpm notify:setup live --fcm secrets/firebase-service-account.json   # push alerts
   pnpm templates:upload live        # the stock sheet template shops download
   ```

   `pnpm db:seed:*` refuses the live project: demo data never reaches real users (D-071).
4. **The first admin.** Sign up in the buyer app (or console sign-in page) with the owner's email, then in the Supabase dashboard → SQL editor run:

   ```sql
   insert into public.user_roles (user_id, role)
   select id, 'ADMIN' from auth.users where email = 'owner@example.com';
   ```

   Further admins are added from the console (Users → make admin).
5. **Password-reset emails**, once the mailbox exists: Supabase dashboard → Authentication → Emails → SMTP settings: host `smtp.gmail.com`, port `465`, the Gmail address and its app password, sender name `شارع الغالي`.

## 3. The admin console on Netlify

1. Sign up at <https://app.netlify.com> with the GitHub account that owns the repository.
2. Add new site → Import an existing project → GitHub → `alghali-app`.
3. Settings: **Base directory** `apps/admin`, **Build command** `pnpm build`, **Publish directory** `apps/admin/.next`. Netlify runs Next.js through its own adapter, which supports what the console uses (Server Actions, Cache Components, the sign-in proxy).
4. Environment variables (Site configuration → Environment variables):
   - `NEXT_PUBLIC_SUPABASE_URL` = the live project URL
   - `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` = the live publishable key

   Never the secret key: the console works as the signed-in admin (D-079).
5. Deploy. The address is `https://<name>.netlify.app`; rename the site to something short in Site configuration. Every push to `main` deploys again (about 15 of the free plan's 300 monthly credits each; the plan pauses the site until the next month if they run out, so don't push dozens of times a month).
6. In Supabase → Authentication → URL configuration, set the **Site URL** to the Netlify address.

The download page is `https://<name>.netlify.app/ar/download` (English: `/en/download`). It needs no sign-in.

## 4. Publishing the Android apps

```sh
# after bumping `version:` in apps/<app>/pubspec.yaml and the build constant in
# apps/<app>/lib/state/push.dart to the same +N
pnpm release:apk buyer live
pnpm release:apk partner live
```

Each run builds the app against the live project, signed with the release key (D-134), as two
files — one for 32-bit and one for 64-bit phones, same version number (D-135) — uploads them,
and updates `latest_app_versions`. Phones with an older build see "a new version is available";
add `--required` when an old build must stop working (it then shows only the update screen).

Share the download page link, not the APK files: the page picks the right file for the phone
and explains Android's "unknown apps" prompt.

## 5. Backups

1. GitHub → the repository → Settings → Secrets and variables → Actions → New repository secret:
   - `LIVE_DB_URL` = the live session pooler URL (with the database password)
   - `BACKUP_PASSPHRASE` = the owner's backup passphrase
2. Actions → Nightly backup → Run workflow, once, to check it works. From then on it runs at 02:30 Khartoum time; each run's file is under the run's *Artifacts* for 30 days.

**Restoring** (into a new or emptied project):

```sh
gpg -d alghali-live-YYYY-MM-DD.tar.gz.gpg | tar -xz     # asks for the passphrase
psql "$NEW_DB_URL" -f backup/roles.sql
psql "$NEW_DB_URL" -f backup/schema.sql
psql "$NEW_DB_URL" -c 'set session_replication_role = replica' -f backup/data.sql
```

The dump holds the database, the users' accounts included. Photos, receipts and voice notes
in Storage are not in it.

## 6. Day to day

| Change | What to run |
|---|---|
| A new migration | `pnpm db:push:test`, `pnpm check`, then `pnpm db:push:dev` and `pnpm db:push:live` |
| A changed Edge Function | `pnpm functions:deploy:live` (after dev and test) |
| A new app version | bump the version, `pnpm release:apk <app> live` |
| The admin console | push to `main`; Netlify deploys it |
| Alert wording, fees, the street | the admin console, no deploy |

Before any of these, `pnpm check` must pass, and for bigger changes `pnpm journey:e2e` (the
acceptance journey on an emulator against alghali-test).
