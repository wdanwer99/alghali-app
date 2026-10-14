// Turns booking_context() (what the database knows) into what the buyer app shows: each
// technician with their price, score and free starts, and the "any available" list
// (PLAN §5). Pure, so the tests run it on hand-made contexts.
import {
  anyAvailable,
  rank,
  scores,
  slots,
  type Candidate,
  type JobPlace,
  type Rule,
  type SlotSettings,
  type WorkMode,
} from './engine.ts';

export interface ContextTechnician {
  id: string;
  name: string;
  avatar_key: string | null;
  verified: boolean;
  rating_avg: number;
  rating_count: number;
  completed_jobs: number;
  years_experience: number;
  bio_ar: string | null;
  bio_en: string | null;
  work_mode: WorkMode;
  radius_km: number;
  distance_km: number | null;
  bay: unknown;
  labour_sdg: number;
  rules: { weekday: number; start_min: number; end_min: number; modes: WorkMode }[];
  time_off: [string, string][];
  busy: [string, string][];
}

export interface BookingContext {
  now: string;
  duration_min: number;
  travel_fee_sdg: number;
  booking_fee_sdg: number;
  mobile_deposit_sdg: number;
  job_type_ids: string[];
  items: unknown[];
  settings: {
    grid_min: number;
    tz_offset_min: number;
    horizon_days: number;
    travel_buffer_min: number;
    part_ready_buffer_min: number;
  };
  technicians: ContextTechnician[];
}

export interface TechnicianOption {
  id: string;
  name: string;
  avatar_key: string | null;
  verified: boolean;
  rating_avg: number;
  rating_count: number;
  completed_jobs: number;
  years_experience: number;
  bio_ar: string | null;
  bio_en: string | null;
  work_mode: WorkMode;
  distance_km: number | null;
  bay: unknown;
  labour_sdg: number;
  score: number;
  next_slot: string | null;
  slot_count: number;
  /** Every free start, only when one technician was asked for. */
  slots?: string[];
}

export interface BookingOptions {
  duration_min: number;
  travel_fee_sdg: number;
  booking_fee_sdg: number;
  mobile_deposit_sdg: number;
  items: unknown[];
  /** Cheapest and dearest labour among technicians with a free slot ("any available" shows a range, D-010). */
  labour_range: [number, number] | null;
  technicians: TechnicianOption[];
  /** "Any available": each start with the best technician who has it. */
  any: { start: string; technician_id: string }[];
}

const iso = (t: number) => new Date(t).toISOString();
const ms = (s: string) => Date.parse(s);

export function bookingOptions(
  ctx: BookingContext,
  place: 'BAY' | 'CUSTOMER_LOCATION',
  technicianId?: string,
): BookingOptions {
  const jobPlace: JobPlace = place === 'BAY' ? 'BAY' : 'MOBILE';
  const settings: SlotSettings = {
    gridMin: ctx.settings.grid_min,
    tzOffsetMin: ctx.settings.tz_offset_min,
    travelBufferMin: ctx.settings.travel_buffer_min,
    partReadyBufferMin: ctx.settings.part_ready_buffer_min,
  };
  const now = ms(ctx.now);
  const free = new Map<string, number[]>();
  for (const t of ctx.technicians) {
    const rules: Rule[] = t.rules.map((r) => ({
      weekday: r.weekday,
      startMin: r.start_min,
      endMin: r.end_min,
      modes: r.modes,
    }));
    free.set(
      t.id,
      slots(
        {
          rules,
          timeOff: t.time_off.map(([from, to]) => ({ from: ms(from), to: ms(to) })),
          busy: t.busy.map(([from, to]) => ({ from: ms(from), to: ms(to) })),
        },
        {
          durationMin: ctx.duration_min,
          place: jobPlace,
          now,
          horizonDays: ctx.settings.horizon_days,
        },
        settings,
      ),
    );
  }

  const candidates: Candidate[] = ctx.technicians.map((t) => ({
    id: t.id,
    rating: Number(t.rating_avg),
    completedJobs: t.completed_jobs,
    distanceKm: place === 'BAY' ? null : t.distance_km,
    radiusKm: t.radius_km,
  }));
  const ranked = rank(candidates).filter((c) => (free.get(c.id) ?? []).length > 0);
  const byId = new Map(ctx.technicians.map((t) => [t.id, t]));
  const scored = scores(candidates);

  const technicians: TechnicianOption[] = ranked.map((c) => {
    const t = byId.get(c.id) as ContextTechnician;
    const starts = free.get(c.id) ?? [];
    return {
      id: t.id,
      name: t.name,
      avatar_key: t.avatar_key,
      verified: t.verified,
      rating_avg: Number(t.rating_avg),
      rating_count: t.rating_count,
      completed_jobs: t.completed_jobs,
      years_experience: t.years_experience,
      bio_ar: t.bio_ar,
      bio_en: t.bio_en,
      work_mode: t.work_mode,
      distance_km: t.distance_km,
      bay: t.bay,
      labour_sdg: t.labour_sdg,
      score: Math.round((scored.get(c.id) ?? 0) * 1000) / 1000,
      next_slot: starts.length > 0 ? iso(starts[0] as number) : null,
      slot_count: starts.length,
      ...(technicianId ? { slots: starts.map(iso) } : {}),
    };
  });
  const prices = technicians.map((t) => t.labour_sdg);
  return {
    duration_min: ctx.duration_min,
    travel_fee_sdg: ctx.travel_fee_sdg,
    booking_fee_sdg: ctx.booking_fee_sdg,
    mobile_deposit_sdg: ctx.mobile_deposit_sdg,
    items: ctx.items,
    labour_range: prices.length > 0 ? [Math.min(...prices), Math.max(...prices)] : null,
    technicians,
    any: technicianId
      ? []
      : anyAvailable(ranked, free).map((a) => ({
          start: iso(a.start),
          technician_id: a.technicianId,
        })),
  };
}
