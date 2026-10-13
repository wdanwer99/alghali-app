import { must, type Tx } from './db.ts';
import { asSystem, asUser, categoryId, createAdmin, createShop, createUser } from './fixtures.ts';

export type Line = { listing_id?: string; offer_id?: string; qty: number; seen_price_sdg: number };

export interface OrderJson {
  id: string;
  ref: string;
  payment_method: 'BANKAK' | 'CASH';
  items_sdg: number;
  delivery_sdg: number;
  total_sdg: number;
  pay_by: string | null;
  payments: {
    id: string;
    method: string;
    status: string;
    amount_sdg: number;
    sub_order_id: string | null;
  }[];
  refunds: { id: string; sub_order_id: string; amount_sdg: number; status: string }[];
  sub_orders: {
    id: string;
    shop_id: string;
    status: string;
    fulfilment: string;
    items_sdg: number;
    delivery_fee_sdg: number;
    commission_bp: number;
    commission_sdg: number;
    items: {
      listing_id: string | null;
      offer_id: string | null;
      title_ar: string;
      unit_price_sdg: number;
      qty: number;
    }[];
    events: { from: string | null; to: string; actor: string }[];
  }[];
}

/** A buyer with a phone number (checkout needs one). */
export const createBuyer = (tx: Tx) =>
  createUser(tx, { meta: { phone: '0912345678', display_name: 'أحمد م.' } });

/** An approved shop with an owner, and one listing in it. */
export async function shopWithListing(
  tx: Tx,
  opts: {
    price?: number;
    qty?: number;
    category?: string;
    name?: string;
    lat?: number;
    lng?: number;
  } = {},
): Promise<{ owner: string; shopId: string; listingId: string; partId: string; price: number }> {
  const owner = await createUser(tx);
  const shopId = await createShop(tx, owner);
  await asSystem(tx);
  if (opts.lat !== undefined) {
    await tx`update public.shops set lat = ${opts.lat}, lng = ${opts.lng ?? 0} where id = ${shopId}`;
  }
  const listing = await addListing(tx, shopId, opts);
  return { owner, shopId, ...listing };
}

export async function addListing(
  tx: Tx,
  shopId: string,
  opts: { price?: number; qty?: number; category?: string; name?: string } = {},
): Promise<{ listingId: string; partId: string; price: number }> {
  await asSystem(tx);
  const price = opts.price ?? 10000;
  const cat = await categoryId(tx, opts.category ?? 'brakes');
  const [part] = await tx<{ id: string }[]>`
    insert into public.parts (category_id, name_ar, name_en) values (${cat}, ${opts.name ?? 'فحمات فرامل'}, 'Brake pads')
    returning id`;
  const [listing] = await tx<{ id: string }[]>`
    insert into public.listings (shop_id, part_id, condition, price_sdg, stock_qty)
    values (${shopId}, ${must(part).id}, 'NEW_AFTERMARKET', ${price}, ${opts.qty ?? 5})
    returning id`;
  return { listingId: must(listing).id, partId: must(part).id, price };
}

/** Places an order as `buyer` (calls checkout like the app does). */
export async function placeOrder(
  tx: Tx,
  buyer: string,
  lines: Line[],
  opts: {
    method?: 'BANKAK' | 'CASH';
    fulfilment?: Record<string, string>;
    addressId?: string;
    idem?: string;
  } = {},
): Promise<OrderJson> {
  await asUser(tx, buyer);
  const [row] = await tx<{ o: OrderJson }[]>`
    select public.checkout(
      p_items => ${tx.json(lines as never)},
      p_method => ${opts.method ?? 'BANKAK'}::public.payment_method,
      p_fulfilment => ${tx.json((opts.fulfilment ?? {}) as never)},
      p_address_id => ${opts.addressId ?? null},
      p_idem => ${opts.idem ?? null}) as o`;
  return must(row).o;
}

/** Buyer sends a transaction number, then an admin confirms it. Returns the admin's id. */
export async function payByBankak(tx: Tx, order: OrderJson, txn = randomTxn()): Promise<string> {
  await asSystem(tx);
  const [o] = await tx<
    { buyer_id: string }[]
  >`select buyer_id from public.orders where id = ${order.id}`;
  await asUser(tx, must(o).buyer_id);
  await tx`select public.submit_bankak_receipt(${order.id}, ${txn})`;
  const admin = await createAdmin(tx);
  await asUser(tx, admin);
  const payment = must(
    order.payments.find((p) => p.method === 'BANKAK'),
    'bankak payment',
  );
  await tx`select public.admin_confirm_payment(${payment.id})`;
  return admin;
}

export const randomTxn = () => String(Math.floor(100000000 + Math.random() * 899999999));

/** Balance of a ledger account by code (+ debit, − credit), as a number. */
export async function balance(tx: Tx, code: string): Promise<number> {
  await asSystem(tx);
  const [row] = await tx<{ b: string }[]>`
    select coalesce(sum(e.amount_sdg), 0) as b
    from public.ledger_entries e join public.ledger_accounts a on a.id = e.account_id where a.code = ${code}`;
  return Number(must(row).b);
}

export const shopBalance = (tx: Tx, shopId: string) => balance(tx, `SHOP:${shopId}`);

/** Runs the deferred "every journal balances" check now, and lists any journal that doesn't. */
export async function unbalancedJournals(tx: Tx): Promise<string[]> {
  await asSystem(tx);
  await tx`set constraints all immediate`;
  const rows = await tx<{ id: string }[]>`
    select journal_id as id from public.ledger_entries group by journal_id having sum(amount_sdg) <> 0`;
  return rows.map((r) => r.id);
}

/** Journal kinds posted for an order, in order. */
export async function journalKinds(tx: Tx, orderId: string): Promise<string[]> {
  await asSystem(tx);
  const rows = await tx<{ kind: string }[]>`
    select kind from public.ledger_journals where order_id = ${orderId} order by created_at, kind`;
  return rows.map((r) => r.kind);
}

/** Moves a sub-order along as its shop: ready, then handed over (pickup or delivery). */
export async function shopFulfils(tx: Tx, owner: string, subOrderId: string): Promise<void> {
  await asUser(tx, owner);
  await tx`select public.shop_mark_ready(${subOrderId})`;
  await tx`select public.shop_hand_over(${subOrderId})`;
}
