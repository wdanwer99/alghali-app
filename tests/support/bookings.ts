import { must, type Tx } from './db.ts';
import { asSystem, asUser, categoryId, createShop, createUser } from './fixtures.ts';

export type Place = 'BAY' | 'CUSTOMER_LOCATION';
export type Item =
  | { listing_id: string }
  | { offer_id: string }
  | { order_item_id: string }
  | { part_id: string; description?: string }
  | { category_id: string; description: string };

export interface BookingJson {
  id: string;
  ref: string;
  status: string;
  technician_id: string;
  order_id: string | null;
  place: Place;
  start_at: string;
  end_at: string;
  block_from: string;
  block_to: string;
  duration_min: number;
  hold_expires_at: string | null;
  labour_sdg: number;
  travel_fee_sdg: number;
  booking_fee_sdg: number;
  deposit_sdg: number;
  job_code: string | null;
  items: {
    order_item_id: string | null;
    listing_id: string | null;
    job_type_id: string;
    minutes: number;
  }[];
  offer: { id: string; status: string; expires_at: string } | null;
}

/** Khartoum (UTC+2) wall-clock time `days` from today at `hour:minute`, as ISO UTC. */
export function khartoumAt(hour: number, days = 1, minute = 0): string {
  const k = new Date(Date.now() + 2 * 3_600_000);
  return new Date(
    Date.UTC(k.getUTCFullYear(), k.getUTCMonth(), k.getUTCDate() + days, hour, minute) -
      2 * 3_600_000,
  ).toISOString();
}

export const minutesAfter = (iso: string, min: number) =>
  new Date(Date.parse(iso) + min * 60_000).toISOString();

/** The street's starting point, which travel fees are measured from (D-026). */
export async function setStreetOrigin(tx: Tx, lat = 15.6, lng = 32.5): Promise<void> {
  await asSystem(tx);
  await tx`update public.streets set origin_lat = ${lat}, origin_lng = ${lng} where slug = 'alghali'`;
}

export async function addAddress(tx: Tx, userId: string, lat = 15.61, lng = 32.5): Promise<string> {
  await asSystem(tx);
  const [row] = await tx<{ id: string }[]>`
    insert into public.addresses (user_id, label, description_ar, lat, lng)
    values (${userId}, 'البيت', 'جوار المسجد', ${lat}, ${lng}) returning id`;
  return must(row).id;
}

export async function jobTypeId(tx: Tx, code: string): Promise<string> {
  const [row] = await tx<{ id: string }[]>`select id from public.job_types where code = ${code}`;
  return must(row, code).id;
}

export interface TechOpts {
  mode?: 'BAY' | 'MOBILE' | 'BOTH';
  /** Job type code → labour SDG. Default: LIGHTING 5000, BRAKES 6000. */
  jobs?: Record<string, number>;
  bayShopId?: string;
  home?: [number, number];
  radiusKm?: number;
  makes?: string[];
  rating?: number;
  completedJobs?: number;
  /** Weekly windows; default every day, all day. */
  rules?: { weekday: number; start_min: number; end_min: number; modes?: string }[];
  name?: string;
}

/** An approved technician, inserted directly (the application flow has its own tests). */
export async function createTechnician(
  tx: Tx,
  opts: TechOpts = {},
): Promise<{ userId: string; techId: string; bayShopId: string | null }> {
  const userId = await createUser(tx, {
    meta: { phone: '0911111111', display_name: opts.name ?? 'الفني عمر' },
  });
  const mode = opts.mode ?? 'BOTH';
  let bay = opts.bayShopId ?? null;
  if (mode !== 'MOBILE' && !bay) {
    bay = await createShop(tx, await createUser(tx), { name: 'ورشة الشارع' });
  }
  await asSystem(tx);
  const home = mode === 'BAY' ? null : (opts.home ?? [15.6, 32.5]);
  const [t] = await tx<{ id: string }[]>`
    insert into public.technicians (user_id, status, work_mode, home_bay_shop_id, home_lat, home_lng, radius_km,
                                    rating_avg, completed_jobs, approved_at)
    values (${userId}, 'APPROVED', ${mode}::public.work_mode, ${mode === 'MOBILE' ? null : bay},
            ${home?.[0] ?? null}, ${home?.[1] ?? null}, ${opts.radiusKm ?? 10}, ${opts.rating ?? 4.5},
            ${opts.completedJobs ?? 10}, now())
    returning id`;
  const techId = must(t).id;
  for (const [code, labour] of Object.entries(opts.jobs ?? { LIGHTING: 5000, BRAKES: 6000 })) {
    await tx`insert into public.technician_job_types (technician_id, job_type_id, labour_sdg)
             values (${techId}, ${await jobTypeId(tx, code)}, ${labour})`;
  }
  for (const slug of opts.makes ?? []) {
    await tx`insert into public.technician_makes (technician_id, make_id)
             select ${techId}, id from public.vehicle_makes where slug = ${slug}`;
  }
  const rules: NonNullable<TechOpts['rules']> =
    opts.rules ??
    [0, 1, 2, 3, 4, 5, 6].map((weekday) => ({ weekday, start_min: 0, end_min: 1440 }));
  for (const r of rules) {
    await tx`insert into public.availability_rules (technician_id, weekday, start_min, end_min, modes)
             values (${techId}, ${r.weekday}, ${r.start_min}, ${r.end_min}, ${r.modes ?? 'BOTH'}::public.work_mode)`;
  }
  await tx`insert into public.user_roles (user_id, role) values (${userId}, 'TECHNICIAN') on conflict do nothing`;
  await tx`select public.tech_account(${techId})`;
  return { userId, techId, bayShopId: mode === 'MOBILE' ? null : bay };
}

/** A part bought elsewhere, described by category (lighting: 30 minutes, LIGHTING). */
export async function elsewhere(tx: Tx, slug = 'lighting'): Promise<Item> {
  return { category_id: await categoryId(tx, slug), description: 'لمبات أمامية' };
}

export async function hold(
  tx: Tx,
  buyer: string,
  opts: {
    technicianId: string;
    start: string;
    items: Item[];
    place?: Place;
    addressId?: string;
    mode?: 'CHOSEN' | 'ANY';
  },
): Promise<BookingJson> {
  await asUser(tx, buyer);
  const [row] = await tx<{ b: BookingJson }[]>`
    select public.create_booking_hold(
      p_technician_id => ${opts.technicianId},
      p_start_at => ${opts.start},
      p_items => ${tx.json(opts.items as never)},
      p_place => ${opts.place ?? 'BAY'}::public.booking_place,
      p_address_id => ${opts.addressId ?? null},
      p_assignment_mode => ${opts.mode ?? 'CHOSEN'}) as b`;
  return must(row).b;
}

export async function bookingRow(tx: Tx, id: string): Promise<BookingJson> {
  await asSystem(tx);
  const [row] = await tx<{ b: BookingJson }[]>`select public.booking_json(${id}) as b`;
  return must(row).b;
}

/** The technician's open offer on the booking (id), as the system sees it. */
export async function openOffer(
  tx: Tx,
  bookingId: string,
): Promise<{ id: string; technician_id: string } | undefined> {
  await asSystem(tx);
  const [row] = await tx<{ id: string; technician_id: string }[]>`
    select id, technician_id from public.booking_offers where booking_id = ${bookingId} and status = 'OFFERED'`;
  return row;
}

export async function accept(tx: Tx, techUser: string, bookingId: string): Promise<void> {
  const offer = must(await openOffer(tx, bookingId), 'open offer');
  await asUser(tx, techUser);
  await tx`select public.tech_respond_offer(${offer.id}, true)`;
}

export async function jobCode(tx: Tx, bookingId: string): Promise<string> {
  await asSystem(tx);
  const [row] = await tx<
    { code: string }[]
  >`select code from public.booking_codes where booking_id = ${bookingId}`;
  return must(row).code;
}

export const techBalance = async (tx: Tx, techId: string) => {
  await asSystem(tx);
  const [row] = await tx<{ b: string }[]>`select public.tech_balance(${techId}) as b`;
  return Number(must(row).b);
};

/** Platform owes the shop (+) / shop owes (−), as in statements. */
export const shopOwed = async (tx: Tx, shopId: string) => {
  await asSystem(tx);
  const [row] = await tx<{ b: string }[]>`select public.shop_balance(${shopId}) as b`;
  return Number(must(row).b);
};

/** Money held for a booking's order and the booking (BUYER_FUNDS_HELD lines tied to either). */
export async function heldFor(tx: Tx, orderId: string): Promise<number> {
  await asSystem(tx);
  const [row] = await tx<{ b: string }[]>`
    select coalesce(sum(e.amount_sdg), 0) as b
    from public.ledger_entries e join public.ledger_journals j on j.id = e.journal_id
    join public.ledger_accounts a on a.id = e.account_id
    where a.code = 'BUYER_FUNDS_HELD' and j.order_id = ${orderId}`;
  return Number(must(row).b);
}
