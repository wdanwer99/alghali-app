import { afterAll, describe, expect, it } from 'vitest';
import {
  connect,
  hasDb,
  must,
  skipReason,
  withRollback,
  type Sql,
  type Tx,
} from '../support/db.ts';
import { asAnon, asSystem, asUser, createShop, createUser, failure } from '../support/fixtures.ts';
import {
  accept,
  addAddress,
  createTechnician,
  heldFor,
  hold,
  jobCode,
  khartoumAt,
  setStreetOrigin,
  shopOwed,
  techBalance,
  type BookingJson,
} from '../support/bookings.ts';
import { createBuyer, unbalancedJournals, type OrderJson } from '../support/commerce.ts';

// D-149: a shop's tint offer, tint lines in the cart, and tint fittings at the shop's
// own bay or at the buyer's place.
const FULL_SALOON = 60000;
const WINDOW_SALOON = 9000;
const LABOUR = 8000;
const FEE = 2000; // booking_fee_sdg default

const choice = { car_size: 'SALOON', package: 'FULL', darkness: 50, colour: 'BLACK' };

/** An approved shop that tints saloons: full car, sides, and single windows. */
async function tintShop(tx: Tx): Promise<{ owner: string; shopId: string }> {
  const owner = await createUser(tx);
  const shopId = await createShop(tx, owner, { name: 'محل التظليل' });
  await asUser(tx, owner);
  await tx`select public.shop_set_tint(${shopId}, true, array[30, 50, 100], array['BLACK', 'SMOKE'],
             ${tx.json([
               { car_size: 'SALOON', item: 'FULL', price_sdg: FULL_SALOON },
               { car_size: 'SALOON', item: 'SIDES', price_sdg: 40000 },
               { car_size: 'SALOON', item: 'WINDOW', price_sdg: WINDOW_SALOON },
             ] as never)})`;
  return { owner, shopId };
}

const tintLine = (shopId: string, seen = FULL_SALOON, tint: object = choice) => ({
  tint_shop_id: shopId,
  tint,
  qty: 1,
  seen_price_sdg: seen,
});

async function validate(tx: Tx, lines: object[]) {
  const [row] = await tx<{ r: Record<string, unknown>[] }[]>`
    select public.cart_validate(${tx.json(lines as never)}) as r`;
  return must(row).r;
}

describe.skipIf(!hasDb)('window tint', { timeout: 90_000 }, () => {
  const sql: Sql = connect();
  afterAll(() => sql.end());

  it('a choice is checked and kept in one form: ticked windows that make a package become it', async () => {
    await withRollback(sql, async (tx) => {
      const norm = async (c: object) => {
        const [row] = await tx<
          { c: object }[]
        >`select public.tint_choice(${tx.json(c as never)}) as c`;
        return must(row).c;
      };
      const sides = ['FRONT_LEFT', 'BACK_RIGHT', 'FRONT_RIGHT', 'BACK_LEFT', 'FRONT_LEFT'];
      expect(await norm({ ...choice, package: undefined, windows: sides })).toEqual({
        ...choice,
        package: 'SIDES',
      });
      expect(
        await norm({
          car_size: 'SUV',
          windows: ['WINDSCREEN', 'SUNROOF'],
          darkness: 30,
          colour: 'SMOKE',
        }),
      ).toEqual({
        car_size: 'SUV',
        windows: ['SUNROOF', 'WINDSCREEN'],
        darkness: 30,
        colour: 'SMOKE',
      });
      for (const bad of [
        { ...choice, car_size: 'TRUCK' },
        { ...choice, darkness: 0 },
        { ...choice, colour: 'PINK' },
        { ...choice, package: 'ROOF' },
        { ...choice, windows: ['WINDSCREEN'] }, // package and windows
        { car_size: 'SALOON', windows: [], darkness: 50, colour: 'BLACK' },
      ]) {
        expect(
          await failure(tx, (sp) => sp`select public.tint_choice(${sp.json(bad as never)})`),
        ).toMatchObject({
          message: 'INVALID_TINT',
        });
      }
    });
  });

  it('a shop sets its offer; only its members can, and offering needs a price', async () => {
    await withRollback(sql, async (tx) => {
      const { owner, shopId } = await tintShop(tx);
      const [row] = await tx<
        {
          s: { is_active: boolean; darkness: number[]; prices: unknown[]; bay_technicians: number };
        }[]
      >`
        select public.shop_tint_settings(${shopId}) as s`;
      expect(must(row).s).toMatchObject({
        is_active: true,
        darkness: [30, 50, 100],
        bay_technicians: 0,
      });
      expect(must(row).s.prices).toHaveLength(3);

      expect(
        await failure(
          tx,
          (sp) => sp`select public.shop_set_tint(${shopId}, true, array[50], array['BLACK'], '[]')`,
        ),
      ).toMatchObject({ message: 'TINT_PRICE_REQUIRED' });
      expect(
        await failure(
          tx,
          (sp) => sp`select public.shop_set_tint(${shopId}, true, array[50], array['PINK'],
                       ${sp.json([{ car_size: 'SALOON', item: 'FULL', price_sdg: 1 }] as never)})`,
        ),
      ).toMatchObject({ message: 'INVALID_TINT' });

      await asUser(tx, await createUser(tx));
      expect(
        await failure(tx, (sp) => sp`select public.shop_tint_settings(${shopId})`),
      ).toMatchObject({
        message: 'FORBIDDEN',
      });
      // Switching it off keeps nothing on offer.
      await asUser(tx, owner);
      await tx`select public.shop_set_tint(${shopId}, false, '{}', '{}', '[]')`;
      await asAnon(tx);
      const [offers] = await tx<
        { o: { shops: unknown[] } }[]
      >`select public.tint_offers('SALOON', 'FULL') as o`;
      expect(
        must(offers).o.shops.filter((s) => (s as { shop_id: string }).shop_id === shopId),
      ).toEqual([]);
    });
  });

  it('buyers (guests too) see which shops tint at what price, and whether they fit it at the shop', async () => {
    await withRollback(sql, async (tx) => {
      const { shopId } = await tintShop(tx);
      await createTechnician(tx, { mode: 'BAY', bayShopId: shopId, jobs: { TINT: LABOUR } });
      await asAnon(tx);
      type Offers = {
        choice: object;
        shops: { shop_id: string; price_sdg: number; at_shop: boolean; colours: string[] }[];
      };
      const offers = async (windows: string[]) => {
        const [row] = await tx<
          { o: Offers }[]
        >`select public.tint_offers('SALOON', null, ${windows}) as o`;
        return must(row).o;
      };
      const three = await offers(['WINDSCREEN', 'BACK_GLASS', 'SUNROOF']);
      expect(three.shops.find((s) => s.shop_id === shopId)).toMatchObject({
        price_sdg: 3 * WINDOW_SALOON,
        at_shop: true,
        colours: ['BLACK', 'SMOKE'],
      });
      // Every window: the full-car price, not six windows.
      const all = await offers([
        'WINDSCREEN',
        'BACK_GLASS',
        'FRONT_LEFT',
        'FRONT_RIGHT',
        'BACK_LEFT',
        'BACK_RIGHT',
      ]);
      expect(all.choice).toEqual({ car_size: 'SALOON', package: 'FULL' });
      expect(all.shops.find((s) => s.shop_id === shopId)?.price_sdg).toBe(FULL_SALOON);
      // Not priced for 4x4s: not listed.
      const [suv] = await tx<{ o: Offers }[]>`select public.tint_offers('SUV', 'FULL') as o`;
      expect(must(suv).o.shops.some((s) => s.shop_id === shopId)).toBe(false);
    });
  });

  it('the cart holds one tint line, priced from the shop at every check', async () => {
    await withRollback(sql, async (tx) => {
      const { owner, shopId } = await tintShop(tx);
      const buyer = await createBuyer(tx);
      await asUser(tx, buyer);
      await tx`insert into public.cart_items (tint_shop_id, tint, seen_price_sdg)
               values (${shopId}, ${tx.json({ ...choice, package: undefined, windows: ['FRONT_LEFT', 'FRONT_RIGHT', 'BACK_LEFT', 'BACK_RIGHT'] } as never)}, 40000)`;
      const [saved] = await tx<
        { tint: object }[]
      >`select tint from public.cart_items where user_id = ${buyer}`;
      expect(must(saved).tint).toEqual({ ...choice, package: 'SIDES' });
      expect(
        await failure(
          tx,
          (sp) => sp`insert into public.cart_items (tint_shop_id, tint, seen_price_sdg)
                                     values (${shopId}, ${sp.json(choice as never)}, ${FULL_SALOON})`,
        ),
      ).toMatchObject({ code: '23505' });

      expect(await validate(tx, [tintLine(shopId)])).toEqual([
        expect.objectContaining({
          ok: true,
          price_sdg: FULL_SALOON,
          tint: choice,
          title_ar: 'تظليل الزجاج: السيارة كاملة، 50%، أسود (صالون)',
          title_en: 'Window tint: full car, 50%, black (saloon)',
        }),
      ]);
      // A darkness the shop doesn't do, then a new price.
      expect(
        await validate(tx, [tintLine(shopId, FULL_SALOON, { ...choice, darkness: 70 })]),
      ).toEqual([expect.objectContaining({ ok: false, problem: 'UNAVAILABLE' })]);
      await asUser(tx, owner);
      await tx`select public.shop_set_tint(${shopId}, true, array[50], array['BLACK'],
                 ${tx.json([{ car_size: 'SALOON', item: 'FULL', price_sdg: 65000 }] as never)})`;
      await asUser(tx, buyer);
      expect(await validate(tx, [tintLine(shopId)])).toEqual([
        expect.objectContaining({ ok: false, problem: 'PRICE_CHANGED', price_sdg: 65000 }),
      ]);
    });
  });

  it('tint is never bought without a fitting', async () => {
    await withRollback(sql, async (tx) => {
      const { shopId } = await tintShop(tx);
      const buyer = await createBuyer(tx);
      await asUser(tx, buyer);
      expect(
        await failure(
          tx,
          (sp) => sp`select public.checkout(${sp.json([tintLine(shopId)] as never)}, 'CASH')`,
        ),
      ).toMatchObject({ message: 'TINT_NEEDS_FITTING' });
    });
  });

  it('at the shop: only technicians at its own bay, then the whole job is paid and settled', async () => {
    await withRollback(sql, async (tx) => {
      const { owner, shopId } = await tintShop(tx);
      const own = await createTechnician(tx, {
        mode: 'BAY',
        bayShopId: shopId,
        jobs: { TINT: LABOUR },
      });
      const other = await createTechnician(tx, { mode: 'BAY', jobs: { TINT: 5000 } });
      const buyer = await createBuyer(tx);
      const item = { tint_shop_id: shopId, tint: choice };

      await asUser(tx, buyer);
      const [ctx] = await tx<
        { c: { technicians: { id: string }[]; items: { minutes: number; title_en: string }[] } }[]
      >`
        select public.booking_context(${tx.json([item] as never)}, 'BAY') as c`;
      expect(must(ctx).c.technicians.map((t) => t.id)).toEqual([own.techId]);
      expect(must(ctx).c.items[0]).toMatchObject({
        minutes: 120,
        title_en: 'Window tint: full car, 50%, black (saloon)',
      });
      expect(
        await failure(tx, (sp) =>
          hold(sp as unknown as Tx, buyer, {
            technicianId: other.techId,
            start: khartoumAt(10),
            items: [item as never],
          }),
        ),
      ).toMatchObject({ message: 'TECHNICIAN_UNSUITABLE' });

      const booking = await hold(tx, buyer, {
        technicianId: own.techId,
        start: khartoumAt(10),
        items: [item as never],
      });
      expect(booking.labour_sdg).toBe(LABOUR);
      await asUser(tx, buyer);
      const [row] = await tx<{ o: OrderJson & { booking: BookingJson } }[]>`
        select public.checkout(p_items => ${tx.json([tintLine(shopId)] as never)}, p_method => 'CASH',
                               p_booking_id => ${booking.id}) as o`;
      const order = must(row).o;
      const sub = must(order.sub_orders[0]);
      expect(sub).toMatchObject({
        shop_id: shopId,
        fulfilment: 'TO_TECHNICIAN',
        items_sdg: FULL_SALOON,
      });
      expect(sub.items[0]).toMatchObject({
        listing_id: null,
        offer_id: null,
        tint: choice,
        unit_price_sdg: FULL_SALOON,
      });
      expect(order.total_sdg).toBe(FULL_SALOON + LABOUR + FEE);
      await asSystem(tx);
      const [linked] = await tx<{ n: number }[]>`
        select count(*)::integer as n from public.booking_items where booking_id = ${booking.id} and order_item_id is not null`;
      expect(must(linked).n).toBe(1);
      const [cart] = await tx<
        { n: number }[]
      >`select count(*)::integer as n from public.cart_items where user_id = ${buyer}`;
      expect(must(cart).n).toBe(0);

      // The job: accepted, the film handed to the shop's own technician, fitted.
      await accept(tx, own.userId, booking.id);
      await asUser(tx, owner);
      await tx`select public.shop_mark_ready(${sub.id})`;
      await tx`select public.shop_hand_over(${sub.id})`;
      await asSystem(tx);
      await tx`update public.bookings set start_at = now() + interval '30 minutes', end_at = now() + interval '150 minutes',
                 block_from = now(), block_to = now() + interval '150 minutes' where id = ${booking.id}`;
      const code = await jobCode(tx, booking.id);
      await asUser(tx, own.userId);
      await tx`select public.tech_check_in(${booking.id})`;
      await tx`select public.tech_complete(${booking.id}, ${code})`;
      // Cash: the technician paid the shop for the film and collected everything at the
      // job, so the shop owes the commission (5%) and the technician the booking fee.
      expect(await shopOwed(tx, shopId)).toBe(-FULL_SALOON * 0.05);
      expect(await techBalance(tx, own.techId)).toBe(-FEE);
      expect(await heldFor(tx, order.id)).toBe(0);
      expect(await unbalancedJournals(tx)).toEqual([]);
    });
  });

  it("at the buyer's place: any mobile technician who tints", async () => {
    await withRollback(sql, async (tx) => {
      await setStreetOrigin(tx);
      const { shopId } = await tintShop(tx);
      const mobile = await createTechnician(tx, { mode: 'MOBILE', jobs: { TINT: LABOUR } });
      const buyer = await createBuyer(tx);
      const address = await addAddress(tx, buyer);
      const item = {
        tint_shop_id: shopId,
        tint: { ...choice, package: undefined, windows: ['WINDSCREEN'] },
      };
      const booking = await hold(tx, buyer, {
        technicianId: mobile.techId,
        start: khartoumAt(11),
        items: [item as never],
        place: 'CUSTOMER_LOCATION',
        addressId: address,
      });
      expect(booking.duration_min).toBe(20);
      await asUser(tx, buyer);
      const [row] = await tx<{ o: OrderJson }[]>`
        select public.checkout(p_items => ${tx.json([tintLine(shopId, WINDOW_SALOON, item.tint)] as never)},
                               p_method => 'BANKAK', p_booking_id => ${booking.id}) as o`;
      expect(must(must(row).o.sub_orders[0]).items[0]).toMatchObject({
        unit_price_sdg: WINDOW_SALOON,
      });
    });
  });
});

describe.runIf(!hasDb)('window tint (skipped)', () => {
  it.skip(skipReason, () => undefined);
});
