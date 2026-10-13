import 'server-only';
import type { Database } from '@alghali/db-types';
import type { Supabase } from '@/lib/supabase/server';
import { must, type Named } from './util';

export type ShopStatus = Database['public']['Enums']['partner_status'];

export type Shop = {
  id: string;
  name: Named;
  status: ShopStatus;
  statusReason: string | null;
  verified: boolean;
  zone: Named & { seq: number };
  plotNo: string | null;
  side: string | null;
  landmark: Named | null;
  about: Named | null;
  phone: string | null;
  whatsapp: string | null;
  openingHours: Record<string, [number, number][]>;
  rating: { avg: number; count: number };
  createdAt: string;
  approvedAt: string | null;
  owner: { name: string; email: string; phone: string | null } | null;
  staff: number;
  listings: number;
  categories: Named[];
  makes: Named[];
};

/** Every shop with its owner, stock size and specialities, newest application first. */
export async function listShops(supabase: Supabase): Promise<Shop[]> {
  const shops = await supabase
    .from('shops')
    .select(
      `id, name_ar, name_en, status, status_reason, verified, plot_no, side, landmark_ar, landmark_en,
       about_ar, about_en, phone, whatsapp, opening_hours, rating_avg, rating_count, created_at, approved_at,
       zone:zones(name_ar, name_en, seq),
       members:shop_members(user_id, role),
       specialities:shop_specialities(category:part_categories(name_ar, name_en), make:vehicle_makes(name_ar, name_en)),
       listings(count)`,
    )
    .is('listings.archived_at', null)
    .eq('listings.is_active', true)
    .order('created_at', { ascending: false })
    .then(must);

  // Owners are auth users; their names live in profiles (no foreign key to embed through).
  const ownerIds = shops.flatMap((s) =>
    s.members.filter((m) => m.role === 'OWNER').map((m) => m.user_id),
  );
  const profiles = ownerIds.length
    ? await supabase
        .from('profiles')
        .select('id, display_name, email, phone')
        .in('id', ownerIds)
        .then(must)
    : [];
  const profileById = new Map(profiles.map((p) => [p.id, p]));

  return shops.map((s) => {
    const ownerId = s.members.find((m) => m.role === 'OWNER')?.user_id;
    const owner = ownerId ? profileById.get(ownerId) : undefined;
    return {
      id: s.id,
      name: { ar: s.name_ar, en: s.name_en || s.name_ar },
      status: s.status,
      statusReason: s.status_reason,
      verified: s.verified,
      zone: { ar: s.zone?.name_ar ?? '', en: s.zone?.name_en ?? '', seq: s.zone?.seq ?? 0 },
      plotNo: s.plot_no,
      side: s.side,
      landmark: s.landmark_ar ? { ar: s.landmark_ar, en: s.landmark_en || s.landmark_ar } : null,
      about: s.about_ar ? { ar: s.about_ar, en: s.about_en || s.about_ar } : null,
      phone: s.phone,
      whatsapp: s.whatsapp,
      openingHours: (s.opening_hours ?? {}) as Shop['openingHours'],
      rating: { avg: Number(s.rating_avg), count: s.rating_count },
      createdAt: s.created_at,
      approvedAt: s.approved_at,
      owner: owner
        ? {
            name: owner.display_name || owner.email || '',
            email: owner.email ?? '',
            phone: owner.phone,
          }
        : null,
      staff: s.members.filter((m) => m.role === 'STAFF').length,
      listings: s.listings[0]?.count ?? 0,
      categories: s.specialities.flatMap((x) =>
        x.category ? [{ ar: x.category.name_ar, en: x.category.name_en }] : [],
      ),
      makes: s.specialities.flatMap((x) =>
        x.make ? [{ ar: x.make.name_ar, en: x.make.name_en }] : [],
      ),
    };
  });
}

export async function countPendingShops(supabase: Supabase): Promise<number> {
  const { count, error } = await supabase
    .from('shops')
    .select('id', { count: 'exact', head: true })
    .eq('status', 'PENDING');
  if (error) throw new Error(error.message);
  return count ?? 0;
}
