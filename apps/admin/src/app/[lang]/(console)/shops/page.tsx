import { Suspense } from 'react';
import { ShopsBoard } from '@/components/admin/shops-board';
import { PageHeader, PageSkeleton } from '@/components/admin/ui';
import type { Locale } from '@/i18n/config';
import { getDictionary, getLocale, type Dictionary } from '@/i18n/dictionaries';
import { requireAdmin } from '@/lib/auth';
import { listShops } from '@/lib/data/shops';
import { ago } from '@/lib/format';

export default async function ShopsPage() {
  const [d, locale] = await Promise.all([getDictionary(), getLocale()]);
  return (
    <>
      <PageHeader title={d.shops.title} description={d.shops.subtitle} />
      <Suspense fallback={<PageSkeleton stats={0} rows={8} />}>
        <Shops d={d} locale={locale} />
      </Suspense>
    </>
  );
}

async function Shops({ d, locale }: { d: Dictionary; locale: Locale }) {
  const { supabase } = await requireAdmin();
  const shops = await listShops(supabase);
  const now = new Date();
  return (
    <ShopsBoard
      locale={locale}
      shops={shops.map((s) => ({
        ...s,
        joined: ago(new Date(s.approvedAt ?? s.createdAt), now, d.common),
      }))}
      t={{
        shops: d.shops,
        approvals: d.approvals,
        common: d.common,
        errors: d.errors,
        status: d.status.shop,
      }}
    />
  );
}
