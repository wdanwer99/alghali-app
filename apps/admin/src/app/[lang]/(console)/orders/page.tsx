import { Suspense } from 'react';
import { OrdersTable } from '@/components/admin/orders-table';
import { PageHeader, PageSkeleton } from '@/components/admin/ui';
import type { Locale } from '@/i18n/config';
import { getDictionary, getLocale, type Dictionary } from '@/i18n/dictionaries';
import { requireAdmin } from '@/lib/auth';
import { listOrders } from '@/lib/data/commerce';
import { dateTime } from '@/lib/format';

export default async function OrdersPage() {
  const [d, locale] = await Promise.all([getDictionary(), getLocale()]);
  return (
    <>
      <PageHeader title={d.orders.title} description={d.orders.subtitle} />
      <Suspense fallback={<PageSkeleton stats={0} rows={8} />}>
        <Orders d={d} locale={locale} />
      </Suspense>
    </>
  );
}

async function Orders({ d, locale }: { d: Dictionary; locale: Locale }) {
  const { supabase } = await requireAdmin();
  const orders = await listOrders(supabase);
  return (
    <OrdersTable
      orders={orders.map((o) => ({ ...o, placedText: dateTime(new Date(o.placedAt), locale) }))}
      locale={locale}
      d={d.orders}
      common={d.common}
      status={d.status}
    />
  );
}
