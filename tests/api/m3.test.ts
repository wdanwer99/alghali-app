import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { must } from '../support/must.ts';
import { anonClient, api, apiSkipReason, Fixtures, hasApi } from '../support/api.ts';

/** A 1×1 JPEG for the booking-photos bucket. */
const JPEG = Uint8Array.from(
  atob(
    '/9j/4AAQSkZJRgABAQEASABIAAD/2wBDAAMCAgICAgMCAgIDAwMDBAYEBAQEBAgGBgUGCQgKCgkICQkKDA8MCgsOCwkJDRENDg8QEBEQCgwSExIQEw8QEBD/yQALCAABAAEBAREA/8wABgAQEAX/2gAIAQEAAD8A0s8g/9k=',
  ),
  (c) => c.charCodeAt(0),
);

/** Khartoum wall-clock time `days` from today, as ISO UTC. */
function khartoumAt(hour: number, days = 1): string {
  const k = new Date(Date.now() + 2 * 3_600_000);
  return new Date(
    Date.UTC(k.getUTCFullYear(), k.getUTCMonth(), k.getUTCDate() + days, hour) - 2 * 3_600_000,
  ).toISOString();
}

interface Options {
  duration_min: number;
  booking_fee_sdg: number;
  technicians: { id: string; labour_sdg: number; slots?: string[]; next_slot: string | null }[];
  any: { start: string; technician_id: string }[];
}

async function slotsFor(
  body: Record<string, unknown>,
  authorization?: string,
): Promise<{ status: number; json: Options }> {
  const res = await fetch(`${api.url}/functions/v1/booking-slots`, {
    method: 'POST',
    headers: {
      apikey: api.publishableKey,
      'Content-Type': 'application/json',
      ...(authorization ? { Authorization: authorization } : {}),
    },
    body: JSON.stringify(body),
  });
  return { status: res.status, json: (await res.json()) as Options };
}

describe.skipIf(!hasApi)('M3 over HTTP: fittings', () => {
  let f: Fixtures;
  let tech: Awaited<ReturnType<Fixtures['technician']>>;
  let lighting: string;
  let origin: { origin_lat: number | null; origin_lng: number | null } | undefined;

  beforeAll(async () => {
    f = new Fixtures();
    tech = await f.technician();
    const [cat] = await f.sql<
      { id: string }[]
    >`select id from public.part_categories where slug = 'lighting'`;
    lighting = must(cat).id;
    // Travel fees need the street's starting point (D-077); put back whatever was there.
    [origin] = await f.sql<{ origin_lat: number | null; origin_lng: number | null }[]>`
      select origin_lat, origin_lng from public.streets where slug = 'alghali'`;
    await f.sql`update public.streets set origin_lat = 15.6, origin_lng = 32.5 where slug = 'alghali'`;
  });
  afterAll(async () => {
    await f.sql`update public.streets set origin_lat = ${origin?.origin_lat ?? null}, origin_lng = ${origin?.origin_lng ?? null}
                where slug = 'alghali'`;
    await f.cleanup();
  });

  it('a guest sees technicians and slots; holding needs an account', async () => {
    const { status, json } = await slotsFor({
      items: [{ category_id: lighting, description: 'لمبات' }],
      place: 'BAY',
    });
    expect(status).toBe(200);
    expect(json.duration_min).toBe(30);
    const mine = must(json.technicians.find((t) => t.id === tech.techId));
    expect(mine.labour_sdg).toBe(6000);
    expect(mine.next_slot).not.toBeNull();
    expect(json.any.length).toBeGreaterThan(0);

    const guest = await anonClient().rpc('create_booking_hold', {
      p_technician_id: tech.techId,
      p_start_at: khartoumAt(12, 3),
      p_items: [{ category_id: lighting, description: 'لمبات' }],
      p_place: 'BAY',
    });
    expect(guest.error).not.toBeNull();
  });

  it('book, pay, fit and rate: the whole fitting journey (acceptance steps 3–8)', async () => {
    const buyer = await f.user({ phone: '0912345678', display_name: 'أحمد' });
    const shop = await f.shop();
    const admin = await f.user();
    await f.sql`insert into public.user_roles (user_id, role) values (${admin.id}, 'ADMIN')`;
    const listing = await shop.owner.client.rpc('shop_upsert_listing', {
      p_shop_id: shop.shopId,
      p_condition: 'NEW_OEM',
      p_stock_qty: 4,
      p_price_sdg: 12000,
      p_new_part: { name_ar: 'لمبات H4', category_id: lighting },
    });
    expect(listing.error).toBeNull();
    const listingId = (listing.data as { id: string }).id;
    const address = await buyer.client
      .from('addresses')
      .insert({ label: 'البيت', lat: 15.61, lng: 32.5 })
      .select('id')
      .single();
    expect(address.error).toBeNull();

    // 3. Technician and slot, held.
    const session = must((await buyer.client.auth.getSession()).data.session);
    const options = await slotsFor(
      {
        items: [{ listing_id: listingId }],
        place: 'CUSTOMER_LOCATION',
        address_id: must(address.data).id,
        technician_id: tech.techId,
      },
      `Bearer ${session.access_token}`,
    );
    expect(options.status).toBe(200);
    const slots = must(options.json.technicians.find((t) => t.id === tech.techId)?.slots);
    const start = must(slots.find((s) => Date.parse(s) >= Date.parse(khartoumAt(9, 3))));
    const held = await buyer.client.rpc('create_booking_hold', {
      p_technician_id: tech.techId,
      p_start_at: start,
      p_items: [{ listing_id: listingId }],
      p_place: 'CUSTOMER_LOCATION',
      p_address_id: must(address.data).id,
    });
    expect(held.error).toBeNull();
    const booking = held.data as { id: string; job_code: string; travel_fee_sdg: number };

    // 4. Bankak checkout and the transfer number.
    const placed = await buyer.client.rpc('checkout', {
      p_items: [{ listing_id: listingId, qty: 1, seen_price_sdg: 12000 }],
      p_method: 'BANKAK',
      p_booking_id: booking.id,
    });
    expect(placed.error).toBeNull();
    const order = placed.data as {
      id: string;
      total_sdg: number;
      payments: { id: string }[];
      sub_orders: { id: string }[];
    };
    expect(order.total_sdg).toBe(12000 + 6000 + booking.travel_fee_sdg + 2000);
    expect(
      (
        await buyer.client.rpc('submit_bankak_receipt', {
          p_order_id: order.id,
          p_txn_no: `5${Date.now()}`.slice(0, 12),
        })
      ).error,
    ).toBeNull();

    // 5. Admin confirms; the technician accepts; the shop hands the part over.
    expect(
      (
        await admin.client.rpc('admin_confirm_payment', {
          p_payment_id: must(order.payments[0]).id,
        })
      ).error,
    ).toBeNull();
    const offers = await tech.user.client.rpc('tech_bookings', { p_scope: 'OFFERS' });
    const offer = must(
      (offers.data as { id: string; offer: { id: string } }[]).find((b) => b.id === booking.id),
    ).offer;
    expect(
      (await tech.user.client.rpc('tech_respond_offer', { p_offer_id: offer.id, p_accept: true }))
        .error,
    ).toBeNull();
    const sub = must(order.sub_orders[0]).id;
    expect(
      (await shop.owner.client.rpc('shop_mark_ready', { p_sub_order_id: sub })).error,
    ).toBeNull();
    expect(
      (await shop.owner.client.rpc('shop_hand_over', { p_sub_order_id: sub })).error,
    ).toBeNull();

    // 7. On the way (the buyer sees where), check-in, photos, the buyer's code.
    expect(
      (await tech.user.client.rpc('tech_en_route', { p_booking_id: booking.id })).error,
    ).toBeNull();
    expect(
      (
        await tech.user.client.rpc('tech_update_location', {
          p_booking_id: booking.id,
          p_lat: 15.605,
          p_lng: 32.5,
        })
      ).error,
    ).toBeNull();
    const seen = await buyer.client
      .from('tech_locations')
      .select('lat')
      .eq('booking_id', booking.id);
    expect(seen.data).toHaveLength(1);
    await f.sql`update public.bookings set start_at = now() + interval '30 minutes', end_at = now() + interval '60 minutes',
                  block_from = now(), block_to = now() + interval '90 minutes' where id = ${booking.id}`;
    expect(
      (await tech.user.client.rpc('tech_check_in', { p_booking_id: booking.id })).error,
    ).toBeNull();
    const key = `${booking.id}/before.jpg`;
    const upload = await tech.user.client.storage
      .from('booking-photos')
      .upload(key, JPEG, { contentType: 'image/jpeg' });
    expect(upload.error).toBeNull();
    f.trackFile('booking-photos', key);
    expect(
      (
        await tech.user.client.rpc('tech_add_photo', {
          p_booking_id: booking.id,
          p_kind: 'BEFORE',
          p_image_key: key,
        })
      ).error,
    ).toBeNull();
    const stranger = await f.user();
    expect(
      (await stranger.client.storage.from('booking-photos').download(key)).error,
    ).not.toBeNull();
    expect((await buyer.client.storage.from('booking-photos').download(key)).error).toBeNull();
    const done = await tech.user.client.rpc('tech_complete', {
      p_booking_id: booking.id,
      p_code: booking.job_code,
    });
    expect(done.error).toBeNull();
    expect((done.data as { ok: boolean }).ok).toBe(true);

    // 8. Ratings, and the money: shop 11,400, technician labour + travel, nothing left held.
    expect(
      (await buyer.client.rpc('create_review', { p_rating: 5, p_booking_id: booking.id })).error,
    ).toBeNull();
    expect(
      (await buyer.client.rpc('create_review', { p_rating: 4, p_sub_order_id: sub })).error,
    ).toBeNull();
    const [m] = await f.sql<{ shop: string; tech: string; held: string }[]>`
      select public.shop_balance(${shop.shopId}) as shop, public.tech_balance(${tech.techId}) as tech,
             (select coalesce(sum(e.amount_sdg), 0) from public.ledger_entries e
              join public.ledger_journals j on j.id = e.journal_id join public.ledger_accounts a on a.id = e.account_id
              where a.code = 'BUYER_FUNDS_HELD' and j.order_id = ${order.id}) as held`;
    expect(Number(must(m).shop)).toBe(11400);
    expect(Number(must(m).tech)).toBe(6000 + booking.travel_fee_sdg);
    expect(Number(must(m).held)).toBe(0);
  });

  it('notify-dispatch: refuses strangers; with the Vault token it works the queue (Firebase or stubs)', async () => {
    const res = await fetch(`${api.url}/functions/v1/notify-dispatch`, {
      method: 'POST',
      headers: { Authorization: 'Bearer nope' },
    });
    expect(res.status).toBe(401);
    const [secret] = await f.sql<{ token: string }[]>`
      select decrypted_secret as token from vault.decrypted_secrets where name = 'notify_dispatch_token'`;
    if (!secret) return; // pnpm notify:setup hasn't been run for this project (CI's local stack)
    const user = await f.user();
    await f.sql`insert into public.devices (user_id, app, platform, fcm_token)
                values (${user.id}, 'buyer', 'android', ${'tok-' + crypto.randomUUID()})`;
    await f.sql`select public.notify(${user.id}, 'ORDER_READY', '{"ref": "11112222"}')`;
    const ok = await fetch(`${api.url}/functions/v1/notify-dispatch`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${secret.token}` },
    });
    expect(ok.status).toBe(200);
    const [d] = await f.sql<{ status: string; last_error: string | null }[]>`
      select d.status, d.last_error from public.notification_deliveries d
      join public.notifications n on n.id = d.notification_id
      where n.user_id = ${user.id} and d.channel = 'PUSH'`;
    // Without Firebase the push is a stub; with it, Google signs the dispatcher in and then
    // refuses the made-up device token, so it fails for good without retrying.
    expect([
      ['STUB', 'NO_FCM_ACCOUNT'],
      ['FAILED', 'INVALID_ARGUMENT'],
    ]).toContainEqual([must(d).status, must(d).last_error]);
  });
});

describe.runIf(!hasApi)('M3 over HTTP (skipped)', () => {
  it.skip(apiSkipReason, () => undefined);
});
