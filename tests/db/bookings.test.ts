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
import { asAnon, asSystem, asUser, createAdmin, failure, variantIds } from '../support/fixtures.ts';
import {
  accept,
  addAddress,
  bookingRow,
  createTechnician,
  elsewhere,
  hold,
  jobCode,
  khartoumAt,
  minutesAfter,
  openOffer,
  setStreetOrigin,
  type BookingJson,
} from '../support/bookings.ts';
import { createBuyer, payByBankak, shopWithListing, type OrderJson } from '../support/commerce.ts';

interface Ctx {
  duration_min: number;
  travel_fee_sdg: number;
  booking_fee_sdg: number;
  technicians: {
    id: string;
    labour_sdg: number;
    distance_km: number | null;
    busy: [string, string][];
    rules: unknown[];
    [k: string]: unknown;
  }[];
}

async function context(
  tx: Tx,
  items: unknown[],
  place: 'BAY' | 'CUSTOMER_LOCATION',
  extra: { lat?: number; lng?: number; variantId?: string } = {},
): Promise<Ctx> {
  const [row] = await tx<{ c: Ctx }[]>`
    select public.booking_context(
      p_items => ${tx.json(items as never)}, p_place => ${place}::public.booking_place,
      p_lat => ${extra.lat ?? null}, p_lng => ${extra.lng ?? null}, p_variant_id => ${extra.variantId ?? null}) as c`;
  return must(row).c;
}

/** Checkout with a held booking, as the buyer. */
async function checkoutBooking(
  tx: Tx,
  buyer: string,
  booking: BookingJson,
  lines: { listing_id: string; qty: number; seen_price_sdg: number }[],
  method: 'BANKAK' | 'CASH',
): Promise<OrderJson & { booking: BookingJson }> {
  await asUser(tx, buyer);
  const [row] = await tx<{ o: OrderJson & { booking: BookingJson } }[]>`
    select public.checkout(p_items => ${tx.json(lines as never)}, p_method => ${method}::public.payment_method,
                           p_booking_id => ${booking.id}) as o`;
  return must(row).o;
}

async function status(tx: Tx, bookingId: string): Promise<string> {
  return (await bookingRow(tx, bookingId)).status;
}

async function notifications(tx: Tx, userId: string): Promise<{ code: string; app: string }[]> {
  await asSystem(tx);
  return tx<{ code: string; app: string }[]>`
    select code, app from public.notifications where user_id = ${userId} order by created_at`;
}

// Each case builds technicians, shops and orders over the internet: give it time.
describe.skipIf(!hasDb)('bookings', { timeout: 90_000 }, () => {
  const sql: Sql = connect();
  afterAll(() => sql.end());
  const start = khartoumAt(10);

  describe('who can take a job', () => {
    it('lists technicians who suit it, with their price and calendar, but no contact details', async () => {
      await withRollback(sql, async (tx) => {
        await setStreetOrigin(tx);
        const good = await createTechnician(tx, { jobs: { LIGHTING: 5000 } });
        const brakesOnly = await createTechnician(tx, { jobs: { BRAKES: 6000 } });
        const bayOnly = await createTechnician(tx, { mode: 'BAY', jobs: { LIGHTING: 4000 } });
        const far = await createTechnician(tx, {
          mode: 'MOBILE',
          jobs: { LIGHTING: 4000 },
          home: [16.6, 33.6],
        });
        const toyota = await createTechnician(tx, {
          mode: 'MOBILE',
          jobs: { LIGHTING: 4500 },
          makes: ['toyota'],
        });
        const [sunny] = await variantIds(tx, 'nissan', 'sunny');
        const item = await elsewhere(tx);
        const ours = (c: Ctx) =>
          c.technicians
            .map((t) => t.id)
            .filter((id) => [good, brakesOnly, bayOnly, far, toyota].some((x) => x.techId === id));

        await asAnon(tx);
        const mobile = await context(tx, [item], 'CUSTOMER_LOCATION', {
          lat: 15.61,
          lng: 32.5,
          variantId: sunny,
        });
        expect(ours(mobile)).toEqual([good.techId]);
        expect(mobile.duration_min).toBe(30);
        expect(mobile.travel_fee_sdg).toBe(3000);
        expect(mobile.booking_fee_sdg).toBe(2000);
        const t = must(mobile.technicians.find((x) => x.id === good.techId));
        expect(t.labour_sdg).toBe(5000);
        expect(t.distance_km).toBeCloseTo(1.1, 0);
        expect(t.rules).toHaveLength(7);
        expect(Object.keys(t)).not.toContain('phone');
        expect(Object.keys(t)).not.toContain('home_lat');

        const bay = await context(tx, [item], 'BAY');
        expect(ours(bay).sort()).toEqual([good.techId, bayOnly.techId].sort());
      });
    });

    it('a part that is not fitted, or a category with no job type, cannot be booked', async () => {
      await withRollback(sql, async (tx) => {
        const [body] = await tx<
          { id: string }[]
        >`select id from public.part_categories where slug = 'body'`;
        await asAnon(tx);
        expect(
          await failure(tx, (sp) =>
            context(sp, [{ category_id: must(body).id, description: 'مرآة' }], 'BAY'),
          ),
        ).toEqual({ code: '22023', message: 'NOT_INSTALLABLE' });
        expect(await failure(tx, (sp) => context(sp, [], 'BAY'))).toEqual({
          code: '22023',
          message: 'ITEMS_REQUIRED',
        });
      });
    });

    it('mobile jobs need the street starting point for the travel fee (D-077)', async () => {
      await withRollback(sql, async (tx) => {
        await asSystem(tx);
        await tx`update public.streets set origin_lat = null, origin_lng = null`;
        const item = await elsewhere(tx);
        await asAnon(tx);
        expect(
          await failure(tx, (sp) =>
            context(sp, [item], 'CUSTOMER_LOCATION', { lat: 15.6, lng: 32.5 }),
          ),
        ).toEqual({ code: '22023', message: 'TRAVEL_UNAVAILABLE' });
      });
    });
  });

  describe('holds', () => {
    it('holds the slot with the price locked and a job code only the buyer can read', async () => {
      await withRollback(sql, async (tx) => {
        await setStreetOrigin(tx);
        const tech = await createTechnician(tx);
        const buyer = await createBuyer(tx);
        const address = await addAddress(tx, buyer);
        const b = await hold(tx, buyer, {
          technicianId: tech.techId,
          start,
          items: [await elsewhere(tx)],
          place: 'CUSTOMER_LOCATION',
          addressId: address,
        });
        expect(b.status).toBe('HELD');
        expect(b.labour_sdg).toBe(5000);
        expect(b.travel_fee_sdg).toBe(3000);
        expect(b.booking_fee_sdg).toBe(2000);
        expect(Date.parse(b.end_at) - Date.parse(b.start_at)).toBe(30 * 60_000);
        // The block includes the travel buffer on both sides (D-025).
        expect(Date.parse(b.start_at) - Date.parse(b.block_from)).toBe(30 * 60_000);
        expect(Date.parse(b.block_to) - Date.parse(b.end_at)).toBe(30 * 60_000);
        expect(b.job_code).toMatch(/^\d{4}$/);
        expect(Date.parse(must(b.hold_expires_at)) - Date.now()).toBeLessThan(11 * 60_000);

        await asUser(tx, tech.userId);
        expect(
          await tx`select * from public.booking_codes where booking_id = ${b.id}`,
        ).toHaveLength(0);
        expect(await tx`select * from public.bookings where id = ${b.id}`).toHaveLength(1);
        const [view] = await tx<{ b: BookingJson }[]>`select public.booking_detail(${b.id}) as b`;
        expect(must(view).b.job_code).toBeNull();
      });
    });

    it('checks the start: on the half hour, after the earliest time, inside the hours, clear of time off', async () => {
      await withRollback(sql, async (tx) => {
        const tech = await createTechnician(tx, {
          rules: [0, 1, 2, 3, 4, 5, 6].map((weekday) => ({
            weekday,
            start_min: 9 * 60,
            end_min: 13 * 60,
          })),
        });
        const buyer = await createBuyer(tx);
        const item = await elsewhere(tx);
        const at = (iso: string) => (sp: Tx) =>
          hold(sp, buyer, { technicianId: tech.techId, start: iso, items: [item] });

        expect(await failure(tx, at(minutesAfter(start, 10)))).toEqual({
          code: '22023',
          message: 'INVALID_START',
        });
        expect(await failure(tx, at(new Date(Date.now() + 30 * 60_000).toISOString()))).toEqual({
          code: '22023',
          message: 'INVALID_START',
        });
        // 12:30 + 30 minutes fits; 13:00 is outside the window.
        expect(await failure(tx, at(khartoumAt(13)))).toEqual({
          code: 'PT409',
          message: 'SLOT_TAKEN',
        });
        await asSystem(tx);
        await tx`insert into public.time_off (technician_id, period)
                 values (${tech.techId}, tstzrange(${start}::timestamptz, ${minutesAfter(start, 60)}::timestamptz))`;
        expect(await failure(tx, at(start))).toEqual({ code: 'PT409', message: 'SLOT_TAKEN' });
        const ok = await hold(tx, buyer, {
          technicianId: tech.techId,
          start: khartoumAt(12, 1, 30),
          items: [item],
        });
        expect(ok.status).toBe('HELD');
      });
    });

    it('two buyers can never hold overlapping blocks of one technician; the constraint is the final word', async () => {
      await withRollback(sql, async (tx) => {
        const tech = await createTechnician(tx);
        const [a, b] = [await createBuyer(tx), await createBuyer(tx)];
        const item = await elsewhere(tx);
        const first = await hold(tx, a, { technicianId: tech.techId, start, items: [item] });
        expect(
          await failure(tx, (sp) =>
            hold(sp, b, {
              technicianId: tech.techId,
              start: minutesAfter(start, 0),
              items: [item],
            }),
          ),
        ).toEqual({ code: 'PT409', message: 'SLOT_TAKEN' });
        // Right after it is fine for a bay job.
        const next = await hold(tx, b, {
          technicianId: tech.techId,
          start: minutesAfter(start, 30),
          items: [item],
        });
        expect(next.status).toBe('HELD');

        // Even a direct insert that skipped every check is refused by EXCLUDE.
        await asSystem(tx);
        const err = await failure(
          tx,
          (
            sp,
          ) => sp`insert into public.bookings (ref, buyer_id, technician_id, place, bay_shop_id, start_at, end_at,
                                                block_from, block_to, duration_min, labour_sdg)
                     select public.new_ref('BOOKING'), ${b}, technician_id, place, bay_shop_id, start_at, end_at,
                            block_from, block_to, duration_min, 0
                     from public.bookings where id = ${first.id}`,
        );
        expect(err.code).toBe('23P01');
      });
    });

    it('a lapsed hold stops blocking; a buyer’s new hold lets the previous one go', async () => {
      await withRollback(sql, async (tx) => {
        const tech = await createTechnician(tx);
        const [a, b] = [await createBuyer(tx), await createBuyer(tx)];
        const item = await elsewhere(tx);
        const old = await hold(tx, a, { technicianId: tech.techId, start, items: [item] });
        await asSystem(tx);
        await tx`update public.bookings set hold_expires_at = now() - interval '1 minute' where id = ${old.id}`;
        const taken = await hold(tx, b, { technicianId: tech.techId, start, items: [item] });
        expect(taken.status).toBe('HELD');
        expect(await status(tx, old.id)).toBe('EXPIRED');

        const second = await hold(tx, b, {
          technicianId: tech.techId,
          start: khartoumAt(15),
          items: [item],
        });
        expect(await status(tx, taken.id)).toBe('CANCELLED_BY_BUYER');
        expect(second.status).toBe('HELD');
      });
    });

    it('the sweeper expires lapsed holds', async () => {
      await withRollback(sql, async (tx) => {
        const tech = await createTechnician(tx);
        const b = await hold(tx, await createBuyer(tx), {
          technicianId: tech.techId,
          start,
          items: [await elsewhere(tx)],
        });
        await asSystem(tx);
        await tx`update public.bookings set hold_expires_at = now() - interval '1 second' where id = ${b.id}`;
        await tx`select public.expire_booking_holds()`;
        expect(await status(tx, b.id)).toBe('EXPIRED');
      });
    });
  });

  describe('checkout with a fitting', () => {
    it('Bankak: the order carries the fees, the parts go to the technician, and the job is offered once paid', async () => {
      await withRollback(sql, async (tx) => {
        const shop = await shopWithListing(tx, { price: 12000 });
        const tech = await createTechnician(tx);
        const buyer = await createBuyer(tx);
        const b = await hold(tx, buyer, {
          technicianId: tech.techId,
          start,
          items: [{ listing_id: shop.listingId }],
        });
        expect(b.duration_min).toBe(60);
        expect(b.labour_sdg).toBe(6000);
        const line = { listing_id: shop.listingId, qty: 1, seen_price_sdg: 12000 };
        const order = await checkoutBooking(tx, buyer, b, [line], 'BANKAK');
        expect(order.total_sdg).toBe(12000 + 6000 + 2000);
        expect(must(order.sub_orders[0]).fulfilment).toBe('TO_TECHNICIAN');
        expect(order.booking.status).toBe('AWAITING_PAYMENT');
        expect(order.booking.order_id).toBe(order.id);
        expect(must(order.booking.items[0]).order_item_id).not.toBeNull();
        expect(await openOffer(tx, b.id)).toBeUndefined();

        await payByBankak(tx, order);
        expect(await status(tx, b.id)).toBe('PENDING_TECH_ACCEPT');
        expect(must(await openOffer(tx, b.id)).technician_id).toBe(tech.techId);
        expect(await notifications(tx, tech.userId)).toEqual([
          { code: 'NEW_JOB_OFFER', app: 'partner' },
        ]);
      });
    });

    it('a booked part must be bought in the same checkout; a lapsed hold cannot be checked out', async () => {
      await withRollback(sql, async (tx) => {
        const shop = await shopWithListing(tx);
        const tech = await createTechnician(tx);
        const buyer = await createBuyer(tx);
        const b = await hold(tx, buyer, {
          technicianId: tech.techId,
          start,
          items: [{ listing_id: shop.listingId }],
        });
        expect(await failure(tx, (sp) => checkoutBooking(sp, buyer, b, [], 'BANKAK'))).toEqual({
          code: '22023',
          message: 'BOOKING_ITEMS_NOT_IN_CART',
        });
        await asSystem(tx);
        await tx`update public.bookings set hold_expires_at = now() - interval '1 second' where id = ${b.id}`;
        expect(
          await failure(tx, (sp) =>
            checkoutBooking(
              sp,
              buyer,
              b,
              [{ listing_id: shop.listingId, qty: 1, seen_price_sdg: shop.price }],
              'BANKAK',
            ),
          ),
        ).toEqual({ code: 'PT409', message: 'HOLD_EXPIRED' });
      });
    });

    it('cash at a bay: offered at once; the technician will collect parts and fees at the job', async () => {
      await withRollback(sql, async (tx) => {
        const shop = await shopWithListing(tx, { price: 12000 });
        const tech = await createTechnician(tx);
        const buyer = await createBuyer(tx);
        const b = await hold(tx, buyer, {
          technicianId: tech.techId,
          start,
          items: [{ listing_id: shop.listingId }],
        });
        const order = await checkoutBooking(
          tx,
          buyer,
          b,
          [{ listing_id: shop.listingId, qty: 1, seen_price_sdg: 12000 }],
          'CASH',
        );
        expect(order.booking.status).toBe('PENDING_TECH_ACCEPT');
        expect(order.pay_by).toBeNull();
        expect(must(order.sub_orders[0]).status).toBe('CONFIRMED');
        expect(
          order.payments.map((p) => [p.method, p.status, p.amount_sdg, p.sub_order_id]),
        ).toEqual([['CASH', 'DUE', 12000 + 6000 + 2000, null]]);
      });
    });

    it('cash at the buyer’s location: a Bankak deposit first (D-019), and the parts wait for it', async () => {
      await withRollback(sql, async (tx) => {
        await setStreetOrigin(tx);
        const shop = await shopWithListing(tx, { price: 12000 });
        const tech = await createTechnician(tx);
        const buyer = await createBuyer(tx);
        const address = await addAddress(tx, buyer);
        const b = await hold(tx, buyer, {
          technicianId: tech.techId,
          start,
          items: [{ listing_id: shop.listingId }],
          place: 'CUSTOMER_LOCATION',
          addressId: address,
        });
        const order = await checkoutBooking(
          tx,
          buyer,
          b,
          [{ listing_id: shop.listingId, qty: 1, seen_price_sdg: 12000 }],
          'CASH',
        );
        expect(order.booking.status).toBe('AWAITING_PAYMENT');
        expect(order.booking.deposit_sdg).toBe(5000);
        expect(order.pay_by).not.toBeNull();
        expect(must(order.sub_orders[0]).status).toBe('PENDING_PAYMENT');
        const methods = order.payments.map((p) => [p.method, p.status, p.amount_sdg]).sort();
        expect(methods).toEqual([
          ['BANKAK', 'AWAITING_TRANSFER', 5000],
          ['CASH', 'DUE', 12000 + 6000 + 3000 + 2000 - 5000],
        ]);
        await payByBankak(tx, order);
        expect(await status(tx, b.id)).toBe('PENDING_TECH_ACCEPT');
        await asSystem(tx);
        const [sub] = await tx<
          { status: string }[]
        >`select status from public.sub_orders where order_id = ${order.id}`;
        expect(must(sub).status).toBe('CONFIRMED');
      });
    });

    it('an unpaid deposit expires the booking and the parts with it', async () => {
      await withRollback(sql, async (tx) => {
        await setStreetOrigin(tx);
        const shop = await shopWithListing(tx, { price: 12000 });
        const tech = await createTechnician(tx);
        const buyer = await createBuyer(tx);
        const address = await addAddress(tx, buyer);
        const b = await hold(tx, buyer, {
          technicianId: tech.techId,
          start,
          items: [{ listing_id: shop.listingId }],
          place: 'CUSTOMER_LOCATION',
          addressId: address,
        });
        const order = await checkoutBooking(
          tx,
          buyer,
          b,
          [{ listing_id: shop.listingId, qty: 1, seen_price_sdg: 12000 }],
          'CASH',
        );
        await asSystem(tx);
        await tx`update public.orders set pay_by = now() - interval '1 minute' where id = ${order.id}`;
        await tx`select public.expire_unpaid_orders()`;
        expect(await status(tx, b.id)).toBe('EXPIRED');
        const [sub] = await tx<
          { status: string }[]
        >`select status from public.sub_orders where order_id = ${order.id}`;
        expect(must(sub).status).toBe('CANCELLED');
        const [l] = await tx<
          { reserved_qty: number }[]
        >`select reserved_qty from public.listings where id = ${shop.listingId}`;
        expect(must(l).reserved_qty).toBe(0);
      });
    });

    it('a fitting on its own (part bought elsewhere): an order with fees only', async () => {
      await withRollback(sql, async (tx) => {
        const tech = await createTechnician(tx);
        const buyer = await createBuyer(tx);
        const b = await hold(tx, buyer, {
          technicianId: tech.techId,
          start,
          items: [await elsewhere(tx)],
        });
        const order = await checkoutBooking(tx, buyer, b, [], 'BANKAK');
        expect(order.items_sdg).toBe(0);
        expect(order.sub_orders).toEqual([]);
        expect(order.total_sdg).toBe(5000 + 2000);
        expect(order.booking.status).toBe('AWAITING_PAYMENT');
      });
    });
  });

  describe('offers', () => {
    /** A paid bay booking for `tech`, waiting for their answer. */
    async function offered(tx: Tx, techId: string, buyer?: string) {
      const who = buyer ?? (await createBuyer(tx));
      const b = await hold(tx, who, { technicianId: techId, start, items: [await elsewhere(tx)] });
      await checkoutBooking(tx, who, b, [], 'CASH');
      return { booking: b, buyer: who };
    }

    it('declined: offered to the next best technician free at the same time, at the same price', async () => {
      await withRollback(sql, async (tx) => {
        const first = await createTechnician(tx, { rating: 4.9 });
        const second = await createTechnician(tx, {
          rating: 4.8,
          completedJobs: 50,
          jobs: { LIGHTING: 9000 },
        });
        const third = await createTechnician(tx, { rating: 3.0 });
        const { booking, buyer } = await offered(tx, first.techId);
        const offer = must(await openOffer(tx, booking.id));
        await asUser(tx, first.userId);
        await tx`select public.tech_respond_offer(${offer.id}, false, 'مشغول')`;

        const after = await bookingRow(tx, booking.id);
        expect(after.status).toBe('PENDING_TECH_ACCEPT');
        expect(after.technician_id).toBe(second.techId);
        expect(after.labour_sdg).toBe(5000);
        expect(must(await openOffer(tx, booking.id)).technician_id).toBe(second.techId);
        expect((await notifications(tx, buyer)).map((n) => n.code)).toContain('BOOKING_REASSIGNED');
        void third;
      });
    });

    it('timed out: the sweeper moves it on; nobody left means NEEDS_RESCHEDULE', async () => {
      await withRollback(sql, async (tx) => {
        const only = await createTechnician(tx);
        const { booking, buyer } = await offered(tx, only.techId);
        await asSystem(tx);
        await tx`update public.booking_offers set expires_at = now() - interval '1 minute' where booking_id = ${booking.id}`;
        await tx`select public.expire_booking_offers()`;
        const [o] = await tx<
          { status: string }[]
        >`select status from public.booking_offers where booking_id = ${booking.id}`;
        expect(must(o).status).toBe('TIMED_OUT');
        expect(await status(tx, booking.id)).toBe('NEEDS_RESCHEDULE');
        expect((await notifications(tx, buyer)).map((n) => n.code)).toContain(
          'BOOKING_NEEDS_RESCHEDULE',
        );
      });
    });

    it('an expired offer can no longer be accepted', async () => {
      await withRollback(sql, async (tx) => {
        const tech = await createTechnician(tx);
        const { booking } = await offered(tx, tech.techId);
        const offer = must(await openOffer(tx, booking.id));
        await asSystem(tx);
        await tx`update public.booking_offers set expires_at = now() - interval '1 second' where id = ${offer.id}`;
        await asUser(tx, tech.userId);
        expect(
          await failure(tx, (sp) => sp`select public.tech_respond_offer(${offer.id}, true)`),
        ).toEqual({
          code: 'PT409',
          message: 'OFFER_CLOSED',
        });
      });
    });

    it('accepted: the shop learns who collects the parts; after NEEDS_RESCHEDULE the buyer picks a new time', async () => {
      await withRollback(sql, async (tx) => {
        const shop = await shopWithListing(tx, { price: 12000 });
        const tech = await createTechnician(tx);
        const buyer = await createBuyer(tx);
        const b = await hold(tx, buyer, {
          technicianId: tech.techId,
          start,
          items: [{ listing_id: shop.listingId }],
        });
        await checkoutBooking(
          tx,
          buyer,
          b,
          [{ listing_id: shop.listingId, qty: 1, seen_price_sdg: 12000 }],
          'CASH',
        );
        await accept(tx, tech.userId, b.id);
        expect(await status(tx, b.id)).toBe('ACCEPTED');
        expect((await notifications(tx, shop.owner)).map((n) => n.code)).toContain(
          'TECH_WILL_COLLECT',
        );

        // The technician drops out and nobody else is free.
        await asUser(tx, tech.userId);
        await tx`select public.tech_cancel(${b.id}, 'مريض')`;
        expect(await status(tx, b.id)).toBe('NEEDS_RESCHEDULE');

        await asUser(tx, buyer);
        const later = khartoumAt(16, 2);
        const [row] = await tx<
          { b: BookingJson }[]
        >`select public.buyer_reschedule(${b.id}, ${later}) as b`;
        expect(must(row).b.status).toBe('PENDING_TECH_ACCEPT');
        expect(Date.parse(must(row).b.start_at)).toBe(Date.parse(later));
        expect(must(await openOffer(tx, b.id)).technician_id).toBe(tech.techId);
      });
    });
  });

  describe('job day', () => {
    it('parts first, then on the way with a live location only the buyer sees, then the job code closes it', async () => {
      await withRollback(sql, async (tx) => {
        await setStreetOrigin(tx);
        const shop = await shopWithListing(tx, { price: 12000 });
        const tech = await createTechnician(tx);
        const buyer = await createBuyer(tx);
        const address = await addAddress(tx, buyer);
        const b = await hold(tx, buyer, {
          technicianId: tech.techId,
          start,
          items: [{ listing_id: shop.listingId }],
          place: 'CUSTOMER_LOCATION',
          addressId: address,
        });
        const order = await checkoutBooking(
          tx,
          buyer,
          b,
          [{ listing_id: shop.listingId, qty: 1, seen_price_sdg: 12000 }],
          'BANKAK',
        );
        const sub = must(order.sub_orders[0]).id;
        await payByBankak(tx, order);
        await asUser(tx, shop.owner);
        await tx`select public.shop_mark_ready(${sub})`;
        expect(await failure(tx, (sp) => sp`select public.shop_hand_over(${sub})`)).toEqual({
          code: 'PT409',
          message: 'TECHNICIAN_NOT_ASSIGNED',
        });
        await accept(tx, tech.userId, b.id);
        await asUser(tx, tech.userId);
        expect(await failure(tx, (sp) => sp`select public.tech_en_route(${b.id})`)).toEqual({
          code: 'PT409',
          message: 'PARTS_NOT_COLLECTED',
        });
        await asUser(tx, shop.owner);
        await tx`select public.shop_hand_over(${sub})`;

        await asUser(tx, tech.userId);
        await tx`select public.tech_en_route(${b.id})`;
        await tx`select public.tech_update_location(${b.id}, 15.605, 32.5)`;
        await asUser(tx, buyer);
        expect(
          await tx`select * from public.tech_locations where booking_id = ${b.id}`,
        ).toHaveLength(1);
        const stranger = await createBuyer(tx);
        await asUser(tx, stranger);
        expect(
          await tx`select * from public.tech_locations where booking_id = ${b.id}`,
        ).toHaveLength(0);

        await asSystem(tx);
        await tx`update public.bookings set start_at = now() + interval '30 minutes', end_at = now() + interval '90 minutes',
                   block_from = now(), block_to = now() + interval '2 hours' where id = ${b.id}`;
        await asUser(tx, tech.userId);
        await tx`select public.tech_check_in(${b.id})`;
        await asUser(tx, buyer);
        expect(
          await tx`select * from public.tech_locations where booking_id = ${b.id}`,
        ).toHaveLength(0);

        const code = await jobCode(tx, b.id);
        await asUser(tx, tech.userId);
        const [wrong] = await tx<{ r: { ok: boolean; error: string; attempts_left: number } }[]>`
          select public.tech_complete(${b.id}, ${code === '0000' ? '1111' : '0000'}) as r`;
        expect(must(wrong).r).toEqual({ ok: false, error: 'WRONG_JOB_CODE', attempts_left: 4 });
        const [right] = await tx<{ r: { ok: boolean; booking: BookingJson } }[]>`
          select public.tech_complete(${b.id}, ${code}) as r`;
        expect(must(right).r.ok).toBe(true);
        expect(must(right).r.booking.status).toBe('COMPLETED');

        await asSystem(tx);
        const [s] = await tx<
          { status: string }[]
        >`select status from public.sub_orders where id = ${sub}`;
        expect(must(s).status).toBe('COMPLETED');
        const [t] = await tx<
          { completed_jobs: number }[]
        >`select completed_jobs from public.technicians where id = ${tech.techId}`;
        expect(must(t).completed_jobs).toBe(11);
      });
    });

    it('five wrong codes lock completion and tell the admins; an admin can then complete', async () => {
      await withRollback(sql, async (tx) => {
        const admin = await createAdmin(tx);
        const tech = await createTechnician(tx);
        const buyer = await createBuyer(tx);
        const b = await hold(tx, buyer, {
          technicianId: tech.techId,
          start,
          items: [await elsewhere(tx)],
        });
        await checkoutBooking(tx, buyer, b, [], 'CASH');
        await accept(tx, tech.userId, b.id);
        await asSystem(tx);
        await tx`update public.bookings set start_at = now() + interval '30 minutes', end_at = now() + interval '60 minutes',
                   block_from = now() + interval '30 minutes', block_to = now() + interval '60 minutes' where id = ${b.id}`;
        await asUser(tx, tech.userId);
        await tx`select public.tech_check_in(${b.id})`;
        const code = await jobCode(tx, b.id);
        const wrong = code === '0000' ? '1111' : '0000';
        await asUser(tx, tech.userId);
        for (let i = 0; i < 4; i++) await tx`select public.tech_complete(${b.id}, ${wrong})`;
        const [fifth] = await tx<
          { r: { error: string } }[]
        >`select public.tech_complete(${b.id}, ${wrong}) as r`;
        expect(must(fifth).r.error).toBe('JOB_CODE_LOCKED');
        expect(
          await failure(tx, (sp) => sp`select public.tech_complete(${b.id}, ${code})`),
        ).toEqual({
          code: 'PT409',
          message: 'JOB_CODE_LOCKED',
        });
        expect(await notifications(tx, admin)).toContainEqual({
          code: 'JOB_CODE_LOCKED',
          app: 'admin',
        });
        await asUser(tx, admin);
        await tx`select public.admin_complete_booking(${b.id})`;
        expect(await status(tx, b.id)).toBe('COMPLETED');
      });
    });

    it('reminders go out a day and an hour before, once each', async () => {
      await withRollback(sql, async (tx) => {
        const tech = await createTechnician(tx);
        const buyer = await createBuyer(tx);
        const b = await hold(tx, buyer, {
          technicianId: tech.techId,
          start,
          items: [await elsewhere(tx)],
        });
        await checkoutBooking(tx, buyer, b, [], 'CASH');
        await accept(tx, tech.userId, b.id);
        await asSystem(tx);
        await tx`update public.bookings set start_at = now() + interval '20 hours', end_at = now() + interval '21 hours',
                   block_from = now() + interval '20 hours', block_to = now() + interval '21 hours' where id = ${b.id}`;
        await tx`select public.send_booking_reminders()`;
        await tx`select public.send_booking_reminders()`;
        await tx`update public.bookings set start_at = now() + interval '40 minutes', end_at = now() + interval '100 minutes',
                   block_from = now() + interval '40 minutes', block_to = now() + interval '100 minutes' where id = ${b.id}`;
        await tx`select public.send_booking_reminders()`;
        const codes = (await notifications(tx, buyer))
          .map((n) => n.code)
          .filter((c) => c.startsWith('BOOKING_REMINDER'));
        expect(codes).toEqual(['BOOKING_REMINDER_DAY', 'BOOKING_REMINDER_HOUR']);
        expect(await notifications(tx, tech.userId)).toContainEqual({
          code: 'BOOKING_REMINDER_HOUR',
          app: 'partner',
        });
      });
    });

    it('only the booking’s technician may act on it', async () => {
      await withRollback(sql, async (tx) => {
        const tech = await createTechnician(tx);
        const other = await createTechnician(tx);
        const buyer = await createBuyer(tx);
        const b = await hold(tx, buyer, {
          technicianId: tech.techId,
          start,
          items: [await elsewhere(tx)],
        });
        await checkoutBooking(tx, buyer, b, [], 'CASH');
        await accept(tx, tech.userId, b.id);
        await asUser(tx, other.userId);
        expect(await failure(tx, (sp) => sp`select public.tech_check_in(${b.id})`)).toEqual({
          code: 'P0002',
          message: 'BOOKING_NOT_FOUND',
        });
        expect(await tx`select * from public.bookings where id = ${b.id}`).toHaveLength(0);
        await asUser(tx, buyer);
        expect(await failure(tx, (sp) => sp`select public.tech_check_in(${b.id})`)).toEqual({
          code: '42501',
          message: 'NOT_A_TECHNICIAN',
        });
      });
    });
  });
});

describe.runIf(!hasDb)('bookings (skipped)', () => {
  it.skip(skipReason, () => undefined);
});
