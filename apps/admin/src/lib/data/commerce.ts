import 'server-only';
import type { Database } from '@alghali/db-types';
import type { Supabase } from '@/lib/supabase/server';
import { must, type Named } from './util';

export type SubStatus = Database['public']['Enums']['suborder_status'];
export type PayStatus = Database['public']['Enums']['payment_status'];
export type Method = Database['public']['Enums']['payment_method'];
export type Fulfilment = Database['public']['Enums']['fulfilment_type'];

const named = (ar: string | null | undefined, en: string | null | undefined): Named => ({
  ar: ar ?? '',
  en: en || ar || '',
});

/** Buyers' names and contact details, by user id (profiles have no FK to embed through). */
async function people(supabase: Supabase, ids: string[]) {
  const unique = [...new Set(ids.filter(Boolean))];
  if (!unique.length) return new Map<string, Person>();
  const rows = await supabase
    .from('profiles')
    .select('id, display_name, email, phone, refund_account')
    .in('id', unique)
    .then(must);
  return new Map(
    rows.map((p) => [
      p.id,
      {
        name: p.display_name || p.email || '',
        email: p.email ?? '',
        phone: p.phone,
        refundAccount: p.refund_account,
      },
    ]),
  );
}

export type Person = {
  name: string;
  email: string;
  phone: string | null;
  refundAccount: string | null;
};

// -------------------------------------------------------------------- payments

export type Receipt = {
  paymentId: string;
  orderId: string;
  ref: string;
  amountSdg: number;
  txn: string | null;
  txnSeenBefore: boolean;
  receiptUrl: string | null;
  submittedAt: string;
  payBy: string | null;
  buyer: { name: string; phone: string | null; email: string };
  shops: Named[];
  hasFitting: boolean;
  earlierRejections: number;
};

type QueueRow = {
  payment_id: string;
  order_id: string;
  ref: string;
  amount_sdg: number;
  txn: string | null;
  receipt_key: string | null;
  submitted_at: string;
  pay_by: string | null;
  buyer: { name: string | null; phone: string | null; email: string | null };
  txn_seen_before: boolean;
  shops: { name_ar: string; name_en: string }[];
  has_fitting: boolean;
  earlier_rejections: number;
};

/** Receipts waiting for review, oldest first, with short-lived links to the screenshots. */
export async function loadPaymentQueue(supabase: Supabase): Promise<Receipt[]> {
  const rows = (await supabase.rpc('admin_payment_queue').then(must)) as unknown as QueueRow[];
  const keys = rows.flatMap((r) => (r.receipt_key ? [r.receipt_key] : []));
  const urls = new Map<string, string>();
  if (keys.length) {
    const { data } = await supabase.storage.from('receipts').createSignedUrls(keys, 15 * 60);
    for (const s of data ?? []) if (s.path && s.signedUrl) urls.set(s.path, s.signedUrl);
  }
  return rows.map((r) => ({
    paymentId: r.payment_id,
    orderId: r.order_id,
    ref: r.ref,
    amountSdg: Number(r.amount_sdg),
    txn: r.txn,
    txnSeenBefore: r.txn_seen_before,
    receiptUrl: r.receipt_key ? (urls.get(r.receipt_key) ?? null) : null,
    submittedAt: r.submitted_at,
    payBy: r.pay_by,
    buyer: {
      name: r.buyer.name || r.buyer.email || '',
      phone: r.buyer.phone,
      email: r.buyer.email ?? '',
    },
    shops: r.shops.map((s) => named(s.name_ar, s.name_en)),
    hasFitting: r.has_fitting,
    earlierRejections: Number(r.earlier_rejections),
  }));
}

export type Refund = {
  id: string;
  orderId: string;
  ref: string;
  amountSdg: number;
  reason: string | null;
  status: 'PENDING' | 'PAID';
  txn: string | null;
  createdAt: string;
  paidAt: string | null;
  buyer: Person | null;
};

/** Refunds to send first (oldest first), then the last month's sent ones. */
export async function loadRefunds(supabase: Supabase): Promise<Refund[]> {
  const since = new Date(Date.now() - 30 * 86_400_000).toISOString();
  const rows = await supabase
    .from('refunds')
    .select(
      'id, order_id, buyer_id, amount_sdg, reason, status, bankak_txn_no, paid_at, created_at, order:orders(ref)',
    )
    .or(`status.eq.PENDING,paid_at.gte.${since}`)
    .order('created_at', { ascending: true })
    .then(must);
  const buyers = await people(
    supabase,
    rows.map((r) => r.buyer_id),
  );
  return rows
    .map((r) => ({
      id: r.id,
      orderId: r.order_id,
      ref: r.order?.ref ?? '',
      amountSdg: Number(r.amount_sdg),
      reason: r.reason,
      status: r.status as Refund['status'],
      txn: r.bankak_txn_no,
      createdAt: r.created_at,
      paidAt: r.paid_at,
      buyer: buyers.get(r.buyer_id) ?? null,
    }))
    .sort((a, b) => (a.status === b.status ? 0 : a.status === 'PENDING' ? -1 : 1));
}

// ---------------------------------------------------------------------- orders

/** The status an admin should see first when an order's shops are at different steps. */
const ATTENTION: SubStatus[] = [
  'PAYMENT_REVIEW',
  'PENDING_PAYMENT',
  'RETURN_REQUESTED',
  'CONFIRMED',
  'READY',
  'OUT_FOR_DELIVERY',
  'HANDED_TO_TECHNICIAN',
  'PICKED_UP',
  'DELIVERED',
  'COMPLETED',
  'RETURNED',
  'REJECTED_BY_SHOP',
  'CANCELLED',
];

export const orderStatusOf = (statuses: SubStatus[]): SubStatus =>
  ATTENTION.find((s) => statuses.includes(s)) ?? 'CANCELLED';

/** One payment state per order: the Bankak transfer, or the cash still to collect. */
function paymentOf(
  method: Method,
  payments: { status: PayStatus; method: Method }[],
): PayStatus | null {
  if (method === 'BANKAK') return payments.find((p) => p.method === 'BANKAK')?.status ?? null;
  const cash = payments.filter((p) => p.method === 'CASH').map((p) => p.status);
  if (cash.includes('DUE')) return 'DUE';
  if (cash.includes('COLLECTED')) return 'COLLECTED';
  return cash[0] ?? null;
}

export type OrderRow = {
  id: string;
  ref: string;
  placedAt: string;
  buyer: string;
  shops: number;
  items: number;
  totalSdg: number;
  method: Method;
  payment: PayStatus | null;
  status: SubStatus;
};

export async function listOrders(supabase: Supabase, limit = 300): Promise<OrderRow[]> {
  const rows = await supabase
    .from('orders')
    .select(
      `id, ref, buyer_id, payment_method, total_sdg, created_at,
       sub_orders(status, order_items(qty)), payments(status, method)`,
    )
    .order('created_at', { ascending: false })
    .limit(limit)
    .then(must);
  const buyers = await people(
    supabase,
    rows.map((r) => r.buyer_id),
  );
  return rows.map((o) => ({
    id: o.id,
    ref: o.ref,
    placedAt: o.created_at,
    buyer: buyers.get(o.buyer_id)?.name ?? '',
    shops: o.sub_orders.length,
    items: o.sub_orders.reduce((n, s) => n + s.order_items.reduce((m, i) => m + i.qty, 0), 0),
    totalSdg: Number(o.total_sdg),
    method: o.payment_method,
    payment: paymentOf(o.payment_method, o.payments),
    status: orderStatusOf(o.sub_orders.map((s) => s.status)),
  }));
}

export type OrderEvent = {
  from: SubStatus | null;
  to: SubStatus;
  actor: string;
  by: string | null;
  reason: string | null;
  at: string;
};

export type OrderDetail = {
  id: string;
  ref: string;
  placedAt: string;
  payBy: string | null;
  method: Method;
  itemsSdg: number;
  deliverySdg: number;
  totalSdg: number;
  address: { label?: string; description_ar?: string | null; lat?: number; lng?: number } | null;
  buyer: Person | null;
  payments: {
    id: string;
    method: Method;
    status: PayStatus;
    amountSdg: number;
    txn: string | null;
    rejectReason: string | null;
    subOrderId: string | null;
    reviewedAt: string | null;
  }[];
  refunds: {
    id: string;
    subOrderId: string | null;
    amountSdg: number;
    status: string;
    txn: string | null;
  }[];
  subOrders: {
    id: string;
    shop: Named & { id: string; phone: string | null };
    status: SubStatus;
    fulfilment: Fulfilment;
    itemsSdg: number;
    deliveryFeeSdg: number;
    commissionSdg: number;
    acceptedAt: string | null;
    cancelReason: string | null;
    items: {
      id: string;
      title: Named;
      condition: string;
      brand: string | null;
      unitPriceSdg: number;
      qty: number;
      warrantyDays: number;
    }[];
    events: OrderEvent[];
    return: { reason: string; status: string; note: string | null; createdAt: string } | null;
  }[];
};

export async function loadOrder(supabase: Supabase, id: string): Promise<OrderDetail | null> {
  const o = await supabase
    .from('orders')
    .select(
      `id, ref, buyer_id, payment_method, items_sdg, delivery_sdg, total_sdg, pay_by, created_at, address_snapshot,
       payments(id, method, status, amount_sdg, bankak_txn_no, reject_reason, sub_order_id, reviewed_at, created_at),
       refunds(id, sub_order_id, amount_sdg, status, bankak_txn_no),
       sub_orders(id, status, fulfilment, items_sdg, delivery_fee_sdg, commission_sdg, shop_ack_at, cancel_reason,
         shop:shops(id, name_ar, name_en, phone),
         order_items(id, title_ar, title_en, condition, brand, unit_price_sdg, qty, warranty_days),
         suborder_events(id, from_status, to_status, actor_kind, actor_id, reason, at),
         returns(reason, status, decision_note, created_at))`,
    )
    .eq('id', id)
    .maybeSingle()
    .then(must);
  if (!o) return null;
  const actorIds = o.sub_orders.flatMap((s) =>
    s.suborder_events.flatMap((e) => (e.actor_id ? [e.actor_id] : [])),
  );
  const names = await people(supabase, [o.buyer_id, ...actorIds]);
  return {
    id: o.id,
    ref: o.ref,
    placedAt: o.created_at,
    payBy: o.pay_by,
    method: o.payment_method,
    itemsSdg: Number(o.items_sdg),
    deliverySdg: Number(o.delivery_sdg),
    totalSdg: Number(o.total_sdg),
    address: (o.address_snapshot ?? null) as OrderDetail['address'],
    buyer: names.get(o.buyer_id) ?? null,
    payments: [...o.payments]
      .sort((a, b) => a.created_at.localeCompare(b.created_at))
      .map((p) => ({
        id: p.id,
        method: p.method,
        status: p.status,
        amountSdg: Number(p.amount_sdg),
        txn: p.bankak_txn_no,
        rejectReason: p.reject_reason,
        subOrderId: p.sub_order_id,
        reviewedAt: p.reviewed_at,
      })),
    refunds: o.refunds.map((r) => ({
      id: r.id,
      subOrderId: r.sub_order_id,
      amountSdg: Number(r.amount_sdg),
      status: r.status,
      txn: r.bankak_txn_no,
    })),
    subOrders: o.sub_orders.map((s) => ({
      id: s.id,
      shop: {
        id: s.shop?.id ?? '',
        ...named(s.shop?.name_ar, s.shop?.name_en),
        phone: s.shop?.phone ?? null,
      },
      status: s.status,
      fulfilment: s.fulfilment,
      itemsSdg: Number(s.items_sdg),
      deliveryFeeSdg: Number(s.delivery_fee_sdg),
      commissionSdg: Number(s.commission_sdg),
      acceptedAt: s.shop_ack_at,
      cancelReason: s.cancel_reason,
      items: s.order_items.map((i) => ({
        id: i.id,
        title: named(i.title_ar, i.title_en),
        condition: i.condition,
        brand: i.brand,
        unitPriceSdg: Number(i.unit_price_sdg),
        qty: i.qty,
        warrantyDays: i.warranty_days,
      })),
      events: [...s.suborder_events]
        .sort((a, b) => a.at.localeCompare(b.at) || a.id - b.id)
        .map((e) => ({
          from: e.from_status,
          to: e.to_status,
          actor: e.actor_kind,
          by: e.actor_id ? (names.get(e.actor_id)?.name ?? null) : null,
          reason: e.reason,
          at: e.at,
        })),
      return: s.returns
        ? {
            reason: s.returns.reason,
            status: s.returns.status,
            note: s.returns.decision_note,
            createdAt: s.returns.created_at,
          }
        : null,
    })),
  };
}

// ------------------------------------------------------------------------ cash

export type PartnerBalance = {
  /** A shop or a technician (M3); `id` is the shop's or the technician's id. */
  party: 'SHOP' | 'TECH';
  id: string;
  name: Named;
  /** Positive: the platform owes the shop. Negative: the shop owes the platform. */
  balanceSdg: number;
  cashCollectedSdg: number;
  openPayoutSdg: number | null;
  cyclesOwing: number;
};

export async function loadPartnerBalances(supabase: Supabase): Promise<PartnerBalance[]> {
  const rows = (await supabase.rpc('admin_partner_balances').then(must)) as unknown as {
    party: 'SHOP' | 'TECH';
    shop_id: string | null;
    technician_id: string | null;
    name_ar: string;
    name_en: string;
    balance_sdg: number;
    cash_collected_sdg: number;
    open_payout_sdg: number | null;
    cycles_owing: number;
  }[];
  return rows.map((r) => ({
    party: r.party,
    id: (r.shop_id ?? r.technician_id) as string,
    name: named(r.name_ar, r.name_en),
    balanceSdg: Number(r.balance_sdg),
    cashCollectedSdg: Number(r.cash_collected_sdg),
    openPayoutSdg: r.open_payout_sdg === null ? null : Number(r.open_payout_sdg),
    cyclesOwing: Number(r.cycles_owing),
  }));
}

// --------------------------------------------------------------------- payouts

export type PayoutStatus = 'DRAFT' | 'APPROVED' | 'PAID' | 'CANCELLED';

export type Payout = {
  id: string;
  party: 'SHOP' | 'TECH';
  partner: Named;
  amountSdg: number;
  salesSdg: number;
  deductionsSdg: number;
  status: PayoutStatus;
  txn: string | null;
  paidAt: string | null;
};

export type Payouts = {
  run: { id: string; from: string | null; to: string; createdAt: string } | null;
  rows: Payout[];
  /** Weekday (0 = Sunday) payouts are sent on, from the payout_schedule setting. */
  payDay: number;
};

/** The latest run's payouts, plus any still waiting from earlier runs. */
export async function loadPayouts(supabase: Supabase): Promise<Payouts> {
  const [runs, schedule] = await Promise.all([
    supabase
      .from('payout_runs')
      .select('id, period_from, period_to, created_at')
      .order('period_to', { ascending: false })
      .limit(1)
      .then(must),
    supabase.rpc('admin_settings').then(must),
  ]);
  const run = runs[0] ?? null;
  const payDay = Number(
    (
      (schedule as { key: string; value: unknown }[]).find((s) => s.key === 'payout_schedule')
        ?.value as { weekday?: number } | undefined
    )?.weekday ?? 0,
  );
  const filter = run
    ? `run_id.eq.${run.id},status.in.(DRAFT,APPROVED)`
    : 'status.in.(DRAFT,APPROVED)';
  const rows = await supabase
    .from('payouts')
    .select(
      'id, amount_sdg, sales_sdg, deductions_sdg, status, bankak_txn_no, paid_at, shop:shops(name_ar, name_en), technician:technicians(user_id)',
    )
    .or(filter)
    .order('amount_sdg', { ascending: false })
    .then(must);
  const techNames = await people(
    supabase,
    rows.flatMap((p) => (p.technician ? [p.technician.user_id] : [])),
  );
  return {
    run: run
      ? { id: run.id, from: run.period_from, to: run.period_to, createdAt: run.created_at }
      : null,
    payDay,
    rows: rows.map((p) => ({
      id: p.id,
      party: p.technician ? ('TECH' as const) : ('SHOP' as const),
      partner: p.technician
        ? named(techNames.get(p.technician.user_id)?.name, null)
        : named(p.shop?.name_ar, p.shop?.name_en),
      amountSdg: Number(p.amount_sdg),
      salesSdg: Number(p.sales_sdg),
      deductionsSdg: Number(p.deductions_sdg),
      status: p.status as PayoutStatus,
      txn: p.bankak_txn_no,
      paidAt: p.paid_at,
    })),
  };
}

// -------------------------------------------------------------------- overview

export type CommerceCounts = {
  receipts: number;
  oldestReceiptAt: string | null;
  refunds: number;
  refundsSdg: number;
  returns: number;
  ordersToday: number;
  salesTodaySdg: number;
  owedToPlatformSdg: number;
};

export async function loadCommerceCounts(supabase: Supabase): Promise<CommerceCounts> {
  // Midnight in Khartoum (UTC+2, no DST) as a UTC timestamp.
  const now = new Date();
  const local = new Date(now.getTime() + 2 * 3_600_000);
  const midnight = new Date(
    Date.UTC(local.getUTCFullYear(), local.getUTCMonth(), local.getUTCDate()) - 2 * 3_600_000,
  );
  const [receipts, refunds, returns, today, balances] = await Promise.all([
    supabase
      .from('payments')
      .select('submitted_at')
      .eq('status', 'RECEIPT_SUBMITTED')
      .order('submitted_at')
      .then(must),
    supabase.from('refunds').select('amount_sdg').eq('status', 'PENDING').then(must),
    supabase.from('returns').select('id', { count: 'exact', head: true }).eq('status', 'REQUESTED'),
    supabase
      .from('orders')
      .select('total_sdg, sub_orders(status)')
      .gte('created_at', midnight.toISOString())
      .then(must),
    loadPartnerBalances(supabase),
  ]);
  const live = today.filter((o) => o.sub_orders.some((s) => s.status !== 'CANCELLED'));
  return {
    receipts: receipts.length,
    oldestReceiptAt: receipts[0]?.submitted_at ?? null,
    refunds: refunds.length,
    refundsSdg: refunds.reduce((s, r) => s + Number(r.amount_sdg), 0),
    returns: returns.count ?? 0,
    ordersToday: live.length,
    salesTodaySdg: live.reduce((s, o) => s + Number(o.total_sdg), 0),
    owedToPlatformSdg: balances.reduce((s, b) => s + Math.max(-b.balanceSdg, 0), 0),
  };
}
