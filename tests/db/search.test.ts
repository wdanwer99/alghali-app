import { afterAll, describe, expect, it } from 'vitest';
import {
  connect,
  hasDb,
  skipReason,
  withRollback,
  type Sql,
  type Tx,
  must,
} from '../support/db.ts';
import {
  asAnon,
  asSystem,
  asUser,
  createAdmin,
  createShop,
  createUser,
  failure,
  modelId,
  quickListing,
  variantIds,
} from '../support/fixtures.ts';

type Result = {
  part_id: string;
  name_ar: string;
  fit: 'FITS' | 'CHECK_FITMENT' | null;
  from_sdg: string;
  shop_count: number;
  conditions: string;
  max_discount_percent: number | null;
  listings: { id: string; shop_id: string; price_sdg: number; discount_percent: number | null }[];
  total_count: string;
};

/** Two approved shops selling bulbs: one fits Hilux only, one has no fitment data. */
async function bulbsMarket(tx: Tx) {
  const a = await createUser(tx);
  const b = await createUser(tx);
  const shopA = await createShop(tx, a, { name: 'النور' });
  const shopB = await createShop(tx, b, { name: 'الزين' });
  const hilux = await modelId(tx, 'toyota', 'hilux');
  await asUser(tx, a);
  const hiluxBulb = await quickListing(tx, shopA, {
    name: 'لمبه أمامية هايلكس',
    category: 'lighting',
    price: 12000,
    modelIds: [hilux],
    condition: 'NEW_OEM',
  });
  const anyBulb = await quickListing(tx, shopA, {
    name: 'Bulb H4 universal',
    category: 'lighting',
    price: 8000,
  });
  await asUser(tx, b);
  const bulbB = await quickListing(tx, shopB, {
    name: 'لمبة اشارة',
    category: 'lighting',
    price: 5000,
    qty: 0,
  });
  await asSystem(tx);
  return { shopA, shopB, hiluxBulb, anyBulb, bulbB, hilux };
}

async function search(tx: Tx, args: Record<string, unknown>): Promise<Result[]> {
  const a = {
    q: '',
    variant: null,
    category: null,
    onlyFits: false,
    conditions: null,
    priceMax: null,
    shop: null,
    inStock: true,
    deals: false,
    sort: 'relevance',
    ...args,
  } as Record<string, unknown>;
  return tx<Result[]>`
    select * from public.search_parts(
      p_q => ${a.q as string}, p_variant_id => ${a.variant as string | null},
      p_category_id => ${a.category as string | null}, p_only_fits => ${a.onlyFits as boolean},
      p_conditions => ${a.conditions as string[] | null}::public.listing_condition[],
      p_price_max => ${a.priceMax as number | null}, p_shop_id => ${a.shop as string | null},
      p_in_stock_only => ${a.inStock as boolean}, p_deals_only => ${a.deals as boolean},
      p_sort => ${a.sort as string})`;
}

describe.skipIf(!hasDb)('search', () => {
  const sql: Sql = connect();
  afterAll(() => sql.end());

  it('"لمبات" finds لمبة, لمبه and "bulb" listings (plural, spelling and English)', async () => {
    await withRollback(sql, async (tx) => {
      const m = await bulbsMarket(tx);
      await asAnon(tx);
      const found = await search(tx, { q: 'لمبات', inStock: false });
      const ids = found.map((r) => r.part_id);
      expect(ids).toEqual(
        expect.arrayContaining([m.hiluxBulb.part_id, m.anyBulb.part_id, m.bulbB.part_id]),
      );
      // Catalogue parts without listings never show up.
      expect(found.every((r) => r.listings.length > 0)).toBe(true);
    });
  });

  it('tags fitment for the buyer’s car and hides parts known not to fit', async () => {
    await withRollback(sql, async (tx) => {
      const m = await bulbsMarket(tx);
      const [hiluxVariant] = await variantIds(tx, 'toyota', 'hilux');
      const [sunnyVariant] = await variantIds(tx, 'nissan', 'sunny');
      await asAnon(tx);

      const hilux = await search(tx, { q: 'لمبة', variant: hiluxVariant });
      const fitOf = (rows: Result[], id: string) => rows.find((r) => r.part_id === id)?.fit;
      expect(fitOf(hilux, m.hiluxBulb.part_id)).toBe('FITS');
      expect(fitOf(hilux, m.anyBulb.part_id)).toBe('CHECK_FITMENT');
      expect(hilux[0]?.fit).toBe('FITS'); // parts that fit come first

      const sunny = await search(tx, { q: 'لمبة', variant: sunnyVariant });
      expect(sunny.map((r) => r.part_id)).not.toContain(m.hiluxBulb.part_id);
      expect(fitOf(sunny, m.anyBulb.part_id)).toBe('CHECK_FITMENT');

      const strict = await search(tx, { q: 'لمبة', variant: hiluxVariant, onlyFits: true });
      expect(strict.map((r) => r.part_id)).toEqual([m.hiluxBulb.part_id]);

      const noCar = await search(tx, { q: 'لمبة' });
      expect(noCar.every((r) => r.fit === null)).toBe(true);
    });
  });

  it('filters by stock, condition, price, shop and category', async () => {
    await withRollback(sql, async (tx) => {
      const m = await bulbsMarket(tx);
      const { id: lighting } = must(
        (
          await tx<{ id: string }[]>`select id from public.part_categories where slug = 'lighting'`
        )[0],
      );
      const { id: brakes } = must(
        (
          await tx<{ id: string }[]>`select id from public.part_categories where slug = 'brakes'`
        )[0],
      );
      await asAnon(tx);
      const ids = async (args: Record<string, unknown>) =>
        (await search(tx, args)).map((r) => r.part_id).sort();

      expect(await ids({ q: 'لمبة' })).not.toContain(m.bulbB.part_id); // out of stock
      expect(await ids({ q: 'لمبة', inStock: false })).toContain(m.bulbB.part_id);
      expect(await ids({ q: 'لمبة', conditions: ['NEW_OEM'] })).toEqual([m.hiluxBulb.part_id]);
      expect(await ids({ q: 'لمبة', priceMax: 9000 })).toEqual([m.anyBulb.part_id]);
      expect(await ids({ shop: m.shopB, inStock: false })).toEqual([m.bulbB.part_id]);
      expect(await ids({ category: lighting })).toEqual(
        [m.anyBulb.part_id, m.hiluxBulb.part_id].sort(),
      );
      expect(await ids({ category: brakes })).toEqual([]);
    });
  });

  it('groups offers per part, cheapest first', async () => {
    await withRollback(sql, async (tx) => {
      const m = await bulbsMarket(tx);
      const { id: catalogueBulb } = must(
        (
          await tx<
            { id: string }[]
          >`select id from public.parts where name_en = 'H4 headlight bulb'`
        )[0],
      );
      for (const [shop, price] of [
        [m.shopA, 9000],
        [m.shopB, 7500],
      ] as const) {
        const { user_id: owner } = must(
          (
            await tx<
              { user_id: string }[]
            >`select user_id from public.shop_members where shop_id = ${shop}`
          )[0],
        );
        await asUser(tx, owner);
        await tx`select public.shop_upsert_listing(p_shop_id => ${shop}, p_condition => 'NEW_AFTERMARKET',
                                                   p_stock_qty => 3, p_price_sdg => ${price}, p_part_id => ${catalogueBulb})`;
        await asSystem(tx);
      }
      await asAnon(tx);
      const [h4] = (await search(tx, { q: 'H4' })).filter((r) => r.part_id === catalogueBulb);
      expect(h4).toMatchObject({ from_sdg: '7500', shop_count: 2 });
      expect(must(h4).listings.map((l) => l.price_sdg)).toEqual([7500, 9000]);
    });
  });

  it('sorts by price and pages with a total count', async () => {
    await withRollback(sql, async (tx) => {
      await bulbsMarket(tx);
      await asAnon(tx);
      const low = await search(tx, { q: 'لمبة', inStock: false, sort: 'price_low' });
      expect(low.map((r) => Number(r.from_sdg))).toEqual([5000, 8000, 12000]);
      const high = await search(tx, { q: 'لمبة', inStock: false, sort: 'price_high' });
      expect(high.map((r) => Number(r.from_sdg))).toEqual([12000, 8000, 5000]);
      expect(high.every((r) => r.total_count === '3')).toBe(true);
      expect((await failure(tx, (sp) => search(sp, { sort: 'cheapest' }))).message).toBe(
        'INVALID_SORT',
      );
    });
  });

  it('finds deals: recent price cuts with the discount', async () => {
    await withRollback(sql, async (tx) => {
      const m = await bulbsMarket(tx);
      const { user_id: owner } = must(
        (
          await tx<
            { user_id: string }[]
          >`select user_id from public.shop_members where shop_id = ${m.shopA}`
        )[0],
      );
      await asUser(tx, owner);
      await tx`select public.shop_bulk_update(${m.shopA}, ${tx.json([{ listing_id: m.anyBulb.id, version: 1, price_sdg: 6000 }])})`;
      await asAnon(tx);
      const deals = await search(tx, { deals: true, sort: 'discount' });
      expect(deals.map((r) => r.part_id)).toEqual([m.anyBulb.part_id]);
      expect(deals[0]).toMatchObject({ max_discount_percent: 25 });
      expect(must(deals[0]).listings[0]).toMatchObject({ discount_percent: 25 });
    });
  });

  it('falls back to fuzzy matching for typos', async () => {
    await withRollback(sql, async (tx) => {
      const owner = await createUser(tx);
      const shop = await createShop(tx, owner);
      await asUser(tx, owner);
      const l = await quickListing(tx, shop, {
        name: 'كمبروسر مكيف هايلكس',
        category: 'ac',
        price: 400000,
      });
      await asAnon(tx);
      const found = await search(tx, { q: 'كمبرسور' });
      expect(found.map((r) => r.part_id)).toContain(l.part_id);
    });
  });

  it('hides listings of suspended shops', async () => {
    await withRollback(sql, async (tx) => {
      const m = await bulbsMarket(tx);
      await tx`update public.shops set status = 'SUSPENDED' where id = ${m.shopA}`;
      await asAnon(tx);
      const found = await search(tx, { q: 'لمبة', inStock: false });
      expect(found.map((r) => r.part_id)).toEqual([m.bulbB.part_id]);
    });
  });

  describe('part_detail', () => {
    it('lists every shop’s offer with the shop’s details and the fit', async () => {
      await withRollback(sql, async (tx) => {
        const m = await bulbsMarket(tx);
        const [hiluxVariant] = await variantIds(tx, 'toyota', 'hilux');
        await asAnon(tx);
        const [r] = await tx<
          { d: { part: Record<string, unknown>; listings: { shop: { name_ar: string } }[] } }[]
        >`
          select public.part_detail(${m.hiluxBulb.part_id}, ${must(hiluxVariant)}) as d`;
        expect(r?.d.part).toMatchObject({
          fit: 'FITS',
          job_type_code: 'LIGHTING',
          std_job_minutes: 30,
        });
        expect(r?.d.part.fitment_model_ids).toEqual([m.hilux]);
        expect(r?.d.listings.map((l) => l.shop.name_ar)).toEqual(['النور']);
        const err = await failure(
          tx,
          (sp) => sp`select public.part_detail(${crypto.randomUUID()})`,
        );
        expect(err).toEqual({ code: 'P0002', message: 'PART_NOT_FOUND' });
      });
    });

    it('answers for a merged part with the part it was merged into', async () => {
      await withRollback(sql, async (tx) => {
        const m = await bulbsMarket(tx);
        const admin = await createAdmin(tx);
        const { id: target } = must(
          (
            await tx<{ id: string }[]>`select id from public.parts where name_en = 'Indicator bulb'`
          )[0],
        );
        await asUser(tx, admin);
        await tx`select public.admin_merge_parts(${m.bulbB.part_id}, ${target})`;
        await asAnon(tx);
        const [r] = await tx<
          { d: { part: { id: string } } }[]
        >`select public.part_detail(${m.bulbB.part_id}) as d`;
        expect(r?.d.part.id).toBe(target);
      });
    });
  });

  it('suggest_parts offers verified parts and the shop’s own, never other shops’', async () => {
    await withRollback(sql, async (tx) => {
      const m = await bulbsMarket(tx);
      const { user_id: ownerB } = must(
        (
          await tx<
            { user_id: string }[]
          >`select user_id from public.shop_members where shop_id = ${m.shopB}`
        )[0],
      );
      await asUser(tx, ownerB);
      const rows = await tx<{ id: string; is_verified: boolean }[]>`
        select id, is_verified from public.suggest_parts('لمبة', ${m.shopB}, null, 20)`;
      const ids = rows.map((r) => r.id);
      expect(ids).toContain(m.bulbB.part_id);
      expect(ids).not.toContain(m.hiluxBulb.part_id);
      expect(rows.some((r) => r.is_verified)).toBe(true);
      expect(
        (await failure(tx, (sp) => sp`select * from public.suggest_parts('لمبة', ${m.shopA})`))
          .message,
      ).toBe('FORBIDDEN');
    });
  });

  describe('catalogue_snapshot', () => {
    it('returns the full cache, then only what changed', async () => {
      await withRollback(sql, async (tx) => {
        const m = await bulbsMarket(tx);
        await asAnon(tx);
        const [full] = await tx<
          { s: Record<string, unknown[]> & { full: boolean; server_time: string } }[]
        >`
          select public.catalogue_snapshot() as s`;
        expect(full?.s.full).toBe(true);
        expect(full?.s.makes?.length).toBeGreaterThanOrEqual(10);
        expect(full?.s.zones).toHaveLength(4);
        expect((full?.s.shops as { id: string }[]).map((s) => s.id)).toEqual(
          expect.arrayContaining([m.shopA, m.shopB]),
        );

        // Rows changed after `since` come back, including deactivated ones and suspended shops.
        // (now() is fixed inside a transaction, so "changed" here means changed in this test.)
        await asSystem(tx);
        await tx`update public.vehicle_makes set is_active = false where slug = 'ford'`;
        await tx`update public.shops set status = 'SUSPENDED' where id = ${m.shopA}`;
        await asAnon(tx);
        type Row = { slug?: string; id?: string; status?: string; is_active?: boolean };
        const [delta] = await tx<{ s: Record<string, Row[]> & { full: boolean } }[]>`
          select public.catalogue_snapshot(now() - interval '1 second') as s`;
        expect(delta?.s.full).toBe(false);
        expect(delta?.s.makes).toEqual([
          expect.objectContaining({ slug: 'ford', is_active: false }),
        ]);
        expect(delta?.s.variants).toEqual([]);
        expect(delta?.s.shops).toEqual(
          expect.arrayContaining([
            { id: m.shopA, status: 'SUSPENDED' },
            expect.objectContaining({ id: m.shopB }),
          ]),
        );
        expect(delta?.s.shops).toHaveLength(2);
      });
    });
  });
});

describe.runIf(!hasDb)('search (skipped)', () => {
  it.skip(skipReason, () => undefined);
});
