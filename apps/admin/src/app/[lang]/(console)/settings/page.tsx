import { Suspense } from 'react';
import { SettingsForm } from '@/components/admin/settings-form';
import { PageHeader, PageSkeleton } from '@/components/admin/ui';
import { getDictionary, type Dictionary } from '@/i18n/dictionaries';
import { requireAdmin } from '@/lib/auth';
import { loadSettings } from '@/lib/data/settings';
import { ago, fill } from '@/lib/format';

export default async function SettingsPage() {
  const d = await getDictionary();
  return (
    <>
      <PageHeader title={d.settings.title} description={d.settings.subtitle} />
      <Suspense fallback={<PageSkeleton stats={0} rows={6} />}>
        <Settings d={d} />
      </Suspense>
    </>
  );
}

async function Settings({ d }: { d: Dictionary }) {
  const { supabase } = await requireAdmin();
  const settings = await loadSettings(supabase);
  const latest = Object.values(settings).sort((a, b) => b.updatedAt.localeCompare(a.updatedAt))[0];
  const age = latest ? ago(new Date(latest.updatedAt), new Date(), d.common) : null;
  return (
    <SettingsForm
      settings={Object.fromEntries(Object.entries(settings).map(([k, s]) => [k, s.value]))}
      lastChanged={
        age
          ? latest.updatedBy
            ? fill(d.settings.lastChanged, { age, name: latest.updatedBy })
            : fill(d.settings.lastChangedBy, { age })
          : undefined
      }
      d={d.settings}
      common={d.common}
      errors={d.errors}
      weekdays={d.shops.weekdays}
    />
  );
}
