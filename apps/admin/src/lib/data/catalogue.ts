import 'server-only';
import type { Supabase } from '@/lib/supabase/server';
import { must, type Named } from './util';

export type CatalogueStats = {
  makes: number;
  models: number;
  variants: number;
  parts: number;
  withFitment: number;
};

export type GapPart = { id: string; name: Named; category: Named; listings: number };
export type ShopPart = GapPart & { shop: Named | null; categoryId: string; createdAt: string };
export type Category = {
  id: string;
  name: Named;
  parts: number;
  listings: number;
  active: boolean;
};
export type SynonymGroup = { id: string; terms: string[]; updatedAt: string };
export type MakeWithModels = { id: string; name: Named; models: { id: string; name: Named }[] };
export type PartOption = { id: string; name: Named; categoryId: string };

export type Catalogue = {
  stats: CatalogueStats;
  gaps: GapPart[];
  shopParts: ShopPart[];
  categories: Category[];
  synonyms: SynonymGroup[];
  makes: MakeWithModels[];
  verifiedParts: PartOption[];
};

/** Everything the catalogue screen shows, in one round of parallel queries. */
export async function loadCatalogue(supabase: Supabase): Promise<Catalogue> {
  const [makes, models, variants, rawParts, categories, synonyms] = await Promise.all([
    supabase
      .from('vehicle_makes')
      .select('id, name_ar, name_en, sort')
      .eq('is_active', true)
      .order('sort')
      .then(must),
    supabase
      .from('vehicle_models')
      .select('id, make_id, name_ar, name_en, sort')
      .eq('is_active', true)
      .order('sort')
      .then(must),
    supabase
      .from('vehicle_variants')
      .select('id', { count: 'exact', head: true })
      .eq('is_active', true),
    // Counts are embedded per part, so fitment and listing rows never hit the row limit.
    supabase
      .from('parts')
      .select(
        `id, name_ar, name_en, category_id, is_verified, created_at,
         shop:shops(name_ar, name_en), fitments:part_fitments(count), listings(count)`,
      )
      .eq('is_active', true)
      .is('merged_into', null)
      .is('listings.archived_at', null)
      .eq('listings.is_active', true)
      .then(must),
    supabase
      .from('part_categories')
      .select('id, name_ar, name_en, sort, is_active')
      .order('sort')
      .then(must),
    supabase
      .from('search_synonyms')
      .select('id, terms, updated_at')
      .order('updated_at', { ascending: false })
      .then(must),
  ]);

  const parts = rawParts.map((p) => ({
    ...p,
    fitted: (p.fitments[0]?.count ?? 0) > 0,
    listingCount: p.listings[0]?.count ?? 0,
  }));
  const fittedIds = new Set(parts.filter((p) => p.fitted).map((p) => p.id));
  const listingsByPart = new Map(parts.map((p) => [p.id, p.listingCount]));
  const categoryById = new Map(categories.map((c) => [c.id, { ar: c.name_ar, en: c.name_en }]));
  const name = (p: { name_ar: string; name_en: string }) => ({
    ar: p.name_ar,
    en: p.name_en || p.name_ar,
  });
  const noCategory = { ar: '—', en: '—' };

  const gaps = parts
    .filter((p) => !fittedIds.has(p.id))
    .map((p) => ({
      id: p.id,
      name: name(p),
      category: categoryById.get(p.category_id) ?? noCategory,
      listings: listingsByPart.get(p.id) ?? 0,
    }))
    .sort((a, b) => b.listings - a.listings || a.name.ar.localeCompare(b.name.ar, 'ar'));

  const shopParts = parts
    .filter((p) => !p.is_verified)
    .map((p) => ({
      id: p.id,
      name: name(p),
      category: categoryById.get(p.category_id) ?? noCategory,
      categoryId: p.category_id,
      listings: listingsByPart.get(p.id) ?? 0,
      shop: p.shop ? name(p.shop) : null,
      createdAt: p.created_at,
    }))
    .sort((a, b) => b.createdAt.localeCompare(a.createdAt));

  const partsPerCategory = new Map<string, number>();
  const listingsPerCategory = new Map<string, number>();
  for (const p of parts) {
    partsPerCategory.set(p.category_id, (partsPerCategory.get(p.category_id) ?? 0) + 1);
    listingsPerCategory.set(
      p.category_id,
      (listingsPerCategory.get(p.category_id) ?? 0) + (listingsByPart.get(p.id) ?? 0),
    );
  }

  return {
    stats: {
      makes: makes.length,
      models: models.length,
      variants: variants.count ?? 0,
      parts: parts.length,
      withFitment: parts.filter((p) => fittedIds.has(p.id)).length,
    },
    gaps,
    shopParts,
    categories: categories.map((c) => ({
      id: c.id,
      name: { ar: c.name_ar, en: c.name_en },
      parts: partsPerCategory.get(c.id) ?? 0,
      listings: listingsPerCategory.get(c.id) ?? 0,
      active: c.is_active,
    })),
    synonyms: synonyms.map((s) => ({ id: s.id, terms: s.terms, updatedAt: s.updated_at })),
    makes: makes.map((m) => ({
      id: m.id,
      name: { ar: m.name_ar, en: m.name_en },
      models: models
        .filter((x) => x.make_id === m.id)
        .map((x) => ({ id: x.id, name: { ar: x.name_ar, en: x.name_en } })),
    })),
    verifiedParts: parts
      .filter((p) => p.is_verified)
      .map((p) => ({ id: p.id, name: name(p), categoryId: p.category_id })),
  };
}
