import { Suspense } from 'react';
import { BookingsTable } from '@/components/admin/bookings-table';
import { PageHeader, PageSkeleton } from '@/components/admin/ui';
import type { Locale } from '@/i18n/config';
import { getDictionary, getLocale, type Dictionary } from '@/i18n/dictionaries';
import { requireAdmin } from '@/lib/auth';
import { listBookings } from '@/lib/data/installation';
import { dateTime } from '@/lib/format';

export default async function BookingsPage() {
  const [d, locale] = await Promise.all([getDictionary(), getLocale()]);
  return (
    <>
      <PageHeader title={d.bookings.title} description={d.bookings.subtitle} />
      <Suspense fallback={<PageSkeleton stats={0} rows={8} />}>
        <Bookings d={d} locale={locale} />
      </Suspense>
    </>
  );
}

async function Bookings({ d, locale }: { d: Dictionary; locale: Locale }) {
  const { supabase } = await requireAdmin();
  const bookings = await listBookings(supabase);
  return (
    <BookingsTable
      bookings={bookings.map((b) => ({ ...b, startText: dateTime(new Date(b.startAt), locale) }))}
      locale={locale}
      d={d.bookings}
      common={d.common}
      status={d.status}
    />
  );
}
