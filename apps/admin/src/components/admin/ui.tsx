import { Tabs } from '@base-ui/react/tabs';
import { ArrowUpRight, FlaskConical } from 'lucide-react';
import Link from 'next/link';
import type { ComponentProps, CSSProperties, ReactNode } from 'react';
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
  description?: ReactNode;
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

/** Staggered entrance for the [i]th item of a group (see `rise` in globals.css). */
export const riseStyle = (i: number) => ({ '--i': i }) as CSSProperties;

/**
 * KPI tile: label, value, optional note. With [href] the whole tile is a link
 * that lifts slightly on hover. [index] staggers its entrance with its siblings.
 */
export function StatCard({
  label,
  value,
  note,
  tone,
  icon,
  index = 0,
  href,
  children,
}: {
  label: string;
  value: ReactNode;
  note?: ReactNode;
  tone?: Tone;
  icon?: ReactNode;
  index?: number;
  href?: string;
  children?: ReactNode;
}) {
  const body = (
    <>
      <div className="flex items-center gap-2 text-sm text-muted-foreground">
        {icon && (
          <span
            className={cn(
              'grid size-7 place-items-center rounded-lg bg-muted text-foreground [&_svg]:size-4',
              tone === 'warning' && 'bg-warning-soft text-warning',
              tone === 'success' && 'bg-success-soft text-success',
              tone === 'info' && 'bg-info-soft text-info',
            )}
          >
            {icon}
          </span>
        )}
        <span className="truncate">{label}</span>
      </div>
      <div className="mt-3 text-2xl font-bold">{value}</div>
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
      {children}
    </>
  );
  const shell =
    'rise group relative block rounded-xl bg-card p-4 ring-1 ring-foreground/10 transition-[box-shadow,transform] duration-200 ease-out-soft';
  if (!href) {
    return (
      <div className={shell} style={riseStyle(index)}>
        {body}
      </div>
    );
  }
  return (
    <Link
      href={href}
      className={cn(
        shell,
        'cursor-pointer hover:-translate-y-0.5 hover:shadow-md hover:ring-foreground/20 focus-visible:ring-2 focus-visible:ring-ring focus-visible:outline-none',
      )}
      style={riseStyle(index)}
    >
      {body}
      <ArrowUpRight
        aria-hidden
        className="absolute end-3 top-3 size-4 text-muted-foreground opacity-0 transition-opacity group-hover:opacity-100 rtl:-scale-x-100"
      />
    </Link>
  );
}

/** Placeholder block shown while data streams in. */
export function Skeleton({ className }: { className?: string }) {
  return <div aria-hidden className={cn('skeleton h-4', className)} />;
}

/** Stat tiles + a panel of rows: the default loading shape of a console page. */
export function PageSkeleton({ stats = 4, rows = 6 }: { stats?: number; rows?: number }) {
  return (
    <div className="flex flex-col gap-6" aria-busy>
      {stats > 0 && (
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 xl:grid-cols-4">
          {Array.from({ length: stats }, (_, i) => (
            <div key={i} className="rounded-xl bg-card p-4 ring-1 ring-foreground/10">
              <Skeleton className="w-28" />
              <Skeleton className="mt-4 h-7 w-20" />
              <Skeleton className="mt-2 h-3 w-32" />
            </div>
          ))}
        </div>
      )}
      <TableSkeleton rows={rows} />
    </div>
  );
}

export function TableSkeleton({ rows = 6 }: { rows?: number }) {
  return (
    <div className="rounded-xl bg-card ring-1 ring-foreground/10">
      <div className="border-b px-4 py-3">
        <Skeleton className="w-40" />
      </div>
      {Array.from({ length: rows }, (_, i) => (
        <div key={i} className="flex items-center gap-4 border-b px-4 py-3.5 last:border-0">
          <Skeleton className="size-9 shrink-0 rounded-lg" />
          <div className="flex flex-1 flex-col gap-2">
            <Skeleton className="w-1/3" />
            <Skeleton className="h-3 w-1/4" />
          </div>
          <Skeleton className="h-6 w-20" />
        </div>
      ))}
    </div>
  );
}

/** Says plainly that a screen shows sample data and when the real thing arrives. */
export function SampleBanner({ title, body }: { title: string; body: string }) {
  return (
    <div className="rise flex items-start gap-3 rounded-xl border border-dashed border-warning/50 bg-warning-soft/40 px-4 py-3 text-sm">
      <FlaskConical className="mt-0.5 size-4.5 shrink-0 text-warning" aria-hidden />
      <p>
        <span className="font-semibold">{title}</span>{' '}
        <span className="text-muted-foreground">{body}</span>
      </p>
    </div>
  );
}

/** Small "sample" tag for nav items and queue rows that aren't live yet. */
export function SampleTag({ label, className }: { label: string; className?: string }) {
  return (
    <span
      className={cn(
        'inline-flex h-5 items-center rounded border border-dashed border-current px-1.5 text-[10px] font-semibold opacity-70',
        className,
      )}
    >
      {label}
    </span>
  );
}

export function EmptyState({
  icon,
  title,
  body,
  action,
}: {
  icon: ReactNode;
  title: string;
  body?: string;
  action?: ReactNode;
}) {
  return (
    <div className="rise flex flex-col items-center gap-3 px-6 py-14 text-center">
      <span className="grid size-12 place-items-center rounded-2xl bg-muted text-muted-foreground [&_svg]:size-6">
        {icon}
      </span>
      <div>
        <p className="text-base font-semibold">{title}</p>
        {body && <p className="mx-auto mt-1 max-w-md text-sm text-muted-foreground">{body}</p>}
      </div>
      {action}
    </div>
  );
}

/** A coloured dot + text, e.g. "Live" next to the page title. */
export function LiveDot({ label }: { label: string }) {
  return (
    <span className="inline-flex h-7 items-center gap-2 rounded-md bg-success-soft px-2.5 text-xs font-semibold text-success">
      <span className="relative flex size-2">
        <span className="absolute inline-flex size-full animate-ping rounded-full bg-success opacity-60 [animation-iteration-count:3]" />
        <span className="relative inline-flex size-2 rounded-full bg-success" />
      </span>
      {label}
    </span>
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

/** Tab style for Base UI `Tabs.Tab`; the underline is the sliding indicator in `TabList`. */
export const tabClass =
  'relative inline-flex h-11 cursor-pointer items-center gap-2 px-3 text-sm font-medium whitespace-nowrap text-muted-foreground transition-colors outline-none select-none hover:text-foreground focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-inset data-active:text-foreground';

/** Tab strip whose charcoal underline glides to the active tab. */
export function TabList({ children, className }: { children: ReactNode; className?: string }) {
  return (
    <Tabs.List className={cn('relative flex gap-1 overflow-x-auto border-b', className)}>
      {children}
      <Tabs.Indicator className="absolute bottom-0 left-0 h-0.5 w-(--active-tab-width) translate-x-(--active-tab-left) rounded-full bg-foreground transition-[translate,width] duration-300 ease-out-soft" />
    </Tabs.List>
  );
}

export function CountPill({ children }: { children: ReactNode }) {
  return (
    <span className="min-w-5 rounded-full bg-muted px-1.5 text-center text-xs leading-5 font-semibold text-foreground tabular-nums">
      {children}
    </span>
  );
}
