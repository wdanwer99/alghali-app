import { afterAll, describe, expect, it } from 'vitest';
import { connect, hasDb, skipReason, withRollback, type Sql, must } from '../support/db.ts';
import {
  asAnon,
  asSystem,
  asUser,
  createAdmin,
  createUser,
  failure,
  variantIds,
} from '../support/fixtures.ts';

describe.skipIf(!hasDb)('catalogue', () => {
  const sql: Sql = connect();
  afterAll(() => sql.end());

  describe('Arabic normaliser (twin of arabic.dart)', () => {
    it.each([
      ['أإآٱ', 'اااا'],
      ['لمبة', 'لمبه'],
      ['مستشفى', 'مستشفي'],
      ['مُحَرِّك', 'محرك'],
      ['بـــطارية', 'بطاريه'],
      ['  Brake   PADS ', 'brake pads'],
      ['٤٥٠٠٠ ۱۲', '45000 12'],
      ['کیا', 'كيا'],
    ])('ar_normalize(%s) = %s', async (input, expected) => {
      const [row] = await sql<{ n: string }[]>`select public.ar_normalize(${input}) as n`;
      expect(row?.n).toBe(expected);
    });

    it.each([
      ['لمبات', ['لمب']],
      ['لمبة', ['لمب']],
      ['لمبه', ['لمب']],
      ['اللمبات', ['لمب']],
      ['فلتر زيت', ['زيت', 'فلتر']],
      ['زيت 5W-30، فلتر', ['5w-30', 'زيت', 'فلتر']],
      ['إطار 265/65R17.', ['265/65r17', 'اطار']],
      ['OEM: 04465-0K290', ['04465-0k290', 'oem']],
      ['!!!', []],
    ])('search_terms(%s) = %j', async (input, expected) => {
      const [row] = await sql<{ t: string[] }[]>`select public.search_terms(${input}) as t`;
      expect([...(row?.t ?? [])].sort()).toEqual([...expected].sort());
    });
  });

  it('ships the starter catalogue in every environment', async () => {
    const [row] = await sql<Record<string, string>[]>`
      select (select count(*) from public.vehicle_makes) as makes,
             (select count(*) from public.vehicle_variants) as variants,
             (select count(*) from public.part_categories) as categories,
             (select count(*) from public.job_types) as job_types,
             (select count(*) from public.zones) as zones`;
    expect(Number(row?.makes)).toBeGreaterThanOrEqual(10);
    expect(Number(row?.variants)).toBeGreaterThanOrEqual(100);
    // 12 part categories and 9 job types, plus window tint (D-149).
    expect(Number(row?.categories)).toBe(13);
    expect(Number(row?.job_types)).toBe(10);
    expect(Number(row?.zones)).toBe(4);
  });

  it('every installable category has a job type and a standard duration', async () => {
    const rows = await sql`
      select slug from public.part_categories
      where (job_type_id is null) <> (std_job_minutes is null)`;
    expect(rows).toEqual([]);
  });

  it('anyone reads active catalogue rows; inactive ones only admins see', async () => {
    await withRollback(sql, async (tx) => {
      await tx`update public.vehicle_makes set is_active = false where slug = 'geely'`;
      const admin = await createAdmin(tx);
      await asAnon(tx);
      const anon = await tx`select slug from public.vehicle_makes`;
      expect(anon.map((r) => r.slug)).not.toContain('geely');
      expect(anon.map((r) => r.slug)).toContain('toyota');
      await asUser(tx, admin);
      const all = await tx`select slug from public.vehicle_makes`;
      expect(all.map((r) => r.slug)).toContain('geely');
    });
  });

  it('only admins write the catalogue, and their changes are audited', async () => {
    await withRollback(sql, async (tx) => {
      const user = await createUser(tx);
      const admin = await createAdmin(tx);
      await asUser(tx, user);
      const err = await failure(
        tx,
        (sp) =>
          sp`insert into public.vehicle_makes (slug, name_ar, name_en) values ('lada', 'لادا', 'Lada')`,
      );
      expect(err.message).toMatch(/row-level security/);

      await asUser(tx, admin);
      const [make] = await tx`insert into public.vehicle_makes (slug, name_ar, name_en)
                              values ('lada', 'لادا', 'Lada') returning id`;
      await tx`update public.vehicle_makes set name_en = 'LADA' where id = ${must(make).id}`;
      await asSystem(tx);
      const audit =
        await tx`select action, actor_id from public.audit_log where entity = 'vehicle_makes'
                             and entity_id = ${must(make).id} order by id`;
      expect(audit).toEqual([
        { action: 'INSERT', actor_id: admin },
        { action: 'UPDATE', actor_id: admin },
      ]);
    });
  });

  it('a synonym group is normalised for query expansion', async () => {
    await withRollback(sql, async (tx) => {
      const admin = await createAdmin(tx);
      await asUser(tx, admin);
      const [s] =
        await tx`insert into public.search_synonyms (terms) values (array['شكمان', 'الشكمانات', 'exhaust'])
                           returning id`;
      await asSystem(tx);
      const terms =
        await tx`select term from public.search_synonym_terms where synonym_id = ${must(s).id} order by term`;
      expect(terms.map((r) => r.term)).toEqual(['exhaust', 'شكمان']);
      const [q] = await tx<{ q: string }[]>`select public.search_query('شكمانات')::text as q`;
      expect(q?.q).toContain("'exhaust':*");
    });
  });

  describe('garage', () => {
    it('buyers see and change only their own cars', async () => {
      await withRollback(sql, async (tx) => {
        const [v] = await variantIds(tx, 'toyota', 'hilux');
        const a = await createUser(tx);
        const b = await createUser(tx);
        await asUser(tx, a);
        const [car] =
          await tx`insert into public.garage_vehicles (variant_id, nickname) values (${must(v)}, 'الهايلكس')
                               returning id, user_id, is_default`;
        expect(car).toMatchObject({ user_id: a, is_default: true });

        await asUser(tx, b);
        expect(await tx`select id from public.garage_vehicles`).toHaveLength(0);
        const upd =
          await tx`update public.garage_vehicles set nickname = 'x' where id = ${must(car).id} returning id`;
        expect(upd).toHaveLength(0);
        const err = await failure(
          tx,
          (sp) =>
            sp`insert into public.garage_vehicles (user_id, variant_id) values (${a}, ${must(v)})`,
        );
        expect(err.message).toMatch(/row-level security/);
      });
    });

    it('keeps exactly one default car, and promotes another when the default goes', async () => {
      await withRollback(sql, async (tx) => {
        const [v1, v2] = await variantIds(tx, 'toyota', 'corolla');
        const a = await createUser(tx);
        await asUser(tx, a);
        const [first] =
          await tx`insert into public.garage_vehicles (variant_id) values (${must(v1)}) returning id`;
        const [second] =
          await tx`insert into public.garage_vehicles (variant_id, is_default) values (${must(v2)}, true)
                                  returning id`;
        const defaults = async () =>
          (await tx`select id from public.garage_vehicles where is_default`).map((r) => r.id);
        expect(await defaults()).toEqual([must(second).id]);
        await tx`delete from public.garage_vehicles where id = ${must(second).id}`;
        expect(await defaults()).toEqual([must(first).id]);
      });
    });

    it('cleans up the VIN and rejects bad ones', async () => {
      await withRollback(sql, async (tx) => {
        const [v] = await variantIds(tx, 'nissan', 'sunny');
        const a = await createUser(tx);
        await asUser(tx, a);
        const [car] = await tx`insert into public.garage_vehicles (variant_id, vin)
                               values (${must(v)}, ' jtfss22p0g0123456 ') returning vin`;
        expect(car?.vin).toBe('JTFSS22P0G0123456');
        const err = await failure(
          tx,
          (sp) =>
            sp`insert into public.garage_vehicles (variant_id, vin) values (${must(v)}, 'SHORT')`,
        );
        expect(err.message).toMatch(/garage_vehicles_vin_check/);
      });
    });

    it('holds at most 10 cars', async () => {
      await withRollback(sql, async (tx) => {
        const [v] = await variantIds(tx, 'kia', 'rio');
        const a = await createUser(tx);
        await asUser(tx, a);
        for (let i = 0; i < 10; i++)
          await tx`insert into public.garage_vehicles (variant_id) values (${must(v)})`;
        const err = await failure(
          tx,
          (sp) => sp`insert into public.garage_vehicles (variant_id) values (${must(v)})`,
        );
        expect(err.message).toBe('GARAGE_FULL');
      });
    });
  });
});

describe.runIf(!hasDb)('catalogue (skipped)', () => {
  it.skip(skipReason, () => undefined);
});
