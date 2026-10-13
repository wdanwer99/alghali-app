import { OrdersTable } from '@/components/admin/orders-table';
import { SampleBanner, PageHeader } from '@/components/admin/ui';
import { getDictionary, getLocale } from '@/i18n/dictionaries';
import { orders } from '@/lib/demo/data';
import { dateTime } from '@/lib/format';

export default async function OrdersPage() {
  const [d, locale] = await Promise.all([getDictionary(), getLocale()]);
  return (
    <>
      <PageHeader title={d.orders.title} description={d.orders.subtitle} />
      <SampleBanner title={d.sample.title} body={d.sample.orders} />
      <OrdersTable
        orders={orders.map((o) => ({ ...o, placedText: dateTime(o.placedAt, locale) }))}
        d={d.orders}
        common={d.common}
        status={d.status}
      />
    </>
  );
}
