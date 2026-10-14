import { describe, expect, it } from 'vitest';
import {
  bookingOptions,
  type BookingContext,
  type ContextTechnician,
} from '../../supabase/functions/_shared/slots/options.ts';

const everyDay = (start: number, end: number) =>
  [0, 1, 2, 3, 4, 5, 6].map((weekday) => ({
    weekday,
    start_min: start,
    end_min: end,
    modes: 'BOTH' as const,
  }));

function tech(over: Partial<ContextTechnician> & { id: string }): ContextTechnician {
  return {
    name: 'فني',
    avatar_key: null,
    verified: true,
    rating_avg: 4.5,
    rating_count: 10,
    completed_jobs: 10,
    years_experience: 5,
    bio_ar: null,
    bio_en: null,
    work_mode: 'BOTH',
    radius_km: 10,
    distance_km: 2,
    bay: null,
    labour_sdg: 5000,
    rules: everyDay(16 * 60, 18 * 60),
    time_off: [],
    busy: [],
    ...over,
  };
}

// Wednesday 14 October 2026, 09:30 in Khartoum.
const ctx = (technicians: ContextTechnician[]): BookingContext => ({
  now: '2026-10-14T07:30:00Z',
  duration_min: 60,
  travel_fee_sdg: 3000,
  booking_fee_sdg: 2000,
  mobile_deposit_sdg: 5000,
  job_type_ids: ['jt'],
  items: [],
  settings: {
    grid_min: 30,
    tz_offset_min: 120,
    horizon_days: 1,
    travel_buffer_min: 30,
    part_ready_buffer_min: 120,
  },
  technicians,
});

describe('booking options', () => {
  it('ranks technicians with free time, shows their next slot and the price range', () => {
    const out = bookingOptions(
      ctx([
        tech({ id: 'a', rating_avg: 4.9, completed_jobs: 100, labour_sdg: 7000 }),
        tech({ id: 'b', rating_avg: 4.0, labour_sdg: 4000 }),
        tech({ id: 'full', busy: [['2026-10-14T14:00:00Z', '2026-10-14T16:00:00Z']] }),
      ]),
      'CUSTOMER_LOCATION',
    );
    expect(out.technicians.map((t) => [t.id, t.next_slot, t.slot_count])).toEqual([
      ['a', '2026-10-14T14:00:00.000Z', 3],
      ['b', '2026-10-14T14:00:00.000Z', 3],
    ]);
    expect(out.labour_range).toEqual([4000, 7000]);
    expect(out.technicians[0]?.slots).toBeUndefined();
    expect(out.any.map((s) => s.technician_id)).toEqual(['a', 'a', 'a']);
    expect(out.travel_fee_sdg).toBe(3000);
  });

  it('for one technician, lists every start', () => {
    const out = bookingOptions(ctx([tech({ id: 'a' })]), 'BAY', 'a');
    expect(out.technicians[0]?.slots).toEqual([
      '2026-10-14T14:00:00.000Z',
      '2026-10-14T14:30:00.000Z',
      '2026-10-14T15:00:00.000Z',
    ]);
    expect(out.any).toEqual([]);
  });

  it('nobody free: an empty list and no price range', () => {
    const out = bookingOptions(ctx([tech({ id: 'a', rules: [] })]), 'BAY');
    expect(out.technicians).toEqual([]);
    expect(out.labour_range).toBeNull();
  });
});
