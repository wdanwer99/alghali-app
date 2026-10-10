import { createClient, type SupabaseClient } from '@supabase/supabase-js';
import type { Database } from '@alghali/db-types';

/**
 * Anonymous server-side client (publishable key). Returns null until `pnpm env:sync`
 * has written the Supabase URL/key into `.env.local`.
 * Cookie-based sessions for signed-in admins arrive with auth in M1.
 */
export function getAnonClient(): SupabaseClient<Database> | null {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY;
  if (!url || !key) return null;
  return createClient<Database>(url, key, { auth: { persistSession: false } });
}
