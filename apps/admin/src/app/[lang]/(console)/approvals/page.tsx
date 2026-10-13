import { Suspense } from 'react';
import { ApplicationsReview } from '@/components/admin/applications-review';
import { PageHeader, PageSkeleton } from '@/components/admin/ui';
import type { Locale } from '@/i18n/config';
import { getDictionary, getLocale, type Dictionary } from '@/i18n/dictionaries';
import { requireAdmin } from '@/lib/auth';
import { applications, DEMO_NOW } from '@/lib/demo/data';
import { listShops } from '@/lib/data/shops';
import { ago } from '@/lib/format';

export default async function ApprovalsPage() {
  const [d, locale] = await Promise.all([getDictionary(), getLocale()]);
  return (
    <>
      <PageHeader title={d.approvals.title} description={d.approvals.subtitle} />
      <Suspense fallback={<PageSkeleton stats={0} rows={4} />}>
        <Applications d={d} locale={locale} />
      </Suspense>
    </>
  );
}

async function Applications({ d, locale }: { d: Dictionary; locale: Locale }) {
  const { supabase } = await requireAdmin();
  const shops = await listShops(supabase);
  const now = new Date();
  return (
    <ApplicationsReview
      locale={locale}
      d={d.approvals}
      common={d.common}
      errors={d.errors}
      sample={{
        tag: d.app.sampleTag,
        title: d.sample.title,
        body: d.sample.technicians,
        statuses: d.status.application,
      }}
      // Oldest first: whoever has waited longest is reviewed first.
      shops={shops
        .filter((s) => s.status === 'PENDING')
        .reverse()
        .map((shop) => ({ shop, submitted: ago(new Date(shop.createdAt), now, d.common) }))}
      technicians={applications
        .filter((a) => a.kind === 'technician')
        .map((a) => ({ ...a, submitted: ago(a.submittedAt, DEMO_NOW, d.common) }))}
    />
  );
}
