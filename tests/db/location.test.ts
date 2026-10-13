import { afterAll, describe, expect, it } from 'vitest';
import {
  connect,
  hasDb,
  skipReason,
  withRollback,
  type Sql,
  type Tx,
  must,
} from '../support/db.ts';
import {
  asAnon,
  asSystem,
  asUser,
  categoryId,
  createAdmin,
  createShop,
  createUser,
  failure,
} from '../support/fixtures.ts';

async function firstZone(tx: Tx): Promise<string> {
  const [z] = await tx<{ id: string }[]>`select id from public.zones order by seq limit 1`;
  return must(z).id;
}

async function apply(tx: Tx, extra: Record<string, unknown> = {}) {
  const zone = await firstZone(tx);
  const [row] = await tx<{ r: Record<string, unknown> & { id: string } }[]>`
    select public.apply_as_shop(
      p_name_ar => ${(extra.name as string) ?? 'النور لقطع الغيار'},
      p_zone_id => ${zone},
      p_phone => ${(extra.phone as string) ?? '0912345678'},
      p_whatsapp => ${(extra.whatsapp as string) ?? null},
      p_opening_hours => ${tx.json((extra.hours ?? { '0': [[480, 1200]] }) as never)},
      p_category_ids => ${(extra.categories as string[]) ?? []}::uuid[]
    ) as r`;
  return must(row).r;
}

describe.skipIf(!hasDb)('shops and street', () => {
  const sql: Sql = connect();
  afterAll(() => sql.end());

  describe('opening hours', () => {
    it.each([
      [{}, true],
      [
        {
          '0': [
            [480, 780],
            [960, 1260],
          ],
        },
        true,
      ],
      [{ '6': [] }, true],
      [{ '7': [[0, 60]] }, false],
      [{ '0': [[780, 480]] }, false],
      [
        {
          '0': [
            [480, 780],
            [700, 900],
          ],
        },
        false,
      ],
      [{ '0': [[0, 1441]] }, false],
      [{ '0': [[0.5, 60]] }, false],
      [{ '0': '8-5' }, false],
      [[], false],
    ])('%j valid: %s', async (hours, ok) => {
      const [row] = await sql<
        { v: boolean }[]
      >`select public.valid_opening_hours(${sql.json(hours as never)}) as v`;
      expect(row?.v).toBe(ok);
    });

    it('is_open_at uses Khartoum time and weekday 0 = Sunday', async () => {
      // 2026-10-18 is a Sunday; 07:30 UTC = 09:30 in Khartoum (UTC+2).
      const hours = { '0': [[540, 600]] };
      const at = async (iso: string) =>
        (
          await sql<
            { o: boolean }[]
          >`select public.is_open_at(${sql.json(hours)}, ${iso}::timestamptz) as o`
        )[0]?.o;
      expect(await at('2026-10-18T07:30:00Z')).toBe(true);
      expect(await at('2026-10-18T06:59:00Z')).toBe(false);
      expect(await at('2026-10-18T08:00:00Z')).toBe(false);
      expect(await at('2026-10-19T07:30:00Z')).toBe(false);
    });
  });

  describe('applying', () => {
    it('creates a pending shop the applicant owns, hidden from the public', async () => {
      await withRollback(sql, async (tx) => {
        const user = await createUser(tx);
        const lighting = await categoryId(tx, 'lighting');
        await asUser(tx, user);
        const shop = await apply(tx, { categories: [lighting], whatsapp: '0911 222 333' });
        expect(shop).toMatchObject({
          status: 'PENDING',
          phone: '+249912345678',
          whatsapp: '+249911222333',
          category_ids: [lighting],
          verified: false,
        });
        const [me] = await tx<
          { m: { shops: { shop_id: string; role: string; status: string }[] } }[]
        >`
          select public.me() as m`;
        expect(me?.m.shops).toEqual([
          expect.objectContaining({ shop_id: shop.id, role: 'OWNER', status: 'PENDING' }),
        ]);
        await asAnon(tx);
        expect(await tx`select id from public.shops where id = ${shop.id}`).toHaveLength(0);
      });
    });

    it('allows one pending application at a time and needs a valid phone', async () => {
      await withRollback(sql, async (tx) => {
        const user = await createUser(tx);
        await asUser(tx, user);
        expect((await failure(tx, (sp) => apply(sp, { phone: '123' }))).message).toBe(
          'INVALID_PHONE',
        );
        await apply(tx);
        const err = await failure(tx, (sp) => apply(sp, { name: 'محل ثاني' }));
        expect(err).toEqual({ code: 'PT409', message: 'APPLICATION_PENDING' });
      });
    });

    it('rejects bad opening hours', async () => {
      await withRollback(sql, async (tx) => {
        const user = await createUser(tx);
        await asUser(tx, user);
        const err = await failure(tx, (sp) => apply(sp, { hours: { '0': [[900, 100]] } }));
        expect(err.message).toBe('INVALID_OPENING_HOURS');
      });
    });
  });

  describe('admin review', () => {
    it('approval publishes the shop, grants SHOP_OWNER and places it mid-zone', async () => {
      await withRollback(sql, async (tx) => {
        const owner = await createUser(tx);
        const admin = await createAdmin(tx);
        await asUser(tx, owner);
        const shop = await apply(tx);
        expect(shop.pos_m).toBeNull();

        await asUser(tx, owner);
        expect(
          (
            await failure(
              tx,
              (sp) => sp`select public.admin_set_shop_status(${shop.id}, 'APPROVED')`,
            )
          ).message,
        ).toBe('FORBIDDEN');

        await asUser(tx, admin);
        const [r] = await tx<{ s: { status: string; pos_m: number; approved_at: string } }[]>`
          select public.admin_set_shop_status(${shop.id}, 'APPROVED') as s`;
        expect(r?.s).toMatchObject({ status: 'APPROVED', pos_m: 150 });
        expect(r?.s.approved_at).toBeTruthy();

        await asSystem(tx);
        const roles =
          await tx`select role from public.user_roles where user_id = ${owner} order by role`;
        expect(roles.map((x) => x.role)).toEqual(['BUYER', 'SHOP_OWNER']);
        await asAnon(tx);
        expect(await tx`select id from public.shops where id = ${shop.id}`).toHaveLength(1);
      });
    });

    it('enforces the review transitions and asks for a reason to reject or suspend', async () => {
      await withRollback(sql, async (tx) => {
        const owner = await createUser(tx);
        const admin = await createAdmin(tx);
        const shop = await createShop(tx, owner, { status: 'PENDING' });
        await asUser(tx, admin);
        const set =
          (status: string, reason: string | null = null) =>
          (sp: Tx) =>
            sp`select public.admin_set_shop_status(${shop}, ${status}::public.partner_status, ${reason})`;
        expect((await failure(tx, set('SUSPENDED', 'x'))).message).toBe('INVALID_TRANSITION');
        expect((await failure(tx, set('REJECTED'))).message).toBe('REASON_REQUIRED');
        await set('REJECTED', 'لا توجد صورة للمحل')(tx);
        await set('APPROVED')(tx);
        await set('SUSPENDED', 'شكاوى متكررة')(tx);
        await set('APPROVED')(tx);
        expect((await failure(tx, set('PENDING'))).message).toBe('INVALID_TRANSITION');
        await asSystem(tx);
        const audit = await tx`select data ->> 'to' as t from public.audit_log
                               where entity = 'shop' and entity_id = ${shop} and action = 'SET_STATUS' order by id`;
        expect(audit.map((x) => x.t)).toEqual(['REJECTED', 'APPROVED', 'SUSPENDED', 'APPROVED']);
      });
    });

    it('a suspended shop disappears from public reads', async () => {
      await withRollback(sql, async (tx) => {
        const owner = await createUser(tx);
        const shop = await createShop(tx, owner);
        await tx`update public.shops set status = 'SUSPENDED' where id = ${shop}`;
        await asAnon(tx);
        expect(await tx`select id from public.shops where id = ${shop}`).toHaveLength(0);
        await asUser(tx, owner);
        expect(await tx`select id from public.shops where id = ${shop}`).toHaveLength(1);
      });
    });
  });

  describe('profile and staff', () => {
    it('owners edit the profile; staff and strangers cannot; only admins move the shop', async () => {
      await withRollback(sql, async (tx) => {
        const owner = await createUser(tx);
        const staff = await createUser(tx, { email: 'staff-a@test.alghali.invalid' });
        const stranger = await createUser(tx);
        const admin = await createAdmin(tx);
        const shop = await createShop(tx, owner);
        await asUser(tx, owner);
        await tx`select public.shop_add_staff(${shop}, 'STAFF-A@test.alghali.invalid')`;

        const [r] = await tx<{ s: Record<string, unknown> }[]>`
          select public.shop_update_profile(${shop}, ${tx.json({ name_en: 'Al-Nour', landmark_ar: 'مقابل البنك', phone: '0123 456 789' })}) as s`;
        expect(r?.s).toMatchObject({
          name_en: 'Al-Nour',
          landmark_ar: 'مقابل البنك',
          phone: '+249123456789',
        });

        const patch = (body: Record<string, unknown>) => (sp: Tx) =>
          sp`select public.shop_update_profile(${shop}, ${sp.json(body as never)})`;
        expect((await failure(tx, patch({ pos_m: 10 }))).message).toBe('FORBIDDEN');
        expect((await failure(tx, patch({ storefront_key: 'shops/other/x.webp' }))).message).toBe(
          'INVALID_IMAGE_KEY',
        );
        await asUser(tx, staff);
        expect((await failure(tx, patch({ name_en: 'x' }))).message).toBe('FORBIDDEN');
        await asUser(tx, stranger);
        expect((await failure(tx, patch({ name_en: 'x' }))).message).toBe('FORBIDDEN');
        await asUser(tx, admin);
        await patch({ pos_m: 420 })(tx);
        await asSystem(tx);
        expect((await tx`select pos_m from public.shops where id = ${shop}`)[0]?.pos_m).toBe(420);
      });
    });

    it('staff join by email, get SHOP_STAFF on an approved shop, and can be removed', async () => {
      await withRollback(sql, async (tx) => {
        const owner = await createUser(tx);
        const staff = await createUser(tx, { email: 'staff-b@test.alghali.invalid' });
        const shop = await createShop(tx, owner);
        await asUser(tx, owner);
        expect(
          (
            await failure(
              tx,
              (sp) => sp`select public.shop_add_staff(${shop}, 'nobody@test.alghali.invalid')`,
            )
          ).message,
        ).toBe('USER_NOT_FOUND');
        await tx`select public.shop_add_staff(${shop}, 'staff-b@test.alghali.invalid')`;
        expect(
          (
            await failure(
              tx,
              (sp) => sp`select public.shop_add_staff(${shop}, 'staff-b@test.alghali.invalid')`,
            )
          ).message,
        ).toBe('ALREADY_MEMBER');

        const team = await tx`select user_id, role, email from public.shop_staff(${shop})`;
        expect(team).toEqual([
          expect.objectContaining({ user_id: owner, role: 'OWNER' }),
          expect.objectContaining({
            user_id: staff,
            role: 'STAFF',
            email: 'staff-b@test.alghali.invalid',
          }),
        ]);

        await asUser(tx, staff);
        expect(
          await tx`select shop_id from public.shop_members where shop_id = ${shop}`,
        ).toHaveLength(2);
        expect(
          (await failure(tx, (sp) => sp`select public.shop_remove_staff(${shop}, ${owner})`))
            .message,
        ).toBe('FORBIDDEN');

        await asUser(tx, owner);
        expect(
          (await failure(tx, (sp) => sp`select public.shop_remove_staff(${shop}, ${owner})`))
            .message,
        ).toBe('CANNOT_REMOVE_OWNER');
        await tx`select public.shop_remove_staff(${shop}, ${staff})`;
        await asSystem(tx);
        const roles = await tx`select role from public.user_roles where user_id = ${staff}`;
        expect(roles.map((x) => x.role)).toEqual(['BUYER']);
      });
    });
  });

  describe('addresses', () => {
    it('are private to their owner and keep one default', async () => {
      await withRollback(sql, async (tx) => {
        const a = await createUser(tx);
        const b = await createUser(tx);
        await asUser(tx, a);
        const [home] =
          await tx`insert into public.addresses (label, lat, lng) values ('البيت', 15.59, 32.53)
                                returning id, is_default`;
        expect(home?.is_default).toBe(true);
        const [work] = await tx`insert into public.addresses (label, lat, lng, is_default)
                                values ('الشغل', 15.6, 32.54, true) returning id`;
        const defaults = await tx`select id from public.addresses where is_default`;
        expect(defaults.map((r) => r.id)).toEqual([must(work).id]);
        await asUser(tx, b);
        expect(await tx`select id from public.addresses`).toHaveLength(0);
        const err = await failure(
          tx,
          (sp) =>
            sp`insert into public.addresses (user_id, label, lat, lng) values (${a}, 'x', 1, 1)`,
        );
        expect(err.message).toMatch(/row-level security/);
      });
    });
  });
});

describe.runIf(!hasDb)('shops and street (skipped)', () => {
  it.skip(skipReason, () => undefined);
});
