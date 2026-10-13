'use client';

import { Dialog } from '@base-ui/react/dialog';
import { Switch } from '@base-ui/react/switch';
import { Ban, Check, RotateCcw, Search, Star, Store, X } from 'lucide-react';
import { AnimatePresence, LayoutGroup, motion } from 'motion/react';
import { useMemo, useState, type MouseEvent, type ReactNode } from 'react';
import { cn } from 'cn';
import { Button } from '@/components/ui/button';
import type { Locale } from '@/i18n/config';
import type { Dictionary } from '@/i18n/dictionaries';
import { setShopStatus, verifyShop } from '@/lib/actions/admin';
import type { Shop, ShopStatus } from '@/lib/data/shops';
import { named } from '@/lib/data/util';
import { digits, fill, searchKey } from '@/lib/format';
import { ConfirmDialog } from './interactive';
import { phoneText, ShopFacts, shopPlace } from './shop-facts';
import { useAction } from './use-action';
import { EmptyState, Num, Panel, StatusBadge, Table, Td, Th, type Tone } from './ui';

export type ShopRow = Shop & { joined: string };

type Labels = {
  shops: Dictionary['shops'];
  approvals: Dictionary['approvals'];
  common: Dictionary['common'];
  errors: Dictionary['errors'];
  status: Dictionary['status']['shop'];
};

const statusTone: Record<ShopStatus, Tone> = {
  APPROVED: 'success',
  PENDING: 'warning',
  SUSPENDED: 'danger',
  REJECTED: 'neutral',
};
const filters = ['ALL', 'APPROVED', 'PENDING', 'SUSPENDED', 'REJECTED'] as const;
type Filter = (typeof filters)[number];

/** What the admin is about to do, waiting for confirmation. */
type Pending = { shop: Shop; to: 'SUSPENDED' | 'REJECTED' } | null;

export function ShopsBoard({ shops, locale, t }: { shops: ShopRow[]; locale: Locale; t: Labels }) {
  const [filter, setFilter] = useState<Filter>('ALL');
  const [query, setQuery] = useState('');
  const [openId, setOpenId] = useState<string | null>(null);
  const [confirm, setConfirm] = useState<Pending>(null);
  // Optimistic overrides until the refreshed list arrives from the server.
  const [verified, setVerified] = useState<Record<string, boolean>>({});
  const { pending, run } = useAction(t.errors);

  const counts = useMemo(() => {
    const c: Record<Filter, number> = {
      ALL: shops.length,
      APPROVED: 0,
      PENDING: 0,
      SUSPENDED: 0,
      REJECTED: 0,
    };
    for (const s of shops) c[s.status] += 1;
    return c;
  }, [shops]);

  const q = searchKey(query);
  const shown = shops.filter(
    (s) =>
      (filter === 'ALL' || s.status === filter) &&
      (!q ||
        [
          s.name.ar,
          s.name.en,
          s.owner?.name ?? '',
          s.owner?.email ?? '',
          s.phone ?? '',
          s.whatsapp ?? '',
        ]
          .map(searchKey)
          .some((x) => x.includes(q))),
  );
  const openShop = shops.find((s) => s.id === openId) ?? null;
  const isVerified = (s: Shop) => verified[s.id] ?? s.verified;
  const shopName = (s: Shop) => named(s.name, locale);

  const toggleVerified = (s: Shop, next: boolean) => {
    setVerified((v) => ({ ...v, [s.id]: next }));
    run(() => verifyShop(s.id, next), {
      success: fill(next ? t.shops.verifyOn : t.shops.verifyOff, { shop: shopName(s) }),
      onFail: () =>
        setVerified((v) => {
          const rest = { ...v };
          delete rest[s.id];
          return rest;
        }),
    });
  };

  const changeStatus = (s: Shop, to: ShopStatus, reason?: string) => {
    setConfirm(null);
    const success =
      to === 'APPROVED'
        ? s.status === 'PENDING'
          ? t.approvals.approved
          : t.shops.reinstated
        : to === 'SUSPENDED'
          ? t.shops.suspended
          : t.approvals.rejectedToast;
    run(() => setShopStatus(s.id, to, reason), { success: fill(success, { shop: shopName(s) }) });
  };

  const actions = (s: Shop, size: 'row' | 'panel') => {
    const cls = size === 'row' ? 'h-8 px-2.5' : 'h-10 px-4';
    const stop = (e: MouseEvent) => e.stopPropagation();
    if (s.status === 'PENDING') {
      return (
        <>
          <Button
            className={cls}
            disabled={pending}
            onClick={(e) => (stop(e), changeStatus(s, 'APPROVED'))}
          >
            <Check />
            {t.common.approve}
          </Button>
          <Button
            variant="outline"
            className={cls}
            disabled={pending}
            onClick={(e) => (stop(e), setConfirm({ shop: s, to: 'REJECTED' }))}
          >
            <X />
            {t.common.reject}
          </Button>
        </>
      );
    }
    if (s.status === 'APPROVED') {
      return (
        <Button
          variant="outline"
          className={cls}
          disabled={pending}
          onClick={(e) => (stop(e), setConfirm({ shop: s, to: 'SUSPENDED' }))}
        >
          <Ban />
          {t.shops.suspend}
        </Button>
      );
    }
    return (
      <Button
        variant="outline"
        className={cls}
        disabled={pending}
        onClick={(e) => (stop(e), changeStatus(s, 'APPROVED'))}
      >
        <RotateCcw />
        {t.shops.reinstate}
      </Button>
    );
  };

  return (
    <>
      <div className="flex flex-col gap-3 lg:flex-row lg:items-center lg:justify-between">
        <LayoutGroup id="shop-filter">
          <div
            role="group"
            aria-label={t.common.status}
            className="flex flex-wrap gap-1 rounded-xl bg-muted p-1"
          >
            {filters.map((f) => (
              <button
                key={f}
                type="button"
                aria-pressed={filter === f}
                onClick={() => setFilter(f)}
                className={cn(
                  'relative inline-flex h-8 cursor-pointer items-center gap-1.5 rounded-lg px-3 text-sm font-medium transition-colors focus-visible:ring-2 focus-visible:ring-ring focus-visible:outline-none',
                  filter === f ? 'text-foreground' : 'text-muted-foreground hover:text-foreground',
                )}
              >
                {filter === f && (
                  <motion.span
                    layoutId="filter-pill"
                    className="absolute inset-0 rounded-lg bg-card shadow-sm"
                    transition={{ type: 'spring', stiffness: 500, damping: 38 }}
                  />
                )}
                <span className="relative">{f === 'ALL' ? t.common.all : t.status[f]}</span>
                <span className="relative text-xs tabular-nums opacity-70">{counts[f]}</span>
              </button>
            ))}
          </div>
        </LayoutGroup>
        <label className="relative block lg:w-72">
          <span className="sr-only">{t.common.search}</span>
          <Search className="pointer-events-none absolute start-3 top-1/2 size-4 -translate-y-1/2 text-muted-foreground" />
          <input
            type="search"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder={t.shops.searchPlaceholder}
            className="h-10 w-full rounded-lg border border-input bg-card ps-9 pe-3 text-base outline-none focus-visible:border-ring focus-visible:ring-2 focus-visible:ring-ring/30"
          />
        </label>
      </div>

      <Panel
        title={fill(t.shops.count, { n: digits(shown.length) })}
        actions={<span className="text-xs text-muted-foreground">{t.shops.verifiedHint}</span>}
      >
        {shown.length === 0 ? (
          <EmptyState icon={<Store />} title={t.shops.empty} body={t.shops.emptyBody} />
        ) : (
          <Table>
            <thead>
              <tr>
                <Th>{t.common.shop}</Th>
                <Th className="hidden md:table-cell">{t.shops.owner}</Th>
                <Th className="text-end">{t.shops.listings}</Th>
                <Th className="hidden sm:table-cell">{t.shops.rating}</Th>
                <Th>{t.shops.verified}</Th>
                <Th>{t.common.status}</Th>
                <Th className="text-end">
                  <span className="sr-only">{t.common.details}</span>
                </Th>
              </tr>
            </thead>
            <tbody>
              <AnimatePresence initial={false}>
                {shown.map((s) => (
                  <motion.tr
                    key={s.id}
                    layout="position"
                    initial={{ opacity: 0 }}
                    animate={{ opacity: 1 }}
                    exit={{ opacity: 0 }}
                    transition={{ duration: 0.18 }}
                    onClick={() => setOpenId(s.id)}
                    className="group cursor-pointer transition-colors hover:bg-muted/50"
                  >
                    <Td className="max-w-72 whitespace-normal">
                      <button
                        type="button"
                        onClick={(e) => (e.stopPropagation(), setOpenId(s.id))}
                        className="cursor-pointer text-start font-medium underline-offset-2 group-hover:underline focus-visible:underline focus-visible:outline-none"
                      >
                        {shopName(s)}
                      </button>
                      <div className="truncate text-xs text-muted-foreground">
                        {shopPlace(s, locale, t.approvals)}
                      </div>
                    </Td>
                    <Td className="hidden md:table-cell">
                      <div className="text-sm">{s.owner?.name ?? '—'}</div>
                      {s.phone && (
                        <div className="text-xs text-muted-foreground">{phoneText(s.phone)}</div>
                      )}
                    </Td>
                    <Td className="text-end">
                      <Num>{s.listings}</Num>
                    </Td>
                    <Td className="hidden sm:table-cell">
                      {s.rating.count > 0 ? (
                        <span className="inline-flex items-center gap-1 text-sm">
                          <Star className="size-3.5 fill-warning text-warning" aria-hidden />
                          <Num>{s.rating.avg.toFixed(1)}</Num>
                          <span className="text-xs text-muted-foreground">({s.rating.count})</span>
                        </span>
                      ) : (
                        <span className="text-xs text-muted-foreground">{t.shops.noRating}</span>
                      )}
                    </Td>
                    <Td onClick={(e) => e.stopPropagation()}>
                      <VerifiedSwitch
                        checked={isVerified(s)}
                        disabled={s.status !== 'APPROVED'}
                        label={`${t.shops.verified}: ${shopName(s)}`}
                        onChange={(next) => toggleVerified(s, next)}
                      />
                    </Td>
                    <Td>
                      <StatusBadge tone={statusTone[s.status]}>{t.status[s.status]}</StatusBadge>
                    </Td>
                    <Td className="text-end">
                      <span className="inline-flex gap-1.5">{actions(s, 'row')}</span>
                    </Td>
                  </motion.tr>
                ))}
              </AnimatePresence>
            </tbody>
          </Table>
        )}
      </Panel>

      <ShopDrawer
        shop={openShop}
        onClose={() => setOpenId(null)}
        locale={locale}
        t={t}
        verified={openShop ? isVerified(openShop) : false}
        onVerify={(next) => openShop && toggleVerified(openShop, next)}
        actions={openShop ? actions(openShop, 'panel') : null}
      />

      <ConfirmDialog
        open={confirm !== null}
        onOpenChange={(o) => !o && setConfirm(null)}
        title={
          confirm
            ? fill(confirm.to === 'SUSPENDED' ? t.shops.suspendTitle : t.approvals.rejectTitle, {
                shop: shopName(confirm.shop),
              })
            : ''
        }
        description={confirm?.to === 'SUSPENDED' ? t.shops.suspendBody : t.approvals.rejectBody}
        reasonLabel={t.approvals.reason}
        reasonPlaceholder={confirm?.to === 'REJECTED' ? t.approvals.reasonPlaceholder : undefined}
        confirmLabel={confirm?.to === 'SUSPENDED' ? t.shops.suspend : t.common.reject}
        cancelLabel={t.common.cancel}
        tone="danger"
        pending={pending}
        onConfirm={(reason) => confirm && changeStatus(confirm.shop, confirm.to, reason)}
      />
    </>
  );
}

function VerifiedSwitch({
  checked,
  disabled,
  label,
  onChange,
}: {
  checked: boolean;
  disabled?: boolean;
  label: string;
  onChange: (next: boolean) => void;
}) {
  return (
    <Switch.Root
      checked={checked}
      disabled={disabled}
      onCheckedChange={onChange}
      aria-label={label}
      className="relative flex h-6 w-11 shrink-0 cursor-pointer items-center rounded-full bg-input/60 p-0.5 transition-colors duration-200 focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 focus-visible:ring-offset-card focus-visible:outline-none data-checked:bg-success data-disabled:cursor-not-allowed data-disabled:opacity-40"
    >
      <Switch.Thumb className="size-5 rounded-full bg-white shadow-sm transition-transform duration-200 ease-out-soft data-checked:translate-x-5 rtl:data-checked:-translate-x-5" />
    </Switch.Root>
  );
}

/** Slides in from the inline end with everything about one shop. */
function ShopDrawer({
  shop,
  onClose,
  locale,
  t,
  verified,
  onVerify,
  actions,
}: {
  shop: ShopRow | null;
  onClose: () => void;
  locale: Locale;
  t: Labels;
  verified: boolean;
  onVerify: (next: boolean) => void;
  actions: ReactNode;
}) {
  return (
    <Dialog.Root open={shop !== null} onOpenChange={(o) => !o && onClose()}>
      <Dialog.Portal>
        <Dialog.Backdrop className="fixed inset-0 z-40 bg-black/30 transition-opacity duration-200 data-ending-style:opacity-0 data-starting-style:opacity-0" />
        <Dialog.Popup className="fixed inset-y-0 end-0 z-50 flex w-[28rem] max-w-[92vw] flex-col overflow-y-auto bg-popover text-popover-foreground shadow-2xl transition-transform duration-300 ease-out-soft data-ending-style:translate-x-full data-starting-style:translate-x-full rtl:data-ending-style:-translate-x-full rtl:data-starting-style:-translate-x-full">
          {shop && (
            <>
              <div className="flex items-start gap-3 border-b p-5">
                <span className="grid size-11 shrink-0 place-items-center rounded-xl bg-muted">
                  <Store className="size-5" aria-hidden />
                </span>
                <div className="min-w-0 flex-1">
                  <Dialog.Title className="text-lg font-semibold">
                    {named(shop.name, locale)}
                  </Dialog.Title>
                  <div className="mt-1 flex flex-wrap items-center gap-2">
                    <StatusBadge tone={statusTone[shop.status]}>
                      {t.status[shop.status]}
                    </StatusBadge>
                    <span className="text-xs text-muted-foreground">
                      {shop.status === 'PENDING' ? t.shops.applied : t.shops.joined}: {shop.joined}
                    </span>
                  </div>
                </div>
                <Dialog.Close
                  aria-label={t.common.close}
                  className="grid size-9 cursor-pointer place-items-center rounded-lg text-muted-foreground hover:bg-muted"
                >
                  <X className="size-5" />
                </Dialog.Close>
              </div>

              <div className="flex flex-col gap-5 p-5">
                {shop.statusReason && shop.status !== 'APPROVED' && (
                  <div className="rounded-lg bg-muted px-3 py-2.5 text-sm">
                    <span className="font-semibold">{t.shops.reasonGiven}: </span>
                    {shop.statusReason}
                  </div>
                )}
                <ShopFacts shop={shop} locale={locale} d={t.approvals} common={t.common} />

                <div className="grid grid-cols-3 gap-2 text-center">
                  <Mini label={t.shops.listings} value={digits(shop.listings)} />
                  <Mini
                    label={t.shops.rating}
                    value={shop.rating.count ? shop.rating.avg.toFixed(1) : '—'}
                  />
                  <Mini label={t.shops.staffLabel} value={digits(shop.staff)} />
                </div>

                <Hours hours={shop.openingHours} t={t.shops} />

                <label className="flex items-center justify-between gap-3 rounded-lg border px-3 py-2.5">
                  <span>
                    <span className="block text-sm font-medium">{t.shops.verified}</span>
                    <span className="block text-xs text-muted-foreground">
                      {t.shops.verifiedHint}
                    </span>
                  </span>
                  <VerifiedSwitch
                    checked={verified}
                    disabled={shop.status !== 'APPROVED'}
                    label={t.shops.verified}
                    onChange={onVerify}
                  />
                </label>
              </div>

              <div className="mt-auto flex flex-wrap gap-2 border-t p-5">{actions}</div>
            </>
          )}
        </Dialog.Popup>
      </Dialog.Portal>
    </Dialog.Root>
  );
}

function Mini({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-lg bg-muted/70 px-2 py-2.5">
      <div className="text-base font-bold tabular-nums">{value}</div>
      <div className="truncate text-xs text-muted-foreground">{label}</div>
    </div>
  );
}

const hhmm = (minutes: number) =>
  `${String(Math.floor(minutes / 60)).padStart(2, '0')}:${String(minutes % 60).padStart(2, '0')}`;

const WEEKDAYS = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

/** Weekly opening hours (0 = Sunday, Khartoum time); today is highlighted. */
function Hours({ hours, t }: { hours: Shop['openingHours']; t: Dictionary['shops'] }) {
  const today = WEEKDAYS.indexOf(
    new Intl.DateTimeFormat('en-US', { timeZone: 'Africa/Khartoum', weekday: 'short' }).format(
      new Date(),
    ),
  );
  return (
    <div>
      <h4 className="mb-2 text-xs font-semibold text-muted-foreground">{t.hours}</h4>
      <ul className="divide-y rounded-lg border text-sm">
        {t.weekdays.map((day, i) => {
          const windows = hours[String(i)] ?? [];
          return (
            <li
              key={day}
              className={cn(
                'flex justify-between px-3 py-1.5',
                i === today && 'bg-muted/60 font-semibold',
              )}
            >
              <span>{day}</span>
              <span
                dir="ltr"
                className={cn('tabular-nums', windows.length === 0 && 'text-muted-foreground')}
              >
                {windows.length
                  ? windows.map(([a, b]) => `${hhmm(a)}–${hhmm(b)}`).join(', ')
                  : t.closed}
              </span>
            </li>
          );
        })}
      </ul>
    </div>
  );
}
