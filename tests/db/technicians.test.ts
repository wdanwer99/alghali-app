import { afterAll, describe, expect, it } from 'vitest';
import {
  connect,
  hasDb,
  must,
  skipReason,
  withRollback,
  type Sql,
  type Tx,
} from '../support/db.ts';
import {
  asSystem,
  asUser,
  createAdmin,
  createShop,
  createUser,
  failure,
} from '../support/fixtures.ts';
import { createTechnician, jobTypeId } from '../support/bookings.ts';

interface TechJson {
  id: string;
  status: string;
  work_mode: string;
  job_types: { code: string; labour_sdg: number }[];
  rules: unknown[];
  time_off: unknown[];
}

async function apply(tx: Tx, user: string, args: Record<string, unknown>): Promise<TechJson> {
  await asUser(tx, user);
  const [row] = await tx<{ t: TechJson }[]>`
    select public.apply_as_technician(
      p_work_mode => ${(args.mode as string) ?? 'MOBILE'}::public.work_mode,
      p_job_types => ${tx.json((args.jobs ?? []) as never)},
      p_phone => ${(args.phone as string) ?? '0912000111'},
      p_home_bay_shop_id => ${(args.bay as string) ?? null},
      p_home_lat => ${(args.lat as number) ?? null},
      p_home_lng => ${(args.lng as number) ?? null}) as t`;
  return must(row).t;
}

// Each case builds technicians, shops and orders over the internet: give it time.
describe.skipIf(!hasDb)('technicians', { timeout: 90_000 }, () => {
  const sql: Sql = connect();
  afterAll(() => sql.end());

  it('apply, then an admin approves: the TECHNICIAN role and a ledger account', async () => {
    await withRollback(sql, async (tx) => {
      const user = await createUser(tx);
      const lighting = await jobTypeId(tx, 'LIGHTING');
      const t = await apply(tx, user, {
        jobs: [{ job_type_id: lighting, labour_sdg: 5000 }],
        lat: 15.6,
        lng: 32.5,
      });
      expect(t.status).toBe('PENDING');
      expect(t.job_types).toEqual([
        expect.objectContaining({ code: 'LIGHTING', labour_sdg: 5000 }),
      ]);
      expect(
        await failure(tx, (sp) =>
          apply(sp, user, { jobs: [{ job_type_id: lighting, labour_sdg: 1 }], lat: 1, lng: 1 }),
        ),
      ).toEqual({ code: 'PT409', message: 'ALREADY_APPLIED' });

      const [me] = await tx<{ m: { technician: { status: string } } }[]>`select public.me() as m`;
      expect(must(me).m.technician.status).toBe('PENDING');

      await asUser(tx, user);
      expect(
        await failure(
          tx,
          (sp) => sp`select public.admin_set_technician_status(${t.id}, 'APPROVED')`,
        ),
      ).toEqual({
        code: '42501',
        message: 'FORBIDDEN',
      });
      const admin = await createAdmin(tx);
      await asUser(tx, admin);
      await tx`select public.admin_set_technician_status(${t.id}, 'APPROVED')`;
      await asSystem(tx);
      const roles =
        await tx`select role from public.user_roles where user_id = ${user} and role = 'TECHNICIAN'`;
      expect(roles).toHaveLength(1);
      expect(
        await tx`select 1 from public.ledger_accounts where technician_id = ${t.id}`,
      ).toHaveLength(1);
      const [n] = await tx<
        { code: string; app: string }[]
      >`select code, app from public.notifications where user_id = ${user}`;
      expect(n).toEqual({ code: 'TECHNICIAN_STATUS', app: 'partner' });
    });
  });

  it('a bay technician needs a bay on the street; a mobile one needs a home point', async () => {
    await withRollback(sql, async (tx) => {
      const lighting = await jobTypeId(tx, 'LIGHTING');
      const jobs = [{ job_type_id: lighting, labour_sdg: 5000 }];
      expect(
        await failure(tx, async (sp) => apply(sp, await createUser(sp), { mode: 'BAY', jobs })),
      ).toEqual({
        code: '22023',
        message: 'BAY_REQUIRED',
      });
      expect(
        await failure(tx, async (sp) => apply(sp, await createUser(sp), { mode: 'MOBILE', jobs })),
      ).toEqual({
        code: '22023',
        message: 'HOME_POINT_REQUIRED',
      });
      expect(
        await failure(tx, async (sp) =>
          apply(sp, await createUser(sp), { jobs: [], lat: 1, lng: 1 }),
        ),
      ).toEqual({
        code: '22023',
        message: 'JOB_TYPES_REQUIRED',
      });
      const bay = await createShop(tx, await createUser(tx));
      const t = await apply(tx, await createUser(tx), { mode: 'BAY', jobs, bay });
      expect(t.work_mode).toBe('BAY');
    });
  });

  it('labour must fall inside the admin’s bounds (D-010)', async () => {
    await withRollback(sql, async (tx) => {
      await asSystem(tx);
      await tx`update public.app_settings set value = '{"LIGHTING": {"min": 3000, "max": 20000}}' where key = 'labour_price_bounds'`;
      const lighting = await jobTypeId(tx, 'LIGHTING');
      const user = await createUser(tx);
      expect(
        await failure(tx, (sp) =>
          apply(sp, user, { jobs: [{ job_type_id: lighting, labour_sdg: 1000 }], lat: 1, lng: 1 }),
        ),
      ).toEqual({ code: '22023', message: 'LABOUR_OUT_OF_BOUNDS' });
      const ok = await apply(tx, user, {
        jobs: [{ job_type_id: lighting, labour_sdg: 4000 }],
        lat: 1,
        lng: 1,
      });
      expect(ok.status).toBe('PENDING');
    });
  });

  it('technicians keep their own hours and time off; nobody else can touch them', async () => {
    await withRollback(sql, async (tx) => {
      const a = await createTechnician(tx, { rules: [] });
      const b = await createTechnician(tx, { rules: [] });
      await asUser(tx, a.userId);
      await tx`insert into public.availability_rules (technician_id, weekday, start_min, end_min)
               values (${a.techId}, 6, 540, 780)`;
      expect(
        (
          await failure(
            tx,
            (
              sp,
            ) => sp`insert into public.availability_rules (technician_id, weekday, start_min, end_min)
                       values (${b.techId}, 6, 540, 780)`,
          )
        ).code,
      ).toBe('42501');
      await tx`select public.tech_quick_block(60)`;
      const [mine] = await tx<
        { t: TechJson }[]
      >`select public.tech_update_profile('{"radius_km": 15}') as t`;
      expect(must(mine).t.rules).toHaveLength(1);
      expect(must(mine).t.time_off).toHaveLength(1);

      await asUser(tx, b.userId);
      expect(
        await tx`select * from public.availability_rules where technician_id = ${a.techId}`,
      ).toHaveLength(0);
      expect(await tx`select * from public.technicians where id = ${a.techId}`).toHaveLength(0);

      const buyer = await createUser(tx);
      await asUser(tx, buyer);
      expect(await tx`select * from public.technicians`).toHaveLength(0);
      const [p] = await tx<
        { p: Record<string, unknown> }[]
      >`select public.technician_profile(${a.techId}) as p`;
      expect(must(p).p).toMatchObject({ id: a.techId, work_mode: 'BOTH' });
      expect(Object.keys(must(p).p)).not.toContain('home_lat');
    });
  });
});

describe.runIf(!hasDb)('technicians (skipped)', () => {
  it.skip(skipReason, () => undefined);
});
