import { MapPin, Wrench } from 'lucide-react';
import {
  SampleBanner,
  Num,
  PageHeader,
  Panel,
  StatusBadge,
  Table,
  Td,
  Th,
} from '@/components/admin/ui';
import type { Locale } from '@/i18n/config';
import { getDictionary, getLocale, type Dictionary } from '@/i18n/dictionaries';
import { bookings, tr, type BookingRow, type BookingStatus } from '@/lib/demo/data';
import { dateTime, formatRef } from '@/lib/format';
import { bookingTone } from '@/lib/tones';

const finished: BookingStatus[] = ['completed', 'cancelledByBuyer'];
const COLUMNS = 8;

export default async function BookingsPage() {
  const [d, locale] = await Promise.all([getDictionary(), getLocale()]);
  const byTime = [...bookings].sort((a, b) => a.startAt.getTime() - b.startAt.getTime());
  const upcoming = byTime.filter((b) => !finished.includes(b.status));
  const earlier = byTime.filter((b) => finished.includes(b.status)).reverse();
  return (
    <>
      <PageHeader title={d.bookings.title} description={d.bookings.subtitle} />
      <SampleBanner title={d.sample.title} body={d.sample.bookings} />
      {/* One table with two groups, so the columns line up. */}
      <Panel>
        <Table>
          <thead>
            <tr>
              <Th>{d.common.reference}</Th>
              <Th>{d.bookings.time}</Th>
              <Th>{d.common.technician}</Th>
              <Th>{d.common.buyer}</Th>
              <Th>{d.bookings.job}</Th>
              <Th>{d.bookings.place}</Th>
              <Th>{d.common.payment}</Th>
              <Th>{d.common.status}</Th>
            </tr>
          </thead>
          <Group title={d.bookings.upcoming} rows={upcoming} d={d} locale={locale} />
          <Group title={d.bookings.earlier} rows={earlier} d={d} locale={locale} />
        </Table>
      </Panel>
    </>
  );
}

function Group({
  title,
  rows,
  d,
  locale,
}: {
  title: string;
  rows: BookingRow[];
  d: Dictionary;
  locale: Locale;
}) {
  return (
    <tbody>
      <tr>
        <th
          colSpan={COLUMNS}
          scope="colgroup"
          className="border-b bg-muted/50 px-4 py-2 text-start text-xs font-semibold text-muted-foreground"
        >
          {title} · {rows.length}
        </th>
      </tr>
      {rows.length === 0 && (
        <tr>
          <Td colSpan={COLUMNS} className="text-center text-muted-foreground">
            {d.common.noResults}
          </Td>
        </tr>
      )}
      {rows.map((b) => (
        <tr key={b.ref} className="hover:bg-muted/40">
          <Td>
            <Num className="font-semibold">{formatRef(b.ref)}</Num>
          </Td>
          <Td className="whitespace-nowrap">{dateTime(b.startAt, locale)}</Td>
          <Td className="whitespace-nowrap">{tr(b.technician, locale)}</Td>
          <Td>
            <bdi>{b.buyer}</bdi>
          </Td>
          <Td className="min-w-40">{tr(b.job, locale)}</Td>
          <Td>
            <span className="inline-flex items-center gap-1.5 whitespace-nowrap">
              {b.place === 'bay' ? (
                <Wrench className="size-4 text-muted-foreground" aria-hidden />
              ) : (
                <MapPin className="size-4 text-muted-foreground" aria-hidden />
              )}
              {b.place === 'bay' ? d.bookings.placeBay : d.bookings.placeCustomer}
            </span>
          </Td>
          <Td className="whitespace-nowrap text-muted-foreground">
            {b.method === 'bankak' ? d.common.bankak : d.common.cash}
          </Td>
          <Td>
            <StatusBadge tone={bookingTone[b.status]}>{d.status.booking[b.status]}</StatusBadge>
          </Td>
        </tr>
      ))}
    </tbody>
  );
}
