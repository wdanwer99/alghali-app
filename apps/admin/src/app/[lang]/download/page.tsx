import type { Metadata } from 'next';
import { connection } from 'next/server';
import { Suspense } from 'react';
import { Mark } from '@/components/admin/ui';
import { DownloadButton } from '@/components/download-button';
import { LanguageSwitch } from '@/components/language-switch';
import { getDictionary, getLocale } from '@/i18n/dictionaries';
import { getAnonClient } from '@/lib/supabase/server';

/**
 * The public page people install the Android apps from (D-058): no sign-in. The files and
 * versions come from latest_app_versions, which `pnpm release:apk` keeps current.
 */
type Release = { latest_build: number; apk_url: string | null };
type Dict = Awaited<ReturnType<typeof getDictionary>>['download'];

export async function generateMetadata(): Promise<Metadata> {
  const d = await getDictionary();
  return { title: d.download.title, description: d.download.subtitle };
}

export default async function DownloadPage() {
  const [dict, locale] = await Promise.all([getDictionary(), getLocale()]);
  const d = dict.download;
  return (
    <main className="mx-auto flex w-full max-w-xl flex-1 flex-col gap-6 px-4 py-10">
      <header className="rise flex flex-col items-center gap-3 text-center">
        <Mark size={56} />
        <div>
          <h1 className="text-2xl font-bold">{d.title}</h1>
          <p className="mt-1 text-sm text-muted-foreground">{d.subtitle}</p>
        </div>
      </header>
      <Suspense fallback={<AppCards d={d} releases={null} />}>
        <Apps d={d} />
      </Suspense>
      <section className="rounded-2xl bg-card p-5 ring-1 ring-foreground/10">
        <h2 className="font-semibold">{d.stepsTitle}</h2>
        <ol className="mt-3 list-decimal space-y-2 ps-5 text-sm text-muted-foreground">
          <li>{d.step1}</li>
          <li>{d.step2}</li>
          <li>{d.step3}</li>
          <li>{d.step4}</li>
        </ol>
      </section>
      <p className="text-center text-xs text-muted-foreground">{d.safety}</p>
      <div className="flex justify-center">
        <LanguageSwitch current={locale} label={dict.nav.switchLanguage} />
      </div>
    </main>
  );
}

async function Apps({ d }: { d: Dict }) {
  await connection();
  const supabase = getAnonClient();
  const { data } = supabase ? await supabase.rpc('public_settings') : { data: null };
  const releases =
    (data as { latest_app_versions?: Record<string, Release> } | null)?.latest_app_versions ?? {};
  return <AppCards d={d} releases={releases} />;
}

/** One card per app; while loading ([releases] null) the buttons wait. */
function AppCards({ d, releases }: { d: Dict; releases: Record<string, Release> | null }) {
  const apps = [
    { key: 'buyer', title: d.buyerTitle, body: d.buyerBody },
    { key: 'partner', title: d.partnerTitle, body: d.partnerBody },
  ];
  return (
    <div className="grid gap-4" aria-busy={releases === null}>
      {apps.map((app) => {
        const release = releases?.[app.key];
        return (
          <section
            key={app.key}
            className="rounded-2xl bg-card p-5 shadow-sm ring-1 ring-foreground/10"
            aria-labelledby={`app-${app.key}`}
          >
            <h2 id={`app-${app.key}`} className="text-lg font-semibold">
              {app.title}
            </h2>
            <p className="mt-1 text-sm text-muted-foreground">{app.body}</p>
            <div className="mt-4">
              {releases === null ? (
                <div className="h-10 animate-pulse rounded-lg bg-muted" />
              ) : release?.apk_url ? (
                <>
                  <DownloadButton apkUrl={release.apk_url} label={d.download} other={d.other} />
                  <p className="mt-2 text-center text-xs text-muted-foreground">
                    {d.version.replace('{build}', String(release.latest_build))}
                  </p>
                </>
              ) : (
                <p className="rounded-lg bg-muted px-3 py-2 text-center text-sm">{d.soon}</p>
              )}
            </div>
          </section>
        );
      })}
    </div>
  );
}
