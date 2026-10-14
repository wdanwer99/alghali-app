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
import { asAnon, asSystem, asUser, createAdmin, createUser, failure } from '../support/fixtures.ts';
import {
  accept,
  createTechnician,
  elsewhere,
  hold,
  jobCode,
  khartoumAt,
} from '../support/bookings.ts';
import { createBuyer, placeOrder, shopFulfils, shopWithListing } from '../support/commerce.ts';

/** A cash pickup the buyer has collected. */
async function collected(tx: Tx) {
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
  await shopFulfils(tx, shop.owner, sub);
  return { shop, buyer, sub };
}

/** A finished bay fitting, paid in cash. */
async function fitted(tx: Tx) {
  const tech = await createTechnician(tx);
  const buyer = await createBuyer(tx);
  const b = await hold(tx, buyer, {
    technicianId: tech.techId,
    start: khartoumAt(10),
    items: [await elsewhere(tx)],
  });
  await asUser(tx, buyer);
  await tx`select public.checkout(p_items => '[]', p_method => 'CASH', p_booking_id => ${b.id})`;
  await accept(tx, tech.userId, b.id);
  await asSystem(tx);
  await tx`update public.bookings set start_at = now() + interval '30 minutes', end_at = now() + interval '60 minutes',
             block_from = now() + interval '30 minutes', block_to = now() + interval '60 minutes' where id = ${b.id}`;
  const code = await jobCode(tx, b.id);
  await asUser(tx, tech.userId);
  await tx`select public.tech_check_in(${b.id})`;
  await tx`select public.tech_complete(${b.id}, ${code})`;
  return { tech, buyer, bookingId: b.id };
}

// Each case builds technicians, shops and orders over the internet: give it time.
describe.skipIf(!hasDb)('reviews and disputes', { timeout: 90_000 }, () => {
  const sql: Sql = connect();
  afterAll(() => sql.end());

  it('the buyer rates the shop once the order is in hand; ratings roll up; anyone can read them', async () => {
    await withRollback(sql, async (tx) => {
      const { shop, buyer, sub } = await collected(tx);
      await asUser(tx, buyer);
      await tx`select public.create_review(4, p_sub_order_id => ${sub}, p_comment => 'جيد')`;
      await tx`select public.create_review(5, p_sub_order_id => ${sub}, p_comment => 'ممتاز')`;
      await asSystem(tx);
      const [s] = await tx<{ rating_avg: string; rating_count: number }[]>`
        select rating_avg, rating_count from public.shops where id = ${shop.shopId}`;
      expect(must(s)).toEqual({ rating_avg: '5.00', rating_count: 1 });

      await asAnon(tx);
      const rows = await tx<{ r: { rating: number; comment: string; author: string } }[]>`
        select r from public.reviews_for(${shop.shopId}) r`;
      expect(rows.map((x) => [x.r.rating, x.r.comment, x.r.author])).toEqual([
        [5, 'ممتاز', 'أحمد'],
      ]);
      expect((await failure(tx, (sp) => sp`select * from public.reviews`)).code).toBe('42501');

      const admin = await createAdmin(tx);
      await asUser(tx, admin);
      const [rev] = await tx<
        { id: string }[]
      >`select id from public.reviews where sub_order_id = ${sub}`;
      await tx`select public.admin_hide_review(${must(rev).id}, true, 'إساءة')`;
      await asSystem(tx);
      const [h] = await tx<
        { rating_count: number }[]
      >`select rating_count from public.shops where id = ${shop.shopId}`;
      expect(must(h).rating_count).toBe(0);
    });
  });

  it('nothing to rate before the order is received, or someone else’s order', async () => {
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
      await asUser(tx, buyer);
      expect(
        await failure(tx, (sp) => sp`select public.create_review(5, p_sub_order_id => ${sub})`),
      ).toEqual({
        code: 'PT409',
        message: 'NOT_REVIEWABLE',
      });
      await asUser(tx, await createUser(tx));
      expect(
        (await failure(tx, (sp) => sp`select public.create_review(5, p_sub_order_id => ${sub})`))
          .message,
      ).toBe('NOT_REVIEWABLE');
    });
  });

  it('the buyer rates the technician after the fitting; the technician hears about it', async () => {
    await withRollback(sql, async (tx) => {
      const { tech, buyer, bookingId } = await fitted(tx);
      await asUser(tx, buyer);
      await tx`select public.create_review(5, p_booking_id => ${bookingId})`;
      await asAnon(tx);
      const [p] = await tx<
        { p: { rating_avg: number; rating_count: number; reviews: unknown[] } }[]
      >`
        select public.technician_profile(${tech.techId}) as p`;
      expect(must(p).p.rating_count).toBe(1);
      expect(must(p).p.reviews).toHaveLength(1);
      await asSystem(tx);
      const codes = await tx<
        { code: string }[]
      >`select code from public.notifications where user_id = ${tech.userId}`;
      expect(codes.map((c) => c.code)).toContain('NEW_REVIEW');
    });
  });

  it('a dispute is between the parties and the admins; replies notify the others; an admin closes it', async () => {
    await withRollback(sql, async (tx) => {
      const { shop, buyer, sub } = await collected(tx);
      const admin = await createAdmin(tx);
      await asUser(tx, buyer);
      const [d] = await tx<{ d: { id: string; status: string; opener_role: string } }[]>`
        select public.open_dispute('WRONG_PART', 'القطعة المستلمة غير المطلوبة', p_sub_order_id => ${sub}) as d`;
      const dispute = must(d).d;
      expect(dispute).toMatchObject({ status: 'OPEN', opener_role: 'BUYER' });
      expect(
        (
          await failure(
            tx,
            (sp) =>
              sp`select public.open_dispute('OTHER', 'مرة أخرى للتجربة', p_sub_order_id => ${sub})`,
          )
        ).message,
      ).toBe('DISPUTE_EXISTS');

      await asUser(tx, shop.owner);
      await tx`select public.dispute_reply(${dispute.id}, 'سنستبدلها غدًا')`;
      const outsider = await createUser(tx);
      await asUser(tx, outsider);
      expect(await tx`select * from public.disputes where id = ${dispute.id}`).toHaveLength(0);
      expect(
        (await failure(tx, (sp) => sp`select public.dispute_reply(${dispute.id}, 'تدخل')`)).message,
      ).toBe('NOT_FOUND');

      await asUser(tx, admin);
      expect(
        (
          await failure(
            tx,
            (sp) => sp`select public.admin_update_dispute(${dispute.id}, 'RESOLVED')`,
          )
        ).message,
      ).toBe('REASON_REQUIRED');
      await tx`select public.admin_update_dispute(${dispute.id}, 'RESOLVED', 'استبدل المحل القطعة')`;
      await asUser(tx, buyer);
      expect(
        (await failure(tx, (sp) => sp`select public.dispute_reply(${dispute.id}, 'شكرًا')`))
          .message,
      ).toBe('DISPUTE_CLOSED');
      await asSystem(tx);
      const notes = await tx<{ user_id: string; code: string; app: string }[]>`
        select user_id, code, app from public.notifications
        where code in ('DISPUTE_OPENED', 'DISPUTE_REPLY', 'DISPUTE_RESOLVED') order by created_at`;
      expect(notes).toContainEqual({ user_id: admin, code: 'DISPUTE_OPENED', app: 'admin' });
      expect(notes).toContainEqual({ user_id: buyer, code: 'DISPUTE_REPLY', app: 'buyer' });
      expect(notes).toContainEqual({ user_id: buyer, code: 'DISPUTE_RESOLVED', app: 'buyer' });
    });
  });

  it('a technician can open a dispute about their booking', async () => {
    await withRollback(sql, async (tx) => {
      const { tech, bookingId } = await fitted(tx);
      await asUser(tx, tech.userId);
      const [d] = await tx<{ d: { opener_role: string } }[]>`
        select public.open_dispute('PAYMENT', 'الزبون لم يدفع المبلغ كاملًا', p_booking_id => ${bookingId}) as d`;
      expect(must(d).d.opener_role).toBe('TECH');
      const [mine] = await tx<{ n: number }[]>`select count(*)::int as n from public.my_disputes()`;
      expect(must(mine).n).toBe(1);
    });
  });
});

describe.runIf(!hasDb)('reviews and disputes (skipped)', () => {
  it.skip(skipReason, () => undefined);
});
