import 'server-only';
import type { Json } from '@alghali/db-types';
import type { Supabase } from '@/lib/supabase/server';
import { must } from './util';

export type Setting = { key: string; value: Json; updatedAt: string; updatedBy: string | null };

/** All settings (admin_settings checks the role), with the name of whoever last changed each. */
export async function loadSettings(supabase: Supabase): Promise<Record<string, Setting>> {
  const rows = await supabase.rpc('admin_settings').then(must);
  const editorIds = [...new Set(rows.flatMap((r) => (r.updated_by ? [r.updated_by] : [])))];
  const editors = editorIds.length
    ? await supabase
        .from('profiles')
        .select('id, display_name, email')
        .in('id', editorIds)
        .then(must)
    : [];
  const editorName = new Map(editors.map((p) => [p.id, p.display_name || p.email || null]));
  return Object.fromEntries(
    rows.map((r) => [
      r.key,
      {
        key: r.key,
        value: r.value,
        updatedAt: r.updated_at,
        updatedBy: r.updated_by ? (editorName.get(r.updated_by) ?? null) : null,
      },
    ]),
  );
}
