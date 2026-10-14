'use client';

import { CalendarClock, MapPin, Search, Wrench } from 'lucide-react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { useId, useState } from 'react';
import type { Locale } from '@/i18n/config';
import type { Dictionary } from '@/i18n/dictionaries';
import type { BookingRow, BookingStatus } from '@/lib/data/installation';
import { named } from '@/lib/data/util';
import { digits, fill, formatRef, money, searchKey } from '@/lib/format';
import { bookingTone, statusKey } from '@/lib/tones';
import { EmptyState, Num, Panel, StatusBadge, Table, Td, Th } from './ui';

/** Still to happen (or waiting on someone); the rest is history. */
const ACTIVE: BookingStatus[] = [
  'NEEDS_RESCHEDULE',
  'AWAITING_PAYMENT',
  'PENDING_TECH_ACCEPT',
  'IN_PROGRESS',
  'EN_ROUTE',
  'ACCEPTED',
  'HELD',
];

const ALL: BookingStatus[] = [
  ...ACTIVE.filter((s) => s !== 'HELD'),
  'COMPLETED',
  'PART_DOES_NOT_FIT',
  'CANCELLED_BY_BUYER',
  'CANCELLED_BY_ADMIN',
  'EXPIRED',
];
const COLUMNS = 8;

/** Upcoming first (soonest at the top), then the rest, newest first. Times arrive pre-formatted. */
export function BookingsTable({
  bookings,
  locale,
  d,
  common,
  status,
}: {
  bookings: (BookingRow & { startText: string })[];
  locale: Locale;
  d: Dictionary['bookings'];
  common: Dictionary['common'];
  status: Dictionary['status'];
}) {
  const [query, setQuery] = useState('');
  const [filter, setFilter] = useState<BookingStatus | 'all'>('all');
  const searchId = useId();
  const filterId = useId();
  const router = useRouter();

  if (bookings.length === 0) {
    return (
      <Panel>
        <EmptyState icon={<CalendarClock />} title={d.empty} body={d.emptyBody} />
      </Panel>
    );
  }

  const q = searchKey(query);
  const qDigits = query.replace(/\D/g, '');
  const rows = bookings.filter(
    (b) =>
      (filter === 'all' || b.status === filter) &&
      (!q ||
        searchKey(b.buyer).includes(q) ||
        searchKey(b.technician).includes(q) ||
        (qDigits.length > 0 && b.ref.includes(qDigits))),
  );
  const upcoming = rows
    .filter((b) => ACTIVE.includes(b.status))
    .sort((a, b) => a.startAt.localeCompare(b.startAt));
  const earlier = rows.filter((b) => !ACTIVE.includes(b.status));
  const href = (b: BookingRow) => `/${locale}/bookings/${b.id}`;

  const group = (title: string, list: typeof rows) => (
    <tbody>
      <tr>
        <th
          colSpan={COLUMNS}
          scope="colgroup"
          className="border-b bg-muted/50 px-4 py-2 text-start text-xs font-semibold text-muted-foreground"
        >
          {title} · {digits(list.length)}
        </th>
      </tr>
      {list.length === 0 && (
        <tr>
          <Td colSpan={COLUMNS} className="text-center text-muted-foreground">
            {common.noResults}
          </Td>
        </tr>
      )}
      {list.map((b) => (
        <tr
          key={b.id}
          onClick={() => router.push(href(b))}
          className="group cursor-pointer hover:bg-muted/40"
        >
          <Td>
            <Link
              href={href(b)}
              onClick={(e) => e.stopPropagation()}
              className="font-semibold tabular-nums underline-offset-2 group-hover:underline focus-visible:underline focus-visible:outline-none"
            >
              {formatRef(b.ref)}
            </Link>
          </Td>
          <Td className="whitespace-nowrap">{b.startText}</Td>
          <Td className="whitespace-nowrap">
            <bdi>{b.technician}</bdi>
          </Td>
          <Td>
            <bdi>{b.buyer}</bdi>
          </Td>
          <Td className="min-w-40">{named(b.job, locale)}</Td>
          <Td>
            <span className="inline-flex items-center gap-1.5 whitespace-nowrap">
              {b.place === 'BAY' ? (
                <Wrench className="size-4 text-muted-foreground" aria-hidden />
              ) : (
                <MapPin className="size-4 text-muted-foreground" aria-hidden />
              )}
              {b.place === 'BAY' ? d.placeBay : d.placeCustomer}
            </span>
          </Td>
          <Td className="whitespace-nowrap">
            <Num>{money(b.totalSdg, common.currency)}</Num>
            <div className="text-xs text-muted-foreground">
              {b.method === 'BANKAK' ? common.bankak : b.method === 'CASH' ? common.cash : ''}
            </div>
          </Td>
          <Td>
            <StatusBadge tone={bookingTone[b.status]}>
              {status.booking[statusKey(b.status)]}
            </StatusBadge>
          </Td>
        </tr>
      ))}
    </tbody>
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
            onChange={(e) => setFilter(e.target.value as BookingStatus | 'all')}
            className="h-10 min-w-44 rounded-lg border border-input bg-card px-3 text-sm outline-none focus-visible:border-ring focus-visible:ring-2 focus-visible:ring-ring/30"
          >
            <option value="all">{d.allStatuses}</option>
            {ALL.map((s) => (
              <option key={s} value={s}>
                {status.booking[statusKey(s)]}
              </option>
            ))}
          </select>
        </div>
        <p className="pb-2.5 text-sm text-muted-foreground" aria-live="polite">
          {fill(d.showing, { n: digits(rows.length) })}
        </p>
      </div>
      {/* One table with two groups, so the columns line up. */}
      <Table>
        <thead>
          <tr>
            <Th>{common.reference}</Th>
            <Th>{d.time}</Th>
            <Th>{common.technician}</Th>
            <Th>{common.buyer}</Th>
            <Th>{d.job}</Th>
            <Th>{d.place}</Th>
            <Th>{common.payment}</Th>
            <Th>{common.status}</Th>
          </tr>
        </thead>
        {group(d.upcoming, upcoming)}
        {group(d.earlier, earlier)}
      </Table>
    </Panel>
  );
}
