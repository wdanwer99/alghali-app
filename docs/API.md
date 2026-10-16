# API

The backend is Supabase. Clients **read** tables through PostgREST under row level security and **change things** by calling Postgres functions (RPC) or Edge Functions. This file lists what exists today; [PLAN.md §4](PLAN.md) lists what's coming. Dart wrappers live in `packages/core/lib/src/backend/` (`AuthRepository`, `CatalogueRepository`, `GarageRepository`, `ShopRepository`, `OrdersRepository`, `RequestsRepository`, `ChatRepository`, `NotificationsRepository`, `BookingsRepository`, `TechnicianRepository`); TypeScript types in `packages/db-types` (`pnpm db:types`).

## Conventions

- **Errors** (D-069). A failed RPC returns the code as the message, and the SQLSTATE sets the HTTP status:

  | SQLSTATE | HTTP | Codes |
  |---|---|---|
  | `42501` | 401 / 403 | `NOT_AUTHENTICATED`, `FORBIDDEN`, `SHOP_NOT_ACTIVE`, `APPEND_ONLY`, `NOT_A_TECHNICIAN`, `TECHNICIAN_NOT_ACTIVE` |
  | `P0002` | 404 | `NOT_FOUND`, `USER_NOT_FOUND`, `SHOP_NOT_FOUND`, `ZONE_NOT_FOUND`, `LISTING_NOT_FOUND`, `PART_NOT_FOUND`, `UNKNOWN_SETTING`, `NOT_A_MEMBER`, `ORDER_NOT_FOUND`, `SUBORDER_NOT_FOUND`, `PAYMENT_NOT_FOUND`, `REFUND_NOT_FOUND`, `RETURN_NOT_FOUND`, `PAYOUT_NOT_FOUND`, `REQUEST_NOT_FOUND`, `OFFER_NOT_FOUND`, `CONVERSATION_NOT_FOUND`, `ADDRESS_NOT_FOUND`, `BOOKING_NOT_FOUND`, `TECHNICIAN_NOT_FOUND`, `ITEM_NOT_FOUND`, `JOB_TYPE_NOT_FOUND`, `MAKE_NOT_FOUND`, `VARIANT_NOT_FOUND`, `REVIEW_NOT_FOUND` |
  | `PT409` | 409 | `VERSION_CONFLICT` (detail = server version), `SKU_TAKEN`, `ALREADY_MEMBER`, `APPLICATION_PENDING`, `INVALID_TRANSITION`, `CART_CHANGED` (detail = the checked lines as JSON), `DUPLICATE_TXN`, `NOT_AWAITING_PAYMENT`, `PAYMENT_EXPIRED`, `NOT_UNDER_REVIEW`, `ALREADY_PAID`, `CANNOT_CANCEL`, `RETURN_EXISTS`, `RETURN_WINDOW_CLOSED`, `NOT_APPROVED`, `PERIOD_ALREADY_PAID`; M3: `SLOT_TAKEN`, `HOLD_EXPIRED`, `ALREADY_APPLIED`, `OFFER_CLOSED`, `TECHNICIAN_NOT_ASSIGNED`, `PARTS_NOT_COLLECTED`, `PARTS_WITH_TECHNICIAN`, `NOT_EN_ROUTE`, `TOO_EARLY`, `JOB_CODE_LOCKED`, `NOT_REVIEWABLE`, `REVIEW_LOCKED`, `DISPUTE_EXISTS`, `DISPUTE_CLOSED` |
  | `22023` | 400 | validation: `INVALID_PHONE`, `INVALID_WHATSAPP`, `INVALID_LOCALE`, `NAME_TOO_LONG`, `INVALID_SETTING`, `INVALID_OPENING_HOURS`, `INVALID_IMAGE_KEY`, `PRICE_REQUIRED`, `INVALID_QTY`, `STOCK_BELOW_RESERVED`, `PART_REQUIRED`, `PART_NAME_REQUIRED`, `PART_NAME_INVALID`, `CATEGORY_NOT_FOUND`, `TOO_MANY_IMAGES`, `TOO_MANY_ROWS`, `TOO_MANY_SHOPS`, `TOO_MANY_STAFF`, `GARAGE_FULL`, `ADDRESS_BOOK_FULL`, `REASON_REQUIRED`, `CANNOT_REVOKE_OWN_ADMIN`, `CANNOT_REVOKE_BUYER`, `CANNOT_REMOVE_OWNER`, `IDEMPOTENCY_KEY_REUSED`, `INVALID_SORT`, `INVALID_VALUE`; from M2: `INVALID_ITEMS`, `CART_FULL`, `INVALID_METHOD`, `INVALID_FULFILMENT`, `ADDRESS_REQUIRED`, `PHONE_REQUIRED`, `DELIVERY_UNAVAILABLE`, `DELIVERY_OUT_OF_RANGE`, `RECEIPT_REQUIRED`, `INVALID_TXN`, `TXN_REQUIRED`, `INVALID_RECEIPT_KEY`, `INVALID_REASON`, `INVALID_ACCOUNT`, `INVALID_REQUEST`, `INVALID_OFFER`, `TOO_MANY_REQUESTS`, `INVALID_VOICE_KEY`; from M3: `ITEMS_REQUIRED`, `DESCRIPTION_REQUIRED`, `NOT_INSTALLABLE`, `INVALID_PLACE`, `INVALID_START`, `TECHNICIAN_UNSUITABLE`, `TRAVEL_UNAVAILABLE`, `TRAVEL_OUT_OF_RANGE`, `BOOKING_ITEMS_NOT_IN_CART`, `JOB_TYPES_REQUIRED`, `INVALID_JOB_TYPES`, `LABOUR_OUT_OF_BOUNDS`, `BAY_REQUIRED`, `HOME_POINT_REQUIRED`, `INVALID_WORK_MODE`, `INVALID_TECHNICIAN`, `TOO_MANY_RULES`, `TIME_OFF_TOO_LONG`, `INVALID_RATING`, `INVALID_DISPUTE` |

  In Dart every failure becomes a `BackendException(code)`; `checkout` throws its subclass `CartChangedException` with the checked lines. Auth errors keep Supabase's code in upper case (`INVALID_CREDENTIALS`, `USER_ALREADY_EXISTS`, `WEAK_PASSWORD`, `OVER_REQUEST_RATE_LIMIT`). A dropped connection is `OFFLINE`.
- **Idempotency.** Mutating RPCs that create things take `p_idem uuid`. A replay with the same key returns the first result without doing anything again. Reusing a key for a different call is `IDEMPOTENCY_KEY_REUSED`. Keys are kept 7 days. Naturally repeatable calls (profile edits, status changes) don't take one.
- **Money** is whole SDG (`bigint`; JSON numbers). **Times** are UTC ISO-8601. **Phones** are stored in E.164 (`+2499…`); any Sudanese format is accepted on input.
- **Weekday numbers** are 0 = Sunday … 6 = Saturday, in Khartoum time. **Opening hours** are `{"0": [[480, 1200]], …}`: minutes after midnight, windows in order, a missing day = closed.

## RPC

### Anyone (signed in or not)

| Function | Returns |
|---|---|
| `ping()` | `{ok, server_time}` |
| `public_settings()` | Buyer-visible settings: fees, fee bands, Bankak account, windows, `booking_lookahead_days`, `latest_app_versions` (`{buyer|partner: {latest_build, min_build, apk_url}}`; `apk_url` holds `{abi}` where the app puts `armeabi-v7a` or `arm64-v8a`, D-135), `support_phone`, `support_whatsapp` |
| `catalogue_snapshot(p_since?)` | `{server_time, full, makes, models, variants, job_types, categories, markets, streets, zones, shops}` for the offline cache. With `p_since`, only rows changed since then, including deactivated ones (`is_active: false`) and shops no longer approved (`{id, status}`). Send `server_time` back next time. |
| `search_parts(p_q, p_variant_id, p_category_id, p_only_fits, p_conditions[], p_price_max, p_shop_id, p_in_stock_only=true, p_deals_only, p_sort, p_limit=30, p_offset)` | One row per part: `part_id, category_id, name_ar/en, installable, std_job_minutes, is_verified, fit (FITS / CHECK_FITMENT / null), from_sdg, shop_count, conditions[], best_warranty_days, max_discount_percent, image_key, listings (≤ 5 offers, cheapest first), rank, total_count`. Parts whose fitment leaves out the given car are hidden. `p_sort`: `relevance` (fits first), `price_low`, `price_high`, `rating`, `discount`, `newest`. Category filters include child categories. |
| `cart_validate(p_items)` | `p_items = [{listing_id \| offer_id, qty, seen_price_sdg}]` (≤ 50). Each line comes back with `ok`, `problem` (`PRICE_CHANGED`, `NOT_ENOUGH_STOCK`, `UNAVAILABLE`), the current `price_sdg`, `available_qty`, `shop_id` and the part's title and condition. Nothing is reserved. |
| `booking_context(p_items, p_place, p_address_id?, p_lat?, p_lng?, p_variant_id?, p_technician_id?)` | What the slot engine needs (called by `booking-slots`): the job's `duration_min`, `travel_fee_sdg`, `booking_fee_sdg`, `mobile_deposit_sdg`, and every technician who suits it with public profile, `labour_sdg`, weekly `rules`, `time_off` and `busy` blocks. `p_items`: `[{listing_id} \| {offer_id} \| {order_item_id} \| {part_id, description?} \| {category_id, description}]` (1–10). `p_place`: `BAY` or `CUSTOMER_LOCATION` (needs an address or a point). |
| `technician_profile(p_technician_id)` | A technician's public profile: rating, jobs, experience, bio, work mode, bay, job types with prices, makes, latest reviews. |
| `reviews_for(p_shop_id?, p_technician_id?, p_limit?)` | Visible reviews, newest first, with the author's first name. |
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

#### Buying (M2)

Order RPCs return `order_json`: the order with `payments`, `refunds` and `sub_orders` (each with `shop`, `items`, `events: [{from, to, actor, at}]` and `return`). A sub-order moves only along the transition table (D-082); any other move is `INVALID_TRANSITION`.

| Function | Who | Does |
|---|---|---|
| `checkout(p_items, p_method, p_fulfilment?, p_address_id?, p_idem?)` | buyer with a phone | Re-checks every line and locks the prices. One sub-order per shop. `p_method`: `BANKAK` or `CASH`. `p_fulfilment = {"<shop_id>": "PICKUP" \| "DELIVERY"}` (pickup by default); delivery needs `p_address_id` and adds the shop's delivery fee (D-087). Reserves stock and takes offers. Bankak: `PENDING_PAYMENT` until `pay_by` (`payment_window_minutes`). Cash: straight to `CONFIRMED`, with one `DUE` cash payment per shop. A changed line gives `CART_CHANGED` and nothing is placed. |
| `cancel_order(p_order_id, p_reason?)` | buyer | While waiting for payment, or a cash order no shop has accepted yet. Otherwise `CANNOT_CANCEL`. |
| `submit_bankak_receipt(p_order_id, p_txn_no?, p_receipt_key?, p_idem?)` | buyer | The transaction number, the receipt (uploaded first to `receipts/{uid}/…`) or both (D-084). Until `pay_by`, also after a rejection. A number already used: `DUPLICATE_TXN`. |
| `confirm_received(p_sub_order_id)` | buyer | Completes the sub-order now instead of after `auto_complete_days`. |
| `request_return(p_sub_order_id, p_reason)` | buyer | Within `return_window_days` of receiving it; the whole sub-order (D-085). An admin decides. |
| `set_refund_account(p_account)` | buyer | The buyer's own Bankak account for refunds. |
| `create_part_request(p_note, p_variant_id?, p_category_id?, p_image_keys[]?, p_idem?)` | buyer | A photo request (≤ 4 photos from `request-photos/{uid}/…`; ≤ 10 open at a time). Matching shops are notified. Open for 3 days. |
| `close_part_request(p_request_id)` | buyer | Its live offers expire. |
| `start_conversation(p_shop_id, p_sub_order_id?)` | buyer | Opens or reopens the chat with an approved shop. Returns the conversation row. |
| `mark_conversation_read(p_conversation_id)` | either side | |
| `mark_notifications_read(p_ids[]?)` | self | Null marks everything. Returns how many changed. |

#### Selling (M2)

A shop sees a sub-order only once it is paid (or a cash order is placed), and never another shop's part of the same order (D-086). Shop order RPCs return `shop_sub_order_json`: the sub-order with `ref`, `payment_method`, `placed_at`, `buyer {name, phone}`, `payment_status`, `address` (delivery only), `items`, `events` and `return`.

| Function | Who | Does |
|---|---|---|
| `shop_orders(p_shop_id, p_statuses[]?, p_limit?, p_offset?)` | members | Newest first. |
| `shop_ack_suborder(p_sub_order_id)` | members | "Accept": a time stamp. The buyer can no longer cancel a cash order. |
| `shop_reject_suborder(p_sub_order_id, p_reason)` | members | Stock goes back; a paid order is refunded. |
| `shop_mark_ready(p_sub_order_id)` | members | `CONFIRMED → READY`. |
| `shop_hand_over(p_sub_order_id)` | members | Pickup: `PICKED_UP`, and cash counts as collected now. Delivery: `OUT_FOR_DELIVERY`. Reserved stock becomes sold. |
| `shop_mark_delivered(p_sub_order_id)` | members | `OUT_FOR_DELIVERY → DELIVERED`; cash counts as collected now. |
| `shop_statement(p_shop_id, p_from?, p_to?)` | members | `{from, to, opening_sdg, closing_sdg, lines: [{id, kind, amount_sdg, at, ref, payout_id}], payouts}`. Positive = the platform owes the shop. The last 30 days by default. |
| `shop_open_requests(p_shop_id, p_limit?, p_offset?)` | members | Open requests in the shop's specialities, with the buyer's first name, `my_offer` and `offer_count`. |
| `shop_make_offer(p_shop_id, p_request_id, p_title_ar, p_condition, p_price_sdg, p_warranty_days?, p_note_ar?, p_part_id?, p_image_key?, p_valid_hours?, p_idem?)` | members | Replaces the shop's earlier offer on the request. Valid for 48 hours by default (1–168). |
| `shop_withdraw_offer(p_shop_id, p_offer_id)` | members | |
| `shop_start_conversation(p_sub_order_id)` | members | Chat with the buyer of one of the shop's orders. |
| `shop_conversations(p_shop_id, p_limit?)` | members | The inbox: the buyer's name, the order reference, the last message and `unread`. |
| `shop_detail(p_shop_id)` | members | The shop as `shop_json`, also while `PENDING`, `REJECTED` or `SUSPENDED` (M5, D-120). |
| `shop_set_closed(p_shop_id, p_until)` | members (writable shop) | "Closed today": `closed_until` until `p_until` (in the future, at most 7 days ahead; null opens again). `open_now` is false meanwhile (D-119). `INVALID_VALUE` otherwise. |
| `shop_insights(p_shop_id, p_days = 7)` | members | `{days: [{day, sales_sdg, orders}], top: [{part_id, title_ar, title_en, qty, sales_sdg}] (≤ 5), rating_avg, rating_count}`: sales per Khartoum day, oldest first, counting sub-orders the shop can see that weren't cancelled, refused or returned (D-120). `p_days` 1–90. |

#### Fittings (M3)

Booking RPCs return `booking_json`: the booking with `items` (each with `job_type_code`), `events`, `technician` (phone once accepted, for the buyer), `buyer` (for the technician), `bay`, `photos`, `offer`, `payments`, `order_ref`, `parts` (M5: each shop holding the fitting's parts, with `sub_order_id, shop_id, name_ar/en, plot_no, phone, status, items_sdg`, D-121), and `job_code` for the buyer only. Statuses move along `booking_transitions` (PLAN §3.10, D-097–D-102).

| Function | Who | Does |
|---|---|---|
| `create_booking_hold(p_technician_id, p_start_at, p_items, p_place, p_address_id?, p_location_note?, p_variant_id?, p_assignment_mode?, p_idem?)` | buyer | Holds the start for `slot_hold_minutes` (D-022, D-096). The start must be on the half hour (Khartoum), after `part_ready_buffer_minutes`, inside the technician's hours for that kind of job and clear of time off and other bookings (`SLOT_TAKEN`). Labour is locked (D-100). One hold per buyer: a new one releases the last. `p_assignment_mode`: `CHOSEN` or `ANY`. |
| `release_booking_hold(p_booking_id)` | buyer | |
| `checkout(…, p_booking_id)` | buyer | Pays the held fitting in the order (D-097); see Buying. |
| `my_bookings(p_limit?, p_offset?)` / `booking_detail(p_booking_id)` | buyer, its technician, admin | |
| `buyer_cancel_booking(p_booking_id, p_reason?)` | buyer | Free before `cancel_cutoff_hours`; later the booking fee and travel fee are kept (D-099). While unpaid it cancels the whole order. |
| `buyer_reschedule(p_booking_id, p_start_at, p_technician_id?)` | buyer | After `NEEDS_RESCHEDULE` only. |
| `create_review(p_rating, p_sub_order_id? \| p_booking_id?, p_comment?)` | buyer | The shop for a received sub-order, the technician for a finished fitting (D-105). |
| `open_dispute(p_category, p_description, p_sub_order_id? \| p_booking_id?)` / `dispute_reply(p_dispute_id, p_body)` / `my_disputes(p_limit?)` | the buyer, the shop's members, the technician | Categories: `NOT_RECEIVED`, `WRONG_PART`, `DAMAGED`, `NOT_FITTED`, `PAYMENT`, `BEHAVIOUR`, `OTHER`. The other side is told (`DISPUTE_FILED`, payload `{dispute_id, ref}`); replies (`DISPUTE_REPLY`) and decisions (`DISPUTE_RESOLVED`) reach each person in the app they use for it (D-132). |

Technicians (partner app):

| Function | Does |
|---|---|
| `apply_as_technician(p_work_mode, p_job_types, p_phone, p_make_ids?, p_home_bay_shop_id?, p_home_lat?, p_home_lng?, p_radius_km?, p_years_experience?, p_bio_ar?, p_employer_shop_id?, p_idem?)` | `p_job_types = [{job_type_id, labour_sdg}]`, within `labour_price_bounds` (D-010). BAY/BOTH need an approved bay shop; MOBILE/BOTH a home point. Starts `PENDING`. |
| `tech_update_profile(p_patch)` / `tech_set_job_types(p_items)` / `tech_set_makes(p_make_ids)` | Keys: `work_mode, home_bay_shop_id, home_lat, home_lng, radius_km, years_experience, bio_ar, bio_en, avatar_key, employer_shop_id`. |
| `tech_quick_block(p_minutes, p_reason?)` | Time off from now (5–720 minutes). Weekly hours and time off are also written directly (`availability_rules`, `time_off`). |
| `tech_bookings(p_scope)` | `OFFERS`, `UPCOMING` or `PAST`. |
| `tech_respond_offer(p_offer_id, p_accept, p_reason?)` | Within `tech_accept_timeout_minutes` (`OFFER_CLOSED`). Declining passes it on (D-102). |
| `tech_en_route` / `tech_update_location(p_booking_id, p_lat, p_lng)` / `tech_check_in` | On the way (buyer's place only; parts collected first), live location while on the way (D-029), check-in up to two hours early. |
| `tech_add_photo(p_booking_id, p_kind, p_image_key)` | `BEFORE`/`AFTER`, uploaded first to `booking-photos/{booking id}/…`; up to 10. |
| `tech_complete(p_booking_id, p_code)` | Returns `{ok: true, booking}` or `{ok: false, error: WRONG_JOB_CODE \| JOB_CODE_LOCKED, attempts_left}` (D-103). Settles the money and completes the parts. |
| `tech_part_not_fit(p_booking_id, p_reason)` | Travel fee only; a return opens on the parts (D-019). |
| `tech_cancel(p_booking_id, p_reason)` | Drops an accepted job before the parts are collected. |
| `tech_statement(p_from?, p_to?)` | Like `shop_statement`; `ref` is the booking's. |

Shops: `shop_hand_over` on a `TO_TECHNICIAN` sub-order works once its booking is accepted (`TECHNICIAN_NOT_ASSIGNED`); `shop_sub_order_json` adds `booking {id, ref, status, start_at, technician {name, phone}}`.

Timed jobs (pg_cron) for fittings: lapsed holds expire and unanswered offers move on (every minute), reminders a day and an hour before (every 5 minutes), the 30-minute "shop hasn't accepted" alert to admins (D-020, every 5 minutes), and the notification dispatcher (every minute).

Three timed jobs run on the server (pg_cron):
- Unpaid Bankak orders expire after `pay_by` (every 5 minutes). Receipts under review wait for the admin.
- Picked-up or delivered sub-orders complete after `auto_complete_days` (hourly).
- Photo requests expire (hourly).

### Admins

| Function | Does |
|---|---|
| `admin_settings()` / `admin_update_setting(p_key, p_value)` | Read all settings / change one (shape checked per key; audited). |
| `admin_grant_role(p_user_id, p_role)` / `admin_revoke_role(…)` | Audited. An admin can't drop their own `ADMIN`; nobody loses `BUYER`. |
| `admin_search_users(p_q, p_limit?)` | By email, name or phone. |
| `admin_set_shop_status(p_shop_id, p_status, p_reason?)` | `PENDING → APPROVED/REJECTED`, `APPROVED ⇄ SUSPENDED`, `REJECTED → APPROVED`. A reason is required to reject or suspend. Approval grants the shop roles and places the shop mid-zone if `pos_m` is unset. |
| `admin_verify_shop(p_shop_id, p_verified)` | The "verified" badge. |
| `admin_merge_parts(p_from, p_into)` | Moves listings onto the target part and retires the duplicate. |
| `admin_payment_queue()` | Receipts under review, oldest first, with the order, the buyer and the checks: amount, reference, `txn_seen_before` (D-054). |
| `admin_confirm_payment(p_payment_id, p_txn_no?, p_ref_in_note?)` | The transfer is on the statement. The transaction number is required here (`TXN_REQUIRED`) and must be unused (`DUPLICATE_TXN`). Sub-orders go to `CONFIRMED` and the shops are told. |
| `admin_reject_payment(p_payment_id, p_reason, p_note?)` | `AMOUNT_WRONG`, `NOT_ON_STATEMENT`, `DUPLICATE`, `UNREADABLE` or `OTHER`. The buyer can send again until `pay_by`. |
| `admin_mark_refund_paid(p_refund_id, p_txn_no)` | The refund was sent by Bankak (D-088). |
| `admin_cancel_suborder(p_sub_order_id, p_reason)` | Until the buyer has the part (up to `OUT_FOR_DELIVERY`); refunds what was paid. A reason is required. |
| `admin_complete_suborder(p_sub_order_id)` | Completes a picked-up, delivered or handed-to-technician sub-order. |
| `admin_decide_return(p_sub_order_id, p_approve, p_note?)` | Approve: `RETURNED`, stock back, the sale reversed and the buyer refunded in full. Decline (note required): `COMPLETED`. |
| `admin_partner_balances()` | Every shop and technician (`party`: `SHOP`/`TECH`) with ledger activity: its balance, cash collected since its last payout, the payout waiting, and how many runs in a row it ended owing the platform (D-018). |
| `admin_ledger_adjustment(p_amount_sdg, p_reason, p_shop_id? \| p_technician_id?)` | A manual correction (D-130): positive = the platform owes the partner more, negative = less. Posts an `ADJUSTMENT` journal against `ADJUSTMENTS`, audited (`ADJUST_BALANCE`). Returns the new balance. `INVALID_VALUE` (no amount, or not exactly one partner), `REASON_REQUIRED`, `SHOP_NOT_FOUND`, `TECHNICIAN_NOT_FOUND`. |
| `admin_report(p_from, p_to)` | Khartoum dates, both included, at most a year (D-129): `{from, to, days: [{day, orders, sales_sdg, commission_sdg, fittings}], totals: {orders, cash_orders, buyers, shops_selling, sales_sdg, commission_sdg, delivery_sdg, fittings_booked, fittings_done, booking_fees_sdg, labour_sdg, travel_sdg, refunds_paid_sdg, receipts_confirmed, receipts_rejected, review_minutes, new_accounts, new_shops, new_technicians}, top_shops: [{shop_id, name_ar, name_en, orders, sales_sdg, commission_sdg, rating_avg, rating_count}], fittings: {STATUS: count}}`. |
| `admin_generate_payouts(p_period_to?)` | A `DRAFT` payout for every shop and technician the platform owes (D-089). |
| `admin_set_technician_status(p_technician_id, p_status, p_reason?)` / `admin_verify_technician(p_technician_id, p_verified)` | Like shops; approval grants `TECHNICIAN` and opens the ledger account. |
| `admin_cancel_booking(p_booking_id, p_reason)` / `admin_reassign_booking(p_booking_id, p_reason?)` / `admin_complete_booking(p_booking_id)` | Cancel with a full refund; pass a pending or accepted job to the next free technician; close a job in progress (e.g. a locked code). |
| `admin_update_dispute(p_dispute_id, p_status, p_resolution?)` / `admin_hide_review(p_review_id, p_hidden, p_reason?)` | `IN_REVIEW`, `RESOLVED` or `REJECTED` (resolution required). |
| `admin_approve_payouts(p_ids[])` / `admin_mark_payout_paid(p_payout_id, p_txn_no)` / `admin_cancel_payout(p_payout_id, p_reason)` | `DRAFT → APPROVED → PAID`. Paying posts the `PAYOUT` journal. |

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
| `orders`, `payments`, `refunds` | the buyer (a shop sees only the cash payment of its own sub-order), admins | — |
| `sub_orders`, `order_items`, `suborder_events`, `returns` | the buyer, the shop it belongs to, admins | — |
| `cart_items` | self | self (`listing_id` or `offer_id`, `qty`, `seen_price_sdg`; ≤ 50 lines) |
| `part_requests` | the buyer, admins (shops use `shop_open_requests`) | — |
| `part_offers` | the request's buyer, the shop, admins | — |
| `conversations` | both sides, admins | — |
| `messages` | both sides, admins | both sides (`body`, or `voice_key` + `voice_secs` ≤ 60); live through Realtime |
| `notifications` | self; new rows live through Realtime (D-142) | — |
| `payouts` | the shop's members, admins | — |
| `ledger_accounts`, `ledger_journals`, `ledger_entries`, `payout_runs`, `payout_run_balances`, `payout_run_tech_balances` | admins | — (append-only) |
| `technicians`, `technician_job_types`, `technician_makes` | the technician, admins (buyers use `booking_context` / `technician_profile`) | — |
| `availability_rules`, `time_off` | the technician, admins | the technician |
| `bookings`, `booking_items`, `booking_events`, `booking_photos` | the buyer, the technician, admins | — |
| `booking_codes` | the buyer, admins | — |
| `booking_offers` | the technician offered, admins | — |
| `tech_locations` | the technician; the buyer while `EN_ROUTE`; admins (Realtime) | — |
| `reviews` | the author, the reviewed shop or technician, admins | — |
| `disputes`, `dispute_messages` | the parties, admins | — |
| `notification_codes`, `notification_templates` | signed-in users | admins (templates; every change audited, D-131) |
| `notification_deliveries` | admins | — |
| `app_settings`, `idempotency_keys`, `part_search_docs`, `search_synonym_terms` | — | — |

## Storage

| Bucket | Public | Limit | Who writes |
|---|---|---|---|
| `media-public` | yes | 5 MB, webp/jpeg/png | shop members under `shops/{shop_id}/…`; a user under `users/{uid}/…` |
| `imports` | no | 5 MB, xlsx/xls/csv | shop members under `{shop_id}/…` (and read their own) |
| `templates` | yes | 5 MB | admins (`pnpm templates:upload <dev|test>`) — `templates/inventory-template.xlsx` |
| `app-releases` | yes | 50 MB, APK | admins (D-058) |
| `receipts` | no | 5 MB, images/PDF | the buyer under `{uid}/…`; admins read |
| `request-photos` | no | 5 MB, images | the buyer under `{uid}/…`; approved shops read the photos of open requests |
| `voice-notes` | no | 2 MB, m4a/aac/mp3 | both sides of a conversation, under `{conversation_id}/…` |
| `booking-photos` | no | 5 MB, images | the booking's technician under `{booking_id}/…`; its buyer and admins read |

## Edge Functions

### `admin-set-password`
`POST /functions/v1/admin-set-password` with an admin's session. Body: `{ "user_id": "…", "password": "…" }`.

Gives a temporary password to a user who called support (D-064, D-080). The caller must have `ADMIN`; the password must have 8–72 characters with letters and digits (D-073). The change is audited as `SET_PASSWORD` (the password isn't stored).

Response: `{ "ok": true }`. Errors: 401 `NOT_AUTHENTICATED`, 403 `FORBIDDEN`, 400 `INVALID_BODY` / `WEAK_PASSWORD`, 404 `USER_NOT_FOUND`.

### `booking-slots`
`POST /functions/v1/booking-slots`, signed in or with only the publishable key (guests). Body: `{ items, place, address_id?, lat?, lng?, variant_id?, technician_id? }` as `booking_context`.

Runs the slot engine (PLAN §5, `_shared/slots`) and answers `{duration_min, travel_fee_sdg, booking_fee_sdg, mobile_deposit_sdg, items, labour_range, technicians: [{id, name, …, labour_sdg, score, next_slot, slot_count, slots?}], any: [{start, technician_id}]}`. With `technician_id`, that technician's every start (`slots`) and no `any`. Errors are the RPC's codes (400/403/404).

### `notify-dispatch`
`POST /functions/v1/notify-dispatch` with `Authorization: Bearer <NOTIFY_DISPATCH_TOKEN>` — called by pg_cron (D-101), not by apps. Claims due pushes (`notify_claim`), words them (`_shared/notify/render.ts`), sends them by FCM when `FCM_SERVICE_ACCOUNT` is set (stubs otherwise) and reports (`notify_report`). Set up per project with `pnpm notify:setup <dev|test> [--fcm key.json]`.

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
