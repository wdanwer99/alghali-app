import postgres from 'postgres';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { dbUrl, hasDb, must, skipReason } from '../support/db.ts';
import { asUser } from '../support/fixtures.ts';
import { createTechnician, khartoumAt } from '../support/bookings.ts';
import { createBuyer } from '../support/commerce.ts';

// PLAN M3 exit criterion: 20 parallel holds on one technician slot → exactly 1 succeeds.
// Twenty buyers on twenty connections, each in its own transaction, the way twenty phones
// would reach PostgREST at once. Unlike the other DB tests this commits real rows, so it
// cleans up after itself.
describe.skipIf(!hasDb)('concurrency', () => {
  // Hosted projects: the session pooler allows 15 clients, so go through the transaction
  // pooler (port 6543), which queues transactions beyond its pool instead of refusing them.
  const url = /pooler\.supabase\.com:5432\//.test(dbUrl)
    ? dbUrl.replace(':5432/', ':6543/')
    : dbUrl;
  const sql = postgres(url, {
    max: 20,
    prepare: false,
    idle_timeout: 5,
    onnotice: () => undefined,
  });
  let techId = '';
  let techUser = '';
  let bayShop = '';
  let buyers: string[] = [];
  let lighting = '';

  beforeAll(async () => {
    await sql.begin(async (tx) => {
      const tech = await createTechnician(tx, { mode: 'BAY' });
      techId = tech.techId;
      techUser = tech.userId;
      bayShop = must(tech.bayShopId);
      buyers = [];
      for (let i = 0; i < 20; i++) buyers.push(await createBuyer(tx));
      const [cat] = await tx<
        { id: string }[]
      >`select id from public.part_categories where slug = 'lighting'`;
      lighting = must(cat).id;
    });
  }, 120_000);

  afterAll(async () => {
    await sql`delete from public.bookings where technician_id = ${techId}`;
    await sql`delete from public.technicians where id = ${techId}`;
    const owners = await sql<
      { user_id: string }[]
    >`select user_id from public.shop_members where shop_id = ${bayShop}`;
    await sql`delete from public.shops where id = ${bayShop}`;
    await sql`delete from auth.users where id = any (${[...buyers, techUser, ...owners.map((o) => o.user_id)]}::uuid[])`;
    await sql.end();
  }, 120_000);

  it('20 buyers racing for one slot: exactly one hold, 19 SLOT_TAKEN', async () => {
    const start = khartoumAt(11, 2);
    const results = await Promise.allSettled(
      buyers.map((buyer) =>
        sql.begin(async (tx) => {
          await asUser(tx, buyer);
          await tx`select public.create_booking_hold(
                     p_technician_id => ${techId}, p_start_at => ${start},
                     p_items => ${tx.json([{ category_id: lighting, description: 'لمبات أمامية' }] as never)},
                     p_place => 'BAY')`;
        }),
      ),
    );
    const won = results.filter((r) => r.status === 'fulfilled');
    const lost = results.filter((r): r is PromiseRejectedResult => r.status === 'rejected');
    expect(won).toHaveLength(1);
    const reasons = lost.map((r) => (r.reason as { message: string }).message);
    expect(reasons.filter((m) => m !== 'SLOT_TAKEN')).toEqual([]);
    expect(reasons).toHaveLength(19);
    const [n] = await sql<{ n: number }[]>`
      select count(*)::int as n from public.bookings where technician_id = ${techId} and status = 'HELD'`;
    expect(must(n).n).toBe(1);
  }, 120_000);
});

describe.runIf(!hasDb)('concurrency (skipped)', () => {
  it.skip(skipReason, () => undefined);
});
