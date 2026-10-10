# API

The backend is Supabase. Clients **read** tables through PostgREST under row level security and **change things** by calling Postgres functions (RPC) or Edge Functions. This file lists what exists today; [PLAN.md §4](PLAN.md) lists what's coming.

Every mutating RPC/Edge Function takes an idempotency key (`p_idem uuid` or the `Idempotency-Key` header) — from M1 on.

## RPC

| Function | Who | Returns | Since |
|---|---|---|---|
| `ping()` | anyone | `{ "ok": true, "server_time": "<timestamptz>" }` | M0 |
| `public_settings()` | anyone | Object of public settings: `booking_fee_sdg`, `mobile_deposit_sdg`, `slot_hold_minutes`, `cancel_cutoff_hours`, `travel_fee_bands`, `delivery_fee_bands`, `bankak_account_name`, `bankak_account_number`, `payment_window_minutes`, `return_window_days`, `booking_lookahead_days` | M0 |

Example (Dart):

```dart
final settings = await Supabase.instance.client.rpc<Map<String, dynamic>>('public_settings');
final fee = settings['booking_fee_sdg'] as int; // whole SDG
```

## Tables

| Table | Read | Write | Since |
|---|---|---|---|
| `app_settings` | none directly (use `public_settings()`); admin policies in M1 | admin RPC in M1 | M0 |

## Edge Functions

None yet (first ones in M1: `inventory-import`).
