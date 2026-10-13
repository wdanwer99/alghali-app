import { afterAll, describe, expect, it } from 'vitest';
import { connect, hasDb, skipReason, withRollback, type Sql, must } from '../support/db.ts';
import { asAnon, asSystem, asUser, createAdmin, createUser, failure } from '../support/fixtures.ts';

describe.skipIf(!hasDb)('identity', () => {
  const sql: Sql = connect();
  afterAll(() => sql.end());

  describe('normalize_phone', () => {
    it.each([
      ['0912345678', '+249912345678'],
      ['912345678', '+249912345678'],
      ['249912345678', '+249912345678'],
      ['+249 91 234 5678', '+249912345678'],
      ['00249912345678', '+249912345678'],
      ['٠٩١٢٣٤٥٦٧٨', '+249912345678'],
      ['+971501234567', '+971501234567'],
      ['12345', null],
      ['abc', null],
      ['', null],
    ])('%s → %s', async (input, expected) => {
      const [row] = await sql<{ p: string | null }[]>`select public.normalize_phone(${input}) as p`;
      expect(row?.p).toBe(expected);
    });
  });

  it('a new account gets a profile from its sign-up data and the BUYER role', async () => {
    await withRollback(sql, async (tx) => {
      const id = await createUser(tx, {
        email: 'ahmed@test.alghali.invalid',
        meta: { display_name: '  أحمد  ', phone: '0912345678', locale: 'en' },
      });
      const [p] =
        await tx`select email, display_name, phone, locale, data_saver from public.profiles where id = ${id}`;
      expect(p).toEqual({
        email: 'ahmed@test.alghali.invalid',
        display_name: 'أحمد',
        phone: '+249912345678',
        locale: 'en',
        data_saver: true,
      });
      const roles = await tx`select role from public.user_roles where user_id = ${id}`;
      expect(roles.map((r) => r.role)).toEqual(['BUYER']);
    });
  });

  it('a bad phone at sign-up is dropped rather than blocking the account', async () => {
    await withRollback(sql, async (tx) => {
      const id = await createUser(tx, { meta: { phone: 'not a phone' } });
      const [p] = await tx`select phone, locale from public.profiles where id = ${id}`;
      expect(p).toEqual({ phone: null, locale: 'ar' });
    });
  });

  it('users see only their own profile and roles', async () => {
    await withRollback(sql, async (tx) => {
      const a = await createUser(tx);
      const b = await createUser(tx);
      await asUser(tx, a);
      const profiles = await tx`select id from public.profiles`;
      expect(profiles.map((r) => r.id)).toEqual([a]);
      const roles = await tx`select user_id from public.user_roles`;
      expect(roles.map((r) => r.user_id)).toEqual([a]);
      expect(b).not.toBe(a);
    });
  });

  it('anon reads no profiles', async () => {
    await withRollback(sql, async (tx) => {
      await createUser(tx);
      await asAnon(tx);
      const err = await failure(tx, (sp) => sp`select id from public.profiles`);
      expect(err.message).toMatch(/permission denied/);
    });
  });

  it('update_profile changes only the given fields and validates them', async () => {
    await withRollback(sql, async (tx) => {
      const id = await createUser(tx, { meta: { display_name: 'Sara', phone: '0912345678' } });
      await asUser(tx, id);

      const [r] =
        await tx`select public.update_profile(p_locale => 'en', p_data_saver => false) as p`;
      expect(r?.p).toMatchObject({
        display_name: 'Sara',
        phone: '+249912345678',
        locale: 'en',
        data_saver: false,
      });

      const [r2] = await tx`select public.update_profile(p_phone => '0123456789') as p`;
      expect(r2?.p).toMatchObject({ phone: '+249123456789' });

      const [r3] = await tx`select public.update_profile(p_phone => '') as p`;
      expect(r3?.p).toMatchObject({ phone: null });

      expect(await failure(tx, (sp) => sp`select public.update_profile(p_phone => '123')`)).toEqual(
        {
          code: '22023',
          message: 'INVALID_PHONE',
        },
      );
      expect(
        (await failure(tx, (sp) => sp`select public.update_profile(p_locale => 'fr')`)).message,
      ).toBe('INVALID_LOCALE');
    });
  });

  it('profiles cannot be written directly', async () => {
    await withRollback(sql, async (tx) => {
      const id = await createUser(tx);
      await asUser(tx, id);
      const err = await failure(
        tx,
        (sp) => sp`update public.profiles set phone_verified_at = now() where id = ${id}`,
      );
      expect(err.message).toMatch(/permission denied/);
    });
  });

  it('anonymous callers are told to sign in', async () => {
    await withRollback(sql, async (tx) => {
      await asAnon(tx);
      const err = await failure(tx, (sp) => sp`select public.me()`);
      expect(err.message).toMatch(/permission denied/);
    });
  });

  it('register_device moves a token to whoever signed in last on that phone', async () => {
    await withRollback(sql, async (tx) => {
      const a = await createUser(tx);
      const b = await createUser(tx);
      const token = `fcm-${crypto.randomUUID()}`;
      await asUser(tx, a);
      await tx`select public.register_device('buyer', 'android', ${token}, 3, 'ar')`;
      await asUser(tx, b);
      await tx`select public.register_device('buyer', 'android', ${token}, 4, 'en')`;
      await asSystem(tx);
      const rows =
        await tx`select user_id, app_build, locale from public.devices where fcm_token = ${token}`;
      expect(rows).toEqual([{ user_id: b, app_build: 4, locale: 'en' }]);

      await asUser(tx, a);
      await tx`select public.unregister_device(${token})`; // not a's any more: no effect
      await asUser(tx, b);
      expect(await tx`select id from public.devices`).toHaveLength(1);
      await tx`select public.unregister_device(${token})`;
      expect(await tx`select id from public.devices`).toHaveLength(0);
    });
  });

  describe('roles', () => {
    it('only admins grant roles', async () => {
      await withRollback(sql, async (tx) => {
        const user = await createUser(tx);
        const other = await createUser(tx);
        await asUser(tx, user);
        const err = await failure(
          tx,
          (sp) => sp`select public.admin_grant_role(${other}, 'ADMIN')`,
        );
        expect(err).toEqual({ code: '42501', message: 'FORBIDDEN' });
      });
    });

    it('an admin grants and revokes roles, and both are audited', async () => {
      await withRollback(sql, async (tx) => {
        const admin = await createAdmin(tx);
        const user = await createUser(tx);
        await asUser(tx, admin);
        await tx`select public.admin_grant_role(${user}, 'TECHNICIAN')`;
        await tx`select public.admin_grant_role(${user}, 'TECHNICIAN')`; // idempotent
        await asSystem(tx);
        expect(
          (await tx`select role from public.user_roles where user_id = ${user} order by role`).map(
            (r) => r.role,
          ),
        ).toEqual(['BUYER', 'TECHNICIAN']);

        await asUser(tx, admin);
        await tx`select public.admin_revoke_role(${user}, 'TECHNICIAN')`;
        await asSystem(tx);
        expect(
          (await tx`select role from public.user_roles where user_id = ${user}`).map((r) => r.role),
        ).toEqual(['BUYER']);
        const audit =
          await tx`select action from public.audit_log where entity_id = ${user} order by id`;
        expect(audit.map((r) => r.action)).toEqual(['GRANT_ROLE', 'GRANT_ROLE', 'REVOKE_ROLE']);
      });
    });

    it('an admin cannot remove their own admin role or anyone’s buyer role', async () => {
      await withRollback(sql, async (tx) => {
        const admin = await createAdmin(tx);
        await asUser(tx, admin);
        expect(
          (await failure(tx, (sp) => sp`select public.admin_revoke_role(${admin}, 'ADMIN')`))
            .message,
        ).toBe('CANNOT_REVOKE_OWN_ADMIN');
        expect(
          (await failure(tx, (sp) => sp`select public.admin_revoke_role(${admin}, 'BUYER')`))
            .message,
        ).toBe('CANNOT_REVOKE_BUYER');
      });
    });

    it('a revoked role stops working at once (RLS reads the table, not the token)', async () => {
      await withRollback(sql, async (tx) => {
        const admin = await createAdmin(tx);
        await asUser(tx, admin);
        expect((await tx`select public.is_admin() as a`)[0]?.a).toBe(true);
        await asSystem(tx);
        await tx`delete from public.user_roles where user_id = ${admin} and role = 'ADMIN'`;
        await asUser(tx, admin);
        expect((await tx`select public.is_admin() as a`)[0]?.a).toBe(false);
      });
    });

    it('admin_search_users finds by email, name or phone', async () => {
      await withRollback(sql, async (tx) => {
        const admin = await createAdmin(tx);
        const user = await createUser(tx, {
          email: 'needle-user@test.alghali.invalid',
          meta: { display_name: 'Needle', phone: '0911111111' },
        });
        await asUser(tx, admin);
        for (const q of ['needle-user', 'Needle', '0911111111']) {
          const rows = await tx`select id, roles from public.admin_search_users(${q})`;
          expect(rows.map((r) => r.id)).toContain(user);
        }
        await asUser(tx, user);
        expect(
          (await failure(tx, (sp) => sp`select * from public.admin_search_users('x')`)).message,
        ).toBe('FORBIDDEN');
      });
    });
  });

  describe('settings', () => {
    it('admins read every setting; others cannot', async () => {
      await withRollback(sql, async (tx) => {
        const admin = await createAdmin(tx);
        const user = await createUser(tx);
        await asUser(tx, admin);
        const rows = await tx`select key from public.admin_settings()`;
        expect(rows.map((r) => r.key)).toContain('commission_percent');
        await asUser(tx, user);
        expect((await failure(tx, (sp) => sp`select * from public.admin_settings()`)).message).toBe(
          'FORBIDDEN',
        );
      });
    });

    it.each([
      ['commission_percent', 7.5, true],
      ['commission_percent', 80, false],
      ['booking_fee_sdg', 2500, true],
      ['booking_fee_sdg', 2500.5, false],
      ['booking_fee_sdg', '2500', false],
      ['slot_hold_minutes', -1, false],
      [
        'travel_fee_bands',
        [
          { max_km: 3, sdg: 3000 },
          { max_km: 8, sdg: 6000 },
        ],
        true,
      ],
      [
        'travel_fee_bands',
        [
          { max_km: 8, sdg: 6000 },
          { max_km: 3, sdg: 3000 },
        ],
        false,
      ],
      ['travel_fee_bands', [], false],
      ['bankak_account_number', '1234567', true],
      ['bankak_account_number', 1234567, false],
      ['payout_schedule', { frequency: 'weekly', weekday: 0 }, true],
      ['payout_schedule', { frequency: 'daily', weekday: 0 }, false],
      [
        'latest_app_versions',
        {
          buyer: { latest_build: 5, min_build: 3, apk_url: 'https://x/buyer.apk' },
          partner: { latest_build: 2, min_build: 2, apk_url: null },
        },
        true,
      ],
      [
        'latest_app_versions',
        {
          buyer: { latest_build: 2, min_build: 3, apk_url: null },
          partner: { latest_build: 1, min_build: 1, apk_url: null },
        },
        false,
      ],
    ])('%s = %j is valid: %s', async (key, value, ok) => {
      await withRollback(sql, async (tx) => {
        const admin = await createAdmin(tx);
        await asUser(tx, admin);
        const call = (sp: typeof tx) =>
          sp`select public.admin_update_setting(${key}, ${sp.json(value as never)})`;
        if (ok) {
          const [row] = await tx<{ r: { value: unknown; updated_by: string } }[]>`
            select public.admin_update_setting(${key}, ${tx.json(value as never)}) as r`;
          expect(row?.r.value).toEqual(value);
          expect(row?.r.updated_by).toBe(admin);
        } else {
          expect((await failure(tx, call)).message).toBe('INVALID_SETTING');
        }
      });
    });

    it('unknown settings cannot be created', async () => {
      await withRollback(sql, async (tx) => {
        const admin = await createAdmin(tx);
        await asUser(tx, admin);
        const err = await failure(
          tx,
          (sp) => sp`select public.admin_update_setting('made_up', '1'::jsonb)`,
        );
        expect(err).toEqual({ code: 'P0002', message: 'UNKNOWN_SETTING' });
      });
    });

    it('apps see the app-version and support settings', async () => {
      const [row] = await sql<
        { s: Record<string, unknown> }[]
      >`select public.public_settings() as s`;
      expect(row?.s).toHaveProperty('latest_app_versions.buyer.min_build');
      expect(row?.s).toHaveProperty('support_phone');
    });
  });

  describe('idempotency', () => {
    it('a replayed call returns the first result and does nothing twice', async () => {
      await withRollback(sql, async (tx) => {
        const user = await createUser(tx);
        const [zone] = await tx`select id from public.zones order by seq limit 1`;
        await asUser(tx, user);
        const key = crypto.randomUUID();
        const call = () => tx<{ r: { id: string } }[]>`
          select public.apply_as_shop(p_name_ar => 'محل التجربة', p_zone_id => ${must(zone).id},
                                      p_phone => '0912345678', p_idem => ${key}) as r`;
        const [first] = await call();
        const [second] = await call();
        expect(second?.r.id).toBe(first?.r.id);
        expect(await tx`select id from public.shops where created_by = ${user}`).toHaveLength(1);
      });
    });

    it('reusing a key for a different call is refused', async () => {
      await withRollback(sql, async (tx) => {
        const user = await createUser(tx);
        const [zone] = await tx`select id from public.zones order by seq limit 1`;
        await asUser(tx, user);
        const key = crypto.randomUUID();
        await tx`select public.apply_as_shop(p_name_ar => 'محل', p_zone_id => ${must(zone).id},
                                             p_phone => '0912345678', p_idem => ${key})`;
        const [shop] = await tx`select id from public.shops where created_by = ${user}`;
        const err = await failure(
          tx,
          (sp) => sp`select public.shop_bulk_update(${must(shop).id}, '[]'::jsonb, ${key})`,
        );
        expect(err.message).toBe('IDEMPOTENCY_KEY_REUSED');
      });
    });
  });
});

describe.runIf(!hasDb)('identity (skipped)', () => {
  it.skip(skipReason, () => undefined);
});
