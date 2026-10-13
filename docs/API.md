# API

The backend is Supabase. Clients **read** tables through PostgREST under row level security and **change things** by calling Postgres functions (RPC) or Edge Functions. This file lists what exists today; [PLAN.md §4](PLAN.md) lists what's coming. Dart wrappers live in `packages/core/lib/src/backend/` (`AuthRepository`, `CatalogueRepository`, `GarageRepository`, `ShopRepository`); TypeScript types in `packages/db-types` (`pnpm db:types`).

## Conventions

- **Errors** (D-069). A failed RPC returns the code as the message, and the SQLSTATE sets the HTTP status:

  | SQLSTATE | HTTP | Codes |
  |---|---|---|
  | `42501` | 401 / 403 | `NOT_AUTHENTICATED`, `FORBIDDEN`, `SHOP_NOT_ACTIVE` |
  | `P0002` | 404 | `NOT_FOUND`, `USER_NOT_FOUND`, `SHOP_NOT_FOUND`, `ZONE_NOT_FOUND`, `LISTING_NOT_FOUND`, `PART_NOT_FOUND`, `UNKNOWN_SETTING`, `NOT_A_MEMBER` |
  | `PT409` | 409 | `VERSION_CONFLICT` (detail = server version), `SKU_TAKEN`, `ALREADY_MEMBER`, `APPLICATION_PENDING`, `INVALID_TRANSITION` |
  | `22023` | 400 | validation: `INVALID_PHONE`, `INVALID_WHATSAPP`, `INVALID_LOCALE`, `NAME_TOO_LONG`, `INVALID_SETTING`, `INVALID_OPENING_HOURS`, `INVALID_IMAGE_KEY`, `PRICE_REQUIRED`, `INVALID_QTY`, `STOCK_BELOW_RESERVED`, `PART_REQUIRED`, `PART_NAME_REQUIRED`, `PART_NAME_INVALID`, `CATEGORY_NOT_FOUND`, `TOO_MANY_IMAGES`, `TOO_MANY_ROWS`, `TOO_MANY_SHOPS`, `TOO_MANY_STAFF`, `GARAGE_FULL`, `ADDRESS_BOOK_FULL`, `REASON_REQUIRED`, `CANNOT_REVOKE_OWN_ADMIN`, `CANNOT_REVOKE_BUYER`, `CANNOT_REMOVE_OWNER`, `IDEMPOTENCY_KEY_REUSED`, `INVALID_SORT`, `INVALID_VALUE` |

  In Dart every failure becomes a `BackendException(code)`. Auth errors keep Supabase's code in upper case (`INVALID_CREDENTIALS`, `USER_ALREADY_EXISTS`, `WEAK_PASSWORD`, `OVER_REQUEST_RATE_LIMIT`). A dropped connection is `OFFLINE`.
- **Idempotency.** Mutating RPCs that create things take `p_idem uuid`. A replay with the same key returns the first result without doing anything again. Reusing a key for a different call is `IDEMPOTENCY_KEY_REUSED`. Keys are kept 7 days. Naturally repeatable calls (profile edits, status changes) don't take one.
- **Money** is whole SDG (`bigint`; JSON numbers). **Times** are UTC ISO-8601. **Phones** are stored in E.164 (`+2499…`); any Sudanese format is accepted on input.
- **Weekday numbers** are 0 = Sunday … 6 = Saturday, in Khartoum time. **Opening hours** are `{"0": [[480, 1200]], …}`: minutes after midnight, windows in order, a missing day = closed.

## RPC

### Anyone (signed in or not)

| Function | Returns |
|---|---|
| `ping()` | `{ok, server_time}` |
| `public_settings()` | Buyer-visible settings: fees, fee bands, Bankak account, windows, `booking_lookahead_days`, `latest_app_versions` (`{buyer|partner: {latest_build, min_build, apk_url}}`), `support_phone`, `support_whatsapp` |
| `catalogue_snapshot(p_since?)` | `{server_time, full, makes, models, variants, job_types, categories, markets, streets, zones, shops}` for the offline cache. With `p_since`, only rows changed since then, including deactivated ones (`is_active: false`) and shops no longer approved (`{id, status}`). Send `server_time` back next time. |
| `search_parts(p_q, p_variant_id, p_category_id, p_only_fits, p_conditions[], p_price_max, p_shop_id, p_in_stock_only=true, p_deals_only, p_sort, p_limit=30, p_offset)` | One row per part: `part_id, category_id, name_ar/en, installable, std_job_minutes, is_verified, fit (FITS / CHECK_FITMENT / null), from_sdg, shop_count, conditions[], best_warranty_days, max_discount_percent, image_key, listings (≤ 5 offers, cheapest first), rank, total_count`. Parts whose fitment leaves out the given car are hidden. `p_sort`: `relevance` (fits first), `price_low`, `price_high`, `rating`, `discount`, `newest`. Category filters include child categories. |
| `part_detail(p_part_id, p_variant_id?)` | `{part: {…, fit, job_type_code, std_job_minutes, fitment_model_ids, fitment_note_ar/en}, listings: [{…, images, shop: {name, zone_id, plot_no, side, landmark, pos_m, verified, rating, phone, whatsapp, open_now}}]}`, in stock first, then cheapest. A merged part answers with the part it was merged into. |

### Signed-in users

| Function | Who | Does |
|---|---|---|
| `me()` | self | `{profile, roles[], shops: [{shop_id, role, status, status_reason, name_ar/en}]}` |
| `update_profile(p_display_name?, p_phone?, p_locale?, p_data_saver?)` | self | Null = unchanged; empty phone clears it. Returns the profile. |
| `register_device(p_app, p_platform, p_fcm_token, p_app_build?, p_locale?)` | self | Upserts by token (a phone that signs in to another account moves over). |
| `unregister_device(p_fcm_token)` | self | Call on sign-out. |
| `apply_as_shop(p_name_ar, p_zone_id, p_phone, p_name_en?, p_plot_no?, p_side?, p_landmark_ar?, p_whatsapp?, p_lat?, p_lng?, p_about_ar?, p_opening_hours?, p_category_ids[]?, p_make_ids[]?, p_idem?)` | any user | Creates a `PENDING` shop the caller owns. One pending application at a time; 3 shops at most. |
| `shop_update_profile(p_shop_id, p_patch)` | owner, admin | Changes only the keys present: `name_ar, name_en, zone_id, plot_no, side, landmark_ar/en, about_ar/en, phone, whatsapp, lat, lng, opening_hours, storefront_key, category_ids, make_ids`; admins also `pos_m`. |
| `shop_staff(p_shop_id)` | members | `user_id, role, email, display_name, added_at`. |
| `shop_add_staff(p_shop_id, p_email)` | owner | The colleague must have an account. Gets `SHOP_STAFF` once the shop is approved. |
| `shop_remove_staff(p_shop_id, p_user_id)` | owner | |
| `shop_listings(p_shop_id, p_q?, p_limit?, p_offset?)` | members | The stock list (archived ones left out); `p_q` searches part names and SKUs. |
| `shop_upsert_listing(p_shop_id, p_condition, p_stock_qty, p_price_sdg?, p_price_on_request?, p_warranty_days?, p_brand?, p_sku?, p_note_ar?, p_is_active?, p_part_id?, p_new_part?, p_listing_id?, p_version?, p_idem?)` | members | Create or edit (D-067). `p_new_part = {name_ar, name_en?, category_id, model_ids?, oem_numbers?}` makes or edits the shop's own part. Edits need `p_version`. A price cut sets `was_sdg` (shown as a deal for 14 days) and is recorded in the price history. |
| `shop_bulk_update(p_shop_id, p_items, p_idem?)` | members | `p_items = [{listing_id, version, price_sdg?, stock_qty?, is_active?}]` (≤ 500). Returns `{results: [{listing_id, ok, error, version, current}]}`; each item succeeds or fails on its own. |
| `shop_archive_listing(p_shop_id, p_listing_id)` | members | Hides it for good. |
| `shop_set_listing_images(p_shop_id, p_listing_id, p_base_keys[])` | members | ≤ 6 keys, each `shops/{shop_id}/listings/{uuid}`, uploaded first. |
| `shop_import_rows(p_shop_id, p_rows, p_dry_run?, p_file_name?, p_idem?)` | members | Called by `inventory-import`; see below. |
| `suggest_parts(p_q, p_shop_id?, p_category_id?, p_limit?)` | members | Verified parts and the shop's own, for quick-listing suggestions. |

Shops may write while `PENDING` (to prepare stock) or `APPROVED`; a `SUSPENDED` or `REJECTED` shop gets `SHOP_NOT_ACTIVE`.

### Admins

| Function | Does |
|---|---|
| `admin_settings()` / `admin_update_setting(p_key, p_value)` | Read all settings / change one (shape checked per key; audited). |
| `admin_grant_role(p_user_id, p_role)` / `admin_revoke_role(…)` | Audited. An admin can't drop their own `ADMIN`; nobody loses `BUYER`. |
| `admin_search_users(p_q, p_limit?)` | By email, name or phone. |
| `admin_set_shop_status(p_shop_id, p_status, p_reason?)` | `PENDING → APPROVED/REJECTED`, `APPROVED ⇄ SUSPENDED`, `REJECTED → APPROVED`. A reason is required to reject or suspend. Approval grants the shop roles and places the shop mid-zone if `pos_m` is unset. |
| `admin_verify_shop(p_shop_id, p_verified)` | The "verified" badge. |
| `admin_merge_parts(p_from, p_into)` | Moves listings onto the target part and retires the duplicate. |

Admins also write the catalogue and street tables directly (D-068); every change is audited.

## Tables

| Table | Read | Write directly |
|---|---|---|
| `vehicle_makes`, `vehicle_models`, `vehicle_variants`, `job_types`, `part_categories`, `parts`, `part_fitments`, `search_synonyms` | anyone (active rows; admins see all) | admins |
| `markets`, `streets`, `zones` | anyone (active rows) | admins |
| `shops`, `shop_specialities` | anyone: approved shops; members and admins: their own / all | — (RPCs) |
| `shop_members` | members of the same shop, admins | — |
| `listings`, `listing_images` | anyone: active listings of approved shops; members: their shop's | — |
| `listing_price_history`, `import_jobs` | members, admins | — |
| `profiles`, `user_roles` | self, admins | — |
| `devices` | self | — |
| `garage_vehicles` | self | self (one default car, ≤ 10, VIN cleaned up) |
| `addresses` | self | self (`label, description_ar, lat, lng, is_default`; ≤ 10) |
| `audit_log` | admins | — |
| `app_settings`, `idempotency_keys`, `part_search_docs`, `search_synonym_terms` | — | — |

## Storage

| Bucket | Public | Limit | Who writes |
|---|---|---|---|
| `media-public` | yes | 5 MB, webp/jpeg/png | shop members under `shops/{shop_id}/…`; a user under `users/{uid}/…` |
| `imports` | no | 5 MB, xlsx/xls/csv | shop members under `{shop_id}/…` (and read their own) |
| `templates` | yes | 5 MB | admins (`pnpm templates:upload <dev|test>`) — `templates/inventory-template.xlsx` |
| `app-releases` | yes | 50 MB, APK | admins (D-058) |
| `receipts`, `booking-photos`, `request-photos`, `voice-notes` | no | 5 MB / 2 MB | policies arrive with M2/M3 |

## Edge Functions

### `inventory-import`
`POST /functions/v1/inventory-import` with the user's session; optional `Idempotency-Key: <uuid>`.

```json
{ "shop_id": "…", "file_key": "{shop_id}/….xlsx", "dry_run": false, "file_name": "stock.xlsx" }
```

Reads the first sheet of the uploaded file (`imports` bucket) and imports it through `shop_import_rows`, all as the caller. The template is `supabase/templates/inventory-template.xlsx`. What the reader accepts is in D-078.

Response: `{total, created, updated, failed, dry_run, job_id?, errors: [{row, code, column?}], warnings: [{row, code, value}]}`. `row` is the Excel row number.
- Row codes: `NAME_REQUIRED`, `CATEGORY_REQUIRED`, `CATEGORY_NOT_FOUND`, `CONDITION_REQUIRED`, `INVALID_CONDITION`, `INVALID_PRICE`, `PRICE_REQUIRED`, `INVALID_QTY`, `INVALID_WARRANTY`, `DUPLICATE_SKU`, `STOCK_BELOW_RESERVED`, `INVALID_VALUE`.
- Warning: `MODEL_NOT_FOUND` (the row is imported without that car).
- Whole-file errors: 401 `NOT_AUTHENTICATED`, 404 `FILE_NOT_FOUND`, 413 `FILE_TOO_LARGE`, 422 `HEADER_NOT_FOUND` / `TOO_MANY_ROWS` (> 2000) / `UNREADABLE_FILE` / `EMPTY_FILE`.

Example (Dart):

```dart
final report = await ref.read(shopRepositoryProvider).importStock(shopId, bytes, 'stock.xlsx');
if (report.failed > 0) showRowErrors(report.errors);
```
