import { LoginForm } from '@/components/admin/login-form';
import { Mark } from '@/components/admin/ui';
import { LanguageSwitch } from '@/components/language-switch';
import { getDictionary, getLocale } from '@/i18n/dictionaries';

export default async function LoginPage() {
  const [d, locale] = await Promise.all([getDictionary(), getLocale()]);

  return (
    <main className="flex flex-1 flex-col items-center justify-center gap-6 p-4">
      <div className="flex flex-col items-center gap-3 text-center">
        <Mark size={56} />
        <div>
          <p className="text-sm font-semibold text-muted-foreground">{d.app.shortTitle}</p>
          <h1 className="text-2xl font-bold">{d.login.title}</h1>
          <p className="mt-1 text-sm text-muted-foreground">{d.login.subtitle}</p>
        </div>
      </div>
      <div className="w-full max-w-sm rounded-xl bg-card p-6 ring-1 ring-foreground/10">
        <LoginForm locale={locale} d={d.login} />
      </div>
      <LanguageSwitch current={locale} label={d.nav.switchLanguage} />
    </main>
  );
}
