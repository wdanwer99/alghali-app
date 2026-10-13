import { Banknote, HandCoins, TriangleAlert, Wallet } from 'lucide-react';
import { Suspense } from 'react';
import {
  EmptyState,
  Num,
  PageHeader,
  PageSkeleton,
  Panel,
  StatCard,
  StatusBadge,
  Table,
  Td,
  Th,
} from '@/components/admin/ui';
import type { Locale } from '@/i18n/config';
import { getDictionary, getLocale, type Dictionary } from '@/i18n/dictionaries';
import { requireAdmin } from '@/lib/auth';
import { loadPartnerBalances } from '@/lib/data/commerce';
import { named } from '@/lib/data/util';
import { digits, money } from '@/lib/format';

/** Flagged after this many payout runs in a row found the shop owing (D-018). */
const CYCLE_LIMIT = 2;

export default async function CashPage() {
  const [d, locale] = await Promise.all([getDictionary(), getLocale()]);
  return (
    <>
      <PageHeader title={d.cash.title} description={d.cash.subtitle} />
      <Suspense fallback={<PageSkeleton stats={3} rows={6} />}>
        <Cash d={d} locale={locale} />
      </Suspense>
    </>
  );
}

async function Cash({ d, locale }: { d: Dictionary; locale: Locale }) {
  const { supabase } = await requireAdmin();
  const balances = await loadPartnerBalances(supabase);
  const rows = [...balances].sort(
    (a, b) => b.cyclesOwing - a.cyclesOwing || a.balanceSdg - b.balanceSdg,
  );
  const owed = rows.reduce((s, r) => s + Math.max(-r.balanceSdg, 0), 0);
  const toShops = rows.reduce((s, r) => s + Math.max(r.balanceSdg, 0), 0);
  const collected = rows.reduce((s, r) => s + r.cashCollectedSdg, 0);
  const flagged = rows.filter((r) => r.cyclesOwing >= CYCLE_LIMIT).length;
  const sdg = (n: number) => money(n, d.common.currency);

  return (
    <>
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 xl:grid-cols-4">
        <StatCard index={0} label={d.cash.totalOwed} value={sdg(owed)} icon={<Banknote />} />
        <StatCard index={1} label={d.cash.owedToShop} value={sdg(toShops)} icon={<Wallet />} />
        <StatCard
          index={2}
          label={d.cash.collected}
          value={sdg(collected)}
          note={d.cash.collectedHint}
          icon={<HandCoins />}
        />
        <StatCard
          index={3}
          label={d.cash.flag}
          value={digits(flagged)}
          icon={<TriangleAlert />}
          tone={flagged > 0 ? 'warning' : undefined}
        />
      </div>
      <Panel>
        {rows.length === 0 ? (
          <EmptyState icon={<Banknote />} title={d.cash.empty} body={d.cash.emptyBody} />
        ) : (
          <Table>
            <thead>
              <tr>
                <Th>{d.common.partner}</Th>
                <Th className="text-end">{d.cash.collected}</Th>
                <Th className="text-end">{d.cash.owed}</Th>
                <Th className="text-end">{d.cash.owedToShop}</Th>
                <Th className="text-end">{d.cash.openPayout}</Th>
                <Th>{d.cash.cycles}</Th>
              </tr>
            </thead>
            <tbody>
              {rows.map((r) => (
                <tr key={r.shopId} className="hover:bg-muted/40">
                  <Td className="font-medium whitespace-nowrap">{named(r.name, locale)}</Td>
                  <Td className="text-end">
                    <Num>{sdg(r.cashCollectedSdg)}</Num>
                  </Td>
                  <Td className="text-end">
                    <Num className="font-semibold">
                      {r.balanceSdg < 0 ? sdg(-r.balanceSdg) : '—'}
                    </Num>
                  </Td>
                  <Td className="text-end">
                    <Num>{r.balanceSdg > 0 ? sdg(r.balanceSdg) : '—'}</Num>
                  </Td>
                  <Td className="text-end">
                    <Num className="text-muted-foreground">
                      {r.openPayoutSdg !== null ? sdg(r.openPayoutSdg) : '—'}
                    </Num>
                  </Td>
                  <Td>
                    <span className="inline-flex items-center gap-2">
                      <Num>{r.cyclesOwing}</Num>
                      {r.cyclesOwing >= CYCLE_LIMIT && (
                        <StatusBadge tone="warning">
                          <TriangleAlert className="size-3.5" aria-hidden />
                          {d.cash.flag}
                        </StatusBadge>
                      )}
                    </span>
                  </Td>
                </tr>
              ))}
            </tbody>
          </Table>
        )}
      </Panel>
    </>
  );
}
