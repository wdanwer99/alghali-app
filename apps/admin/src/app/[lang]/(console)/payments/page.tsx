import { PaymentsQueue } from '@/components/admin/payments-queue';
import { DemoBadge, PageHeader } from '@/components/admin/ui';
import { getDictionary, getLocale } from '@/i18n/dictionaries';

export default async function PaymentsPage() {
  const [d, locale] = await Promise.all([getDictionary(), getLocale()]);
  return (
    <>
      <PageHeader
        title={d.payments.title}
        description={d.payments.subtitle}
        actions={<DemoBadge label={d.app.demo} note={d.app.demoNote} />}
      />
      <PaymentsQueue locale={locale} d={d.payments} common={d.common} />
    </>
  );
}
