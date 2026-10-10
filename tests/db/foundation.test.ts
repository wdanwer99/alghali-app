import { afterAll, describe, expect, it } from 'vitest';
import { actAs, connect, hasDb, skipReason, withRollback, type Sql } from '../support/db.ts';

describe.skipIf(!hasDb)('foundation migration', () => {
  const sql: Sql = connect();
  afterAll(() => sql.end());

  it('has the extensions later milestones depend on', async () => {
    const rows = await sql<{ extname: string }[]>`select extname from pg_extension`;
    const names = rows.map((r) => r.extname);
    for (const ext of ['postgis', 'btree_gist', 'pg_trgm', 'pg_net', 'pg_cron', 'pgmq']) {
      expect(names, `extension ${ext}`).toContain(ext);
    }
  });

  it('every table in the public schema has row level security enabled', async () => {
    const rows = await sql<{ table: string }[]>`
      select c.relname as table
      from pg_class c join pg_namespace n on n.oid = c.relnamespace
      where n.nspname = 'public' and c.relkind in ('r', 'p') and not c.relrowsecurity`;
    expect(rows.map((r) => r.table)).toEqual([]);
  });

  it('ping() answers anonymous callers', async () => {
    const res = await withRollback(sql, async (tx) => {
      await actAs(tx, 'anon');
      const [row] = await tx<
        { ping: { ok: boolean; server_time: string } }[]
      >`select public.ping()`;
      return row?.ping;
    });
    expect(res?.ok).toBe(true);
    expect(Number.isNaN(Date.parse(res?.server_time ?? ''))).toBe(false);
  });

  it('public_settings() exposes buyer-facing settings only', async () => {
    const settings = await withRollback(sql, async (tx) => {
      await actAs(tx, 'anon');
      const [row] = await tx<
        { s: Record<string, unknown> }[]
      >`select public.public_settings() as s`;
      return row?.s ?? {};
    });
    expect(settings).toHaveProperty('bankak_account_number');
    expect(settings).toHaveProperty('booking_fee_sdg');
    expect(settings).not.toHaveProperty('commission_percent');
    expect(settings).not.toHaveProperty('payout_schedule');
  });

  it('anonymous and signed-in users cannot read app_settings directly', async () => {
    for (const role of ['anon', 'authenticated'] as const) {
      await expect(
        withRollback(sql, async (tx) => {
          await actAs(tx, role, role === 'authenticated' ? crypto.randomUUID() : undefined);
          return tx`select key from public.app_settings`;
        }),
      ).rejects.toThrow(/permission denied/);
    }
  });

  it('money settings are whole SDG numbers', async () => {
    const rows = await sql<{ key: string; value: unknown }[]>`
      select key, value from public.app_settings where key like '%\\_sdg' escape '\\'`;
    expect(rows.length).toBeGreaterThan(0);
    for (const r of rows) expect(Number.isInteger(r.value), r.key).toBe(true);
  });
});

describe.runIf(!hasDb)('foundation migration (skipped)', () => {
  it.skip(skipReason, () => undefined);
});
