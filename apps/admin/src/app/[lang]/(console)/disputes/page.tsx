import { Suspense } from 'react';
import { DisputesBoard } from '@/components/admin/disputes-board';
import { PageHeader, PageSkeleton } from '@/components/admin/ui';
import type { Locale } from '@/i18n/config';
import { getDictionary, getLocale, type Dictionary } from '@/i18n/dictionaries';
import { requireAdmin } from '@/lib/auth';
import { listDisputes } from '@/lib/data/installation';
import { ago, dateTime } from '@/lib/format';

export default async function DisputesPage() {
  const [d, locale] = await Promise.all([getDictionary(), getLocale()]);
  return (
    <>
      <PageHeader title={d.disputes.title} description={d.disputes.subtitle} />
      <Suspense fallback={<PageSkeleton stats={0} rows={6} />}>
        <Disputes d={d} locale={locale} />
      </Suspense>
    </>
  );
}

async function Disputes({ d, locale }: { d: Dictionary; locale: Locale }) {
  const { supabase } = await requireAdmin();
  const disputes = await listDisputes(supabase);
  const now = new Date();
  return (
    <DisputesBoard
      disputes={disputes.map((x) => ({
        ...x,
        openedText: ago(new Date(x.createdAt), now, d.common),
        messages: x.messages.map((m) => ({ ...m, atText: dateTime(new Date(m.at), locale) })),
      }))}
      locale={locale}
      t={{ disputes: d.disputes, common: d.common, errors: d.errors, status: d.status }}
    />
  );
}
