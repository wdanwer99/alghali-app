import {
  BadgeCheck,
  Banknote,
  BookOpen,
  ChevronLeft,
  ChevronRight,
  GitMerge,
  KeyRound,
  Landmark,
  MapPinned,
  MessageSquareWarning,
  Package,
  PackageSearch,
  Settings,
  ShieldCheck,
  Store,
  UserCog,
  UserPlus,
  Users,
  type LucideIcon,
} from 'lucide-react';
import Link from 'next/link';
import { Suspense } from 'react';
import { BackendStatus } from '@/components/backend-status';
import { CategoryBars } from '@/components/admin/category-bars';
import { AnimatedNumber } from '@/components/motion';
import {
  EmptyState,
  LiveDot,
  PageHeader,
  PageSkeleton,
  Panel,
  riseStyle,
  SampleTag,
  StatCard,
  StatusBadge,
} from '@/components/admin/ui';
import type { Locale } from '@/i18n/config';
import { getDictionary, getLocale, type Dictionary } from '@/i18n/dictionaries';
import { requireAdmin } from '@/lib/auth';
import { cashRows, disputes, receipts } from '@/lib/demo/data';
import { loadOverview, type Activity } from '@/lib/data/overview';
import { named } from '@/lib/data/util';
import { ago, digits, fill, money } from '@/lib/format';

export default async function OverviewPage() {
  const [d, locale] = await Promise.all([getDictionary(), getLocale()]);
  return (
    <>
      <PageHeader
        title={d.overview.title}
        description={d.overview.subtitle}
        actions={<LiveDot label={d.app.live} />}
      />
      <Suspense fallback={<PageSkeleton rows={5} />}>
        <Overview d={d} locale={locale} />
      </Suspense>
    </>
  );
}

async function Overview({ d, locale }: { d: Dictionary; locale: Locale }) {
  const { supabase } = await requireAdmin();
  const o = await loadOverview(supabase);
  const now = new Date();
  const t = d.overview;
  const p = (path: string) => `/${locale}${path}`;
  const Chevron = locale === 'ar' ? ChevronLeft : ChevronRight;
  const totalListings = o.byCategory.reduce((s, c) => s + c.listings, 0);

  const queues: {
    href: string;
    icon: LucideIcon;
    label: string;
    value: string;
    note?: string;
    sample?: boolean;
  }[] = [
    {
      href: p('/approvals'),
      icon: UserPlus,
      label: t.queueApprovals,
      value: digits(o.shops.pending),
      note: o.oldestPendingAt
        ? fill(t.kpiPendingNote, { age: ago(new Date(o.oldestPendingAt), now, d.common) })
        : undefined,
    },
    {
      href: p('/catalogue?tab=shop-parts'),
      icon: PackageSearch,
      label: t.queueShopParts,
      value: digits(o.shopParts),
    },
    {
      href: p('/catalogue?tab=gaps'),
      icon: BookOpen,
      label: t.queueGaps,
      value: digits(o.listedWithoutFitment),
    },
    {
      href: p('/payments'),
      icon: Landmark,
      label: t.queuePayments,
      value: digits(receipts.length),
      sample: true,
    },
    {
      href: p('/disputes'),
      icon: MessageSquareWarning,
      label: t.queueDisputes,
      value: digits(disputes.filter((x) => x.status !== 'resolved').length),
      sample: true,
    },
    {
      href: p('/cash'),
      icon: Banknote,
      label: t.queueCash,
      value: money(
        cashRows.reduce((s, r) => s + r.owedSdg, 0),
        d.common.currency,
      ),
      sample: true,
    },
  ];

  return (
    <>
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 xl:grid-cols-4">
        <StatCard
          index={0}
          href={p('/shops')}
          label={t.kpiShops}
          value={<AnimatedNumber value={o.shops.approved} />}
          note={fill(t.kpiShopsNote, { n: digits(o.shops.verified) })}
          icon={<Store />}
          tone="success"
        />
        <StatCard
          index={1}
          href={p('/approvals')}
          label={t.kpiPending}
          value={<AnimatedNumber value={o.shops.pending} />}
          note={
            o.oldestPendingAt
              ? fill(t.kpiPendingNote, { age: ago(new Date(o.oldestPendingAt), now, d.common) })
              : t.kpiPendingNone
          }
          icon={<UserPlus />}
          tone={o.shops.pending > 0 ? 'warning' : undefined}
        />
        <StatCard
          index={2}
          href={p('/catalogue')}
          label={t.kpiListings}
          value={<AnimatedNumber value={o.listings} />}
          note={fill(t.kpiListingsNote, { n: digits(o.parts) })}
          icon={<Package />}
          tone="info"
        />
        <StatCard
          index={3}
          label={t.kpiAccounts}
          value={<AnimatedNumber value={o.accounts} />}
          note={fill(t.kpiAccountsNote, { n: digits(o.shopOwners) })}
          icon={<Users />}
        />
      </div>

      <div className="grid grid-cols-1 gap-6 lg:grid-cols-3">
        <Panel
          title={t.byCategory}
          actions={
            <span className="text-sm text-muted-foreground">
              {fill(t.byCategoryTotal, { n: digits(totalListings) })}
            </span>
          }
          className="lg:col-span-2"
        >
          <CategoryBars
            label={t.byCategory}
            rows={o.byCategory.map((c) => ({
              id: c.id,
              label: named(c.name, locale),
              value: c.listings,
              note: fill(t.partsInCategory, { n: digits(c.parts) }),
            }))}
          />
        </Panel>
        <Panel title={t.attention}>
          <ul className="divide-y">
            {queues.map((q, i) => (
              <li key={q.href} className="rise" style={riseStyle(i)}>
                <Link
                  href={q.href}
                  className="group flex items-center gap-3 px-4 py-3 transition-colors hover:bg-muted/60 focus-visible:bg-muted focus-visible:outline-none"
                >
                  <span className="grid size-9 shrink-0 place-items-center rounded-lg bg-muted transition-colors group-hover:bg-background">
                    <q.icon className="size-4.5" />
                  </span>
                  <span className="min-w-0 flex-1">
                    <span className="flex items-center gap-2">
                      <span className="truncate text-sm font-medium">{q.label}</span>
                      {q.sample && (
                        <SampleTag label={d.app.sampleTag} className="text-muted-foreground" />
                      )}
                    </span>
                    {q.note && <span className="block text-xs text-warning">{q.note}</span>}
                  </span>
                  <span className="text-base font-bold whitespace-nowrap tabular-nums">
                    {q.value}
                  </span>
                  <Chevron className="size-4 text-muted-foreground transition-transform group-hover:translate-x-0.5 rtl:group-hover:-translate-x-0.5" />
                </Link>
              </li>
            ))}
          </ul>
        </Panel>
      </div>

      <div className="grid grid-cols-1 gap-6 lg:grid-cols-3">
        <Panel title={t.activity} className="lg:col-span-2">
          {o.activity.length === 0 ? (
            <EmptyState icon={<BookOpen />} title={t.activityEmpty} />
          ) : (
            <ol className="relative px-4 py-2">
              {o.activity.map((a, i) => {
                const { icon: Icon, text } = describe(a, d.activity, locale);
                return (
                  <li key={a.id} className="rise relative flex gap-3 py-2.5" style={riseStyle(i)}>
                    {/* Timeline rail between the icons. */}
                    {i < o.activity.length - 1 && (
                      <span
                        aria-hidden
                        className="absolute start-[17px] top-11 bottom-0 w-px bg-border"
                      />
                    )}
                    <span className="relative grid size-9 shrink-0 place-items-center rounded-full bg-muted">
                      <Icon className="size-4 text-muted-foreground" />
                    </span>
                    <span className="flex-1 pt-2 text-sm">{text}</span>
                    <time
                      dateTime={a.at}
                      className="pt-2 text-xs whitespace-nowrap text-muted-foreground"
                    >
                      {ago(new Date(a.at), now, d.common)}
                    </time>
                  </li>
                );
              })}
            </ol>
          )}
        </Panel>
        <Panel title={d.system.backend}>
          <div className="p-4">
            <Suspense fallback={<StatusBadge>{d.system.backendChecking}</StatusBadge>}>
              <BackendStatus labels={d.system} locale={locale} />
            </Suspense>
          </div>
        </Panel>
      </div>
    </>
  );
}

/** Turns an audit-log row into an icon and a sentence. */
function describe(
  a: Activity,
  t: Dictionary['activity'],
  locale: Locale,
): { icon: LucideIcon; text: string } {
  const values = {
    actor: a.actor ?? t.someone,
    shop: a.shop ? named(a.shop, locale) : t.aShop,
    key: a.detail ?? '',
  };
  const say = (key: keyof Dictionary['activity'], icon: LucideIcon) => ({
    icon,
    text: fill(t[key], values),
  });
  switch (a.action) {
    case 'APPLY':
      return say('APPLY', UserPlus);
    case 'SET_STATUS':
      return say(
        a.detail === 'APPROVED' ? 'APPROVED' : a.detail === 'REJECTED' ? 'REJECTED' : 'SUSPENDED',
        ShieldCheck,
      );
    case 'VERIFY':
      return say(a.detail === 'true' ? 'VERIFY_ON' : 'VERIFY_OFF', BadgeCheck);
    case 'ADD_STAFF':
    case 'REMOVE_STAFF':
      return say('STAFF', Users);
    case 'UPDATE_SETTING':
      return say('SETTING', Settings);
    case 'GRANT_ROLE':
    case 'REVOKE_ROLE':
      return say('ROLE', UserCog);
    case 'MERGE':
      return say('MERGE', GitMerge);
    case 'SET_PASSWORD':
      return say('PASSWORD', KeyRound);
    default:
      if (a.entity === 'shop') return say('UPDATE_SHOP', Store);
      if (['markets', 'streets', 'zones'].includes(a.entity)) return say('STREET', MapPinned);
      return say('CATALOGUE', BookOpen);
  }
}
