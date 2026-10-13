import { ReceiptText } from 'lucide-react';
import { Suspense } from 'react';
import { OrderDetail } from '@/components/admin/order-detail';
import { EmptyState, PageSkeleton, Panel } from '@/components/admin/ui';
import type { Locale } from '@/i18n/config';
import { getDictionary, getLocale, type Dictionary } from '@/i18n/dictionaries';
import { requireAdmin } from '@/lib/auth';
import { UUID } from '@/lib/actions/result';
import { loadOrder } from '@/lib/data/commerce';

// The order id is only known at request time, and the console's navigation reads the
// path; there is no static shell to prerender for this route.
export const instant = false;

export default async function OrderPage({ params }: { params: Promise<{ id: string }> }) {
  const [d, locale] = await Promise.all([getDictionary(), getLocale()]);
  return (
    <Suspense fallback={<PageSkeleton stats={0} rows={6} />}>
      <Order params={params} d={d} locale={locale} />
    </Suspense>
  );
}

async function Order({
  params,
  d,
  locale,
}: {
  params: Promise<{ id: string }>;
  d: Dictionary;
  locale: Locale;
}) {
  const { id } = await params;
  const { supabase } = await requireAdmin();
  const order = UUID.test(id) ? await loadOrder(supabase, id) : null;
  if (!order) {
    return (
      <Panel>
        <EmptyState icon={<ReceiptText />} title={d.orders.notFound} />
      </Panel>
    );
  }
  return (
    <OrderDetail
      order={order}
      locale={locale}
      t={{ orders: d.orders, common: d.common, errors: d.errors, status: d.status }}
    />
  );
}
