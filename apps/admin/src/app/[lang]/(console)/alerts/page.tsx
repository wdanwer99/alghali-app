import { Suspense } from 'react';
import { AlertsEditor } from '@/components/admin/alerts-editor';
import { PageHeader, PageSkeleton } from '@/components/admin/ui';
import { getDictionary, type Dictionary } from '@/i18n/dictionaries';
import { requireAdmin } from '@/lib/auth';
import { loadAlertWording } from '@/lib/data/alerts';

export default async function AlertsPage() {
  const d = await getDictionary();
  return (
    <>
      <PageHeader title={d.alerts.title} description={d.alerts.subtitle} />
      <Suspense fallback={<PageSkeleton stats={0} rows={8} />}>
        <Alerts d={d} />
      </Suspense>
    </>
  );
}

async function Alerts({ d }: { d: Dictionary }) {
  const { supabase } = await requireAdmin();
  const rows = await loadAlertWording(supabase);
  return <AlertsEditor rows={rows} d={d.alerts} common={d.common} errors={d.errors} />;
}
