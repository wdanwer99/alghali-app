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
import { asSystem, failure } from '../support/fixtures.ts';
import { createBuyer, placeOrder, shopWithListing } from '../support/commerce.ts';

// The specification, written out independently of the migration (PLAN §3.10). Every
// (from, to, actor) not listed here must be refused.
const SUBORDER: Record<string, Record<string, string[]>> = {
  PENDING_PAYMENT: { PAYMENT_REVIEW: ['BUYER'], CANCELLED: ['BUYER', 'SYSTEM', 'ADMIN'] },
  PAYMENT_REVIEW: { CONFIRMED: ['ADMIN'], PENDING_PAYMENT: ['ADMIN'], CANCELLED: ['ADMIN'] },
  CONFIRMED: {
    READY: ['SHOP'],
    REJECTED_BY_SHOP: ['SHOP'],
    CANCELLED: ['BUYER', 'ADMIN', 'SYSTEM'],
  },
  READY: {
    PICKED_UP: ['SHOP'],
    OUT_FOR_DELIVERY: ['SHOP'],
    HANDED_TO_TECHNICIAN: ['SHOP'],
    REJECTED_BY_SHOP: ['SHOP'],
    CANCELLED: ['ADMIN', 'SYSTEM'],
  },
  OUT_FOR_DELIVERY: { DELIVERED: ['SHOP'], CANCELLED: ['ADMIN'] },
  PICKED_UP: { COMPLETED: ['BUYER', 'SYSTEM', 'ADMIN'], RETURN_REQUESTED: ['BUYER'] },
  DELIVERED: { COMPLETED: ['BUYER', 'SYSTEM', 'ADMIN'], RETURN_REQUESTED: ['BUYER'] },
  // SYSTEM: the parts follow their fitting (D-098).
  HANDED_TO_TECHNICIAN: {
    COMPLETED: ['SYSTEM', 'ADMIN'],
    RETURN_REQUESTED: ['SYSTEM'],
    CANCELLED: ['SYSTEM'],
  },
  COMPLETED: { RETURN_REQUESTED: ['BUYER'] },
  RETURN_REQUESTED: { RETURNED: ['ADMIN'], COMPLETED: ['ADMIN'] },
  CANCELLED: {},
  REJECTED_BY_SHOP: {},
  RETURNED: {},
};

const PAYMENT: Record<string, Record<string, string[]>> = {
  AWAITING_TRANSFER: {
    RECEIPT_SUBMITTED: ['BUYER'],
    EXPIRED: ['SYSTEM'],
    CANCELLED: ['BUYER', 'ADMIN'],
  },
  RECEIPT_SUBMITTED: { CONFIRMED: ['ADMIN'], REJECTED: ['ADMIN'], CANCELLED: ['ADMIN'] },
  REJECTED: { RECEIPT_SUBMITTED: ['BUYER'], EXPIRED: ['SYSTEM'], CANCELLED: ['BUYER', 'ADMIN'] },
  // SYSTEM: cash a technician took at the job (D-098).
  DUE: { COLLECTED: ['SHOP', 'SYSTEM'], CANCELLED: ['BUYER', 'SHOP', 'ADMIN', 'SYSTEM'] },
  CONFIRMED: {},
  COLLECTED: {},
  EXPIRED: {},
  CANCELLED: {},
};

// PLAN §3.10 with D-024 (decline and timeout are offer statuses) and D-097–D-099.
const BOOKING: Record<string, Record<string, string[]>> = {
  HELD: {
    AWAITING_PAYMENT: ['BUYER'],
    PENDING_TECH_ACCEPT: ['BUYER'],
    EXPIRED: ['SYSTEM'],
    CANCELLED_BY_BUYER: ['BUYER'],
  },
  AWAITING_PAYMENT: {
    PENDING_TECH_ACCEPT: ['ADMIN'],
    NEEDS_RESCHEDULE: ['ADMIN'],
    EXPIRED: ['SYSTEM'],
    CANCELLED_BY_BUYER: ['BUYER'],
    CANCELLED_BY_ADMIN: ['ADMIN', 'SYSTEM'],
  },
  PENDING_TECH_ACCEPT: {
    ACCEPTED: ['TECH'],
    NEEDS_RESCHEDULE: ['TECH', 'SYSTEM', 'ADMIN'],
    CANCELLED_BY_BUYER: ['BUYER'],
    CANCELLED_BY_ADMIN: ['ADMIN', 'SYSTEM'],
  },
  ACCEPTED: {
    EN_ROUTE: ['TECH'],
    IN_PROGRESS: ['TECH'],
    PENDING_TECH_ACCEPT: ['TECH', 'ADMIN'],
    NEEDS_RESCHEDULE: ['TECH', 'ADMIN'],
    CANCELLED_BY_BUYER: ['BUYER'],
    CANCELLED_BY_ADMIN: ['ADMIN', 'SYSTEM'],
  },
  EN_ROUTE: { IN_PROGRESS: ['TECH'], CANCELLED_BY_BUYER: ['BUYER'], CANCELLED_BY_ADMIN: ['ADMIN'] },
  IN_PROGRESS: {
    COMPLETED: ['TECH', 'ADMIN'],
    PART_DOES_NOT_FIT: ['TECH'],
    CANCELLED_BY_ADMIN: ['ADMIN'],
  },
  NEEDS_RESCHEDULE: {
    PENDING_TECH_ACCEPT: ['BUYER'],
    CANCELLED_BY_BUYER: ['BUYER'],
    CANCELLED_BY_ADMIN: ['ADMIN', 'SYSTEM'],
    EXPIRED: ['SYSTEM'],
  },
  COMPLETED: {},
  EXPIRED: {},
  CANCELLED_BY_BUYER: {},
  CANCELLED_BY_TECH: {},
  CANCELLED_BY_ADMIN: {},
  PART_DOES_NOT_FIT: {},
};

const ACTORS = ['BUYER', 'SHOP', 'ADMIN', 'SYSTEM'];
const BOOKING_ACTORS = ['BUYER', 'TECH', 'SHOP', 'ADMIN', 'SYSTEM'];

function cases(spec: Record<string, Record<string, string[]>>, actors = ACTORS) {
  const states = Object.keys(spec);
  return states.flatMap((from) =>
    states.flatMap((to) =>
      actors.map((actor) => [from, to, actor, (spec[from]?.[to] ?? []).includes(actor)] as const),
    ),
  );
}

describe.skipIf(!hasDb)('state machines', () => {
  const sql: Sql = connect();
  afterAll(() => sql.end());

  it('the spec covers every sub-order and payment status', async () => {
    const enums = await sql<{ t: string; v: string }[]>`
      select t.typname as t, e.enumlabel as v from pg_enum e join pg_type t on t.oid = e.enumtypid
      where t.typname in ('suborder_status', 'payment_status', 'booking_status')`;
    const of = (t: string) =>
      enums
        .filter((e) => e.t === t)
        .map((e) => e.v)
        .sort();
    expect(of('suborder_status')).toEqual(Object.keys(SUBORDER).sort());
    expect(of('payment_status')).toEqual(Object.keys(PAYMENT).sort());
    expect(of('booking_status')).toEqual(Object.keys(BOOKING).sort());
  });

  it('booking transitions: the table allows exactly the spec', async () => {
    const rows = await sql<{ from_status: string; to_status: string; actor: string }[]>`
      select from_status, to_status, actor from public.booking_transitions`;
    const allowed = new Set(rows.map((r) => `${r.from_status}>${r.to_status}>${r.actor}`));
    const mismatches = cases(BOOKING, BOOKING_ACTORS)
      .filter(([f, t, a, ok]) => allowed.has(`${f}>${t}>${a}`) !== ok)
      .map(([f, t, a, ok]) => `${f} → ${t} by ${a}: expected ${ok ? 'allowed' : 'refused'}`);
    expect(mismatches).toEqual([]);
  });

  it('sub-order transitions: the table allows exactly the spec (all from × to × actor)', async () => {
    const rows = await sql<{ from_status: string; to_status: string; actor: string }[]>`
      select from_status, to_status, actor from public.suborder_transitions`;
    const allowed = new Set(rows.map((r) => `${r.from_status}>${r.to_status}>${r.actor}`));
    const mismatches = cases(SUBORDER)
      .filter(([f, t, a, ok]) => allowed.has(`${f}>${t}>${a}`) !== ok)
      .map(([f, t, a, ok]) => `${f} → ${t} by ${a}: expected ${ok ? 'allowed' : 'refused'}`);
    expect(mismatches).toEqual([]);
  });

  it('payment transitions: the table allows exactly the spec', async () => {
    const rows = await sql<{ from_status: string; to_status: string; actor: string }[]>`
      select from_status, to_status, actor from public.payment_transitions`;
    const allowed = new Set(rows.map((r) => `${r.from_status}>${r.to_status}>${r.actor}`));
    const mismatches = cases(PAYMENT)
      .filter(([f, t, a, ok]) => allowed.has(`${f}>${t}>${a}`) !== ok)
      .map(([f, t, a, ok]) => `${f} → ${t} by ${a}: expected ${ok ? 'allowed' : 'refused'}`);
    expect(mismatches).toEqual([]);
  });

  it('the guard enforces the table on real rows, and refuses updates with no declared actor', async () => {
    await withRollback(sql, async (tx) => {
      const shop = await shopWithListing(tx);
      const buyer = await createBuyer(tx);
      const order = await placeOrder(tx, buyer, [
        { listing_id: shop.listingId, qty: 1, seen_price_sdg: shop.price },
      ]);
      const sub = must(order.sub_orders[0]).id;
      await asSystem(tx);

      // Even the database owner (e.g. the SQL editor) can't change a status by hand.
      const raw = await failure(
        tx,
        (sp) => sp`update public.sub_orders set status = 'COMPLETED' where id = ${sub}`,
      );
      expect(raw).toEqual({ code: 'PT409', message: 'INVALID_TRANSITION' });

      const move = (actor: string, to: string) => async (sp: Tx) => {
        await sp`select set_config('app.actor', ${actor}, true)`;
        await sp`update public.sub_orders set status = ${to}::public.suborder_status where id = ${sub}`;
      };
      expect((await failure(tx, move('SHOP', 'PAYMENT_REVIEW'))).message).toBe(
        'INVALID_TRANSITION',
      );
      expect((await failure(tx, move('BUYER', 'CONFIRMED'))).message).toBe('INVALID_TRANSITION');
      await move('BUYER', 'PAYMENT_REVIEW')(tx);
      const [row] = await tx`select status from public.sub_orders where id = ${sub}`;
      expect(row?.status).toBe('PAYMENT_REVIEW');
    });
  });

  it('payment guard: same rules on payment rows', async () => {
    await withRollback(sql, async (tx) => {
      const shop = await shopWithListing(tx);
      const buyer = await createBuyer(tx);
      const order = await placeOrder(tx, buyer, [
        { listing_id: shop.listingId, qty: 1, seen_price_sdg: shop.price },
      ]);
      const pay = must(order.payments[0]).id;
      await asSystem(tx);
      expect(
        await failure(
          tx,
          (sp) => sp`update public.payments set status = 'CONFIRMED' where id = ${pay}`,
        ),
      ).toEqual({
        code: 'PT409',
        message: 'INVALID_TRANSITION',
      });
      await tx`select set_config('app.actor', 'ADMIN', true)`;
      expect(
        (
          await failure(
            tx,
            (sp) => sp`update public.payments set status = 'CONFIRMED' where id = ${pay}`,
          )
        ).message,
      ).toBe('INVALID_TRANSITION');
    });
  });

  it('every move writes an event row with who did it', async () => {
    await withRollback(sql, async (tx) => {
      const shop = await shopWithListing(tx);
      const buyer = await createBuyer(tx);
      const order = await placeOrder(
        tx,
        buyer,
        [{ listing_id: shop.listingId, qty: 1, seen_price_sdg: shop.price }],
        {
          method: 'CASH',
        },
      );
      const sub = must(order.sub_orders[0]).id;
      await asSystem(tx);
      await tx`select public.transition_suborder(${sub}, 'READY', 'SHOP')`;
      const events = await tx`select from_status, to_status, actor_kind from public.suborder_events
                              where sub_order_id = ${sub} order by id`;
      expect(events).toEqual([
        { from_status: null, to_status: 'CONFIRMED', actor_kind: 'BUYER' },
        { from_status: 'CONFIRMED', to_status: 'READY', actor_kind: 'SHOP' },
      ]);
    });
  });
});

describe.runIf(!hasDb)('state machines (skipped)', () => {
  it.skip(skipReason, () => undefined);
});
