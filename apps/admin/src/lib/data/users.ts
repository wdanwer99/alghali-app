import 'server-only';
import type { Database } from '@alghali/db-types';
import type { Supabase } from '@/lib/supabase/server';
import { must } from './util';

export type Role = Database['public']['Enums']['app_role'];
export type UserRow = {
  id: string;
  email: string;
  name: string;
  phone: string | null;
  roles: Role[];
  createdAt: string;
};

/** Newest accounts first; [q] matches email, name or phone (admin_search_users checks the role). */
export async function searchUsers(supabase: Supabase, q: string, limit = 50): Promise<UserRow[]> {
  const rows = await supabase
    .rpc('admin_search_users', { p_q: q.trim().slice(0, 100), p_limit: limit })
    .then(must);
  return rows.map((r) => ({
    id: r.id,
    email: r.email ?? '',
    name: r.display_name || r.email || '',
    phone: r.phone,
    roles: r.roles ?? [],
    createdAt: r.created_at,
  }));
}
