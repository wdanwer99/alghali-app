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
import { asSystem, asUser, createAdmin, failure } from '../support/fixtures.ts';
import {
  balance,
  createBuyer,
  journalKinds,
  payByBankak,
  placeOrder,
  randomTxn,
  shopBalance,
  shopFulfils,
  shopWithListing,
  unbalancedJournals,
} from '../support/commerce.ts';

/** Money held for one order (BUYER_FUNDS_HELD entries tied to it). */
async function heldFor(tx: Tx, orderId: string): Promise<number> {
  await asSystem(tx);
  const [row] = await tx<{ b: string }[]>`
    select coalesce(sum(e.amount_sdg), 0) as b
    from public.ledger_entries e
    join public.ledger_journals j on j.id = e.journal_id
    join public.ledger_accounts a on a.id = e.account_id
    where a.code = 'BUYER_FUNDS_HELD' and j.order_id = ${orderId}`;
  return Number(must(row).b);
}

/** Every account's change caused by one test, measured from a snapshot. */
async function snapshot(tx: Tx) {
  const codes = ['PLATFORM_BANKAK', 'BUYER_FUNDS_HELD', 'REFUNDS_PAYABLE', 'REVENUE_COMMISSION'];
  const base = Object.fromEntries(
    await Promise.all(codes.map(async (c) => [c, await balance(tx, c)] as const)),
  );
  return async () =>
    Object.fromEntries(
      await Promise.all(
        codes.map(async (c) => [c, (await balance(tx, c)) - (base[c] ?? 0)] as const),
      ),
    );
}

describe.skipIf(!hasDb)('ledger', () => {
  const sql: Sql = connect();
  afterAll(() => sql.end());

  it('Bankak pickup: payment → sale → commission; the shop is owed the rest (D-013)', async () => {
    await withRollback(sql, async (tx) => {
      const delta = await snapshot(tx);
      const shop = await shopWithListing(tx, { price: 12000 });
      const buyer = await createBuyer(tx);
      const order = await placeOrder(tx, buyer, [
        { listing_id: shop.listingId, qty: 1, seen_price_sdg: 12000 },
      ]);
      const sub = must(order.sub_orders[0]).id;
      await payByBankak(tx, order);
      await shopFulfils(tx, shop.owner, sub);
      await asUser(tx, buyer);
      await tx`select public.confirm_received(${sub})`;

      expect((await journalKinds(tx, order.id)).sort()).toEqual(['COMMISSION', 'PAYMENT', 'SALE']);
      expect(await delta()).toEqual({
        PLATFORM_BANKAK: 12000,
        BUYER_FUNDS_HELD: 0,
        REFUNDS_PAYABLE: 0,
        REVENUE_COMMISSION: -600,
      });
      expect(await shopBalance(tx, shop.shopId)).toBe(-11400); // credit: the platform owes the shop
      expect(await heldFor(tx, order.id)).toBe(0);
      expect(await unbalancedJournals(tx)).toEqual([]);

      const [l] =
        await tx`select stock_qty, reserved_qty from public.listings where id = ${shop.listingId}`;
      expect(l).toEqual({ stock_qty: 4, reserved_qty: 0 });
    });
  });

  it('cash pickup: the shop keeps the cash and owes the commission', async () => {
    await withRollback(sql, async (tx) => {
      const delta = await snapshot(tx);
      const shop = await shopWithListing(tx, { price: 45000 });
      const buyer = await createBuyer(tx);
      const order = await placeOrder(
        tx,
        buyer,
        [{ listing_id: shop.listingId, qty: 1, seen_price_sdg: 45000 }],
        {
          method: 'CASH',
        },
      );
      const sub = must(order.sub_orders[0]).id;
      await shopFulfils(tx, shop.owner, sub);
      await asSystem(tx);
      const [p] =
        await tx`select status, collected_by from public.payments where sub_order_id = ${sub}`;
      expect(p).toEqual({ status: 'COLLECTED', collected_by: shop.owner });

      await asUser(tx, buyer);
      await tx`select public.confirm_received(${sub})`;
      expect((await journalKinds(tx, order.id)).sort()).toEqual([
        'CASH_COLLECTED',
        'COMMISSION',
        'SALE',
      ]);
      expect(await delta()).toMatchObject({
        PLATFORM_BANKAK: 0,
        BUYER_FUNDS_HELD: 0,
        REVENUE_COMMISSION: -2250,
      });
      expect(await shopBalance(tx, shop.shopId)).toBe(2250); // debit: the shop owes the platform
      expect(await unbalancedJournals(tx)).toEqual([]);
    });
  });

  it('a shop rejects after payment: the buyer is owed a refund; paying it settles everything', async () => {
    await withRollback(sql, async (tx) => {
      const delta = await snapshot(tx);
      const shop = await shopWithListing(tx, { price: 38000 });
      const buyer = await createBuyer(tx);
      const order = await placeOrder(tx, buyer, [
        { listing_id: shop.listingId, qty: 1, seen_price_sdg: 38000 },
      ]);
      const admin = await payByBankak(tx, order);
      await asUser(tx, shop.owner);
      await tx`select public.shop_reject_suborder(${must(order.sub_orders[0]).id}, 'القطعة تالفة')`;
      expect(await delta()).toMatchObject({
        PLATFORM_BANKAK: 38000,
        BUYER_FUNDS_HELD: 0,
        REFUNDS_PAYABLE: -38000,
      });

      await asSystem(tx);
      const [refund] = await tx<
        { id: string }[]
      >`select id from public.refunds where order_id = ${order.id}`;
      await asUser(tx, admin);
      await tx`select public.admin_mark_refund_paid(${must(refund).id}, ${randomTxn()})`;
      expect(await delta()).toEqual({
        PLATFORM_BANKAK: 0,
        BUYER_FUNDS_HELD: 0,
        REFUNDS_PAYABLE: 0,
        REVENUE_COMMISSION: 0,
      });
      expect(await shopBalance(tx, shop.shopId)).toBe(0);
      expect(await heldFor(tx, order.id)).toBe(0);
      expect(await unbalancedJournals(tx)).toEqual([]);
    });
  });

  it('a return after completion reverses the sale and commission, then refunds', async () => {
    await withRollback(sql, async (tx) => {
      const delta = await snapshot(tx);
      const shop = await shopWithListing(tx, { price: 20000 });
      const buyer = await createBuyer(tx);
      const order = await placeOrder(tx, buyer, [
        { listing_id: shop.listingId, qty: 1, seen_price_sdg: 20000 },
      ]);
      const sub = must(order.sub_orders[0]).id;
      const admin = await payByBankak(tx, order);
      await shopFulfils(tx, shop.owner, sub);
      await asUser(tx, buyer);
      await tx`select public.confirm_received(${sub})`;
      await tx`select public.request_return(${sub}, 'القطعة لا تناسب السيارة')`;
      await asUser(tx, admin);
      await tx`select public.admin_decide_return(${sub}, true, 'مقبول')`;

      expect((await journalKinds(tx, order.id)).sort()).toEqual([
        'COMMISSION',
        'COMMISSION_REVERSAL',
        'PAYMENT',
        'REFUND',
        'SALE',
        'SALE_REVERSAL',
      ]);
      expect(await delta()).toEqual({
        PLATFORM_BANKAK: 20000,
        BUYER_FUNDS_HELD: 0,
        REFUNDS_PAYABLE: -20000,
        REVENUE_COMMISSION: 0,
      });
      expect(await shopBalance(tx, shop.shopId)).toBe(0);
      expect(await unbalancedJournals(tx)).toEqual([]);
    });
  });

  it('a cash return before completion: the shop gives the cash back, nothing left owing', async () => {
    await withRollback(sql, async (tx) => {
      const shop = await shopWithListing(tx, { price: 9000 });
      const buyer = await createBuyer(tx);
      const order = await placeOrder(
        tx,
        buyer,
        [{ listing_id: shop.listingId, qty: 1, seen_price_sdg: 9000 }],
        {
          method: 'CASH',
        },
      );
      const sub = must(order.sub_orders[0]).id;
      await shopFulfils(tx, shop.owner, sub);
      await asUser(tx, buyer);
      await tx`select public.request_return(${sub}, 'المقاس خطأ')`;
      const admin = await createAdmin(tx);
      await asUser(tx, admin);
      await tx`select public.admin_decide_return(${sub}, true)`;
      expect((await journalKinds(tx, order.id)).sort()).toEqual([
        'CASH_COLLECTED',
        'CASH_RETURNED',
      ]);
      expect(await shopBalance(tx, shop.shopId)).toBe(0);
      expect(await heldFor(tx, order.id)).toBe(0);
    });
  });

  it('payouts: drafts for shops the platform owes; paying posts PAYOUT and settles the shop', async () => {
    await withRollback(sql, async (tx) => {
      const owed = await shopWithListing(tx, { price: 12000 });
      const owing = await shopWithListing(tx, { price: 45000 });
      const buyer = await createBuyer(tx);

      const a = await placeOrder(tx, buyer, [
        { listing_id: owed.listingId, qty: 1, seen_price_sdg: 12000 },
      ]);
      await payByBankak(tx, a);
      await shopFulfils(tx, owed.owner, must(a.sub_orders[0]).id);
      const b = await placeOrder(
        tx,
        buyer,
        [{ listing_id: owing.listingId, qty: 1, seen_price_sdg: 45000 }],
        {
          method: 'CASH',
        },
      );
      await shopFulfils(tx, owing.owner, must(b.sub_orders[0]).id);
      await asUser(tx, buyer);
      await tx`select public.confirm_received(${must(a.sub_orders[0]).id})`;
      await tx`select public.confirm_received(${must(b.sub_orders[0]).id})`;

      const admin = await createAdmin(tx);
      await asUser(tx, admin);
      await tx`select public.admin_generate_payouts()`;
      const payouts = await tx<
        {
          id: string;
          shop_id: string;
          amount_sdg: string;
          sales_sdg: string;
          deductions_sdg: string;
        }[]
      >`
        select id, shop_id, amount_sdg, sales_sdg, deductions_sdg from public.payouts
        where shop_id in (${owed.shopId}, ${owing.shopId})`;
      expect(payouts).toEqual([
        expect.objectContaining({
          shop_id: owed.shopId,
          amount_sdg: '11400',
          sales_sdg: '12000',
          deductions_sdg: '600',
        }),
      ]);
      const balances = await tx<
        { j: { shop_id: string; balance_sdg: number; cycles_owing: number } }[]
      >`
        select j from public.admin_partner_balances() j`;
      const owingRow = balances.find((r) => r.j.shop_id === owing.shopId)?.j;
      expect(owingRow).toMatchObject({ balance_sdg: -2250, cycles_owing: 1 });

      const payout = must(payouts[0]).id;
      expect(
        (
          await failure(
            tx,
            (sp) => sp`select public.admin_mark_payout_paid(${payout}, ${randomTxn()})`,
          )
        ).message,
      ).toBe('NOT_APPROVED');
      await tx`select public.admin_approve_payouts(${[payout]}::uuid[])`;
      await tx`select public.admin_mark_payout_paid(${payout}, ${randomTxn()})`;
      expect(await shopBalance(tx, owed.shopId)).toBe(0);
      expect(await unbalancedJournals(tx)).toEqual([]);

      await asUser(tx, owed.owner);
      const [st] = await tx<
        { s: { closing_sdg: number; lines: { kind: string; amount_sdg: number }[] } }[]
      >`
        select public.shop_statement(${owed.shopId}) as s`;
      expect(st?.s.closing_sdg).toBe(0);
      expect(st?.s.lines.map((l) => [l.kind, l.amount_sdg]).sort()).toEqual([
        ['COMMISSION', -600],
        ['PAYOUT', -11400],
        ['SALE', 12000],
      ]);
    });
  });

  it('the ledger is append-only and every journal must balance', async () => {
    await withRollback(sql, async (tx) => {
      const shop = await shopWithListing(tx, { price: 1000 });
      const buyer = await createBuyer(tx);
      const order = await placeOrder(tx, buyer, [
        { listing_id: shop.listingId, qty: 1, seen_price_sdg: 1000 },
      ]);
      await payByBankak(tx, order);
      await asSystem(tx);
      expect(
        (await failure(tx, (sp) => sp`update public.ledger_entries set amount_sdg = 1`)).message,
      ).toBe('APPEND_ONLY');
      expect((await failure(tx, (sp) => sp`delete from public.ledger_journals`)).message).toBe(
        'APPEND_ONLY',
      );
      const err = await failure(tx, async (sp) => {
        const [j] =
          await sp`insert into public.ledger_journals (kind) values ('ADJUSTMENT') returning id`;
        await sp`insert into public.ledger_entries (journal_id, account_id, amount_sdg)
                 values (${must(j).id}, public.ledger_account('PLATFORM_BANKAK'), 500)`;
        await sp`set constraints all immediate`;
      });
      expect(err.message).toBe('LEDGER_UNBALANCED');
    });
  });

  it('shops can’t read the ledger directly; statements are theirs alone', async () => {
    await withRollback(sql, async (tx) => {
      const a = await shopWithListing(tx);
      const b = await shopWithListing(tx);
      await asUser(tx, a.owner);
      expect(await tx`select id from public.ledger_entries`).toHaveLength(0);
      expect(
        (await failure(tx, (sp) => sp`select public.shop_statement(${b.shopId})`)).message,
      ).toBe('FORBIDDEN');
    });
  });
});

describe.runIf(!hasDb)('ledger (skipped)', () => {
  it.skip(skipReason, () => undefined);
});
