'use client';

import { useId, useState } from 'react';
import { Button } from '@/components/ui/button';
import type { Locale } from '@/i18n/config';
import type { Dictionary } from '@/i18n/dictionaries';
import { payoutTxns, tr, type PayoutRow } from '@/lib/demo/data';
import { digits, fill, ltr, money } from '@/lib/format';
import { payoutTone } from '@/lib/tones';
import { Modal, Notice } from './interactive';
import { Num, Panel, StatusBadge, Table, Td, Th } from './ui';

type Status = PayoutRow['status'];

export function PayoutsBoard({
  rows,
  locale,
  period,
  payDay,
  d,
  common,
  statusLabels,
}: {
  rows: PayoutRow[];
  locale: Locale;
  /** Pre-formatted on the server, e.g. "11 Oct – 17 Oct". */
  period: string;
  payDay: string;
  d: Dictionary['payouts'];
  common: Dictionary['common'];
  statusLabels: Dictionary['status']['payout'];
}) {
  const [status, setStatus] = useState<Record<string, Status>>(() =>
    Object.fromEntries(rows.map((r) => [r.id, r.status])),
  );
  const [txns, setTxns] = useState<Record<string, string>>(payoutTxns);
  const [notice, setNotice] = useState<string | null>(null);
  const [paying, setPaying] = useState<PayoutRow | null>(null);
  const [txn, setTxn] = useState('');
  const [txnError, setTxnError] = useState(false);
  const txnId = useId();

  const sdg = (n: number) => money(n, common.currency);
  const net = (r: PayoutRow) => r.grossSdg - r.deductionsSdg;
  const drafts = rows.filter((r) => status[r.id] === 'draft');
  const toPay = rows.filter((r) => status[r.id] !== 'paid').reduce((s, r) => s + net(r), 0);

  function approve(ids: string[]) {
    setStatus((s) => ({ ...s, ...Object.fromEntries(ids.map((id) => [id, 'approved' as const])) }));
    setNotice(d.approvedToast);
  }

  function openPay(r: PayoutRow) {
    setPaying(r);
    setTxn('');
    setTxnError(false);
  }

  function recordPayment() {
    if (!paying) return;
    const value = txn.trim();
    if (!/^\d{6,12}$/.test(value)) {
      setTxnError(true);
      return;
    }
    setStatus((s) => ({ ...s, [paying.id]: 'paid' }));
    setTxns((t) => ({ ...t, [paying.id]: value }));
    setPaying(null);
    setNotice(d.paidToast);
  }

  return (
    <div className="flex flex-col gap-4">
      <Notice message={notice} onDismiss={() => setNotice(null)} closeLabel={common.close} />
      <Panel
        title={`${d.period}: ${period}`}
        actions={
          <Button
            variant="outline"
            className="h-9 px-3"
            disabled={drafts.length === 0}
            onClick={() => approve(drafts.map((r) => r.id))}
          >
            {d.approveAll}
          </Button>
        }
      >
        <div className="flex flex-wrap items-baseline justify-between gap-2 border-b px-4 py-3">
          <p className="text-sm text-muted-foreground">{fill(d.payoutDay, { date: payDay })}</p>
          <p className="text-sm">
            <span className="text-muted-foreground">{d.totalToPay}: </span>
            <span className="text-base font-bold whitespace-nowrap">{sdg(toPay)}</span>
          </p>
        </div>
        <Table>
          <thead>
            <tr>
              <Th>{common.partner}</Th>
              <Th>{common.role}</Th>
              <Th className="text-end">{d.sales}</Th>
              <Th className="text-end">{d.commission}</Th>
              <Th className="text-end">{d.net}</Th>
              <Th>{common.status}</Th>
              <Th>
                <span className="sr-only">{common.details}</span>
              </Th>
            </tr>
          </thead>
          <tbody>
            {rows.map((r) => {
              const s = status[r.id];
              return (
                <tr key={r.id} className="hover:bg-muted/40">
                  <Td className="font-medium whitespace-nowrap">{tr(r.partner, locale)}</Td>
                  <Td className="text-muted-foreground">
                    {r.role === 'shop' ? common.shop : common.technician}
                  </Td>
                  <Td className="text-end">
                    <Num>{sdg(r.grossSdg)}</Num>
                  </Td>
                  <Td className="text-end">
                    <Num className="text-muted-foreground">
                      {fill(common.currency, { amount: ltr(`−${digits(r.deductionsSdg)}`) })}
                    </Num>
                  </Td>
                  <Td className="text-end">
                    <Num className="font-semibold">{sdg(net(r))}</Num>
                  </Td>
                  <Td>
                    <StatusBadge tone={payoutTone[s]}>{statusLabels[s]}</StatusBadge>
                  </Td>
                  <Td className="text-end whitespace-nowrap">
                    {s === 'draft' && (
                      <Button
                        variant="outline"
                        className="h-9 px-3"
                        onClick={() => approve([r.id])}
                      >
                        {common.approve}
                      </Button>
                    )}
                    {s === 'approved' && (
                      <Button className="h-9 px-3" onClick={() => openPay(r)}>
                        {d.markPaid}
                      </Button>
                    )}
                    {s === 'paid' && txns[r.id] && (
                      <span className="text-xs text-muted-foreground">
                        {fill(d.txnShort, { txn: ltr(txns[r.id]) })}
                      </span>
                    )}
                  </Td>
                </tr>
              );
            })}
          </tbody>
        </Table>
      </Panel>

      <Modal
        open={paying !== null}
        onOpenChange={(open) => !open && setPaying(null)}
        title={d.markPaidTitle}
        description={
          paying
            ? fill(d.markPaidBody, {
                amount: sdg(net(paying)),
                partner: tr(paying.partner, locale),
              })
            : undefined
        }
      >
        <form
          noValidate
          onSubmit={(e) => {
            e.preventDefault();
            recordPayment();
          }}
          className="flex flex-col gap-4"
        >
          <div className="flex flex-col gap-1.5">
            <label htmlFor={txnId} className="text-sm font-medium">
              {d.txnPrompt}
            </label>
            <input
              id={txnId}
              value={txn}
              onChange={(e) => {
                setTxn(e.target.value);
                setTxnError(false);
              }}
              inputMode="numeric"
              autoComplete="off"
              dir="ltr"
              aria-invalid={txnError || undefined}
              aria-describedby={txnError ? `${txnId}-error` : undefined}
              className="h-10 rounded-lg border border-input bg-card px-3 text-base tabular-nums outline-none focus-visible:border-ring focus-visible:ring-2 focus-visible:ring-ring/30 aria-invalid:border-destructive"
            />
            {txnError && (
              <p id={`${txnId}-error`} className="text-sm text-destructive">
                {d.txnInvalid}
              </p>
            )}
          </div>
          <div className="flex flex-wrap justify-end gap-2">
            <Button
              type="button"
              variant="outline"
              className="h-10 px-4"
              onClick={() => setPaying(null)}
            >
              {common.cancel}
            </Button>
            <Button type="submit" className="h-10 px-4">
              {common.confirm}
            </Button>
          </div>
        </form>
      </Modal>
    </div>
  );
}
