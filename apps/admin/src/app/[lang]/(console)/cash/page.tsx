import { Banknote, HandCoins, TriangleAlert } from 'lucide-react';
import {
  DemoBadge,
  Num,
  PageHeader,
  Panel,
  StatCard,
  StatusBadge,
  Table,
  Td,
  Th,
} from '@/components/admin/ui';
import { getDictionary, getLocale } from '@/i18n/dictionaries';
import { cashRows, tr } from '@/lib/demo/data';
import { digits, money } from '@/lib/format';

/** Flagged after this many payout cycles without paying the platform. */
const CYCLE_LIMIT = 2;

export default async function CashPage() {
  const [d, locale] = await Promise.all([getDictionary(), getLocale()]);
  const rows = [...cashRows].sort((a, b) => b.cycles - a.cycles || b.owedSdg - a.owedSdg);
  const owed = rows.reduce((s, r) => s + r.owedSdg, 0);
  const collected = rows.reduce((s, r) => s + r.collectedSdg, 0);
  const flagged = rows.filter((r) => r.cycles >= CYCLE_LIMIT).length;
  const sdg = (n: number) => money(n, d.common.currency);

  return (
    <>
      <PageHeader
        title={d.cash.title}
        description={d.cash.subtitle}
        actions={<DemoBadge label={d.app.demo} note={d.app.demoNote} />}
      />
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-3">
        <StatCard label={d.cash.totalOwed} value={sdg(owed)} icon={<Banknote />} />
        <StatCard label={d.cash.collected} value={sdg(collected)} icon={<HandCoins />} />
        <StatCard
          label={d.cash.flag}
          value={digits(flagged)}
          icon={<TriangleAlert />}
          tone={flagged > 0 ? 'warning' : undefined}
        />
      </div>
      <Panel>
        <Table>
          <thead>
            <tr>
              <Th>{d.common.partner}</Th>
              <Th>{d.common.role}</Th>
              <Th className="text-end">{d.cash.collected}</Th>
              <Th className="text-end">{d.cash.handed}</Th>
              <Th className="text-end">{d.cash.owed}</Th>
              <Th>{d.cash.cycles}</Th>
            </tr>
          </thead>
          <tbody>
            {rows.map((r) => (
              <tr key={r.partner.en} className="hover:bg-muted/40">
                <Td className="font-medium whitespace-nowrap">{tr(r.partner, locale)}</Td>
                <Td className="text-muted-foreground">
                  {r.role === 'shop' ? d.common.shop : d.common.technician}
                </Td>
                <Td className="text-end">
                  <Num>{sdg(r.collectedSdg)}</Num>
                </Td>
                <Td className="text-end">
                  <Num>{r.role === 'shop' ? '—' : sdg(r.handedSdg)}</Num>
                </Td>
                <Td className="text-end">
                  <Num className="font-semibold">{sdg(r.owedSdg)}</Num>
                </Td>
                <Td>
                  <span className="inline-flex items-center gap-2">
                    <Num>{r.cycles}</Num>
                    {r.cycles >= CYCLE_LIMIT && (
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
      </Panel>
    </>
  );
}
