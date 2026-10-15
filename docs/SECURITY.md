# Security review (M7)

The checklist from PLAN §2 M7 — row level security on every table, every function's
permission check, sign-in and sign-up abuse, upload checks — plus secrets, the admin website,
money and dependencies. Each line says how it is enforced and which test keeps it that way.
Reviewed 2026-10-15 against migrations up to `20261017100000_admin_tools`.

## Checklist

| # | Area | How it is enforced | Kept by |
|---|---|---|---|
| 1 | Every table has row level security | RLS on every `public` table; policies use `(select auth.uid())` and the role helpers | `tests/db/security.test.ts` (RLS on every table) |
| 2 | What the apps may write directly | `anon` writes nothing; signed-in users write only to an allow-list of tables (cart, garage, addresses, chat messages, hours, time off; catalogue and alert wording for admins) | security tests (allow-lists) |
| 3 | What the apps may call | `anon` and signed-in users can execute only allow-listed functions; everything else is revoked | security tests (allow-lists) |
| 4 | Every callable function checks the caller | Each one calls a `require_*` helper, a role or membership helper, or `auth.uid()`; the 13 that don't only read public data (catalogue, search, settings) and are listed with the reason | security tests (**new in M7**: caller check, every `require_*` helper reads the caller, every `admin_*` function requires an admin) |
| 5 | No back door through views or search paths | No view skips RLS; every `security definer` function pins an empty `search_path` | security tests |
| 6 | Each party sees only its own data | Buyers their orders and fittings; a shop only its part of an order (D-086); technicians' home and phone hidden until a job is accepted (D-104); live location only while on the way, deleted at check-in | per-feature tests in `tests/db` and `tests/api` |
| 7 | Password guessing and mass sign-ups | Password rule 8+ characters with letters and digits (D-073); Supabase limits sign-in and sign-up to **30 per 5 minutes per IP address**, token refresh to 150 (pinned in `infra/hosted/supabase/config.toml`, matched on the projects) | `tests/api/m1.test.ts` (password rule); `pnpm hosted:diff` |
| 8 | The admin console | Only `ADMIN` accounts stay signed in; every page and every Server Action checks the admin on the server before touching data; the database checks again; every admin change is audited; temporary passwords go through an Edge Function so the secret key never reaches the website (D-080) | `apps/admin/src/lib/actions/actions.test.ts` (**new**: every action checks the admin), `admin_*` security test |
| 9 | Browser protections on the console | Can't be framed (`X-Frame-Options`, `frame-ancestors`), no type sniffing, no referrer leaks, camera/microphone/location off, HSTS, no `X-Powered-By`; the session cookies are **httpOnly** (the browser never talks to Supabase); no raw HTML is rendered | `apps/admin/e2e/pages.spec.ts` (**new**: headers and cookies) |
| 10 | Uploads | Every bucket has a size limit and a MIME allow-list; **no bucket takes HTML, SVG, XML or scripts**; private buckets only under the owner's folder (receipts, request photos, voice notes, job photos, stock sheets), checked by storage policies; admins see receipts through 15-minute signed links | security tests (**new**: no web-page types), `tests/api/m1.test.ts`, `m3.test.ts` (strangers refused) |
| 11 | Edge Functions | `notify-dispatch` needs the token kept in Vault; `inventory-import` acts as the caller; `admin-set-password` checks the admin with the caller's own token and never logs the password; `booking-slots` reads only what anyone may see | `tests/api/m3.test.ts`, `m1.test.ts` |
| 12 | Secrets | No secret key in any app or the console (`pnpm env:sync` copies only publishable values); `.env` and `secrets/` are ignored by Git; the whole Git history was scanned in M7 and holds only placeholders and test values | `tests/infra/env.test.ts` |
| 13 | Money can't be bent | Double-entry ledger, append-only (`APPEND_ONLY`); every journal balances; status changes only along the transition tables; one Bankak transaction number pays one thing (`DUPLICATE_TXN`); creating calls take idempotency keys; manual corrections need a reason and are audited (D-130) | `tests/db/ledger`, `state-machines`, `payments`, `booking-money` |
| 14 | Dependencies | `pnpm audit --prod`: no known vulnerabilities (the shadcn CLI, which pulled in a vulnerable `braces`, moved to build-time dependencies) | run `pnpm audit --prod` before each release |
| 15 | Recovery | Nightly encrypted database backup (D-136); the release signing key and Firebase keys backed up by the owner (DEPLOY §1) | `.github/workflows/backup.yml` |

## Risks that remain, and what to do about them

- **No CAPTCHA and no email confirmation.** Someone could create many fake accounts, up to the
  IP rate limit, and fake buyers could place cash orders that shops then refuse. Admins can
  suspend accounts and shops can refuse orders. If it happens: turn on Supabase's CAPTCHA
  (Cloudflare Turnstile, free), which needs a small change in both apps' sign-up screens.
- **Sudan's mobile networks put many phones behind one IP address.** At busy times real users
  could hit the 30-per-5-minutes sign-in limit together. Raise `sign_in_sign_ups` in the hosted
  config if users report "too many attempts".
- **No lock-out per account.** Guessing is limited per IP address, not per account (Supabase
  has no per-account lock-out). The password rule and the IP limit make guessing slow; admins
  should use long passwords.
- **Uploaded files are checked by declared type, not content.** A non-image renamed `.jpg` can be
  stored, but it is always served as an image or download, never as a page, so it can't run in
  a browser.
- **The console's Content-Security-Policy doesn't restrict scripts.** Next.js needs inline
  scripts, and a nonce-based policy would make every page dynamic. React escapes all text, and
  the session cookies are httpOnly, which limits what an injected script could do.
- **Storage files aren't in the nightly backup.** Losing the live project would lose photos,
  receipts and voice notes (the database, accounts included, is backed up).
- **The Firebase key pasted in chat on 2026-10-14 is still valid** until the owner deletes it
  (DEPLOY §1). It can send push alerts to the apps' users.

## Sign-off

- [x] Checks 1–15 above, with the tests named, pass (`pnpm check`, CI).
- [ ] The owner has replaced the Firebase key and backed up `secrets/` (DEPLOY §1).
