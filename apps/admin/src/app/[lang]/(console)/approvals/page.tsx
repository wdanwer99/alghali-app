import { Suspense } from 'react';
import { ApplicationsReview } from '@/components/admin/applications-review';
import { PageHeader, PageSkeleton } from '@/components/admin/ui';
import type { Locale } from '@/i18n/config';
import { getDictionary, getLocale, type Dictionary } from '@/i18n/dictionaries';
import { requireAdmin } from '@/lib/auth';
import { listTechnicianApplications } from '@/lib/data/installation';
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
  const [shops, technicians] = await Promise.all([
    listShops(supabase),
    listTechnicianApplications(supabase),
  ]);
  const now = new Date();
  return (
    <ApplicationsReview
      locale={locale}
      d={d.approvals}
      common={d.common}
      errors={d.errors}
      pendingLabel={d.status.application.pending}
      // Oldest first: whoever has waited longest is reviewed first.
      shops={shops
        .filter((s) => s.status === 'PENDING')
        .reverse()
        .map((shop) => ({ shop, submitted: ago(new Date(shop.createdAt), now, d.common) }))}
      technicians={technicians.map((t) => ({
        technician: t,
        submitted: ago(new Date(t.appliedAt), now, d.common),
      }))}
    />
  );
}
