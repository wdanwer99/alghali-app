'use server';

import { requireAdmin } from '@/lib/auth';
import { code, done, fail, UUID, type ActionResult } from './result';

export type StreetInput = {
  market: { id: string; name_ar: string; name_en: string; city_ar: string; city_en: string };
  street: {
    id: string;
    name_ar: string;
    name_en: string;
    length_m: number;
    origin_lat: number | null;
    origin_lng: number | null;
  };
  /** `id` null = a new zone. */
  zones: {
    id: string | null;
    seq: number;
    name_ar: string;
    name_en: string;
    from_m: number;
    to_m: number;
    is_active: boolean;
  }[];
  removed: string[];
};

const text = (s: unknown, max: number) => (typeof s === 'string' ? s.trim().slice(0, max) : '');
const int = (n: unknown) => typeof n === 'number' && Number.isInteger(n);

/** Checks the whole street before writing anything; returns an error code or null. */
function check(input: StreetInput): string | null {
  const { market, street, zones, removed } = input;
  if (!UUID.test(market?.id) || !UUID.test(street?.id)) return 'INVALID_VALUE';
  if (!text(market.name_ar, 80) || !text(market.name_en, 80)) return 'NAME_REQUIRED';
  if (!text(street.name_ar, 80) || !text(street.name_en, 80)) return 'NAME_REQUIRED';
  if (!int(street.length_m) || street.length_m < 1 || street.length_m > 100000)
    return 'INVALID_VALUE';
  const hasLat = street.origin_lat !== null;
  if (hasLat !== (street.origin_lng !== null)) return 'INVALID_LOCATION';
  if (
    hasLat &&
    !(Math.abs(street.origin_lat as number) <= 90 && Math.abs(street.origin_lng as number) <= 180)
  ) {
    return 'INVALID_LOCATION';
  }
  if (!Array.isArray(zones) || zones.length === 0 || zones.length > 50) return 'INVALID_VALUE';
  if (!Array.isArray(removed) || !removed.every((id) => UUID.test(id))) return 'INVALID_VALUE';
  const seqs = new Set<number>();
  for (const z of zones) {
    if (z.id !== null && !UUID.test(z.id)) return 'INVALID_VALUE';
    if (!int(z.seq) || z.seq < 1 || seqs.has(z.seq)) return 'INVALID_VALUE';
    seqs.add(z.seq);
    if (!text(z.name_ar, 80) || !text(z.name_en, 80)) return 'NAME_REQUIRED';
    if (
      !int(z.from_m) ||
      !int(z.to_m) ||
      z.from_m < 0 ||
      z.to_m <= z.from_m ||
      z.to_m > street.length_m
    ) {
      return 'ZONE_OUT_OF_RANGE';
    }
  }
  return null;
}

/**
 * Saves the market's city, the street (name, length, GPS starting point) and its
 * zones. Admins write these tables directly (D-068); every change is audited.
 */
export async function saveStreet(input: StreetInput): Promise<ActionResult> {
  const problem = check(input);
  if (problem) return fail(problem);
  const { supabase } = await requireAdmin();
  const { market, street, zones, removed } = input;

  const steps = [
    () =>
      supabase
        .from('markets')
        .update({
          name_ar: text(market.name_ar, 80),
          name_en: text(market.name_en, 80),
          city_ar: text(market.city_ar, 80),
          city_en: text(market.city_en, 80),
        })
        .eq('id', market.id),
    () =>
      supabase
        .from('streets')
        .update({
          name_ar: text(street.name_ar, 80),
          name_en: text(street.name_en, 80),
          length_m: street.length_m,
          origin_lat: street.origin_lat,
          origin_lng: street.origin_lng,
        })
        .eq('id', street.id),
    // A zone that still has shops can't go; the foreign key says so (23503).
    ...(removed.length ? [() => supabase.from('zones').delete().in('id', removed)] : []),
    ...zones.map((z) => () => {
      const row = {
        seq: z.seq,
        name_ar: text(z.name_ar, 80),
        name_en: text(z.name_en, 80),
        from_m: z.from_m,
        to_m: z.to_m,
        is_active: z.is_active,
      };
      return z.id
        ? supabase.from('zones').update(row).eq('id', z.id).eq('street_id', street.id)
        : supabase.from('zones').insert({ ...row, street_id: street.id });
    }),
  ];

  for (const step of steps) {
    const { error } = await step();
    if (error)
      return fail(
        error.code === '23503'
          ? 'ZONE_HAS_SHOPS'
          : error.code === '23505'
            ? 'INVALID_VALUE'
            : code(error),
      );
  }
  return done(null);
}
