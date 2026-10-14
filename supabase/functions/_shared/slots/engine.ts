// The slot engine (PLAN §5): which start times a technician can take for a job, and how
// "any available technician" picks one. Pure functions with no runtime APIs, so the
// Edge Function and the tests share them. Times are epoch milliseconds (UTC); weekly
// rules are wall-clock minutes in Khartoum time (UTC+2, no daylight saving).

export type WorkMode = 'BAY' | 'MOBILE' | 'BOTH';
export type JobPlace = 'BAY' | 'MOBILE';

/** One weekly window: weekday 0 = Sunday, minutes after midnight, [start, end). */
export interface Rule {
  weekday: number;
  startMin: number;
  endMin: number;
  modes: WorkMode;
}

/** A half-open time range [from, to) in epoch ms. */
export interface Interval {
  from: number;
  to: number;
}

export interface TechCalendar {
  rules: Rule[];
  timeOff: Interval[];
  /** Blocks already taken: other bookings' `block_from..block_to` (travel buffer included). */
  busy: Interval[];
}

export interface SlotRequest {
  durationMin: number;
  place: JobPlace;
  now: number;
  /** When the part should be at the shop counter; defaults to now. */
  readyAt?: number;
  horizonDays: number;
}

export interface SlotSettings {
  gridMin: number;
  travelBufferMin: number;
  partReadyBufferMin: number;
  /** Khartoum is UTC+2. */
  tzOffsetMin: number;
}

export const DEFAULT_SETTINGS: SlotSettings = {
  gridMin: 30,
  travelBufferMin: 30,
  partReadyBufferMin: 120,
  tzOffsetMin: 120,
};

const MIN = 60_000;
const DAY = 1440 * MIN;

const overlaps = (a: Interval, b: Interval) => a.from < b.to && b.from < a.to;

/** Rounds up to the next multiple of `step` minutes. */
export function roundUp(t: number, stepMin: number): number {
  const step = stepMin * MIN;
  return Math.ceil(t / step) * step;
}

/** The earliest start: now (or when the part is ready) + the ready buffer, on a 15-minute mark (D-027). */
export function earliestStart(req: SlotRequest, s: SlotSettings): number {
  return roundUp(Math.max(req.now, req.readyAt ?? req.now) + s.partReadyBufferMin * MIN, 15);
}

/** Local midnight (as epoch ms) of the Khartoum day containing `t`. */
export function localMidnight(t: number, s: SlotSettings): number {
  const offset = s.tzOffsetMin * MIN;
  return Math.floor((t + offset) / DAY) * DAY - offset;
}

/** Weekday (0 = Sunday) of the Khartoum day starting at local midnight `midnight`. */
export function localWeekday(midnight: number, s: SlotSettings): number {
  return new Date(midnight + s.tzOffsetMin * MIN).getUTCDay();
}

/** The block a job occupies: the job itself, padded by the travel buffer for mobile jobs (D-025). */
export function blockOf(
  start: number,
  durationMin: number,
  place: JobPlace,
  s: SlotSettings,
): Interval {
  const pad = place === 'MOBILE' ? s.travelBufferMin * MIN : 0;
  return { from: start - pad, to: start + durationMin * MIN + pad };
}

const ruleFits = (r: Rule, place: JobPlace) => r.modes === 'BOTH' || r.modes === place;

/**
 * Start times (epoch ms, ascending) on the grid where the job fits inside one of the
 * technician's windows for that kind of job, clear of time off, with its block clear of
 * every busy block, no earlier than `earliestStart`.
 */
export function slots(
  cal: TechCalendar,
  req: SlotRequest,
  s: SlotSettings = DEFAULT_SETTINGS,
): number[] {
  if (req.durationMin <= 0 || req.horizonDays <= 0) return [];
  const earliest = earliestStart(req, s);
  const firstDay = localMidnight(req.now, s);
  const out: number[] = [];
  for (let d = 0; d < req.horizonDays; d++) {
    const midnight = firstDay + d * DAY;
    const weekday = localWeekday(midnight, s);
    const windows = cal.rules
      .filter((r) => r.weekday === weekday && ruleFits(r, req.place) && r.endMin > r.startMin)
      .sort((a, b) => a.startMin - b.startMin);
    const seen = new Set<number>();
    for (const w of windows) {
      const firstGrid = Math.ceil(w.startMin / s.gridMin) * s.gridMin;
      for (let m = firstGrid; m + req.durationMin <= w.endMin; m += s.gridMin) {
        const start = midnight + m * MIN;
        if (start < earliest || seen.has(start)) continue;
        const job: Interval = { from: start, to: start + req.durationMin * MIN };
        if (cal.timeOff.some((t) => overlaps(t, job))) continue;
        const block = blockOf(start, req.durationMin, req.place, s);
        if (cal.busy.some((b) => overlaps(b, block))) continue;
        seen.add(start);
        out.push(start);
      }
    }
  }
  return out.sort((a, b) => a - b);
}

// ------------------------------------------------------------------ ranking

export interface Candidate {
  id: string;
  rating: number;
  completedJobs: number;
  /** Straight-line km from the technician's base to the job; null for bay jobs. */
  distanceKm: number | null;
  radiusKm: number;
}

/**
 * PLAN §5: 0.5·rating + 0.3·experience + 0.2·closeness, each scaled to 0–1. Experience is
 * log(jobs + 1) relative to the most experienced candidate; closeness is 1 − distance/radius
 * (1 for bay jobs, where the buyer comes to the technician).
 */
export function scores(candidates: Candidate[]): Map<string, number> {
  const maxJobs = Math.max(0, ...candidates.map((c) => c.completedJobs));
  const out = new Map<string, number>();
  for (const c of candidates) {
    const rating = Math.min(Math.max(c.rating, 0), 5) / 5;
    const experience = maxJobs > 0 ? Math.log(c.completedJobs + 1) / Math.log(maxJobs + 1) : 0;
    const closeness =
      c.distanceKm === null || c.radiusKm <= 0 ? 1 : Math.max(0, 1 - c.distanceKm / c.radiusKm);
    out.set(c.id, 0.5 * rating + 0.3 * experience + 0.2 * closeness);
  }
  return out;
}

/** Candidates best first; ties go to more completed jobs, then the id (stable). */
export function rank(candidates: Candidate[]): Candidate[] {
  const s = scores(candidates);
  return [...candidates].sort(
    (a, b) =>
      (s.get(b.id) ?? 0) - (s.get(a.id) ?? 0) ||
      b.completedJobs - a.completedJobs ||
      a.id.localeCompare(b.id),
  );
}

/** "Any available": every start any technician has, each given to the best-ranked one that has it. */
export function anyAvailable(
  ranked: Candidate[],
  slotsByTech: Map<string, number[]>,
): { start: number; technicianId: string }[] {
  const owner = new Map<number, string>();
  for (const c of ranked) {
    for (const start of slotsByTech.get(c.id) ?? []) {
      if (!owner.has(start)) owner.set(start, c.id);
    }
  }
  return [...owner.entries()]
    .sort((a, b) => a[0] - b[0])
    .map(([start, technicianId]) => ({ start, technicianId }));
}
