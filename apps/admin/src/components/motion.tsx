'use client';

import { CircleAlert, CircleCheck, X } from 'lucide-react';
import {
  animate,
  AnimatePresence,
  motion,
  MotionConfig,
  useInView,
  useMotionValue,
  useReducedMotion,
  useTransform,
} from 'motion/react';
import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useRef,
  useState,
  type ReactNode,
} from 'react';
import { cn } from 'cn';

/** Shared easing for JS-driven motion; matches `--ease-out-soft` in globals.css. */
export const easeOut = [0.22, 1, 0.36, 1] as const;

type Toast = { id: number; tone: 'success' | 'error'; message: string };
type ToastApi = { success: (message: string) => void; error: (message: string) => void };

const ToastContext = createContext<ToastApi | null>(null);

export function useToast(): ToastApi {
  const api = useContext(ToastContext);
  if (!api) throw new Error('useToast needs <MotionProvider>');
  return api;
}

/**
 * Motion follows the OS "reduce motion" setting, and action results show as
 * toasts in a polite live region (always rendered, so screen readers hear them).
 */
export function MotionProvider({
  children,
  closeLabel,
}: {
  children: ReactNode;
  closeLabel: string;
}) {
  const [toasts, setToasts] = useState<Toast[]>([]);
  const next = useRef(0);
  const dismiss = useCallback((id: number) => setToasts((t) => t.filter((x) => x.id !== id)), []);
  const push = useCallback(
    (tone: Toast['tone'], message: string) => {
      const id = ++next.current;
      setToasts((t) => [...t.slice(-2), { id, tone, message }]);
      setTimeout(() => dismiss(id), tone === 'error' ? 7000 : 4000);
    },
    [dismiss],
  );
  const api = useMemo<ToastApi>(
    () => ({ success: (m) => push('success', m), error: (m) => push('error', m) }),
    [push],
  );

  return (
    <MotionConfig reducedMotion="user" transition={{ duration: 0.25, ease: easeOut }}>
      <ToastContext value={api}>
        {children}
        <div
          role="status"
          aria-live="polite"
          className="pointer-events-none fixed inset-x-4 bottom-4 z-[60] flex flex-col items-center gap-2 sm:inset-x-auto sm:end-6 sm:bottom-6 sm:items-end"
        >
          <AnimatePresence initial={false}>
            {toasts.map((t) => (
              <motion.div
                key={t.id}
                layout
                initial={{ opacity: 0, y: 16, scale: 0.96 }}
                animate={{ opacity: 1, y: 0, scale: 1 }}
                exit={{ opacity: 0, scale: 0.96, transition: { duration: 0.15 } }}
                className={cn(
                  'pointer-events-auto flex w-full max-w-sm items-start gap-3 rounded-xl px-4 py-3 text-sm shadow-lg ring-1',
                  t.tone === 'success'
                    ? 'bg-card text-foreground ring-success/30'
                    : 'bg-card text-foreground ring-destructive/40',
                )}
              >
                {t.tone === 'success' ? (
                  <CircleCheck className="mt-0.5 size-4.5 shrink-0 text-success" aria-hidden />
                ) : (
                  <CircleAlert className="mt-0.5 size-4.5 shrink-0 text-destructive" aria-hidden />
                )}
                <p className="flex-1 font-medium">{t.message}</p>
                <button
                  type="button"
                  onClick={() => dismiss(t.id)}
                  aria-label={closeLabel}
                  className="-m-1 grid size-7 shrink-0 cursor-pointer place-items-center rounded-md text-muted-foreground hover:bg-muted focus-visible:ring-2 focus-visible:ring-ring focus-visible:outline-none"
                >
                  <X className="size-4" />
                </button>
              </motion.div>
            ))}
          </AnimatePresence>
        </div>
      </ToastContext>
    </MotionConfig>
  );
}

const grouped = new Intl.NumberFormat('en-US');

/**
 * Counts up to [value] the first time it scrolls into view. The final text is
 * rendered on the server, so the number is right even before JS loads.
 * `template` wraps it, e.g. "SDG {amount}"; `suffix` follows it, e.g. "%".
 */
export function AnimatedNumber({
  value,
  template,
  suffix = '',
  className,
}: {
  value: number;
  template?: string;
  suffix?: string;
  className?: string;
}) {
  const ref = useRef<HTMLSpanElement>(null);
  const inView = useInView(ref, { once: true });
  const reduced = useReducedMotion();
  const started = useRef(false);
  const count = useMotionValue(value);
  const display = useTransform(count, (n) => {
    const s = grouped.format(Math.round(n)) + suffix;
    return template ? template.replace('{amount}', s) : s;
  });
  useEffect(() => {
    if (!inView) return;
    if (reduced) {
      count.jump(value);
      return;
    }
    // First time in view: count up from zero. Later changes glide from the old value.
    if (!started.current) count.jump(0);
    started.current = true;
    const controls = animate(count, value, {
      duration: Math.min(1.1, 0.5 + Math.log10(Math.abs(value) + 1) * 0.15),
      ease: easeOut,
    });
    return () => controls.stop();
  }, [inView, reduced, value, count]);
  return (
    <motion.span ref={ref} className={cn('tabular-nums', className)}>
      {display}
    </motion.span>
  );
}
