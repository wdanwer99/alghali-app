'use server';

import type { Json } from '@alghali/db-types';
import { refresh } from 'next/cache';
import { requireAdmin } from '@/lib/auth';
import type { ShopStatus } from '@/lib/data/shops';
import { code, done, fail, UUID } from './result';

// ----------------------------------------------------------------------- shops

const STATUSES: ShopStatus[] = ['APPROVED', 'REJECTED', 'SUSPENDED'];

/** Approve, reject, suspend or reinstate a shop; rejecting and suspending need a reason. */
export async function setShopStatus(shopId: string, status: ShopStatus, reason?: string) {
  if (!UUID.test(shopId) || !STATUSES.includes(status)) return fail('INVALID_VALUE');
  const { supabase } = await requireAdmin();
  const { error } = await supabase.rpc('admin_set_shop_status', {
    p_shop_id: shopId,
    p_status: status,
    p_reason: reason?.trim().slice(0, 500) || undefined,
  });
  return done(error);
}

export async function verifyShop(shopId: string, verified: boolean) {
  if (!UUID.test(shopId)) return fail('INVALID_VALUE');
  const { supabase } = await requireAdmin();
  const { error } = await supabase.rpc('admin_verify_shop', {
    p_shop_id: shopId,
    p_verified: verified,
  });
  return done(error);
}

// -------------------------------------------------------------------- settings

/** Saves each changed setting; the database checks every value's shape. */
export async function saveSettings(changes: { key: string; value: Json }[]) {
  if (!Array.isArray(changes) || changes.length === 0 || changes.length > 40) {
    return { ok: false as const, error: 'INVALID_VALUE', failed: [] as string[] };
  }
  const { supabase } = await requireAdmin();
  const failed: string[] = [];
  let firstError = '';
  for (const { key, value } of changes) {
    const { error } = await supabase.rpc('admin_update_setting', {
      p_key: String(key),
      p_value: value,
    });
    if (error) {
      failed.push(key);
      firstError ||= code(error);
    }
  }
  refresh();
  return failed.length
    ? { ok: false as const, error: firstError, failed }
    : { ok: true as const, failed };
}

// ------------------------------------------------------------------- catalogue

function cleanTerms(terms: unknown): string[] | null {
  if (!Array.isArray(terms)) return null;
  const seen = new Set<string>();
  const out: string[] = [];
  for (const t of terms) {
    const word = String(t).trim().replace(/\s+/g, ' ').slice(0, 40);
    if (word && !seen.has(word.toLowerCase())) {
      seen.add(word.toLowerCase());
      out.push(word);
    }
  }
  return out.length >= 2 && out.length <= 40 ? out : null;
}

export async function saveSynonymGroup(id: string | null, terms: string[]) {
  const clean = cleanTerms(terms);
  if (!clean) return fail('SYNONYMS_TOO_FEW');
  if (id !== null && !UUID.test(id)) return fail('INVALID_VALUE');
  const { supabase, admin } = await requireAdmin();
  const row = { terms: clean, updated_by: admin.id };
  const { error } = id
    ? await supabase.from('search_synonyms').update(row).eq('id', id)
    : await supabase.from('search_synonyms').insert(row);
  return done(error);
}

export async function deleteSynonymGroup(id: string) {
  if (!UUID.test(id)) return fail('INVALID_VALUE');
  const { supabase } = await requireAdmin();
  const { error } = await supabase.from('search_synonyms').delete().eq('id', id);
  return done(error);
}

/** Adds every active engine variant of the chosen models to the part's fitment. */
export async function addPartFitment(partId: string, modelIds: string[]) {
  if (
    !UUID.test(partId) ||
    !Array.isArray(modelIds) ||
    modelIds.length === 0 ||
    modelIds.length > 200
  ) {
    return fail('INVALID_VALUE');
  }
  if (!modelIds.every((m) => UUID.test(m))) return fail('INVALID_VALUE');
  const { supabase } = await requireAdmin();
  const { data: variants, error } = await supabase
    .from('vehicle_variants')
    .select('id')
    .in('model_id', modelIds)
    .eq('is_active', true);
  if (error) return fail(code(error));
  if (!variants.length) return fail('NO_VARIANTS');
  const { error: insertError } = await supabase.from('part_fitments').upsert(
    variants.map((v) => ({ part_id: partId, variant_id: v.id })),
    { onConflict: 'part_id,variant_id', ignoreDuplicates: true },
  );
  return done(insertError);
}

/** Accepts a shop's own part into the catalogue as it is. */
export async function verifyPart(partId: string) {
  if (!UUID.test(partId)) return fail('INVALID_VALUE');
  const { supabase } = await requireAdmin();
  const { error } = await supabase.from('parts').update({ is_verified: true }).eq('id', partId);
  return done(error);
}

/** Moves a duplicate's listings onto the catalogue part and retires the duplicate. */
export async function mergePart(fromId: string, intoId: string) {
  if (!UUID.test(fromId) || !UUID.test(intoId)) return fail('INVALID_VALUE');
  const { supabase } = await requireAdmin();
  const { error } = await supabase.rpc('admin_merge_parts', { p_from: fromId, p_into: intoId });
  return done(error);
}

// ---------------------------------------------------------------- alert wording

type Wording = { title: string; body: string };
const ALERT_CODE = /^[A-Z][A-Z_]*$/;
const placeholdersIn = (s: string) => [...s.matchAll(/\{([a-z_]+)\}/g)].map((m) => m[1]);

/**
 * Saves an alert's Arabic and English wording (push and both inboxes use it, D-101).
 * Only the placeholders the alert already uses are allowed: others would show as typed.
 */
export async function saveAlertWording(
  alertCode: string,
  wording: { ar: Wording; en: Wording },
  allowed: string[],
) {
  if (!ALERT_CODE.test(alertCode)) return fail('INVALID_VALUE');
  for (const w of [wording.ar, wording.en]) {
    const title = w.title.trim();
    const body = w.body.trim();
    if (title.length < 1 || title.length > 100 || body.length < 1 || body.length > 300) {
      return fail('INVALID_VALUE');
    }
    if (placeholdersIn(`${title} ${body}`).some((p) => !allowed.includes(p as string))) {
      return fail('UNKNOWN_PLACEHOLDER');
    }
  }
  const { supabase } = await requireAdmin();
  for (const locale of ['ar', 'en'] as const) {
    const { error } = await supabase.from('notification_templates').upsert({
      code: alertCode,
      locale,
      title: wording[locale].title.trim(),
      body: wording[locale].body.trim(),
    });
    if (error) return done(error);
  }
  return done(null);
}
