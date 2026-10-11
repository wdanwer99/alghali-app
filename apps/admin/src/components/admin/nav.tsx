'use client';

import { Dialog } from '@base-ui/react/dialog';
import {
  Banknote,
  BookOpen,
  CalendarClock,
  Landmark,
  LayoutDashboard,
  LogOut,
  Menu,
  MessageSquareWarning,
  ReceiptText,
  Settings,
  UserPlus,
  Wallet,
  X,
} from 'lucide-react';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { useState, type ComponentType } from 'react';
import { cn } from 'cn';
import { LOCALE_COOKIE, type Locale } from '@/i18n/config';
import type { Dictionary } from '@/i18n/dictionaries';
import { Mark } from './ui';

type NavLabels = Dictionary['nav'];

type Item = {
  href: string;
  label: string;
  icon: ComponentType<{ className?: string }>;
  badge?: number;
};

function groups(
  locale: Locale,
  d: NavLabels,
  badges: { payments: number; approvals: number; disputes: number },
) {
  const p = (path: string) => `/${locale}${path}`;
  return [
    { title: null, items: [{ href: p(''), label: d.overview, icon: LayoutDashboard }] },
    {
      title: d.operations,
      items: [
        { href: p('/payments'), label: d.payments, icon: Landmark, badge: badges.payments },
        { href: p('/orders'), label: d.orders, icon: ReceiptText },
        { href: p('/bookings'), label: d.bookings, icon: CalendarClock },
        { href: p('/cash'), label: d.cash, icon: Banknote },
        {
          href: p('/disputes'),
          label: d.disputes,
          icon: MessageSquareWarning,
          badge: badges.disputes,
        },
      ],
    },
    {
      title: d.partners,
      items: [
        { href: p('/approvals'), label: d.approvals, icon: UserPlus, badge: badges.approvals },
        { href: p('/payouts'), label: d.payouts, icon: Wallet },
      ],
    },
    {
      title: d.platform,
      items: [
        { href: p('/catalogue'), label: d.catalogue, icon: BookOpen },
        { href: p('/settings'), label: d.settings, icon: Settings },
      ],
    },
  ] satisfies { title: string | null; items: Item[] }[];
}

function NavList({
  locale,
  d,
  badges,
  onNavigate,
}: {
  locale: Locale;
  d: NavLabels;
  badges: { payments: number; approvals: number; disputes: number };
  onNavigate?: () => void;
}) {
  const pathname = usePathname();
  const home = `/${locale}`;
  return (
    <nav aria-label={d.menu} className="flex flex-col gap-5">
      {groups(locale, d, badges).map((g) => (
        <div key={g.title ?? 'top'} className="flex flex-col gap-1">
          {g.title && (
            <div className="px-3 pb-1 text-xs font-semibold text-sidebar-muted">{g.title}</div>
          )}
          {g.items.map((item: Item) => {
            const active = item.href === home ? pathname === home : pathname.startsWith(item.href);
            const Icon = item.icon;
            return (
              <Link
                key={item.href}
                href={item.href}
                onClick={onNavigate}
                aria-current={active ? 'page' : undefined}
                className={cn(
                  'relative flex h-10 items-center gap-3 rounded-lg px-3 text-sm font-medium transition-colors',
                  'focus-visible:ring-2 focus-visible:ring-sidebar-ring focus-visible:outline-none',
                  active
                    ? 'bg-sidebar-accent text-sidebar-accent-foreground'
                    : 'text-sidebar-foreground/80 hover:bg-sidebar-accent/60 hover:text-sidebar-accent-foreground',
                )}
              >
                {active && (
                  <span
                    className="absolute inset-y-2 start-0 w-1 rounded-full bg-sidebar-primary"
                    aria-hidden
                  />
                )}
                <Icon className="size-4.5 shrink-0" />
                <span className="flex-1 truncate">{item.label}</span>
                {item.badge ? (
                  <span className="min-w-5 rounded-full bg-sidebar-primary px-1.5 text-center text-xs leading-5 font-bold text-sidebar-primary-foreground tabular-nums">
                    {item.badge}
                  </span>
                ) : null}
              </Link>
            );
          })}
        </div>
      ))}
    </nav>
  );
}

function Brand({ title }: { title: string }) {
  return (
    <div className="flex items-center gap-3 px-1">
      <Mark size={36} />
      <div className="min-w-0 leading-tight">
        <div className="truncate text-base font-bold text-sidebar-foreground">{title}</div>
      </div>
    </div>
  );
}

function Footer({ locale, d }: { locale: Locale; d: NavLabels }) {
  const pathname = usePathname();
  const target: Locale = locale === 'ar' ? 'en' : 'ar';
  return (
    <div className="mt-auto flex flex-col gap-3 border-t border-sidebar-border pt-4">
      <div className="flex items-center gap-3 px-1">
        <div className="grid size-9 place-items-center rounded-full bg-sidebar-accent text-sm font-bold text-sidebar-foreground">
          {d.adminName.slice(0, 1)}
        </div>
        <div className="min-w-0 leading-tight">
          <div className="truncate text-sm font-semibold text-sidebar-foreground">
            {d.adminName}
          </div>
          <div className="truncate text-xs text-sidebar-muted" dir="ltr">
            {d.adminEmail}
          </div>
        </div>
      </div>
      <div className="flex gap-2">
        <Link
          href={pathname.replace(/^\/(ar|en)(?=\/|$)/, `/${target}`)}
          lang={target}
          onClick={() => {
            document.cookie = `${LOCALE_COOKIE}=${target}; path=/; max-age=31536000; samesite=lax`;
          }}
          className="flex h-9 flex-1 items-center justify-center rounded-lg border border-sidebar-border text-sm text-sidebar-foreground hover:bg-sidebar-accent"
        >
          {d.switchLanguage}
        </Link>
        <Link
          href={`/${locale}/login`}
          aria-label={d.signOut}
          title={d.signOut}
          className="grid size-9 place-items-center rounded-lg border border-sidebar-border text-sidebar-foreground hover:bg-sidebar-accent"
        >
          <LogOut className="size-4 rtl:-scale-x-100" />
        </Link>
      </div>
    </div>
  );
}

/** Fixed sidebar on large screens; a top bar with a slide-in menu below `lg`. */
export function AdminNav({
  locale,
  d,
  title,
  badges,
}: {
  locale: Locale;
  d: NavLabels;
  title: string;
  badges: { payments: number; approvals: number; disputes: number };
}) {
  const [open, setOpen] = useState(false);
  return (
    <>
      <aside className="fixed inset-y-0 start-0 z-30 hidden w-64 flex-col gap-6 overflow-y-auto bg-sidebar p-4 lg:flex">
        <Brand title={title} />
        <NavList locale={locale} d={d} badges={badges} />
        <Footer locale={locale} d={d} />
      </aside>

      <div className="sticky top-0 z-30 flex h-14 items-center gap-3 bg-sidebar px-4 lg:hidden">
        <Dialog.Root open={open} onOpenChange={setOpen}>
          <Dialog.Trigger
            aria-label={d.menu}
            className="grid size-10 place-items-center rounded-lg text-sidebar-foreground hover:bg-sidebar-accent focus-visible:ring-2 focus-visible:ring-sidebar-ring focus-visible:outline-none"
          >
            <Menu className="size-5" />
          </Dialog.Trigger>
          <Dialog.Portal>
            <Dialog.Backdrop className="fixed inset-0 z-40 bg-black/50 transition-opacity data-[ending-style]:opacity-0 data-[starting-style]:opacity-0" />
            <Dialog.Popup className="fixed inset-y-0 start-0 z-50 flex w-72 max-w-[85vw] flex-col gap-6 overflow-y-auto bg-sidebar p-4 transition-transform data-[ending-style]:-translate-x-full data-[starting-style]:-translate-x-full rtl:data-[ending-style]:translate-x-full rtl:data-[starting-style]:translate-x-full">
              <div className="flex items-center justify-between">
                <Dialog.Title className="sr-only">{d.menu}</Dialog.Title>
                <Brand title={title} />
                <Dialog.Close
                  aria-label={d.close}
                  className="grid size-10 place-items-center rounded-lg text-sidebar-foreground hover:bg-sidebar-accent"
                >
                  <X className="size-5" />
                </Dialog.Close>
              </div>
              <NavList locale={locale} d={d} badges={badges} onNavigate={() => setOpen(false)} />
              <Footer locale={locale} d={d} />
            </Dialog.Popup>
          </Dialog.Portal>
        </Dialog.Root>
        <Brand title={title} />
      </div>
    </>
  );
}
