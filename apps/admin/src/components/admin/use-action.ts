'use client';

import { useTransition } from 'react';
import { useToast } from '@/components/motion';
import type { Dictionary } from '@/i18n/dictionaries';
import type { ActionResult } from '@/lib/actions/result';

export type ErrorLabels = Dictionary['errors'];

export function errorText(errors: ErrorLabels, code: string): string {
  return code in errors ? errors[code as keyof ErrorLabels] : errors.FAILED;
}

/**
 * Runs a server action in a transition and reports the result as a toast.
 * `onFail` undoes any optimistic change the caller made.
 */
export function useAction(errors: ErrorLabels) {
  const toast = useToast();
  const [pending, startTransition] = useTransition();
  const run = (
    action: () => Promise<ActionResult>,
    { success, onDone, onFail }: { success: string; onDone?: () => void; onFail?: () => void },
  ) =>
    startTransition(async () => {
      try {
        const result = await action();
        if (result.ok) {
          toast.success(success);
          onDone?.();
        } else {
          toast.error(errorText(errors, result.error));
          onFail?.();
        }
      } catch {
        toast.error(errors.FAILED);
        onFail?.();
      }
    });
  return { pending, run };
}
