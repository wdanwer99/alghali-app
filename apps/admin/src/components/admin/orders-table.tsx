'use client';

import { ReceiptText, Search } from 'lucide-react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { useId, useState } from 'react';
import type { Locale } from '@/i18n/config';
import type { Dictionary } from '@/i18n/dictionaries';
import type { OrderRow, SubStatus } from '@/lib/data/commerce';
import { digits, fill, formatRef, money, searchKey } from '@/lib/format';
import { orderTone, paymentTone, statusKey } from '@/lib/tones';
import { EmptyState, Num, Panel, StatusBadge, Table, Td, Th } from './ui';

const statuses: SubStatus[] = [
  'PAYMENT_REVIEW',
  'PENDING_PAYMENT',
  'RETURN_REQUESTED',
  'CONFIRMED',
  'READY',
  'OUT_FOR_DELIVERY',
  'PICKED_UP',
  'DELIVERED',
  'HANDED_TO_TECHNICIAN',
  'COMPLETED',
  'REJECTED_BY_SHOP',
  'RETURNED',
  'CANCELLED',
];

/** Dates arrive pre-formatted from the server so both render the same text. */
export function OrdersTable({
  orders,
  locale,
  d,
  common,
  status,
}: {
  orders: (OrderRow & { placedText: string })[];
  locale: Locale;
  d: Dictionary['orders'];
  common: Dictionary['common'];
  status: Dictionary['status'];
}) {
  const [query, setQuery] = useState('');
  const [filter, setFilter] = useState<SubStatus | 'all'>('all');
  const searchId = useId();
  const filterId = useId();
  const router = useRouter();

  const q = searchKey(query);
  const qDigits = query.replace(/\D/g, '');
  const rows = orders.filter(
    (o) =>
      (filter === 'all' || o.status === filter) &&
      (!q || searchKey(o.buyer).includes(q) || (qDigits.length > 0 && o.ref.includes(qDigits))),
  );
  const href = (o: OrderRow) => `/${locale}/orders/${o.id}`;

  if (orders.length === 0) {
    return (
      <Panel>
        <EmptyState icon={<ReceiptText />} title={d.empty} body={d.emptyBody} />
      </Panel>
    );
  }

  return (
    <Panel>
      <div className="flex flex-wrap items-end gap-3 border-b p-4">
        <div className="flex min-w-56 flex-1 flex-col gap-1.5">
          <label htmlFor={searchId} className="text-xs font-medium text-muted-foreground">
            {common.search}
          </label>
          <div className="relative">
            <Search
              className="pointer-events-none absolute start-3 top-1/2 size-4 -translate-y-1/2 text-muted-foreground"
              aria-hidden
            />
            <input
              id={searchId}
              type="search"
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              placeholder={d.searchPlaceholder}
              className="h-10 w-full rounded-lg border border-input bg-card ps-9 pe-3 text-sm outline-none placeholder:text-muted-foreground focus-visible:border-ring focus-visible:ring-2 focus-visible:ring-ring/30"
            />
          </div>
        </div>
        <div className="flex flex-col gap-1.5">
          <label htmlFor={filterId} className="text-xs font-medium text-muted-foreground">
            {common.status}
          </label>
          <select
            id={filterId}
            value={filter}
            onChange={(e) => setFilter(e.target.value as SubStatus | 'all')}
            className="h-10 min-w-44 rounded-lg border border-input bg-card px-3 text-sm outline-none focus-visible:border-ring focus-visible:ring-2 focus-visible:ring-ring/30"
          >
            <option value="all">{d.allStatuses}</option>
            {statuses.map((s) => (
              <option key={s} value={s}>
                {status.order[statusKey(s)]}
              </option>
            ))}
          </select>
        </div>
        <p className="pb-2.5 text-sm text-muted-foreground" aria-live="polite">
          {fill(d.showing, { n: digits(rows.length) })}
        </p>
      </div>

      {rows.length === 0 ? (
        <p className="px-4 py-12 text-center text-sm text-muted-foreground">{common.noResults}</p>
      ) : (
        <Table>
          <thead>
            <tr>
              <Th>{common.reference}</Th>
              <Th>{d.placed}</Th>
              <Th>{common.buyer}</Th>
              <Th className="text-end">{d.shops}</Th>
              <Th className="text-end">{d.items}</Th>
              <Th className="text-end">{common.total}</Th>
              <Th>{common.payment}</Th>
              <Th>{common.status}</Th>
            </tr>
          </thead>
          <tbody>
            {rows.map((o) => (
              <tr
                key={o.id}
                onClick={() => router.push(href(o))}
                className="group cursor-pointer hover:bg-muted/40"
              >
                <Td>
                  <Link
                    href={href(o)}
                    onClick={(e) => e.stopPropagation()}
                    className="font-semibold tabular-nums underline-offset-2 group-hover:underline focus-visible:underline focus-visible:outline-none"
                  >
                    {formatRef(o.ref)}
                  </Link>
                </Td>
                <Td className="whitespace-nowrap text-muted-foreground">{o.placedText}</Td>
                <Td>
                  <bdi>{o.buyer}</bdi>
                </Td>
                <Td className="text-end">
                  <Num>{o.shops}</Num>
                </Td>
                <Td className="text-end">
                  <Num>{o.items}</Num>
                </Td>
                <Td className="text-end">
                  <Num className="font-medium">{money(o.totalSdg, common.currency)}</Num>
                </Td>
                <Td>
                  <div className="flex items-center gap-2 whitespace-nowrap">
                    <span className="text-muted-foreground">
                      {o.method === 'BANKAK' ? common.bankak : common.cash}
                    </span>
                    {o.payment && (
                      <StatusBadge tone={paymentTone[o.payment]}>
                        {status.payment[statusKey(o.payment)]}
                      </StatusBadge>
                    )}
                  </div>
                </Td>
                <Td>
                  <StatusBadge tone={orderTone[o.status]}>
                    {status.order[statusKey(o.status)]}
                  </StatusBadge>
                </Td>
              </tr>
            ))}
          </tbody>
        </Table>
      )}
    </Panel>
  );
}
