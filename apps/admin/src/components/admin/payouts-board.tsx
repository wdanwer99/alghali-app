'use client';

import { Ban, Wallet } from 'lucide-react';
import { useId, useState } from 'react';
import { Button } from '@/components/ui/button';
import type { Locale } from '@/i18n/config';
import type { Dictionary } from '@/i18n/dictionaries';
import {
  approvePayouts,
  cancelPayout,
  generatePayouts,
  markPayoutPaid,
} from '@/lib/actions/commerce';
import type { Payout } from '@/lib/data/commerce';
import { named } from '@/lib/data/util';
import { digits, fill, ltr, money } from '@/lib/format';
import { payoutTone, statusKey } from '@/lib/tones';
import { ConfirmDialog, Modal } from './interactive';
import { useAction } from './use-action';
import { EmptyState, Num, Panel, StatusBadge, Table, Td, Th } from './ui';

/**
 * Payouts come from the ledger (D-018): "Prepare" creates a draft for every shop the
 * platform owes; an admin approves, sends the money by Bankak and records the
 * transaction number, which posts the payout to the shop's account.
 */
export function PayoutsBoard({
  rows,
  hasRun,
  locale,
  period,
  payDay,
  d,
  common,
  errors,
  statusLabels,
}: {
  rows: Payout[];
  hasRun: boolean;
  locale: Locale;
  /** Pre-formatted on the server, e.g. "Up to 18 Oct". */
  period: string | null;
  payDay: string;
  d: Dictionary['payouts'];
  common: Dictionary['common'];
  errors: Dictionary['errors'];
  statusLabels: Dictionary['status']['payout'];
}) {
  const [paying, setPaying] = useState<Payout | null>(null);
  const [cancelling, setCancelling] = useState<Payout | null>(null);
  const [txn, setTxn] = useState('');
  const txnId = useId();
  const { pending, run } = useAction(errors);

  const sdg = (n: number) => money(n, common.currency);
  const drafts = rows.filter((r) => r.status === 'DRAFT');
  const toPay = rows
    .filter((r) => r.status === 'DRAFT' || r.status === 'APPROVED')
    .reduce((s, r) => s + r.amountSdg, 0);
  const txnOk = /^[\d٠-٩]{6,20}$/.test(txn.replace(/[\s-]/g, ''));

  const prepare = (
    <Button
      className="h-10 px-4"
      disabled={pending}
      onClick={() => run(generatePayouts, { success: d.prepared })}
    >
      <Wallet />
      {d.prepare}
    </Button>
  );

  if (!hasRun && rows.length === 0) {
    return (
      <Panel>
        <EmptyState icon={<Wallet />} title={d.noRun} body={d.noRunBody} action={prepare} />
      </Panel>
    );
  }

  return (
    <div className="flex flex-col gap-4">
      <Panel
        title={period ? `${d.period}: ${period}` : d.period}
        actions={
          <div className="flex flex-wrap gap-2">
            <Button
              variant="outline"
              className="h-9 px-3"
              disabled={pending || drafts.length === 0}
              onClick={() =>
                run(() => approvePayouts(drafts.map((r) => r.id)), { success: d.approvedToast })
              }
            >
              {d.approveAll}
            </Button>
            {prepare}
          </div>
        }
      >
        <div className="flex flex-wrap items-baseline justify-between gap-2 border-b px-4 py-3">
          <p className="text-sm text-muted-foreground">{fill(d.nextPayDay, { date: payDay })}</p>
          <p className="text-sm">
            <span className="text-muted-foreground">{d.totalToPay}: </span>
            <span className="text-base font-bold whitespace-nowrap">{sdg(toPay)}</span>
          </p>
        </div>
        {rows.length === 0 ? (
          <p className="px-4 py-10 text-center text-sm text-muted-foreground">{d.nothingOwed}</p>
        ) : (
          <Table>
            <thead>
              <tr>
                <Th>{common.partner}</Th>
                <Th className="text-end">{d.sales}</Th>
                <Th className="text-end" title={d.deductionsHint}>
                  {d.commission}
                </Th>
                <Th className="text-end">{d.net}</Th>
                <Th>{common.status}</Th>
                <Th>
                  <span className="sr-only">{common.details}</span>
                </Th>
              </tr>
            </thead>
            <tbody>
              {rows.map((r) => (
                <tr key={r.id} className="hover:bg-muted/40">
                  <Td className="font-medium whitespace-nowrap">{named(r.shop, locale)}</Td>
                  <Td className="text-end">
                    <Num>{sdg(r.salesSdg)}</Num>
                  </Td>
                  <Td className="text-end">
                    <Num className="text-muted-foreground">
                      {fill(common.currency, { amount: ltr(`−${digits(r.deductionsSdg)}`) })}
                    </Num>
                  </Td>
                  <Td className="text-end">
                    <Num className="font-semibold">{sdg(r.amountSdg)}</Num>
                  </Td>
                  <Td>
                    <StatusBadge tone={payoutTone[r.status]}>
                      {statusLabels[statusKey(r.status)]}
                    </StatusBadge>
                  </Td>
                  <Td className="text-end whitespace-nowrap">
                    <span className="inline-flex gap-1.5">
                      {r.status === 'DRAFT' && (
                        <Button
                          variant="outline"
                          className="h-9 px-3"
                          disabled={pending}
                          onClick={() =>
                            run(() => approvePayouts([r.id]), { success: d.approvedToast })
                          }
                        >
                          {common.approve}
                        </Button>
                      )}
                      {r.status === 'APPROVED' && (
                        <Button
                          className="h-9 px-3"
                          disabled={pending}
                          onClick={() => {
                            setPaying(r);
                            setTxn('');
                          }}
                        >
                          {d.markPaid}
                        </Button>
                      )}
                      {(r.status === 'DRAFT' || r.status === 'APPROVED') && (
                        <Button
                          variant="ghost"
                          className="h-9 px-2"
                          aria-label={d.cancelPayout}
                          title={d.cancelPayout}
                          disabled={pending}
                          onClick={() => setCancelling(r)}
                        >
                          <Ban />
                        </Button>
                      )}
                      {r.status === 'PAID' && r.txn && (
                        <span className="text-xs text-muted-foreground">
                          {fill(d.txnShort, { txn: ltr(r.txn) })}
                        </span>
                      )}
                    </span>
                  </Td>
                </tr>
              ))}
            </tbody>
          </Table>
        )}
        <p className="border-t px-4 py-2.5 text-xs text-muted-foreground">{d.deductionsHint}</p>
      </Panel>

      <Modal
        open={paying !== null}
        onOpenChange={(open) => !open && setPaying(null)}
        title={d.markPaidTitle}
        description={
          paying
            ? fill(d.markPaidBody, {
                amount: sdg(paying.amountSdg),
                partner: named(paying.shop, locale),
              })
            : undefined
        }
      >
        <form
          noValidate
          onSubmit={(e) => {
            e.preventDefault();
            if (!paying || !txnOk) return;
            const payout = paying;
            setPaying(null);
            run(() => markPayoutPaid(payout.id, txn), { success: d.paidToast });
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
              onChange={(e) => setTxn(e.target.value)}
              inputMode="numeric"
              autoComplete="off"
              dir="ltr"
              aria-invalid={(txn.length > 0 && !txnOk) || undefined}
              aria-describedby={txn.length > 0 && !txnOk ? `${txnId}-error` : undefined}
              className="h-10 rounded-lg border border-input bg-card px-3 text-base tabular-nums outline-none focus-visible:border-ring focus-visible:ring-2 focus-visible:ring-ring/30 aria-invalid:border-destructive"
            />
            {txn.length > 0 && !txnOk && (
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
            <Button type="submit" className="h-10 px-4" disabled={!txnOk}>
              {common.confirm}
            </Button>
          </div>
        </form>
      </Modal>

      <ConfirmDialog
        open={cancelling !== null}
        onOpenChange={(o) => !o && setCancelling(null)}
        title={cancelling ? fill(d.cancelTitle, { partner: named(cancelling.shop, locale) }) : ''}
        description={d.cancelledToast}
        reasonLabel={common.notes}
        confirmLabel={d.cancelPayout}
        cancelLabel={common.cancel}
        tone="danger"
        pending={pending}
        onConfirm={(reason) => {
          const p = cancelling;
          setCancelling(null);
          if (p) run(() => cancelPayout(p.id, reason), { success: d.cancelledToast });
        }}
      />
    </div>
  );
}
