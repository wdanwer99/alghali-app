import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { must } from '../support/must.ts';
import { anonClient, api, apiSkipReason, Fixtures, hasApi, type TestUser } from '../support/api.ts';

/**
 * The owner's acceptance journey (brief §12), end to end over HTTP exactly as the apps call
 * it. Sign-in is email + password instead of phone + OTP (D-059); alerts are push rows plus
 * logged SMS stubs (D-061). Step 9 repeats the fitting with cash to the technician.
 */

/** A 1×1 JPEG (receipts, job photos). */
const JPEG = Uint8Array.from(
  atob(
    '/9j/4AAQSkZJRgABAQEASABIAAD/2wBDAAMCAgICAgMCAgIDAwMDBAYEBAQEBAgGBgUGCQgKCgkICQkKDA8MCgsOCwkJDRENDg8QEBEQCgwSExIQEw8QEBD/yQALCAABAAEBAREA/8wABgAQEAX/2gAIAQEAAD8A0s8g/9k=',
  ),
  (c) => c.charCodeAt(0),
);

// D-013's worked example: bulbs 12,000, labour 6,000, booking fee 2,000, commission 5% = 600,
// mobile deposit 5,000; travel comes from the distance (about a kilometre here).
const PRICE = 12000;
const LABOUR = 6000;
const FEE = 2000;
const COMMISSION = 600;
const DEPOSIT = 5000;

const KHARTOUM = 2 * 3_600_000;
const khartoum = (iso: string) => new Date(Date.parse(iso) + KHARTOUM);

interface Slots {
  technicians: { id: string; labour_sdg: number; slots?: string[] }[];
}
interface Booking {
  id: string;
  job_code: string;
  travel_fee_sdg: number;
  status: string;
}
interface Order {
  id: string;
  ref: string;
  total_sdg: number;
  payments: { id: string; method: string; status: string; amount_sdg: number }[];
  sub_orders: { id: string }[];
}
interface Hit {
  part_id: string;
  fit: string | null;
  shop_count: number;
  listings: { shop_id: string; price_sdg: number; condition: string; warranty_days: number }[];
}

describe.skipIf(!hasApi)('acceptance journey (brief §12, steps 1–9)', { timeout: 120_000 }, () => {
  let f: Fixtures;
  let admin: TestUser;
  let tech: Awaited<ReturnType<Fixtures['technician']>>;
  let shops: Awaited<ReturnType<Fixtures['shop']>>[];
  let hilux: string;
  let bulb: string;
  let decoy: string;
  let lighting: string;
  let listing: string;
  let origin: { origin_lat: number | null; origin_lng: number | null } | undefined;

  // Ahmed, from step 1 on.
  let ahmed: TestUser;
  let home: string;
  let firstJob: { booking: Booking; order: Order };

  beforeAll(async () => {
    f = new Fixtures();
    admin = await f.user();
    await f.sql`insert into public.user_roles (user_id, role) values (${admin.id}, 'ADMIN')`;
    const [v] = await f.sql<{ id: string }[]>`
      select v.id from public.vehicle_variants v join public.vehicle_models m on m.id = v.model_id
      where m.slug = 'hilux' order by v.year_from desc limit 1`;
    hilux = must(v).id;
    const [other] = await f.sql<{ id: string }[]>`
      select v.id from public.vehicle_variants v join public.vehicle_models m on m.id = v.model_id
      where m.slug <> 'hilux' order by v.year_from desc limit 1`;
    const [cat] = await f.sql<
      { id: string }[]
    >`select id from public.part_categories where slug = 'lighting'`;
    lighting = must(cat).id;

    // An admin adds two bulbs to the catalogue with their fitment (D-068): one for the
    // Hilux, one for another car.
    const parts = await admin.client
      .from('parts')
      .insert([
        { category_id: lighting, name_ar: 'لمبة أمامية H4 هالوجين', name_en: 'H4 halogen bulb' },
        { category_id: lighting, name_ar: 'لمبة أمامية H7 ليد', name_en: 'H7 LED bulb' },
      ])
      .select('id, name_en');
    expect(parts.error).toBeNull();
    bulb = must(must(parts.data).find((p) => p.name_en === 'H4 halogen bulb')).id;
    decoy = must(must(parts.data).find((p) => p.name_en === 'H7 LED bulb')).id;
    const fitment = await admin.client.from('part_fitments').insert([
      { part_id: bulb, variant_id: hilux },
      { part_id: decoy, variant_id: must(other).id },
    ]);
    expect(fitment.error).toBeNull();

    // Three shops: two sell the Hilux bulb (new and used), one the other car's bulb.
    shops = [await f.shop(), await f.shop(), await f.shop()];
    const list = async (
      s: (typeof shops)[number],
      part: string,
      price: number,
      condition: string,
      warranty: number,
    ) => {
      const r = await s.owner.client.rpc('shop_upsert_listing', {
        p_shop_id: s.shopId,
        p_part_id: part,
        p_condition: condition,
        p_stock_qty: 6,
        p_price_sdg: price,
        p_warranty_days: warranty,
      });
      expect(r.error).toBeNull();
      return (r.data as { id: string }).id;
    };
    listing = await list(must(shops[0]), bulb, PRICE, 'NEW_OEM', 30);
    await list(must(shops[1]), bulb, 9000, 'USED', 0);
    await list(must(shops[2]), decoy, 15000, 'NEW_AFTERMARKET', 90);

    tech = await f.technician();
    // Travel fees need the street's starting point (D-077); put back whatever was there.
    [origin] = await f.sql<{ origin_lat: number | null; origin_lng: number | null }[]>`
      select origin_lat, origin_lng from public.streets where slug = 'alghali'`;
    await f.sql`update public.streets set origin_lat = 15.6, origin_lng = 32.5 where slug = 'alghali'`;
  });

  afterAll(async () => {
    await f.sql`update public.streets set origin_lat = ${origin?.origin_lat ?? null}, origin_lng = ${origin?.origin_lng ?? null}
                where slug = 'alghali'`;
    await f.cleanup();
    // The listings went with the shops; now the bulbs the admin added.
    await f.admin.from('parts').delete().in('id', [bulb, decoy]);
  });

  /** "Add installation" → at Ahmed's place → the lighting technician → Thursday 4 pm. */
  async function holdThursday(): Promise<Booking> {
    const session = must((await ahmed.client.auth.getSession()).data.session);
    const res = await fetch(`${api.url}/functions/v1/booking-slots`, {
      method: 'POST',
      headers: {
        apikey: api.publishableKey,
        Authorization: `Bearer ${session.access_token}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        items: [{ listing_id: listing }],
        place: 'CUSTOMER_LOCATION',
        address_id: home,
        technician_id: tech.techId,
      }),
    });
    expect(res.status).toBe(200);
    const options = (await res.json()) as Slots;
    const mine = must(options.technicians.find((t) => t.id === tech.techId));
    expect(mine.labour_sdg).toBe(LABOUR);
    const slots = must(mine.slots);
    // The first Thursday at 4 pm Khartoum time still free (step 9 takes the next one).
    const thursday = slots.find((s) => {
      const k = khartoum(s);
      return k.getUTCDay() === 4 && k.getUTCHours() === 16 && k.getUTCMinutes() === 0;
    });
    // On a Thursday evening the next Thursday is past the 7-day window: any 4 pm will do.
    const start = must(thursday ?? slots.find((s) => khartoum(s).getUTCHours() === 16));
    const held = await ahmed.client.rpc('create_booking_hold', {
      p_technician_id: tech.techId,
      p_start_at: start,
      p_items: [{ listing_id: listing }],
      p_place: 'CUSTOMER_LOCATION',
      p_address_id: home,
    });
    expect(held.error).toBeNull();
    return held.data as Booking;
  }

  /** Ahmed uploads a receipt for the order's Bankak payment; an admin finds it and confirms. */
  async function payByBankak(order: Order): Promise<void> {
    const key = `${ahmed.id}/${crypto.randomUUID()}.jpg`;
    const up = await ahmed.client.storage
      .from('receipts')
      .upload(key, JPEG, { contentType: 'image/jpeg' });
    expect(up.error).toBeNull();
    f.trackFile('receipts', key);
    const sent = await ahmed.client.rpc('submit_bankak_receipt', {
      p_order_id: order.id,
      p_receipt_key: key,
    });
    expect(sent.error).toBeNull();
    // "Payment being checked".
    const bankak = must((sent.data as Order).payments.find((p) => p.method === 'BANKAK'));
    expect(bankak.status).toBe('RECEIPT_SUBMITTED');

    const queue = await admin.client.rpc('admin_payment_queue');
    expect(queue.error).toBeNull();
    expect((queue.data as { payment_id: string }[]).map((p) => p.payment_id)).toContain(bankak.id);
    const confirmed = await admin.client.rpc('admin_confirm_payment', {
      p_payment_id: bankak.id,
      p_txn_no: `7${Date.now()}`.slice(0, 12),
    });
    expect(confirmed.error).toBeNull();
  }

  /** The technician accepts; the shop readies the bulbs and hands them to the technician. */
  async function acceptAndHandOver(booking: Booking, order: Order): Promise<void> {
    const offers = await tech.user.client.rpc('tech_bookings', { p_scope: 'OFFERS' });
    const offer = must(
      (offers.data as { id: string; offer: { id: string } }[]).find((b) => b.id === booking.id),
    ).offer;
    expect(
      (await tech.user.client.rpc('tech_respond_offer', { p_offer_id: offer.id, p_accept: true }))
        .error,
    ).toBeNull();
    const owner = must(shops[0]).owner.client;
    const sub = must(order.sub_orders[0]).id;
    expect((await owner.rpc('shop_ack_suborder', { p_sub_order_id: sub })).error).toBeNull();
    expect((await owner.rpc('shop_mark_ready', { p_sub_order_id: sub })).error).toBeNull();
    expect((await owner.rpc('shop_hand_over', { p_sub_order_id: sub })).error).toBeNull();
  }

  /** On the way, check-in, before and after photos, Ahmed's code. */
  async function doTheJob(booking: Booking): Promise<void> {
    const t = tech.user.client;
    expect((await t.rpc('tech_en_route', { p_booking_id: booking.id })).error).toBeNull();
    expect(
      (
        await t.rpc('tech_update_location', {
          p_booking_id: booking.id,
          p_lat: 15.605,
          p_lng: 32.5,
        })
      ).error,
    ).toBeNull();
    // The job is days away: bring it to now, as if the day had come.
    await f.sql`update public.bookings set start_at = now() + interval '30 minutes', end_at = now() + interval '60 minutes',
                  block_from = now(), block_to = now() + interval '90 minutes' where id = ${booking.id}`;
    expect((await t.rpc('tech_check_in', { p_booking_id: booking.id })).error).toBeNull();
    for (const kind of ['BEFORE', 'AFTER']) {
      const key = `${booking.id}/${kind.toLowerCase()}.jpg`;
      const up = await t.storage
        .from('booking-photos')
        .upload(key, JPEG, { contentType: 'image/jpeg' });
      expect(up.error).toBeNull();
      f.trackFile('booking-photos', key);
      expect(
        (
          await t.rpc('tech_add_photo', {
            p_booking_id: booking.id,
            p_kind: kind,
            p_image_key: key,
          })
        ).error,
      ).toBeNull();
    }
    const wrong = await t.rpc('tech_complete', {
      p_booking_id: booking.id,
      p_code: booking.job_code === '0000' ? '1111' : '0000',
    });
    expect(wrong.data).toMatchObject({ ok: false });
    const done = await t.rpc('tech_complete', {
      p_booking_id: booking.id,
      p_code: booking.job_code,
    });
    expect(done.error).toBeNull();
    expect(done.data).toMatchObject({ ok: true });
  }

  async function alerts(userId: string, code: string) {
    return f.sql<{ app: string; channels: string[] }[]>`
      select n.app, array(select d.channel::text || ':' || d.status from public.notification_deliveries d
                          where d.notification_id = n.id order by d.channel) as channels
      from public.notifications n where n.user_id = ${userId} and n.code = ${code}`;
  }

  async function balances(): Promise<{ shop: number; tech: number }> {
    const r = await admin.client.rpc('admin_partner_balances');
    expect(r.error).toBeNull();
    const rows = r.data as {
      shop_id: string | null;
      technician_id: string | null;
      balance_sdg: number;
    }[];
    return {
      shop: Number(rows.find((x) => x.shop_id === must(shops[0]).shopId)?.balance_sdg ?? 0),
      tech: Number(rows.find((x) => x.technician_id === tech.techId)?.balance_sdg ?? 0),
    };
  }

  it('1. Ahmed signs up and adds his Toyota Hilux to My Garage', async () => {
    const client = anonClient();
    const email = `ahmed-${crypto.randomUUID().slice(0, 8)}@test.alghali.invalid`;
    const password = `Ahmed-${crypto.randomUUID().slice(0, 8)}9`;
    const signUp = await client.auth.signUp({
      email,
      password,
      options: { data: { display_name: 'أحمد', phone: '0912345678', locale: 'ar' } },
    });
    expect(signUp.error).toBeNull();
    const id = must(signUp.data.user).id;
    f.track(id);
    // Later he signs in on his phone, which registers for push.
    await client.auth.signOut();
    const signIn = await client.auth.signInWithPassword({ email, password });
    expect(signIn.error).toBeNull();
    ahmed = { id, email, password, client };
    expect(
      (
        await client.rpc('register_device', {
          p_app: 'buyer',
          p_platform: 'android',
          p_fcm_token: `journey-${crypto.randomUUID()}`,
          p_app_build: 4,
          p_locale: 'ar',
        })
      ).error,
    ).toBeNull();

    const car = await client
      .from('garage_vehicles')
      .insert({ variant_id: hilux })
      .select('is_default')
      .single();
    expect(car.error).toBeNull();
    expect(car.data).toEqual({ is_default: true }); // his first car is the one search uses

    const address = await client
      .from('addresses')
      .insert({ label: 'البيت', description_ar: 'الرياض، قرب الصيدلية', lat: 15.61, lng: 32.5 })
      .select('id')
      .single();
    expect(address.error).toBeNull();
    home = must(address.data).id;
  });

  it('2. "لمبات" finds only bulbs that fit, from several shops, with price, condition and warranty', async () => {
    const r = await ahmed.client.rpc('search_parts', {
      p_q: 'لمبات',
      p_variant_id: hilux,
      p_only_fits: true,
    });
    expect(r.error).toBeNull();
    const hits = r.data as Hit[];
    expect(hits.every((h) => h.fit === 'FITS')).toBe(true);
    expect(hits.map((h) => h.part_id)).not.toContain(decoy);
    const h4 = must(hits.find((h) => h.part_id === bulb));
    expect(h4.shop_count).toBe(2);
    expect(h4.listings.map((l) => [l.price_sdg, l.condition, l.warranty_days]).sort()).toEqual([
      [12000, 'NEW_OEM', 30],
      [9000, 'USED', 0],
    ]);

    // Without the "only what fits" filter, the other car's bulb still stays hidden for him.
    const all = await ahmed.client.rpc('search_parts', { p_q: 'لمبات', p_variant_id: hilux });
    expect((all.data as Hit[]).map((h) => h.part_id)).not.toContain(decoy);
  });

  it('3–4. cart, a fitting at his place on Thursday at 4 pm, Bankak with the account and his reference', async () => {
    const cart = await ahmed.client
      .from('cart_items')
      .insert({ listing_id: listing, qty: 1, seen_price_sdg: PRICE })
      .select('id');
    expect(cart.error).toBeNull();

    const booking = await holdThursday();
    expect(booking.status).toBe('HELD');
    expect(booking.travel_fee_sdg).toBeGreaterThan(0);

    const settings = await ahmed.client.rpc('public_settings');
    const s = settings.data as Record<string, unknown>;
    expect(s.bankak_account_number).toBeTruthy();
    expect(s.bankak_account_name).toBeTruthy();

    const placed = await ahmed.client.rpc('checkout', {
      p_items: [{ listing_id: listing, qty: 1, seen_price_sdg: PRICE }],
      p_method: 'BANKAK',
      p_booking_id: booking.id,
    });
    expect(placed.error).toBeNull();
    const order = placed.data as Order;
    expect(order.ref).toMatch(/^\d{8}$/); // what he writes in the Bankak note (D-016)
    expect(order.total_sdg).toBe(PRICE + LABOUR + booking.travel_fee_sdg + FEE);
    firstJob = { booking, order };
  });

  it('5. the admin confirms; push and SMS (stub); the technician accepts and the shop hands over', async () => {
    const { booking, order } = firstJob;
    await payByBankak(order);
    // A push to his phone (the dispatcher may already have tried the made-up token) and
    // the SMS stub, both logged against the alert.
    const [paid] = await alerts(ahmed.id, 'PAYMENT_CONFIRMED');
    expect(must(paid).app).toBe('buyer');
    expect(must(paid).channels).toHaveLength(2);
    expect(must(paid).channels[0]).toMatch(/^PUSH:/);
    expect(must(paid).channels[1]).toBe('SMS:STUB');
    expect((await alerts(tech.user.id, 'NEW_JOB_OFFER')).map((a) => a.app)).toEqual(['partner']);
    expect((await alerts(must(shops[0]).owner.id, 'NEW_ORDER')).length).toBe(1);
    await acceptAndHandOver(booking, order);
    const [b] = await f.sql<
      { status: string }[]
    >`select status from public.bookings where id = ${booking.id}`;
    expect(must(b).status).toBe('ACCEPTED');
    const [sub] = await f.sql<{ status: string }[]>`
      select status from public.sub_orders where id = ${must(order.sub_orders[0]).id}`;
    expect(must(sub).status).toBe('HANDED_TO_TECHNICIAN');
  });

  it('6. reminders the day before and an hour before, once each', async () => {
    const { booking } = firstJob;
    await f.sql`update public.bookings set start_at = now() + interval '20 hours', end_at = now() + interval '21 hours',
                  block_from = now() + interval '20 hours', block_to = now() + interval '21 hours' where id = ${booking.id}`;
    await f.sql`select public.send_booking_reminders()`;
    await f.sql`select public.send_booking_reminders()`;
    await f.sql`update public.bookings set start_at = now() + interval '40 minutes', end_at = now() + interval '100 minutes',
                  block_from = now() + interval '40 minutes', block_to = now() + interval '100 minutes' where id = ${booking.id}`;
    await f.sql`select public.send_booking_reminders()`;
    expect((await alerts(ahmed.id, 'BOOKING_REMINDER_DAY')).length).toBe(1);
    expect((await alerts(ahmed.id, 'BOOKING_REMINDER_HOUR')).length).toBe(1);
    expect((await alerts(tech.user.id, 'BOOKING_REMINDER_HOUR')).map((a) => a.app)).toEqual([
      'partner',
    ]);
  });

  it('7. on the way, check-in, before and after photos, his code: the job is done', async () => {
    const { booking } = firstJob;
    await doTheJob(booking);
    const detail = await ahmed.client.rpc('booking_detail', { p_booking_id: booking.id });
    expect(detail.data).toMatchObject({ status: 'COMPLETED' });
    expect((detail.data as { photos: unknown[] }).photos).toHaveLength(2);
  });

  it('8. he rates the shop and the technician; the ledger has the sale, commission, booking fee and payouts', async () => {
    const { booking, order } = firstJob;
    const sub = must(order.sub_orders[0]).id;
    expect(
      (await ahmed.client.rpc('create_review', { p_rating: 5, p_booking_id: booking.id })).error,
    ).toBeNull();
    expect(
      (await ahmed.client.rpc('create_review', { p_rating: 4, p_sub_order_id: sub })).error,
    ).toBeNull();

    const journals = await f.sql<{ kind: string; credit: string }[]>`
      select j.kind, sum(e.amount_sdg) filter (where e.amount_sdg < 0) as credit
      from public.ledger_journals j join public.ledger_entries e on e.journal_id = j.id
      where j.order_id = ${order.id} or j.booking_id = ${booking.id}
      group by j.id, j.kind order by j.kind`;
    const amount = (kind: string) =>
      journals.filter((j) => j.kind === kind).map((j) => -Number(j.credit));
    expect(amount('SALE')).toEqual([PRICE]);
    expect(amount('COMMISSION')).toEqual([COMMISSION]);
    expect(amount('BOOKING_FEE')).toEqual([FEE]);
    expect(amount('LABOUR')).toEqual([LABOUR]);
    expect(amount('TRAVEL_FEE')).toEqual([booking.travel_fee_sdg]);
    const [held] = await f.sql<{ b: string }[]>`
      select coalesce(sum(e.amount_sdg), 0) as b from public.ledger_entries e
      join public.ledger_journals j on j.id = e.journal_id join public.ledger_accounts a on a.id = e.account_id
      where a.code = 'BUYER_FUNDS_HELD' and j.order_id = ${order.id}`;
    expect(Number(must(held).b)).toBe(0);

    // What the platform will pay out: the shop its sale less commission, the technician
    // labour and travel. The shop sees the same on its statement.
    expect(await balances()).toEqual({
      shop: PRICE - COMMISSION,
      tech: LABOUR + booking.travel_fee_sdg,
    });
    const statement = await must(shops[0]).owner.client.rpc('shop_statement', {
      p_shop_id: must(shops[0]).shopId,
    });
    expect(
      (statement.data as { lines: { kind: string; amount_sdg: number }[] }).lines
        .map((l) => [l.kind, l.amount_sdg])
        .sort(),
    ).toEqual([
      ['COMMISSION', -COMMISSION],
      ['SALE', PRICE],
    ]);
  });

  it('9. cash to the technician: only the deposit by Bankak, the rest collected in cash, commission netted', async () => {
    const before = await balances();
    const booking = await holdThursday();
    const placed = await ahmed.client.rpc('checkout', {
      p_items: [{ listing_id: listing, qty: 1, seen_price_sdg: PRICE }],
      p_method: 'CASH',
      p_booking_id: booking.id,
    });
    expect(placed.error).toBeNull();
    const order = placed.data as Order;
    const total = PRICE + LABOUR + booking.travel_fee_sdg + FEE;
    expect(order.payments.map((p) => [p.method, p.amount_sdg]).sort()).toEqual([
      ['BANKAK', DEPOSIT],
      ['CASH', total - DEPOSIT],
    ]);

    await payByBankak(order);
    await acceptAndHandOver(booking, order);
    await doTheJob(booking);

    const cash = await f.sql<{ amount_sdg: string }[]>`
      select amount_sdg from public.payments
      where order_id = ${order.id} and method = 'CASH' and status = 'COLLECTED'`;
    expect(cash.map((c) => Number(c.amount_sdg))).toEqual([total - DEPOSIT]);
    // The shop was paid for the bulbs in cash at hand-over, so it owes the commission, which
    // comes off its next payout; the technician keeps what he collected and is owed the
    // deposit less the booking fee (D-013).
    expect(await balances()).toEqual({
      shop: before.shop - COMMISSION,
      tech: before.tech + DEPOSIT - FEE,
    });
    const [unbalanced] = await f.sql<{ n: string }[]>`
      select count(*) as n from (
        select j.id from public.ledger_journals j join public.ledger_entries e on e.journal_id = j.id
        where j.order_id = ${order.id} or j.booking_id = ${booking.id}
        group by j.id having sum(e.amount_sdg) <> 0) x`;
    expect(Number(must(unbalanced).n)).toBe(0);
  });
});

describe.runIf(!hasApi)('acceptance journey (skipped)', () => {
  it.skip(apiSkipReason, () => undefined);
});
