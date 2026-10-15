import 'server-only';
import { createServerClient } from '@supabase/ssr';
import { createClient, type SupabaseClient } from '@supabase/supabase-js';
import type { Database } from '@alghali/db-types';
import { cookies } from 'next/headers';
import { connection } from 'next/server';
import { SESSION_COOKIE } from './cookies';

export type Supabase = SupabaseClient<Database>;

function config() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY;
  return url && key ? { url, key } : null;
}

export const isConfigured = () => config() !== null;

/**
 * Anonymous server-side client (publishable key). Returns null until `pnpm env:sync`
 * has written the Supabase URL/key into `.env.local`.
 */
export function getAnonClient(): Supabase | null {
  const c = config();
  if (!c) return null;
  return createClient<Database>(c.url, c.key, { auth: { persistSession: false } });
}

/**
 * The signed-in admin's client: the session lives in cookies, so every query runs
 * as that user under row level security. Server Components can't write cookies;
 * the proxy refreshes the session before rendering, so those writes are skipped.
 */
export async function getSessionClient(): Promise<Supabase | null> {
  const c = config();
  if (!c) return null;
  // Request-time only: the auth client reads the clock (token expiry), which
  // Next refuses during prerendering.
  await connection();
  const store = await cookies();
  return createServerClient<Database>(c.url, c.key, {
    cookieOptions: SESSION_COOKIE,
    cookies: {
      getAll: () => store.getAll(),
      setAll(list) {
        try {
          for (const { name, value, options } of list) store.set(name, value, options);
        } catch {
          // Called from a Server Component; the proxy already refreshed the session.
        }
      },
    },
  });
}
