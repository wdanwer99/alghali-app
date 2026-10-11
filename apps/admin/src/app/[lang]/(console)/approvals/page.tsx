import { ApplicationsReview } from '@/components/admin/applications-review';
import { DemoBadge, PageHeader } from '@/components/admin/ui';
import { getDictionary, getLocale } from '@/i18n/dictionaries';

export default async function ApprovalsPage() {
  const [d, locale] = await Promise.all([getDictionary(), getLocale()]);
  return (
    <>
      <PageHeader
        title={d.approvals.title}
        description={d.approvals.subtitle}
        actions={<DemoBadge label={d.app.demo} note={d.app.demoNote} />}
      />
      <ApplicationsReview
        locale={locale}
        d={d.approvals}
        common={d.common}
        statusLabels={d.status.application}
      />
    </>
  );
}
