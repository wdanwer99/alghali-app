import { Suspense, type ComponentProps, type ReactNode } from 'react';
import { AdminNav } from '@/components/admin/nav';
import { getDictionary, getLocale } from '@/i18n/dictionaries';
import { requireAdmin } from '@/lib/auth';
import { countPendingShops } from '@/lib/data/shops';

type ShellProps = Omit<ComponentProps<typeof AdminNav>, 'admin' | 'badges'>;

/** The signed-in console: sidebar (or top bar on small screens) + content. */
export default async function ConsoleLayout({ children }: { children: ReactNode }) {
  const [d, locale] = await Promise.all([getDictionary(), getLocale()]);
  const shell: ShellProps = { locale, d: d.nav, title: d.app.console, sampleTag: d.app.sampleTag };
  return (
    <div className="flex min-h-full flex-1 flex-col">
      <a
        href="#main"
        className="sr-only z-50 rounded-md bg-card px-3 py-2 focus:not-sr-only focus:absolute focus:start-2 focus:top-2"
      >
        {d.nav.skipToContent}
      </a>
      {/* The session is read per request, so the signed-in parts stream in behind a boundary. */}
      <Suspense fallback={<AdminNav {...shell} admin={null} badges={null} />}>
        <SignedInNav {...shell} />
      </Suspense>
      <main id="main" className="flex-1 lg:ps-64">
        <div className="mx-auto w-full max-w-7xl p-4 sm:p-6 lg:p-8">{children}</div>
      </main>
    </div>
  );
}

async function SignedInNav(shell: ShellProps) {
  const { supabase, admin } = await requireAdmin();
  const [shops, technicians] = await Promise.all([
    countPendingShops(supabase),
    supabase
      .from('technicians')
      .select('id', { count: 'exact', head: true })
      .eq('status', 'PENDING'),
  ]);
  const approvals = shops + (technicians.count ?? 0);
  return (
    <AdminNav {...shell} admin={{ name: admin.name, email: admin.email }} badges={{ approvals }} />
  );
}
