import Link from 'next/link';
import { Suspense } from 'react';
import { BackendStatus } from '@/components/backend-status';
import { LanguageSwitch } from '@/components/language-switch';
import { Badge } from '@/components/ui/badge';
import { buttonVariants } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { getDictionary, getLocale } from '@/i18n/dictionaries';

const queueKeys = ['approvals', 'payments', 'cash', 'catalogue', 'disputes', 'payouts'] as const;

export default async function HomePage() {
  const [d, locale] = await Promise.all([getDictionary(), getLocale()]);

  return (
    <main className="mx-auto flex w-full max-w-5xl flex-col gap-6 p-4 sm:p-6">
      <header className="flex flex-wrap items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold">{d.app.title}</h1>
          <p className="text-muted-foreground">{d.home.subtitle}</p>
        </div>
        <div className="flex items-center gap-2">
          <Link href={`/${locale}/login`} className={buttonVariants({ size: 'sm' })}>
            {d.nav.login}
          </Link>
          <LanguageSwitch current={locale} label={d.nav.switchLanguage} />
        </div>
      </header>

      <Card>
        <CardHeader>
          <CardTitle>{d.home.backend}</CardTitle>
        </CardHeader>
        <CardContent>
          <Suspense fallback={<Badge variant="outline">{d.home.backendChecking}</Badge>}>
            <BackendStatus labels={d.home} locale={locale} />
          </Suspense>
        </CardContent>
      </Card>

      <section className="flex flex-col gap-3">
        <h2 className="text-lg font-medium">{d.home.queues}</h2>
        <ul className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
          {queueKeys.map((key) => (
            <li key={key}>
              <Card>
                <CardContent className="flex items-center justify-between gap-3">
                  <span>{d.home.queue[key]}</span>
                  <Badge variant="secondary">{d.home.comingSoon}</Badge>
                </CardContent>
              </Card>
            </li>
          ))}
        </ul>
      </section>
    </main>
  );
}
