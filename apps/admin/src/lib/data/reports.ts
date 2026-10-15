import 'server-only';
import type { Supabase } from '@/lib/supabase/server';
import { must, type Named } from './util';

export type ReportDay = {
  /** Khartoum date, YYYY-MM-DD. */
  day: string;
  orders: number;
  salesSdg: number;
  commissionSdg: number;
  fittings: number;
};

export type ReportShop = {
  id: string;
  name: Named;
  orders: number;
  salesSdg: number;
  commissionSdg: number;
  rating: number;
  ratingCount: number;
};

export type Report = {
  from: string;
  to: string;
  days: ReportDay[];
  totals: {
    orders: number;
    cashOrders: number;
    buyers: number;
    shopsSelling: number;
    salesSdg: number;
    commissionSdg: number;
    deliverySdg: number;
    fittingsBooked: number;
    fittingsDone: number;
    bookingFeesSdg: number;
    labourSdg: number;
    travelSdg: number;
    refundsPaidSdg: number;
    receiptsConfirmed: number;
    receiptsRejected: number;
    /** Average minutes from a receipt sent to its confirmation; null when none. */
    reviewMinutes: number | null;
    newAccounts: number;
    newShops: number;
    newTechnicians: number;
  };
  topShops: ReportShop[];
  /** Fittings booked in the period, by booking status code. */
  fittings: Record<string, number>;
};

type Raw = {
  from: string;
  to: string;
  days: {
    day: string;
    orders: number;
    sales_sdg: number;
    commission_sdg: number;
    fittings: number;
  }[];
  totals: Record<string, number | null>;
  top_shops: {
    shop_id: string;
    name_ar: string;
    name_en: string;
    orders: number;
    sales_sdg: number;
    commission_sdg: number;
    rating_avg: number;
    rating_count: number;
  }[];
  fittings: Record<string, number>;
};

/** The days from [from] to [to] (Khartoum dates, both included); admin_report checks the role. */
export async function loadReport(supabase: Supabase, from: string, to: string): Promise<Report> {
  const r = (await supabase
    .rpc('admin_report', { p_from: from, p_to: to })
    .then(must)) as unknown as Raw;
  const n = (k: string) => Number(r.totals[k] ?? 0);
  return {
    from: r.from,
    to: r.to,
    days: (r.days ?? []).map((d) => ({
      day: d.day,
      orders: Number(d.orders),
      salesSdg: Number(d.sales_sdg),
      commissionSdg: Number(d.commission_sdg),
      fittings: Number(d.fittings),
    })),
    totals: {
      orders: n('orders'),
      cashOrders: n('cash_orders'),
      buyers: n('buyers'),
      shopsSelling: n('shops_selling'),
      salesSdg: n('sales_sdg'),
      commissionSdg: n('commission_sdg'),
      deliverySdg: n('delivery_sdg'),
      fittingsBooked: n('fittings_booked'),
      fittingsDone: n('fittings_done'),
      bookingFeesSdg: n('booking_fees_sdg'),
      labourSdg: n('labour_sdg'),
      travelSdg: n('travel_sdg'),
      refundsPaidSdg: n('refunds_paid_sdg'),
      receiptsConfirmed: n('receipts_confirmed'),
      receiptsRejected: n('receipts_rejected'),
      reviewMinutes: r.totals.review_minutes === null ? null : n('review_minutes'),
      newAccounts: n('new_accounts'),
      newShops: n('new_shops'),
      newTechnicians: n('new_technicians'),
    },
    topShops: r.top_shops.map((s) => ({
      id: s.shop_id,
      name: { ar: s.name_ar, en: s.name_en || s.name_ar },
      orders: Number(s.orders),
      salesSdg: Number(s.sales_sdg),
      commissionSdg: Number(s.commission_sdg),
      rating: Number(s.rating_avg),
      ratingCount: Number(s.rating_count),
    })),
    fittings: r.fittings ?? {},
  };
}

/** Today in Khartoum (UTC+2, no daylight saving) as YYYY-MM-DD, moved by [days]. */
export function khartoumDate(now: Date, days = 0): string {
  return new Date(now.getTime() + 2 * 3_600_000 + days * 86_400_000).toISOString().slice(0, 10);
}
