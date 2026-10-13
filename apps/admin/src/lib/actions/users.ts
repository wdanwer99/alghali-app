'use server';

import { FunctionsHttpError } from '@supabase/supabase-js';
import { requireAdmin } from '@/lib/auth';
import { searchUsers, type UserRow } from '@/lib/data/users';
import { strongEnough } from '@/lib/password';
import { done, fail, UUID, type ActionResult } from './result';

/** Live search from the Users page. */
export async function findUsers(q: string): Promise<UserRow[]> {
  const { supabase } = await requireAdmin();
  return searchUsers(supabase, String(q));
}

/** Gives or takes the ADMIN role (the database refuses to let you remove your own). */
export async function setAdminRole(userId: string, admin: boolean): Promise<ActionResult> {
  if (!UUID.test(userId)) return fail('INVALID_VALUE');
  const { supabase } = await requireAdmin();
  const args = { p_user_id: userId, p_role: 'ADMIN' as const };
  const { error } = admin
    ? await supabase.rpc('admin_grant_role', args)
    : await supabase.rpc('admin_revoke_role', args);
  return done(error);
}

/**
 * Sets a temporary password for a user who called support (D-064). Runs in the
 * `admin-set-password` Edge Function, which holds the secret key; the console never does.
 */
export async function setTemporaryPassword(
  userId: string,
  password: string,
): Promise<ActionResult> {
  if (!UUID.test(userId)) return fail('INVALID_VALUE');
  if (!strongEnough(password)) return fail('WEAK_PASSWORD');
  const { supabase } = await requireAdmin();
  const { error } = await supabase.functions.invoke('admin-set-password', {
    body: { user_id: userId, password },
  });
  if (!error) return { ok: true };
  if (error instanceof FunctionsHttpError) {
    const body = await error.context.json().catch(() => null);
    if (body && typeof body.error === 'string') return fail(body.error);
  }
  return fail('FAILED');
}
