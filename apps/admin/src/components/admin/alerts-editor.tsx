'use client';

import { BellRing, MessageSquareText, Pencil, Search } from 'lucide-react';
import { useId, useMemo, useState } from 'react';
import { Button } from '@/components/ui/button';
import type { Dictionary } from '@/i18n/dictionaries';
import { saveAlertWording } from '@/lib/actions/admin';
import type { AlertApp, AlertWording, Wording } from '@/lib/data/alerts';
import { searchKey } from '@/lib/format';
import { Modal } from './interactive';
import { useAction } from './use-action';
import { EmptyState, Panel, StatusBadge, Table, Td, Th } from './ui';

const inputClass =
  'w-full rounded-lg border border-input bg-card px-3 py-2 text-base outline-none focus-visible:border-ring focus-visible:ring-2 focus-visible:ring-ring/30';

/**
 * The wording of every alert in both languages, as push and the apps' inboxes show it
 * (D-101). Admins edit it here; `{name}` placeholders are filled from each alert's data,
 * so only the ones an alert already uses are allowed.
 */
export function AlertsEditor({
  rows,
  d,
  common,
  errors,
}: {
  rows: AlertWording[];
  d: Dictionary['alerts'];
  common: Dictionary['common'];
  errors: Dictionary['errors'];
}) {
  const [query, setQuery] = useState('');
  const [editing, setEditing] = useState<AlertWording | null>(null);
  const q = searchKey(query);
  const shown = useMemo(
    () =>
      rows.filter(
        (r) =>
          !q ||
          searchKey(`${r.code} ${r.ar.title} ${r.ar.body} ${r.en.title} ${r.en.body}`).includes(q),
      ),
    [rows, q],
  );
  const groups: { app: AlertApp; label: string }[] = [
    { app: 'buyer', label: d.appBuyer },
    { app: 'partner', label: d.appPartner },
    { app: 'admin', label: d.appAdmin },
  ];

  return (
    <>
      <div className="relative max-w-md">
        <Search
          className="pointer-events-none absolute start-3 top-1/2 size-4 -translate-y-1/2 text-muted-foreground"
          aria-hidden
        />
        <input
          type="search"
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          placeholder={d.search}
          aria-label={d.search}
          className={`${inputClass} ps-9`}
        />
      </div>
      {shown.length === 0 && (
        <Panel>
          <EmptyState icon={<BellRing />} title={d.empty} />
        </Panel>
      )}
      {groups.map(({ app, label }) => {
        const list = shown.filter((r) => r.app === app);
        if (list.length === 0) return null;
        return (
          <Panel key={app} title={label}>
            <Table>
              <thead>
                <tr>
                  <Th>{d.code}</Th>
                  <Th>{d.arabic}</Th>
                  <Th>{d.english}</Th>
                  <Th className="w-0">
                    <span className="sr-only">{common.edit}</span>
                  </Th>
                </tr>
              </thead>
              <tbody>
                {list.map((r) => (
                  <tr key={r.code} className="align-top hover:bg-muted/40">
                    <Td className="whitespace-nowrap">
                      <code className="text-xs font-semibold" dir="ltr">
                        {r.code}
                      </code>
                      {r.sms && (
                        <div className="mt-1">
                          <StatusBadge tone="info">{d.sms}</StatusBadge>
                        </div>
                      )}
                    </Td>
                    <Td dir="rtl" lang="ar" className="min-w-56">
                      <div className="font-medium">{r.ar.title}</div>
                      <div className="text-muted-foreground">{r.ar.body}</div>
                    </Td>
                    <Td dir="ltr" lang="en" className="min-w-56">
                      <div className="font-medium">{r.en.title}</div>
                      <div className="text-muted-foreground">{r.en.body}</div>
                    </Td>
                    <Td>
                      <Button
                        variant="ghost"
                        size="sm"
                        onClick={() => setEditing(r)}
                        aria-label={`${common.edit} ${r.code}`}
                      >
                        <Pencil aria-hidden />
                        {common.edit}
                      </Button>
                    </Td>
                  </tr>
                ))}
              </tbody>
            </Table>
          </Panel>
        );
      })}
      {editing && (
        <EditDialog
          key={editing.code}
          row={editing}
          onClose={() => setEditing(null)}
          d={d}
          common={common}
          errors={errors}
        />
      )}
    </>
  );
}

function EditDialog({
  row,
  onClose,
  d,
  common,
  errors,
}: {
  row: AlertWording;
  onClose: () => void;
  d: Dictionary['alerts'];
  common: Dictionary['common'];
  errors: Dictionary['errors'];
}) {
  const [ar, setAr] = useState<Wording>(row.ar);
  const [en, setEn] = useState<Wording>(row.en);
  const { pending, run } = useAction(errors);
  const id = useId();
  const used = (w: Wording) =>
    [...`${w.title} ${w.body}`.matchAll(/\{([a-z_]+)\}/g)].map((m) => m[1]);
  const unknown = [...new Set([...used(ar), ...used(en)])].filter(
    (p) => !row.placeholders.includes(p as string),
  );
  const valid =
    [ar, en].every(
      (w) => w.title.trim() && w.title.length <= 100 && w.body.trim() && w.body.length <= 300,
    ) && unknown.length === 0;

  const fields = (lang: 'ar' | 'en', value: Wording, set: (w: Wording) => void) => (
    <fieldset className="flex flex-col gap-2" dir={lang === 'ar' ? 'rtl' : 'ltr'} lang={lang}>
      <legend className="mb-1 text-sm font-semibold">{lang === 'ar' ? d.arabic : d.english}</legend>
      <label className="sr-only" htmlFor={`${id}-${lang}-title`}>
        {d.titleLabel}
      </label>
      <input
        id={`${id}-${lang}-title`}
        value={value.title}
        maxLength={100}
        onChange={(e) => set({ ...value, title: e.target.value })}
        placeholder={d.titleLabel}
        className={inputClass}
      />
      <label className="sr-only" htmlFor={`${id}-${lang}-body`}>
        {d.bodyLabel}
      </label>
      <textarea
        id={`${id}-${lang}-body`}
        value={value.body}
        maxLength={300}
        rows={3}
        onChange={(e) => set({ ...value, body: e.target.value })}
        placeholder={d.bodyLabel}
        className={`${inputClass} resize-none`}
      />
    </fieldset>
  );

  return (
    <Modal open onOpenChange={(o) => !o && onClose()} title={row.code} description={d.editHint}>
      <form
        className="flex flex-col gap-4"
        onSubmit={(e) => {
          e.preventDefault();
          if (!valid) return;
          run(() => saveAlertWording(row.code, { ar, en }, row.placeholders), {
            success: d.saved,
            onDone: onClose,
          });
        }}
      >
        {fields('ar', ar, setAr)}
        {fields('en', en, setEn)}
        <div className="flex flex-wrap items-center gap-2 text-xs text-muted-foreground">
          <MessageSquareText className="size-4" aria-hidden />
          {row.placeholders.length ? (
            <>
              {d.placeholders}
              {row.placeholders.map((p) => (
                <code key={p} dir="ltr" className="rounded bg-muted px-1.5 py-0.5 text-foreground">
                  {`{${p}}`}
                </code>
              ))}
            </>
          ) : (
            d.noPlaceholders
          )}
        </div>
        {unknown.length > 0 && (
          <p role="alert" className="text-sm text-destructive">
            {errors.UNKNOWN_PLACEHOLDER}
          </p>
        )}
        <div className="flex flex-wrap justify-end gap-2">
          <Button type="button" variant="outline" className="h-10 px-4" onClick={onClose}>
            {common.cancel}
          </Button>
          <Button type="submit" className="h-10 px-4" disabled={pending || !valid}>
            {common.save}
          </Button>
        </div>
      </form>
    </Modal>
  );
}
