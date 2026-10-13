'use client';

import type { Json } from '@alghali/db-types';
import { Plus, RotateCcw, Save, TriangleAlert, X } from 'lucide-react';
import { AnimatePresence, motion } from 'motion/react';
import { useId, useState, useTransition, type ReactNode } from 'react';
import { cn } from 'cn';
import { useToast } from '@/components/motion';
import { Button } from '@/components/ui/button';
import type { Dictionary } from '@/i18n/dictionaries';
import { saveSettings } from '@/lib/actions/admin';
import { fill } from '@/lib/format';
import { errorText } from './use-action';
import { Panel, riseStyle } from './ui';

type Labels = Dictionary['settings'];
type Values = Record<string, Json>;
type Band = { max_km: number; sdg: number };

type NumberSpec = {
  key: string;
  label: keyof Labels;
  min?: number;
  max?: number;
  step?: number;
  int?: boolean;
};

const sections: { title: keyof Labels; fields: NumberSpec[] }[] = [
  {
    title: 'fees',
    fields: [
      { key: 'commission_percent', label: 'commission', min: 0, max: 50, step: 0.5 },
      { key: 'booking_fee_sdg', label: 'bookingFee', min: 0, step: 500, int: true },
      { key: 'mobile_deposit_sdg', label: 'deposit', min: 0, step: 500, int: true },
    ],
  },
  {
    title: 'timing',
    fields: [
      { key: 'slot_hold_minutes', label: 'hold', min: 1, int: true },
      { key: 'payment_window_minutes', label: 'paymentWindow', min: 1, int: true },
      { key: 'tech_accept_timeout_minutes', label: 'techTimeout', min: 1, int: true },
      { key: 'cancel_cutoff_hours', label: 'cancelCutoff', min: 0, int: true },
      { key: 'return_window_days', label: 'returnWindow', min: 0, int: true },
      { key: 'part_ready_buffer_minutes', label: 'partReady', min: 0, int: true },
      { key: 'travel_buffer_minutes', label: 'travelBuffer', min: 0, int: true },
      { key: 'booking_lookahead_days', label: 'lookahead', min: 1, int: true },
      { key: 'auto_complete_days', label: 'autoComplete', min: 0, int: true },
    ],
  },
];

const textFields: {
  title: keyof Labels;
  fields: { key: string; label: keyof Labels; ltr?: boolean }[];
}[] = [
  {
    title: 'bankak',
    fields: [
      { key: 'bankak_account_name', label: 'accountName' },
      { key: 'bankak_account_number', label: 'accountNumber', ltr: true },
    ],
  },
  {
    title: 'support',
    fields: [
      { key: 'support_phone', label: 'supportPhone', ltr: true },
      { key: 'support_whatsapp', label: 'supportWhatsapp', ltr: true },
    ],
  },
];

const same = (a: Json | undefined, b: Json | undefined) => JSON.stringify(a) === JSON.stringify(b);
const isPlaceholder = (v: Json | undefined) => typeof v === 'string' && /^TODO\b/i.test(v);

/** Mirrors `validate_setting()` so mistakes show before saving; the database checks again. */
function invalid(key: string, value: Json | undefined, spec?: NumberSpec): boolean {
  if (spec) {
    if (typeof value !== 'number' || Number.isNaN(value)) return true;
    if (spec.min !== undefined && value < spec.min) return true;
    if (spec.max !== undefined && value > spec.max) return true;
    return Boolean(spec.int && !Number.isInteger(value));
  }
  if (key.endsWith('_bands')) {
    const bands = value as Band[];
    return (
      !Array.isArray(bands) ||
      bands.length === 0 ||
      bands.some(
        (b, i) =>
          !(b.max_km > (i ? bands[i - 1].max_km : 0)) || !(b.sdg >= 0) || !Number.isInteger(b.sdg),
      )
    );
  }
  if (key === 'payout_schedule') return false;
  return typeof value !== 'string' || value.length > 100;
}

const allSpecs = new Map(sections.flatMap((s) => s.fields).map((f) => [f.key, f]));

export function SettingsForm({
  settings,
  lastChanged,
  d,
  common,
  errors,
  weekdays,
}: {
  settings: Values;
  lastChanged?: string;
  d: Labels;
  common: Dictionary['common'];
  errors: Dictionary['errors'];
  weekdays: string[];
}) {
  // `baseline` is what the database holds; it moves forward as saves succeed.
  const [baseline, setBaseline] = useState<Values>(settings);
  const [values, setValues] = useState<Values>(settings);
  const [failed, setFailed] = useState<Set<string>>(new Set());
  const [saving, startSaving] = useTransition();
  const toast = useToast();

  const set = (key: string, value: Json) => {
    setValues((v) => ({ ...v, [key]: value }));
    setFailed((f) => {
      if (!f.has(key)) return f;
      const next = new Set(f);
      next.delete(key);
      return next;
    });
  };
  const changed = Object.keys(values).filter((k) => !same(values[k], baseline[k]));
  const bad = new Set(changed.filter((k) => invalid(k, values[k], allSpecs.get(k))));

  const save = () =>
    startSaving(async () => {
      const changes = changed.map((key) => ({ key, value: values[key] }));
      try {
        const result = await saveSettings(changes);
        const failedKeys = new Set(result.failed);
        setBaseline((b) => {
          const next = { ...b };
          for (const { key, value } of changes) if (!failedKeys.has(key)) next[key] = value;
          return next;
        });
        setFailed(failedKeys);
        if (result.ok) toast.success(d.saved);
        else toast.error(result.failed.length ? d.notSaved : errorText(errors, result.error));
      } catch {
        toast.error(errors.FAILED);
      }
    });

  const fieldState = (key: string) => ({
    changed: changed.includes(key),
    error: failed.has(key) || bad.has(key),
  });

  return (
    <form
      onSubmit={(e) => {
        e.preventDefault();
        if (changed.length && !bad.size) save();
      }}
      className="flex flex-col gap-6 pb-24"
    >
      {lastChanged && <p className="-mt-3 text-xs text-muted-foreground">{lastChanged}</p>}

      {sections.map((s, i) => (
        <Section key={s.title} title={d[s.title] as string} index={i}>
          {s.fields.map((f) => (
            <Field
              key={f.key}
              label={d[f.label] as string}
              {...fieldState(f.key)}
              changedLabel={d.changed}
            >
              {(id) => (
                <input
                  id={id}
                  type="number"
                  inputMode={f.int ? 'numeric' : 'decimal'}
                  min={f.min}
                  max={f.max}
                  step={f.step ?? 1}
                  value={
                    typeof values[f.key] === 'number' && !Number.isNaN(values[f.key])
                      ? (values[f.key] as number)
                      : ''
                  }
                  onChange={(e) => set(f.key, e.target.value === '' ? NaN : Number(e.target.value))}
                  aria-invalid={fieldState(f.key).error || undefined}
                  className={inputClass(fieldState(f.key).error)}
                />
              )}
            </Field>
          ))}
        </Section>
      ))}

      {(['travel_fee_bands', 'delivery_fee_bands'] as const).map((key, i) => (
        <Section
          key={key}
          title={key === 'travel_fee_bands' ? d.travelBands : d.deliveryBands}
          index={sections.length + i}
          wide
        >
          <Bands
            bands={(values[key] as Band[] | undefined) ?? []}
            onChange={(b) => set(key, b)}
            d={d}
            {...fieldState(key)}
          />
        </Section>
      ))}

      {textFields.map((s, i) => (
        <Section key={s.title} title={d[s.title] as string} index={sections.length + 2 + i}>
          {s.fields.map((f) => (
            <Field
              key={f.key}
              label={d[f.label] as string}
              {...fieldState(f.key)}
              changedLabel={d.changed}
              warning={isPlaceholder(values[f.key]) ? d.placeholder : undefined}
            >
              {(id) => (
                <input
                  id={id}
                  dir={f.ltr ? 'ltr' : undefined}
                  maxLength={100}
                  value={typeof values[f.key] === 'string' ? (values[f.key] as string) : ''}
                  onChange={(e) => set(f.key, e.target.value)}
                  aria-invalid={fieldState(f.key).error || undefined}
                  className={inputClass(fieldState(f.key).error)}
                />
              )}
            </Field>
          ))}
        </Section>
      ))}

      <Section title={d.payoutSchedule} index={sections.length + 4}>
        <PayoutSchedule
          value={
            (values.payout_schedule as { frequency: string; weekday: number } | undefined) ?? {
              frequency: 'weekly',
              weekday: 0,
            }
          }
          onChange={(v) => set('payout_schedule', v)}
          d={d}
          weekdays={weekdays}
          {...fieldState('payout_schedule')}
        />
      </Section>

      {/* Appears only when something changed; slides up from the bottom of the page. */}
      <AnimatePresence>
        {changed.length > 0 && (
          <motion.div
            initial={{ y: 80, opacity: 0 }}
            animate={{ y: 0, opacity: 1 }}
            exit={{ y: 80, opacity: 0 }}
            transition={{ type: 'spring', stiffness: 420, damping: 34 }}
            className="fixed inset-x-4 bottom-4 z-40 mx-auto flex max-w-2xl flex-wrap items-center gap-3 rounded-2xl bg-foreground px-4 py-3 text-background shadow-2xl lg:start-68"
          >
            <span className="flex-1 text-sm font-medium" aria-live="polite">
              {fill(d.unsaved, { n: changed.length })}
            </span>
            <Button
              type="button"
              variant="ghost"
              className="h-9 px-3 text-background hover:bg-background/10 hover:text-background"
              onClick={() => {
                setValues(baseline);
                setFailed(new Set());
              }}
            >
              <RotateCcw />
              {common.discard}
            </Button>
            <Button type="submit" className="h-9 px-4" disabled={saving || bad.size > 0}>
              <Save />
              {saving ? common.saving : d.save}
            </Button>
          </motion.div>
        )}
      </AnimatePresence>
    </form>
  );
}

function Section({
  title,
  index,
  wide,
  children,
}: {
  title: string;
  index: number;
  wide?: boolean;
  children: ReactNode;
}) {
  return (
    <div className="rise" style={riseStyle(index)}>
      <Panel title={title}>
        <div className={cn('grid grid-cols-1 gap-4 p-4', !wide && 'sm:grid-cols-2 xl:grid-cols-3')}>
          {children}
        </div>
      </Panel>
    </div>
  );
}

function inputClass(error: boolean) {
  return cn(
    'h-10 w-full rounded-lg border bg-card px-3 text-base tabular-nums outline-none transition-[border-color,box-shadow] focus-visible:ring-2',
    error
      ? 'border-destructive focus-visible:ring-destructive/30'
      : 'border-input focus-visible:border-ring focus-visible:ring-ring/30',
  );
}

function Field({
  label,
  changed,
  error,
  changedLabel,
  warning,
  children,
}: {
  label: string;
  changed: boolean;
  error: boolean;
  changedLabel: string;
  warning?: string;
  children: (id: string) => ReactNode;
}) {
  const id = useId();
  return (
    <div className="flex flex-col gap-1.5">
      <label htmlFor={id} className="flex items-center gap-2 text-sm font-medium">
        <span className={cn('flex-1', error && 'text-destructive')}>{label}</span>
        <AnimatePresence>
          {changed && (
            <motion.span
              initial={{ opacity: 0, scale: 0.6 }}
              animate={{ opacity: 1, scale: 1 }}
              exit={{ opacity: 0, scale: 0.6 }}
              className="inline-flex items-center gap-1 text-xs font-semibold text-info"
            >
              <span className="size-1.5 rounded-full bg-info" />
              {changedLabel}
            </motion.span>
          )}
        </AnimatePresence>
      </label>
      {children(id)}
      {warning && (
        <p className="flex items-center gap-1.5 text-xs text-warning">
          <TriangleAlert className="size-3.5" aria-hidden />
          {warning}
        </p>
      )}
    </div>
  );
}

function Bands({
  bands,
  onChange,
  d,
  changed,
  error,
}: {
  bands: Band[];
  onChange: (bands: Band[]) => void;
  d: Labels;
  changed: boolean;
  error: boolean;
}) {
  const update = (i: number, patch: Partial<Band>) =>
    onChange(bands.map((b, j) => (j === i ? { ...b, ...patch } : b)));
  const num = (s: string) => (s === '' ? NaN : Number(s));
  return (
    <div
      className={cn(
        'flex flex-col gap-2 rounded-lg',
        changed && 'ring-2 ring-info/30 ring-offset-4 ring-offset-card',
      )}
    >
      <div className="grid grid-cols-[1fr_1fr_2.5rem] gap-2 text-xs font-semibold text-muted-foreground">
        <span>{d.bandKm}</span>
        <span>{d.bandFee}</span>
      </div>
      <AnimatePresence initial={false}>
        {bands.map((b, i) => (
          <motion.div
            key={i}
            layout
            initial={{ opacity: 0, height: 0 }}
            animate={{ opacity: 1, height: 'auto' }}
            exit={{ opacity: 0, height: 0 }}
            className="grid grid-cols-[1fr_1fr_2.5rem] items-center gap-2"
          >
            <input
              type="number"
              min={0}
              step={0.5}
              aria-label={`${d.bandKm} ${i + 1}`}
              value={Number.isNaN(b.max_km) ? '' : b.max_km}
              onChange={(e) => update(i, { max_km: num(e.target.value) })}
              className={inputClass(error)}
            />
            <input
              type="number"
              min={0}
              step={500}
              aria-label={`${d.bandFee} ${i + 1}`}
              value={Number.isNaN(b.sdg) ? '' : b.sdg}
              onChange={(e) => update(i, { sdg: num(e.target.value) })}
              className={inputClass(error)}
            />
            <Button
              type="button"
              variant="ghost"
              size="icon-lg"
              aria-label={d.removeBand}
              disabled={bands.length <= 1}
              onClick={() => onChange(bands.filter((_, j) => j !== i))}
            >
              <X />
            </Button>
          </motion.div>
        ))}
      </AnimatePresence>
      <div className="flex flex-wrap items-center justify-between gap-2">
        <p className={cn('text-xs', error ? 'text-destructive' : 'text-muted-foreground')}>
          {d.bandsHint}
        </p>
        <Button
          type="button"
          variant="outline"
          className="h-9 px-3"
          onClick={() => {
            const last = bands[bands.length - 1];
            onChange([...bands, { max_km: (last?.max_km ?? 0) + 5, sdg: last?.sdg ?? 0 }]);
          }}
        >
          <Plus />
          {d.addBand}
        </Button>
      </div>
    </div>
  );
}

function PayoutSchedule({
  value,
  onChange,
  d,
  weekdays,
  changed,
  error,
}: {
  value: { frequency: string; weekday: number };
  onChange: (v: { frequency: string; weekday: number }) => void;
  d: Labels;
  weekdays: string[];
  changed: boolean;
  error: boolean;
}) {
  const freqId = useId();
  const dayId = useId();
  const select = cn(inputClass(error), 'cursor-pointer', changed && 'border-info');
  return (
    <>
      <div className="flex flex-col gap-1.5">
        <label htmlFor={freqId} className="text-sm font-medium">
          {d.frequency}
        </label>
        <select
          id={freqId}
          value={value.frequency}
          onChange={(e) => onChange({ ...value, frequency: e.target.value })}
          className={select}
        >
          <option value="weekly">{d.weekly}</option>
          <option value="biweekly">{d.biweekly}</option>
          <option value="monthly">{d.monthly}</option>
        </select>
      </div>
      <div className="flex flex-col gap-1.5">
        <label htmlFor={dayId} className="text-sm font-medium">
          {d.payDay}
        </label>
        <select
          id={dayId}
          value={value.weekday}
          onChange={(e) => onChange({ ...value, weekday: Number(e.target.value) })}
          className={select}
        >
          {weekdays.map((w, i) => (
            <option key={w} value={i}>
              {w}
            </option>
          ))}
        </select>
      </div>
    </>
  );
}
