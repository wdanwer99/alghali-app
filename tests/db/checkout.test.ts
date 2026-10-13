import { afterAll, describe, expect, it } from 'vitest';
import { connect, hasDb, must, skipReason, withRollback, type Sql } from '../support/db.ts';
import { asAnon, asSystem, asUser, createUser, failure } from '../support/fixtures.ts';
import {
  addListing,
  createBuyer,
  placeOrder,
  shopWithListing,
  type Line,
} from '../support/commerce.ts';

function luhnOk(ref: string): boolean {
  let sum = 0;
  for (let i = 0; i < ref.length; i++) {
    let d = Number(ref[ref.length - 1 - i]);
    if (i % 2 === 1) {
      d *= 2;
      if (d > 9) d -= 9;
    }
    sum += d;
  }
  return sum % 10 === 0;
}

describe.skipIf(!hasDb)('checkout', () => {
  const sql: Sql = connect();
  afterAll(() => sql.end());

  it('places a Bankak order: price lock, stock reserved, payment window, cart cleared', async () => {
    await withRollback(sql, async (tx) => {
      const shop = await shopWithListing(tx, { price: 38000, qty: 5 });
      const buyer = await createBuyer(tx);
      await asUser(tx, buyer);
      await tx`insert into public.cart_items (listing_id, qty, seen_price_sdg) values (${shop.listingId}, 2, 38000)`;

      const order = await placeOrder(tx, buyer, [
        { listing_id: shop.listingId, qty: 2, seen_price_sdg: 38000 },
      ]);
      expect(order.ref).toMatch(/^[1-9]\d{7}$/);
      expect(luhnOk(order.ref)).toBe(true);
      expect(order).toMatchObject({
        payment_method: 'BANKAK',
        items_sdg: 76000,
        delivery_sdg: 0,
        total_sdg: 76000,
      });
      expect(order.payments).toEqual([
        expect.objectContaining({
          method: 'BANKAK',
          status: 'AWAITING_TRANSFER',
          amount_sdg: 76000,
          sub_order_id: null,
        }),
      ]);
      const sub = must(order.sub_orders[0]);
      expect(sub).toMatchObject({
        status: 'PENDING_PAYMENT',
        fulfilment: 'PICKUP',
        items_sdg: 76000,
        commission_bp: 500,
        commission_sdg: 3800,
      });
      expect(sub.items).toEqual([
        expect.objectContaining({ unit_price_sdg: 38000, qty: 2, title_ar: 'فحمات فرامل' }),
      ]);

      await asSystem(tx);
      const [o] =
        await tx`select pay_by - created_at as window from public.orders where id = ${order.id}`;
      expect(String(o?.window)).toBe('02:00:00');
      const [l] =
        await tx`select stock_qty, reserved_qty, version from public.listings where id = ${shop.listingId}`;
      expect(l).toEqual({ stock_qty: 5, reserved_qty: 2, version: 1 });
      expect(await tx`select id from public.cart_items where user_id = ${buyer}`).toHaveLength(0);

      // The shop changing its price afterwards doesn't touch the order (price lock).
      await tx`update public.listings set price_sdg = 50000 where id = ${shop.listingId}`;
      const [item] =
        await tx`select unit_price_sdg from public.order_items where sub_order_id = ${sub.id}`;
      expect(item?.unit_price_sdg).toBe('38000');
      expect(
        (
          await failure(
            tx,
            (sp) => sp`update public.order_items set qty = 9 where sub_order_id = ${sub.id}`,
          )
        ).message,
      ).toBe('APPEND_ONLY');
    });
  });

  it('splits a cart over shops into one sub-order each, commission rounded half up', async () => {
    await withRollback(sql, async (tx) => {
      const a = await shopWithListing(tx, { price: 12345 });
      const b = await shopWithListing(tx, { price: 990 });
      const buyer = await createBuyer(tx);
      const order = await placeOrder(tx, buyer, [
        { listing_id: a.listingId, qty: 1, seen_price_sdg: 12345 },
        { listing_id: b.listingId, qty: 3, seen_price_sdg: 990 },
      ]);
      expect(order.total_sdg).toBe(12345 + 2970);
      const byShop = Object.fromEntries(order.sub_orders.map((s) => [s.shop_id, s]));
      expect(byShop[a.shopId]).toMatchObject({ items_sdg: 12345, commission_sdg: 617 }); // 617.25
      expect(byShop[b.shopId]).toMatchObject({ items_sdg: 2970, commission_sdg: 149 }); // 148.5 → 149
    });
  });

  it('a cash order goes straight to the shops, each collecting its own part', async () => {
    await withRollback(sql, async (tx) => {
      const a = await shopWithListing(tx, { price: 5000 });
      const b = await shopWithListing(tx, { price: 7000 });
      const buyer = await createBuyer(tx);
      const order = await placeOrder(
        tx,
        buyer,
        [
          { listing_id: a.listingId, qty: 1, seen_price_sdg: 5000 },
          { listing_id: b.listingId, qty: 1, seen_price_sdg: 7000 },
        ],
        { method: 'CASH' },
      );
      expect(order.pay_by).toBeNull();
      expect(order.sub_orders.map((s) => s.status)).toEqual(['CONFIRMED', 'CONFIRMED']);
      expect(order.payments.map((p) => [p.method, p.status, p.amount_sdg]).sort()).toEqual([
        ['CASH', 'DUE', 5000],
        ['CASH', 'DUE', 7000],
      ]);
      await asSystem(tx);
      const notes = await tx`select code from public.notifications where user_id = ${a.owner}`;
      expect(notes.map((n) => n.code)).toEqual(['NEW_ORDER']);
    });
  });

  it('when a price or stock changed, nothing is placed and the changes come back', async () => {
    await withRollback(sql, async (tx) => {
      const shop = await shopWithListing(tx, { price: 10000, qty: 2 });
      const other = await addListing(tx, shop.shopId, { price: 3000, qty: 1 });
      const buyer = await createBuyer(tx);
      const lines: Line[] = [
        { listing_id: shop.listingId, qty: 1, seen_price_sdg: 9000 },
        { listing_id: other.listingId, qty: 2, seen_price_sdg: 3000 },
      ];
      await asUser(tx, buyer);
      const err = await failure(
        tx,
        (sp) => sp`select public.checkout(${sp.json(lines as never)}, 'BANKAK')`,
      );
      expect(err).toEqual({ code: 'PT409', message: 'CART_CHANGED' });
      const changes = JSON.parse(must(err.detail)) as Record<string, unknown>[];
      expect(changes).toEqual(
        expect.arrayContaining([
          expect.objectContaining({
            listing_id: shop.listingId,
            ok: false,
            problem: 'PRICE_CHANGED',
            price_sdg: 10000,
          }),
          expect.objectContaining({
            listing_id: other.listingId,
            ok: false,
            problem: 'NOT_ENOUGH_STOCK',
            available_qty: 1,
          }),
        ]),
      );
      await asSystem(tx);
      expect(await tx`select id from public.orders where buyer_id = ${buyer}`).toHaveLength(0);
    });
  });

  it('cart_validate works for guests too and flags what is unavailable', async () => {
    await withRollback(sql, async (tx) => {
      const shop = await shopWithListing(tx, { price: 10000 });
      await asSystem(tx);
      await tx`update public.shops set status = 'SUSPENDED' where id = ${shop.shopId}`;
      await asAnon(tx);
      const [r] = await tx<{ v: { ok: boolean; problem: string }[] }[]>`
        select public.cart_validate(${tx.json([{ listing_id: shop.listingId, qty: 1, seen_price_sdg: 10000 }])}) as v`;
      expect(r?.v).toEqual([expect.objectContaining({ ok: false, problem: 'UNAVAILABLE' })]);
    });
  });

  it('two buyers can’t both take the last one', async () => {
    await withRollback(sql, async (tx) => {
      const shop = await shopWithListing(tx, { price: 1000, qty: 1 });
      const first = await createBuyer(tx);
      const second = await createBuyer(tx);
      await placeOrder(tx, first, [{ listing_id: shop.listingId, qty: 1, seen_price_sdg: 1000 }]);
      const err = await failure(tx, (sp) =>
        placeOrder(sp, second, [{ listing_id: shop.listingId, qty: 1, seen_price_sdg: 1000 }]),
      );
      expect(err.message).toBe('CART_CHANGED');
    });
  });

  it('needs a phone number, a known payment method and a valid cart', async () => {
    await withRollback(sql, async (tx) => {
      const shop = await shopWithListing(tx, { price: 1000 });
      const noPhone = await createUser(tx);
      const buyer = await createBuyer(tx);
      const line = [{ listing_id: shop.listingId, qty: 1, seen_price_sdg: 1000 }];
      expect((await failure(tx, (sp) => placeOrder(sp, noPhone, line))).message).toBe(
        'PHONE_REQUIRED',
      );
      expect((await failure(tx, (sp) => placeOrder(sp, buyer, []))).message).toBe('INVALID_ITEMS');
      expect((await failure(tx, (sp) => placeOrder(sp, buyer, [...line, ...line]))).message).toBe(
        'INVALID_ITEMS',
      );
      expect(
        (await failure(tx, (sp) => placeOrder(sp, buyer, [{ ...must(line[0]), qty: 0 }]))).message,
      ).toBe('INVALID_ITEMS');
    });
  });

  it('a replay with the same key returns the same order', async () => {
    await withRollback(sql, async (tx) => {
      const shop = await shopWithListing(tx, { price: 1000, qty: 3 });
      const buyer = await createBuyer(tx);
      const key = crypto.randomUUID();
      const line = [{ listing_id: shop.listingId, qty: 1, seen_price_sdg: 1000 }];
      const a = await placeOrder(tx, buyer, line, { idem: key });
      const b = await placeOrder(tx, buyer, line, { idem: key });
      expect(b.id).toBe(a.id);
      await asSystem(tx);
      const [l] = await tx`select reserved_qty from public.listings where id = ${shop.listingId}`;
      expect(l?.reserved_qty).toBe(1);
    });
  });

  describe('delivery', () => {
    it('charges the delivery band by distance from the shop', async () => {
      await withRollback(sql, async (tx) => {
        // Shop at the origin of a small grid; the buyer ~5.6 km away → second band (≤ 8 km).
        const shop = await shopWithListing(tx, { price: 20000, lat: 15.5, lng: 32.5 });
        const buyer = await createBuyer(tx);
        await asUser(tx, buyer);
        const [addr] =
          await tx`insert into public.addresses (label, lat, lng) values ('البيت', 15.55, 32.5) returning id`;
        const order = await placeOrder(
          tx,
          buyer,
          [{ listing_id: shop.listingId, qty: 1, seen_price_sdg: 20000 }],
          {
            fulfilment: { [shop.shopId]: 'DELIVERY' },
            addressId: must(addr).id,
          },
        );
        expect(order).toMatchObject({ delivery_sdg: 4000, total_sdg: 24000 });
        expect(must(order.sub_orders[0])).toMatchObject({
          fulfilment: 'DELIVERY',
          delivery_fee_sdg: 4000,
        });
      });
    });

    it('needs an address, and a shop pin or the street’s starting point', async () => {
      await withRollback(sql, async (tx) => {
        const shop = await shopWithListing(tx, { price: 20000 });
        const buyer = await createBuyer(tx);
        const line = [{ listing_id: shop.listingId, qty: 1, seen_price_sdg: 20000 }];
        const delivery = { [shop.shopId]: 'DELIVERY' };
        expect(
          (await failure(tx, (sp) => placeOrder(sp, buyer, line, { fulfilment: delivery })))
            .message,
        ).toBe('ADDRESS_REQUIRED');
        await asUser(tx, buyer);
        const [addr] =
          await tx`insert into public.addresses (label, lat, lng) values ('x', 15.5, 32.5) returning id`;
        const err = await failure(tx, (sp) =>
          placeOrder(sp, buyer, line, { fulfilment: delivery, addressId: must(addr).id }),
        );
        expect(err.message).toBe('DELIVERY_UNAVAILABLE'); // D-077: no pin, no street origin yet
        const far = await failure(tx, async (sp) => {
          await asSystem(sp);
          await sp`update public.shops set lat = 19.6, lng = 37.2 where id = ${shop.shopId}`; // Port Sudan
          return placeOrder(sp, buyer, line, { fulfilment: delivery, addressId: must(addr).id });
        });
        expect(far.message).toBe('DELIVERY_OUT_OF_RANGE');
      });
    });
  });

  describe('cancelling', () => {
    it('the buyer cancels an unpaid order; stock goes back', async () => {
      await withRollback(sql, async (tx) => {
        const shop = await shopWithListing(tx, { price: 1000, qty: 2 });
        const buyer = await createBuyer(tx);
        const order = await placeOrder(tx, buyer, [
          { listing_id: shop.listingId, qty: 2, seen_price_sdg: 1000 },
        ]);
        await asUser(tx, buyer);
        const [r] = await tx<
          { o: { sub_orders: { status: string }[]; payments: { status: string }[] } }[]
        >`
          select public.cancel_order(${order.id}) as o`;
        expect(r?.o.sub_orders.map((s) => s.status)).toEqual(['CANCELLED']);
        expect(r?.o.payments.map((p) => p.status)).toEqual(['CANCELLED']);
        await asSystem(tx);
        const [l] = await tx`select reserved_qty from public.listings where id = ${shop.listingId}`;
        expect(l?.reserved_qty).toBe(0);
      });
    });

    it('a cash order can be cancelled until the shop accepts it', async () => {
      await withRollback(sql, async (tx) => {
        const shop = await shopWithListing(tx, { price: 1000 });
        const buyer = await createBuyer(tx);
        const line = [{ listing_id: shop.listingId, qty: 1, seen_price_sdg: 1000 }];
        const first = await placeOrder(tx, buyer, line, { method: 'CASH' });
        await asUser(tx, buyer);
        await tx`select public.cancel_order(${first.id})`;

        const second = await placeOrder(tx, buyer, line, { method: 'CASH' });
        await asUser(tx, shop.owner);
        await tx`select public.shop_ack_suborder(${must(second.sub_orders[0]).id})`;
        await asUser(tx, buyer);
        expect(await failure(tx, (sp) => sp`select public.cancel_order(${second.id})`)).toEqual({
          code: 'PT409',
          message: 'CANNOT_CANCEL',
        });
      });
    });

    it('not while the receipt is being checked, and never someone else’s order', async () => {
      await withRollback(sql, async (tx) => {
        const shop = await shopWithListing(tx, { price: 1000 });
        const buyer = await createBuyer(tx);
        const other = await createBuyer(tx);
        const order = await placeOrder(tx, buyer, [
          { listing_id: shop.listingId, qty: 1, seen_price_sdg: 1000 },
        ]);
        await asUser(tx, other);
        expect(
          (await failure(tx, (sp) => sp`select public.cancel_order(${order.id})`)).message,
        ).toBe('ORDER_NOT_FOUND');
        await asUser(tx, buyer);
        await tx`select public.submit_bankak_receipt(${order.id}, '123456789')`;
        expect(
          (await failure(tx, (sp) => sp`select public.cancel_order(${order.id})`)).message,
        ).toBe('CANNOT_CANCEL');
      });
    });
  });

  describe('who sees what', () => {
    it('the buyer sees their order; the shop its part; strangers nothing', async () => {
      await withRollback(sql, async (tx) => {
        const a = await shopWithListing(tx, { price: 1000 });
        const b = await shopWithListing(tx, { price: 2000 });
        const buyer = await createBuyer(tx);
        const stranger = await createBuyer(tx);
        const order = await placeOrder(
          tx,
          buyer,
          [
            { listing_id: a.listingId, qty: 1, seen_price_sdg: 1000 },
            { listing_id: b.listingId, qty: 1, seen_price_sdg: 2000 },
          ],
          { method: 'CASH' },
        );
        await asUser(tx, a.owner);
        const subs = await tx`select shop_id from public.sub_orders where order_id = ${order.id}`;
        expect(subs.map((s) => s.shop_id)).toEqual([a.shopId]);
        const pays = await tx`select amount_sdg from public.payments where order_id = ${order.id}`;
        expect(pays.map((p) => p.amount_sdg)).toEqual(['1000']);
        const shopView = await tx<{ j: { buyer: { phone: string }; items: unknown[] } }[]>`
          select j from public.shop_orders(${a.shopId}) j`;
        expect(shopView[0]?.j.buyer.phone).toBe('+249912345678');

        await asUser(tx, stranger);
        expect(await tx`select id from public.orders where id = ${order.id}`).toHaveLength(0);
        expect(await tx`select id from public.order_items`).toHaveLength(0);
        expect(
          (await failure(tx, (sp) => sp`select * from public.shop_orders(${a.shopId})`)).message,
        ).toBe('FORBIDDEN');
      });
    });

    it('shops don’t see an order before it is paid', async () => {
      await withRollback(sql, async (tx) => {
        const shop = await shopWithListing(tx, { price: 1000 });
        const buyer = await createBuyer(tx);
        await placeOrder(tx, buyer, [{ listing_id: shop.listingId, qty: 1, seen_price_sdg: 1000 }]);
        await asUser(tx, shop.owner);
        expect(await tx`select j from public.shop_orders(${shop.shopId}) j`).toHaveLength(0);
      });
    });
  });

  describe('photo requests and offers', () => {
    it('a request reaches matching shops; an offer can be bought like a listing', async () => {
      await withRollback(sql, async (tx) => {
        const shop = await shopWithListing(tx);
        const buyer = await createBuyer(tx);
        await asUser(tx, buyer);
        const [req] = await tx<{ r: { id: string } }[]>`
          select public.create_part_request('دينمو هايلكس 2018 — الصورة مرفقة') as r`;
        const requestId = must(req).r.id;

        await asSystem(tx);
        const notes = await tx`select code from public.notifications where user_id = ${shop.owner}`;
        expect(notes.map((n) => n.code)).toContain('NEW_PART_REQUEST');

        await asUser(tx, shop.owner);
        const open = await tx<
          { j: { id: string } }[]
        >`select j from public.shop_open_requests(${shop.shopId}) j`;
        expect(open.map((r) => r.j.id)).toContain(requestId);
        const [offer] = await tx<{ o: { id: string } }[]>`
          select public.shop_make_offer(${shop.shopId}, ${requestId}, 'دينمو مستعمل مفحوص', 'USED', 110000, 30) as o`;
        const offerId = must(offer).o.id;

        await asUser(tx, buyer);
        const offers =
          await tx`select price_sdg from public.part_offers where request_id = ${requestId}`;
        expect(offers.map((o) => o.price_sdg)).toEqual(['110000']);
        const order = await placeOrder(tx, buyer, [
          { offer_id: offerId, qty: 1, seen_price_sdg: 110000 },
        ]);
        expect(must(order.sub_orders[0]).items).toEqual([
          expect.objectContaining({
            offer_id: offerId,
            title_ar: 'دينمو مستعمل مفحوص',
            unit_price_sdg: 110000,
          }),
        ]);
        await asSystem(tx);
        const [o] = await tx`select status from public.part_offers where id = ${offerId}`;
        expect(o?.status).toBe('ORDERED');
      });
    });

    it('nobody else can buy a buyer’s offer', async () => {
      await withRollback(sql, async (tx) => {
        const shop = await shopWithListing(tx);
        const buyer = await createBuyer(tx);
        const other = await createBuyer(tx);
        await asUser(tx, buyer);
        const [req] = await tx<
          { r: { id: string } }[]
        >`select public.create_part_request('مراية جانبية يمين') as r`;
        await asUser(tx, shop.owner);
        const [offer] = await tx<{ o: { id: string } }[]>`
          select public.shop_make_offer(${shop.shopId}, ${must(req).r.id}, 'مراية', 'NEW_AFTERMARKET', 9000) as o`;
        const err = await failure(tx, (sp) =>
          placeOrder(sp, other, [{ offer_id: must(offer).o.id, qty: 1, seen_price_sdg: 9000 }]),
        );
        expect(err.message).toBe('CART_CHANGED');
      });
    });
  });
});

describe.runIf(!hasDb)('checkout (skipped)', () => {
  it.skip(skipReason, () => undefined);
});
