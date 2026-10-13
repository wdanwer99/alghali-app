import 'server-only';
import type { Supabase } from '@/lib/supabase/server';
import { must, type Named } from './util';

export type Activity = {
  id: number;
  action: string;
  entity: string;
  at: string;
  actor: string | null;
  /** The shop's name for shop events; null when the row is gone or not a shop. */
  shop: Named | null;
  /** Setting key, role, new status or verified flag, depending on the action. */
  detail: string | null;
};

export type Overview = {
  shops: {
    approved: number;
    pending: number;
    suspended: number;
    rejected: number;
    verified: number;
  };
  oldestPendingAt: string | null;
  accounts: number;
  shopOwners: number;
  listings: number;
  parts: number;
  shopParts: number;
  listedWithoutFitment: number;
  byCategory: { id: string; name: Named; listings: number; parts: number }[];
  activity: Activity[];
};

const head = { count: 'exact', head: true } as const;

function count({ count, error }: { count: number | null; error: { message: string } | null }) {
  if (error) throw new Error(error.message);
  return count ?? 0;
}

export async function loadOverview(supabase: Supabase): Promise<Overview> {
  const [shops, accounts, shopOwners, listings, parts, categories, audit] = await Promise.all([
    supabase.from('shops').select('id, status, verified, created_at').then(must),
    supabase.from('profiles').select('id', head).then(count),
    supabase.from('user_roles').select('user_id', head).eq('role', 'SHOP_OWNER').then(count),
    supabase
      .from('listings')
      .select('id', head)
      .is('archived_at', null)
      .eq('is_active', true)
      .then(count),
    supabase
      .from('parts')
      .select('id, category_id, is_verified, fitments:part_fitments(count), listings(count)')
      .eq('is_active', true)
      .is('merged_into', null)
      .is('listings.archived_at', null)
      .eq('listings.is_active', true)
      .then(must),
    supabase
      .from('part_categories')
      .select('id, name_ar, name_en, sort')
      .eq('is_active', true)
      .order('sort')
      .then(must),
    supabase
      .from('audit_log')
      .select('id, action, entity, entity_id, actor_id, data, created_at')
      .order('id', { ascending: false })
      .limit(8)
      .then(must),
  ]);

  const status = (s: string) => shops.filter((x) => x.status === s).length;
  const pending = shops
    .filter((x) => x.status === 'PENDING')
    .map((x) => x.created_at)
    .sort();

  const perCategory = new Map<string, { listings: number; parts: number }>();
  for (const p of parts) {
    const c = perCategory.get(p.category_id) ?? { listings: 0, parts: 0 };
    c.listings += p.listings[0]?.count ?? 0;
    c.parts += 1;
    perCategory.set(p.category_id, c);
  }

  // Names for the people and shops the recent events mention.
  const actorIds = [...new Set(audit.flatMap((a) => (a.actor_id ? [a.actor_id] : [])))];
  const shopIds = [
    ...new Set(audit.flatMap((a) => (a.entity === 'shop' && a.entity_id ? [a.entity_id] : []))),
  ];
  const [actors, shopNames] = await Promise.all([
    actorIds.length
      ? supabase.from('profiles').select('id, display_name, email').in('id', actorIds).then(must)
      : [],
    shopIds.length
      ? supabase.from('shops').select('id, name_ar, name_en').in('id', shopIds).then(must)
      : [],
  ]);
  const actorName = new Map(actors.map((p) => [p.id, p.display_name || p.email || null]));
  const shopName = new Map(
    shopNames.map((s) => [s.id, { ar: s.name_ar, en: s.name_en || s.name_ar }]),
  );

  return {
    shops: {
      approved: status('APPROVED'),
      pending: status('PENDING'),
      suspended: status('SUSPENDED'),
      rejected: status('REJECTED'),
      verified: shops.filter((x) => x.verified && x.status === 'APPROVED').length,
    },
    oldestPendingAt: pending[0] ?? null,
    accounts,
    shopOwners,
    listings,
    parts: parts.length,
    shopParts: parts.filter((p) => !p.is_verified).length,
    listedWithoutFitment: parts.filter(
      (p) => (p.listings[0]?.count ?? 0) > 0 && (p.fitments[0]?.count ?? 0) === 0,
    ).length,
    byCategory: categories
      .map((c) => ({
        id: c.id,
        name: { ar: c.name_ar, en: c.name_en },
        listings: perCategory.get(c.id)?.listings ?? 0,
        parts: perCategory.get(c.id)?.parts ?? 0,
      }))
      .sort((a, b) => b.listings - a.listings),
    activity: audit.map((a) => {
      const data = (a.data ?? {}) as Record<string, unknown>;
      const detail =
        a.action === 'SET_STATUS'
          ? String(data.to ?? '')
          : a.action === 'VERIFY'
            ? String(data.verified ?? '')
            : a.action === 'GRANT_ROLE' || a.action === 'REVOKE_ROLE'
              ? String(data.role ?? '')
              : a.entity === 'setting'
                ? a.entity_id
                : null;
      return {
        id: a.id,
        action: a.action,
        entity: a.entity,
        at: a.created_at,
        actor: a.actor_id ? (actorName.get(a.actor_id) ?? null) : null,
        shop: a.entity === 'shop' && a.entity_id ? (shopName.get(a.entity_id) ?? null) : null,
        detail,
      };
    }),
  };
}
