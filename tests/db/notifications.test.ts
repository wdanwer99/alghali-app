import { readdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
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
import { asSystem, asUser, createUser, failure } from '../support/fixtures.ts';

const migrations = join(import.meta.dirname, '../../supabase/migrations');

/** Every alert code any migration sends (notify, notify_shop, notify_partner, notify_admins, direct inserts). */
function codesInMigrations(): string[] {
  const codes = new Set<string>();
  for (const f of readdirSync(migrations).filter((x) => x.endsWith('.sql'))) {
    const text = readFileSync(join(migrations, f), 'utf8');
    for (const m of text.matchAll(/notify(?:_shop|_partner)?\([^,]+,\s*'([A-Z_]+)'/g))
      codes.add(must(m[1]));
    for (const m of text.matchAll(/notify_admins\(\s*'([A-Z_]+)'/g)) codes.add(must(m[1]));
    for (const m of text.matchAll(/then '([A-Z_]+)' else '([A-Z_]+)' end/g)) {
      if (/(ORDER|BOOKING)_/.test(must(m[1]))) {
        codes.add(must(m[1]));
        codes.add(must(m[2]));
      }
    }
    for (const m of text.matchAll(/'(NEW_PART_REQUEST|DISPUTE_REPLY)'/g)) codes.add(must(m[1]));
  }
  return [...codes].sort();
}

async function device(
  tx: Tx,
  userId: string,
  app: 'buyer' | 'partner',
  locale = 'ar',
): Promise<string> {
  await asSystem(tx);
  const [row] = await tx<{ id: string }[]>`
    insert into public.devices (user_id, app, platform, fcm_token, locale)
    values (${userId}, ${app}, 'android', ${'tok-' + crypto.randomUUID()}, ${locale}) returning id`;
  return must(row).id;
}

interface Claimed {
  id: string;
  code: string;
  app: string;
  locale: string;
  title: string;
  body: string;
  payload: Record<string, unknown>;
  attempts: number;
}

async function claim(tx: Tx): Promise<Claimed[]> {
  await asSystem(tx);
  const rows = await tx<{ c: Claimed }[]>`select c from public.notify_claim(500) c`;
  return rows.map((r) => r.c);
}

describe.skipIf(!hasDb)('notifications', () => {
  const sql: Sql = connect();
  afterAll(() => sql.end());

  it('every code the database sends has wording in Arabic and English', async () => {
    await withRollback(sql, async (tx) => {
      await asSystem(tx);
      const rows = await tx<{ code: string; locales: string[] }[]>`
        select c.code, coalesce(array_agg(t.locale order by t.locale) filter (where t.locale is not null), '{}') as locales
        from public.notification_codes c left join public.notification_templates t on t.code = c.code
        group by c.code`;
      const known = new Map(rows.map((r) => [r.code, r.locales]));
      const used = codesInMigrations();
      expect(used.filter((c) => !known.has(c))).toEqual([]);
      expect([...known.entries()].filter(([, l]) => l.join() !== 'ar,en').map(([c]) => c)).toEqual(
        [],
      );
    });
  });

  it('a push goes to each device of the right app; key alerts also get an SMS stub', async () => {
    await withRollback(sql, async (tx) => {
      const user = await createUser(tx, { meta: { phone: '0912345678' } });
      const buyerPhone = await device(tx, user, 'buyer', 'en');
      await device(tx, user, 'partner');
      await asSystem(tx);
      await tx`select public.notify(${user}, 'PAYMENT_CONFIRMED', '{"ref": "12345678"}')`;
      await tx`select public.notify_partner(${user}, 'NEW_JOB_OFFER', '{"ref": "87654321"}')`;
      const rows = await tx<
        {
          code: string;
          channel: string;
          device_id: string | null;
          status: string;
          locale: string;
        }[]
      >`
        select n.code, d.channel, d.device_id, d.status, d.locale
        from public.notification_deliveries d join public.notifications n on n.id = d.notification_id
        where n.user_id = ${user} order by n.code, d.channel`;
      expect(rows.filter((r) => r.code === 'PAYMENT_CONFIRMED')).toEqual([
        {
          code: 'PAYMENT_CONFIRMED',
          channel: 'PUSH',
          device_id: buyerPhone,
          status: 'PENDING',
          locale: 'en',
        },
        {
          code: 'PAYMENT_CONFIRMED',
          channel: 'SMS',
          device_id: null,
          status: 'STUB',
          locale: 'ar',
        },
      ]);
      expect(
        rows.filter((r) => r.code === 'NEW_JOB_OFFER').map((r) => [r.channel, r.status]),
      ).toEqual([
        ['PUSH', 'PENDING'],
        ['SMS', 'STUB'],
      ]);
    });
  });

  it('the dispatcher claims due pushes with their wording, and retries failures with backoff', async () => {
    await withRollback(sql, async (tx) => {
      const user = await createUser(tx);
      const dev = await device(tx, user, 'buyer');
      await asSystem(tx);
      await tx`select public.notify(${user}, 'ORDER_READY', '{"ref": "12345678"}')`;
      const mine = (await claim(tx)).filter((c) => c.payload.ref === '12345678');
      expect(mine).toHaveLength(1);
      const c = must(mine[0]);
      expect(c).toMatchObject({
        code: 'ORDER_READY',
        app: 'buyer',
        locale: 'ar',
        title: 'طلبك جاهز',
        attempts: 1,
      });
      expect(c.body).toContain('{ref}');
      expect((await claim(tx)).some((x) => x.id === c.id)).toBe(false);

      await tx`select public.notify_report(${tx.json([{ id: c.id, ok: false, error: 'HTTP_500' }] as never)})`;
      const [d] = await tx<{ status: string; wait: number }[]>`
        select status, extract(epoch from next_attempt_at - now())::int as wait
        from public.notification_deliveries where id = ${c.id}`;
      expect(must(d).status).toBe('PENDING');
      expect(must(d).wait).toBeGreaterThanOrEqual(55);

      // A token FCM doesn't know any more: failed, and the device is dropped.
      await tx`update public.notification_deliveries set next_attempt_at = now() where id = ${c.id}`;
      await claim(tx);
      await tx`select public.notify_report(${tx.json([{ id: c.id, ok: false, error: 'UNREGISTERED', retry: false }] as never)})`;
      const [e] = await tx<
        { status: string }[]
      >`select status from public.notification_deliveries where id = ${c.id}`;
      expect(must(e).status).toBe('FAILED');
      expect(await tx`select 1 from public.devices where id = ${dev}`).toHaveLength(0);
    });
  });

  it('only the service role may claim; apps and admins cannot', async () => {
    await withRollback(sql, async (tx) => {
      const user = await createUser(tx);
      await asUser(tx, user);
      expect((await failure(tx, (sp) => sp`select public.notify_claim(1)`)).code).toBe('42501');
    });
  });

  it('the cron kick only calls the Edge Function when something is waiting', async () => {
    await withRollback(sql, async (tx) => {
      await asSystem(tx);
      await tx`update public.notification_deliveries set status = 'STUB' where status = 'PENDING'`;
      const [r] = await tx<{ k: boolean }[]>`select public.kick_notify_dispatch() as k`;
      expect(must(r).k).toBe(false);
    });
  });
});

describe.runIf(!hasDb)('notifications (skipped)', () => {
  it.skip(skipReason, () => undefined);
});
