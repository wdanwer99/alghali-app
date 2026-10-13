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
import { asSystem, asUser, createAdmin, createUser, failure } from '../support/fixtures.ts';
import {
  createBuyer,
  payByBankak,
  placeOrder,
  shopFulfils,
  shopWithListing,
} from '../support/commerce.ts';

const status = async (tx: Tx, subId: string) => {
  await asSystem(tx);
  const [row] = await tx`select status from public.sub_orders where id = ${subId}`;
  return must(row).status as string;
};

async function paidOrder(tx: Tx, opts: { cash?: boolean } = {}) {
  const shop = await shopWithListing(tx, { price: 10000, qty: 3 });
  const buyer = await createBuyer(tx);
  const order = await placeOrder(
    tx,
    buyer,
    [{ listing_id: shop.listingId, qty: 1, seen_price_sdg: 10000 }],
    {
      method: opts.cash ? 'CASH' : 'BANKAK',
    },
  );
  if (!opts.cash) await payByBankak(tx, order);
  return { shop, buyer, order, sub: must(order.sub_orders[0]).id };
}

describe.skipIf(!hasDb)('fulfilment', () => {
  const sql: Sql = connect();
  afterAll(() => sql.end());

  it('the shop accepts, readies and hands over; the buyer is told at each step', async () => {
    await withRollback(sql, async (tx) => {
      const { shop, buyer, sub } = await paidOrder(tx);
      await asUser(tx, shop.owner);
      const [ack] = await tx<
        { j: { shop_ack_at: string | null } }[]
      >`select public.shop_ack_suborder(${sub}) as j`;
      expect(ack?.j.shop_ack_at).toBeTruthy();
      await shopFulfils(tx, shop.owner, sub);
      expect(await status(tx, sub)).toBe('PICKED_UP');
      const notes = await tx`select code from public.notifications where user_id = ${buyer}`;
      expect(notes.map((n) => n.code)).toEqual(
        expect.arrayContaining(['ORDER_READY', 'ORDER_HANDED_OVER']),
      );
    });
  });

  it('only the shop’s own people act on its orders', async () => {
    await withRollback(sql, async (tx) => {
      const { buyer, sub } = await paidOrder(tx);
      const otherShop = await shopWithListing(tx);
      for (const who of [buyer, otherShop.owner]) {
        await asUser(tx, who);
        expect((await failure(tx, (sp) => sp`select public.shop_mark_ready(${sub})`)).message).toBe(
          'FORBIDDEN',
        );
      }
    });
  });

  it('a shop can’t skip steps', async () => {
    await withRollback(sql, async (tx) => {
      const { shop, sub } = await paidOrder(tx);
      await asUser(tx, shop.owner);
      expect(await failure(tx, (sp) => sp`select public.shop_hand_over(${sub})`)).toEqual({
        code: 'PT409',
        message: 'INVALID_TRANSITION',
      });
      expect(
        (await failure(tx, (sp) => sp`select public.shop_reject_suborder(${sub}, ' ')`)).message,
      ).toBe('REASON_REQUIRED');
    });
  });

  it('delivery: out for delivery, then delivered; cash is collected on delivery', async () => {
    await withRollback(sql, async (tx) => {
      const shop = await shopWithListing(tx, { price: 10000, lat: 15.5, lng: 32.5 });
      const buyer = await createBuyer(tx);
      await asUser(tx, buyer);
      const [addr] =
        await tx`insert into public.addresses (label, lat, lng) values ('البيت', 15.51, 32.5) returning id`;
      const order = await placeOrder(
        tx,
        buyer,
        [{ listing_id: shop.listingId, qty: 1, seen_price_sdg: 10000 }],
        {
          method: 'CASH',
          fulfilment: { [shop.shopId]: 'DELIVERY' },
          addressId: must(addr).id,
        },
      );
      const sub = must(order.sub_orders[0]).id;
      await shopFulfils(tx, shop.owner, sub);
      expect(await status(tx, sub)).toBe('OUT_FOR_DELIVERY');
      const [p1] = await tx`select status from public.payments where sub_order_id = ${sub}`;
      expect(p1?.status).toBe('DUE');
      await asUser(tx, shop.owner);
      const [view] = await tx<
        { j: { address: { label: string } } }[]
      >`select public.shop_mark_delivered(${sub}) as j`;
      expect(view?.j.address.label).toBe('البيت');
      const [p2] =
        await tx`select status, amount_sdg from public.payments where sub_order_id = ${sub}`;
      expect(p2).toEqual({ status: 'COLLECTED', amount_sdg: '12000' }); // 10,000 + 2,000 delivery
    });
  });

  it('a delivery the admin cancels puts the part back in stock', async () => {
    await withRollback(sql, async (tx) => {
      const shop = await shopWithListing(tx, { price: 10000, qty: 3, lat: 15.5, lng: 32.5 });
      const buyer = await createBuyer(tx);
      await asUser(tx, buyer);
      const [addr] =
        await tx`insert into public.addresses (label, lat, lng) values ('x', 15.51, 32.5) returning id`;
      const order = await placeOrder(
        tx,
        buyer,
        [{ listing_id: shop.listingId, qty: 1, seen_price_sdg: 10000 }],
        {
          fulfilment: { [shop.shopId]: 'DELIVERY' },
          addressId: must(addr).id,
        },
      );
      const admin = await payByBankak(tx, order);
      const sub = must(order.sub_orders[0]).id;
      await shopFulfils(tx, shop.owner, sub);
      await asSystem(tx);
      expect(
        (await tx`select stock_qty from public.listings where id = ${shop.listingId}`)[0]
          ?.stock_qty,
      ).toBe(2);
      await asUser(tx, admin);
      expect(
        (await failure(tx, (sp) => sp`select public.admin_cancel_suborder(${sub}, '')`)).message,
      ).toBe('REASON_REQUIRED');
      await tx`select public.admin_cancel_suborder(${sub}, 'لم يُعثر على العنوان')`;
      await asSystem(tx);
      expect(
        (await tx`select stock_qty from public.listings where id = ${shop.listingId}`)[0]
          ?.stock_qty,
      ).toBe(3);
      expect(await tx`select id from public.refunds where sub_order_id = ${sub}`).toHaveLength(1);
    });
  });

  describe('returns', () => {
    it('within the return window only; an admin decides', async () => {
      await withRollback(sql, async (tx) => {
        const { shop, buyer, sub } = await paidOrder(tx);
        await asUser(tx, buyer);
        expect(
          (await failure(tx, (sp) => sp`select public.request_return(${sub}, 'لا تناسب')`)).message,
        ).toBe('INVALID_TRANSITION');
        await shopFulfils(tx, shop.owner, sub);
        await asSystem(tx);
        await tx`update public.sub_orders set handed_over_at = now() - interval '4 days' where id = ${sub}`;
        await asUser(tx, buyer);
        expect(
          (await failure(tx, (sp) => sp`select public.request_return(${sub}, 'لا تناسب')`)).message,
        ).toBe('RETURN_WINDOW_CLOSED');
        await asSystem(tx);
        await tx`update public.sub_orders set handed_over_at = now() - interval '1 day' where id = ${sub}`;
        await asUser(tx, buyer);
        expect(
          (await failure(tx, (sp) => sp`select public.request_return(${sub}, 'x')`)).message,
        ).toBe('REASON_REQUIRED');
        await tx`select public.request_return(${sub}, 'لا تناسب سيارتي')`;
        expect(await status(tx, sub)).toBe('RETURN_REQUESTED');
        const shopNotes =
          await tx`select code from public.notifications where user_id = ${shop.owner}`;
        expect(shopNotes.map((n) => n.code)).toContain('RETURN_REQUESTED');

        await asUser(tx, buyer);
        expect(
          (await failure(tx, (sp) => sp`select public.admin_decide_return(${sub}, true)`)).message,
        ).toBe('FORBIDDEN');
        const admin = await createAdmin(tx);
        await asUser(tx, admin);
        expect(
          (await failure(tx, (sp) => sp`select public.admin_decide_return(${sub}, false)`)).message,
        ).toBe('REASON_REQUIRED');
        await tx`select public.admin_decide_return(${sub}, false, 'القطعة استُخدمت')`;
        expect(await status(tx, sub)).toBe('COMPLETED');
        const [r] =
          await tx`select status, decision_note from public.returns where sub_order_id = ${sub}`;
        expect(r).toEqual({ status: 'DECLINED', decision_note: 'القطعة استُخدمت' });
      });
    });
  });

  describe('timed jobs', () => {
    it('handed-over orders complete after auto_complete_days', async () => {
      await withRollback(sql, async (tx) => {
        const { shop, sub } = await paidOrder(tx);
        const recent = await paidOrder(tx);
        await shopFulfils(tx, shop.owner, sub);
        await shopFulfils(tx, recent.shop.owner, recent.sub);
        await asSystem(tx);
        await tx`update public.sub_orders set handed_over_at = now() - interval '4 days' where id = ${sub}`;
        await tx`select public.auto_complete_suborders()`;
        expect(await status(tx, sub)).toBe('COMPLETED');
        expect(await status(tx, recent.sub)).toBe('PICKED_UP');
        const [e] = await tx`select actor_kind, reason from public.suborder_events
                             where sub_order_id = ${sub} and to_status = 'COMPLETED'`;
        expect(e).toEqual({ actor_kind: 'SYSTEM', reason: 'AUTO_COMPLETED' });
      });
    });

    it('the timed jobs are scheduled', async () => {
      const jobs = await sql<{ jobname: string }[]>`select jobname from cron.job order by jobname`;
      expect(jobs.map((j) => j.jobname)).toEqual(
        expect.arrayContaining([
          'auto-complete-suborders',
          'expire-part-requests',
          'expire-unpaid-orders',
        ]),
      );
    });

    it('requests and offers expire', async () => {
      await withRollback(sql, async (tx) => {
        const buyer = await createUser(tx);
        await asUser(tx, buyer);
        const [r] = await tx<
          { r: { id: string } }[]
        >`select public.create_part_request('طلمبة ماء كورولا 2015') as r`;
        await asSystem(tx);
        await tx`update public.part_requests set expires_at = now() - interval '1 minute' where id = ${must(r).r.id}`;
        await tx`select public.expire_part_requests()`;
        const [row] = await tx`select status from public.part_requests where id = ${must(r).r.id}`;
        expect(row?.status).toBe('EXPIRED');
      });
    });
  });

  describe('chat', () => {
    it('buyer and shop talk; nobody else reads or writes', async () => {
      await withRollback(sql, async (tx) => {
        const { shop, buyer, sub } = await paidOrder(tx, { cash: true });
        const stranger = await createUser(tx);
        await asUser(tx, buyer);
        const [c] = await tx<
          { c: { id: string } }[]
        >`select public.start_conversation(${shop.shopId}, ${sub}) as c`;
        const conv = must(c).c.id;
        await tx`insert into public.messages (conversation_id, body) values (${conv}, 'متى تكون جاهزة؟')`;

        await asUser(tx, shop.owner);
        const inbox = await tx<{ j: { unread: boolean; last: { body: string } } }[]>`
          select j from public.shop_conversations(${shop.shopId}) j`;
        expect(inbox[0]?.j).toMatchObject({ unread: true, last: { body: 'متى تكون جاهزة؟' } });
        await tx`insert into public.messages (conversation_id, body) values (${conv}, 'بعد ساعة إن شاء الله')`;
        await tx`select public.mark_conversation_read(${conv})`;
        const again = await tx<
          { j: { unread: boolean } }[]
        >`select j from public.shop_conversations(${shop.shopId}) j`;
        expect(again[0]?.j.unread).toBe(false);

        await asUser(tx, buyer);
        expect(
          await tx`select body from public.messages where conversation_id = ${conv}`,
        ).toHaveLength(2);
        const [n] = await tx`select count(*)::int as n from public.notifications
                             where user_id = ${buyer} and code = 'NEW_MESSAGE'`;
        expect(n?.n).toBe(1);

        await asUser(tx, stranger);
        expect(
          await tx`select id from public.messages where conversation_id = ${conv}`,
        ).toHaveLength(0);
        const err = await failure(
          tx,
          (sp) => sp`insert into public.messages (conversation_id, body) values (${conv}, 'hi')`,
        );
        expect(err.message).toMatch(/row-level security/);
        await asUser(tx, buyer);
        const spoof = await failure(
          tx,
          (sp) =>
            sp`insert into public.messages (conversation_id, sender_id, body) values (${conv}, ${shop.owner}, 'x')`,
        );
        expect(spoof.message).toMatch(/row-level security/);
      });
    });
  });
});

describe.runIf(!hasDb)('fulfilment (skipped)', () => {
  it.skip(skipReason, () => undefined);
});
