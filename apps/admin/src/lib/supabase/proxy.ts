import { createServerClient } from '@supabase/ssr';
import type { Database } from '@alghali/db-types';
import type { NextRequest, NextResponse } from 'next/server';
import { SESSION_COOKIE } from './cookies';

/**
 * Refreshes the Supabase session cookies on [response] and says whether the
 * request carries a valid session. Only an optimistic check: pages and actions
 * still verify the admin role on the server.
 */
export async function refreshSession(request: NextRequest, response: NextResponse) {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY;
  if (!url || !key) return { configured: false, signedIn: false };

  const supabase = createServerClient<Database>(url, key, {
    cookieOptions: SESSION_COOKIE,
    cookies: {
      getAll: () => request.cookies.getAll(),
      setAll(list) {
        for (const { name, value } of list) request.cookies.set(name, value);
        for (const { name, value, options } of list) response.cookies.set(name, value, options);
      },
    },
  });
  const { data } = await supabase.auth.getClaims();
  return { configured: true, signedIn: Boolean(data?.claims?.sub) };
}
