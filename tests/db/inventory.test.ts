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
  categoryId,
  createAdmin,
  createShop,
  createUser,
  failure,
  modelId,
  quickListing,
  variantIds,
} from '../support/fixtures.ts';

type Listing = {
  id: string;
  version: number;
  part_id: string;
  price_sdg: number | null;
  was_sdg: number | null;
  stock_qty: number;
  available_qty: number;
  is_active: boolean;
  part: { own: boolean; is_verified: boolean; model_ids: string[]; installable: boolean };
  images: string[];
};

async function edit(tx: Tx, shop: string, listing: Listing, changes: Record<string, unknown>) {
  const p = {
    price: listing.price_sdg,
    qty: listing.stock_qty,
    version: listing.version,
    ...changes,
  };
  const [row] = await tx<{ r: Listing }[]>`
    select public.shop_upsert_listing(
      p_shop_id => ${shop}, p_listing_id => ${listing.id}, p_version => ${p.version as number},
      p_condition => 'NEW_AFTERMARKET', p_stock_qty => ${p.qty as number}, p_price_sdg => ${p.price as number}
    ) as r`;
  return must(row).r;
}

describe.skipIf(!hasDb)('inventory', () => {
  const sql: Sql = connect();
  afterAll(() => sql.end());

  describe('quick listing', () => {
    it('creates the shop’s own part with fitment for every engine of the chosen models', async () => {
      await withRollback(sql, async (tx) => {
        const owner = await createUser(tx);
        const shop = await createShop(tx, owner);
        const hilux = await modelId(tx, 'toyota', 'hilux');
        await asUser(tx, owner);
        const l = (await quickListing(tx, shop, {
          name: 'فحمات هايلكس أمامية',
          category: 'brakes',
          price: 38000,
          qty: 4,
          modelIds: [hilux],
        })) as unknown as Listing;
        expect(l).toMatchObject({
          version: 1,
          price_sdg: 38000,
          available_qty: 4,
          is_active: true,
        });
        expect(l.part).toMatchObject({
          own: true,
          is_verified: false,
          model_ids: [hilux],
          installable: true,
        });

        await asSystem(tx);
        const fit =
          await tx`select variant_id from public.part_fitments where part_id = ${l.part_id}`;
        expect(fit.map((r) => r.variant_id).sort()).toEqual(
          (await variantIds(tx, 'toyota', 'hilux')).sort(),
        );
      });
    });

    it('"not sure which cars" leaves fitment empty; accessories are not installable', async () => {
      await withRollback(sql, async (tx) => {
        const owner = await createUser(tx);
        const shop = await createShop(tx, owner);
        await asUser(tx, owner);
        const l = (await quickListing(tx, shop, {
          name: 'كسوة جلد',
          category: 'accessories',
        })) as unknown as Listing;
        expect(l.part).toMatchObject({ model_ids: [], installable: false });
      });
    });

    it('is visible to the public only once the shop is approved', async () => {
      await withRollback(sql, async (tx) => {
        const owner = await createUser(tx);
        const shop = await createShop(tx, owner, { status: 'PENDING' });
        await asUser(tx, owner);
        const l = await quickListing(tx, shop, { name: 'لمبة H4', category: 'lighting' });
        expect(await tx`select id from public.listings where id = ${l.id}`).toHaveLength(1);
        await asAnon(tx);
        expect(await tx`select id from public.listings where id = ${l.id}`).toHaveLength(0);
        await asSystem(tx);
        await tx`update public.shops set status = 'APPROVED' where id = ${shop}`;
        await asAnon(tx);
        expect(await tx`select id from public.listings where id = ${l.id}`).toHaveLength(1);
      });
    });

    it('needs a price unless it is "price on request"', async () => {
      await withRollback(sql, async (tx) => {
        const owner = await createUser(tx);
        const shop = await createShop(tx, owner);
        const cat = await categoryId(tx, 'engine');
        await asUser(tx, owner);
        const part = tx.json({ name_ar: 'مكينة كاملة', category_id: cat });
        const err = await failure(
          tx,
          (sp) => sp`
          select public.shop_upsert_listing(p_shop_id => ${shop}, p_condition => 'USED', p_stock_qty => 1,
                                            p_new_part => ${part})`,
        );
        expect(err).toEqual({ code: '22023', message: 'PRICE_REQUIRED' });
        const [r] = await tx<{ r: Listing }[]>`
          select public.shop_upsert_listing(p_shop_id => ${shop}, p_condition => 'USED', p_stock_qty => 1,
                                            p_price_on_request => true, p_new_part => ${part}) as r`;
        expect(r?.r.price_sdg).toBeNull();
      });
    });

    it('can use a verified catalogue part but not another shop’s own part', async () => {
      await withRollback(sql, async (tx) => {
        const a = await createUser(tx);
        const b = await createUser(tx);
        const shopA = await createShop(tx, a);
        const shopB = await createShop(tx, b);
        const [catalogue] =
          await tx`select id from public.parts where name_en = 'Oil filter' and is_verified`;
        await asUser(tx, a);
        const own = await quickListing(tx, shopA, { name: 'فلتر خاص', category: 'oil-filters' });
        await asUser(tx, b);
        const use = (part: string) => (sp: Tx) => sp`
          select public.shop_upsert_listing(p_shop_id => ${shopB}, p_condition => 'NEW_OEM', p_stock_qty => 3,
                                            p_price_sdg => 9000, p_part_id => ${part})`;
        await use(must(catalogue).id)(tx);
        expect((await failure(tx, use(own.part_id))).message).toBe('PART_NOT_FOUND');
      });
    });

    it('only the shop’s members may list, and not while suspended', async () => {
      await withRollback(sql, async (tx) => {
        const owner = await createUser(tx);
        const stranger = await createUser(tx);
        const shop = await createShop(tx, owner);
        await asUser(tx, stranger);
        expect(
          (await failure(tx, (sp) => quickListing(sp, shop, { name: 'x', category: 'brakes' })))
            .message,
        ).toBe('FORBIDDEN');
        await asSystem(tx);
        await tx`update public.shops set status = 'SUSPENDED' where id = ${shop}`;
        await asUser(tx, owner);
        expect(
          (await failure(tx, (sp) => quickListing(sp, shop, { name: 'x', category: 'brakes' })))
            .message,
        ).toBe('SHOP_NOT_ACTIVE');
      });
    });

    it('keeps SKUs unique within a shop', async () => {
      await withRollback(sql, async (tx) => {
        const owner = await createUser(tx);
        const shop = await createShop(tx, owner);
        const cat = await categoryId(tx, 'brakes');
        await asUser(tx, owner);
        const add = (sp: Tx) => sp`
          select public.shop_upsert_listing(p_shop_id => ${shop}, p_condition => 'NEW_OEM', p_stock_qty => 1,
                                            p_price_sdg => 100, p_sku => 'BR-1',
                                            p_new_part => ${sp.json({ name_ar: 'فحمات', category_id: cat })})`;
        await add(tx);
        expect(await failure(tx, add)).toEqual({ code: 'PT409', message: 'SKU_TAKEN' });
      });
    });
  });

  describe('editing', () => {
    it('needs the latest version; stale edits get VERSION_CONFLICT', async () => {
      await withRollback(sql, async (tx) => {
        const owner = await createUser(tx);
        const shop = await createShop(tx, owner);
        await asUser(tx, owner);
        const l = (await quickListing(tx, shop, {
          name: 'بطارية',
          category: 'batteries',
          price: 140000,
        })) as unknown as Listing;
        const v2 = await edit(tx, shop, l, { qty: 9 });
        expect(v2).toMatchObject({ version: 2, stock_qty: 9 });
        const err = await failure(tx, (sp) => edit(sp, shop, l, { qty: 1 }));
        expect(err).toEqual({ code: 'PT409', message: 'VERSION_CONFLICT' });
      });
    });

    it('a price cut records history and shows the old price as a deal; a rise clears it', async () => {
      await withRollback(sql, async (tx) => {
        const owner = await createUser(tx);
        const shop = await createShop(tx, owner);
        await asUser(tx, owner);
        const l = (await quickListing(tx, shop, {
          name: 'بطارية',
          category: 'batteries',
          price: 52000,
        })) as unknown as Listing;
        const cut = await edit(tx, shop, l, { price: 45000 });
        expect(cut).toMatchObject({ price_sdg: 45000, was_sdg: 52000 });
        const cut2 = await edit(tx, shop, cut, { price: 44000 });
        expect(cut2.was_sdg).toBe(52000);
        const rise = await edit(tx, shop, cut2, { price: 50000 });
        expect(rise.was_sdg).toBeNull();
        const history =
          await tx`select old_sdg, new_sdg, changed_by from public.listing_price_history
                                 where listing_id = ${l.id} order by id`;
        expect(history).toEqual([
          { old_sdg: '52000', new_sdg: '45000', changed_by: owner },
          { old_sdg: '45000', new_sdg: '44000', changed_by: owner },
          { old_sdg: '44000', new_sdg: '50000', changed_by: owner },
        ]);
      });
    });

    it('stock reserved by checkout does not bump the version, and stock cannot drop below it', async () => {
      await withRollback(sql, async (tx) => {
        const owner = await createUser(tx);
        const shop = await createShop(tx, owner);
        await asUser(tx, owner);
        const l = (await quickListing(tx, shop, {
          name: 'بطارية',
          category: 'batteries',
          qty: 5,
        })) as unknown as Listing;
        await asSystem(tx);
        await tx`update public.listings set reserved_qty = 3 where id = ${l.id}`;
        expect((await tx`select version from public.listings where id = ${l.id}`)[0]?.version).toBe(
          1,
        );
        await asUser(tx, owner);
        const err = await failure(tx, (sp) => edit(sp, shop, l, { qty: 2 }));
        expect(err.message).toBe('STOCK_BELOW_RESERVED');
        expect((await edit(tx, shop, l, { qty: 3 })).available_qty).toBe(0);
      });
    });

    it('editing a listing with a typed-in part renames that part instead of creating another', async () => {
      await withRollback(sql, async (tx) => {
        const owner = await createUser(tx);
        const shop = await createShop(tx, owner);
        const cat = await categoryId(tx, 'lighting');
        const corolla = await modelId(tx, 'toyota', 'corolla');
        await asUser(tx, owner);
        const l = await quickListing(tx, shop, { name: 'لمبه', category: 'lighting' });
        const [r] = await tx<{ r: Listing & { part: { name_ar: string } } }[]>`
          select public.shop_upsert_listing(
            p_shop_id => ${shop}, p_listing_id => ${l.id}, p_version => 1, p_condition => 'NEW_OEM',
            p_stock_qty => 2, p_price_sdg => 12000,
            p_new_part => ${tx.json({ name_ar: 'لمبة H4 هالوجين', category_id: cat, model_ids: [corolla] })}) as r`;
        expect(r?.r.part_id).toBe(l.part_id);
        expect(r?.r.part).toMatchObject({ name_ar: 'لمبة H4 هالوجين', model_ids: [corolla] });
      });
    });
  });

  describe('bulk update', () => {
    it('applies each item on its own and reports conflicts with the current values', async () => {
      await withRollback(sql, async (tx) => {
        const owner = await createUser(tx);
        const shop = await createShop(tx, owner);
        const other = await createShop(tx, await createUser(tx));
        await asUser(tx, owner);
        const a = await quickListing(tx, shop, {
          name: 'فحمات أ',
          category: 'brakes',
          price: 1000,
          qty: 1,
        });
        const b = await quickListing(tx, shop, {
          name: 'فحمات ب',
          category: 'brakes',
          price: 2000,
          qty: 2,
        });
        await asSystem(tx);
        const [foreign] = await tx`select id from public.listings where shop_id = ${other} limit 1`;
        await asUser(tx, owner);
        const items = [
          { listing_id: a.id, version: 1, price_sdg: 1500, stock_qty: 10 },
          { listing_id: b.id, version: 7, price_sdg: 2500 },
          { listing_id: foreign?.id ?? crypto.randomUUID(), version: 1, stock_qty: 1 },
          { listing_id: a.id, version: 2, stock_qty: -1 },
          { listing_id: a.id, version: 2, is_active: false },
        ];
        const [r] = await tx<{ r: { results: Record<string, unknown>[] } }[]>`
          select public.shop_bulk_update(${shop}, ${tx.json(items)}) as r`;
        expect(r?.r.results).toEqual([
          { listing_id: a.id, ok: true, error: null, version: 2, current: null },
          {
            listing_id: b.id,
            ok: false,
            error: 'VERSION_CONFLICT',
            version: 1,
            current: { price_sdg: 2000, stock_qty: 2, is_active: true },
          },
          expect.objectContaining({ ok: false, error: 'LISTING_NOT_FOUND' }),
          expect.objectContaining({ ok: false, error: 'INVALID_QTY' }),
          { listing_id: a.id, ok: true, error: null, version: 3, current: null },
        ]);
        const [row] =
          await tx`select price_sdg, stock_qty, is_active from public.listings where id = ${a.id}`;
        expect(row).toEqual({ price_sdg: '1500', stock_qty: 10, is_active: false });
      });
    });
  });

  describe('photos and archive', () => {
    it('accepts only keys under the shop’s own folder, at most 6', async () => {
      await withRollback(sql, async (tx) => {
        const owner = await createUser(tx);
        const shop = await createShop(tx, owner);
        await asUser(tx, owner);
        const l = await quickListing(tx, shop, { name: 'مراية', category: 'body' });
        const key = (n = crypto.randomUUID()) => `shops/${shop}/listings/${n}`;
        const keys = [key(), key()];
        const [r] = await tx<{ r: Listing }[]>`
          select public.shop_set_listing_images(${shop}, ${l.id}, ${keys}::text[]) as r`;
        expect(r?.r.images).toEqual(keys);
        const set = (k: string[]) => (sp: Tx) =>
          sp`select public.shop_set_listing_images(${shop}, ${l.id}, ${k}::text[])`;
        expect(
          (await failure(tx, set([`shops/${crypto.randomUUID()}/listings/${crypto.randomUUID()}`])))
            .message,
        ).toBe('INVALID_IMAGE_KEY');
        expect((await failure(tx, set(Array.from({ length: 7 }, () => key())))).message).toBe(
          'TOO_MANY_IMAGES',
        );
      });
    });

    it('archived listings leave the stock list and public reads', async () => {
      await withRollback(sql, async (tx) => {
        const owner = await createUser(tx);
        const shop = await createShop(tx, owner);
        await asUser(tx, owner);
        const keep = await quickListing(tx, shop, { name: 'فحمات أمامية', category: 'brakes' });
        const gone = await quickListing(tx, shop, { name: 'فحمات خلفية', category: 'brakes' });
        await tx`select public.shop_archive_listing(${shop}, ${gone.id})`;
        const stock = await tx<
          { j: { id: string } }[]
        >`select j from public.shop_listings(${shop}) j`;
        expect(stock.map((r) => r.j.id)).toEqual([keep.id]);
        const found = await tx<
          { j: { id: string } }[]
        >`select j from public.shop_listings(${shop}, 'فحمات') j`;
        expect(found.map((r) => r.j.id)).toEqual([keep.id]);
        await asAnon(tx);
        expect(await tx`select id from public.listings where id = ${gone.id}`).toHaveLength(0);
      });
    });
  });

  describe('Excel import', () => {
    const rows = (extra: Record<string, unknown>[] = []) => [
      {
        row: 2,
        sku: 'P-1',
        name_ar: 'فحمات أمامية',
        category: 'الفرامل',
        condition: 'NEW_OEM',
        price_sdg: 65000,
        stock_qty: 10,
        warranty_days: 180,
        models: ['هايلكس'],
      },
      {
        row: 3,
        name_ar: 'زيت محرك 5W-30',
        category: 'oil-filters',
        condition: 'NEW_AFTERMARKET',
        price_sdg: 42000,
        stock_qty: 60,
        brand: 'Shell',
      },
      {
        row: 4,
        name_ar: 'كمبروسر',
        category: 'Air conditioning',
        condition: 'USED',
        price_sdg: 190000,
        stock_qty: 1,
        models: ['تويوتا هايلكس', 'Spaceship'],
      },
      {
        row: 5,
        name_ar: 'شيء',
        category: 'غير موجود',
        condition: 'NEW_OEM',
        price_sdg: 1,
        stock_qty: 1,
      },
      {
        row: 6,
        name_ar: 'شيء',
        category: 'brakes',
        condition: 'BROKEN',
        price_sdg: 1,
        stock_qty: 1,
      },
      { row: 7, name_ar: 'شيء', category: 'brakes', condition: 'USED', stock_qty: 1 },
      { row: 8, name_ar: '', category: 'brakes', condition: 'USED', price_sdg: 5, stock_qty: 1 },
      ...extra,
    ];

    it('creates listings, skips bad rows with a reason, and warns about unknown models', async () => {
      await withRollback(sql, async (tx) => {
        const owner = await createUser(tx);
        const shop = await createShop(tx, owner);
        const hilux = await modelId(tx, 'toyota', 'hilux');
        await asUser(tx, owner);
        const [r] = await tx<{ r: Record<string, unknown> }[]>`
          select public.shop_import_rows(${shop}, ${tx.json(rows() as never)}, false, 'stock.xlsx') as r`;
        expect(r?.r).toMatchObject({
          total: 7,
          created: 3,
          updated: 0,
          failed: 4,
          dry_run: false,
          errors: [
            { row: 5, code: 'CATEGORY_NOT_FOUND' },
            { row: 6, code: 'INVALID_CONDITION' },
            { row: 7, code: 'PRICE_REQUIRED' },
            { row: 8, code: 'NAME_REQUIRED' },
          ],
          warnings: [{ row: 4, code: 'MODEL_NOT_FOUND', value: 'Spaceship' }],
        });
        expect(r?.r.job_id).toBeTruthy();
        const listing = await tx<
          { j: Listing & { sku: string } }[]
        >`select j from public.shop_listings(${shop}) j`;
        const bySku = must(
          listing.find((x) => x.j.sku === 'P-1'),
          'listing P-1',
        ).j;
        expect(bySku.part.model_ids).toEqual([hilux]);
        const jobs =
          await tx`select file_name, created, failed from public.import_jobs where shop_id = ${shop}`;
        expect(jobs).toEqual([{ file_name: 'stock.xlsx', created: 3, failed: 4 }]);
      });
    });

    it('a re-import updates by SKU, or by name + condition + brand', async () => {
      await withRollback(sql, async (tx) => {
        const owner = await createUser(tx);
        const shop = await createShop(tx, owner);
        await asUser(tx, owner);
        await tx`select public.shop_import_rows(${shop}, ${tx.json(rows().slice(0, 3) as never)})`;
        const again = [
          {
            row: 2,
            sku: 'P-1',
            name_ar: 'فحمات أمامية (أصلي)',
            category: 'brakes',
            condition: 'NEW_OEM',
            price_sdg: 60000,
            stock_qty: 3,
          },
          {
            row: 3,
            name_ar: 'زيت محرك 5w-30',
            category: 'oil-filters',
            condition: 'NEW_AFTERMARKET',
            price_sdg: 40000,
            stock_qty: 50,
            brand: 'shell',
          },
          {
            row: 4,
            name_ar: 'زيت محرك 5W-30',
            category: 'oil-filters',
            condition: 'NEW_AFTERMARKET',
            price_sdg: 41000,
            stock_qty: 5,
            brand: 'Total',
          },
        ];
        const [r] = await tx<
          { r: Record<string, unknown> }[]
        >`select public.shop_import_rows(${shop}, ${tx.json(again)}) as r`;
        expect(r?.r).toMatchObject({ created: 1, updated: 2, failed: 0 });
        const stock = await tx<{ j: Listing & { sku: string | null; brand: string | null } }[]>`
          select j from public.shop_listings(${shop}) j`;
        expect(stock).toHaveLength(4);
        expect(stock.find((x) => x.j.sku === 'P-1')?.j).toMatchObject({
          price_sdg: 60000,
          stock_qty: 3,
        });
        expect(stock.find((x) => x.j.brand === 'shell')?.j).toMatchObject({
          price_sdg: 40000,
          was_sdg: 42000,
        });
      });
    });

    it('a dry run reports without changing anything', async () => {
      await withRollback(sql, async (tx) => {
        const owner = await createUser(tx);
        const shop = await createShop(tx, owner);
        await asUser(tx, owner);
        const [r] = await tx<{ r: Record<string, unknown> }[]>`
          select public.shop_import_rows(${shop}, ${tx.json(rows() as never)}, true) as r`;
        expect(r?.r).toMatchObject({ created: 3, failed: 4, dry_run: true });
        expect(r?.r.job_id).toBeUndefined();
        expect(await tx`select j from public.shop_listings(${shop}) j`).toHaveLength(0);
        expect(await tx`select id from public.import_jobs where shop_id = ${shop}`).toHaveLength(0);
      });
    });

    it('refuses more than 2000 rows', async () => {
      await withRollback(sql, async (tx) => {
        const owner = await createUser(tx);
        const shop = await createShop(tx, owner);
        await asUser(tx, owner);
        const many = Array.from({ length: 2001 }, (_, i) => ({ row: i + 2 }));
        const err = await failure(
          tx,
          (sp) => sp`select public.shop_import_rows(${shop}, ${sp.json(many)})`,
        );
        expect(err.message).toBe('TOO_MANY_ROWS');
      });
    });
  });

  describe('admin merge', () => {
    it('moves a shop part’s listings onto the catalogue part and retires it', async () => {
      await withRollback(sql, async (tx) => {
        const owner = await createUser(tx);
        const admin = await createAdmin(tx);
        const shop = await createShop(tx, owner);
        const [target] =
          await tx`select id from public.parts where name_en = 'Front brake pads' and is_verified`;
        await asUser(tx, owner);
        const l = await quickListing(tx, shop, {
          name: 'فحمات قدام',
          category: 'brakes',
          modelIds: [await modelId(tx, 'kia', 'rio')],
        });
        await asUser(tx, owner);
        expect(
          (
            await failure(
              tx,
              (sp) => sp`select public.admin_merge_parts(${l.part_id}, ${must(target).id})`,
            )
          ).message,
        ).toBe('FORBIDDEN');
        await asUser(tx, admin);
        await tx`select public.admin_merge_parts(${l.part_id}, ${must(target).id})`;
        await asSystem(tx);
        expect((await tx`select part_id from public.listings where id = ${l.id}`)[0]?.part_id).toBe(
          must(target).id,
        );
        const [old] =
          await tx`select merged_into, is_active from public.parts where id = ${l.part_id}`;
        expect(old).toEqual({ merged_into: must(target).id, is_active: false });
        // The catalogue part had no fitment, so it borrows the shop's.
        expect(
          await tx`select 1 from public.part_fitments where part_id = ${must(target).id}`,
        ).not.toHaveLength(0);
      });
    });
  });
});

describe.runIf(!hasDb)('inventory (skipped)', () => {
  it.skip(skipReason, () => undefined);
});
