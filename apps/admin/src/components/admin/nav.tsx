'use client';

import { Dialog } from '@base-ui/react/dialog';
import {
  Banknote,
  BarChart3,
  BellRing,
  BookOpen,
  CalendarClock,
  Landmark,
  LayoutDashboard,
  LogOut,
  MapPinned,
  Menu,
  MessageSquareWarning,
  ReceiptText,
  Search,
  Settings,
  Store,
  UserPlus,
  Users,
  Wallet,
  X,
} from 'lucide-react';
import { AnimatePresence, LayoutGroup, motion } from 'motion/react';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { useState, type ComponentType } from 'react';
import { cn } from 'cn';
import { LOCALE_COOKIE, type Locale } from '@/i18n/config';
import type { Dictionary } from '@/i18n/dictionaries';
import { signOut } from '@/lib/actions/auth';
import { CommandPalette } from './command-palette';
import { Mark, SampleTag } from './ui';

type NavLabels = Dictionary['nav'];
export type NavAdmin = { name: string; email: string };
export type NavBadges = { approvals: number };

export type NavItem = {
  href: string;
  label: string;
  icon: ComponentType<{ className?: string }>;
  badge?: number;
  /** Still on sample data until its milestone is built. */
  sample?: boolean;
};

export function navGroups(locale: Locale, d: NavLabels, badges: NavBadges | null) {
  const p = (path: string) => `/${locale}${path}`;
  return [
    {
      title: null,
      items: [
        { href: p(''), label: d.overview, icon: LayoutDashboard },
        { href: p('/reports'), label: d.reports, icon: BarChart3 },
      ],
    },
    {
      title: d.partners,
      items: [
        { href: p('/approvals'), label: d.approvals, icon: UserPlus, badge: badges?.approvals },
        { href: p('/shops'), label: d.shops, icon: Store },
        { href: p('/payouts'), label: d.payouts, icon: Wallet },
      ],
    },
    {
      title: d.platform,
      items: [
        { href: p('/users'), label: d.users, icon: Users },
        { href: p('/catalogue'), label: d.catalogue, icon: BookOpen },
        { href: p('/street'), label: d.street, icon: MapPinned },
        { href: p('/alerts'), label: d.alerts, icon: BellRing },
        { href: p('/settings'), label: d.settings, icon: Settings },
      ],
    },
    {
      title: d.operations,
      items: [
        { href: p('/payments'), label: d.payments, icon: Landmark },
        { href: p('/orders'), label: d.orders, icon: ReceiptText },
        { href: p('/bookings'), label: d.bookings, icon: CalendarClock },
        { href: p('/cash'), label: d.cash, icon: Banknote },
        { href: p('/disputes'), label: d.disputes, icon: MessageSquareWarning },
      ],
    },
  ] satisfies { title: string | null; items: NavItem[] }[];
}

function NavList({
  locale,
  d,
  sampleTag,
  badges,
  onNavigate,
}: {
  locale: Locale;
  d: NavLabels;
  sampleTag: string;
  badges: NavBadges | null;
  onNavigate?: () => void;
}) {
  const pathname = usePathname();
  const home = `/${locale}`;
  return (
    <nav aria-label={d.menu} className="flex flex-col gap-5">
      {navGroups(locale, d, badges).map((g) => (
        <div key={g.title ?? 'top'} className="flex flex-col gap-0.5">
          {g.title && (
            <div className="px-3 pb-1 text-xs font-semibold text-sidebar-muted">{g.title}</div>
          )}
          {g.items.map((item: NavItem) => {
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
                    ? 'text-sidebar-accent-foreground'
                    : 'text-sidebar-foreground/75 hover:bg-sidebar-accent/50 hover:text-sidebar-accent-foreground',
                )}
              >
                {active && (
                  // One highlight that glides from the old page to the new one.
                  <motion.span
                    layoutId="nav-active"
                    aria-hidden
                    className="absolute inset-0 rounded-lg bg-sidebar-accent"
                    transition={{ type: 'spring', stiffness: 500, damping: 40 }}
                  >
                    <span className="absolute inset-y-2 start-0 w-1 rounded-full bg-sidebar-primary" />
                  </motion.span>
                )}
                <Icon className="relative size-4.5 shrink-0" />
                <span className="relative flex-1 truncate">{item.label}</span>
                {item.sample && (
                  <SampleTag label={sampleTag} className="relative text-sidebar-muted" />
                )}
                <AnimatePresence>
                  {item.badge ? (
                    <motion.span
                      key={item.badge}
                      initial={{ scale: 0.5, opacity: 0 }}
                      animate={{ scale: 1, opacity: 1 }}
                      exit={{ scale: 0.5, opacity: 0 }}
                      transition={{ type: 'spring', stiffness: 600, damping: 25 }}
                      className="relative min-w-5 rounded-full bg-sidebar-primary px-1.5 text-center text-xs leading-5 font-bold text-sidebar-primary-foreground tabular-nums"
                    >
                      {item.badge}
                    </motion.span>
                  ) : null}
                </AnimatePresence>
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

function Footer({ locale, d, admin }: { locale: Locale; d: NavLabels; admin: NavAdmin | null }) {
  const pathname = usePathname();
  const target: Locale = locale === 'ar' ? 'en' : 'ar';
  return (
    <div className="mt-auto flex flex-col gap-3 border-t border-sidebar-border pt-4">
      <div className="flex items-center gap-3 px-1">
        <div className="grid size-9 shrink-0 place-items-center rounded-full bg-sidebar-accent text-sm font-bold text-sidebar-foreground uppercase">
          {admin ? admin.name.slice(0, 1) : ''}
        </div>
        <div className="min-w-0 flex-1 leading-tight">
          {admin ? (
            <>
              <div className="truncate text-sm font-semibold text-sidebar-foreground">
                {admin.name}
              </div>
              <div className="truncate text-xs text-sidebar-muted" dir="ltr">
                {admin.email}
              </div>
            </>
          ) : (
            <div aria-hidden className="flex flex-col gap-1.5">
              <div className="h-3 w-24 animate-pulse rounded bg-sidebar-accent" />
              <div className="h-2.5 w-32 animate-pulse rounded bg-sidebar-accent" />
            </div>
          )}
        </div>
      </div>
      <div className="flex gap-2">
        <Link
          href={pathname.replace(/^\/(ar|en)(?=\/|$)/, `/${target}`)}
          lang={target}
          onClick={() => {
            document.cookie = `${LOCALE_COOKIE}=${target}; path=/; max-age=31536000; samesite=lax`;
          }}
          className="flex h-9 flex-1 items-center justify-center rounded-lg border border-sidebar-border text-sm text-sidebar-foreground transition-colors hover:bg-sidebar-accent"
        >
          {d.switchLanguage}
        </Link>
        <form action={signOut}>
          <input type="hidden" name="locale" value={locale} />
          <button
            type="submit"
            aria-label={d.signOut}
            title={d.signOut}
            className="grid size-9 cursor-pointer place-items-center rounded-lg border border-sidebar-border text-sidebar-foreground transition-colors hover:bg-sidebar-accent focus-visible:ring-2 focus-visible:ring-sidebar-ring focus-visible:outline-none"
          >
            <LogOut className="size-4 rtl:-scale-x-100" />
          </button>
        </form>
      </div>
    </div>
  );
}

function JumpButton({ label, onOpen }: { label: string; onOpen: () => void }) {
  return (
    <button
      type="button"
      onClick={onOpen}
      className="flex h-9 w-full cursor-pointer items-center gap-2 rounded-lg border border-sidebar-border px-3 text-sm text-sidebar-muted transition-colors hover:bg-sidebar-accent hover:text-sidebar-foreground focus-visible:ring-2 focus-visible:ring-sidebar-ring focus-visible:outline-none"
    >
      <Search className="size-4" />
      <span className="flex-1 text-start">{label}</span>
      <kbd className="rounded border border-sidebar-border px-1.5 font-sans text-[10px]" dir="ltr">
        Ctrl K
      </kbd>
    </button>
  );
}

/** Fixed sidebar on large screens; a top bar with a slide-in menu below `lg`. */
export function AdminNav({
  locale,
  d,
  title,
  sampleTag,
  admin,
  badges,
}: {
  locale: Locale;
  d: NavLabels;
  title: string;
  sampleTag: string;
  admin: NavAdmin | null;
  badges: NavBadges | null;
}) {
  const [open, setOpen] = useState(false);
  const [paletteOpen, setPaletteOpen] = useState(false);
  return (
    <>
      <aside className="fixed inset-y-0 start-0 z-30 hidden w-64 flex-col gap-5 overflow-y-auto bg-sidebar p-4 lg:flex">
        <Brand title={title} />
        <JumpButton label={d.jumpTo} onOpen={() => setPaletteOpen(true)} />
        <LayoutGroup id="desktop-nav">
          <NavList locale={locale} d={d} sampleTag={sampleTag} badges={badges} />
        </LayoutGroup>
        <Footer locale={locale} d={d} admin={admin} />
      </aside>

      <div className="sticky top-0 z-30 flex h-14 items-center gap-3 bg-sidebar px-4 lg:hidden">
        <Dialog.Root open={open} onOpenChange={setOpen}>
          <Dialog.Trigger
            aria-label={d.menu}
            className="grid size-10 cursor-pointer place-items-center rounded-lg text-sidebar-foreground hover:bg-sidebar-accent focus-visible:ring-2 focus-visible:ring-sidebar-ring focus-visible:outline-none"
          >
            <Menu className="size-5" />
          </Dialog.Trigger>
          <Dialog.Portal>
            <Dialog.Backdrop className="fixed inset-0 z-40 bg-black/50 transition-opacity duration-200 data-[ending-style]:opacity-0 data-[starting-style]:opacity-0" />
            <Dialog.Popup className="fixed inset-y-0 start-0 z-50 flex w-72 max-w-[85vw] flex-col gap-5 overflow-y-auto bg-sidebar p-4 transition-transform duration-300 ease-out-soft data-[ending-style]:-translate-x-full data-[starting-style]:-translate-x-full rtl:data-[ending-style]:translate-x-full rtl:data-[starting-style]:translate-x-full">
              <div className="flex items-center justify-between">
                <Dialog.Title className="sr-only">{d.menu}</Dialog.Title>
                <Brand title={title} />
                <Dialog.Close
                  aria-label={d.close}
                  className="grid size-10 cursor-pointer place-items-center rounded-lg text-sidebar-foreground hover:bg-sidebar-accent"
                >
                  <X className="size-5" />
                </Dialog.Close>
              </div>
              <LayoutGroup id="mobile-nav">
                <NavList
                  locale={locale}
                  d={d}
                  sampleTag={sampleTag}
                  badges={badges}
                  onNavigate={() => setOpen(false)}
                />
              </LayoutGroup>
              <Footer locale={locale} d={d} admin={admin} />
            </Dialog.Popup>
          </Dialog.Portal>
        </Dialog.Root>
        <Brand title={title} />
        <button
          type="button"
          onClick={() => setPaletteOpen(true)}
          aria-label={d.jumpTo}
          className="ms-auto grid size-10 cursor-pointer place-items-center rounded-lg text-sidebar-foreground hover:bg-sidebar-accent focus-visible:ring-2 focus-visible:ring-sidebar-ring focus-visible:outline-none"
        >
          <Search className="size-5" />
        </button>
      </div>

      <CommandPalette
        open={paletteOpen}
        onOpenChange={setPaletteOpen}
        locale={locale}
        d={d}
        sampleTag={sampleTag}
        groups={navGroups(locale, d, badges)}
      />
    </>
  );
}
