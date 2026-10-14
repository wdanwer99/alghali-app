import { CalendarClock } from 'lucide-react';
import { Suspense } from 'react';
import { BookingDetail } from '@/components/admin/booking-detail';
import { EmptyState, PageSkeleton, Panel } from '@/components/admin/ui';
import type { Locale } from '@/i18n/config';
import { getDictionary, getLocale, type Dictionary } from '@/i18n/dictionaries';
import { requireAdmin } from '@/lib/auth';
import { UUID } from '@/lib/actions/result';
import { loadBooking } from '@/lib/data/installation';

// The booking id is only known at request time; there is no static shell to prerender.
export const instant = false;

export default async function BookingPage({ params }: { params: Promise<{ id: string }> }) {
  const [d, locale] = await Promise.all([getDictionary(), getLocale()]);
  return (
    <Suspense fallback={<PageSkeleton stats={0} rows={6} />}>
      <Booking params={params} d={d} locale={locale} />
    </Suspense>
  );
}

async function Booking({
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
  const booking = UUID.test(id) ? await loadBooking(supabase, id) : null;
  if (!booking) {
    return (
      <Panel>
        <EmptyState icon={<CalendarClock />} title={d.bookings.notFound} />
      </Panel>
    );
  }
  return (
    <BookingDetail
      booking={booking}
      locale={locale}
      t={{ bookings: d.bookings, common: d.common, errors: d.errors, status: d.status }}
    />
  );
}
