# Build: Alghali Street Auto Parts & Installation Platform

You are the lead engineer on a new product. Read this whole brief before writing any code. Then follow the "How to work" section exactly.

---

## 1. Product context

Alghali Street (شارع الغالي) is a market street in Sudan where every car accessories and spare parts shop sits along one road. We are building an **independent platform** (not owned by any shop) with two jobs:

1. **Marketplace** — buyers browse and buy parts and accessories from the street's shops.
2. **Installation booking** — buyers book a vetted technician to fit the part, either at a **workshop bay on the street** or at the **buyer's location** (home/work).

The platform earns a **commission on part sales** and a **fee on each installation booking**.

Users:
- **Buyer** — car owner, Arabic speaker, usually on a low-end Android phone with unreliable data.
- **Shop owner / shop staff** — lists stock, handles orders. Often not tech-savvy.
- **Technician** — freelance or employed by a shop; does jobs at a bay, mobile, or both.
- **Admin** — platform staff: approve partners, confirm payments, manage catalogue, handle disputes.

### Non-negotiable constraints
- **Arabic first, full RTL.** English is the second language. No hard-coded user-facing strings.
- **Offline-tolerant.** Catalogue, garage, orders and the street map are cached. Actions taken offline go to an outbox and sync later.
- **Light on data.** Compressed thumbnails by default, full images on tap, small app size.
- **Payments at launch: Bankak (mBOK) and cash only.** There is no Bankak merchant API. Bankak works as a **confirmed transfer**: the buyer transfers to the platform account with an order reference, uploads the receipt screenshot and/or transaction number, and an admin confirms it against the bank statement. Never mark an order paid from the screenshot alone.
- **SMS as a fallback** for OTP and key alerts, because push is unreliable.
- **Prices are in SDG** and change often; shops need fast bulk price updates, the cart re-checks prices before payment, and a paid order locks its price.

---

## 2. Tech stack (use this unless you find a blocking problem — if so, stop and tell me)

| Layer | Choice |
|---|---|
| Monorepo | pnpm workspaces for JS/TS + a Dart workspace for Flutter |
| Backend | NestJS (TypeScript, strict), REST, OpenAPI via `@nestjs/swagger`, modular monolith |
| ORM / DB | Prisma + PostgreSQL 16 with PostGIS and `btree_gist` |
| Cache / jobs | Redis + BullMQ |
| Search | Meilisearch (Arabic normalisation + synonyms) |
| Files | S3-compatible storage (MinIO locally), image resizing on upload (sharp) |
| Buyer app | Flutter (Android first, iOS-ready), Riverpod, go_router, Dio, Drift (SQLite), `flutter_localizations` + ARB files |
| Partner app | Flutter, same stack, separate app |
| Shared Flutter code | `packages/core` — models, generated API client, theme, RTL widgets, outbox/sync engine |
| Admin | Next.js (App Router, TypeScript), Tailwind, shadcn/ui, Arabic + English with RTL |
| Notifications | Provider interfaces for Push (FCM), SMS, WhatsApp — ship with console/log stubs; real providers later |
| Local dev | docker-compose: postgres+postgis, redis, meilisearch, minio, mailpit (optional) |
| Quality | ESLint + Prettier, Jest (unit + e2e with Testcontainers or docker DB), `flutter analyze`, `flutter test`, GitHub Actions CI |
| Monitoring hooks | Sentry SDK wired but disabled without a DSN |

### Repo layout
```
/backend                 NestJS API
/apps/buyer              Flutter buyer app
/apps/partner            Flutter shop + technician app
/apps/admin              Next.js admin panel
/packages/core           Shared Dart package
/packages/api-client     OpenAPI-generated TS client (admin) — Dart client generated into packages/core
/infra                   docker-compose, seed data, scripts
/docs                    PLAN.md, ARCHITECTURE.md, API.md, DECISIONS.md
```

---

## 3. Backend modules

Each module owns its tables and exposes services only through its public interface.

1. **identity** — phone + OTP login (SMS provider interface), JWT access + refresh tokens, roles: `BUYER`, `SHOP_OWNER`, `SHOP_STAFF`, `TECHNICIAN`, `ADMIN`. One user can hold several roles. Rate-limit OTP requests.
2. **catalogue** — vehicle makes/models/year ranges/engines; part categories (tree); parts with Arabic + English names and OEM numbers; fitment (part ↔ vehicle). Job type per category (e.g. lighting, AC, electrical, suspension, audio) and a **standard job duration** per part/category.
3. **shops** — shop profile, street zone, plot number, side of street, landmark (Arabic text), verified pin (PostGIS point), storefront photo, opening hours, specialities, `verified` flag, staff accounts.
4. **inventory** — listings: shop, part, condition (`NEW_OEM`, `NEW_AFTERMARKET`, `USED`), price SDG, stock qty, warranty days, photos, `price_on_request`. Bulk price/stock update endpoint. Excel (xlsx) import with a downloadable template.
5. **requests** — buyer "photo requests" (photo of old part or VIN plate + car + note); shops reply with offers (price, photo, condition) that buyers can add to cart.
6. **orders** — cart (multi-shop), checkout splits into one `SubOrder` per shop. Fulfilment: `PICKUP`, `DELIVERY`, `TO_TECHNICIAN`. Price re-validation at checkout; price lock once paid. Returns.
7. **payments & ledger** — Bankak receipts (image + transaction no.), admin confirmation queue, cash collection records, double-entry-style `LedgerEntry` for every money movement (sale, commission, booking fee, deposit, travel fee, refund, payout). Commission on cash orders is netted from the shop's next payout.
8. **bookings** — technicians, skills (job types × car makes), work mode (`BAY`, `MOBILE`, `BOTH`), home bay, service radius, weekly availability rules, time off, slot computation, slot holds, booking lifecycle, job code, before/after photos.
9. **notifications** — one dispatcher that chooses push / SMS / WhatsApp per message type and user state; templates in Arabic + English; retries via BullMQ.
10. **reviews & disputes** — separate ratings for shop and technician per order/booking; dispute tickets handled by admin.
11. **settings** — admin-editable config (see §5) stored in DB, cached.

### Core state machines (implement as explicit enums + guarded transitions with tests)
- **SubOrder:** `PENDING_PAYMENT → PAYMENT_REVIEW → CONFIRMED → READY → (PICKED_UP | OUT_FOR_DELIVERY → DELIVERED | HANDED_TO_TECHNICIAN) → COMPLETED`; side exits `CANCELLED`, `REJECTED_BY_SHOP`, `RETURN_REQUESTED → RETURNED`. Cash orders skip `PAYMENT_REVIEW`.
- **Payment:** `AWAITING_TRANSFER → RECEIPT_SUBMITTED → CONFIRMED | REJECTED`; cash: `DUE → COLLECTED`.
- **Booking:** `HELD → PENDING_TECH_ACCEPT → ACCEPTED → EN_ROUTE (mobile only) → IN_PROGRESS → COMPLETED`; side exits `TECH_DECLINED/TIMEOUT → reassigned`, `CANCELLED_BY_BUYER`, `CANCELLED_BY_TECH`, `PART_DOES_NOT_FIT → return flow`.

---

## 4. Booking rules (the hardest part — get these right and test them heavily)

- Booking can be added in checkout ("Add installation" per part), from a past order, or for a part bought elsewhere.
- **Location first:** `BAY` (no travel fee; part goes from shop to bay) or `CUSTOMER_LOCATION` (pin + written description; travel fee by distance band from the street; only `MOBILE`/`BOTH` technicians whose radius covers the pin).
- **Technician list** filtered by job type of the part(s), car make, location coverage, and availability in the next N days; sorted by a score of rating, completed jobs and distance. Default option "Any available technician" auto-assigns the best match.
- **Slots** = weekly availability − time off − existing bookings − travel buffer between mobile jobs. Slot length = sum of standard job durations of the parts. Earliest slot = part ready time + configurable buffer.
- **Hold:** the chosen slot is held in Redis for `slot_hold_minutes` (default 10) during payment.
- **No double booking:** enforce in Postgres with an `EXCLUDE USING gist (technician_id WITH =, tstzrange(start_at, end_at) WITH &&)` constraint on active bookings (write it as a raw SQL Prisma migration). Concurrency test required.
- **Accept timeout:** technician must accept within `tech_accept_timeout_minutes`; otherwise offer to next match and notify buyer.
- **Deposit:** mobile bookings paid in cash require a Bankak deposit of `mobile_deposit_sdg` (configurable, can be set to 0). Bay bookings can be fully cash.
- **Reminders:** day before and 1 hour before (push + SMS).
- **Job day:** check-in, before/after photos, closed by the buyer's 4-digit job code. Technician location shared only while `EN_ROUTE`.
- **Cancellation:** free until `cancel_cutoff_hours` before start (default 6); after that the deposit covers travel. Technician cancellation → next match or full refund. "Part does not fit" at check-in → return flow, buyer pays only travel fee.

---

## 5. Configurable settings (seed with defaults, editable in admin)
`commission_percent`, `booking_fee_sdg`, `mobile_deposit_sdg`, `slot_hold_minutes`, `tech_accept_timeout_minutes`, `cancel_cutoff_hours`, `part_ready_buffer_minutes`, `travel_fee_bands` (JSON: km → SDG), `delivery_fee_bands`, `bankak_account_name`, `bankak_account_number`, `payout_schedule`.

---

## 6. Location model (single street)

- A `Market` has `Street`s; a `Street` has ordered `Zone`s; a `Shop` belongs to a zone with a plot number, side, landmark and pin. Do not hard-code Alghali Street — seed it as data.
- **Street strip view** in the buyer app: a custom-drawn horizontal strip (Flutter CustomPainter) with zones and shop dots, from cached data; tap a dot → shop page. A real map (OpenStreetMap tiles via flutter_map) is only a fallback.
- For multi-shop pickup, return the stops ordered along the street.
- GPS is used only for the buyer's delivery/installation address, distance bands, and technician en-route sharing. Directions open Google Maps by deep link.

---

## 7. Search
- Meilisearch index of listings joined with part, category, shop, and fitment vehicle IDs.
- Arabic normalisation on index and query: unify أ/إ/آ→ا, ة→ه, ى→ي, strip tashkeel and tatweel. Synonym list file (Arabic ↔ English ↔ local terms) editable by admin.
- Filter by selected garage vehicle → results tagged `FITS` or `CHECK_FITMENT` (no fitment data).
- Keep Postgres as source of truth; sync index via BullMQ jobs.

---

## 8. Apps — screens for MVP

**Buyer app:** onboarding + language pick (Arabic default), phone/OTP login, My Garage (add/select car), home (categories, deals for my car), search + filters, listing detail (compare same part across shops), shop page, street strip, photo request + offers inbox, cart (grouped by shop, add installation per part), installation booking flow (location → technician → slot), checkout (Bankak instructions with account number + order reference + receipt upload, or cash), order tracking, booking tracking (job code shown), chat with shop (text + voice notes; can be basic polling for MVP), WhatsApp/call buttons, reviews, profile/settings (language, data saver).

**Partner app (role-based home):**
- Shop: onboarding, profile, quick listing (photo → category → fitment → price/qty; drafts offline), stock/price quick edit + bulk edit, photo-request inbox, orders (accept/reject/ready/hand over), cash to collect, statements/payouts, staff accounts, simple insights.
- Technician: profile + skills + work mode + radius, weekly availability + time off + quick block, job offers (accept/decline with countdown), job detail (parts, car, address, directions), check-in, photos, job code entry, earnings.

**Admin (web):** login, approval queues (shops, technicians), Bankak payment confirmation queue (receipt image beside order + amount + reference, confirm/reject), cash reconciliation, catalogue + fitment management, synonyms, orders & bookings browser, disputes, settings, payouts, basic reports.

### App-wide requirements
- All strings in ARB / i18n files, Arabic and English complete. Test every screen in RTL.
- Offline outbox in `packages/core`: queued mutations with idempotency keys; backend accepts `Idempotency-Key` header on all POST/PATCH.
- Images: upload compressed client-side; backend stores original + 3 sizes.
- Large tap targets, minimal steps; support Android 8+.

---

## 9. Seed data
Seed realistic dev data: one market, Alghali Street with 3–4 zones (placeholder names, mark them as `TODO: confirm local names`), 15 shops, ~300 listings across common categories, vehicles for common makes in Sudan (e.g. Toyota Hilux, Land Cruiser, Corolla; Hyundai; Kia; Nissan), 10 technicians with mixed modes, one admin. All names in Arabic with English translations.

---

## 10. Out of scope for MVP (design so they can be added, do not build)
Card/USD payments, automatic Bankak statement matching, platform-run delivery fleet, pickup counter, price-drop alerts, service reminders, fleet accounts, multiple cities.

---

## 11. How to work

1. **Plan first.** Before coding, write `/docs/PLAN.md` with: milestones, the Prisma schema draft, the API endpoint list, and anything in this brief you think is wrong or risky. Then **stop and show me the plan**, plus at most 5 questions that would change the design. Where something is unclear and not worth asking, choose a sensible default and log it in `/docs/DECISIONS.md`.
2. **Build milestone by milestone.** After each milestone: all tests and linters pass, `docker compose up` + one command starts everything, update docs, commit with a clear message, and give me a short summary (what's done, how to run it, what's next). Wait for my go-ahead before the next milestone.
3. **Milestones:**
   - **M0** Monorepo scaffold, docker-compose, CI, lint/test setup, empty apps that build and run in Arabic RTL.
   - **M1** Backend: identity (OTP stub), catalogue + fitment, shops, inventory, settings, seed data, search indexing. OpenAPI + generated clients.
   - **M2** Backend: orders, payments (Bankak receipt flow + admin confirm, cash), ledger, photo requests.
   - **M3** Backend: technicians, availability, slot engine, holds, exclusion constraint, booking lifecycle, timeouts, reminders, notifications dispatcher, reviews, disputes.
   - **M4** Buyer app end-to-end against the real API (incl. offline cache + outbox).
   - **M5** Partner app (shop + technician).
   - **M6** Admin panel.
   - **M7** Hardening: e2e test of the full customer journey (below), performance on a low-end Android emulator, security review (authz on every endpoint, OTP abuse, file upload checks), README for deployment.
4. **Testing bar:** unit tests for every state machine and the slot engine; e2e tests for checkout, payment confirmation and booking; a concurrency test proving two buyers cannot book the same technician slot.
5. **Code standards:** strict TypeScript, no `any`; DTO validation with class-validator; authorization guards per role and per resource ownership; money as integer SDG (no floats); all times stored UTC, displayed in `Africa/Khartoum`.
6. Do not invent real third-party credentials. Put every secret in `.env.example` with placeholders.

---

## 12. Acceptance journey (must pass end-to-end in M7)

1. Ahmed logs in with phone + OTP and adds his Toyota Hilux to My Garage.
2. He searches "لمبات" and sees only bulbs that fit, from several shops, with price, condition and warranty.
3. He adds one set to the cart and taps "Add installation" → "At my location" → picks a lighting technician → picks Thursday 4 pm (slot held).
4. He chooses Bankak, sees the account number and his order reference, uploads a receipt. Order shows "Payment being checked".
5. Admin confirms the payment. Ahmed gets push + SMS (stub logs). The shop marks the part ready and hands it to the technician. The technician accepts the job.
6. Reminders fire the day before and 1 hour before.
7. The technician goes en route, checks in, uploads before/after photos, enters Ahmed's 4-digit code; the booking completes.
8. Ahmed rates the shop and the technician. Ledger shows the sale, commission, booking fee and pending payouts correctly.
9. Variant: the same journey with "Cash to technician" — only the mobile deposit goes through Bankak; the rest is recorded as cash collected, and commission is netted from the shop's payout.

Start with step 1 of "How to work": read, plan, and show me `/docs/PLAN.md`.
