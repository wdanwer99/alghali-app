// `pnpm partner:e2e [-- -d <device>]`: the partner's happy path on a running emulator or
// phone, against alghali-dev (apps/partner/integration_test/journey_test.dart).
//   1. As a demo buyer: a cash order at the demo shop (Al-Nour), and a fitting at its bay
//      with the demo technician (Omar), so both have something new waiting.
//   2. The device test: the shop accepts the order and marks it ready; the technician
//      accepts the job.
//   3. Always: an admin cancels the order and the fitting, and the shop is open again.
// The accounts come from .env through a temporary defines file, so the password never
// shows on a command line. Needs the demo data (pnpm db:seed:dev).
import { spawnSync } from 'node:child_process';
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { createClient } from '@supabase/supabase-js';
import { readEnvFile, supabaseTarget } from './lib/env.mjs';
import { root } from './lib/paths.mjs';

const env = readEnvFile(join(root, '.env')) ?? {};
const dev = supabaseTarget(env, 'DEV');
if (!env.DEMO_PASSWORD || !dev.url || !dev.publishableKey) {
  console.error('DEMO_PASSWORD and the dev project must be set in .env (pnpm db:seed:dev).');
  process.exit(1);
}
const SHOP = 'owner.nour@demo.alghali.invalid';
const TECH = 'tech.omar@demo.alghali.invalid';
const BUYER = 'buyer.omer@demo.alghali.invalid';
const ADMIN = 'admin@demo.alghali.invalid';

const must = ({ data, error }, what) => {
  if (error) throw new Error(`${what}: ${error.message}`);
  return data;
};
// A few tries: a dropped connection must not leave the test's order behind.
const signIn = async (email) => {
  const client = createClient(dev.url, dev.publishableKey, { auth: { persistSession: false } });
  for (let i = 1; ; i++) {
    const { error } = await client.auth.signInWithPassword({ email, password: env.DEMO_PASSWORD });
    if (!error) return client;
    if (i === 4) throw new Error(`${email}: ${error.message}`);
    await new Promise((r) => setTimeout(r, 3000));
  }
};

const owner = await signIn(SHOP);
const buyer = await signIn(BUYER);
const shopId = must(await owner.rpc('me'), 'me').shops[0].shop_id;
let order;
let booking;

try {
  // 1a. A cash order for one part the shop has.
  const listings = must(
    await owner.rpc('shop_listings', { p_shop_id: shopId, p_q: '', p_limit: 100, p_offset: 0 }),
    'stock',
  );
  const listing = listings.find((l) => l.is_active && l.available_qty > 0 && l.price_sdg);
  if (!listing) throw new Error('The demo shop has nothing in stock (pnpm db:seed:dev).');
  order = must(
    await buyer.rpc('checkout', {
      p_items: [{ listing_id: listing.id, qty: 1, seen_price_sdg: listing.price_sdg }],
      p_method: 'CASH',
      p_fulfilment: {},
      p_address_id: null,
      p_idem: crypto.randomUUID(),
    }),
    'order',
  );

  // 1b. A fitting at the bay with the demo technician, paid in cash: offered to him.
  const tech = await signIn(TECH);
  const techId = must(await tech.rpc('me'), 'tech me').technician.technician_id;
  const snapshot = must(await buyer.rpc('catalogue_snapshot', { p_since: null }), 'snapshot');
  const lighting = snapshot.job_types.find((j) => j.code === 'LIGHTING');
  const category = snapshot.categories.find((c) => c.job_type_id === lighting.id);
  const items = [{ category_id: category.id, description: 'device test' }];
  const { data: session } = await buyer.auth.getSession();
  const slots = await fetch(`${dev.url}/functions/v1/booking-slots`, {
    method: 'POST',
    headers: {
      apikey: dev.publishableKey,
      Authorization: `Bearer ${session.session.access_token}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ items, place: 'BAY', technician_id: techId }),
  }).then((r) => r.json());
  const start = slots.technicians?.[0]?.slots?.[0];
  if (!start) throw new Error('The demo technician has no free time this week.');
  const hold = must(
    await buyer.rpc('create_booking_hold', {
      p_technician_id: techId,
      p_start_at: start,
      p_items: items,
      p_place: 'BAY',
      p_assignment_mode: 'CHOSEN',
      p_idem: crypto.randomUUID(),
    }),
    'hold',
  );
  const fitting = must(
    await buyer.rpc('checkout', {
      p_items: [],
      p_method: 'CASH',
      p_fulfilment: {},
      p_address_id: null,
      p_booking_id: hold.id,
      p_idem: crypto.randomUUID(),
    }),
    'fitting',
  );
  booking = fitting.booking ?? hold;
  console.log(`order ${order.ref} and fitting ${booking.ref} placed`);

  // 2. The device test.
  const app = join(root, 'apps', 'partner');
  const defines = JSON.parse(readFileSync(join(app, 'env', 'dev.json'), 'utf8'));
  const dir = mkdtempSync(join(tmpdir(), 'alghali-e2e-'));
  try {
    const file = join(dir, 'defines.json');
    writeFileSync(
      file,
      JSON.stringify({
        ...defines,
        E2E_SHOP_EMAIL: SHOP,
        E2E_TECH_EMAIL: TECH,
        E2E_PASSWORD: env.DEMO_PASSWORD,
        E2E_ORDER_REF: order.ref,
        E2E_BOOKING_REF: booking.ref,
      }),
      { mode: 0o600 },
    );
    const r = spawnSync(
      'flutter',
      [
        'test',
        'integration_test/journey_test.dart',
        `--dart-define-from-file=${file}`,
        ...process.argv.slice(2).filter((a) => a !== '--'),
      ],
      { cwd: app, stdio: 'inherit', shell: true },
    );
    process.exitCode = r.status ?? 1;
  } finally {
    rmSync(dir, { recursive: true, force: true });
    // The test build lists the integration_test plugin here; a release build that reuses
    // the file fails, and Flutter writes it again when it is missing.
    rmSync(
      join(app, 'android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java'),
      {
        force: true,
      },
    );
  }
} finally {
  // 3. Tidy up, whatever happened.
  const admin = await signIn(ADMIN);
  const reason = 'device test clean-up';
  for (const sub of order?.sub_orders ?? []) {
    const { error } = await admin.rpc('admin_cancel_suborder', {
      p_sub_order_id: sub.id,
      p_reason: reason,
    });
    console.log(`order ${order.ref}: ${error ? `not cancelled (${error.message})` : 'cancelled'}`);
  }
  if (booking) {
    const { error } = await admin.rpc('admin_cancel_booking', {
      p_booking_id: booking.id,
      p_reason: reason,
    });
    console.log(
      `fitting ${booking.ref}: ${error ? `not cancelled (${error.message})` : 'cancelled'}`,
    );
  }
  await owner.rpc('shop_set_closed', { p_shop_id: shopId, p_until: null });
}
