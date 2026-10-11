import { SettingsForm } from '@/components/admin/settings-form';
import { DemoBadge, PageHeader, StatusBadge } from '@/components/admin/ui';
import { getDictionary, getLocale } from '@/i18n/dictionaries';
import { platformSettings, tr } from '@/lib/demo/data';

export default async function SettingsPage() {
  const [d, locale] = await Promise.all([getDictionary(), getLocale()]);
  return (
    <>
      <PageHeader
        title={d.settings.title}
        description={d.settings.subtitle}
        actions={
          <>
            <StatusBadge tone="warning">{d.settings.placeholder}</StatusBadge>
            <DemoBadge label={d.app.demo} note={d.app.demoNote} />
          </>
        }
      />
      <SettingsForm
        values={{
          ...platformSettings,
          bankakAccountName: tr(platformSettings.bankakAccountName, locale),
        }}
        d={d.settings}
        common={d.common}
      />
    </>
  );
}
