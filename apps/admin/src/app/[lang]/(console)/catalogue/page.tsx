import { Tabs } from '@base-ui/react/tabs';
import { Car, Layers, Plus, Tags } from 'lucide-react';
import { DemoAction } from '@/components/admin/interactive';
import {
  CountPill,
  DemoBadge,
  Num,
  PageHeader,
  Panel,
  StatCard,
  Table,
  Td,
  Th,
  tabClass,
} from '@/components/admin/ui';
import { getDictionary, getLocale } from '@/i18n/dictionaries';
import { catalogueStats, categories, fitmentGaps, synonymGroups, tr } from '@/lib/demo/data';
import { digits, fill } from '@/lib/format';

export default async function CataloguePage() {
  const [d, locale] = await Promise.all([getDictionary(), getLocale()]);
  const c = d.catalogue;
  const coverage = Math.round((catalogueStats.withFitment / catalogueStats.parts) * 100);

  return (
    <>
      <PageHeader
        title={c.title}
        description={c.subtitle}
        actions={<DemoBadge label={d.app.demo} note={d.app.demoNote} />}
      />

      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 xl:grid-cols-4">
        <StatCard label={c.makes} value={digits(catalogueStats.makes)} icon={<Car />} />
        <StatCard label={c.models} value={digits(catalogueStats.models)} icon={<Layers />} />
        <StatCard label={c.parts} value={digits(catalogueStats.parts)} icon={<Tags />} />
        <div className="rounded-xl bg-card p-4 ring-1 ring-foreground/10">
          <div className="text-sm text-muted-foreground">{c.coverage}</div>
          <div className="mt-2 text-2xl font-bold">{digits(coverage)}%</div>
          <div className="mt-2 h-2 overflow-hidden rounded-full bg-muted" aria-hidden>
            <div className="h-full rounded-full bg-chart-1" style={{ width: `${coverage}%` }} />
          </div>
          <div className="mt-2 text-xs text-muted-foreground">
            {fill(c.coverageOf, {
              n: digits(catalogueStats.withFitment),
              total: digits(catalogueStats.parts),
            })}
          </div>
        </div>
      </div>

      <Tabs.Root defaultValue="gaps">
        <Tabs.List className="flex gap-1 overflow-x-auto border-b">
          <Tabs.Tab value="gaps" className={tabClass}>
            {c.gaps}
            <CountPill>{fitmentGaps.length}</CountPill>
          </Tabs.Tab>
          <Tabs.Tab value="synonyms" className={tabClass}>
            {c.synonyms}
            <CountPill>{synonymGroups.length}</CountPill>
          </Tabs.Tab>
          <Tabs.Tab value="categories" className={tabClass}>
            {c.categories}
            <CountPill>{categories.length}</CountPill>
          </Tabs.Tab>
        </Tabs.List>

        <Tabs.Panel value="gaps" className="pt-5 outline-none">
          <Panel>
            <p className="border-b px-4 py-3 text-sm text-muted-foreground">{c.gapsBody}</p>
            <ul className="divide-y">
              {fitmentGaps.map((g) => (
                <li key={g.name.en} className="flex flex-wrap items-center gap-3 px-4 py-3">
                  <div className="min-w-0 flex-1">
                    <div className="text-sm font-medium">{tr(g.name, locale)}</div>
                    <div className="text-xs text-muted-foreground">
                      {fill(c.listings, { n: digits(g.listings) })}
                    </div>
                  </div>
                  <DemoAction label={c.addFitment} note={d.common.demoOnly} icon={<Plus />} />
                </li>
              ))}
            </ul>
          </Panel>
        </Tabs.Panel>

        <Tabs.Panel value="synonyms" className="pt-5 outline-none">
          <Panel>
            <div className="flex flex-wrap items-center justify-between gap-3 border-b px-4 py-3">
              <p className="text-sm text-muted-foreground">{c.synonymsBody}</p>
              <DemoAction label={c.addSynonym} note={d.common.demoOnly} icon={<Plus />} />
            </div>
            <ul className="divide-y">
              {synonymGroups.map((group) => (
                <li key={group.join('|')} className="flex flex-wrap gap-2 px-4 py-3">
                  {group.map((word) => (
                    <bdi key={word} className="rounded-md bg-muted px-2 py-1 text-sm">
                      {word}
                    </bdi>
                  ))}
                </li>
              ))}
            </ul>
          </Panel>
        </Tabs.Panel>

        <Tabs.Panel value="categories" className="pt-5 outline-none">
          <Panel>
            <Table>
              <thead>
                <tr>
                  <Th>{c.categories}</Th>
                  <Th className="text-end">{c.parts}</Th>
                </tr>
              </thead>
              <tbody>
                {categories.map((x) => (
                  <tr key={x.name.en} className="hover:bg-muted/40">
                    <Td className="font-medium">{tr(x.name, locale)}</Td>
                    <Td className="text-end">
                      <Num>{x.parts}</Num>
                    </Td>
                  </tr>
                ))}
              </tbody>
            </Table>
          </Panel>
        </Tabs.Panel>
      </Tabs.Root>
    </>
  );
}
