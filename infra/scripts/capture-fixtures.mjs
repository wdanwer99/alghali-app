// Saves real answers from alghali-dev as JSON fixtures for the buyer app's widget tests
// (apps/buyer/test/fixtures), so the screens are tested on data shaped exactly like the
// server's. Reads the demo data only (pnpm db:seed:dev), signed in as the demo buyer.
//   node infra/scripts/capture-fixtures.mjs
// Needs SUPABASE_DEV_URL / _PUBLISHABLE_KEY and DEMO_PASSWORD in .env; prints no secrets.
import { mkdirSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { createClient } from '@supabase/supabase-js';
import { readEnvFile, supabaseTarget } from './lib/env.mjs';
import { root } from './lib/paths.mjs';

const env = readEnvFile(join(root, '.env')) ?? {};
const dev = supabaseTarget(env, 'DEV');
if (!dev.url || !dev.publishableKey || !env.DEMO_PASSWORD) {
  console.error(
    'SUPABASE_DEV_URL, SUPABASE_DEV_PUBLISHABLE_KEY and DEMO_PASSWORD must be set in .env.',
  );
  process.exit(1);
}
const out = join(root, 'apps/buyer/test/fixtures');
mkdirSync(out, { recursive: true });
const save = (name, data) =>
  writeFileSync(join(out, `${name}.json`), JSON.stringify(data, null, 2) + '\n');
const must = ({ data, error }, what) => {
  if (error) throw new Error(`${what}: ${error.message}`);
  return data;
};

const anon = createClient(dev.url, dev.publishableKey, { auth: { persistSession: false } });
const buyer = createClient(dev.url, dev.publishableKey, { auth: { persistSession: false } });
must(
  await buyer.auth.signInWithPassword({
    email: 'buyer@demo.alghali.invalid',
    password: env.DEMO_PASSWORD,
  }),
  'sign in',
);

// Public catalogue.
const snapshot = must(await anon.rpc('catalogue_snapshot', { p_since: null }), 'snapshot');
save('catalogue_snapshot', snapshot);
save('public_settings', must(await anon.rpc('public_settings'), 'settings'));
const hilux = snapshot.variants.find((v) => {
  const model = snapshot.models.find((m) => m.id === v.model_id);
  return model?.name_en === 'Hilux';
});
const search = (params) =>
  anon.rpc('search_parts', {
    p_q: '',
    p_variant_id: null,
    p_category_id: null,
    p_only_fits: false,
    p_conditions: null,
    p_price_max: null,
    p_shop_id: null,
    p_in_stock_only: true,
    p_deals_only: false,
    p_sort: 'relevance',
    p_limit: 30,
    p_offset: 0,
    ...params,
  });
const bulbs = must(await search({ p_q: 'لمبات', p_variant_id: hilux?.id ?? null }), 'search');
save('search_bulbs', bulbs);
save(
  'search_deals',
  must(await search({ p_deals_only: true, p_sort: 'discount', p_limit: 12 }), 'deals'),
);
const partId = bulbs[0]?.part_id;
save(
  'part_detail',
  must(
    await anon.rpc('part_detail', { p_part_id: partId, p_variant_id: hilux?.id ?? null }),
    'part',
  ),
);
const shopId = bulbs[0]?.listings?.[0]?.shop_id;
save('search_shop', must(await search({ p_shop_id: shopId, p_limit: 50 }), 'shop parts'));
save(
  'reviews_shop',
  must(
    await anon.rpc('reviews_for', { p_shop_id: shopId, p_technician_id: null, p_limit: 20 }),
    'reviews',
  ),
);
const listingId = bulbs[0]?.listings?.[0]?.id;
const slots = await fetch(`${dev.url}/functions/v1/booking-slots`, {
  method: 'POST',
  headers: { apikey: dev.publishableKey, 'Content-Type': 'application/json' },
  body: JSON.stringify({ items: [{ listing_id: listingId }], place: 'BAY', variant_id: hilux?.id }),
});
save('booking_slots_bay', await slots.json());

// The demo buyer's own things.
save('me', must(await buyer.rpc('me'), 'me'));
save(
  'garage',
  must(
    await buyer.from('garage_vehicles').select().order('is_default', { ascending: false }),
    'garage',
  ),
);
save('addresses', must(await buyer.from('addresses').select(), 'addresses'));
const orderSelect =
  '*, payments(*), refunds(*), sub_orders(*, shop:shops(id, name_ar, name_en, phone, whatsapp, ' +
  'zone_id, plot_no, pos_m), order_items(*), suborder_events(*), returns(*))';
save(
  'orders',
  must(
    await buyer
      .from('orders')
      .select(orderSelect)
      .order('created_at', { ascending: false })
      .range(0, 29),
    'orders',
  ),
);
save('my_bookings', must(await buyer.rpc('my_bookings', { p_limit: 30, p_offset: 0 }), 'bookings'));
save(
  'notifications',
  must(
    await buyer.from('notifications').select().order('created_at', { ascending: false }).limit(50),
    'inbox',
  ),
);
save(
  'templates',
  must(
    await buyer
      .from('notification_templates')
      .select('code, locale, title, body, notification_codes!inner(app)')
      .eq('notification_codes.app', 'buyer'),
    'templates',
  ),
);
save(
  'requests',
  must(
    await buyer
      .from('part_requests')
      .select('*, part_offers(*)')
      .order('created_at', { ascending: false }),
    'requests',
  ),
);
save('disputes', must(await buyer.rpc('my_disputes', { p_limit: 30 }), 'disputes'));

console.log(
  `fixtures saved to apps/buyer/test/fixtures (Hilux ${hilux ? 'found' : 'missing'}, ${bulbs.length} bulb results)`,
);
