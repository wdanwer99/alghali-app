import type { ComponentProps, ReactNode } from 'react';
import { cn } from 'cn';

/**
 * The placeholder brand mark: "ع" + dot = "غ". Glyph and dot positions were
 * measured against the apps' icon (apps/partner/assets/icon/icon.png) so
 * both read as the same logo.
 */
export function Mark({ size = 36, className }: { size?: number; className?: string }) {
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 100 100"
      role="img"
      aria-hidden="true"
      className={cn('shrink-0', className)}
    >
      <rect width="100" height="100" rx="24" fill="#b91c1c" />
      <text
        x="48.5"
        y="69.7"
        textAnchor="middle"
        fontSize="53.5"
        fontWeight="700"
        fill="#fff"
        style={{ fontFamily: 'var(--font-sans)' }}
      >
        ع
      </text>
      <circle cx="50" cy="26" r="5.5" fill="#fff" />
    </svg>
  );
}

export type Tone = 'neutral' | 'success' | 'warning' | 'danger' | 'info' | 'brand';

const toneClass: Record<Tone, string> = {
  neutral: 'bg-muted text-muted-foreground',
  success: 'bg-success-soft text-success',
  warning: 'bg-warning-soft text-warning',
  danger: 'bg-danger-soft text-destructive',
  info: 'bg-info-soft text-info',
  brand: 'bg-brand text-brand-foreground',
};

/** Status label; colour always comes with text, never alone. */
export function StatusBadge({
  tone = 'neutral',
  children,
  className,
}: {
  tone?: Tone;
  children: ReactNode;
  className?: string;
}) {
  return (
    <span
      className={cn(
        'inline-flex h-6 items-center gap-1 rounded-md px-2 text-xs font-semibold whitespace-nowrap',
        toneClass[tone],
        className,
      )}
    >
      {children}
    </span>
  );
}

export function PageHeader({
  title,
  description,
  actions,
}: {
  title: string;
  description?: string;
  actions?: ReactNode;
}) {
  return (
    <header className="flex flex-wrap items-end justify-between gap-4">
      <div className="min-w-0">
        <h1 className="text-2xl font-bold tracking-normal">{title}</h1>
        {description && (
          <p className="mt-1 max-w-3xl text-sm text-muted-foreground">{description}</p>
        )}
      </div>
      {actions && <div className="flex flex-wrap items-center gap-2">{actions}</div>}
    </header>
  );
}

/** KPI tile: label, value (proportional figures), optional note. */
export function StatCard({
  label,
  value,
  note,
  tone,
  icon,
}: {
  label: string;
  value: string;
  note?: string;
  tone?: Tone;
  icon?: ReactNode;
}) {
  return (
    <div className="rounded-xl bg-card p-4 ring-1 ring-foreground/10">
      <div className="flex items-center gap-2 text-sm text-muted-foreground">
        {icon && (
          <span
            className={cn(
              '[&_svg]:size-4',
              tone === 'warning' && 'text-warning',
              tone === 'success' && 'text-success',
            )}
          >
            {icon}
          </span>
        )}
        <span>{label}</span>
      </div>
      <div className="mt-2 text-2xl font-bold">{value}</div>
      {note && (
        <div
          className={cn(
            'mt-1 text-xs',
            tone === 'warning' ? 'text-warning' : 'text-muted-foreground',
          )}
        >
          {note}
        </div>
      )}
    </div>
  );
}

export function Panel({
  title,
  actions,
  children,
  className,
}: {
  title?: string;
  actions?: ReactNode;
  children: ReactNode;
  className?: string;
}) {
  return (
    <section className={cn('rounded-xl bg-card ring-1 ring-foreground/10', className)}>
      {(title || actions) && (
        <div className="flex items-center justify-between gap-3 border-b px-4 py-3">
          {title && <h2 className="text-base font-semibold">{title}</h2>}
          {actions}
        </div>
      )}
      {children}
    </section>
  );
}

export function Table({ className, ...props }: ComponentProps<'table'>) {
  return (
    <div className="w-full overflow-x-auto">
      <table className={cn('w-full border-collapse text-sm', className)} {...props} />
    </div>
  );
}

export function Th({ className, ...props }: ComponentProps<'th'>) {
  return (
    <th
      scope="col"
      className={cn(
        'border-b px-4 py-2.5 text-start text-xs font-semibold whitespace-nowrap text-muted-foreground',
        className,
      )}
      {...props}
    />
  );
}

export function Td({ className, ...props }: ComponentProps<'td'>) {
  return (
    <td className={cn('border-b px-4 py-3 align-middle whitespace-nowrap', className)} {...props} />
  );
}

/** Numbers in table columns align, so they use tabular figures. */
export function Num({ children, className }: { children: ReactNode; className?: string }) {
  return <span className={cn('whitespace-nowrap tabular-nums', className)}>{children}</span>;
}

/** Underlined tab style for Base UI `Tabs.Tab` (active = charcoal underline). */
export const tabClass =
  'relative inline-flex h-11 items-center gap-2 px-3 text-sm font-medium whitespace-nowrap text-muted-foreground outline-none select-none hover:text-foreground focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-inset data-active:text-foreground after:absolute after:inset-x-2 after:-bottom-px after:h-0.5 after:rounded-full data-active:after:bg-foreground';

export function CountPill({ children }: { children: ReactNode }) {
  return (
    <span className="min-w-5 rounded-full bg-muted px-1.5 text-center text-xs leading-5 font-semibold text-foreground tabular-nums">
      {children}
    </span>
  );
}

export function DemoBadge({ label, note }: { label: string; note: string }) {
  return (
    <span
      title={note}
      className="inline-flex h-7 items-center rounded-md border border-dashed border-input px-2 text-xs font-medium text-muted-foreground"
    >
      {label}
    </span>
  );
}
