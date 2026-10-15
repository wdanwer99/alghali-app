import { afterAll, describe, expect, it } from 'vitest';
import { connect, hasDb, must, withRollback, type Sql, type Tx } from '../support/db.ts';
import { asSystem, asUser, createShop, createUser, failure } from '../support/fixtures.ts';
import {
  createBuyer,
  payByBankak,
  placeOrder,
  shopWithListing,
  type OrderJson,
} from '../support/commerce.ts';
import { accept, createTechnician, hold, khartoumAt } from '../support/bookings.ts';

type ShopJson = { id: string; open_now: boolean; closed_until: string | null; status: string };

/** A shop open every day, all day, so "closed today" is the only thing that closes it. */
async function alwaysOpen(tx: Tx, shopId: string): Promise<void> {
  await asSystem(tx);
  const hours = Object.fromEntries([0, 1, 2, 3, 4, 5, 6].map((d) => [String(d), [[0, 1440]]]));
  await tx`update public.shops set opening_hours = ${tx.json(hours)} where id = ${shopId}`;
}

describe.skipIf(!hasDb)('partner app (M5)', () => {
  const sql: Sql = connect();
  afterAll(() => sql.end());

  describe('closed today', () => {
    it('a member closes the shop until a time; buyers see it closed, then open again', () =>
      withRollback(sql, async (tx) => {
        const { owner, shopId, partId } = await shopWithListing(tx);
        await alwaysOpen(tx, shopId);
        await asUser(tx, owner);
        const until = new Date(Date.now() + 3 * 3600_000).toISOString();
        const [closed] = await tx<
          { s: ShopJson }[]
        >`select public.shop_set_closed(${shopId}, ${until}) as s`;
        expect(must(closed).s.open_now).toBe(false);
        expect(new Date(must(must(closed).s.closed_until)).getTime()).toBe(
          new Date(until).getTime(),
        );

        const buyer = await createBuyer(tx);
        await asUser(tx, buyer);
        const [detail] = await tx<{ d: { listings: { shop: { open_now: boolean } }[] } }[]>`
          select public.part_detail(${partId}) as d`;
        expect(must(detail).d.listings[0]?.shop.open_now).toBe(false);

        await asUser(tx, owner);
        const [open] = await tx<
          { s: ShopJson }[]
        >`select public.shop_set_closed(${shopId}, null) as s`;
        expect(must(open).s.open_now).toBe(true);
        expect(must(open).s.closed_until).toBeNull();
      }));

    it('only members, and only up to a week ahead', () =>
      withRollback(sql, async (tx) => {
        const { owner, shopId } = await shopWithListing(tx);
        const stranger = await createUser(tx);
        await asUser(tx, stranger);
        const soon = new Date(Date.now() + 3600_000).toISOString();
        expect(
          await failure(tx, (sp) => sp`select public.shop_set_closed(${shopId}, ${soon})`),
        ).toMatchObject({
          message: 'FORBIDDEN',
        });
        await asUser(tx, owner);
        for (const at of [new Date(Date.now() - 60_000), new Date(Date.now() + 8 * 86400_000)]) {
          expect(
            await failure(
              tx,
              (sp) => sp`select public.shop_set_closed(${shopId}, ${at.toISOString()})`,
            ),
          ).toMatchObject({ message: 'INVALID_VALUE' });
        }
      }));

    it('a suspended shop cannot change it', () =>
      withRollback(sql, async (tx) => {
        const owner = await createUser(tx);
        const shopId = await createShop(tx, owner, { status: 'SUSPENDED' });
        await asUser(tx, owner);
        expect(
          await failure(tx, (sp) => sp`select public.shop_set_closed(${shopId}, null)`),
        ).toMatchObject({
          message: 'SHOP_NOT_ACTIVE',
        });
      }));
  });

  it('members read their shop while it is pending; others cannot', () =>
    withRollback(sql, async (tx) => {
      const owner = await createUser(tx);
      const shopId = await createShop(tx, owner, { status: 'PENDING' });
      await asUser(tx, owner);
      const [row] = await tx<{ s: ShopJson }[]>`select public.shop_detail(${shopId}) as s`;
      expect(must(row).s).toMatchObject({ id: shopId, status: 'PENDING' });
      const stranger = await createUser(tx);
      await asUser(tx, stranger);
      expect(await failure(tx, (sp) => sp`select public.shop_detail(${shopId})`)).toMatchObject({
        message: 'FORBIDDEN',
      });
    }));

  it('insights count paid and cash sales per Khartoum day, not unpaid or cancelled ones', () =>
    withRollback(sql, async (tx) => {
      const { owner, shopId, listingId, price } = await shopWithListing(tx, {
        price: 12000,
        qty: 20,
      });
      const buyer = await createBuyer(tx);
      const line = (qty: number) => [{ listing_id: listingId, qty, seen_price_sdg: price }];
      // Cash: counts at once. Bankak paid: counts. Bankak unpaid: not yet.
      await placeOrder(tx, buyer, line(2), { method: 'CASH' });
      await payByBankak(tx, await placeOrder(tx, buyer, line(1)));
      await placeOrder(tx, buyer, line(3));
      // Cash, then cancelled by the buyer before the shop accepts: not a sale.
      const cancelled = await placeOrder(tx, buyer, line(4), { method: 'CASH' });
      await asUser(tx, buyer);
      await tx`select public.cancel_order(${cancelled.id})`;

      await asUser(tx, owner);
      const [row] = await tx<
        {
          i: {
            days: { day: string; sales_sdg: number; orders: number }[];
            top: { part_id: string; qty: number; sales_sdg: number }[];
          };
        }[]
      >`select public.shop_insights(${shopId}) as i`;
      const { days, top } = must(row).i;
      expect(days).toHaveLength(7);
      const today = new Date(Date.now() + 2 * 3600_000).toISOString().slice(0, 10);
      expect(must(days.at(-1))).toEqual({ day: today, sales_sdg: 36000, orders: 2 });
      expect(days.slice(0, 6).every((d) => d.sales_sdg === 0 && d.orders === 0)).toBe(true);
      expect(top).toEqual([expect.objectContaining({ qty: 3, sales_sdg: 36000 })]);

      const stranger = await createUser(tx);
      await asUser(tx, stranger);
      expect(await failure(tx, (sp) => sp`select public.shop_insights(${shopId})`)).toMatchObject({
        message: 'FORBIDDEN',
      });
      await asUser(tx, owner);
      expect(
        await failure(tx, (sp) => sp`select public.shop_insights(${shopId}, 0)`),
      ).toMatchObject({
        message: 'INVALID_VALUE',
      });
    }));

  it('a fitting lists where its parts are, as the shop moves them along', () =>
    withRollback(sql, async (tx) => {
      const shop = await shopWithListing(tx, {
        price: 12000,
        category: 'lighting',
        name: 'لمبات H4',
      });
      const tech = await createTechnician(tx, { jobs: { LIGHTING: 6000 } });
      const buyer = await createBuyer(tx);
      const booking = await hold(tx, buyer, {
        technicianId: tech.techId,
        start: khartoumAt(10),
        items: [{ listing_id: shop.listingId }],
      });
      await asUser(tx, buyer);
      const [row] = await tx<{ o: OrderJson }[]>`
        select public.checkout(p_items => ${tx.json([{ listing_id: shop.listingId, qty: 1, seen_price_sdg: 12000 }] as never)},
                               p_method => 'CASH', p_booking_id => ${booking.id}) as o`;
      const sub = must(must(row).o.sub_orders[0]).id;
      await accept(tx, tech.userId, booking.id);

      type Parts = {
        b: {
          parts: { sub_order_id: string; shop_id: string; status: string; items_sdg: number }[];
        };
      };
      const parts = async () => {
        await asUser(tx, tech.userId);
        const [r] = await tx<Parts[]>`select public.booking_detail(${booking.id}) as b`;
        return must(r).b.parts;
      };
      expect(await parts()).toEqual([
        expect.objectContaining({
          sub_order_id: sub,
          shop_id: shop.shopId,
          status: 'CONFIRMED',
          items_sdg: 12000,
        }),
      ]);
      await asUser(tx, shop.owner);
      await tx`select public.shop_mark_ready(${sub})`;
      expect((await parts())[0]?.status).toBe('READY');
      await asUser(tx, shop.owner);
      await tx`select public.shop_hand_over(${sub})`;
      expect((await parts())[0]?.status).toBe('HANDED_TO_TECHNICIAN');
    }));
});
