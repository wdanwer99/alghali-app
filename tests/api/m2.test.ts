import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { must } from '../support/must.ts';
import { anonClient, apiSkipReason, Fixtures, hasApi, type TestUser } from '../support/api.ts';

/** A 1×1 JPEG, enough for the receipts bucket's MIME check. */
const JPEG = Uint8Array.from(
  atob(
    '/9j/4AAQSkZJRgABAQEASABIAAD/2wBDAAMCAgICAgMCAgIDAwMDBAYEBAQEBAgGBgUGCQgKCgkICQkKDA8MCgsOCwkJDRENDg8QEBEQCgwSExIQEw8QEBD/yQALCAABAAEBAREA/8wABgAQEAX/2gAIAQEAAD8A0s8g/9k=',
  ),
  (c) => c.charCodeAt(0),
);

type Order = {
  id: string;
  ref: string;
  total_sdg: number;
  payments: { id: string; status: string }[];
  sub_orders: { id: string; status: string }[];
};

describe.skipIf(!hasApi)('M2 over HTTP: the acceptance flow without a fitting', () => {
  let f: Fixtures;
  let buyer: TestUser;
  let shop: { owner: TestUser; shopId: string };
  let admin: TestUser;
  let listingId: string;

  beforeAll(async () => {
    f = new Fixtures();
    shop = await f.shop();
    buyer = await f.user({ phone: '0912345678', display_name: 'أحمد' });
    admin = await f.user();
    await f.sql`insert into public.user_roles (user_id, role) values (${admin.id}, 'ADMIN')`;
    const cat = await f.sql<
      { id: string }[]
    >`select id from public.part_categories where slug = 'lighting'`;
    const { data, error } = await shop.owner.client.rpc('shop_upsert_listing', {
      p_shop_id: shop.shopId,
      p_condition: 'NEW_OEM',
      p_stock_qty: 4,
      p_price_sdg: 12000,
      p_new_part: { name_ar: 'لمبة هالوجين H4', category_id: must(cat[0]).id },
    });
    if (error) throw error;
    listingId = (data as { id: string }).id;
  });
  afterAll(() => f.cleanup());

  it('checkout → receipt → admin confirms → shop fulfils → buyer confirms; the money adds up', async () => {
    // 1. Checkout with the price the buyer saw.
    const placed = await buyer.client.rpc('checkout', {
      p_items: [{ listing_id: listingId, qty: 1, seen_price_sdg: 12000 }],
      p_method: 'BANKAK',
      p_idem: crypto.randomUUID(),
    });
    expect(placed.error).toBeNull();
    const order = placed.data as Order;
    expect(order.total_sdg).toBe(12000);

    // 2. The receipt screenshot goes to the buyer's own folder; then the transfer number.
    const key = `${buyer.id}/${crypto.randomUUID()}.jpg`;
    f.trackFile('receipts', key);
    const up = await buyer.client.storage
      .from('receipts')
      .upload(key, JPEG, { contentType: 'image/jpeg' });
    expect(up.error).toBeNull();
    const txn = String(Date.now()).slice(-10);
    const submitted = await buyer.client.rpc('submit_bankak_receipt', {
      p_order_id: order.id,
      p_txn_no: txn,
      p_receipt_key: key,
    });
    expect(submitted.error).toBeNull();
    expect((submitted.data as Order).sub_orders[0]?.status).toBe('PAYMENT_REVIEW');

    // Other people can't see the receipt; the admin can.
    const stranger = await f.user();
    expect((await stranger.client.storage.from('receipts').download(key)).error).not.toBeNull();
    expect((await admin.client.storage.from('receipts').download(key)).error).toBeNull();

    // 3. The admin's queue shows it; confirming moves the order to the shop.
    const queue = await admin.client.rpc('admin_payment_queue');
    expect(queue.error).toBeNull();
    const row = (queue.data as { ref: string; payment_id: string; receipt_key: string }[]).find(
      (q) => q.ref === order.ref,
    );
    expect(row?.receipt_key).toBe(key);
    const confirmed = await admin.client.rpc('admin_confirm_payment', {
      p_payment_id: must(row).payment_id,
    });
    expect(confirmed.error).toBeNull();

    // 4. The shop sees it now, readies it and hands it over.
    const todo = await shop.owner.client.rpc('shop_orders', { p_shop_id: shop.shopId });
    const sub = must((todo.data as { id: string; ref: string }[]).find((s) => s.ref === order.ref));
    for (const fn of ['shop_ack_suborder', 'shop_mark_ready', 'shop_hand_over']) {
      const r = await shop.owner.client.rpc(fn, { p_sub_order_id: sub.id });
      expect(r.error, fn).toBeNull();
    }

    // 5. The buyer confirms receipt: the sale completes.
    const done = await buyer.client.rpc('confirm_received', { p_sub_order_id: sub.id });
    expect((done.data as Order).sub_orders[0]?.status).toBe('COMPLETED');

    // The ledger: shop owed 11,400; 600 commission; nothing held for this order.
    const [held] = await f.sql<{ b: string }[]>`
      select coalesce(sum(e.amount_sdg), 0) as b from public.ledger_entries e
      join public.ledger_journals j on j.id = e.journal_id join public.ledger_accounts a on a.id = e.account_id
      where a.code = 'BUYER_FUNDS_HELD' and j.order_id = ${order.id}`;
    expect(Number(must(held).b)).toBe(0);
    const statement = await shop.owner.client.rpc('shop_statement', { p_shop_id: shop.shopId });
    expect((statement.data as { closing_sdg: number }).closing_sdg).toBe(11400);

    // The buyer's inbox tells the story.
    const { data: notes } = await buyer.client.from('notifications').select('code');
    expect(notes?.map((n) => n.code)).toEqual(
      expect.arrayContaining([
        'ORDER_PLACED',
        'PAYMENT_CONFIRMED',
        'ORDER_READY',
        'ORDER_HANDED_OVER',
      ]),
    );
  });

  it('the same transfer number can’t pay for a second order', async () => {
    const a = await buyer.client.rpc('checkout', {
      p_items: [{ listing_id: listingId, qty: 1, seen_price_sdg: 12000 }],
      p_method: 'BANKAK',
    });
    const b = await buyer.client.rpc('checkout', {
      p_items: [{ listing_id: listingId, qty: 1, seen_price_sdg: 12000 }],
      p_method: 'BANKAK',
    });
    const txn = `9${String(Date.now()).slice(-9)}`;
    const first = await buyer.client.rpc('submit_bankak_receipt', {
      p_order_id: (a.data as Order).id,
      p_txn_no: txn,
    });
    expect(first.error).toBeNull();
    const second = await buyer.client.rpc('submit_bankak_receipt', {
      p_order_id: (b.data as Order).id,
      p_txn_no: txn,
    });
    expect(second.error).toMatchObject({ code: 'PT409', message: 'DUPLICATE_TXN' });
  });

  it('a stale price comes back as CART_CHANGED with the new price', async () => {
    const r = await buyer.client.rpc('checkout', {
      p_items: [{ listing_id: listingId, qty: 1, seen_price_sdg: 11000 }],
      p_method: 'CASH',
    });
    expect(r.error).toMatchObject({ code: 'PT409', message: 'CART_CHANGED' });
    const lines = JSON.parse(must(r.error).details) as { problem: string; price_sdg: number }[];
    expect(lines[0]).toMatchObject({ problem: 'PRICE_CHANGED', price_sdg: 12000 });
  });

  it('guests check a cart, but must sign in to buy', async () => {
    const anon = anonClient();
    const check = await anon.rpc('cart_validate', {
      p_items: [{ listing_id: listingId, qty: 1, seen_price_sdg: 12000 }],
    });
    expect(check.error).toBeNull();
    const buy = await anon.rpc('checkout', {
      p_items: [{ listing_id: listingId, qty: 1, seen_price_sdg: 12000 }],
      p_method: 'CASH',
    });
    expect(buy.error).not.toBeNull();
  });

  it('chat messages arrive live for the other side', async () => {
    const conv = await buyer.client.rpc('start_conversation', { p_shop_id: shop.shopId });
    expect(conv.error).toBeNull();
    const conversationId = (conv.data as { id: string }).id;

    await shop.owner.client.realtime.setAuth();
    let got: string | null = null;
    const subscribed = new Promise<void>((resolve, reject) => {
      shop.owner.client
        .channel(`test-${conversationId}`)
        .on(
          'postgres_changes',
          {
            event: 'INSERT',
            schema: 'public',
            table: 'messages',
            filter: `conversation_id=eq.${conversationId}`,
          },
          (payload) => {
            got ??= (payload.new as { body: string }).body;
          },
        )
        .subscribe((status, err) => {
          if (status === 'SUBSCRIBED') resolve();
          else if (status === 'CHANNEL_ERROR' || status === 'TIMED_OUT')
            reject(err ?? new Error(status));
        });
    });
    await subscribed;

    // Right after a stack (re)starts, the first change can be missed while Realtime
    // attaches to the database; send again until one arrives.
    for (let attempt = 0; attempt < 3 && got === null; attempt++) {
      const sent = await buyer.client
        .from('messages')
        .insert({ conversation_id: conversationId, body: 'السلام عليكم' });
      expect(sent.error).toBeNull();
      for (let waited = 0; waited < 5000 && got === null; waited += 250) {
        await new Promise((r) => setTimeout(r, 250));
      }
    }
    await shop.owner.client.removeAllChannels();
    expect(got).toBe('السلام عليكم');
  }, 45_000);
});

describe.runIf(!hasApi)('M2 over HTTP (skipped)', () => {
  it.skip(apiSkipReason, () => undefined);
});
