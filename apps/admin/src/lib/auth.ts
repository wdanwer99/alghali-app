import 'server-only';
import { redirect } from 'next/navigation';
import { cache } from 'react';
import { getSessionClient, type Supabase } from '@/lib/supabase/server';

export type Admin = { id: string; email: string; name: string };
export type AdminSession = { supabase: Supabase; admin: Admin };

/**
 * The signed-in admin for this request, or null (signed out, not an admin, or
 * the backend isn't set up). The role is read from the database on every
 * request (D-065), so a revoked admin loses access at once.
 */
export const getAdminSession = cache(async (): Promise<AdminSession | null> => {
  const supabase = await getSessionClient();
  if (!supabase) return null;
  const { data: claims } = await supabase.auth.getClaims();
  const id = claims?.claims?.sub;
  if (!id) return null;
  const [{ data: isAdmin }, { data: profile }] = await Promise.all([
    supabase.rpc('is_admin'),
    supabase.from('profiles').select('email, display_name').eq('id', id).maybeSingle(),
  ]);
  if (!isAdmin) return null;
  const email = profile?.email ?? '';
  return { supabase, admin: { id, email, name: profile?.display_name || email } };
});

/** For pages and actions that need an admin: sends anyone else to sign-in. */
export async function requireAdmin(): Promise<AdminSession> {
  const session = await getAdminSession();
  if (!session) redirect('/login?reason=signin');
  return session;
}
