import { describe, expect, it } from 'vitest';
import {
  anyAvailable,
  blockOf,
  DEFAULT_SETTINGS,
  earliestStart,
  localMidnight,
  localWeekday,
  rank,
  roundUp,
  scores,
  slots,
  type Rule,
  type SlotRequest,
  type TechCalendar,
} from '../../supabase/functions/_shared/slots/engine.ts';

const MIN = 60_000;
/** Khartoum wall-clock time (UTC+2) as epoch ms: k('2026-10-14 09:30'). */
const k = (s: string) => Date.parse(`${s.replace(' ', 'T')}:00+02:00`);
/** Back to Khartoum wall-clock text, for readable expectations. */
const show = (t: number) => new Date(t + 120 * MIN).toISOString().slice(0, 16).replace('T', ' ');

// Wednesday 14 Oct 2026, 09:30 in Khartoum (the admin demo's "now", D-055).
const NOW = k('2026-10-14 09:30');

const everyDay = (startMin: number, endMin: number, modes: Rule['modes'] = 'BOTH'): Rule[] =>
  [0, 1, 2, 3, 4, 5, 6].map((weekday) => ({ weekday, startMin, endMin, modes }));

const req = (over: Partial<SlotRequest> = {}): SlotRequest => ({
  durationMin: 60,
  place: 'BAY',
  now: NOW,
  horizonDays: 1,
  ...over,
});

const cal = (over: Partial<TechCalendar> = {}): TechCalendar => ({
  rules: everyDay(9 * 60, 13 * 60),
  timeOff: [],
  busy: [],
  ...over,
});

describe('time helpers', () => {
  it('works in Khartoum time whatever the UTC date is', () => {
    // 01:00 Thursday in Khartoum is still Wednesday 23:00 UTC.
    const t = k('2026-10-15 01:00');
    expect(new Date(t).getUTCDay()).toBe(3);
    const midnight = localMidnight(t, DEFAULT_SETTINGS);
    expect(show(midnight)).toBe('2026-10-15 00:00');
    expect(localWeekday(midnight, DEFAULT_SETTINGS)).toBe(4);
  });

  it('rounds up to the grid and leaves exact marks alone', () => {
    expect(show(roundUp(k('2026-10-14 11:31'), 15))).toBe('2026-10-14 11:45');
    expect(show(roundUp(k('2026-10-14 11:45'), 15))).toBe('2026-10-14 11:45');
  });

  it('the earliest start is now + the ready buffer, on a quarter hour (D-027)', () => {
    expect(show(earliestStart(req(), DEFAULT_SETTINGS))).toBe('2026-10-14 11:30');
    expect(show(earliestStart(req({ now: k('2026-10-14 09:31') }), DEFAULT_SETTINGS))).toBe(
      '2026-10-14 11:45',
    );
    // A part that won't be ready until later pushes everything back.
    expect(show(earliestStart(req({ readyAt: k('2026-10-14 15:10') }), DEFAULT_SETTINGS))).toBe(
      '2026-10-14 17:15',
    );
  });

  it('mobile jobs carry the travel buffer on both sides; bay jobs none (D-025)', () => {
    const s = k('2026-10-14 16:00');
    expect(blockOf(s, 60, 'MOBILE', DEFAULT_SETTINGS)).toEqual({
      from: s - 30 * MIN,
      to: s + 90 * MIN,
    });
    expect(blockOf(s, 60, 'BAY', DEFAULT_SETTINGS)).toEqual({ from: s, to: s + 60 * MIN });
  });
});

describe('slots', () => {
  it('cuts the window on a 30-minute grid after the earliest start', () => {
    expect(slots(cal(), req()).map(show)).toEqual(['2026-10-14 11:30', '2026-10-14 12:00']);
  });

  it('a job must end inside the window', () => {
    expect(slots(cal(), req({ durationMin: 90 })).map(show)).toEqual(['2026-10-14 11:30']);
    expect(slots(cal(), req({ durationMin: 120 }))).toEqual([]);
  });

  it('covers every day of the horizon, skipping days with no hours', () => {
    const rules: Rule[] = [
      { weekday: 3, startMin: 16 * 60, endMin: 17 * 60, modes: 'BOTH' }, // Wednesday
      { weekday: 5, startMin: 9 * 60, endMin: 10 * 60, modes: 'BOTH' }, // Friday
    ];
    // Seven days from Wednesday 14th end on Tuesday 20th, so the next Wednesday is out.
    expect(slots(cal({ rules }), req({ horizonDays: 7 })).map(show)).toEqual([
      '2026-10-14 16:00',
      '2026-10-16 09:00',
    ]);
  });

  it('the horizon counts calendar days from today', () => {
    const rules = everyDay(9 * 60, 10 * 60);
    const out = slots(cal({ rules }), req({ horizonDays: 3 })).map(show);
    expect(out).toEqual(['2026-10-15 09:00', '2026-10-16 09:00']);
  });

  it('only uses windows meant for this kind of job', () => {
    const rules: Rule[] = [
      { weekday: 3, startMin: 12 * 60, endMin: 13 * 60, modes: 'BAY' },
      { weekday: 3, startMin: 16 * 60, endMin: 17 * 60, modes: 'MOBILE' },
    ];
    expect(slots(cal({ rules }), req({ place: 'BAY' })).map(show)).toEqual(['2026-10-14 12:00']);
    expect(slots(cal({ rules }), req({ place: 'MOBILE' })).map(show)).toEqual(['2026-10-14 16:00']);
  });

  it('a window starting off the grid begins at the next grid mark', () => {
    const rules: Rule[] = [{ weekday: 3, startMin: 16 * 60 + 10, endMin: 18 * 60, modes: 'BOTH' }];
    expect(slots(cal({ rules }), req()).map(show)).toEqual([
      '2026-10-14 16:30',
      '2026-10-14 17:00',
    ]);
  });

  it('time off removes every start whose job would overlap it', () => {
    const rules = everyDay(16 * 60, 20 * 60);
    const timeOff = [{ from: k('2026-10-14 17:15'), to: k('2026-10-14 18:00') }];
    expect(slots(cal({ rules, timeOff }), req()).map(show)).toEqual([
      '2026-10-14 16:00',
      '2026-10-14 18:00',
      '2026-10-14 18:30',
      '2026-10-14 19:00',
    ]);
  });

  it('a bay job fits right up against another booking', () => {
    const rules = everyDay(16 * 60, 19 * 60);
    const busy = [{ from: k('2026-10-14 17:00'), to: k('2026-10-14 18:00') }];
    expect(slots(cal({ rules, busy }), req()).map(show)).toEqual([
      '2026-10-14 16:00',
      '2026-10-14 18:00',
    ]);
  });

  it('a mobile job keeps the travel buffer clear of other bookings', () => {
    const rules = everyDay(16 * 60, 21 * 60);
    const busy = [{ from: k('2026-10-14 17:30'), to: k('2026-10-14 18:30') }];
    expect(slots(cal({ rules, busy }), req({ place: 'MOBILE' })).map(show)).toEqual([
      '2026-10-14 16:00',
      '2026-10-14 19:00',
      '2026-10-14 19:30',
      '2026-10-14 20:00',
    ]);
  });

  it('overlapping windows do not list a start twice', () => {
    const rules: Rule[] = [
      { weekday: 3, startMin: 16 * 60, endMin: 18 * 60, modes: 'BAY' },
      { weekday: 3, startMin: 17 * 60, endMin: 19 * 60, modes: 'BOTH' },
    ];
    expect(slots(cal({ rules }), req()).map(show)).toEqual([
      '2026-10-14 16:00',
      '2026-10-14 16:30',
      '2026-10-14 17:00',
      '2026-10-14 17:30',
      '2026-10-14 18:00',
    ]);
  });

  it('nothing for an empty request or a technician without hours', () => {
    expect(slots(cal(), req({ durationMin: 0 }))).toEqual([]);
    expect(slots(cal(), req({ horizonDays: 0 }))).toEqual([]);
    expect(slots(cal({ rules: [] }), req({ horizonDays: 7 }))).toEqual([]);
  });

  it('late in the evening, the next slots are tomorrow', () => {
    const rules = everyDay(9 * 60, 21 * 60);
    const out = slots(cal({ rules }), req({ now: k('2026-10-14 20:00'), horizonDays: 2 })).map(
      show,
    );
    expect(out[0]).toBe('2026-10-15 09:00');
  });

  it('starts are always on the local grid, never between marks', () => {
    const rules = everyDay(8 * 60, 22 * 60);
    for (const t of slots(cal({ rules }), req({ now: k('2026-10-14 07:07'), horizonDays: 7 }))) {
      expect(((t + 120 * MIN) / MIN) % 30).toBe(0);
    }
  });
});

describe('ranking', () => {
  const a = { id: 'a', rating: 4.9, completedJobs: 120, distanceKm: 2, radiusKm: 10 };
  const b = { id: 'b', rating: 4.2, completedJobs: 10, distanceKm: 1, radiusKm: 10 };
  const c = { id: 'c', rating: 4.9, completedJobs: 120, distanceKm: 9, radiusKm: 10 };

  it('follows 0.5·rating + 0.3·experience + 0.2·closeness', () => {
    const s = scores([a, b]);
    expect(s.get('a')).toBeCloseTo(0.5 * 0.98 + 0.3 * 1 + 0.2 * 0.8, 6);
    expect(s.get('b')).toBeCloseTo(
      0.5 * 0.84 + 0.3 * (Math.log(11) / Math.log(121)) + 0.2 * 0.9,
      6,
    );
  });

  it('puts the better, closer technician first', () => {
    expect(rank([b, c, a]).map((x) => x.id)).toEqual(['a', 'c', 'b']);
  });

  it('nobody has finished a job yet: experience counts for nothing', () => {
    const s = scores([{ ...a, completedJobs: 0 }]);
    expect(s.get('a')).toBeCloseTo(0.5 * 0.98 + 0.2 * 0.8, 6);
  });

  it('bay jobs ignore distance', () => {
    const s = scores([{ ...a, distanceKm: null }]);
    expect(s.get('a')).toBeCloseTo(0.5 * 0.98 + 0.3 + 0.2, 6);
  });

  it('"any available" gives each start to the best technician that has it', () => {
    const ranked = rank([b, a]);
    const t1 = k('2026-10-14 16:00');
    const t2 = k('2026-10-14 16:30');
    const t3 = k('2026-10-14 17:00');
    const merged = anyAvailable(
      ranked,
      new Map([
        ['a', [t2]],
        ['b', [t1, t2, t3]],
      ]),
    );
    expect(merged).toEqual([
      { start: t1, technicianId: 'b' },
      { start: t2, technicianId: 'a' },
      { start: t3, technicianId: 'b' },
    ]);
  });
});
