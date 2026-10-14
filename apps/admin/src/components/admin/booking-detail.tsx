'use client';

import {
  ArrowLeft,
  ArrowRight,
  Ban,
  CheckCheck,
  MapPin,
  Phone,
  Repeat,
  Wrench,
} from 'lucide-react';
import Link from 'next/link';
import { useState } from 'react';
import { Button } from '@/components/ui/button';
import type { Locale } from '@/i18n/config';
import type { Dictionary } from '@/i18n/dictionaries';
import { cancelBooking, completeBooking, reassignBooking } from '@/lib/actions/installation';
import type { BookingDetail as Booking, BookingStatus } from '@/lib/data/installation';
import { named } from '@/lib/data/util';
import { dateTime, fill, formatRef, ltr, money } from '@/lib/format';
import { bookingTone, paymentTone, statusKey } from '@/lib/tones';
import { ConfirmDialog } from './interactive';
import { phoneText } from './shop-facts';
import { useAction } from './use-action';
import { Num, Panel, StatusBadge } from './ui';

type Labels = {
  bookings: Dictionary['bookings'];
  common: Dictionary['common'];
  errors: Dictionary['errors'];
  status: Dictionary['status'];
};

/** Where the transition table lets an admin act (PLAN §3.10). */
const CANCELLABLE: BookingStatus[] = [
  'AWAITING_PAYMENT',
  'PENDING_TECH_ACCEPT',
  'ACCEPTED',
  'EN_ROUTE',
  'IN_PROGRESS',
  'NEEDS_RESCHEDULE',
];
const REASSIGNABLE: BookingStatus[] = ['PENDING_TECH_ACCEPT', 'ACCEPTED'];

export function BookingDetail({
  booking,
  locale,
  t,
}: {
  booking: Booking;
  locale: Locale;
  t: Labels;
}) {
  const d = t.bookings;
  const [confirm, setConfirm] = useState<'cancel' | 'reassign' | null>(null);
  const { pending, run } = useAction(t.errors);
  const sdg = (n: number) => money(n, t.common.currency);
  const Back = locale === 'ar' ? ArrowRight : ArrowLeft;
  const b = booking;

  return (
    <div className="flex flex-col gap-6">
      <div className="flex flex-wrap items-start justify-between gap-4">
        <div>
          <Link
            href={`/${locale}/bookings`}
            className="inline-flex items-center gap-1.5 text-sm text-muted-foreground hover:text-foreground"
          >
            <Back className="size-4" aria-hidden />
            {d.back}
          </Link>
          <h1 className="mt-2 flex flex-wrap items-center gap-3 text-2xl font-bold tabular-nums">
            {formatRef(b.ref)}
            <StatusBadge tone={bookingTone[b.status]}>
              {t.status.booking[statusKey(b.status)]}
            </StatusBadge>
          </h1>
          <p className="mt-1 text-sm text-muted-foreground">
            {dateTime(new Date(b.startAt), locale)} · {fill(d.minutes, { n: b.durationMin })} ·{' '}
            {b.place === 'BAY' ? d.placeBay : d.placeCustomer}
            {b.orderId && b.orderRef && (
              <>
                {' · '}
                <Link
                  href={`/${locale}/orders/${b.orderId}`}
                  className="underline-offset-2 hover:underline"
                >
                  {fill(d.order, { ref: formatRef(b.orderRef) })}
                </Link>
              </>
            )}
          </p>
        </div>
        <div className="flex flex-wrap gap-3">
          <Person label={t.common.technician} name={b.technician.name} phone={b.technician.phone} />
          {b.buyer && <Person label={t.common.buyer} name={b.buyer.name} phone={b.buyer.phone} />}
        </div>
      </div>

      {b.codeLocked && b.status === 'IN_PROGRESS' && (
        <p className="rounded-lg border border-warning/40 bg-warning-soft/40 px-4 py-3 text-sm">
          {d.codeLocked}
        </p>
      )}

      <div className="grid grid-cols-1 items-start gap-6 lg:grid-cols-[minmax(0,1fr)_20rem]">
        <div className="flex flex-col gap-6">
          <Panel title={d.items}>
            <ul className="divide-y">
              {b.items.map((i, n) => (
                <li key={n} className="flex items-center justify-between gap-3 px-4 py-3 text-sm">
                  <div>
                    <div className="font-medium">{named(i.title, locale)}</div>
                    {i.description && (
                      <div className="text-xs text-muted-foreground">{i.description}</div>
                    )}
                  </div>
                  <span className="text-muted-foreground">{fill(d.minutes, { n: i.minutes })}</span>
                </li>
              ))}
            </ul>
          </Panel>

          <Panel title={d.timeline}>
            <ol className="flex flex-col gap-2 border-s p-4 ps-8">
              {b.events.map((e, i) => (
                <li key={i} className="relative text-sm">
                  <span
                    className="absolute -start-[1.3rem] top-1.5 size-2 rounded-full bg-foreground/40"
                    aria-hidden
                  />
                  <span className="font-medium">{t.status.booking[statusKey(e.to)]}</span>
                  <span className="text-muted-foreground">
                    {' '}
                    · {d.actors[e.actor as keyof typeof d.actors] ?? e.actor}
                    {e.by && ` (${e.by})`} · {dateTime(new Date(e.at), locale)}
                  </span>
                  {e.reason && <div className="text-xs text-muted-foreground">{e.reason}</div>}
                </li>
              ))}
            </ol>
          </Panel>

          {b.offers.length > 0 && (
            <Panel title={d.offers}>
              <ul className="divide-y">
                {b.offers.map((o, i) => (
                  <li
                    key={i}
                    className="flex flex-wrap items-center justify-between gap-2 px-4 py-3 text-sm"
                  >
                    <span>
                      <bdi className="font-medium">{o.technician}</bdi>
                      <span className="text-muted-foreground">
                        {' '}
                        · {dateTime(new Date(o.offeredAt), locale)}
                      </span>
                      {o.reason && (
                        <span className="block text-xs text-muted-foreground">{o.reason}</span>
                      )}
                    </span>
                    <StatusBadge
                      tone={
                        o.status === 'ACCEPTED'
                          ? 'success'
                          : o.status === 'OFFERED'
                            ? 'warning'
                            : 'neutral'
                      }
                    >
                      {d.offerStatus[o.status as keyof typeof d.offerStatus] ?? o.status}
                    </StatusBadge>
                  </li>
                ))}
              </ul>
            </Panel>
          )}

          {b.photos.length > 0 && (
            <Panel title={d.photos}>
              <div className="grid grid-cols-2 gap-3 p-4 sm:grid-cols-3">
                {b.photos.map((p, i) =>
                  p.url ? (
                    <a
                      key={i}
                      href={p.url}
                      target="_blank"
                      rel="noreferrer"
                      className="flex flex-col gap-1"
                    >
                      {/* eslint-disable-next-line @next/next/no-img-element -- short-lived signed link */}
                      <img
                        src={p.url}
                        alt=""
                        className="aspect-square w-full rounded-lg object-cover ring-1 ring-foreground/10"
                      />
                      <span className="text-xs text-muted-foreground">
                        {p.kind === 'BEFORE' ? d.before : d.after}
                      </span>
                    </a>
                  ) : null,
                )}
              </div>
            </Panel>
          )}

          {(CANCELLABLE.includes(b.status) || b.status === 'IN_PROGRESS') && (
            <div className="flex flex-wrap gap-2">
              {b.status === 'IN_PROGRESS' && (
                <Button
                  className="h-10 px-4"
                  disabled={pending}
                  onClick={() => run(() => completeBooking(b.id), { success: d.completedToast })}
                >
                  <CheckCheck />
                  {d.complete}
                </Button>
              )}
              {REASSIGNABLE.includes(b.status) && (
                <Button
                  variant="outline"
                  className="h-10 px-4"
                  disabled={pending}
                  onClick={() => setConfirm('reassign')}
                >
                  <Repeat />
                  {d.reassign}
                </Button>
              )}
              {CANCELLABLE.includes(b.status) && (
                <Button
                  variant="outline"
                  className="h-10 px-4"
                  disabled={pending}
                  onClick={() => setConfirm('cancel')}
                >
                  <Ban />
                  {d.cancel}
                </Button>
              )}
            </div>
          )}
        </div>

        <div className="flex flex-col gap-6">
          <Panel title={d.fees}>
            <dl className="divide-y text-sm">
              <Row label={d.labour} value={sdg(b.labourSdg)} />
              {b.travelFeeSdg > 0 && <Row label={d.travel} value={sdg(b.travelFeeSdg)} />}
              <Row label={d.bookingFee} value={sdg(b.bookingFeeSdg)} />
              {b.depositSdg > 0 && <Row label={d.deposit} value={sdg(b.depositSdg)} />}
            </dl>
            <p className="border-t px-4 py-2 text-xs text-muted-foreground">
              {b.assignment === 'ANY' ? d.any : d.chosen}
            </p>
          </Panel>

          {b.payments.length > 0 && (
            <Panel title={d.payments}>
              <ul className="divide-y">
                {b.payments.map((p) => (
                  <li key={p.id} className="flex flex-col gap-1 px-4 py-3 text-sm">
                    <div className="flex items-center justify-between gap-2">
                      <span>
                        {p.method === 'BANKAK' ? t.common.bankak : t.common.cash}
                        {p.purpose === 'BOOKING_DEPOSIT' && ` · ${d.deposit_purpose}`}
                      </span>
                      <Num className="font-semibold">{sdg(p.amountSdg)}</Num>
                    </div>
                    <StatusBadge tone={paymentTone[p.status]} className="self-start">
                      {t.status.payment[statusKey(p.status)]}
                    </StatusBadge>
                  </li>
                ))}
              </ul>
            </Panel>
          )}

          <Panel title={d.where}>
            <div className="flex items-start gap-2 p-4 text-sm">
              {b.place === 'BAY' ? (
                <>
                  <Wrench className="mt-0.5 size-4 shrink-0 text-muted-foreground" aria-hidden />
                  <span className="font-medium">{b.bay ? named(b.bay, locale) : d.placeBay}</span>
                </>
              ) : (
                <>
                  <MapPin className="mt-0.5 size-4 shrink-0 text-muted-foreground" aria-hidden />
                  <div>
                    <div className="font-medium">{b.address?.label}</div>
                    {b.address?.description_ar && (
                      <div className="text-muted-foreground">{b.address.description_ar}</div>
                    )}
                    {b.locationNote && (
                      <div className="text-muted-foreground">{b.locationNote}</div>
                    )}
                    {b.address?.lat !== undefined && (
                      <a
                        className="text-xs underline-offset-2 hover:underline"
                        href={`https://maps.google.com/?q=${b.address.lat},${b.address.lng}`}
                        target="_blank"
                        rel="noreferrer"
                      >
                        {ltr(`${b.address.lat?.toFixed(5)}, ${b.address.lng?.toFixed(5)}`)}
                      </a>
                    )}
                  </div>
                </>
              )}
            </div>
          </Panel>

          {b.cancelReason && (
            <p className="rounded-lg bg-muted px-3 py-2 text-sm">
              <span className="font-semibold">{d.reasonGiven}: </span>
              {b.cancelReason}
            </p>
          )}
        </div>
      </div>

      <ConfirmDialog
        open={confirm !== null}
        onOpenChange={(o) => !o && setConfirm(null)}
        title={confirm === 'cancel' ? fill(d.cancelTitle, { ref: formatRef(b.ref) }) : d.reassign}
        description={confirm === 'cancel' ? d.cancelBody : undefined}
        reasonLabel={t.common.notes}
        confirmLabel={confirm === 'cancel' ? d.cancel : d.reassign}
        cancelLabel={t.common.cancel}
        tone={confirm === 'cancel' ? 'danger' : undefined}
        pending={pending}
        onConfirm={(reason) => {
          const c = confirm;
          setConfirm(null);
          if (c === 'cancel') run(() => cancelBooking(b.id, reason), { success: d.cancelledToast });
          else if (c === 'reassign')
            run(() => reassignBooking(b.id, reason), { success: d.reassignedToast });
        }}
      />
    </div>
  );
}

function Person({ label, name, phone }: { label: string; name: string; phone: string | null }) {
  return (
    <div className="rounded-xl bg-card px-4 py-3 text-sm ring-1 ring-foreground/10">
      <div className="text-xs text-muted-foreground">{label}</div>
      <div className="font-semibold">
        <bdi>{name}</bdi>
      </div>
      {phone && (
        <a href={`tel:${phone}`} className="mt-1 inline-flex items-center gap-1.5 hover:underline">
          <Phone className="size-3.5" aria-hidden />
          {phoneText(phone)}
        </a>
      )}
    </div>
  );
}

function Row({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex items-center justify-between gap-2 px-4 py-2.5">
      <dt className="text-muted-foreground">{label}</dt>
      <dd className="font-semibold tabular-nums">{value}</dd>
    </div>
  );
}
