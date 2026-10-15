import {
  CalendarClock,
  HandCoins,
  Landmark,
  Percent,
  ReceiptText,
  Undo2,
  UserPlus,
  Users,
} from 'lucide-react';
import Link from 'next/link';
import { Suspense } from 'react';
import { CategoryBars } from '@/components/admin/category-bars';
import { CsvButton, DailyChart } from '@/components/admin/report-charts';
import {
  EmptyState,
  Num,
  PageHeader,
  PageSkeleton,
  Panel,
  StatCard,
  Table,
  Td,
  Th,
} from '@/components/admin/ui';
import type { Locale } from '@/i18n/config';
import { getDictionary, getLocale, type Dictionary } from '@/i18n/dictionaries';
import { requireAdmin } from '@/lib/auth';
import { khartoumDate, loadReport } from '@/lib/data/reports';
import { named } from '@/lib/data/util';
import { digits, fill, money, shortDate } from '@/lib/format';
import { statusKey } from '@/lib/tones';

const PERIODS = [7, 30, 90] as const;

export default async function ReportsPage({ searchParams }: PageProps<'/[lang]/reports'>) {
  const [d, locale] = await Promise.all([getDictionary(), getLocale()]);
  return (
    <>
      <PageHeader title={d.reports.title} description={d.reports.subtitle} />
      <Suspense fallback={<PageSkeleton rows={6} />}>
        <Reports d={d} locale={locale} searchParams={searchParams} />
      </Suspense>
    </>
  );
}

async function Reports({
  d,
  locale,
  searchParams,
}: {
  d: Dictionary;
  locale: Locale;
  searchParams: PageProps<'/[lang]/reports'>['searchParams'];
}) {
  const [{ supabase }, { days }] = await Promise.all([requireAdmin(), searchParams]);
  const span = PERIODS.find((p) => String(p) === days) ?? 30;
  const now = new Date();
  const to = khartoumDate(now);
  const from = khartoumDate(now, -(span - 1));
  const r = await loadReport(supabase, from, to);
  const t = d.reports;
  const sdg = (n: number) => money(n, d.common.currency);
  const dayLabel = (day: string) => shortDate(new Date(`${day}T10:00:00Z`), locale);
  const cashShare = r.totals.orders ? Math.round((r.totals.cashOrders / r.totals.orders) * 100) : 0;
  const fittingRows = Object.entries(r.fittings)
    .map(([status, n]) => ({
      id: status,
      label: d.status.booking[statusKey(status) as keyof Dictionary['status']['booking']] ?? status,
      value: n,
      note: digits(n),
    }))
    .sort((a, b) => b.value - a.value);

  const csv: (string | number)[][] = [
    [t.colDay, t.colOrders, t.colSales, t.colCommission, t.colFittings],
    ...r.days.map((x) => [x.day, x.orders, x.salesSdg, x.commissionSdg, x.fittings]),
    [],
    [t.topShops, t.colOrders, t.colSales, t.colCommission],
    ...r.topShops.map((s) => [named(s.name, locale), s.orders, s.salesSdg, s.commissionSdg]),
  ];

  return (
    <>
      <div className="flex flex-wrap items-center justify-between gap-3">
        <nav aria-label={t.period} className="flex gap-1 rounded-lg bg-muted p-1">
          {PERIODS.map((p) => (
            <Link
              key={p}
              href={`/${locale}/reports?days=${p}`}
              aria-current={p === span ? 'page' : undefined}
              className={
                p === span
                  ? 'rounded-md bg-card px-3 py-1.5 text-sm font-semibold shadow-sm'
                  : 'rounded-md px-3 py-1.5 text-sm text-muted-foreground hover:text-foreground'
              }
            >
              {fill(t.lastDays, { n: digits(p) })}
            </Link>
          ))}
        </nav>
        <CsvButton rows={csv} fileName={`alghali-report-${from}-${to}.csv`} label={t.download} />
      </div>

      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 xl:grid-cols-4">
        <StatCard
          index={0}
          label={t.sales}
          value={sdg(r.totals.salesSdg)}
          note={fill(t.salesNote, { n: digits(r.totals.shopsSelling) })}
          icon={<ReceiptText />}
          tone="success"
        />
        <StatCard
          index={1}
          label={t.orders}
          value={digits(r.totals.orders)}
          note={fill(t.ordersNote, { n: digits(cashShare) })}
          icon={<Users />}
        />
        <StatCard
          index={2}
          label={t.commission}
          value={sdg(r.totals.commissionSdg)}
          note={fill(t.commissionNote, { fees: sdg(r.totals.bookingFeesSdg) })}
          icon={<Percent />}
        />
        <StatCard
          index={3}
          label={t.fittingsDone}
          value={digits(r.totals.fittingsDone)}
          note={fill(t.fittingsNote, { n: digits(r.totals.fittingsBooked) })}
          icon={<CalendarClock />}
        />
        <StatCard
          index={4}
          label={t.buyers}
          value={digits(r.totals.buyers)}
          note={fill(t.buyersNote, { n: digits(r.totals.newAccounts) })}
          icon={<Users />}
        />
        <StatCard
          index={5}
          label={t.receipts}
          value={digits(r.totals.receiptsConfirmed)}
          note={
            r.totals.reviewMinutes === null
              ? fill(t.rejected, { n: digits(r.totals.receiptsRejected) })
              : fill(t.receiptsNote, {
                  minutes: digits(r.totals.reviewMinutes),
                  n: digits(r.totals.receiptsRejected),
                })
          }
          icon={<Landmark />}
        />
        <StatCard
          index={6}
          label={t.refunds}
          value={sdg(r.totals.refundsPaidSdg)}
          icon={<Undo2 />}
          tone={r.totals.refundsPaidSdg > 0 ? 'warning' : undefined}
        />
        <StatCard
          index={7}
          label={t.newPartners}
          value={digits(r.totals.newShops + r.totals.newTechnicians)}
          note={fill(t.newPartnersNote, {
            shops: digits(r.totals.newShops),
            techs: digits(r.totals.newTechnicians),
          })}
          icon={<UserPlus />}
        />
      </div>

      <Panel title={t.salesPerDay}>
        <DailyChart
          label={fill(t.chartSummary, { total: sdg(r.totals.salesSdg), n: digits(span) })}
          chartLabel={t.showChart}
          tableLabel={t.showTable}
          dayHeader={t.colDay}
          valueHeader={t.colSales}
          noteHeader={t.colOrders}
          points={r.days.map((x) => ({
            label: dayLabel(x.day),
            value: x.salesSdg,
            valueText: sdg(x.salesSdg),
            note: fill(t.ordersCount, { n: digits(x.orders) }),
          }))}
        />
      </Panel>

      <div className="grid grid-cols-1 gap-4 xl:grid-cols-3">
        <Panel title={t.topShops} className="xl:col-span-2">
          {r.topShops.length === 0 ? (
            <EmptyState icon={<HandCoins />} title={t.noSales} />
          ) : (
            <Table>
              <thead>
                <tr>
                  <Th>{d.common.partner}</Th>
                  <Th className="text-end">{t.colOrders}</Th>
                  <Th className="text-end">{t.colSales}</Th>
                  <Th className="text-end">{t.colCommission}</Th>
                  <Th className="text-end">{t.colRating}</Th>
                </tr>
              </thead>
              <tbody>
                {r.topShops.map((s) => (
                  <tr key={s.id} className="hover:bg-muted/40">
                    <Td className="font-medium">
                      <bdi>{named(s.name, locale)}</bdi>
                    </Td>
                    <Td className="text-end">
                      <Num>{digits(s.orders)}</Num>
                    </Td>
                    <Td className="text-end">
                      <Num className="font-semibold">{sdg(s.salesSdg)}</Num>
                    </Td>
                    <Td className="text-end">
                      <Num>{sdg(s.commissionSdg)}</Num>
                    </Td>
                    <Td className="text-end">
                      <Num>{s.ratingCount ? s.rating.toFixed(1) : '—'}</Num>
                    </Td>
                  </tr>
                ))}
              </tbody>
            </Table>
          )}
        </Panel>
        <Panel title={t.fittings}>
          {fittingRows.length === 0 ? (
            <EmptyState icon={<CalendarClock />} title={t.noFittings} />
          ) : (
            <CategoryBars rows={fittingRows} label={t.fittings} />
          )}
        </Panel>
      </div>
    </>
  );
}
