'use client';

import { Loader2, SlidersHorizontal } from 'lucide-react';
import { useId, useState } from 'react';
import { cn } from 'cn';
import { Button } from '@/components/ui/button';
import type { Dictionary } from '@/i18n/dictionaries';
import { adjustBalance } from '@/lib/actions/commerce';
import { fill, money } from '@/lib/format';
import { Modal } from './interactive';
import { useAction } from './use-action';

const inputClass =
  'w-full rounded-lg border border-input bg-card px-3 py-2 text-base outline-none focus-visible:border-ring focus-visible:ring-2 focus-visible:ring-ring/30';

/**
 * Corrects a partner's balance by hand (D-130): money the platform owes them more of
 * (compensation, a fee charged by mistake) or less of (a cash return the system couldn't
 * record, D-098). Posted to the ledger, audited, and settled in the next payout.
 */
export function AdjustBalance({
  party,
  partyId,
  name,
  d,
  common,
  errors,
}: {
  party: 'SHOP' | 'TECH';
  partyId: string;
  name: string;
  d: Dictionary['cash'];
  common: Dictionary['common'];
  errors: Dictionary['errors'];
}) {
  const [open, setOpen] = useState(false);
  const [credit, setCredit] = useState(true);
  const [amount, setAmount] = useState('');
  const [why, setWhy] = useState('');
  const { pending, run } = useAction(errors);
  const id = useId();
  const sdg = Number(
    amount.replace(/[٠-٩]/g, (c) => String(c.charCodeAt(0) - 0x0660)).replace(/\D/g, ''),
  );
  const valid = sdg > 0 && why.trim().length > 0;

  const close = () => {
    setOpen(false);
    setAmount('');
    setWhy('');
    setCredit(true);
  };

  return (
    <>
      <Button
        variant="ghost"
        size="sm"
        onClick={() => setOpen(true)}
        aria-label={`${d.adjust} ${name}`}
      >
        <SlidersHorizontal aria-hidden />
        {d.adjust}
      </Button>
      <Modal
        open={open}
        onOpenChange={(o) => (o ? setOpen(true) : close())}
        title={fill(d.adjustTitle, { name })}
        description={d.adjustBody}
      >
        <form
          className="flex flex-col gap-4"
          onSubmit={(e) => {
            e.preventDefault();
            if (!valid) return;
            run(() => adjustBalance(party, partyId, credit ? sdg : -sdg, why), {
              success: d.adjusted,
              onDone: close,
            });
          }}
        >
          <div role="radiogroup" aria-label={d.adjustDirection} className="grid grid-cols-2 gap-2">
            {[
              { value: true, label: d.adjustCredit },
              { value: false, label: d.adjustDebit },
            ].map((o) => (
              <button
                key={String(o.value)}
                type="button"
                role="radio"
                aria-checked={credit === o.value}
                onClick={() => setCredit(o.value)}
                className={cn(
                  'rounded-lg border px-3 py-2 text-sm font-medium transition-colors',
                  credit === o.value
                    ? 'border-foreground bg-foreground text-background'
                    : 'border-input hover:bg-muted',
                )}
              >
                {o.label}
              </button>
            ))}
          </div>
          <div className="flex flex-col gap-1.5">
            <label htmlFor={`${id}-amount`} className="text-sm font-medium">
              {d.adjustAmount}
            </label>
            <input
              id={`${id}-amount`}
              inputMode="numeric"
              dir="ltr"
              autoFocus
              value={amount}
              onChange={(e) => setAmount(e.target.value)}
              className={inputClass}
            />
            {sdg > 0 && (
              <p className="text-xs text-muted-foreground">
                {fill(credit ? d.adjustCreditNote : d.adjustDebitNote, {
                  amount: money(sdg, common.currency),
                })}
              </p>
            )}
          </div>
          <div className="flex flex-col gap-1.5">
            <label htmlFor={`${id}-why`} className="text-sm font-medium">
              {d.adjustReason}
            </label>
            <textarea
              id={`${id}-why`}
              rows={3}
              maxLength={500}
              value={why}
              onChange={(e) => setWhy(e.target.value)}
              className={`${inputClass} resize-none`}
            />
          </div>
          <div className="flex flex-wrap justify-end gap-2">
            <Button type="button" variant="outline" className="h-10 px-4" onClick={close}>
              {common.cancel}
            </Button>
            <Button type="submit" className="h-10 px-4" disabled={pending || !valid}>
              {pending && <Loader2 className="animate-spin" aria-hidden />}
              {d.adjustSave}
            </Button>
          </div>
        </form>
      </Modal>
    </>
  );
}
