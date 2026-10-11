'use client';

import { Radio } from '@base-ui/react/radio';
import { RadioGroup } from '@base-ui/react/radio-group';
import { CircleCheck, CircleX, ImageIcon, TriangleAlert, Wrench } from 'lucide-react';
import { useRef, useState, type ReactNode } from 'react';
import { cn } from 'cn';
import { Button } from '@/components/ui/button';
import type { Locale } from '@/i18n/config';
import type { Dictionary } from '@/i18n/dictionaries';
import { DEMO_NOW, receipts, tr, type ReceiptReview } from '@/lib/demo/data';
import { ago, formatRef, money } from '@/lib/format';
import { CheckField, Modal, Notice } from './interactive';
import { Panel, StatusBadge } from './ui';

type Labels = Dictionary['payments'];
type Common = Dictionary['common'];
type Reason = 'reasonAmount' | 'reasonNotFound' | 'reasonDuplicate' | 'reasonUnreadable';
const reasons: Reason[] = ['reasonAmount', 'reasonNotFound', 'reasonDuplicate', 'reasonUnreadable'];

/**
 * Amount and transaction number are hard checks (they block confirming);
 * a missing order number in the note is only a warning, because the
 * transfer can still be matched on the statement by amount and number.
 */
function checksOf(r: ReceiptReview) {
  return { amount: r.transferredSdg === r.dueSdg, txn: !r.txnUsedBefore, ref: r.refInNote };
}

export function PaymentsQueue({
  locale,
  d,
  common,
}: {
  locale: Locale;
  d: Labels;
  common: Common;
}) {
  const [pending, setPending] = useState(() =>
    [...receipts].sort((a, b) => a.submittedAt.getTime() - b.submittedAt.getTime()),
  );
  const [selectedId, setSelectedId] = useState<string | null>(pending[0]?.id ?? null);
  const [statement, setStatement] = useState<Record<string, boolean>>({});
  const [reviewed, setReviewed] = useState(0);
  const [notice, setNotice] = useState<string | null>(null);
  const [rejectOpen, setRejectOpen] = useState(false);
  const [reason, setReason] = useState<Reason>('reasonNotFound');
  const detailRef = useRef<HTMLDivElement>(null);

  const selected = pending.find((r) => r.id === selectedId) ?? null;

  function select(id: string) {
    setSelectedId(id);
    // One column below `lg`: bring the details into view.
    if (window.matchMedia('(max-width: 1023px)').matches) {
      const smooth = !window.matchMedia('(prefers-reduced-motion: reduce)').matches;
      requestAnimationFrame(() =>
        detailRef.current?.scrollIntoView({ block: 'start', behavior: smooth ? 'smooth' : 'auto' }),
      );
    }
  }

  function resolve(id: string, message: string) {
    const next = pending.filter((r) => r.id !== id);
    setPending(next);
    setSelectedId(next[0]?.id ?? null);
    setReviewed((n) => n + 1);
    setNotice(message);
  }

  function openReject(r: ReceiptReview) {
    const c = checksOf(r);
    setReason(!c.amount ? 'reasonAmount' : !c.txn ? 'reasonDuplicate' : 'reasonNotFound');
    setRejectOpen(true);
  }

  return (
    <div className="flex flex-col gap-4">
      <Notice message={notice} onDismiss={() => setNotice(null)} closeLabel={common.close} />

      {pending.length === 0 ? (
        <Panel>
          <div className="flex flex-col items-center gap-3 px-6 py-16 text-center">
            <CircleCheck className="size-10 text-success" aria-hidden />
            <p className="text-base font-semibold">{d.empty}</p>
            <p className="text-sm text-muted-foreground">
              {d.doneToday}: {reviewed}
            </p>
          </div>
        </Panel>
      ) : (
        <div className="grid grid-cols-1 items-start gap-6 lg:grid-cols-[minmax(0,21rem)_minmax(0,1fr)]">
          <Panel
            title={d.queue}
            actions={<StatusBadge tone="warning">{pending.length}</StatusBadge>}
          >
            <ul className="divide-y">
              {pending.map((r) => {
                const c = checksOf(r);
                const active = r.id === selected?.id;
                return (
                  <li key={r.id}>
                    <button
                      type="button"
                      onClick={() => select(r.id)}
                      aria-current={active ? 'true' : undefined}
                      className={cn(
                        'relative flex w-full flex-col gap-1 px-4 py-3 text-start transition-colors hover:bg-muted/60 focus-visible:bg-muted focus-visible:outline-none',
                        active && 'bg-muted',
                      )}
                    >
                      {active && (
                        <span
                          className="absolute inset-y-2 start-0 w-1 rounded-e-full bg-foreground"
                          aria-hidden
                        />
                      )}
                      <span className="flex items-center justify-between gap-2">
                        <span className="font-semibold tabular-nums">{formatRef(r.ref)}</span>
                        <span className="text-sm font-semibold whitespace-nowrap">
                          {money(r.transferredSdg, common.currency)}
                        </span>
                      </span>
                      <span className="flex items-center justify-between gap-2 text-xs text-muted-foreground">
                        <bdi className="truncate">{r.buyer}</bdi>
                        <span className="whitespace-nowrap">
                          {ago(r.submittedAt, DEMO_NOW, common)}
                        </span>
                      </span>
                      {(!c.amount || !c.txn) && (
                        <span className="mt-1">
                          <StatusBadge tone="danger">
                            <TriangleAlert className="size-3.5" aria-hidden />
                            {d.mismatch}
                          </StatusBadge>
                        </span>
                      )}
                    </button>
                  </li>
                );
              })}
            </ul>
            {reviewed > 0 && (
              <p className="border-t px-4 py-3 text-sm text-muted-foreground">
                {d.doneToday}: {reviewed}
              </p>
            )}
          </Panel>

          <div ref={detailRef} className="min-w-0 scroll-mt-20">
            {selected ? (
              <ReceiptDetail
                key={selected.id}
                r={selected}
                locale={locale}
                d={d}
                common={common}
                statementChecked={!!statement[selected.id]}
                onStatementChange={(v) => setStatement((s) => ({ ...s, [selected.id]: v }))}
                onConfirm={() => resolve(selected.id, d.confirmed)}
                onReject={() => openReject(selected)}
              />
            ) : (
              <Panel>
                <p className="px-6 py-16 text-center text-sm text-muted-foreground">
                  {d.selectHint}
                </p>
              </Panel>
            )}
          </div>
        </div>
      )}

      <Modal
        open={rejectOpen}
        onOpenChange={setRejectOpen}
        title={d.rejectTitle}
        description={selected ? formatRef(selected.ref) : undefined}
      >
        <RadioGroup
          value={reason}
          onValueChange={(v) => setReason(v as Reason)}
          aria-label={d.reason}
          className="flex flex-col gap-1"
        >
          {reasons.map((key) => (
            <label
              key={key}
              className="flex cursor-pointer items-center gap-3 rounded-lg p-2 hover:bg-muted/60"
            >
              <Radio.Root
                value={key}
                className="grid size-5 shrink-0 place-items-center rounded-full border-2 border-input bg-card focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 focus-visible:ring-offset-popover focus-visible:outline-none data-checked:border-foreground"
              >
                <Radio.Indicator className="size-2.5 rounded-full bg-foreground data-unchecked:hidden" />
              </Radio.Root>
              <span className="text-sm">{d[key]}</span>
            </label>
          ))}
        </RadioGroup>
        <div className="flex flex-wrap justify-end gap-2 pt-1">
          <Button variant="outline" className="h-10 px-4" onClick={() => setRejectOpen(false)}>
            {common.cancel}
          </Button>
          <Button
            variant="destructive"
            className="h-10 px-4"
            onClick={() => {
              setRejectOpen(false);
              if (selected) resolve(selected.id, d.rejected);
            }}
          >
            {d.reject}
          </Button>
        </div>
      </Modal>
    </div>
  );
}

function ReceiptDetail({
  r,
  locale,
  d,
  common,
  statementChecked,
  onStatementChange,
  onConfirm,
  onReject,
}: {
  r: ReceiptReview;
  locale: Locale;
  d: Labels;
  common: Common;
  statementChecked: boolean;
  onStatementChange: (checked: boolean) => void;
  onConfirm: () => void;
  onReject: () => void;
}) {
  const c = checksOf(r);
  const hardFail = !c.amount || !c.txn;
  const separator = locale === 'ar' ? '، ' : ', ';

  return (
    <Panel>
      <div className="flex flex-col gap-5 p-4 sm:p-5">
        <div className="flex flex-wrap items-start justify-between gap-3">
          <div className="min-w-0">
            <div className="text-xs text-muted-foreground">{common.reference}</div>
            <div className="text-xl font-bold tabular-nums">{formatRef(r.ref)}</div>
            <div className="mt-1 text-sm text-muted-foreground">
              <bdi>{r.buyer}</bdi> · {d.submitted} {ago(r.submittedAt, DEMO_NOW, common)}
            </div>
          </div>
          {r.hasFitting && (
            <StatusBadge tone="info">
              <Wrench className="size-3.5" aria-hidden />
              {d.fitting}
            </StatusBadge>
          )}
        </div>

        <div className="grid grid-cols-1 gap-5 xl:grid-cols-[minmax(0,14rem)_minmax(0,1fr)]">
          <figure className="flex min-h-48 flex-col items-center justify-center gap-2 rounded-lg border-2 border-dashed bg-muted/40 p-4 text-center text-muted-foreground xl:aspect-[3/4] xl:min-h-0">
            <ImageIcon className="size-8" aria-hidden />
            <figcaption className="text-xs text-balance">{d.receiptPlaceholder}</figcaption>
          </figure>

          <div className="flex min-w-0 flex-col gap-5">
            <dl className="grid grid-cols-1 gap-x-6 gap-y-4 sm:grid-cols-2">
              <Fact label={d.expected} value={money(r.dueSdg, common.currency)} />
              <Fact
                label={d.transferred}
                value={money(r.transferredSdg, common.currency)}
                badge={
                  <StatusBadge tone={c.amount ? 'success' : 'danger'}>
                    {c.amount ? d.match : d.mismatch}
                  </StatusBadge>
                }
              />
              <Fact
                label={d.txn}
                value={
                  <span dir="ltr" className="tabular-nums">
                    {r.txn}
                  </span>
                }
                badge={!c.txn && <StatusBadge tone="danger">{d.usedBefore}</StatusBadge>}
              />
              <Fact
                label={d.shopsInOrder}
                value={r.shops.map((s) => tr(s, locale)).join(separator)}
                small
              />
            </dl>

            <div>
              <h3 className="text-sm font-semibold">{d.checks}</h3>
              <ul className="mt-2 flex flex-col gap-1.5">
                <CheckRow
                  state={c.amount ? 'pass' : 'fail'}
                  label={d.checkAmount}
                  answer={c.amount ? common.yes : common.no}
                />
                <CheckRow
                  state={c.txn ? 'pass' : 'fail'}
                  label={d.checkTxn}
                  answer={c.txn ? common.yes : common.no}
                  detail={c.txn ? undefined : d.usedBefore}
                />
                <CheckRow
                  state={c.ref ? 'pass' : 'warn'}
                  label={d.checkRef}
                  answer={c.ref ? common.yes : common.no}
                  detail={c.ref ? undefined : d.notInNote}
                />
              </ul>
              <div className="mt-2 -ms-2">
                <CheckField
                  checked={statementChecked}
                  onCheckedChange={onStatementChange}
                  label={d.checkStatement}
                  hint={d.tickStatement}
                />
              </div>
            </div>

            {hardFail && (
              <div className="flex items-start gap-2 rounded-lg bg-danger-soft p-3 text-sm text-destructive">
                <TriangleAlert className="mt-0.5 size-4 shrink-0" aria-hidden />
                <p>{d.failedHint}</p>
              </div>
            )}

            <div className="flex flex-wrap gap-3 border-t pt-4">
              <Button
                className="h-10 px-4"
                disabled={hardFail || !statementChecked}
                onClick={onConfirm}
              >
                {d.confirm}
              </Button>
              <Button variant="outline" className="h-10 px-4" onClick={onReject}>
                {d.reject}
              </Button>
            </div>
          </div>
        </div>
      </div>
    </Panel>
  );
}

function Fact({
  label,
  value,
  badge,
  small,
}: {
  label: string;
  value: ReactNode;
  badge?: ReactNode;
  small?: boolean;
}) {
  return (
    <div className="flex min-w-0 flex-col gap-1">
      <dt className="text-xs text-muted-foreground">{label}</dt>
      <dd
        className={cn(
          'flex flex-wrap items-center gap-2',
          small ? 'text-sm font-medium' : 'text-base font-semibold',
        )}
      >
        {value}
        {badge}
      </dd>
    </div>
  );
}

const checkIcon = {
  pass: <CircleCheck className="size-4.5 text-success" aria-hidden />,
  warn: <TriangleAlert className="size-4.5 text-warning" aria-hidden />,
  fail: <CircleX className="size-4.5 text-destructive" aria-hidden />,
};

/** Icon shape (not only colour) shows the result; screen readers get the answer as text. */
function CheckRow({
  state,
  label,
  answer,
  detail,
}: {
  state: 'pass' | 'warn' | 'fail';
  label: string;
  answer: string;
  detail?: string;
}) {
  return (
    <li className="flex items-start gap-2.5 text-sm">
      <span className="mt-0.5 shrink-0">{checkIcon[state]}</span>
      <span>
        <span className={cn(state === 'fail' && 'font-semibold')}>{label}</span>
        <span className="sr-only">: {answer}</span>
        {detail && <span className="text-muted-foreground"> — {detail}</span>}
      </span>
    </li>
  );
}
