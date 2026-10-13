'use client';

import { Checkbox } from '@base-ui/react/checkbox';
import { Dialog } from '@base-ui/react/dialog';
import { Check, CircleCheck, Loader2, X } from 'lucide-react';
import { useId, useState, type ReactNode } from 'react';
import { Button } from '@/components/ui/button';

/** Centred dialog with a title and optional description; the caller supplies the body and buttons. */
export function Modal({
  open,
  onOpenChange,
  title,
  description,
  children,
}: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  title: string;
  description?: string;
  children: ReactNode;
}) {
  return (
    <Dialog.Root open={open} onOpenChange={onOpenChange}>
      <Dialog.Portal>
        <Dialog.Backdrop className="fixed inset-0 z-40 bg-black/40 transition-opacity duration-150 data-ending-style:opacity-0 data-starting-style:opacity-0" />
        <Dialog.Popup className="fixed top-1/2 left-1/2 z-50 flex w-[28rem] max-w-[calc(100vw-2rem)] -translate-x-1/2 -translate-y-1/2 flex-col gap-4 rounded-xl bg-popover p-5 text-popover-foreground shadow-lg ring-1 ring-foreground/10 transition-[scale,opacity] duration-150 data-ending-style:scale-95 data-ending-style:opacity-0 data-starting-style:scale-95 data-starting-style:opacity-0">
          <div className="flex flex-col gap-1">
            <Dialog.Title className="text-lg font-semibold">{title}</Dialog.Title>
            {description && (
              <Dialog.Description className="text-sm text-muted-foreground">
                {description}
              </Dialog.Description>
            )}
          </div>
          {children}
        </Dialog.Popup>
      </Dialog.Portal>
    </Dialog.Root>
  );
}

/**
 * Polite live region for the result of an action ("Payment confirmed…").
 * The region is always rendered (screen readers only announce changes to a
 * region that already exists); while empty it is taken out of the layout.
 */
export function Notice({
  message,
  onDismiss,
  closeLabel,
}: {
  message: string | null;
  onDismiss: () => void;
  closeLabel: string;
}) {
  return (
    <div role="status" aria-live="polite" className={message ? undefined : 'sr-only'}>
      {message && (
        <div className="flex items-start gap-3 rounded-xl bg-success-soft px-4 py-3 text-sm text-success ring-1 ring-success/20">
          <CircleCheck className="mt-0.5 size-4.5 shrink-0" aria-hidden />
          <p className="flex-1 font-medium">{message}</p>
          <button
            type="button"
            onClick={onDismiss}
            aria-label={closeLabel}
            className="-m-1 grid size-7 shrink-0 place-items-center rounded-md hover:bg-success/10 focus-visible:ring-2 focus-visible:ring-ring focus-visible:outline-none"
          >
            <X className="size-4" />
          </button>
        </div>
      )}
    </div>
  );
}

/** Charcoal checkbox (never red, so it doesn't read as an error). */
export function CheckField({
  checked,
  onCheckedChange,
  label,
  hint,
}: {
  checked: boolean;
  onCheckedChange: (checked: boolean) => void;
  label: string;
  hint?: string;
}) {
  return (
    <label className="flex cursor-pointer items-start gap-3 rounded-lg p-2 hover:bg-muted/60">
      <Checkbox.Root
        checked={checked}
        onCheckedChange={(value) => onCheckedChange(value)}
        className="mt-0.5 grid size-5 shrink-0 place-items-center rounded-md border-2 border-input bg-card text-background transition-colors focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 focus-visible:ring-offset-card focus-visible:outline-none data-checked:border-foreground data-checked:bg-foreground"
      >
        <Checkbox.Indicator className="data-unchecked:hidden">
          <Check className="size-3.5" strokeWidth={3} />
        </Checkbox.Indicator>
      </Checkbox.Root>
      <span className="flex flex-col gap-0.5">
        <span className="text-sm font-medium">{label}</span>
        {hint && <span className="text-xs text-muted-foreground">{hint}</span>}
      </span>
    </label>
  );
}

/**
 * Asks before a consequential action. With [reasonLabel] it also asks why, and
 * the confirm button stays disabled until a reason is written.
 */
export function ConfirmDialog({
  open,
  onOpenChange,
  title,
  description,
  confirmLabel,
  cancelLabel,
  tone = 'default',
  reasonLabel,
  reasonPlaceholder,
  pending,
  onConfirm,
}: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  title: string;
  description?: string;
  confirmLabel: string;
  cancelLabel: string;
  tone?: 'default' | 'danger';
  reasonLabel?: string;
  reasonPlaceholder?: string;
  pending?: boolean;
  onConfirm: (reason: string) => void;
}) {
  const [reason, setReason] = useState('');
  const reasonId = useId();
  const needsReason = reasonLabel !== undefined;
  return (
    <Modal
      open={open}
      onOpenChange={(next) => {
        onOpenChange(next);
        if (!next) setReason('');
      }}
      title={title}
      description={description}
    >
      <form
        className="flex flex-col gap-4"
        onSubmit={(e) => {
          e.preventDefault();
          if (!needsReason || reason.trim()) onConfirm(reason.trim());
        }}
      >
        {needsReason && (
          <div className="flex flex-col gap-1.5">
            <label htmlFor={reasonId} className="text-sm font-medium">
              {reasonLabel}
            </label>
            <textarea
              id={reasonId}
              autoFocus
              required
              rows={3}
              maxLength={500}
              value={reason}
              onChange={(e) => setReason(e.target.value)}
              placeholder={reasonPlaceholder}
              className="w-full resize-none rounded-lg border border-input bg-card px-3 py-2 text-base outline-none focus-visible:border-ring focus-visible:ring-2 focus-visible:ring-ring/30"
            />
          </div>
        )}
        <div className="flex flex-wrap justify-end gap-2">
          <Button
            type="button"
            variant="outline"
            className="h-10 px-4"
            onClick={() => onOpenChange(false)}
          >
            {cancelLabel}
          </Button>
          <Button
            type="submit"
            variant={tone === 'danger' ? 'destructive' : 'default'}
            className="h-10 px-4"
            disabled={pending || (needsReason && !reason.trim())}
          >
            {pending && <Loader2 className="animate-spin" aria-hidden />}
            {confirmLabel}
          </Button>
        </div>
      </form>
    </Modal>
  );
}
