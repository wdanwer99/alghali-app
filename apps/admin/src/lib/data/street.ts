import 'server-only';
import type { Supabase } from '@/lib/supabase/server';
import { must, type Named } from './util';

export type Zone = {
  id: string;
  seq: number;
  name: Named;
  fromM: number;
  toM: number;
  active: boolean;
  shops: number;
};

export type StreetData = {
  market: { id: string; name: Named; city: Named };
  street: {
    id: string;
    name: Named;
    lengthM: number;
    originLat: number | null;
    originLng: number | null;
  };
  zones: Zone[];
  /** Shops with a position, for the street strip. */
  shops: { id: string; name: Named; posM: number }[];
};

/**
 * The market and its street (the platform has one of each today), their zones in
 * order with how many shops each holds, and where the shops sit along the street.
 */
export async function loadStreet(supabase: Supabase): Promise<StreetData | null> {
  const street = await supabase
    .from('streets')
    .select(
      `id, name_ar, name_en, length_m, origin_lat, origin_lng,
       market:markets(id, name_ar, name_en, city_ar, city_en)`,
    )
    .order('slug')
    .limit(1)
    .maybeSingle()
    .then(must);
  if (!street || !street.market) return null;

  const [zones, shops] = await Promise.all([
    supabase
      .from('zones')
      .select('id, seq, name_ar, name_en, from_m, to_m, is_active, shops(count)')
      .eq('street_id', street.id)
      .order('seq')
      .then(must),
    supabase
      .from('shops')
      .select('id, name_ar, name_en, pos_m, zone:zones!inner(street_id)')
      .eq('zone.street_id', street.id)
      .not('pos_m', 'is', null)
      .in('status', ['APPROVED', 'PENDING'])
      .then(must),
  ]);

  const m = street.market;
  return {
    market: {
      id: m.id,
      name: { ar: m.name_ar, en: m.name_en },
      city: { ar: m.city_ar, en: m.city_en },
    },
    street: {
      id: street.id,
      name: { ar: street.name_ar, en: street.name_en },
      lengthM: street.length_m,
      originLat: street.origin_lat,
      originLng: street.origin_lng,
    },
    zones: zones.map((z) => ({
      id: z.id,
      seq: z.seq,
      name: { ar: z.name_ar, en: z.name_en },
      fromM: z.from_m,
      toM: z.to_m,
      active: z.is_active,
      shops: z.shops[0]?.count ?? 0,
    })),
    shops: shops.map((s) => ({
      id: s.id,
      name: { ar: s.name_ar, en: s.name_en || s.name_ar },
      posM: s.pos_m ?? 0,
    })),
  };
}
