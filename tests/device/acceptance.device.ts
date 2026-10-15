import { spawnSync } from 'node:child_process';
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { must } from '../support/must.ts';
import { api, Fixtures, hasApi, type TestUser } from '../support/api.ts';

/**
 * The acceptance journey (brief §12) on a phone, against alghali-test with fresh accounts
 * (`pnpm journey:e2e [-- -d <device>]`, an emulator running). The buyer app does steps
 * 1–4 and 8, the partner app steps 5 and 7, and this script does what happens elsewhere:
 * the admin's confirmation, the reminders (step 6), and the checks on the server. Steps
 * 1–9 are also tested over HTTP in tests/api/journey.test.ts; this proves the apps do them.
 * Everything it creates is deleted afterwards.
 */

const root = join(import.meta.dirname, '../..');
const PART = 'لمبة أمامية H4 هالوجين';
const DECOY = 'لمبة أمامية H7 ليد';
const TECH = 'الفني عمر';
const PRICE = 12000;
const LABOUR = 6000;
const COMMISSION = 600;

/** The emulator or phone (`-d` of `pnpm journey:e2e`); the only one attached otherwise. */
const device = process.env.E2E_DEVICE;
const adb = join(process.env.LOCALAPPDATA ?? '', 'Android/Sdk/platform-tools/adb');

/** Runs one device test with [defines] (written to a private file, never on a command line). */
function runOnDevice(
  appName: 'buyer' | 'partner',
  only: string,
  defines: Record<string, string>,
): void {
  const app = join(root, 'apps', appName);
  // A fresh start: signed out, the welcome screen first.
  spawnSync(adb, [
    ...(device ? ['-s', device] : []),
    'shell',
    'pm',
    'clear',
    `sd.alghali.${appName}`,
  ]);
  const base = JSON.parse(readFileSync(join(app, 'env', 'dev.json'), 'utf8')) as Record<
    string,
    string
  >;
  const dir = mkdtempSync(join(tmpdir(), 'alghali-journey-'));
  const file = join(dir, 'defines.json');
  try {
    writeFileSync(
      file,
      JSON.stringify({
        ...base,
        SUPABASE_URL: api.url,
        SUPABASE_PUBLISHABLE_KEY: api.publishableKey,
        ...defines,
      }),
      { mode: 0o600 },
    );
    const r = spawnSync(
      'flutter',
      [
        'test',
        'integration_test/acceptance_test.dart',
        '--plain-name',
        only,
        `--dart-define-from-file=${file}`,
        ...(device ? ['-d', device] : []),
      ],
      { cwd: app, stdio: 'inherit', shell: true },
    );
    expect(r.status, `${appName} device test "${only}"`).toBe(0);
  } finally {
    rmSync(dir, { recursive: true, force: true });
    // The test build lists the integration_test plugin here; a release build that reuses
    // the file fails, and Flutter writes it again when it is missing.
    rmSync(
      join(app, 'android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java'),
      { force: true },
    );
  }
}

/** Waits for the server to show what the app did (the outbox sends a moment later). */
async function eventually<T>(read: () => Promise<T>, ok: (v: T) => boolean): Promise<T> {
  for (let i = 0; ; i++) {
    const v = await read();
    if (ok(v) || i === 30) return v;
    await new Promise((r) => setTimeout(r, 1000));
  }
}

describe.skipIf(!hasApi)('acceptance journey on a phone', () => {
  let f: Fixtures;
  let admin: TestUser;
  let ahmed: TestUser;
  let shopA: Awaited<ReturnType<Fixtures['shop']>>;
  let tech: Awaited<ReturnType<Fixtures['technician']>>;
  let parts: string[] = [];
  let origin: { origin_lat: number | null; origin_lng: number | null } | undefined;
  let order: { id: string; ref: string; booking_id: string; sub_order_id: string };

  beforeAll(async () => {
    f = new Fixtures();
    admin = await f.user();
    await f.sql`insert into public.user_roles (user_id, role) values (${admin.id}, 'ADMIN')`;
    ahmed = await f.user({ display_name: 'أحمد', phone: '0912345678' });
    await f.sql`insert into public.addresses (user_id, label, description_ar, lat, lng)
                values (${ahmed.id}, 'البيت', 'الرياض، قرب الصيدلية', 15.61, 32.5)`;

    // The bulbs: one fits every Hilux, the other another car.
    const [cat] = await f.sql<{ id: string }[]>`
      select id from public.part_categories where slug = 'lighting'`;
    const made = await f.sql<{ id: string; name_ar: string }[]>`
      insert into public.parts (category_id, name_ar, name_en)
      values (${must(cat).id}, ${PART}, 'H4 halogen bulb'), (${must(cat).id}, ${DECOY}, 'H7 LED bulb')
      returning id, name_ar`;
    parts = made.map((p) => p.id);
    const bulb = must(made.find((p) => p.name_ar === PART)).id;
    const decoy = must(made.find((p) => p.name_ar === DECOY)).id;
    await f.sql`
      insert into public.part_fitments (part_id, variant_id)
      select ${bulb}, v.id from public.vehicle_variants v join public.vehicle_models m on m.id = v.model_id
      where m.slug = 'hilux'`;
    await f.sql`
      insert into public.part_fitments (part_id, variant_id)
      select ${decoy}, v.id from public.vehicle_variants v join public.vehicle_models m on m.id = v.model_id
      where m.slug = 'corolla'`;

    // Two shops sell the Hilux bulb, a third the other one.
    shopA = await f.shop();
    const shopB = await f.shop();
    const shopC = await f.shop();
    for (const [s, part, price, condition, warranty] of [
      [shopA, bulb, PRICE, 'NEW_OEM', 30],
      [shopB, bulb, 14000, 'NEW_AFTERMARKET', 0],
      [shopC, decoy, 15000, 'NEW_OEM', 90],
    ] as const) {
      const r = await s.owner.client.rpc('shop_upsert_listing', {
        p_shop_id: s.shopId,
        p_part_id: part,
        p_condition: condition,
        p_stock_qty: 6,
        p_price_sdg: price,
        p_warranty_days: warranty,
      });
      expect(r.error).toBeNull();
    }

    tech = await f.technician();
    [origin] = await f.sql<{ origin_lat: number | null; origin_lng: number | null }[]>`
      select origin_lat, origin_lng from public.streets where slug = 'alghali'`;
    await f.sql`update public.streets set origin_lat = 15.6, origin_lng = 32.5 where slug = 'alghali'`;
  });

  /** What the partner app's runs need; the job code is the one Ahmed would read out. */
  async function partnerDefines(): Promise<Record<string, string>> {
    const [code] = await f.sql<{ code: string }[]>`
      select code from public.booking_codes where booking_id = ${order.booking_id}`;
    return {
      E2E_TECH_EMAIL: tech.user.email,
      E2E_TECH_PASSWORD: tech.user.password,
      E2E_SHOP_EMAIL: shopA.owner.email,
      E2E_SHOP_PASSWORD: shopA.owner.password,
      E2E_ORDER_REF: order.ref,
      E2E_JOB_CODE: must(code).code,
      E2E_PART_NAME: PART,
    };
  }

  afterAll(async () => {
    await f.sql`update public.streets set origin_lat = ${origin?.origin_lat ?? null}, origin_lng = ${origin?.origin_lng ?? null}
                where slug = 'alghali'`;
    await f.cleanup();
    if (parts.length) await f.admin.from('parts').delete().in('id', parts);
  });

  it('1–4 in the buyer app: garage, search, a fitting at home on Thursday, Bankak', () => {
    runOnDevice('buyer', 'order', {
      E2E_EMAIL: ahmed.email,
      E2E_PASSWORD: ahmed.password,
      E2E_PART_NAME: PART,
      E2E_DECOY_NAME: DECOY,
      E2E_TECH_NAME: TECH,
      E2E_TXN: `8${Date.now()}`.slice(0, 12),
    });
  });

  it('the order reached the server, paid by Bankak and waiting for the check', async () => {
    const [o] = await f.sql<
      {
        id: string;
        ref: string;
        booking_id: string;
        sub_order_id: string;
        status: string;
        start_at: Date;
      }[]
    >`
      select o.id, o.ref, b.id as booking_id, s.id as sub_order_id, p.status, b.start_at
      from public.orders o
      join public.bookings b on b.order_id = o.id
      join public.sub_orders s on s.order_id = o.id
      join public.payments p on p.order_id = o.id and p.method = 'BANKAK'
      where o.buyer_id = ${ahmed.id}`;
    expect(must(o).status).toBe('RECEIPT_SUBMITTED');
    // Thursday at 4 pm Khartoum time (or tomorrow at 4 pm on a Thursday).
    expect(new Date(must(o).start_at.getTime() + 2 * 3_600_000).getUTCHours()).toBe(16);
    const [garage] = await f.sql<{ model: string }[]>`
      select m.slug as model from public.garage_vehicles g join public.vehicle_variants v on v.id = g.variant_id
      join public.vehicle_models m on m.id = v.model_id where g.user_id = ${ahmed.id}`;
    expect(must(garage).model).toBe('hilux');
    order = must(o);
  });

  it('5. the admin confirms; the technician accepts in the partner app', async () => {
    const [pay] = await f.sql<{ id: string }[]>`
      select id from public.payments where order_id = ${order.id} and method = 'BANKAK'`;
    const confirmed = await admin.client.rpc('admin_confirm_payment', {
      p_payment_id: must(pay).id,
    });
    expect(confirmed.error).toBeNull();
    runOnDevice('partner', 'offer', await partnerDefines());
    const [b] = await f.sql<{ status: string }[]>`
      select status from public.bookings where id = ${order.booking_id}`;
    expect(must(b).status).toBe('ACCEPTED');
  });

  it('6. reminders a day and an hour before', async () => {
    const move = (from: string, to: string) => f.sql`
      update public.bookings set start_at = now() + ${from}::interval, end_at = now() + ${to}::interval,
             block_from = now() + ${from}::interval, block_to = now() + ${to}::interval
      where id = ${order.booking_id}`;
    await move('20 hours', '21 hours');
    await f.sql`select public.send_booking_reminders()`;
    await move('40 minutes', '100 minutes');
    await f.sql`select public.send_booking_reminders()`;
    const codes = await f.sql<{ code: string }[]>`
      select code from public.notifications where user_id = ${ahmed.id} order by created_at`;
    expect(codes.map((c) => c.code)).toEqual(
      expect.arrayContaining([
        'PAYMENT_CONFIRMED',
        'BOOKING_REMINDER_DAY',
        'BOOKING_REMINDER_HOUR',
      ]),
    );
    // The day has come: the job starts in half an hour.
    await move('30 minutes', '60 minutes');
  });

  it('5 and 7 in the partner app: the shop hands over; on the way, photos, his code', async () => {
    runOnDevice('partner', 'jobday', await partnerDefines());
    const [b] = await f.sql<{ steps: string[]; photos: string }[]>`
      select array(select e.to_status::text from public.booking_events e
                   where e.booking_id = b.id order by e.id) as steps,
             (select count(*) from public.booking_photos p where p.booking_id = b.id) as photos
      from public.bookings b where b.id = ${order.booking_id}`;
    expect(must(b).steps.slice(-4)).toEqual(['ACCEPTED', 'EN_ROUTE', 'IN_PROGRESS', 'COMPLETED']);
    expect(Number(must(b).photos)).toBe(2);
  });

  it('8 in the buyer app: he rates both; the money is right', async () => {
    runOnDevice('buyer', 'rate', {
      E2E_EMAIL: ahmed.email,
      E2E_PASSWORD: ahmed.password,
      E2E_ORDER_REF: order.ref,
    });
    const reviews = await eventually(
      () => f.sql<{ rating: number }[]>`
        select rating from public.reviews
        where booking_id = ${order.booking_id} or sub_order_id = ${order.sub_order_id}`,
      (r) => r.length === 2,
    );
    expect(reviews.map((r) => r.rating)).toEqual([5, 5]);
    const [m] = await f.sql<{ shop: string; tech: string; travel: string }[]>`
      select public.shop_balance(${shopA.shopId}) as shop, public.tech_balance(${tech.techId}) as tech,
             (select travel_fee_sdg from public.bookings where id = ${order.booking_id}) as travel`;
    expect(Number(must(m).shop)).toBe(PRICE - COMMISSION);
    expect(Number(must(m).tech)).toBe(LABOUR + Number(must(m).travel));
  });
});
