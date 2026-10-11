import {
  Banknote,
  CalendarClock,
  Landmark,
  MessageSquareWarning,
  ReceiptText,
  TrendingUp,
  UserPlus,
} from 'lucide-react';
import Link from 'next/link';
import { Suspense } from 'react';
import { BackendStatus } from '@/components/backend-status';
import { OrdersChart } from '@/components/admin/orders-chart';
import { DemoBadge, PageHeader, Panel, StatCard, StatusBadge } from '@/components/admin/ui';
import { dirOf } from '@/i18n/config';
import { getDictionary, getLocale } from '@/i18n/dictionaries';
import {
  activity,
  applications,
  cashRows,
  dailyOrders,
  DEMO_NOW,
  disputes,
  receipts,
  today,
  tr,
} from '@/lib/demo/data';
import { ago, dateTime, dayNumber, digits, fill, money, weekdayDate } from '@/lib/format';

const activityIcon = {
  payment: Landmark,
  order: ReceiptText,
  booking: CalendarClock,
  partner: UserPlus,
  dispute: MessageSquareWarning,
};

export default async function OverviewPage() {
  const [d, locale] = await Promise.all([getDictionary(), getLocale()]);
  const oldest = receipts.reduce((a, b) => (a.submittedAt < b.submittedAt ? a : b));
  const oldestAge = ago(oldest.submittedAt, DEMO_NOW, d.common);
  const openDisputes = disputes.filter((x) => x.status !== 'resolved').length;
  const owed = cashRows.reduce((s, r) => s + r.owedSdg, 0);
  const totalOrders = dailyOrders.reduce((s, x) => s + x.orders, 0);

  const queues: {
    href: string;
    icon: typeof Landmark;
    label: string;
    value: string;
    note?: string;
  }[] = [
    {
      href: `/${locale}/payments`,
      icon: Landmark,
      label: d.overview.queuePayments,
      value: digits(receipts.length),
      note: fill(d.overview.oldest, { age: oldestAge }),
    },
    {
      href: `/${locale}/approvals`,
      icon: UserPlus,
      label: d.overview.queueApprovals,
      value: digits(applications.length),
    },
    {
      href: `/${locale}/disputes`,
      icon: MessageSquareWarning,
      label: d.overview.queueDisputes,
      value: digits(openDisputes),
    },
    {
      href: `/${locale}/cash`,
      icon: Banknote,
      label: d.overview.queueCash,
      value: money(owed, d.common.currency),
    },
  ];

  return (
    <>
      <PageHeader
        title={d.overview.title}
        description={`${d.overview.subtitle} · ${dateTime(DEMO_NOW, locale)}`}
        actions={<DemoBadge label={d.app.demo} note={d.app.demoNote} />}
      />

      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 xl:grid-cols-4">
        <StatCard
          label={d.overview.kpiSales}
          value={money(today.salesSdg, d.common.currency)}
          icon={<TrendingUp />}
          tone="success"
        />
        <StatCard
          label={d.overview.kpiOrders}
          value={digits(today.orders)}
          icon={<ReceiptText />}
        />
        <StatCard
          label={d.overview.kpiBookings}
          value={digits(today.bookings)}
          icon={<CalendarClock />}
        />
        <StatCard
          label={d.overview.kpiWaiting}
          value={digits(receipts.length)}
          note={fill(d.overview.oldest, { age: oldestAge })}
          tone="warning"
          icon={<Landmark />}
        />
      </div>

      <div className="grid grid-cols-1 gap-6 lg:grid-cols-3">
        <div className="lg:col-span-2">
          <OrdersChart
            rtl={dirOf(locale) === 'rtl'}
            data={dailyOrders.map((x) => ({
              key: x.day.toISOString(),
              short: dayNumber(x.day),
              full: weekdayDate(x.day, locale),
              orders: x.orders,
            }))}
            labels={{
              title: d.overview.ordersChart,
              total: fill(d.overview.ordersChartTotal, { n: digits(totalOrders) }),
              showTable: d.common.showTable,
              showChart: d.common.showChart,
              day: d.overview.chartDay,
              orders: d.overview.chartOrders,
            }}
          />
        </div>
        <Panel title={d.overview.attention}>
          <ul className="divide-y">
            {queues.map((q) => (
              <li key={q.href}>
                <Link
                  href={q.href}
                  className="flex items-center gap-3 px-4 py-3 transition-colors hover:bg-muted/60 focus-visible:bg-muted focus-visible:outline-none"
                >
                  <span className="grid size-9 shrink-0 place-items-center rounded-lg bg-muted">
                    <q.icon className="size-4.5" />
                  </span>
                  <span className="min-w-0 flex-1">
                    <span className="block truncate text-sm font-medium">{q.label}</span>
                    {q.note && <span className="block text-xs text-warning">{q.note}</span>}
                  </span>
                  <span className="text-base font-bold whitespace-nowrap">{q.value}</span>
                </Link>
              </li>
            ))}
          </ul>
        </Panel>
      </div>

      <div className="grid grid-cols-1 gap-6 lg:grid-cols-3">
        <Panel title={d.overview.activity} className="lg:col-span-2">
          <ul className="divide-y">
            {activity.map((a) => {
              const Icon = activityIcon[a.kind];
              return (
                <li key={a.id} className="flex items-start gap-3 px-4 py-3">
                  <Icon className="mt-0.5 size-4.5 shrink-0 text-muted-foreground" />
                  <span className="flex-1 text-sm">{tr(a.text, locale)}</span>
                  <span className="text-xs whitespace-nowrap text-muted-foreground">
                    {ago(a.at, DEMO_NOW, d.common)}
                  </span>
                </li>
              );
            })}
          </ul>
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
