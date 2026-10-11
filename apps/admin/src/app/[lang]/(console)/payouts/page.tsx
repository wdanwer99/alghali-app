import { PayoutsBoard } from '@/components/admin/payouts-board';
import { DemoBadge, PageHeader } from '@/components/admin/ui';
import { getDictionary, getLocale } from '@/i18n/dictionaries';
import { payouts, payoutWeek } from '@/lib/demo/data';
import { shortDate, weekdayDate } from '@/lib/format';

export default async function PayoutsPage() {
  const [d, locale] = await Promise.all([getDictionary(), getLocale()]);
  return (
    <>
      <PageHeader
        title={d.payouts.title}
        description={d.payouts.subtitle}
        actions={<DemoBadge label={d.app.demo} note={d.app.demoNote} />}
      />
      <PayoutsBoard
        rows={payouts}
        locale={locale}
        period={`${shortDate(payoutWeek.from, locale)} – ${shortDate(payoutWeek.to, locale)}`}
        payDay={weekdayDate(payoutWeek.payDay, locale)}
        d={d.payouts}
        common={d.common}
        statusLabels={d.status.payout}
      />
    </>
  );
}
