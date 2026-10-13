import { MapPinOff } from 'lucide-react';
import { Suspense } from 'react';
import { StreetEditor } from '@/components/admin/street-editor';
import { EmptyState, PageHeader, PageSkeleton, Panel } from '@/components/admin/ui';
import type { Locale } from '@/i18n/config';
import { getDictionary, getLocale, type Dictionary } from '@/i18n/dictionaries';
import { requireAdmin } from '@/lib/auth';
import { loadStreet } from '@/lib/data/street';

export default async function StreetPage() {
  const [d, locale] = await Promise.all([getDictionary(), getLocale()]);
  return (
    <>
      <PageHeader title={d.street.title} description={d.street.subtitle} />
      <Suspense fallback={<PageSkeleton stats={0} rows={4} />}>
        <Street d={d} locale={locale} />
      </Suspense>
    </>
  );
}

async function Street({ d, locale }: { d: Dictionary; locale: Locale }) {
  const { supabase } = await requireAdmin();
  const data = await loadStreet(supabase);
  if (!data) {
    return (
      <Panel>
        <EmptyState icon={<MapPinOff />} title={d.street.none} />
      </Panel>
    );
  }
  return (
    <StreetEditor
      // After a save the page re-renders with the stored rows (new zones get their ids),
      // so the editor starts over from them.
      key={JSON.stringify(data)}
      data={data}
      locale={locale}
      t={{ s: d.street, common: d.common, errors: d.errors }}
    />
  );
}
