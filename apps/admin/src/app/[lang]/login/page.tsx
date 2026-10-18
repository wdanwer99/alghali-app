import { redirect } from 'next/navigation';
import { Suspense } from 'react';
import { LoginForm, LoginNotice } from '@/components/admin/login-form';
import { Mark, riseStyle } from '@/components/admin/ui';
import { LanguageSwitch } from '@/components/language-switch';
import { getDictionary, getLocale } from '@/i18n/dictionaries';
import { getAdminSession } from '@/lib/auth';

export default async function LoginPage({ searchParams }: PageProps<'/[lang]/login'>) {
  const [d, locale] = await Promise.all([getDictionary(), getLocale()]);

  return (
    <main className="relative flex flex-1 flex-col items-center justify-center gap-6 overflow-hidden p-4">
      {/* Soft brand glow behind the card; decorative only. */}
      <div
        aria-hidden
        className="pointer-events-none absolute -top-40 left-1/2 size-[36rem] -translate-x-1/2 rounded-full bg-primary/10 blur-3xl"
      />
      <Suspense>
        <SendAdminIn locale={locale} />
      </Suspense>
      <div className="rise flex flex-col items-center gap-3 text-center">
        <Mark size={56} />
        <div>
          <p className="text-sm font-semibold text-muted-foreground">{d.app.shortTitle}</p>
          <h1 className="text-2xl font-bold">{d.login.title}</h1>
          <p className="mt-1 text-sm text-muted-foreground">{d.login.subtitle}</p>
        </div>
      </div>
      <div
        className="rise w-full max-w-sm rounded-2xl bg-card p-6 shadow-sm ring-1 ring-foreground/10"
        style={riseStyle(1)}
      >
        {/* Only the note waits for the address; the form is there from the first paint. */}
        <LoginForm
          locale={locale}
          d={d.login}
          notice={
            <Suspense>
              <SessionEnded searchParams={searchParams} text={d.login.sessionEnded} />
            </Suspense>
          }
        />
      </div>
      <LanguageSwitch current={locale} label={d.nav.switchLanguage} />
    </main>
  );
}

/** Someone already signed in as an admin goes straight to the console. */
async function SendAdminIn({ locale }: { locale: string }) {
  if (await getAdminSession()) redirect(`/${locale}`);
  return null;
}

/** Shown when an admin page sent the visitor here (`?reason=signin`). */
async function SessionEnded({
  searchParams,
  text,
}: {
  searchParams: PageProps<'/[lang]/login'>['searchParams'];
  text: string;
}) {
  const { reason } = await searchParams;
  return reason === 'signin' ? <LoginNotice text={text} /> : null;
}
