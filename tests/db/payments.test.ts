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
  placeOrder,
  randomTxn,
  shopWithListing,
} from '../support/commerce.ts';

async function bankakOrder(tx: Tx, price = 23000) {
  const shop = await shopWithListing(tx, { price, qty: 3 });
  const buyer = await createBuyer(tx);
  const order = await placeOrder(tx, buyer, [
    { listing_id: shop.listingId, qty: 1, seen_price_sdg: price },
  ]);
  const payment = must(order.payments[0]);
  return { shop, buyer, order, payment };
}

const statuses = async (tx: Tx, orderId: string) => {
  await asSystem(tx);
  const subs = await tx`select status from public.sub_orders where order_id = ${orderId}`;
  const pays = await tx`select status from public.payments where order_id = ${orderId}`;
  return { subs: subs.map((s) => s.status), pays: pays.map((p) => p.status) };
};

describe.skipIf(!hasDb)('Bankak payments', () => {
  const sql: Sql = connect();
  afterAll(() => sql.end());

  it('a receipt moves the order to "being checked"; confirming posts the money and tells the shop', async () => {
    await withRollback(sql, async (tx) => {
      const { shop, buyer, order, payment } = await bankakOrder(tx);
      await asUser(tx, buyer);
      await tx`select public.submit_bankak_receipt(${order.id}, ' ٢٠٠٩٩٢٠١٤ ')`;
      expect(await statuses(tx, order.id)).toEqual({
        subs: ['PAYMENT_REVIEW'],
        pays: ['RECEIPT_SUBMITTED'],
      });
      const [p] = await tx`select bankak_txn_no from public.payments where id = ${payment.id}`;
      expect(p?.bankak_txn_no).toBe('200992014');

      const admin = await createAdmin(tx);
      await asUser(tx, admin);
      const queue = await tx<
        { j: { ref: string; txn_seen_before: boolean; buyer: { phone: string } } }[]
      >`
        select j from public.admin_payment_queue() j`;
      expect(queue.map((q) => q.j.ref)).toContain(order.ref);
      await tx`select public.admin_confirm_payment(${payment.id}, null, true)`;
      expect(await statuses(tx, order.id)).toEqual({ subs: ['CONFIRMED'], pays: ['CONFIRMED'] });
      expect(await balance(tx, 'PLATFORM_BANKAK')).toBeGreaterThanOrEqual(23000);

      await asSystem(tx);
      const shopNotes =
        await tx`select code from public.notifications where user_id = ${shop.owner}`;
      expect(shopNotes.map((n) => n.code)).toEqual(['NEW_ORDER']);
      const buyerNotes =
        await tx`select code from public.notifications where user_id = ${buyer} order by created_at, code`;
      expect(buyerNotes.map((n) => n.code).sort()).toEqual(['ORDER_PLACED', 'PAYMENT_CONFIRMED']);
      const [audit] =
        await tx`select actor_id from public.audit_log where entity = 'payment' and entity_id = ${payment.id}`;
      expect(audit?.actor_id).toBe(admin);
    });
  });

  it('a Bankak transaction number can pay for one payment only', async () => {
    await withRollback(sql, async (tx) => {
      const first = await bankakOrder(tx);
      const second = await bankakOrder(tx);
      const txn = randomTxn();
      await asUser(tx, first.buyer);
      await tx`select public.submit_bankak_receipt(${first.order.id}, ${txn})`;
      await asUser(tx, second.buyer);
      expect(
        await failure(
          tx,
          (sp) => sp`select public.submit_bankak_receipt(${second.order.id}, ${txn})`,
        ),
      ).toEqual({
        code: 'PT409',
        message: 'DUPLICATE_TXN',
      });
      expect((await statuses(tx, second.order.id)).pays).toEqual(['AWAITING_TRANSFER']);
    });
  });

  it('confirming needs the transaction number, typed by the admin when only a screenshot came', async () => {
    await withRollback(sql, async (tx) => {
      const first = await bankakOrder(tx);
      const second = await bankakOrder(tx);
      const used = randomTxn();
      // First order paid and confirmed with `used`.
      await asUser(tx, first.buyer);
      await tx`select public.submit_bankak_receipt(${first.order.id}, ${used})`;
      const admin = await createAdmin(tx);
      await asUser(tx, admin);
      await tx`select public.admin_confirm_payment(${first.payment.id})`;

      // Second buyer sends only a screenshot.
      await asSystem(tx);
      await tx`insert into storage.objects (bucket_id, name) values ('receipts', ${`${second.buyer}/r.jpg`})`;
      await asUser(tx, second.buyer);
      expect(
        (
          await failure(
            tx,
            (sp) =>
              sp`select public.submit_bankak_receipt(${second.order.id}, null, 'someone/else.jpg')`,
          )
        ).message,
      ).toBe('INVALID_RECEIPT_KEY');
      expect(
        (await failure(tx, (sp) => sp`select public.submit_bankak_receipt(${second.order.id})`))
          .message,
      ).toBe('RECEIPT_REQUIRED');
      await tx`select public.submit_bankak_receipt(${second.order.id}, null, ${`${second.buyer}/r.jpg`})`;

      await asUser(tx, admin);
      expect(
        (await failure(tx, (sp) => sp`select public.admin_confirm_payment(${second.payment.id})`))
          .message,
      ).toBe('TXN_REQUIRED');
      expect(
        (
          await failure(
            tx,
            (sp) => sp`select public.admin_confirm_payment(${second.payment.id}, ${used})`,
          )
        ).message,
      ).toBe('DUPLICATE_TXN');
      await tx`select public.admin_confirm_payment(${second.payment.id}, ${randomTxn()})`;
      expect((await statuses(tx, second.order.id)).pays).toEqual(['CONFIRMED']);
    });
  });

  it('a rejected receipt sends the order back; the buyer may try again', async () => {
    await withRollback(sql, async (tx) => {
      const { buyer, order, payment } = await bankakOrder(tx);
      await asUser(tx, buyer);
      await tx`select public.submit_bankak_receipt(${order.id}, ${randomTxn()})`;
      const admin = await createAdmin(tx);
      await asUser(tx, admin);
      expect(
        (await failure(tx, (sp) => sp`select public.admin_reject_payment(${payment.id}, 'BAD')`))
          .message,
      ).toBe('INVALID_REASON');
      await tx`select public.admin_reject_payment(${payment.id}, 'NOT_ON_STATEMENT')`;
      expect(await statuses(tx, order.id)).toEqual({
        subs: ['PENDING_PAYMENT'],
        pays: ['REJECTED'],
      });
      const [n] = await tx`select payload ->> 'reason' as r from public.notifications
                           where user_id = ${buyer} and code = 'PAYMENT_REJECTED'`;
      expect(n?.r).toBe('NOT_ON_STATEMENT');

      await asUser(tx, buyer);
      await tx`select public.submit_bankak_receipt(${order.id}, ${randomTxn()})`;
      expect(await statuses(tx, order.id)).toEqual({
        subs: ['PAYMENT_REVIEW'],
        pays: ['RECEIPT_SUBMITTED'],
      });
    });
  });

  it('only admins confirm or reject', async () => {
    await withRollback(sql, async (tx) => {
      const { shop, buyer, order, payment } = await bankakOrder(tx);
      await asUser(tx, buyer);
      await tx`select public.submit_bankak_receipt(${order.id}, ${randomTxn()})`;
      for (const who of [buyer, shop.owner]) {
        await asUser(tx, who);
        expect(
          (await failure(tx, (sp) => sp`select public.admin_confirm_payment(${payment.id})`))
            .message,
        ).toBe('FORBIDDEN');
        expect(
          (await failure(tx, (sp) => sp`select * from public.admin_payment_queue()`)).message,
        ).toBe('FORBIDDEN');
      }
    });
  });

  it('unpaid orders expire after the payment window: cancelled, stock released', async () => {
    await withRollback(sql, async (tx) => {
      const { shop, buyer, order } = await bankakOrder(tx);
      const reviewed = await bankakOrder(tx);
      await asUser(tx, reviewed.buyer);
      await tx`select public.submit_bankak_receipt(${reviewed.order.id}, ${randomTxn()})`;

      await asSystem(tx);
      await tx`update public.orders set pay_by = now() - interval '1 minute'
               where id in (${order.id}, ${reviewed.order.id})`;
      await tx`select public.expire_unpaid_orders()`;
      expect(await statuses(tx, order.id)).toEqual({ subs: ['CANCELLED'], pays: ['EXPIRED'] });
      // A receipt under review is left for the admin.
      expect(await statuses(tx, reviewed.order.id)).toEqual({
        subs: ['PAYMENT_REVIEW'],
        pays: ['RECEIPT_SUBMITTED'],
      });
      const [l] = await tx`select reserved_qty from public.listings where id = ${shop.listingId}`;
      expect(l?.reserved_qty).toBe(0);

      await asUser(tx, buyer);
      expect(
        (
          await failure(
            tx,
            (sp) => sp`select public.submit_bankak_receipt(${order.id}, '123456789')`,
          )
        ).message,
      ).toBe('NOT_AWAITING_PAYMENT');
    });
  });

  it('a late receipt is refused', async () => {
    await withRollback(sql, async (tx) => {
      const { buyer, order } = await bankakOrder(tx);
      await asSystem(tx);
      await tx`update public.orders set pay_by = now() - interval '1 minute' where id = ${order.id}`;
      await asUser(tx, buyer);
      expect(
        await failure(
          tx,
          (sp) => sp`select public.submit_bankak_receipt(${order.id}, '123456789')`,
        ),
      ).toEqual({
        code: 'PT409',
        message: 'PAYMENT_EXPIRED',
      });
    });
  });

  it('refund accounts and paid refunds are recorded once', async () => {
    await withRollback(sql, async (tx) => {
      const { shop, buyer, order, payment } = await bankakOrder(tx);
      await asUser(tx, buyer);
      await tx`select public.set_refund_account('٠٩١٢-٣٤٥-٦٧٨')`;
      expect((await failure(tx, (sp) => sp`select public.set_refund_account('abc')`)).message).toBe(
        'INVALID_ACCOUNT',
      );
      await tx`select public.submit_bankak_receipt(${order.id}, ${randomTxn()})`;
      const admin = await createAdmin(tx);
      await asUser(tx, admin);
      await tx`select public.admin_confirm_payment(${payment.id})`;
      await asUser(tx, shop.owner);
      await tx`select public.shop_reject_suborder(${must(order.sub_orders[0]).id}, 'نفدت الكمية')`;

      await asSystem(tx);
      const [refund] = await tx<{ id: string; amount_sdg: string; status: string }[]>`
        select id, amount_sdg, status from public.refunds where order_id = ${order.id}`;
      expect(refund).toMatchObject({ amount_sdg: '23000', status: 'PENDING' });
      const [acc] = await tx`select refund_account from public.profiles where id = ${buyer}`;
      expect(acc?.refund_account).toBe('0912345678');

      await asUser(tx, admin);
      const txn = randomTxn();
      await tx`select public.admin_mark_refund_paid(${must(refund).id}, ${txn})`;
      expect(
        (
          await failure(
            tx,
            (sp) => sp`select public.admin_mark_refund_paid(${must(refund).id}, ${txn})`,
          )
        ).message,
      ).toBe('ALREADY_PAID');
    });
  });
});

describe.runIf(!hasDb)('Bankak payments (skipped)', () => {
  it.skip(skipReason, () => undefined);
});
