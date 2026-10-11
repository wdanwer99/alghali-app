'use client';

import { Search } from 'lucide-react';
import { useId, useState } from 'react';
import type { Dictionary } from '@/i18n/dictionaries';
import type { OrderRow, OrderStatus } from '@/lib/demo/data';
import { digits, fill, formatRef, money, searchKey } from '@/lib/format';
import { orderTone, paymentTone } from '@/lib/tones';
import { Num, Panel, StatusBadge, Table, Td, Th } from './ui';

const statuses: OrderStatus[] = [
  'paymentReview',
  'pendingPayment',
  'confirmed',
  'ready',
  'handedToTechnician',
  'completed',
  'cancelled',
];

/** Dates arrive pre-formatted from the server so both render the same text. */
export function OrdersTable({
  orders,
  d,
  common,
  status,
}: {
  orders: (OrderRow & { placedText: string })[];
  d: Dictionary['orders'];
  common: Dictionary['common'];
  status: Dictionary['status'];
}) {
  const [query, setQuery] = useState('');
  const [filter, setFilter] = useState<OrderStatus | 'all'>('all');
  const searchId = useId();
  const filterId = useId();

  const q = searchKey(query);
  const qDigits = query.replace(/\D/g, '');
  const rows = orders.filter(
    (o) =>
      (filter === 'all' || o.status === filter) &&
      (!q || searchKey(o.buyer).includes(q) || (qDigits.length > 0 && o.ref.includes(qDigits))),
  );

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
            onChange={(e) => setFilter(e.target.value as OrderStatus | 'all')}
            className="h-10 min-w-44 rounded-lg border border-input bg-card px-3 text-sm outline-none focus-visible:border-ring focus-visible:ring-2 focus-visible:ring-ring/30"
          >
            <option value="all">{d.allStatuses}</option>
            {statuses.map((s) => (
              <option key={s} value={s}>
                {status.order[s]}
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
              <tr key={o.ref} className="hover:bg-muted/40">
                <Td>
                  <Num className="font-semibold">{formatRef(o.ref)}</Num>
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
                      {o.method === 'bankak' ? common.bankak : common.cash}
                    </span>
                    <StatusBadge tone={paymentTone[o.payment]}>
                      {status.payment[o.payment]}
                    </StatusBadge>
                  </div>
                </Td>
                <Td>
                  <StatusBadge tone={orderTone[o.status]}>{status.order[o.status]}</StatusBadge>
                </Td>
              </tr>
            ))}
          </tbody>
        </Table>
      )}
    </Panel>
  );
}
