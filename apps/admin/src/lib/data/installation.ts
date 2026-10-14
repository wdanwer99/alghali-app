import 'server-only';
import type { Database } from '@alghali/db-types';
import type { Supabase } from '@/lib/supabase/server';
import type { Method, PayStatus } from './commerce';
import { must, type Named } from './util';

export type BookingStatus = Database['public']['Enums']['booking_status'];
export type BookingPlace = Database['public']['Enums']['booking_place'];
export type WorkMode = Database['public']['Enums']['work_mode'];

const named = (ar: string | null | undefined, en: string | null | undefined): Named => ({
  ar: ar ?? '',
  en: en || ar || '',
});

/** Names and phones by user id (profiles have no FK to embed through). */
async function people(supabase: Supabase, ids: string[]) {
  const unique = [...new Set(ids.filter(Boolean))];
  if (!unique.length)
    return new Map<string, { name: string; phone: string | null; email: string }>();
  const rows = await supabase
    .from('profiles')
    .select('id, display_name, email, phone')
    .in('id', unique)
    .then(must);
  return new Map(
    rows.map((p) => [
      p.id,
      { name: p.display_name || p.email || '', phone: p.phone, email: p.email ?? '' },
    ]),
  );
}

/** Technicians' names, by technician id. */
async function technicianNames(supabase: Supabase, ids: string[]) {
  const unique = [...new Set(ids.filter(Boolean))];
  if (!unique.length)
    return new Map<string, { name: string; phone: string | null; userId: string }>();
  const techs = await supabase
    .from('technicians')
    .select('id, user_id')
    .in('id', unique)
    .then(must);
  const names = await people(
    supabase,
    techs.map((t) => t.user_id),
  );
  return new Map(
    techs.map((t) => [
      t.id,
      {
        name: names.get(t.user_id)?.name ?? '',
        phone: names.get(t.user_id)?.phone ?? null,
        userId: t.user_id,
      },
    ]),
  );
}

// -------------------------------------------------------------------- bookings

export type BookingRow = {
  id: string;
  ref: string;
  startAt: string;
  status: BookingStatus;
  place: BookingPlace;
  method: Method | null;
  technician: string;
  buyer: string;
  job: Named;
  totalSdg: number;
};

export async function listBookings(supabase: Supabase, limit = 300): Promise<BookingRow[]> {
  const rows = await supabase
    .from('bookings')
    .select(
      `id, ref, start_at, status, place, payment_method, technician_id, buyer_id, labour_sdg, travel_fee_sdg,
       booking_fee_sdg, booking_items(title_ar, title_en)`,
    )
    .not('order_id', 'is', null)
    .order('start_at', { ascending: false })
    .limit(limit)
    .then(must);
  const [techs, buyers] = await Promise.all([
    technicianNames(
      supabase,
      rows.map((r) => r.technician_id),
    ),
    people(
      supabase,
      rows.map((r) => r.buyer_id),
    ),
  ]);
  return rows.map((b) => {
    const first = b.booking_items[0];
    const more = b.booking_items.length - 1;
    const title = named(first?.title_ar, first?.title_en);
    return {
      id: b.id,
      ref: b.ref,
      startAt: b.start_at,
      status: b.status,
      place: b.place,
      method: b.payment_method,
      technician: techs.get(b.technician_id)?.name ?? '',
      buyer: buyers.get(b.buyer_id)?.name ?? '',
      job: more > 0 ? { ar: `${title.ar} +${more}`, en: `${title.en} +${more}` } : title,
      totalSdg: Number(b.labour_sdg) + Number(b.travel_fee_sdg) + Number(b.booking_fee_sdg),
    };
  });
}

export type BookingEvent = {
  from: BookingStatus | null;
  to: BookingStatus;
  actor: string;
  by: string | null;
  reason: string | null;
  at: string;
};

export type BookingDetail = {
  id: string;
  ref: string;
  orderId: string | null;
  orderRef: string | null;
  status: BookingStatus;
  place: BookingPlace;
  method: Method | null;
  startAt: string;
  endAt: string;
  durationMin: number;
  labourSdg: number;
  travelFeeSdg: number;
  bookingFeeSdg: number;
  depositSdg: number;
  assignment: 'CHOSEN' | 'ANY';
  cancelReason: string | null;
  codeLocked: boolean;
  address: { label?: string; description_ar?: string | null; lat?: number; lng?: number } | null;
  locationNote: string | null;
  bay: Named | null;
  technician: { id: string; name: string; phone: string | null };
  buyer: { name: string; phone: string | null; email: string } | null;
  items: { title: Named; minutes: number; description: string | null }[];
  events: BookingEvent[];
  offers: { technician: string; status: string; offeredAt: string; reason: string | null }[];
  photos: { kind: 'BEFORE' | 'AFTER'; url: string | null; takenAt: string }[];
  payments: { id: string; method: Method; purpose: string; status: PayStatus; amountSdg: number }[];
};

export async function loadBooking(supabase: Supabase, id: string): Promise<BookingDetail | null> {
  const b = await supabase
    .from('bookings')
    .select(
      `id, ref, order_id, status, place, payment_method, start_at, end_at, duration_min, labour_sdg, travel_fee_sdg,
       booking_fee_sdg, deposit_sdg, assignment_mode, cancel_reason, address_snapshot, location_note,
       technician_id, buyer_id, bay:shops(name_ar, name_en), order:orders(ref),
       booking_codes(locked_at),
       booking_items(title_ar, title_en, minutes, description),
       booking_events(id, from_status, to_status, actor_kind, actor_id, reason, at),
       booking_offers(technician_id, status, offered_at, reason),
       booking_photos(kind, image_key, taken_at)`,
    )
    .eq('id', id)
    .maybeSingle()
    .then(must);
  if (!b) return null;
  const payments = b.order_id
    ? await supabase
        .from('payments')
        .select('id, method, purpose, status, amount_sdg, booking_id')
        .eq('order_id', b.order_id)
        .then(must)
    : [];
  const techIds = [b.technician_id, ...b.booking_offers.map((o) => o.technician_id)];
  const actorIds = b.booking_events.flatMap((e) => (e.actor_id ? [e.actor_id] : []));
  const [techs, names] = await Promise.all([
    technicianNames(supabase, techIds),
    people(supabase, [b.buyer_id, ...actorIds]),
  ]);
  const keys = b.booking_photos.map((p) => p.image_key);
  const urls = new Map<string, string>();
  if (keys.length) {
    const { data } = await supabase.storage.from('booking-photos').createSignedUrls(keys, 15 * 60);
    for (const s of data ?? []) if (s.path && s.signedUrl) urls.set(s.path, s.signedUrl);
  }
  const tech = techs.get(b.technician_id);
  const code = Array.isArray(b.booking_codes) ? b.booking_codes[0] : b.booking_codes;
  return {
    id: b.id,
    ref: b.ref,
    orderId: b.order_id,
    orderRef: b.order?.ref ?? null,
    status: b.status,
    place: b.place,
    method: b.payment_method,
    startAt: b.start_at,
    endAt: b.end_at,
    durationMin: b.duration_min,
    labourSdg: Number(b.labour_sdg),
    travelFeeSdg: Number(b.travel_fee_sdg),
    bookingFeeSdg: Number(b.booking_fee_sdg),
    depositSdg: Number(b.deposit_sdg),
    assignment: b.assignment_mode as 'CHOSEN' | 'ANY',
    cancelReason: b.cancel_reason,
    codeLocked: Boolean(code?.locked_at),
    address: (b.address_snapshot ?? null) as BookingDetail['address'],
    locationNote: b.location_note,
    bay: b.bay ? named(b.bay.name_ar, b.bay.name_en) : null,
    technician: { id: b.technician_id, name: tech?.name ?? '', phone: tech?.phone ?? null },
    buyer: names.get(b.buyer_id) ?? null,
    items: b.booking_items.map((i) => ({
      title: named(i.title_ar, i.title_en),
      minutes: i.minutes,
      description: i.description,
    })),
    events: [...b.booking_events]
      .sort((x, y) => x.at.localeCompare(y.at) || x.id - y.id)
      .map((e) => ({
        from: e.from_status,
        to: e.to_status,
        actor: e.actor_kind,
        by: e.actor_id ? (names.get(e.actor_id)?.name ?? null) : null,
        reason: e.reason,
        at: e.at,
      })),
    offers: [...b.booking_offers]
      .sort((x, y) => x.offered_at.localeCompare(y.offered_at))
      .map((o) => ({
        technician: techs.get(o.technician_id)?.name ?? '',
        status: o.status,
        offeredAt: o.offered_at,
        reason: o.reason,
      })),
    photos: b.booking_photos.map((p) => ({
      kind: p.kind as 'BEFORE' | 'AFTER',
      url: urls.get(p.image_key) ?? null,
      takenAt: p.taken_at,
    })),
    payments: payments
      .filter((p) => p.method === 'BANKAK' || p.booking_id === b.id)
      .map((p) => ({
        id: p.id,
        method: p.method,
        purpose: p.purpose,
        status: p.status,
        amountSdg: Number(p.amount_sdg),
      })),
  };
}

// ----------------------------------------------------------------- technicians

export type TechnicianApplication = {
  id: string;
  name: string;
  phone: string | null;
  email: string;
  mode: WorkMode;
  years: number;
  radiusKm: number;
  bio: string | null;
  bay: Named | null;
  jobs: { name: Named; labourSdg: number }[];
  makes: Named[];
  rulesCount: number;
  appliedAt: string;
};

export async function listTechnicianApplications(
  supabase: Supabase,
): Promise<TechnicianApplication[]> {
  const rows = await supabase
    .from('technicians')
    .select(
      `id, user_id, work_mode, years_experience, radius_km, bio_ar, created_at,
       bay:shops!technicians_home_bay_shop_id_fkey(name_ar, name_en),
       technician_job_types(labour_sdg, job_types(name_ar, name_en, sort)),
       technician_makes(vehicle_makes(name_ar, name_en)),
       availability_rules(id)`,
    )
    .eq('status', 'PENDING')
    .order('created_at')
    .then(must);
  const names = await people(
    supabase,
    rows.map((r) => r.user_id),
  );
  return rows.map((t) => ({
    id: t.id,
    name: names.get(t.user_id)?.name ?? '',
    phone: names.get(t.user_id)?.phone ?? null,
    email: names.get(t.user_id)?.email ?? '',
    mode: t.work_mode,
    years: t.years_experience,
    radiusKm: t.radius_km,
    bio: t.bio_ar,
    bay: t.bay ? named(t.bay.name_ar, t.bay.name_en) : null,
    jobs: [...t.technician_job_types]
      .sort((a, b) => (a.job_types?.sort ?? 0) - (b.job_types?.sort ?? 0))
      .map((j) => ({
        name: named(j.job_types?.name_ar, j.job_types?.name_en),
        labourSdg: Number(j.labour_sdg),
      })),
    makes: t.technician_makes.map((m) => named(m.vehicle_makes?.name_ar, m.vehicle_makes?.name_en)),
    rulesCount: t.availability_rules.length,
    appliedAt: t.created_at,
  }));
}

// -------------------------------------------------------------------- disputes

export type DisputeStatus = 'OPEN' | 'IN_REVIEW' | 'RESOLVED' | 'REJECTED';
export type DisputeCategory =
  'NOT_RECEIVED' | 'WRONG_PART' | 'DAMAGED' | 'NOT_FITTED' | 'PAYMENT' | 'BEHAVIOUR' | 'OTHER';

export type Dispute = {
  id: string;
  category: DisputeCategory;
  description: string;
  status: DisputeStatus;
  openerRole: 'BUYER' | 'SHOP' | 'TECH';
  openedBy: string;
  ref: string | null;
  orderId: string | null;
  bookingId: string | null;
  resolution: string | null;
  createdAt: string;
  updatedAt: string;
  messages: { id: string; body: string; fromAdmin: boolean; sender: string; at: string }[];
};

export async function listDisputes(supabase: Supabase, limit = 200): Promise<Dispute[]> {
  const rows = await supabase
    .from('disputes')
    .select(
      `id, category, description, status, opener_role, opened_by, resolution, created_at, updated_at, booking_id,
       sub_order:sub_orders(order_id, order:orders(ref)), booking:bookings(ref),
       dispute_messages(id, body, from_admin, sender_id, created_at)`,
    )
    .order('created_at', { ascending: false })
    .limit(limit)
    .then(must);
  const names = await people(supabase, [
    ...rows.map((r) => r.opened_by),
    ...rows.flatMap((r) => r.dispute_messages.map((m) => m.sender_id)),
  ]);
  return rows.map((d) => ({
    id: d.id,
    category: d.category as DisputeCategory,
    description: d.description,
    status: d.status as DisputeStatus,
    openerRole: d.opener_role as Dispute['openerRole'],
    openedBy: names.get(d.opened_by)?.name ?? '',
    ref: d.sub_order?.order?.ref ?? d.booking?.ref ?? null,
    orderId: d.sub_order?.order_id ?? null,
    bookingId: d.booking_id,
    resolution: d.resolution,
    createdAt: d.created_at,
    updatedAt: d.updated_at,
    messages: [...d.dispute_messages]
      .sort((a, b) => a.created_at.localeCompare(b.created_at))
      .map((m) => ({
        id: m.id,
        body: m.body,
        fromAdmin: m.from_admin,
        sender: names.get(m.sender_id)?.name ?? '',
        at: m.created_at,
      })),
  }));
}

// -------------------------------------------------------------------- overview

export type InstallationCounts = {
  technicianApplications: number;
  needsAttention: number;
  openDisputes: number;
  fittingsToday: number;
};

export async function loadInstallationCounts(supabase: Supabase): Promise<InstallationCounts> {
  const now = new Date();
  const local = new Date(now.getTime() + 2 * 3_600_000);
  const midnight = new Date(
    Date.UTC(local.getUTCFullYear(), local.getUTCMonth(), local.getUTCDate()) - 2 * 3_600_000,
  );
  const tomorrow = new Date(midnight.getTime() + 86_400_000);
  const count = async (q: PromiseLike<{ count: number | null }>) => (await q).count ?? 0;
  const [apps, attention, disputes, today] = await Promise.all([
    count(
      supabase
        .from('technicians')
        .select('id', { count: 'exact', head: true })
        .eq('status', 'PENDING'),
    ),
    count(
      supabase
        .from('bookings')
        .select('id', { count: 'exact', head: true })
        .in('status', ['NEEDS_RESCHEDULE', 'PENDING_TECH_ACCEPT']),
    ),
    count(
      supabase
        .from('disputes')
        .select('id', { count: 'exact', head: true })
        .in('status', ['OPEN', 'IN_REVIEW']),
    ),
    count(
      supabase
        .from('bookings')
        .select('id', { count: 'exact', head: true })
        .gte('start_at', midnight.toISOString())
        .lt('start_at', tomorrow.toISOString())
        .in('status', ['ACCEPTED', 'EN_ROUTE', 'IN_PROGRESS', 'COMPLETED']),
    ),
  ]);
  return {
    technicianApplications: apps,
    needsAttention: attention,
    openDisputes: disputes,
    fittingsToday: today,
  };
}
