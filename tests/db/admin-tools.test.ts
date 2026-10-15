import { afterAll, describe, expect, it } from 'vitest';
import { connect, hasDb, must, withRollback, type Sql, type Tx } from '../support/db.ts';
import { asSystem, asUser, createAdmin, createUser, failure } from '../support/fixtures.ts';
import {
  createBuyer,
  placeOrder,
  shopBalance,
  shopWithListing,
  unbalancedJournals,
} from '../support/commerce.ts';

/** Today's date in Khartoum (UTC+2), as the report takes it. */
const today = () => new Date(Date.now() + 2 * 3600_000).toISOString().slice(0, 10);

type Report = {
  days: { day: string; orders: number; sales_sdg: number; commission_sdg: number }[];
  totals: Record<string, number | null>;
  top_shops: { shop_id: string; orders: number; sales_sdg: number }[];
};

async function report(tx: Tx, admin: string, from = today(), to = today()): Promise<Report> {
  await asUser(tx, admin);
  const [row] = await tx<
    { r: Report }[]
  >`select public.admin_report(${from}::date, ${to}::date) as r`;
  return must(row).r;
}

async function alerts(
  tx: Tx,
  userId: string,
  code: string,
): Promise<{ app: string; payload: Record<string, unknown> }[]> {
  await asSystem(tx);
  return tx<{ app: string; payload: Record<string, unknown> }[]>`
    select app, payload from public.notifications where user_id = ${userId} and code = ${code}`;
}

describe.skipIf(!hasDb)('admin tools (M6)', () => {
  const sql: Sql = connect();
  afterAll(() => sql.end());

  describe('reports', () => {
    it('count paid and cash sales once, by Khartoum day, with the shops that made them', () =>
      withRollback(sql, async (tx) => {
        const admin = await createAdmin(tx);
        const before = await report(tx, admin);
        const { shopId, listingId, price } = await shopWithListing(tx, { price: 20000, qty: 10 });
        const buyer = await createBuyer(tx);
        const line = (qty: number) => [{ listing_id: listingId, qty, seen_price_sdg: price }];
        await placeOrder(tx, buyer, line(2), { method: 'CASH' });
        await placeOrder(tx, buyer, line(1)); // Bankak, not paid: not a sale yet
        const cancelled = await placeOrder(tx, buyer, line(1), { method: 'CASH' });
        await asUser(tx, buyer);
        await tx`select public.cancel_order(${cancelled.id})`;

        const r = await report(tx, admin);
        const day = must(r.days.at(-1));
        const was = must(before.days.at(-1));
        expect(day.day).toBe(today());
        expect(day.orders - was.orders).toBe(1);
        expect(day.sales_sdg - was.sales_sdg).toBe(40000);
        expect(day.commission_sdg - was.commission_sdg).toBe(2000);
        expect((r.totals.cash_orders ?? 0) - (before.totals.cash_orders ?? 0)).toBe(1);
        expect(r.top_shops.find((s) => s.shop_id === shopId)).toMatchObject({
          orders: 1,
          sales_sdg: 40000,
        });
      }));

    it('admins only, and only sensible periods', () =>
      withRollback(sql, async (tx) => {
        const user = await createUser(tx);
        await asUser(tx, user);
        expect(
          await failure(
            tx,
            (sp) => sp`select public.admin_report(${today()}::date, ${today()}::date)`,
          ),
        ).toMatchObject({ message: 'FORBIDDEN' });
        const admin = await createAdmin(tx);
        await asUser(tx, admin);
        expect(
          await failure(
            tx,
            (sp) => sp`select public.admin_report('2026-10-10'::date, '2026-10-01'::date)`,
          ),
        ).toMatchObject({ message: 'INVALID_VALUE' });
        expect(
          await failure(
            tx,
            (sp) => sp`select public.admin_report('2025-01-01'::date, '2026-10-01'::date)`,
          ),
        ).toMatchObject({ message: 'INVALID_VALUE' });
      }));
  });

  describe('balance corrections', () => {
    it('move a shop balance both ways, show on its statement, balance and get audited', () =>
      withRollback(sql, async (tx) => {
        const admin = await createAdmin(tx);
        const { owner, shopId } = await shopWithListing(tx);
        const start = await shopBalance(tx, shopId);
        await asUser(tx, admin);
        const [up] = await tx<{ b: string }[]>`
          select public.admin_ledger_adjustment(5000, 'تعويض عن شحنة تالفة', p_shop_id => ${shopId}) as b`;
        expect(Number(must(up).b)).toBe(start + 5000);
        const [down] = await tx<{ b: string }[]>`
          select public.admin_ledger_adjustment(-2000, 'Correction', p_shop_id => ${shopId}) as b`;
        expect(Number(must(down).b)).toBe(start + 3000);
        expect(await unbalancedJournals(tx)).toEqual([]);

        await asUser(tx, owner);
        const [st] = await tx<{ s: { lines: { kind: string; amount_sdg: number }[] } }[]>`
          select public.shop_statement(${shopId}, null, null) as s`;
        expect(
          must(st)
            .s.lines.filter((l) => l.kind === 'ADJUSTMENT')
            .map((l) => l.amount_sdg)
            .sort(),
        ).toEqual([-2000, 5000]);

        await asSystem(tx);
        const audit = await tx<{ data: { amount_sdg: number } }[]>`
          select data from public.audit_log where action = 'ADJUST_BALANCE' and entity_id = ${shopId} order by id`;
        expect(audit.map((a) => a.data.amount_sdg)).toEqual([5000, -2000]);
      }));

    it('need an admin, one partner, an amount and a reason', () =>
      withRollback(sql, async (tx) => {
        const { owner, shopId } = await shopWithListing(tx);
        await asUser(tx, owner);
        expect(
          await failure(
            tx,
            (sp) => sp`select public.admin_ledger_adjustment(100, 'x', p_shop_id => ${shopId})`,
          ),
        ).toMatchObject({ message: 'FORBIDDEN' });
        const admin = await createAdmin(tx);
        await asUser(tx, admin);
        for (const [amount, reason, code] of [
          [0, 'x', 'INVALID_VALUE'],
          [100, '  ', 'REASON_REQUIRED'],
        ] as const) {
          expect(
            await failure(
              tx,
              (sp) =>
                sp`select public.admin_ledger_adjustment(${amount}, ${reason}, p_shop_id => ${shopId})`,
            ),
          ).toMatchObject({ message: code });
        }
        expect(
          await failure(tx, (sp) => sp`select public.admin_ledger_adjustment(100, 'x')`),
        ).toMatchObject({
          message: 'INVALID_VALUE',
        });
      }));
  });

  it('alert wording an admin changes is audited', () =>
    withRollback(sql, async (tx) => {
      const admin = await createAdmin(tx);
      await asUser(tx, admin);
      await tx`update public.notification_templates set body = 'طلب جديد {ref}.' where code = 'NEW_ORDER' and locale = 'ar'`;
      await asSystem(tx);
      const [row] = await tx<{ data: { new: { body: string } } }[]>`
        select data from public.audit_log where entity = 'notification_template' and entity_id = 'NEW_ORDER:ar'`;
      expect(must(row).data.new.body).toBe('طلب جديد {ref}.');
    }));

  it('complaints: the shop hears one was opened, and each side hears the decision in its own app', () =>
    withRollback(sql, async (tx) => {
      const { owner, listingId, price } = await shopWithListing(tx);
      const buyer = await createBuyer(tx);
      const order = await placeOrder(
        tx,
        buyer,
        [{ listing_id: listingId, qty: 1, seen_price_sdg: price }],
        {
          method: 'CASH',
        },
      );
      const sub = must(order.sub_orders[0]).id;
      await asUser(tx, buyer);
      const [opened] = await tx<{ d: { id: string } }[]>`
        select public.open_dispute('WRONG_PART', 'وصلتني قطعة غير المطلوبة', p_sub_order_id => ${sub}) as d`;
      const dispute = must(opened).d.id;
      expect(await alerts(tx, owner, 'DISPUTE_FILED')).toEqual([
        { app: 'partner', payload: { dispute_id: dispute, ref: order.ref } },
      ]);
      expect(await alerts(tx, buyer, 'DISPUTE_FILED')).toEqual([]);

      const admin = await createAdmin(tx);
      await asUser(tx, admin);
      await tx`select public.admin_update_dispute(${dispute}, 'RESOLVED', 'استُبدلت القطعة')`;
      expect((await alerts(tx, buyer, 'DISPUTE_RESOLVED')).map((a) => a.app)).toEqual(['buyer']);
      expect((await alerts(tx, owner, 'DISPUTE_RESOLVED')).map((a) => a.app)).toEqual(['partner']);
    }));
});
