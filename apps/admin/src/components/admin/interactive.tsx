'use client';

import { Checkbox } from '@base-ui/react/checkbox';
import { Dialog } from '@base-ui/react/dialog';
import { Check, CircleCheck, X } from 'lucide-react';
import { useEffect, useState, type ReactNode } from 'react';
import { cn } from 'cn';

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

/** A button for an action the demo can't carry out; says so next to it for a few seconds. */
export function DemoAction({
  label,
  note,
  icon,
}: {
  label: string;
  note: string;
  icon?: ReactNode;
}) {
  const [shown, setShown] = useState(false);
  useEffect(() => {
    if (!shown) return;
    const id = setTimeout(() => setShown(false), 3000);
    return () => clearTimeout(id);
  }, [shown]);
  return (
    <span className="inline-flex flex-wrap items-center gap-2">
      <button
        type="button"
        onClick={() => setShown(true)}
        className="inline-flex h-8 items-center gap-1.5 rounded-lg border border-border bg-card px-2.5 text-sm font-medium hover:bg-muted focus-visible:ring-2 focus-visible:ring-ring focus-visible:outline-none [&_svg]:size-4"
      >
        {icon}
        {label}
      </button>
      <span role="status" className={cn('text-xs text-muted-foreground', !shown && 'sr-only')}>
        {shown ? note : ''}
      </span>
    </span>
  );
}
