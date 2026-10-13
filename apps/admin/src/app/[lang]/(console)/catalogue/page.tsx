import { Car, Layers, Tags } from 'lucide-react';
import { Suspense } from 'react';
import { CatalogueBoard, type CatalogueTab } from '@/components/admin/catalogue-board';
import { AnimatedNumber } from '@/components/motion';
import { PageHeader, PageSkeleton, StatCard } from '@/components/admin/ui';
import type { Locale } from '@/i18n/config';
import { getDictionary, getLocale, type Dictionary } from '@/i18n/dictionaries';
import { requireAdmin } from '@/lib/auth';
import { loadCatalogue } from '@/lib/data/catalogue';
import { digits, fill } from '@/lib/format';

const TABS: CatalogueTab[] = ['gaps', 'shop-parts', 'synonyms', 'categories'];

export default async function CataloguePage({ searchParams }: PageProps<'/[lang]/catalogue'>) {
  const [d, locale] = await Promise.all([getDictionary(), getLocale()]);
  return (
    <>
      <PageHeader title={d.catalogue.title} description={d.catalogue.subtitle} />
      <Suspense fallback={<PageSkeleton rows={8} />}>
        <Catalogue d={d} locale={locale} searchParams={searchParams} />
      </Suspense>
    </>
  );
}

async function Catalogue({
  d,
  locale,
  searchParams,
}: {
  d: Dictionary;
  locale: Locale;
  searchParams: PageProps<'/[lang]/catalogue'>['searchParams'];
}) {
  const [{ supabase }, { tab }] = await Promise.all([requireAdmin(), searchParams]);
  const { stats, ...data } = await loadCatalogue(supabase);
  const c = d.catalogue;
  const coverage = stats.parts ? Math.round((stats.withFitment / stats.parts) * 100) : 0;
  const initialTab = TABS.find((x) => x === tab) ?? 'gaps';

  return (
    <>
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 xl:grid-cols-4">
        <StatCard
          index={0}
          label={c.makes}
          value={<AnimatedNumber value={stats.makes} />}
          icon={<Car />}
        />
        <StatCard
          index={1}
          label={c.models}
          value={<AnimatedNumber value={stats.models} />}
          note={fill(c.variants, { n: digits(stats.variants) })}
          icon={<Layers />}
        />
        <StatCard
          index={2}
          label={c.parts}
          value={<AnimatedNumber value={stats.parts} />}
          icon={<Tags />}
        />
        <StatCard
          index={3}
          label={c.coverage}
          value={<AnimatedNumber value={coverage} suffix="%" />}
          note={fill(c.coverageOf, { n: digits(stats.withFitment), total: digits(stats.parts) })}
          tone={coverage < 50 ? 'warning' : 'success'}
        >
          <div className="mt-3 h-2 overflow-hidden rounded-full bg-muted" aria-hidden>
            <div className="h-full rounded-full bg-chart-1" style={{ width: `${coverage}%` }} />
          </div>
        </StatCard>
      </div>
      <CatalogueBoard
        key={initialTab}
        data={data}
        locale={locale}
        initialTab={initialTab}
        t={{ c, common: d.common, errors: d.errors }}
      />
    </>
  );
}
