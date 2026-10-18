'use client';

import {
  CircleAlert,
  ExternalLink,
  MapPin,
  Plus,
  RotateCcw,
  Save,
  Trash2,
  TriangleAlert,
} from 'lucide-react';
import { AnimatePresence, motion } from 'motion/react';
import { useId, useState, type ReactNode } from 'react';
import { cn } from 'cn';
import { Button } from '@/components/ui/button';
import type { Locale } from '@/i18n/config';
import type { Dictionary } from '@/i18n/dictionaries';
import { saveStreet } from '@/lib/actions/street';
import type { StreetData } from '@/lib/data/street';
import { named } from '@/lib/data/util';
import { digits, fill } from '@/lib/format';
import {
  coordinateText,
  insideSudan,
  parseCoordinate,
  parsePoint,
  readCoordinate,
  type Axis,
} from '@/lib/geo';
import { useAction } from './use-action';
import { NumberText } from './number-text';
import { Panel, riseStyle } from './ui';

type Labels = {
  s: Dictionary['street'];
  common: Dictionary['common'];
  errors: Dictionary['errors'];
};

type ZoneDraft = {
  key: string;
  id: string | null;
  seq: number;
  nameAr: string;
  nameEn: string;
  fromM: number;
  toM: number;
  active: boolean;
  shops: number;
};

type Draft = {
  marketAr: string;
  marketEn: string;
  cityAr: string;
  cityEn: string;
  streetAr: string;
  streetEn: string;
  lengthM: number;
  lat: string;
  lng: string;
  zones: ZoneDraft[];
};

function draftOf(data: StreetData): Draft {
  return {
    marketAr: data.market.name.ar,
    marketEn: data.market.name.en,
    cityAr: data.market.city.ar,
    cityEn: data.market.city.en,
    streetAr: data.street.name.ar,
    streetEn: data.street.name.en,
    lengthM: data.street.lengthM,
    lat: data.street.originLat?.toString() ?? '',
    lng: data.street.originLng?.toString() ?? '',
    zones: data.zones.map((z) => ({
      key: z.id,
      id: z.id,
      seq: z.seq,
      nameAr: z.name.ar,
      nameEn: z.name.en,
      fromM: z.fromM,
      toM: z.toM,
      active: z.active,
      shops: z.shops,
    })),
  };
}

/** The starter data's "القطاع 1 / Section 1" names, which the owner still has to replace (D-077). */
const isPlaceholder = (z: ZoneDraft) =>
  /^القطاع \d+$/.test(z.nameAr.trim()) || /^Section \d+$/i.test(z.nameEn.trim());
/** Neighbouring zones alternate between two shades of the chart blue; white text reads on both. */
const zoneColours = ['bg-chart-1', 'bg-[color-mix(in_oklab,var(--chart-1),black_28%)]'];

/** Gaps and overlaps between the visible zones, in street order. */
function coverage(d: Draft) {
  const zones = d.zones.filter((z) => z.active).sort((a, b) => a.fromM - b.fromM);
  const gaps: [number, number][] = [];
  const overlaps: [number, number][] = [];
  let reach = 0;
  let last: ZoneDraft | null = null;
  for (const z of zones) {
    if (z.fromM > reach) gaps.push([reach, z.fromM]);
    if (last && z.fromM < last.toM) overlaps.push([last.seq, z.seq]);
    if (z.toM > reach) {
      reach = z.toM;
      last = z;
    }
  }
  if (reach < d.lengthM) gaps.push([reach, d.lengthM]);
  return { gaps, overlaps };
}

/** Field problems that would make the server refuse the save (mirrors saveStreet's check). */
function problems(d: Draft): string | null {
  const names = [
    d.marketAr,
    d.marketEn,
    d.streetAr,
    d.streetEn,
    ...d.zones.flatMap((z) => [z.nameAr, z.nameEn]),
  ];
  if (names.some((n) => !n.trim())) return 'NAME_REQUIRED';
  if (!Number.isInteger(d.lengthM) || d.lengthM < 1) return 'INVALID_VALUE';
  const lat = parseCoordinate(d.lat);
  const lng = parseCoordinate(d.lng);
  if ((lat === null) !== (lng === null)) return 'INVALID_LOCATION';
  if (lat !== null && lng !== null && !(Math.abs(lat) <= 90 && Math.abs(lng) <= 180))
    return 'INVALID_LOCATION';
  if (d.zones.length === 0) return 'INVALID_VALUE';
  if (
    d.zones.some(
      (z) =>
        !Number.isInteger(z.fromM) ||
        !Number.isInteger(z.toM) ||
        z.fromM < 0 ||
        z.toM <= z.fromM ||
        z.toM > d.lengthM,
    )
  ) {
    return 'ZONE_OUT_OF_RANGE';
  }
  return null;
}

export function StreetEditor({ data, locale, t }: { data: StreetData; locale: Locale; t: Labels }) {
  const { s } = t;
  const [initial] = useState(() => draftOf(data));
  const [draft, setDraft] = useState(initial);
  const [removed, setRemoved] = useState<string[]>([]);
  const { pending, run } = useAction(t.errors);
  const set = (patch: Partial<Draft>) => setDraft((d) => ({ ...d, ...patch }));
  const setZone = (key: string, patch: Partial<ZoneDraft>) =>
    setDraft((d) => ({
      ...d,
      zones: d.zones.map((z) => (z.key === key ? { ...z, ...patch } : z)),
    }));

  const dirty = removed.length > 0 || JSON.stringify(draft) !== JSON.stringify(initial);
  const problem = problems(draft);
  const { gaps, overlaps } = coverage(draft);
  const lat = parseCoordinate(draft.lat);
  const lng = parseCoordinate(draft.lng);
  const hasOrigin = lat !== null && lng !== null && !Number.isNaN(lat) && !Number.isNaN(lng);
  const swapped = hasOrigin && !insideSudan({ lat, lng });

  const addZone = () =>
    setDraft((d) => {
      const from = Math.max(0, ...d.zones.map((z) => z.toM));
      const seq = Math.max(0, ...d.zones.map((z) => z.seq)) + 1;
      return {
        ...d,
        lengthM: Math.max(d.lengthM, from + 100),
        zones: [
          ...d.zones,
          {
            key: `new-${seq}-${Date.now()}`,
            id: null,
            seq,
            // Left empty on purpose: the admin names it (saving is blocked until then).
            nameAr: '',
            nameEn: '',
            fromM: from,
            toM: Math.max(from + 100, Math.min(from + 300, d.lengthM)),
            active: true,
            shops: 0,
          },
        ],
      };
    });

  const save = () =>
    run(
      () =>
        saveStreet({
          market: {
            id: data.market.id,
            name_ar: draft.marketAr,
            name_en: draft.marketEn,
            city_ar: draft.cityAr,
            city_en: draft.cityEn,
          },
          street: {
            id: data.street.id,
            name_ar: draft.streetAr,
            name_en: draft.streetEn,
            length_m: draft.lengthM,
            origin_lat: lat,
            origin_lng: lng,
          },
          zones: draft.zones.map((z) => ({
            id: z.id,
            seq: z.seq,
            name_ar: z.nameAr,
            name_en: z.nameEn,
            from_m: z.fromM,
            to_m: z.toM,
            is_active: z.active,
          })),
          removed,
        }),
      { success: s.saved },
    );

  return (
    <form
      className="flex flex-col gap-6 pb-24"
      onSubmit={(e) => {
        e.preventDefault();
        if (dirty && !problem) save();
      }}
    >
      <StreetStrip draft={draft} shops={data.shops} locale={locale} s={s} />

      <div className="grid grid-cols-1 gap-6 xl:grid-cols-2">
        <Card title={s.market} index={1}>
          <Pair
            label={s.marketName}
            ar={draft.marketAr}
            en={draft.marketEn}
            s={s}
            onAr={(v) => set({ marketAr: v })}
            onEn={(v) => set({ marketEn: v })}
          />
          <Pair
            label={s.city}
            ar={draft.cityAr}
            en={draft.cityEn}
            s={s}
            onAr={(v) => set({ cityAr: v })}
            onEn={(v) => set({ cityEn: v })}
          />
        </Card>

        <Card title={s.street} index={2}>
          <Pair
            label={s.streetName}
            ar={draft.streetAr}
            en={draft.streetEn}
            s={s}
            onAr={(v) => set({ streetAr: v })}
            onEn={(v) => set({ streetEn: v })}
          />
          <NumberInput
            label={s.length}
            value={draft.lengthM}
            min={1}
            onChange={(v) => set({ lengthM: v })}
          />
          <fieldset className="flex flex-col gap-2">
            <legend className="mb-1.5 flex items-center gap-2 text-sm font-medium">
              <MapPin className="size-4 text-muted-foreground" aria-hidden />
              {s.origin}
              <span
                className={cn(
                  'rounded-md px-1.5 py-0.5 text-xs font-semibold',
                  hasOrigin ? 'bg-success-soft text-success' : 'bg-warning-soft text-warning',
                )}
              >
                {hasOrigin ? s.originSet : '!'}
              </span>
            </legend>
            <div className="grid grid-cols-2 gap-2">
              <CoordInput
                axis="lat"
                label={s.lat}
                value={draft.lat}
                onChange={(v) => set({ lat: v })}
                onOther={(v) => set({ lng: v })}
                onPair={(a, b) => set({ lat: a, lng: b })}
              />
              <CoordInput
                axis="lng"
                label={s.lng}
                value={draft.lng}
                onChange={(v) => set({ lng: v })}
                onOther={(v) => set({ lat: v })}
                onPair={(a, b) => set({ lat: a, lng: b })}
              />
            </div>
            <p className="text-xs text-muted-foreground">{s.originHint}</p>
            {swapped && (
              <p className="flex items-start gap-1.5 text-xs text-warning" role="status">
                <TriangleAlert className="mt-0.5 size-3.5 shrink-0" aria-hidden />
                {s.outsideSudan}
              </p>
            )}
            {hasOrigin ? (
              <a
                href={`https://www.google.com/maps?q=${lat},${lng}`}
                target="_blank"
                rel="noreferrer"
                className="inline-flex w-fit items-center gap-1.5 text-sm font-medium underline-offset-2 hover:underline"
              >
                <ExternalLink className="size-4" />
                {s.openMap}
              </a>
            ) : (
              <p className="flex items-start gap-1.5 text-xs text-warning">
                <TriangleAlert className="mt-0.5 size-3.5 shrink-0" aria-hidden />
                {s.originMissing}
              </p>
            )}
          </fieldset>
        </Card>
      </div>

      <div className="rise" style={riseStyle(3)}>
        <Panel
          title={s.zones}
          actions={
            <Button type="button" variant="outline" className="h-9 px-3" onClick={addZone}>
              <Plus />
              {s.addZone}
            </Button>
          }
        >
          <p className="border-b px-4 py-3 text-sm text-muted-foreground">{s.zonesBody}</p>
          <ul className="divide-y">
            <AnimatePresence initial={false}>
              {draft.zones.map((z, i) => (
                <motion.li
                  key={z.key}
                  layout="position"
                  initial={{ opacity: 0, height: 0 }}
                  animate={{ opacity: 1, height: 'auto' }}
                  exit={{ opacity: 0, height: 0 }}
                  className="overflow-hidden"
                >
                  <div className="grid grid-cols-2 items-end gap-3 px-4 py-3 md:grid-cols-[2.5rem_1fr_1fr_6rem_6rem_auto]">
                    <span
                      className={cn(
                        'col-span-2 grid size-9 place-items-center rounded-lg text-sm font-bold text-white md:col-span-1',
                        zoneColours[i % zoneColours.length],
                      )}
                      aria-hidden
                    >
                      {z.seq}
                    </span>
                    <TextInput
                      label={`${s.arabic}`}
                      value={z.nameAr}
                      onChange={(v) => setZone(z.key, { nameAr: v })}
                      lang="ar"
                      warn={isPlaceholder(z)}
                    />
                    <TextInput
                      label={`${s.english}`}
                      value={z.nameEn}
                      onChange={(v) => setZone(z.key, { nameEn: v })}
                      lang="en"
                      warn={isPlaceholder(z)}
                    />
                    <NumberInput
                      label={s.from}
                      value={z.fromM}
                      min={0}
                      onChange={(v) => setZone(z.key, { fromM: v })}
                    />
                    <NumberInput
                      label={s.to}
                      value={z.toM}
                      min={1}
                      onChange={(v) => setZone(z.key, { toM: v })}
                    />
                    <div className="col-span-2 flex items-center justify-between gap-2 md:col-span-1 md:justify-end">
                      <span className="text-xs whitespace-nowrap text-muted-foreground">
                        {fill(s.shopsIn, { n: digits(z.shops) })}
                      </span>
                      <label className="flex cursor-pointer items-center gap-1.5 text-xs whitespace-nowrap">
                        <input
                          type="checkbox"
                          checked={z.active}
                          onChange={(e) => setZone(z.key, { active: e.target.checked })}
                          className="size-4 cursor-pointer accent-foreground"
                        />
                        {s.visible}
                      </label>
                      <Button
                        type="button"
                        variant="ghost"
                        size="icon-lg"
                        aria-label={z.shops > 0 ? s.removeBlocked : s.removeZone}
                        title={z.shops > 0 ? s.removeBlocked : s.removeZone}
                        disabled={z.shops > 0 || draft.zones.length <= 1}
                        className="text-destructive hover:text-destructive"
                        onClick={() => {
                          if (z.id) setRemoved((r) => [...r, z.id as string]);
                          setDraft((d) => ({
                            ...d,
                            zones: d.zones.filter((x) => x.key !== z.key),
                          }));
                        }}
                      >
                        <Trash2 />
                      </Button>
                    </div>
                  </div>
                </motion.li>
              ))}
            </AnimatePresence>
          </ul>
          <AnimatePresence>
            {(gaps.length > 0 || overlaps.length > 0 || draft.zones.some(isPlaceholder)) && (
              <motion.ul
                initial={{ opacity: 0, height: 0 }}
                animate={{ opacity: 1, height: 'auto' }}
                exit={{ opacity: 0, height: 0 }}
                className="flex flex-col gap-1 overflow-hidden border-t bg-warning-soft/30 px-4 py-3 text-sm text-warning"
              >
                {draft.zones.some(isPlaceholder) && <Warning>{s.placeholderNames}</Warning>}
                {gaps.map(([from, to]) => (
                  <Warning key={`g${from}`}>
                    {fill(s.gap, { from: digits(from), to: digits(to) })}
                  </Warning>
                ))}
                {overlaps.map(([a, b]) => (
                  <Warning key={`o${a}-${b}`}>{fill(s.overlap, { a, b })}</Warning>
                ))}
              </motion.ul>
            )}
          </AnimatePresence>
        </Panel>
      </div>

      <AnimatePresence>
        {dirty && (
          <motion.div
            initial={{ y: 80, opacity: 0 }}
            animate={{ y: 0, opacity: 1 }}
            exit={{ y: 80, opacity: 0 }}
            transition={{ type: 'spring', stiffness: 420, damping: 34 }}
            className="fixed inset-x-4 bottom-4 z-40 mx-auto flex max-w-2xl flex-wrap items-center gap-3 rounded-2xl bg-foreground px-4 py-3 text-background shadow-2xl lg:start-68"
          >
            <span className="flex flex-1 items-center gap-2 text-sm font-medium" aria-live="polite">
              {problem ? (
                <>
                  <CircleAlert className="size-4 shrink-0 text-red-300" aria-hidden />
                  {t.errors[problem as keyof Labels['errors']]}
                </>
              ) : (
                s.unsaved
              )}
            </span>
            <Button
              type="button"
              variant="ghost"
              className="h-9 px-3 text-background hover:bg-background/10 hover:text-background"
              onClick={() => {
                setDraft(initial);
                setRemoved([]);
              }}
            >
              <RotateCcw />
              {t.common.discard}
            </Button>
            <Button type="submit" className="h-9 px-4" disabled={pending || problem !== null}>
              <Save />
              {pending ? t.common.saving : s.save}
            </Button>
          </motion.div>
        )}
      </AnimatePresence>
    </form>
  );
}

/** The street drawn to scale: zones as bands, shops as dots; it follows every edit. */
function StreetStrip({
  draft,
  shops,
  locale,
  s,
}: {
  draft: Draft;
  shops: StreetData['shops'];
  locale: Locale;
  s: Dictionary['street'];
}) {
  const [hover, setHover] = useState<string | null>(null);
  const length = Math.max(1, draft.lengthM, ...draft.zones.map((z) => z.toM));
  const pct = (m: number) => `${(Math.min(Math.max(m, 0), length) / length) * 100}%`;
  const ticks = [0, 0.25, 0.5, 0.75, 1].map((f) => Math.round(f * length));
  const hovered = shops.find((x) => x.id === hover);
  return (
    <section className="rise rounded-xl bg-card p-4 ring-1 ring-foreground/10" aria-label={s.strip}>
      <div className="mb-3 flex items-center justify-between text-sm">
        <span className="font-semibold">
          {named({ ar: draft.streetAr, en: draft.streetEn }, locale) || '—'}
        </span>
        <span className="text-muted-foreground">
          {fill(s.metres, { n: digits(draft.lengthM || 0) })}
        </span>
      </div>
      <div className="relative h-14 rounded-lg bg-muted">
        {draft.zones.map((z, i) => (
          <motion.div
            key={z.key}
            className={cn(
              'absolute inset-y-1 flex items-center justify-center overflow-hidden rounded-md text-xs font-semibold text-white',
              zoneColours[i % zoneColours.length],
              !z.active && 'opacity-30',
            )}
            initial={false}
            animate={{
              insetInlineStart: pct(z.fromM),
              width: `calc(${pct(z.toM - z.fromM)} - 2px)`,
            }}
            transition={{ type: 'spring', stiffness: 260, damping: 30 }}
          >
            <span className="truncate px-1">{named({ ar: z.nameAr, en: z.nameEn }, locale)}</span>
          </motion.div>
        ))}
        {shops.map((shop) => (
          <button
            key={shop.id}
            type="button"
            onMouseEnter={() => setHover(shop.id)}
            onMouseLeave={() => setHover(null)}
            onFocus={() => setHover(shop.id)}
            onBlur={() => setHover(null)}
            aria-label={`${named(shop.name, locale)} · ${fill(s.metres, { n: digits(shop.posM) })}`}
            className="absolute -bottom-1.5 size-3 -translate-x-1/2 cursor-pointer rounded-full border-2 border-card bg-foreground transition-transform hover:scale-150 focus-visible:scale-150 focus-visible:outline-none rtl:translate-x-1/2"
            style={{ insetInlineStart: pct(shop.posM) }}
          />
        ))}
        <AnimatePresence>
          {hovered && (
            <motion.div
              key={hovered.id}
              initial={{ opacity: 0, y: 4 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0 }}
              className="pointer-events-none absolute -bottom-10 z-10 -translate-x-1/2 rounded-md bg-foreground px-2 py-1 text-xs whitespace-nowrap text-background shadow rtl:translate-x-1/2"
              style={{ insetInlineStart: pct(hovered.posM) }}
            >
              {named(hovered.name, locale)} · {fill(s.metres, { n: digits(hovered.posM) })}
            </motion.div>
          )}
        </AnimatePresence>
      </div>
      <div className="relative mt-5 h-4 text-[11px] text-muted-foreground tabular-nums">
        {ticks.map((m, i) => (
          <span
            key={m}
            className={cn(
              'absolute',
              i === 0
                ? ''
                : i === ticks.length - 1
                  ? '-translate-x-full rtl:translate-x-full'
                  : '-translate-x-1/2 rtl:translate-x-1/2',
            )}
            style={{ insetInlineStart: pct(m) }}
          >
            {m}
          </span>
        ))}
      </div>
    </section>
  );
}

function Card({ title, index, children }: { title: string; index: number; children: ReactNode }) {
  return (
    <div className="rise" style={riseStyle(index)}>
      <Panel title={title} className="h-full">
        <div className="flex flex-col gap-4 p-4">{children}</div>
      </Panel>
    </div>
  );
}

function Warning({ children }: { children: ReactNode }) {
  return (
    <li className="flex items-start gap-2">
      <TriangleAlert className="mt-0.5 size-4 shrink-0" aria-hidden />
      {children}
    </li>
  );
}

const inputClass =
  'h-10 w-full rounded-lg border border-input bg-card px-3 text-base outline-none focus-visible:border-ring focus-visible:ring-2 focus-visible:ring-ring/30 aria-invalid:border-destructive';

function Pair({
  label,
  ar,
  en,
  s,
  onAr,
  onEn,
}: {
  label: string;
  ar: string;
  en: string;
  s: Dictionary['street'];
  onAr: (v: string) => void;
  onEn: (v: string) => void;
}) {
  return (
    <fieldset>
      <legend className="mb-1.5 text-sm font-medium">{label}</legend>
      <div className="grid grid-cols-1 gap-2 sm:grid-cols-2">
        <TextInput label={s.arabic} value={ar} onChange={onAr} lang="ar" />
        <TextInput label={s.english} value={en} onChange={onEn} lang="en" />
      </div>
    </fieldset>
  );
}

function TextInput({
  label,
  value,
  onChange,
  lang,
  warn,
}: {
  label: string;
  value: string;
  onChange: (v: string) => void;
  lang: 'ar' | 'en';
  warn?: boolean;
}) {
  const id = useId();
  return (
    <div className="flex flex-col gap-1">
      <label htmlFor={id} className="text-xs text-muted-foreground">
        {label}
      </label>
      <input
        id={id}
        lang={lang}
        dir={lang === 'ar' ? 'rtl' : 'ltr'}
        maxLength={80}
        value={value}
        onChange={(e) => onChange(e.target.value)}
        aria-invalid={!value.trim() || undefined}
        className={cn(inputClass, warn && 'border-warning')}
      />
    </div>
  );
}

function NumberInput({
  label,
  value,
  min,
  onChange,
}: {
  label: string;
  value: number;
  min?: number;
  onChange: (v: number) => void;
}) {
  const id = useId();
  return (
    <div className="flex flex-col gap-1">
      <label htmlFor={id} className="text-xs text-muted-foreground">
        {label}
      </label>
      <NumberText
        id={id}
        integer
        value={value}
        onChange={onChange}
        aria-invalid={Number.isNaN(value) || (min !== undefined && value < min) || undefined}
        className={cn(inputClass, 'tabular-nums')}
      />
    </div>
  );
}

/**
 * A latitude or longitude box that takes the text however it arrives (pasted, a phone
 * keyboard's clipboard bar, typed): Arabic digits, a decimal comma, Google Maps'
 * 15°34'43.5"N. A whole point fills both boxes; a half marked for the other box (E/W in
 * the latitude box, N/S in the longitude box) goes there. Leaving the box shows the
 * number as it will be saved, with at most 6 decimals.
 */
function CoordInput({
  axis,
  label,
  value,
  onChange,
  onOther,
  onPair,
}: {
  axis: Axis;
  label: string;
  value: string;
  onChange: (v: string) => void;
  onOther: (v: string) => void;
  onPair: (lat: string, lng: string) => void;
}) {
  const id = useId();
  const n = parseCoordinate(value);
  const take = (text: string) => {
    const point = parsePoint(text);
    if (point) {
      onPair(coordinateText(point.lat), coordinateText(point.lng));
      return true;
    }
    const half = readCoordinate(text);
    if (half.axis && half.axis !== axis && half.value !== null && !Number.isNaN(half.value)) {
      onOther(coordinateText(half.value));
      // It belonged to the other box: don't leave it showing here too.
      if (text === value) onChange('');
      return true;
    }
    return false;
  };
  return (
    <div className="flex flex-col gap-1">
      <label htmlFor={id} className="text-xs text-muted-foreground">
        {label}
      </label>
      <input
        id={id}
        dir="ltr"
        inputMode="decimal"
        autoComplete="off"
        spellCheck={false}
        value={value}
        onChange={(e) => {
          // Text that arrives in one go (a phone keyboard's clipboard bar, drag and drop) is
          // sorted at once; typing waits for the box to be left, so "15.5007, 32" isn't split
          // half-way.
          const pasted = e.target.value.length - value.length > 1;
          if (!(pasted && take(e.target.value))) onChange(e.target.value);
        }}
        onBlur={() => {
          if (take(value)) return;
          if (n !== null && !Number.isNaN(n) && coordinateText(n) !== value) {
            onChange(coordinateText(n));
          }
        }}
        onPaste={(e) => {
          // A paste replaces what's in the box, rather than joining on to it.
          if (take(e.clipboardData.getData('text'))) e.preventDefault();
        }}
        aria-invalid={(n !== null && Number.isNaN(n)) || undefined}
        className={cn(inputClass, 'tabular-nums')}
      />
    </div>
  );
}
