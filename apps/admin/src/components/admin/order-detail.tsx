'use client';

import { ArrowLeft, ArrowRight, Ban, CheckCheck, MapPin, Phone, Store, Undo2 } from 'lucide-react';
import Link from 'next/link';
import { useState } from 'react';
import { Button } from '@/components/ui/button';
import type { Locale } from '@/i18n/config';
import type { Dictionary } from '@/i18n/dictionaries';
import { cancelSubOrder, completeSubOrder, decideReturn } from '@/lib/actions/commerce';
import type { OrderDetail as Order, SubStatus } from '@/lib/data/commerce';
import { named } from '@/lib/data/util';
import { dateTime, fill, formatRef, ltr, money } from '@/lib/format';
import { orderTone, paymentTone, statusKey } from '@/lib/tones';
import { ConfirmDialog } from './interactive';
import { phoneText } from './shop-facts';
import { useAction } from './use-action';
import { Num, Panel, StatusBadge, Table, Td, Th } from './ui';

type Labels = {
  orders: Dictionary['orders'];
  common: Dictionary['common'];
  errors: Dictionary['errors'];
  status: Dictionary['status'];
};

/** Where an admin may still cancel a shop's part (the transition table allows ADMIN from these). */
const CANCELLABLE: SubStatus[] = [
  'PENDING_PAYMENT',
  'PAYMENT_REVIEW',
  'CONFIRMED',
  'READY',
  'OUT_FOR_DELIVERY',
];
const COMPLETABLE: SubStatus[] = ['PICKED_UP', 'DELIVERED', 'HANDED_TO_TECHNICIAN'];

type Pending =
  { kind: 'cancel'; subId: string; shop: string } | { kind: 'decline'; subId: string } | null;

export function OrderDetail({ order, locale, t }: { order: Order; locale: Locale; t: Labels }) {
  const d = t.orders;
  const [confirm, setConfirm] = useState<Pending>(null);
  const { pending, run } = useAction(t.errors);
  const sdg = (n: number) => money(n, t.common.currency);
  const Back = locale === 'ar' ? ArrowRight : ArrowLeft;

  return (
    <div className="flex flex-col gap-6">
      <div className="flex flex-wrap items-start justify-between gap-4">
        <div>
          <Link
            href={`/${locale}/orders`}
            className="inline-flex items-center gap-1.5 text-sm text-muted-foreground hover:text-foreground"
          >
            <Back className="size-4" aria-hidden />
            {d.back}
          </Link>
          <h1 className="mt-2 text-2xl font-bold tabular-nums">{formatRef(order.ref)}</h1>
          <p className="mt-1 text-sm text-muted-foreground">
            {dateTime(new Date(order.placedAt), locale)} ·{' '}
            {order.method === 'BANKAK' ? t.common.bankak : t.common.cash} · {sdg(order.totalSdg)}
          </p>
        </div>
        {order.buyer && (
          <div className="rounded-xl bg-card px-4 py-3 text-sm ring-1 ring-foreground/10">
            <div className="text-xs text-muted-foreground">{t.common.buyer}</div>
            <div className="font-semibold">
              <bdi>{order.buyer.name}</bdi>
            </div>
            {order.buyer.phone && (
              <a
                href={`tel:${order.buyer.phone}`}
                className="mt-1 inline-flex items-center gap-1.5 hover:underline"
              >
                <Phone className="size-3.5" aria-hidden />
                {phoneText(order.buyer.phone)}
              </a>
            )}
          </div>
        )}
      </div>

      <div className="grid grid-cols-1 items-start gap-6 lg:grid-cols-[minmax(0,1fr)_20rem]">
        <div className="flex flex-col gap-6">
          {order.subOrders.map((s) => (
            <Panel
              key={s.id}
              title={named(s.shop, locale)}
              actions={
                <StatusBadge tone={orderTone[s.status]}>
                  {t.status.order[statusKey(s.status)]}
                </StatusBadge>
              }
            >
              <div className="flex flex-col gap-4 p-4">
                <div className="flex flex-wrap gap-x-5 gap-y-1 text-sm text-muted-foreground">
                  <span className="inline-flex items-center gap-1.5">
                    <Store className="size-4" aria-hidden />
                    {d.fulfilment[s.fulfilment]}
                  </span>
                  {s.shop.phone && <span>{phoneText(s.shop.phone)}</span>}
                  <span>{s.acceptedAt ? d.accepted : d.notAccepted}</span>
                </div>

                <Table>
                  <thead>
                    <tr>
                      <Th>{d.parts}</Th>
                      <Th className="text-end">{d.qty}</Th>
                      <Th className="text-end">{d.unitPrice}</Th>
                    </tr>
                  </thead>
                  <tbody>
                    {s.items.map((i) => (
                      <tr key={i.id}>
                        <Td className="whitespace-normal">
                          <div className="font-medium">{named(i.title, locale)}</div>
                          <div className="text-xs text-muted-foreground">
                            {d.conditions[i.condition as keyof typeof d.conditions] ?? i.condition}
                            {i.brand && ` · ${i.brand}`}
                          </div>
                        </Td>
                        <Td className="text-end">
                          <Num>{i.qty}</Num>
                        </Td>
                        <Td className="text-end">
                          <Num>{sdg(i.unitPriceSdg)}</Num>
                        </Td>
                      </tr>
                    ))}
                  </tbody>
                </Table>

                <dl className="grid grid-cols-3 gap-2 text-center text-sm">
                  <Mini label={d.parts} value={sdg(s.itemsSdg)} />
                  <Mini label={d.delivery} value={sdg(s.deliveryFeeSdg)} />
                  <Mini label={d.commission} value={sdg(s.commissionSdg)} />
                </dl>

                {s.cancelReason && (
                  <p className="rounded-lg bg-muted px-3 py-2 text-sm">
                    <span className="font-semibold">{d.reasonGiven}: </span>
                    {s.cancelReason}
                  </p>
                )}

                {s.return && (
                  <div className="flex flex-col gap-3 rounded-lg border border-warning/40 bg-warning-soft/40 p-3">
                    <p className="text-sm">
                      <span className="font-semibold">
                        {s.status === 'RETURN_REQUESTED'
                          ? d.returnRequested
                          : fill(d.returnDecided, {
                              status:
                                d.returnStatus[s.return.status as keyof typeof d.returnStatus],
                            })}
                        :{' '}
                      </span>
                      {s.return.reason}
                    </p>
                    {s.return.note && (
                      <p className="text-sm text-muted-foreground">{s.return.note}</p>
                    )}
                    {s.status === 'RETURN_REQUESTED' && (
                      <div className="flex flex-wrap gap-2">
                        <Button
                          className="h-9 px-3"
                          disabled={pending}
                          onClick={() =>
                            run(() => decideReturn(s.id, true), { success: d.returnApprovedToast })
                          }
                        >
                          <Undo2 />
                          {d.returnApprove}
                        </Button>
                        <Button
                          variant="outline"
                          className="h-9 px-3"
                          disabled={pending}
                          onClick={() => setConfirm({ kind: 'decline', subId: s.id })}
                        >
                          {d.returnDecline}
                        </Button>
                      </div>
                    )}
                  </div>
                )}

                <div>
                  <h3 className="mb-2 text-xs font-semibold text-muted-foreground">{d.timeline}</h3>
                  <ol className="flex flex-col gap-2 border-s ps-4">
                    {s.events.map((e, i) => (
                      <li key={i} className="relative text-sm">
                        <span
                          className="absolute -start-[1.3rem] top-1.5 size-2 rounded-full bg-foreground/40"
                          aria-hidden
                        />
                        <span className="font-medium">{t.status.order[statusKey(e.to)]}</span>
                        <span className="text-muted-foreground">
                          {' '}
                          · {d.actors[e.actor as keyof typeof d.actors] ?? e.actor}
                          {e.by && ` (${e.by})`} · {dateTime(new Date(e.at), locale)}
                        </span>
                        {e.reason && (
                          <div className="text-xs text-muted-foreground">{e.reason}</div>
                        )}
                      </li>
                    ))}
                  </ol>
                </div>

                {(CANCELLABLE.includes(s.status) || COMPLETABLE.includes(s.status)) && (
                  <div className="flex flex-wrap gap-2 border-t pt-4">
                    {COMPLETABLE.includes(s.status) && (
                      <Button
                        variant="outline"
                        className="h-9 px-3"
                        disabled={pending}
                        onClick={() =>
                          run(() => completeSubOrder(s.id), { success: d.completedToast })
                        }
                      >
                        <CheckCheck />
                        {d.complete}
                      </Button>
                    )}
                    {CANCELLABLE.includes(s.status) && (
                      <Button
                        variant="outline"
                        className="h-9 px-3"
                        disabled={pending}
                        onClick={() =>
                          setConfirm({ kind: 'cancel', subId: s.id, shop: named(s.shop, locale) })
                        }
                      >
                        <Ban />
                        {d.cancelSub}
                      </Button>
                    )}
                  </div>
                )}
              </div>
            </Panel>
          ))}
        </div>

        <div className="flex flex-col gap-6">
          <Panel title={d.payments}>
            <ul className="divide-y">
              {order.payments.map((p) => (
                <li key={p.id} className="flex flex-col gap-1 px-4 py-3 text-sm">
                  <div className="flex items-center justify-between gap-2">
                    <span>{p.method === 'BANKAK' ? t.common.bankak : t.common.cash}</span>
                    <Num className="font-semibold">{sdg(p.amountSdg)}</Num>
                  </div>
                  <div className="flex flex-wrap items-center gap-2">
                    <StatusBadge tone={paymentTone[p.status]}>
                      {t.status.payment[statusKey(p.status)]}
                    </StatusBadge>
                    {p.txn && <span className="text-xs text-muted-foreground">{ltr(p.txn)}</span>}
                  </div>
                  {p.rejectReason && (
                    <div className="text-xs text-muted-foreground">{p.rejectReason}</div>
                  )}
                </li>
              ))}
            </ul>
          </Panel>

          {order.refunds.length > 0 && (
            <Panel title={d.refunds}>
              <ul className="divide-y">
                {order.refunds.map((r) => (
                  <li
                    key={r.id}
                    className="flex items-center justify-between gap-2 px-4 py-3 text-sm"
                  >
                    <span className="text-muted-foreground">
                      {r.status === 'PAID' && r.txn
                        ? fill(d.refundSent, { txn: ltr(r.txn) })
                        : d.refundPending}
                    </span>
                    <Num className="font-semibold">{sdg(r.amountSdg)}</Num>
                  </li>
                ))}
              </ul>
            </Panel>
          )}

          {order.address && (
            <Panel title={d.deliverTo}>
              <div className="flex items-start gap-2 p-4 text-sm">
                <MapPin className="mt-0.5 size-4 shrink-0 text-muted-foreground" aria-hidden />
                <div>
                  <div className="font-medium">{order.address.label}</div>
                  {order.address.description_ar && (
                    <div className="text-muted-foreground">{order.address.description_ar}</div>
                  )}
                  {order.address.lat !== undefined && (
                    <a
                      className="text-xs underline-offset-2 hover:underline"
                      href={`https://maps.google.com/?q=${order.address.lat},${order.address.lng}`}
                      target="_blank"
                      rel="noreferrer"
                    >
                      {ltr(`${order.address.lat?.toFixed(5)}, ${order.address.lng?.toFixed(5)}`)}
                    </a>
                  )}
                </div>
              </div>
            </Panel>
          )}
        </div>
      </div>

      <ConfirmDialog
        open={confirm !== null}
        onOpenChange={(o) => !o && setConfirm(null)}
        title={
          confirm?.kind === 'cancel' ? fill(d.cancelTitle, { shop: confirm.shop }) : d.declineTitle
        }
        description={confirm?.kind === 'cancel' ? d.cancelBody : undefined}
        reasonLabel={t.common.notes}
        confirmLabel={confirm?.kind === 'cancel' ? d.cancelSub : d.returnDecline}
        cancelLabel={t.common.cancel}
        tone="danger"
        pending={pending}
        onConfirm={(reason) => {
          const c = confirm;
          setConfirm(null);
          if (!c) return;
          if (c.kind === 'cancel')
            run(() => cancelSubOrder(c.subId, reason), { success: d.cancelledToast });
          else run(() => decideReturn(c.subId, false, reason), { success: d.returnDeclinedToast });
        }}
      />
    </div>
  );
}

function Mini({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-lg bg-muted/70 px-2 py-2.5">
      <dd className="text-sm font-bold tabular-nums">{value}</dd>
      <dt className="truncate text-xs text-muted-foreground">{label}</dt>
    </div>
  );
}
