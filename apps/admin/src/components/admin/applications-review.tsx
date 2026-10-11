'use client';

import { Tabs } from '@base-ui/react/tabs';
import { FileCheck, FileX, Store, Wrench } from 'lucide-react';
import { useState } from 'react';
import { Button } from '@/components/ui/button';
import type { Locale } from '@/i18n/config';
import type { Dictionary } from '@/i18n/dictionaries';
import { applications, DEMO_NOW, tr, type Application } from '@/lib/demo/data';
import { ago, fill } from '@/lib/format';
import { Notice } from './interactive';
import { CountPill, StatusBadge, tabClass } from './ui';

type Labels = Dictionary['approvals'];
type Common = Dictionary['common'];
type Decision = 'approved' | 'rejected';

const docLabel = {
  license: 'docLicense',
  id: 'docId',
  photos: 'docPhotos',
  certificate: 'docCertificate',
} as const;
const modeLabel = { bay: 'modeBay', mobile: 'modeMobile', both: 'modeBoth' } as const;

export function ApplicationsReview({
  locale,
  d,
  common,
  statusLabels,
}: {
  locale: Locale;
  d: Labels;
  common: Common;
  statusLabels: Dictionary['status']['application'];
}) {
  const [decisions, setDecisions] = useState<Record<string, Decision>>({});
  const [notice, setNotice] = useState<string | null>(null);

  const decide = (id: string, decision: Decision) => {
    setDecisions((s) => ({ ...s, [id]: decision }));
    setNotice(decision === 'approved' ? d.approved : d.rejectedToast);
  };

  const groups = [
    { value: 'shop', label: d.shops, items: applications.filter((a) => a.kind === 'shop') },
    {
      value: 'technician',
      label: d.technicians,
      items: applications.filter((a) => a.kind === 'technician'),
    },
  ];

  return (
    <div className="flex flex-col gap-4">
      <Notice message={notice} onDismiss={() => setNotice(null)} closeLabel={common.close} />
      <Tabs.Root defaultValue="shop">
        <Tabs.List className="flex gap-1 border-b">
          {groups.map((g) => {
            const open = g.items.filter((a) => !decisions[a.id]).length;
            return (
              <Tabs.Tab key={g.value} value={g.value} className={tabClass}>
                {g.label}
                <CountPill>{open}</CountPill>
              </Tabs.Tab>
            );
          })}
        </Tabs.List>
        {groups.map((g) => (
          <Tabs.Panel key={g.value} value={g.value} className="pt-5 outline-none">
            {g.items.length === 0 ? (
              <p className="py-12 text-center text-sm text-muted-foreground">{d.empty}</p>
            ) : (
              <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
                {g.items.map((a) => (
                  <ApplicationCard
                    key={a.id}
                    a={a}
                    locale={locale}
                    d={d}
                    common={common}
                    decision={decisions[a.id]}
                    statusLabels={statusLabels}
                    onDecide={(decision) => decide(a.id, decision)}
                  />
                ))}
              </div>
            )}
          </Tabs.Panel>
        ))}
      </Tabs.Root>
    </div>
  );
}

function ApplicationCard({
  a,
  locale,
  d,
  common,
  decision,
  statusLabels,
  onDecide,
}: {
  a: Application;
  locale: Locale;
  d: Labels;
  common: Common;
  decision?: Decision;
  statusLabels: Dictionary['status']['application'];
  onDecide: (decision: Decision) => void;
}) {
  const missing = a.docs.filter((doc) => !doc.ok);
  const Icon = a.kind === 'shop' ? Store : Wrench;
  return (
    <article className="flex flex-col rounded-xl bg-card ring-1 ring-foreground/10">
      <div className="flex items-start gap-3 p-4">
        <span className="grid size-10 shrink-0 place-items-center rounded-lg bg-muted">
          <Icon className="size-5" aria-hidden />
        </span>
        <div className="min-w-0 flex-1">
          <h3 className="text-base font-semibold">{tr(a.name, locale)}</h3>
          <p className="text-sm text-muted-foreground">{tr(a.detail, locale)}</p>
          <p className="mt-1 text-xs text-muted-foreground">
            {d.submitted}: {ago(a.submittedAt, DEMO_NOW, common)}
          </p>
        </div>
        <StatusBadge
          tone={
            decision === 'approved' ? 'success' : decision === 'rejected' ? 'neutral' : 'warning'
          }
        >
          {statusLabels[decision ?? 'pending']}
        </StatusBadge>
      </div>

      {a.kind === 'technician' && (
        <dl className="grid grid-cols-2 gap-3 border-t px-4 py-3 text-sm">
          {a.mode && (
            <div>
              <dt className="text-xs text-muted-foreground">{d.mode}</dt>
              <dd className="font-medium">{d[modeLabel[a.mode]]}</dd>
            </div>
          )}
          {a.years !== undefined && (
            <div>
              <dt className="text-xs text-muted-foreground">{d.experience}</dt>
              <dd className="font-medium">{fill(d.years, { n: a.years })}</dd>
            </div>
          )}
        </dl>
      )}

      <div className="border-t px-4 py-3">
        <h4 className="text-xs font-semibold text-muted-foreground">{d.documents}</h4>
        <ul className="mt-2 flex flex-col gap-1.5">
          {a.docs.map((doc) => (
            <li key={doc.key} className="flex items-center gap-2 text-sm">
              {doc.ok ? (
                <FileCheck className="size-4 shrink-0 text-success" aria-hidden />
              ) : (
                <FileX className="size-4 shrink-0 text-warning" aria-hidden />
              )}
              <span className="flex-1">{d[docLabel[doc.key]]}</span>
              {!doc.ok && <StatusBadge tone="warning">{d.missing}</StatusBadge>}
            </li>
          ))}
        </ul>
      </div>

      {!decision && (
        <div className="mt-auto flex flex-col gap-3 border-t px-4 py-3">
          {missing.length > 0 && <p className="text-xs text-warning">{d.missingHint}</p>}
          <div className="flex flex-wrap gap-2">
            <Button
              className="h-10 px-4"
              disabled={missing.length > 0}
              onClick={() => onDecide('approved')}
            >
              {common.approve}
            </Button>
            <Button variant="outline" className="h-10 px-4" onClick={() => onDecide('rejected')}>
              {common.reject}
            </Button>
          </div>
        </div>
      )}
    </article>
  );
}
