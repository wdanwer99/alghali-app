'use client';

import { Radio } from '@base-ui/react/radio';
import { RadioGroup } from '@base-ui/react/radio-group';
import { Tabs } from '@base-ui/react/tabs';
import {
  CircleCheck,
  CircleX,
  ExternalLink,
  ImageOff,
  Phone,
  TriangleAlert,
  Undo2,
  Wrench,
} from 'lucide-react';
import Link from 'next/link';
import { useId, useRef, useState, type ReactNode } from 'react';
import { cn } from 'cn';
import { Button } from '@/components/ui/button';
import type { Locale } from '@/i18n/config';
import type { Dictionary } from '@/i18n/dictionaries';
import {
  confirmPayment,
  markRefundPaid,
  rejectPayment,
  type RejectReason,
} from '@/lib/actions/commerce';
import type { Receipt, Refund } from '@/lib/data/commerce';
import { named } from '@/lib/data/util';
import { ago, dateTime, digits, fill, formatRef, ltr, money } from '@/lib/format';
import { CheckField, Modal } from './interactive';
import { phoneText } from './shop-facts';
import { useAction } from './use-action';
import {
  CountPill,
  EmptyState,
  Num,
  Panel,
  StatusBadge,
  tabClass,
  TabList,
  Table,
  Td,
  Th,
} from './ui';

type Labels = {
  payments: Dictionary['payments'];
  common: Dictionary['common'];
  errors: Dictionary['errors'];
};

const reasons: { code: RejectReason; label: keyof Dictionary['payments'] }[] = [
  { code: 'NOT_ON_STATEMENT', label: 'reasonNotFound' },
  { code: 'AMOUNT_WRONG', label: 'reasonAmount' },
  { code: 'DUPLICATE', label: 'reasonDuplicate' },
  { code: 'UNREADABLE', label: 'reasonUnreadable' },
  { code: 'OTHER', label: 'reasonOther' },
];

/**
 * Bankak confirmations (D-054): the admin finds the transfer on the statement and ticks
 * it; the transaction number is required (typed here when only a screenshot came) and
 * one already used elsewhere blocks confirming. The order number in the transfer note
 * is only a hint. Refunds to send are the second tab.
 */
export function PaymentsBoard({
  receipts,
  refunds,
  locale,
  now,
  t,
}: {
  receipts: Receipt[];
  refunds: Refund[];
  locale: Locale;
  /** Server time when the page rendered, so "x min ago" reads the same on both sides. */
  now: string;
  t: Labels;
}) {
  const pendingRefunds = refunds.filter((r) => r.status === 'PENDING').length;
  return (
    <Tabs.Root defaultValue="transfers" className="flex flex-col gap-4">
      <TabList>
        <Tabs.Tab value="transfers" className={tabClass}>
          {t.payments.tabTransfers}
          <CountPill>{digits(receipts.length)}</CountPill>
        </Tabs.Tab>
        <Tabs.Tab value="refunds" className={tabClass}>
          {t.payments.tabRefunds}
          <CountPill>{digits(pendingRefunds)}</CountPill>
        </Tabs.Tab>
      </TabList>
      <Tabs.Panel value="transfers">
        <TransfersQueue receipts={receipts} locale={locale} now={new Date(now)} t={t} />
      </Tabs.Panel>
      <Tabs.Panel value="refunds">
        <RefundsList refunds={refunds} locale={locale} now={new Date(now)} t={t} />
      </Tabs.Panel>
    </Tabs.Root>
  );
}

// ----------------------------------------------------------------- transfers

function TransfersQueue({
  receipts,
  locale,
  now,
  t,
}: {
  receipts: Receipt[];
  locale: Locale;
  now: Date;
  t: Labels;
}) {
  const d = t.payments;
  const [handled, setHandled] = useState<Set<string>>(new Set());
  const pending = receipts.filter((r) => !handled.has(r.paymentId));
  const [selectedId, setSelectedId] = useState<string | null>(pending[0]?.paymentId ?? null);
  const [rejectOpen, setRejectOpen] = useState(false);
  const detailRef = useRef<HTMLDivElement>(null);
  const { pending: busy, run } = useAction(t.errors);

  const selected = pending.find((r) => r.paymentId === selectedId) ?? pending[0] ?? null;

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

  const resolve = (id: string) => {
    setHandled((h) => new Set(h).add(id));
    setSelectedId(pending.find((r) => r.paymentId !== id)?.paymentId ?? null);
  };

  if (pending.length === 0) {
    return (
      <Panel>
        <EmptyState icon={<CircleCheck />} title={d.empty} />
      </Panel>
    );
  }

  return (
    <div className="grid grid-cols-1 items-start gap-6 lg:grid-cols-[minmax(0,21rem)_minmax(0,1fr)]">
      <Panel
        title={d.queue}
        actions={<StatusBadge tone="warning">{digits(pending.length)}</StatusBadge>}
      >
        <ul className="divide-y">
          {pending.map((r) => {
            const active = r.paymentId === selected?.paymentId;
            return (
              <li key={r.paymentId}>
                <button
                  type="button"
                  onClick={() => select(r.paymentId)}
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
                      {money(r.amountSdg, t.common.currency)}
                    </span>
                  </span>
                  <span className="flex items-center justify-between gap-2 text-xs text-muted-foreground">
                    <bdi className="truncate">{r.buyer.name}</bdi>
                    <span className="whitespace-nowrap">
                      {ago(new Date(r.submittedAt), now, t.common)}
                    </span>
                  </span>
                  {r.txnSeenBefore && (
                    <span className="mt-1">
                      <StatusBadge tone="danger">
                        <TriangleAlert className="size-3.5" aria-hidden />
                        {d.usedBefore}
                      </StatusBadge>
                    </span>
                  )}
                </button>
              </li>
            );
          })}
        </ul>
      </Panel>

      <div ref={detailRef} className="min-w-0 scroll-mt-20">
        {selected && (
          <ReceiptDetail
            key={selected.paymentId}
            r={selected}
            locale={locale}
            now={now}
            t={t}
            busy={busy}
            onConfirm={(txn, refInNote) =>
              run(() => confirmPayment(selected.paymentId, txn, refInNote), {
                success: d.confirmed,
                onDone: () => resolve(selected.paymentId),
              })
            }
            onReject={() => setRejectOpen(true)}
          />
        )}
      </div>

      <RejectDialog
        open={rejectOpen}
        onOpenChange={setRejectOpen}
        receipt={selected}
        d={d}
        common={t.common}
        busy={busy}
        onReject={(code, note) => {
          if (!selected) return;
          setRejectOpen(false);
          run(() => rejectPayment(selected.paymentId, code, note), {
            success: d.rejected,
            onDone: () => resolve(selected.paymentId),
          });
        }}
      />
    </div>
  );
}

function ReceiptDetail({
  r,
  locale,
  now,
  t,
  busy,
  onConfirm,
  onReject,
}: {
  r: Receipt;
  locale: Locale;
  now: Date;
  t: Labels;
  busy: boolean;
  onConfirm: (txn: string | undefined, refInNote: boolean) => void;
  onReject: () => void;
}) {
  const d = t.payments;
  const [statement, setStatement] = useState(false);
  const [refInNote, setRefInNote] = useState(false);
  const [txn, setTxn] = useState('');
  const txnId = useId();
  const needsTxn = r.txn === null;
  const txnOk = !needsTxn || /^[\d٠-٩]{6,20}$/.test(txn.replace(/[\s-]/g, ''));
  const separator = locale === 'ar' ? '، ' : ', ';

  return (
    <Panel>
      <div className="flex flex-col gap-5 p-4 sm:p-5">
        <div className="flex flex-wrap items-start justify-between gap-3">
          <div className="min-w-0">
            <div className="text-xs text-muted-foreground">{t.common.reference}</div>
            <Link
              href={`/${locale}/orders/${r.orderId}`}
              className="text-xl font-bold tabular-nums underline-offset-4 hover:underline"
            >
              {formatRef(r.ref)}
            </Link>
            <div className="mt-1 text-sm text-muted-foreground">
              <bdi>{r.buyer.name}</bdi> · {d.submitted}{' '}
              {ago(new Date(r.submittedAt), now, t.common)}
            </div>
          </div>
          <div className="flex flex-wrap gap-2">
            {r.earlierRejections > 0 && (
              <StatusBadge tone="warning">
                {fill(d.rejectedBefore, { n: digits(r.earlierRejections) })}
              </StatusBadge>
            )}
            {r.hasFitting && (
              <StatusBadge tone="info">
                <Wrench className="size-3.5" aria-hidden />
                {d.fitting}
              </StatusBadge>
            )}
          </div>
        </div>

        <div className="grid grid-cols-1 gap-5 xl:grid-cols-[minmax(0,14rem)_minmax(0,1fr)]">
          {r.receiptUrl ? (
            <figure className="flex flex-col gap-2">
              <a
                href={r.receiptUrl}
                target="_blank"
                rel="noreferrer"
                className="block overflow-hidden rounded-lg border bg-muted/40 focus-visible:ring-2 focus-visible:ring-ring focus-visible:outline-none"
              >
                {/* A short-lived signed link to a private file; not something next/image can optimise. */}
                {/* eslint-disable-next-line @next/next/no-img-element */}
                <img
                  src={r.receiptUrl}
                  alt={d.receipt}
                  className="max-h-96 w-full object-contain"
                />
              </a>
              <figcaption>
                <a
                  href={r.receiptUrl}
                  target="_blank"
                  rel="noreferrer"
                  className="inline-flex items-center gap-1 text-xs text-muted-foreground underline-offset-2 hover:underline"
                >
                  <ExternalLink className="size-3.5" aria-hidden />
                  {d.openReceipt}
                </a>
              </figcaption>
            </figure>
          ) : (
            <div className="flex min-h-40 flex-col items-center justify-center gap-2 rounded-lg border-2 border-dashed bg-muted/40 p-4 text-center text-sm text-muted-foreground">
              <ImageOff className="size-7" aria-hidden />
              {d.noReceipt}
            </div>
          )}

          <div className="flex min-w-0 flex-col gap-5">
            <dl className="grid grid-cols-1 gap-x-6 gap-y-4 sm:grid-cols-2">
              <Fact label={d.expected} value={money(r.amountSdg, t.common.currency)} />
              <Fact
                label={d.txn}
                value={
                  r.txn ? (
                    <span dir="ltr" className="tabular-nums">
                      {r.txn}
                    </span>
                  ) : (
                    '—'
                  )
                }
                badge={r.txnSeenBefore && <StatusBadge tone="danger">{d.usedBefore}</StatusBadge>}
              />
              <Fact
                label={d.shopsInOrder}
                value={r.shops.map((s) => named(s, locale)).join(separator)}
                small
              />
              <Fact
                label={d.buyerPhone}
                value={
                  r.buyer.phone ? (
                    <a
                      href={`tel:${r.buyer.phone}`}
                      className="inline-flex items-center gap-1.5 underline-offset-2 hover:underline"
                    >
                      <Phone className="size-3.5" aria-hidden />
                      {phoneText(r.buyer.phone)}
                    </a>
                  ) : (
                    '—'
                  )
                }
                small
              />
              {r.payBy && (
                <Fact label={d.payBy} value={dateTime(new Date(r.payBy), locale)} small />
              )}
            </dl>

            <div className="flex flex-col gap-1">
              <h3 className="text-sm font-semibold">{d.checks}</h3>
              <CheckRow
                state={r.txnSeenBefore ? 'fail' : 'pass'}
                label={d.checkTxn}
                answer={r.txnSeenBefore ? t.common.no : t.common.yes}
              />
              {needsTxn && (
                <div className="mt-2 flex flex-col gap-1.5 rounded-lg bg-warning-soft/50 p-3">
                  <label htmlFor={txnId} className="text-sm font-medium">
                    {d.txnLabel}
                  </label>
                  <p className="text-xs text-muted-foreground">{d.txnMissing}</p>
                  <input
                    id={txnId}
                    value={txn}
                    onChange={(e) => setTxn(e.target.value)}
                    inputMode="numeric"
                    autoComplete="off"
                    dir="ltr"
                    className="h-10 rounded-lg border border-input bg-card px-3 text-base tabular-nums outline-none focus-visible:border-ring focus-visible:ring-2 focus-visible:ring-ring/30"
                  />
                </div>
              )}
              <div className="-ms-2 mt-2 flex flex-col">
                <CheckField
                  checked={statement}
                  onCheckedChange={setStatement}
                  label={fill(d.statementAmount, { amount: money(r.amountSdg, t.common.currency) })}
                  hint={d.tickStatement}
                />
                <CheckField
                  checked={refInNote}
                  onCheckedChange={setRefInNote}
                  label={d.refInNoteLabel}
                  hint={d.refInNoteHint}
                />
              </div>
            </div>

            {r.txnSeenBefore && (
              <div className="flex items-start gap-2 rounded-lg bg-danger-soft p-3 text-sm text-destructive">
                <TriangleAlert className="mt-0.5 size-4 shrink-0" aria-hidden />
                <p>{d.failedHint}</p>
              </div>
            )}

            <div className="flex flex-wrap gap-3 border-t pt-4">
              <Button
                className="h-10 px-4"
                disabled={busy || r.txnSeenBefore || !statement || !txnOk}
                onClick={() => onConfirm(needsTxn ? txn : undefined, refInNote)}
              >
                {d.confirm}
              </Button>
              <Button variant="outline" className="h-10 px-4" disabled={busy} onClick={onReject}>
                {d.reject}
              </Button>
            </div>
          </div>
        </div>
      </div>
    </Panel>
  );
}

function RejectDialog({
  open,
  onOpenChange,
  receipt,
  d,
  common,
  busy,
  onReject,
}: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  receipt: Receipt | null;
  d: Labels['payments'];
  common: Labels['common'];
  busy: boolean;
  onReject: (code: RejectReason, note: string) => void;
}) {
  const [code, setCode] = useState<RejectReason>(
    receipt?.txnSeenBefore ? 'DUPLICATE' : 'NOT_ON_STATEMENT',
  );
  const [note, setNote] = useState('');
  const noteId = useId();
  return (
    <Modal
      open={open}
      onOpenChange={(o) => {
        onOpenChange(o);
        if (o) setCode(receipt?.txnSeenBefore ? 'DUPLICATE' : 'NOT_ON_STATEMENT');
        else setNote('');
      }}
      title={d.rejectTitle}
      description={receipt ? formatRef(receipt.ref) : undefined}
    >
      <RadioGroup
        value={code}
        onValueChange={(v) => setCode(v as RejectReason)}
        aria-label={d.reason}
        className="flex flex-col gap-1"
      >
        {reasons.map((r) => (
          <label
            key={r.code}
            className="flex cursor-pointer items-center gap-3 rounded-lg p-2 hover:bg-muted/60"
          >
            <Radio.Root
              value={r.code}
              className="grid size-5 shrink-0 place-items-center rounded-full border-2 border-input bg-card focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 focus-visible:ring-offset-popover focus-visible:outline-none data-checked:border-foreground"
            >
              <Radio.Indicator className="size-2.5 rounded-full bg-foreground data-unchecked:hidden" />
            </Radio.Root>
            <span className="text-sm">{d[r.label]}</span>
          </label>
        ))}
      </RadioGroup>
      <div className="flex flex-col gap-1.5">
        <label htmlFor={noteId} className="text-sm font-medium">
          {d.rejectNote}
        </label>
        <textarea
          id={noteId}
          rows={2}
          maxLength={500}
          value={note}
          onChange={(e) => setNote(e.target.value)}
          className="w-full resize-none rounded-lg border border-input bg-card px-3 py-2 text-base outline-none focus-visible:border-ring focus-visible:ring-2 focus-visible:ring-ring/30"
        />
      </div>
      <div className="flex flex-wrap justify-end gap-2 pt-1">
        <Button variant="outline" className="h-10 px-4" onClick={() => onOpenChange(false)}>
          {common.cancel}
        </Button>
        <Button
          variant="destructive"
          className="h-10 px-4"
          disabled={busy}
          onClick={() => onReject(code, note)}
        >
          {d.reject}
        </Button>
      </div>
    </Modal>
  );
}

// ------------------------------------------------------------------- refunds

function RefundsList({
  refunds,
  locale,
  now,
  t,
}: {
  refunds: Refund[];
  locale: Locale;
  now: Date;
  t: Labels;
}) {
  const d = t.payments;
  const [paying, setPaying] = useState<Refund | null>(null);
  const [txn, setTxn] = useState('');
  const [sent, setSent] = useState<Record<string, string>>({});
  const txnId = useId();
  const { pending, run } = useAction(t.errors);
  const sdg = (n: number) => money(n, t.common.currency);

  if (refunds.length === 0) {
    return (
      <Panel>
        <EmptyState icon={<Undo2 />} title={d.refundsEmpty} body={d.refundsEmptyBody} />
      </Panel>
    );
  }

  return (
    <Panel>
      <Table>
        <thead>
          <tr>
            <Th>{d.refundOrder}</Th>
            <Th>{t.common.buyer}</Th>
            <Th>{d.refundTo}</Th>
            <Th className="text-end">{t.common.amount}</Th>
            <Th className="hidden md:table-cell">{d.refundReason}</Th>
            <Th>{t.common.status}</Th>
            <Th className="text-end">
              <span className="sr-only">{t.common.details}</span>
            </Th>
          </tr>
        </thead>
        <tbody>
          {refunds.map((r) => {
            const paidTxn = sent[r.id] ?? r.txn;
            const isPaid = r.status === 'PAID' || sent[r.id] !== undefined;
            return (
              <tr key={r.id} className="hover:bg-muted/40">
                <Td>
                  <Link
                    href={`/${locale}/orders/${r.orderId}`}
                    className="font-semibold tabular-nums underline-offset-2 hover:underline"
                  >
                    {formatRef(r.ref)}
                  </Link>
                  <div className="text-xs text-muted-foreground">
                    {ago(new Date(r.createdAt), now, t.common)}
                  </div>
                </Td>
                <Td>
                  <bdi className="text-sm">{r.buyer?.name ?? '—'}</bdi>
                  {r.buyer?.phone && (
                    <div className="text-xs text-muted-foreground">{phoneText(r.buyer.phone)}</div>
                  )}
                </Td>
                <Td>
                  {r.buyer?.refundAccount ? (
                    <Num>{ltr(r.buyer.refundAccount)}</Num>
                  ) : (
                    <span className="text-xs text-warning">{d.noRefundAccount}</span>
                  )}
                </Td>
                <Td className="text-end">
                  <Num className="font-semibold">{sdg(r.amountSdg)}</Num>
                </Td>
                <Td className="hidden max-w-56 truncate text-muted-foreground md:table-cell">
                  {r.reason ?? '—'}
                </Td>
                <Td>
                  {isPaid ? (
                    <StatusBadge tone="success">
                      {d.refundSent}
                      {paidTxn && <span className="font-normal">· {ltr(paidTxn)}</span>}
                    </StatusBadge>
                  ) : (
                    <StatusBadge tone="warning">{d.waiting}</StatusBadge>
                  )}
                </Td>
                <Td className="text-end">
                  {!isPaid && (
                    <Button
                      className="h-9 px-3"
                      disabled={pending}
                      onClick={() => {
                        setPaying(r);
                        setTxn('');
                      }}
                    >
                      {d.markRefundPaid}
                    </Button>
                  )}
                </Td>
              </tr>
            );
          })}
        </tbody>
      </Table>

      <Modal
        open={paying !== null}
        onOpenChange={(o) => !o && setPaying(null)}
        title={d.refundPaidTitle}
        description={
          paying
            ? fill(d.refundPaidBody, {
                amount: sdg(paying.amountSdg),
                buyer: paying.buyer?.name ?? '',
              })
            : undefined
        }
      >
        <form
          noValidate
          className="flex flex-col gap-4"
          onSubmit={(e) => {
            e.preventDefault();
            if (!paying) return;
            const refund = paying;
            const value = txn.trim();
            setPaying(null);
            run(() => markRefundPaid(refund.id, value), {
              success: d.refundPaidToast,
              onDone: () => setSent((s) => ({ ...s, [refund.id]: value })),
            });
          }}
        >
          <div className="flex flex-col gap-1.5">
            <label htmlFor={txnId} className="text-sm font-medium">
              {d.txn}
            </label>
            <input
              id={txnId}
              value={txn}
              onChange={(e) => setTxn(e.target.value)}
              inputMode="numeric"
              autoComplete="off"
              dir="ltr"
              className="h-10 rounded-lg border border-input bg-card px-3 text-base tabular-nums outline-none focus-visible:border-ring focus-visible:ring-2 focus-visible:ring-ring/30"
            />
          </div>
          <div className="flex flex-wrap justify-end gap-2">
            <Button
              type="button"
              variant="outline"
              className="h-10 px-4"
              onClick={() => setPaying(null)}
            >
              {t.common.cancel}
            </Button>
            <Button
              type="submit"
              className="h-10 px-4"
              disabled={!/^[\d٠-٩]{6,20}$/.test(txn.replace(/[\s-]/g, ''))}
            >
              {t.common.confirm}
            </Button>
          </div>
        </form>
      </Modal>
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
  fail: <CircleX className="size-4.5 text-destructive" aria-hidden />,
};

/** Icon shape (not only colour) shows the result; screen readers get the answer as text. */
function CheckRow({
  state,
  label,
  answer,
}: {
  state: 'pass' | 'fail';
  label: string;
  answer: string;
}) {
  return (
    <p className="flex items-start gap-2.5 text-sm">
      <span className="mt-0.5 shrink-0">{checkIcon[state]}</span>
      <span className={cn(state === 'fail' && 'font-semibold')}>
        {label}
        <span className="sr-only">: {answer}</span>
      </span>
    </p>
  );
}
