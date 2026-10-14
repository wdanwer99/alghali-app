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
import { asSystem, asUser, createAdmin } from '../support/fixtures.ts';
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
  type Place,
} from '../support/bookings.ts';
import {
  balance,
  createBuyer,
  payByBankak,
  shopWithListing,
  unbalancedJournals,
  type OrderJson,
} from '../support/commerce.ts';

// D-013's worked example: bulbs 12,000, labour 6,000, travel 3,000 (≤ 3 km), booking fee
// 2,000, commission 5% = 600, mobile deposit 5,000.
const PRICE = 12000;
const LABOUR = 6000;
const TRAVEL = 3000;
const FEE = 2000;
const COMMISSION = 600;
const DEPOSIT = 5000;

interface Job {
  shop: Awaited<ReturnType<typeof shopWithListing>>;
  tech: Awaited<ReturnType<typeof createTechnician>>;
  buyer: string;
  booking: BookingJson;
  order: OrderJson & { booking: BookingJson };
  sub: string;
}

/** A buyer books the bulbs with a fitting, pays, and the technician accepts. */
async function bookedJob(tx: Tx, method: 'BANKAK' | 'CASH', place: Place): Promise<Job> {
  await setStreetOrigin(tx);
  const shop = await shopWithListing(tx, { price: PRICE, category: 'lighting', name: 'لمبات H4' });
  const tech = await createTechnician(tx, { jobs: { LIGHTING: LABOUR } });
  const buyer = await createBuyer(tx);
  const address = place === 'CUSTOMER_LOCATION' ? await addAddress(tx, buyer) : undefined;
  const booking = await hold(tx, buyer, {
    technicianId: tech.techId,
    start: khartoumAt(10),
    items: [{ listing_id: shop.listingId }],
    place,
    ...(address ? { addressId: address } : {}),
  });
  await asUser(tx, buyer);
  const [row] = await tx<{ o: OrderJson & { booking: BookingJson } }[]>`
    select public.checkout(p_items => ${tx.json([{ listing_id: shop.listingId, qty: 1, seen_price_sdg: PRICE }] as never)},
                           p_method => ${method}::public.payment_method, p_booking_id => ${booking.id}) as o`;
  const order = must(row).o;
  if (order.payments.some((p) => p.method === 'BANKAK')) await payByBankak(tx, order);
  await accept(tx, tech.userId, booking.id);
  return { shop, tech, buyer, booking, order, sub: must(order.sub_orders[0]).id };
}

/** The shop hands the bulbs over, the technician arrives and starts. */
async function startJob(tx: Tx, job: Job): Promise<void> {
  await asUser(tx, job.shop.owner);
  await tx`select public.shop_mark_ready(${job.sub})`;
  await tx`select public.shop_hand_over(${job.sub})`;
  await asSystem(tx);
  await tx`update public.bookings set start_at = now() + interval '30 minutes', end_at = now() + interval '60 minutes',
             block_from = now(), block_to = now() + interval '90 minutes' where id = ${job.booking.id}`;
  await asUser(tx, job.tech.userId);
  if (job.booking.place === 'CUSTOMER_LOCATION')
    await tx`select public.tech_en_route(${job.booking.id})`;
  await tx`select public.tech_check_in(${job.booking.id})`;
}

async function finishJob(tx: Tx, job: Job): Promise<void> {
  const code = await jobCode(tx, job.booking.id);
  await asUser(tx, job.tech.userId);
  await tx`select public.tech_complete(${job.booking.id}, ${code})`;
}

async function refunds(tx: Tx, orderId: string): Promise<number[]> {
  await asSystem(tx);
  const rows = await tx<{ amount_sdg: string }[]>`
    select amount_sdg from public.refunds where order_id = ${orderId} order by amount_sdg`;
  return rows.map((r) => Number(r.amount_sdg));
}

async function cashCollected(tx: Tx, bookingId: string): Promise<number[]> {
  await asSystem(tx);
  const rows = await tx<{ amount_sdg: string }[]>`
    select amount_sdg from public.payments where booking_id = ${bookingId} and method = 'CASH' and status = 'COLLECTED'`;
  return rows.map((r) => Number(r.amount_sdg));
}

// Each case builds technicians, shops and orders over the internet: give it time.
describe.skipIf(!hasDb)('booking money', { timeout: 90_000 }, () => {
  const sql: Sql = connect();
  afterAll(() => sql.end());

  it('Bankak, fitted at home: shop 11,400, technician 9,000, revenue 2,600 (D-013)', async () => {
    await withRollback(sql, async (tx) => {
      const before = await balance(tx, 'REVENUE_BOOKING_FEE');
      const job = await bookedJob(tx, 'BANKAK', 'CUSTOMER_LOCATION');
      expect(job.order.total_sdg).toBe(PRICE + LABOUR + TRAVEL + FEE);
      await startJob(tx, job);
      await finishJob(tx, job);
      expect(await shopOwed(tx, job.shop.shopId)).toBe(PRICE - COMMISSION);
      expect(await techBalance(tx, job.tech.techId)).toBe(LABOUR + TRAVEL);
      expect((await balance(tx, 'REVENUE_BOOKING_FEE')) - before).toBe(-FEE);
      expect(await heldFor(tx, job.order.id)).toBe(0);
      expect(await unbalancedJournals(tx)).toEqual([]);
    });
  });

  it('cash to the technician with a Bankak deposit: shop owes 600, platform owes the technician 3,000 (D-013)', async () => {
    await withRollback(sql, async (tx) => {
      const job = await bookedJob(tx, 'CASH', 'CUSTOMER_LOCATION');
      expect(job.order.booking.deposit_sdg).toBe(DEPOSIT);
      await startJob(tx, job);
      // The technician paid the shop for the bulbs at hand-over (D-011).
      expect(await shopOwed(tx, job.shop.shopId)).toBe(-PRICE);
      await finishJob(tx, job);
      expect(await cashCollected(tx, job.booking.id)).toEqual([
        PRICE + LABOUR + TRAVEL + FEE - DEPOSIT,
      ]);
      expect(await shopOwed(tx, job.shop.shopId)).toBe(-COMMISSION);
      expect(await techBalance(tx, job.tech.techId)).toBe(DEPOSIT - FEE);
      expect(await heldFor(tx, job.order.id)).toBe(0);
      expect(await unbalancedJournals(tx)).toEqual([]);
    });
  });

  it('cash at a bay, nothing upfront: the technician owes the booking fee', async () => {
    await withRollback(sql, async (tx) => {
      const job = await bookedJob(tx, 'CASH', 'BAY');
      await startJob(tx, job);
      await finishJob(tx, job);
      expect(await cashCollected(tx, job.booking.id)).toEqual([PRICE + LABOUR + FEE]);
      expect(await techBalance(tx, job.tech.techId)).toBe(-FEE);
      expect(await shopOwed(tx, job.shop.shopId)).toBe(-COMMISSION);
      expect(await heldFor(tx, job.order.id)).toBe(0);
      expect(await unbalancedJournals(tx)).toEqual([]);
    });
  });

  it('part does not fit (Bankak): travel fee only, labour and fee refunded, a return opened (D-019)', async () => {
    await withRollback(sql, async (tx) => {
      const job = await bookedJob(tx, 'BANKAK', 'CUSTOMER_LOCATION');
      await startJob(tx, job);
      await asUser(tx, job.tech.userId);
      await tx`select public.tech_part_not_fit(${job.booking.id}, 'المقاس مختلف')`;
      expect(await refunds(tx, job.order.id)).toEqual([LABOUR + FEE]);
      expect(await techBalance(tx, job.tech.techId)).toBe(TRAVEL);
      await asSystem(tx);
      const [s] = await tx<
        { status: string }[]
      >`select status from public.sub_orders where id = ${job.sub}`;
      expect(must(s).status).toBe('RETURN_REQUESTED');

      const admin = await createAdmin(tx);
      await asUser(tx, admin);
      await tx`select public.admin_decide_return(${job.sub}, true)`;
      expect(await refunds(tx, job.order.id)).toEqual([LABOUR + FEE, PRICE]);
      expect(await heldFor(tx, job.order.id)).toBe(0);
      expect(await shopOwed(tx, job.shop.shopId)).toBe(0);
      expect(await unbalancedJournals(tx)).toEqual([]);
    });
  });

  it('part does not fit (cash, deposit): the deposit covers travel, the rest comes back, the shop repays the technician', async () => {
    await withRollback(sql, async (tx) => {
      const job = await bookedJob(tx, 'CASH', 'CUSTOMER_LOCATION');
      await startJob(tx, job);
      await asUser(tx, job.tech.userId);
      await tx`select public.tech_part_not_fit(${job.booking.id}, 'المقاس مختلف')`;
      expect(await refunds(tx, job.order.id)).toEqual([DEPOSIT - TRAVEL]);
      expect(await cashCollected(tx, job.booking.id)).toEqual([]);

      const admin = await createAdmin(tx);
      await asUser(tx, admin);
      await tx`select public.admin_decide_return(${job.sub}, true)`;
      expect(await shopOwed(tx, job.shop.shopId)).toBe(0);
      expect(await techBalance(tx, job.tech.techId)).toBe(TRAVEL);
      expect(await heldFor(tx, job.order.id)).toBe(0);
      expect(await unbalancedJournals(tx)).toEqual([]);
    });
  });

  it('the buyer cancels in good time: everything paid comes back, parts included', async () => {
    await withRollback(sql, async (tx) => {
      const job = await bookedJob(tx, 'BANKAK', 'CUSTOMER_LOCATION');
      await asUser(tx, job.buyer);
      await tx`select public.buyer_cancel_booking(${job.booking.id}, 'تغيرت الخطة')`;
      expect(await refunds(tx, job.order.id)).toEqual([LABOUR + TRAVEL + FEE, PRICE]);
      await asSystem(tx);
      const [s] = await tx<
        { status: string }[]
      >`select status from public.sub_orders where id = ${job.sub}`;
      expect(must(s).status).toBe('CANCELLED');
      expect(await techBalance(tx, job.tech.techId)).toBe(0);
      expect(await heldFor(tx, job.order.id)).toBe(0);
      expect(await unbalancedJournals(tx)).toEqual([]);
    });
  });

  it('the buyer cancels late: the booking fee and travel are kept, labour comes back (D-099)', async () => {
    await withRollback(sql, async (tx) => {
      await asSystem(tx);
      await tx`update public.app_settings set value = '48' where key = 'cancel_cutoff_hours'`;
      const before = await balance(tx, 'REVENUE_BOOKING_FEE');
      const job = await bookedJob(tx, 'BANKAK', 'CUSTOMER_LOCATION');
      await asUser(tx, job.buyer);
      await tx`select public.buyer_cancel_booking(${job.booking.id})`;
      expect(await refunds(tx, job.order.id)).toEqual([LABOUR, PRICE]);
      expect(await techBalance(tx, job.tech.techId)).toBe(TRAVEL);
      expect((await balance(tx, 'REVENUE_BOOKING_FEE')) - before).toBe(-FEE);
      expect(await heldFor(tx, job.order.id)).toBe(0);
      expect(await unbalancedJournals(tx)).toEqual([]);
    });
  });

  it('a late cancellation of a cash job keeps the deposit: fee to the platform, the rest to the technician', async () => {
    await withRollback(sql, async (tx) => {
      await asSystem(tx);
      await tx`update public.app_settings set value = '48' where key = 'cancel_cutoff_hours'`;
      const job = await bookedJob(tx, 'CASH', 'CUSTOMER_LOCATION');
      await asUser(tx, job.buyer);
      await tx`select public.buyer_cancel_booking(${job.booking.id})`;
      expect(await refunds(tx, job.order.id)).toEqual([]);
      expect(await techBalance(tx, job.tech.techId)).toBe(DEPOSIT - FEE);
      expect(await heldFor(tx, job.order.id)).toBe(0);
      expect(await unbalancedJournals(tx)).toEqual([]);
    });
  });

  it('an admin cancellation always refunds in full', async () => {
    await withRollback(sql, async (tx) => {
      await asSystem(tx);
      await tx`update public.app_settings set value = '48' where key = 'cancel_cutoff_hours'`;
      const job = await bookedJob(tx, 'BANKAK', 'BAY');
      const admin = await createAdmin(tx);
      await asUser(tx, admin);
      await tx`select public.admin_cancel_booking(${job.booking.id}, 'الفني غير متاح')`;
      expect(await refunds(tx, job.order.id)).toEqual([LABOUR + FEE, PRICE]);
      expect(await heldFor(tx, job.order.id)).toBe(0);
      expect(await unbalancedJournals(tx)).toEqual([]);
    });
  });

  it('technicians get payouts and statements like shops (D-089)', async () => {
    await withRollback(sql, async (tx) => {
      const job = await bookedJob(tx, 'BANKAK', 'CUSTOMER_LOCATION');
      await startJob(tx, job);
      await finishJob(tx, job);

      await asUser(tx, job.tech.userId);
      const [st] = await tx<
        { s: { closing_sdg: number; lines: { kind: string; amount_sdg: number; ref: string }[] } }[]
      >`
        select public.tech_statement() as s`;
      expect(must(st).s.lines.map((l) => [l.kind, l.amount_sdg, l.ref])).toEqual([
        ['LABOUR', LABOUR, job.booking.ref],
        ['TRAVEL_FEE', TRAVEL, job.booking.ref],
      ]);
      expect(must(st).s.closing_sdg).toBe(LABOUR + TRAVEL);

      const admin = await createAdmin(tx);
      await asUser(tx, admin);
      await tx`select public.admin_generate_payouts()`;
      const [p] = await tx<{ id: string; amount_sdg: string }[]>`
        select id, amount_sdg from public.payouts where technician_id = ${job.tech.techId}`;
      expect(Number(must(p).amount_sdg)).toBe(LABOUR + TRAVEL);
      await tx`select public.admin_approve_payouts(${[must(p).id]}::uuid[])`;
      await tx`select public.admin_mark_payout_paid(${must(p).id}, '777888999')`;
      expect(await techBalance(tx, job.tech.techId)).toBe(0);

      await asUser(tx, admin);
      const rows = await tx<{ r: { party: string; technician_id: string | null } }[]>`
        select r from public.admin_partner_balances() r`;
      expect(rows.some((x) => x.r.party === 'TECH' && x.r.technician_id === job.tech.techId)).toBe(
        true,
      );
      expect(await unbalancedJournals(tx)).toEqual([]);
    });
  });
});

describe.runIf(!hasDb)('booking money (skipped)', () => {
  it.skip(skipReason, () => undefined);
});
