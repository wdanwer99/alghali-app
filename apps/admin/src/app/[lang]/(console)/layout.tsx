import type { ReactNode } from 'react';
import { AdminNav } from '@/components/admin/nav';
import { getDictionary, getLocale } from '@/i18n/dictionaries';
import { applications, disputes, receipts } from '@/lib/demo/data';

/** The signed-in console: sidebar (or top bar on small screens) + content. */
export default async function ConsoleLayout({ children }: { children: ReactNode }) {
  const [d, locale] = await Promise.all([getDictionary(), getLocale()]);
  return (
    <div className="flex min-h-full flex-1 flex-col">
      <a
        href="#main"
        className="sr-only z-50 rounded-md bg-card px-3 py-2 focus:not-sr-only focus:absolute focus:start-2 focus:top-2"
      >
        {d.nav.skipToContent}
      </a>
      <AdminNav
        locale={locale}
        d={d.nav}
        title={d.app.console}
        badges={{
          payments: receipts.length,
          approvals: applications.length,
          disputes: disputes.filter((x) => x.status !== 'resolved').length,
        }}
      />
      <main id="main" className="flex-1 lg:ps-64">
        <div className="mx-auto flex w-full max-w-7xl flex-col gap-6 p-4 sm:p-6 lg:p-8">
          {children}
        </div>
      </main>
    </div>
  );
}
