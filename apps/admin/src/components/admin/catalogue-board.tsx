'use client';

import { Tabs } from '@base-ui/react/tabs';
import { Check, GitMerge, PackageCheck, Pencil, Plus, Search, Trash2, X } from 'lucide-react';
import { AnimatePresence, motion } from 'motion/react';
import { useId, useMemo, useState } from 'react';
import { cn } from 'cn';
import { Button } from '@/components/ui/button';
import type { Locale } from '@/i18n/config';
import type { Dictionary } from '@/i18n/dictionaries';
import {
  addPartFitment,
  deleteSynonymGroup,
  mergePart,
  saveSynonymGroup,
  verifyPart,
} from '@/lib/actions/admin';
import type { Catalogue, GapPart, ShopPart, SynonymGroup } from '@/lib/data/catalogue';
import { named } from '@/lib/data/util';
import { digits, fill, searchKey } from '@/lib/format';
import { CheckField, ConfirmDialog, Modal } from './interactive';
import { useAction } from './use-action';
import { CountPill, EmptyState, Num, Panel, Table, TabList, Td, Th, tabClass } from './ui';

type Labels = {
  c: Dictionary['catalogue'];
  common: Dictionary['common'];
  errors: Dictionary['errors'];
};

export type CatalogueTab = 'gaps' | 'shop-parts' | 'synonyms' | 'categories';

export function CatalogueBoard({
  data,
  locale,
  t,
  initialTab,
}: {
  data: Omit<Catalogue, 'stats'>;
  locale: Locale;
  t: Labels;
  initialTab: CatalogueTab;
}) {
  const { c } = t;
  return (
    <Tabs.Root defaultValue={initialTab}>
      <TabList>
        <Tabs.Tab value="gaps" className={tabClass}>
          {c.gaps}
          <CountPill>{data.gaps.length}</CountPill>
        </Tabs.Tab>
        <Tabs.Tab value="shop-parts" className={tabClass}>
          {c.shopParts}
          <CountPill>{data.shopParts.length}</CountPill>
        </Tabs.Tab>
        <Tabs.Tab value="synonyms" className={tabClass}>
          {c.synonyms}
          <CountPill>{data.synonyms.length}</CountPill>
        </Tabs.Tab>
        <Tabs.Tab value="categories" className={tabClass}>
          {c.categories}
          <CountPill>{data.categories.length}</CountPill>
        </Tabs.Tab>
      </TabList>

      <Tabs.Panel value="gaps" className="pt-5 outline-none">
        <Gaps gaps={data.gaps} makes={data.makes} locale={locale} t={t} />
      </Tabs.Panel>
      <Tabs.Panel value="shop-parts" className="pt-5 outline-none">
        <ShopParts parts={data.shopParts} options={data.verifiedParts} locale={locale} t={t} />
      </Tabs.Panel>
      <Tabs.Panel value="synonyms" className="pt-5 outline-none">
        <Synonyms groups={data.synonyms} t={t} />
      </Tabs.Panel>
      <Tabs.Panel value="categories" className="pt-5 outline-none">
        <Categories categories={data.categories} locale={locale} t={t} />
      </Tabs.Panel>
    </Tabs.Root>
  );
}

function SearchBox({
  value,
  onChange,
  placeholder,
}: {
  value: string;
  onChange: (v: string) => void;
  placeholder: string;
}) {
  return (
    <label className="relative block w-full sm:w-64">
      <span className="sr-only">{placeholder}</span>
      <Search className="pointer-events-none absolute start-3 top-1/2 size-4 -translate-y-1/2 text-muted-foreground" />
      <input
        type="search"
        value={value}
        onChange={(e) => onChange(e.target.value)}
        placeholder={placeholder}
        className="h-9 w-full rounded-lg border border-input bg-card ps-9 pe-3 text-sm outline-none focus-visible:border-ring focus-visible:ring-2 focus-visible:ring-ring/30"
      />
    </label>
  );
}

const rowMotion = {
  layout: 'position' as const,
  initial: { opacity: 0, y: 6 },
  animate: { opacity: 1, y: 0 },
  exit: { opacity: 0, x: -24, transition: { duration: 0.18 } },
};

// ------------------------------------------------------------------- fitment

function Gaps({
  gaps,
  makes,
  locale,
  t,
}: {
  gaps: GapPart[];
  makes: Catalogue['makes'];
  locale: Locale;
  t: Labels;
}) {
  const { c } = t;
  const [query, setQuery] = useState('');
  const [editing, setEditing] = useState<GapPart | null>(null);
  const [done, setDone] = useState<Set<string>>(new Set());
  const q = searchKey(query);
  const shown = gaps.filter(
    (g) => !done.has(g.id) && (!q || searchKey(`${g.name.ar} ${g.name.en}`).includes(q)),
  );

  return (
    <Panel>
      <div className="flex flex-wrap items-center justify-between gap-3 border-b px-4 py-3">
        <p className="max-w-xl text-sm text-muted-foreground">{c.gapsBody}</p>
        <SearchBox value={query} onChange={setQuery} placeholder={c.searchParts} />
      </div>
      {shown.length === 0 ? (
        <EmptyState icon={<PackageCheck />} title={q ? t.common.noResults : c.gapsEmpty} />
      ) : (
        <ul className="divide-y">
          <AnimatePresence initial={false}>
            {shown.map((g) => (
              <motion.li
                key={g.id}
                {...rowMotion}
                className="flex flex-wrap items-center gap-3 px-4 py-3"
              >
                <div className="min-w-0 flex-1">
                  <div className="text-sm font-medium">{named(g.name, locale)}</div>
                  <div className="text-xs text-muted-foreground">{named(g.category, locale)}</div>
                </div>
                <span
                  className={cn(
                    'rounded-md px-2 py-0.5 text-xs font-semibold',
                    g.listings > 0 ? 'bg-info-soft text-info' : 'bg-muted text-muted-foreground',
                  )}
                >
                  {g.listings > 0 ? fill(c.listings, { n: digits(g.listings) }) : c.notListed}
                </span>
                <Button variant="outline" className="h-8 px-2.5" onClick={() => setEditing(g)}>
                  <Plus />
                  {c.addFitment}
                </Button>
              </motion.li>
            ))}
          </AnimatePresence>
        </ul>
      )}
      <FitmentDialog
        part={editing}
        makes={makes}
        locale={locale}
        t={t}
        onClose={() => setEditing(null)}
        onSaved={(id) => setDone((s) => new Set(s).add(id))}
      />
    </Panel>
  );
}

/** Pick the models a part fits; every active engine variant of each is added. */
function FitmentDialog({
  part,
  makes,
  locale,
  t,
  onClose,
  onSaved,
}: {
  part: GapPart | null;
  makes: Catalogue['makes'];
  locale: Locale;
  t: Labels;
  onClose: () => void;
  onSaved: (partId: string) => void;
}) {
  const { c } = t;
  const [picked, setPicked] = useState<Set<string>>(new Set());
  const [query, setQuery] = useState('');
  const { pending, run } = useAction(t.errors);
  const q = searchKey(query);
  const visible = makes
    .map((m) => {
      const makeHit = !q || searchKey(`${m.name.ar} ${m.name.en}`).includes(q);
      return {
        ...m,
        models: m.models.filter(
          (x) => makeHit || searchKey(`${x.name.ar} ${x.name.en}`).includes(q),
        ),
      };
    })
    .filter((m) => m.models.length > 0);

  const close = () => {
    onClose();
    setPicked(new Set());
    setQuery('');
  };
  const toggle = (id: string, on: boolean) =>
    setPicked((s) => {
      const next = new Set(s);
      if (on) next.add(id);
      else next.delete(id);
      return next;
    });

  return (
    <Modal
      open={part !== null}
      onOpenChange={(o) => !o && close()}
      title={c.fitmentTitle}
      description={part ? `${named(part.name, locale)} — ${c.fitmentBody}` : undefined}
    >
      <SearchBox value={query} onChange={setQuery} placeholder={c.fitmentSearch} />
      <div className="-mx-2 max-h-80 overflow-y-auto px-2">
        {visible.length === 0 && (
          <p className="py-8 text-center text-sm text-muted-foreground">{t.common.noResults}</p>
        )}
        {visible.map((m) => {
          const all = m.models.every((x) => picked.has(x.id));
          return (
            <fieldset key={m.id} className="border-b py-2 last:border-0">
              <legend className="sr-only">{named(m.name, locale)}</legend>
              <div className="flex items-center justify-between px-2 py-1">
                <span className="text-sm font-semibold">{named(m.name, locale)}</span>
                <button
                  type="button"
                  onClick={() => m.models.forEach((x) => toggle(x.id, !all))}
                  className="cursor-pointer rounded px-1.5 text-xs font-medium text-muted-foreground hover:text-foreground"
                >
                  {all ? t.common.cancel : t.common.all}
                </button>
              </div>
              <div className="grid grid-cols-1 sm:grid-cols-2">
                {m.models.map((x) => (
                  <CheckField
                    key={x.id}
                    checked={picked.has(x.id)}
                    onCheckedChange={(on) => toggle(x.id, on)}
                    label={named(x.name, locale)}
                  />
                ))}
              </div>
            </fieldset>
          );
        })}
      </div>
      <div className="flex flex-wrap items-center justify-between gap-2">
        <span className="text-sm text-muted-foreground" aria-live="polite">
          {fill(c.fitmentSelected, { n: digits(picked.size) })}
        </span>
        <div className="flex gap-2">
          <Button variant="outline" className="h-10 px-4" onClick={close}>
            {t.common.cancel}
          </Button>
          <Button
            className="h-10 px-4"
            disabled={picked.size === 0 || pending || !part}
            onClick={() => {
              if (!part) return;
              const id = part.id;
              run(() => addPartFitment(id, [...picked]), {
                success: fill(c.fitmentSaved, { part: named(part.name, locale) }),
                onDone: () => {
                  onSaved(id);
                  close();
                },
              });
            }}
          >
            <Check />
            {t.common.save}
          </Button>
        </div>
      </div>
    </Modal>
  );
}

// ---------------------------------------------------------------- shop parts

function ShopParts({
  parts,
  options,
  locale,
  t,
}: {
  parts: ShopPart[];
  options: Catalogue['verifiedParts'];
  locale: Locale;
  t: Labels;
}) {
  const { c } = t;
  const [done, setDone] = useState<Set<string>>(new Set());
  const [merging, setMerging] = useState<ShopPart | null>(null);
  const { pending, run } = useAction(t.errors);
  const shown = parts.filter((p) => !done.has(p.id));
  const hide = (id: string) => setDone((s) => new Set(s).add(id));
  const unhide = (id: string) =>
    setDone((s) => {
      const next = new Set(s);
      next.delete(id);
      return next;
    });

  return (
    <Panel>
      <p className="border-b px-4 py-3 text-sm text-muted-foreground">{c.shopPartsBody}</p>
      {shown.length === 0 ? (
        <EmptyState icon={<PackageCheck />} title={c.shopPartsEmpty} />
      ) : (
        <ul className="divide-y">
          <AnimatePresence initial={false}>
            {shown.map((p) => (
              <motion.li
                key={p.id}
                {...rowMotion}
                className="flex flex-wrap items-center gap-3 px-4 py-3"
              >
                <div className="min-w-0 flex-1">
                  <div className="text-sm font-medium">{named(p.name, locale)}</div>
                  <div className="text-xs text-muted-foreground">
                    {named(p.category, locale)}
                    {p.shop && ` · ${fill(c.fromShop, { shop: named(p.shop, locale) })}`}
                    {` · ${fill(c.listings, { n: digits(p.listings) })}`}
                  </div>
                </div>
                <Button
                  className="h-8 px-2.5"
                  disabled={pending}
                  onClick={() => {
                    hide(p.id);
                    run(() => verifyPart(p.id), {
                      success: fill(c.accepted, { part: named(p.name, locale) }),
                      onFail: () => unhide(p.id),
                    });
                  }}
                >
                  <Check />
                  {c.accept}
                </Button>
                <Button
                  variant="outline"
                  className="h-8 px-2.5"
                  disabled={pending}
                  onClick={() => setMerging(p)}
                >
                  <GitMerge />
                  {c.merge}
                </Button>
              </motion.li>
            ))}
          </AnimatePresence>
        </ul>
      )}
      <MergeDialog
        part={merging}
        options={options}
        locale={locale}
        t={t}
        pending={pending}
        onClose={() => setMerging(null)}
        onMerge={(part, into) => {
          setMerging(null);
          hide(part.id);
          run(() => mergePart(part.id, into.id), {
            success: fill(c.merged, { part: named(into.name, locale) }),
            onFail: () => unhide(part.id),
          });
        }}
      />
    </Panel>
  );
}

function MergeDialog({
  part,
  options,
  locale,
  t,
  pending,
  onClose,
  onMerge,
}: {
  part: ShopPart | null;
  options: Catalogue['verifiedParts'];
  locale: Locale;
  t: Labels;
  pending: boolean;
  onClose: () => void;
  onMerge: (part: ShopPart, into: Catalogue['verifiedParts'][number]) => void;
}) {
  const { c } = t;
  const [query, setQuery] = useState('');
  const [target, setTarget] = useState<string | null>(null);
  const q = searchKey(query);
  const candidates = part
    ? options.filter(
        (o) =>
          o.categoryId === part.categoryId &&
          (!q || searchKey(`${o.name.ar} ${o.name.en}`).includes(q)),
      )
    : [];
  const close = () => {
    onClose();
    setQuery('');
    setTarget(null);
  };
  const chosen = candidates.find((o) => o.id === target);
  return (
    <Modal
      open={part !== null}
      onOpenChange={(o) => !o && close()}
      title={part ? fill(c.mergeTitle, { part: named(part.name, locale) }) : ''}
      description={c.mergeBody}
    >
      <SearchBox value={query} onChange={setQuery} placeholder={c.searchParts} />
      <div
        role="radiogroup"
        aria-label={c.mergeTarget}
        className="-mx-2 flex max-h-72 flex-col overflow-y-auto px-2"
      >
        {candidates.length === 0 && (
          <p className="py-8 text-center text-sm text-muted-foreground">{c.mergeNoMatch}</p>
        )}
        {candidates.map((o) => (
          <button
            key={o.id}
            type="button"
            role="radio"
            aria-checked={target === o.id}
            onClick={() => setTarget(o.id)}
            className={cn(
              'flex cursor-pointer items-center gap-3 rounded-lg px-3 py-2.5 text-start text-sm transition-colors',
              target === o.id ? 'bg-foreground text-background' : 'hover:bg-muted',
            )}
          >
            <span
              className={cn(
                'grid size-4 shrink-0 place-items-center rounded-full border-2',
                target === o.id ? 'border-background' : 'border-input',
              )}
            >
              {target === o.id && <span className="size-1.5 rounded-full bg-background" />}
            </span>
            {named(o.name, locale)}
          </button>
        ))}
      </div>
      <div className="flex justify-end gap-2">
        <Button variant="outline" className="h-10 px-4" onClick={close}>
          {t.common.cancel}
        </Button>
        <Button
          className="h-10 px-4"
          disabled={!chosen || pending}
          onClick={() => {
            if (part && chosen) {
              onMerge(part, chosen);
              setQuery('');
              setTarget(null);
            }
          }}
        >
          <GitMerge />
          {c.merge}
        </Button>
      </div>
    </Modal>
  );
}

// ------------------------------------------------------------------ synonyms

const splitTerms = (s: string) =>
  s
    .split(/[,،\n]/)
    .map((x) => x.trim())
    .filter(Boolean);

function Synonyms({ groups, t }: { groups: SynonymGroup[]; t: Labels }) {
  const { c } = t;
  const [adding, setAdding] = useState(false);
  const [editing, setEditing] = useState<string | null>(null);
  const [deleting, setDeleting] = useState<SynonymGroup | null>(null);
  const [query, setQuery] = useState('');
  const { pending, run } = useAction(t.errors);
  const q = searchKey(query);
  const shown = groups.filter((g) => !q || g.terms.some((x) => searchKey(x).includes(q)));

  return (
    <Panel>
      <div className="flex flex-wrap items-center justify-between gap-3 border-b px-4 py-3">
        <p className="max-w-xl text-sm text-muted-foreground">{c.synonymsBody}</p>
        <div className="flex w-full flex-wrap gap-2 sm:w-auto">
          <SearchBox value={query} onChange={setQuery} placeholder={t.common.search} />
          <Button className="h-9 px-3" onClick={() => setAdding(true)} disabled={adding}>
            <Plus />
            {c.addSynonym}
          </Button>
        </div>
      </div>
      <AnimatePresence initial={false}>
        {adding && (
          <motion.div
            initial={{ height: 0, opacity: 0 }}
            animate={{ height: 'auto', opacity: 1 }}
            exit={{ height: 0, opacity: 0 }}
            className="overflow-hidden border-b bg-muted/40"
          >
            <TermsForm
              t={t}
              pending={pending}
              onCancel={() => setAdding(false)}
              onSave={(terms) =>
                run(() => saveSynonymGroup(null, terms), {
                  success: c.synonymSaved,
                  onDone: () => setAdding(false),
                })
              }
            />
          </motion.div>
        )}
      </AnimatePresence>
      {shown.length === 0 ? (
        <EmptyState icon={<Search />} title={t.common.noResults} />
      ) : (
        <ul className="divide-y">
          <AnimatePresence initial={false}>
            {shown.map((g) => (
              <motion.li key={g.id} {...rowMotion} className="group px-4 py-3">
                {editing === g.id ? (
                  <TermsForm
                    t={t}
                    initial={g.terms.join('، ')}
                    pending={pending}
                    onCancel={() => setEditing(null)}
                    onSave={(terms) =>
                      run(() => saveSynonymGroup(g.id, terms), {
                        success: c.synonymSaved,
                        onDone: () => setEditing(null),
                      })
                    }
                  />
                ) : (
                  <div className="flex items-start gap-3">
                    <div className="flex flex-1 flex-wrap gap-1.5">
                      {g.terms.map((word) => (
                        <bdi key={word} className="rounded-md bg-muted px-2 py-1 text-sm">
                          {word}
                        </bdi>
                      ))}
                    </div>
                    <div className="flex gap-1 opacity-100 transition-opacity sm:opacity-0 sm:group-focus-within:opacity-100 sm:group-hover:opacity-100">
                      <Button
                        variant="ghost"
                        size="icon"
                        aria-label={t.common.edit}
                        onClick={() => setEditing(g.id)}
                      >
                        <Pencil />
                      </Button>
                      <Button
                        variant="ghost"
                        size="icon"
                        aria-label={t.common.delete}
                        className="text-destructive hover:text-destructive"
                        onClick={() => setDeleting(g)}
                      >
                        <Trash2 />
                      </Button>
                    </div>
                  </div>
                )}
              </motion.li>
            ))}
          </AnimatePresence>
        </ul>
      )}
      <ConfirmDialog
        open={deleting !== null}
        onOpenChange={(o) => !o && setDeleting(null)}
        title={c.deleteTitle}
        description={deleting ? `${deleting.terms.join('، ')} — ${c.deleteBody}` : undefined}
        confirmLabel={t.common.delete}
        cancelLabel={t.common.cancel}
        tone="danger"
        pending={pending}
        onConfirm={() => {
          if (!deleting) return;
          const id = deleting.id;
          setDeleting(null);
          run(() => deleteSynonymGroup(id), { success: c.synonymDeleted });
        }}
      />
    </Panel>
  );
}

function TermsForm({
  t,
  initial = '',
  pending,
  onSave,
  onCancel,
}: {
  t: Labels;
  initial?: string;
  pending: boolean;
  onSave: (terms: string[]) => void;
  onCancel: () => void;
}) {
  const [value, setValue] = useState(initial);
  const id = useId();
  const terms = useMemo(() => splitTerms(value), [value]);
  const ok = new Set(terms.map((x) => x.toLowerCase())).size >= 2;
  return (
    <form
      className="flex flex-col gap-2 p-4"
      onSubmit={(e) => {
        e.preventDefault();
        if (ok) onSave(terms);
      }}
    >
      <label className="text-sm font-medium" htmlFor={id}>
        {t.c.synonymWords}
      </label>
      <input
        id={id}
        autoFocus
        value={value}
        onChange={(e) => setValue(e.target.value)}
        className="h-10 rounded-lg border border-input bg-card px-3 text-base outline-none focus-visible:border-ring focus-visible:ring-2 focus-visible:ring-ring/30"
      />
      <div className="flex min-h-7 flex-wrap gap-1.5">
        <AnimatePresence initial={false}>
          {terms.map((word, i) => (
            <motion.bdi
              key={`${word}-${i}`}
              initial={{ opacity: 0, scale: 0.8 }}
              animate={{ opacity: 1, scale: 1 }}
              exit={{ opacity: 0, scale: 0.8 }}
              className="rounded-md bg-card px-2 py-1 text-sm ring-1 ring-foreground/10"
            >
              {word}
            </motion.bdi>
          ))}
        </AnimatePresence>
      </div>
      <p className="text-xs text-muted-foreground">{t.c.synonymHint}</p>
      <div className="flex justify-end gap-2">
        <Button type="button" variant="outline" className="h-9 px-3" onClick={onCancel}>
          <X />
          {t.common.cancel}
        </Button>
        <Button type="submit" className="h-9 px-3" disabled={!ok || pending}>
          <Check />
          {t.common.save}
        </Button>
      </div>
    </form>
  );
}

// ---------------------------------------------------------------- categories

function Categories({
  categories,
  locale,
  t,
}: {
  categories: Catalogue['categories'];
  locale: Locale;
  t: Labels;
}) {
  const { c } = t;
  const max = Math.max(1, ...categories.map((x) => x.listings));
  return (
    <Panel>
      <Table>
        <thead>
          <tr>
            <Th>{c.categories}</Th>
            <Th className="text-end">{c.categoryParts}</Th>
            <Th className="w-1/2">{c.categoryListings}</Th>
          </tr>
        </thead>
        <tbody>
          {categories.map((x, i) => (
            <tr key={x.id} className="transition-colors hover:bg-muted/40">
              <Td className="font-medium">
                {named(x.name, locale)}
                {!x.active && (
                  <span className="ms-2 text-xs text-muted-foreground">({c.hidden})</span>
                )}
              </Td>
              <Td className="text-end">
                <Num>{x.parts}</Num>
              </Td>
              <Td>
                <div className="flex items-center gap-3">
                  <span className="relative h-2 flex-1 overflow-hidden rounded-full bg-muted">
                    <motion.span
                      className="absolute inset-y-0 start-0 rounded-full bg-chart-1 ltr:origin-left rtl:origin-right"
                      style={{ width: `${(x.listings / max) * 100}%` }}
                      initial={{ scaleX: 0 }}
                      animate={{ scaleX: 1 }}
                      transition={{ duration: 0.6, delay: i * 0.04 }}
                    />
                  </span>
                  <Num className="w-8 text-end">{x.listings}</Num>
                </div>
              </Td>
            </tr>
          ))}
        </tbody>
      </Table>
    </Panel>
  );
}
