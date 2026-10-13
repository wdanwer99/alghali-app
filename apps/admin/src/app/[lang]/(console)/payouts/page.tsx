import { Suspense } from 'react';
import { PayoutsBoard } from '@/components/admin/payouts-board';
import { PageHeader, PageSkeleton } from '@/components/admin/ui';
import type { Locale } from '@/i18n/config';
import { getDictionary, getLocale, type Dictionary } from '@/i18n/dictionaries';
import { requireAdmin } from '@/lib/auth';
import { loadPayouts } from '@/lib/data/commerce';
import { fill, shortDate, weekdayDate } from '@/lib/format';

export default async function PayoutsPage() {
  const [d, locale] = await Promise.all([getDictionary(), getLocale()]);
  return (
    <>
      <PageHeader title={d.payouts.title} description={d.payouts.subtitle} />
      <Suspense fallback={<PageSkeleton stats={0} rows={6} />}>
        <Payouts d={d} locale={locale} />
      </Suspense>
    </>
  );
}

/** The next date (from today, Khartoum time) that falls on `weekday` (0 = Sunday). */
function nextWeekday(weekday: number): Date {
  const now = new Date();
  const local = new Date(now.getTime() + 2 * 3_600_000);
  const ahead = (weekday - local.getUTCDay() + 7) % 7;
  return new Date(now.getTime() + ahead * 86_400_000);
}

async function Payouts({ d, locale }: { d: Dictionary; locale: Locale }) {
  const { supabase } = await requireAdmin();
  const { run, rows, payDay } = await loadPayouts(supabase);
  return (
    <PayoutsBoard
      rows={rows}
      hasRun={run !== null}
      locale={locale}
      period={
        run
          ? run.from
            ? `${shortDate(new Date(run.from), locale)} – ${shortDate(new Date(run.to), locale)}`
            : fill(d.payouts.upTo, { date: shortDate(new Date(run.to), locale) })
          : null
      }
      payDay={weekdayDate(nextWeekday(payDay), locale)}
      d={d.payouts}
      common={d.common}
      errors={d.errors}
      statusLabels={d.status.payout}
    />
  );
}
