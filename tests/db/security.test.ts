import { afterAll, describe, expect, it } from 'vitest';
import { connect, hasDb, skipReason, type Sql } from '../support/db.ts';

// Allow-lists. Adding a table or function to one of these is a security decision:
// say why in the migration that needs it.

/** Tables clients may write directly; RLS limits whose rows (PLAN §1 rule 2). */
const DIRECT_WRITE_TABLES = [
  'addresses',
  'cart_items',
  'garage_vehicles',
  'messages', // insert only: participants, as themselves
  // M3: the technician's own hours and time off; admins edit alert wording.
  'availability_rules',
  'notification_templates',
  'time_off',
  // Admin-only through RLS (D-068).
  'job_types',
  'markets',
  'part_categories',
  'part_fitments',
  'parts',
  'search_synonyms',
  'streets',
  'vehicle_makes',
  'vehicle_models',
  'vehicle_variants',
  'zones',
].sort();

/** Functions anyone (signed in or not) may call. */
const ANON_FUNCTIONS = [
  'ar_normalize',
  'booking_context', // what the booking-slots Edge Function reads (no contact details)
  'reviews_for',
  'technician_profile',
  'cart_validate',
  'catalogue_snapshot',
  'has_role',
  'is_admin',
  'is_shop_member',
  'part_detail',
  'ping',
  'public_settings',
  'search_parts',
  'search_terms',
  'valid_opening_hours',
].sort();

/** Functions only signed-in users may call (each checks role/ownership itself). */
const AUTHENTICATED_FUNCTIONS = [
  ...ANON_FUNCTIONS,
  'admin_grant_role',
  'admin_merge_parts',
  'admin_revoke_role',
  'admin_search_users',
  'admin_set_shop_status',
  'admin_settings',
  'admin_update_setting',
  'admin_verify_shop',
  'apply_as_shop',
  'me',
  'register_device',
  'shop_add_staff',
  'shop_archive_listing',
  'shop_bulk_update',
  'shop_import_rows',
  'shop_listings',
  'shop_remove_staff',
  'shop_set_listing_images',
  'shop_staff',
  'shop_update_profile',
  'shop_upsert_listing',
  'suggest_parts',
  'try_uuid',
  'unregister_device',
  'update_profile',
  // M2 commerce
  'admin_approve_payouts',
  'admin_cancel_payout',
  'admin_cancel_suborder',
  'admin_complete_suborder',
  'admin_confirm_payment',
  'admin_decide_return',
  'admin_generate_payouts',
  'admin_mark_payout_paid',
  'admin_mark_refund_paid',
  'admin_partner_balances',
  'admin_payment_queue',
  'admin_reject_payment',
  'can_see_sub_order',
  'cancel_order',
  'checkout',
  'close_part_request',
  'confirm_received',
  'create_part_request',
  'is_conversation_participant',
  'mark_conversation_read',
  'mark_notifications_read',
  'request_return',
  'set_refund_account',
  'shop_ack_suborder',
  'shop_conversations',
  'shop_hand_over',
  'shop_make_offer',
  'shop_mark_delivered',
  'shop_mark_ready',
  'shop_open_requests',
  'shop_orders',
  'shop_reject_suborder',
  'shop_start_conversation',
  'shop_statement',
  'shop_withdraw_offer',
  'start_conversation',
  'submit_bankak_receipt',
  // M3 installation
  'admin_cancel_booking',
  'admin_complete_booking',
  'admin_hide_review',
  'admin_reassign_booking',
  'admin_set_technician_status',
  'admin_update_dispute',
  'admin_verify_technician',
  'apply_as_technician',
  'booking_detail',
  'buyer_cancel_booking',
  'buyer_reschedule',
  'can_see_booking',
  'can_see_dispute',
  'create_booking_hold',
  'create_review',
  'dispute_reply',
  'my_bookings',
  'my_disputes',
  'my_technician_id',
  'open_dispute',
  'release_booking_hold',
  'tech_add_photo',
  'tech_bookings',
  'tech_cancel',
  'tech_check_in',
  'tech_complete',
  'tech_en_route',
  'tech_part_not_fit',
  'tech_quick_block',
  'tech_respond_offer',
  'tech_set_job_types',
  'tech_set_makes',
  'tech_statement',
  'tech_update_location',
  'tech_update_profile',
].sort();

describe.skipIf(!hasDb)('security baseline', () => {
  const sql: Sql = connect();
  afterAll(() => sql.end());

  it('every public table has row level security enabled', async () => {
    const rows = await sql<{ table: string }[]>`
      select c.relname as table
      from pg_class c join pg_namespace n on n.oid = c.relnamespace
      where n.nspname = 'public' and c.relkind in ('r', 'p') and not c.relrowsecurity`;
    expect(rows.map((r) => r.table)).toEqual([]);
  });

  it('anon can never write to a public table', async () => {
    const rows = await sql<{ table: string }[]>`
      select distinct table_name as table from information_schema.role_table_grants
      where table_schema = 'public' and grantee = 'anon'
        and privilege_type in ('INSERT', 'UPDATE', 'DELETE', 'TRUNCATE')`;
    expect(rows.map((r) => r.table)).toEqual([]);
  });

  it('signed-in users write directly only to the allow-listed tables', async () => {
    const rows = await sql<{ table: string }[]>`
      select distinct table_name as table from information_schema.role_table_grants
      where table_schema = 'public' and grantee = 'authenticated'
        and privilege_type in ('INSERT', 'UPDATE', 'DELETE')
      order by 1`;
    expect(rows.map((r) => r.table)).toEqual(DIRECT_WRITE_TABLES);
  });

  it('nobody but the owner can truncate, reference or add triggers to tables', async () => {
    const rows = await sql<{ table: string; grantee: string; privilege_type: string }[]>`
      select table_name as table, grantee, privilege_type from information_schema.role_table_grants
      where table_schema = 'public' and grantee in ('anon', 'authenticated')
        and privilege_type in ('TRUNCATE', 'REFERENCES', 'TRIGGER')`;
    expect(rows).toEqual([]);
  });

  async function callable(role: 'anon' | 'authenticated'): Promise<string[]> {
    const rows = await sql<{ name: string }[]>`
      select distinct p.proname as name
      from pg_proc p join pg_namespace n on n.oid = p.pronamespace
      where n.nspname = 'public' and p.prokind = 'f'
        and has_function_privilege(${role}, p.oid, 'EXECUTE')
      order by 1`;
    return rows.map((r) => r.name);
  }

  it('anon can call only the allow-listed functions', async () => {
    expect(await callable('anon')).toEqual(ANON_FUNCTIONS);
  });

  it('signed-in users can call only the allow-listed functions', async () => {
    expect(await callable('authenticated')).toEqual(AUTHENTICATED_FUNCTIONS);
  });

  it('every security definer function pins an empty search_path', async () => {
    const rows = await sql<{ name: string }[]>`
      select p.proname as name
      from pg_proc p join pg_namespace n on n.oid = p.pronamespace
      where n.nspname = 'public' and p.prosecdef
        and not coalesce('search_path=""' = any (p.proconfig), false)`;
    expect(rows.map((r) => r.name)).toEqual([]);
  });

  it('every public bucket is limited by size and MIME type', async () => {
    const rows = await sql<{ id: string }[]>`
      select id from storage.buckets where file_size_limit is null or allowed_mime_types is null`;
    expect(rows.map((r) => r.id)).toEqual([]);
  });
});

describe.runIf(!hasDb)('security baseline (skipped)', () => {
  it.skip(skipReason, () => undefined);
});
