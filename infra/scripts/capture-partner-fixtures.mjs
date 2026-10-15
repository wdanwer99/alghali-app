// Saves real answers from alghali-dev as JSON fixtures for the partner app's widget tests
// (apps/partner/test/fixtures), signed in as the demo shop owner (Al-Nour) and the demo
// technician who works at its bay (Omar). Reads only; needs the demo data (pnpm db:seed:dev).
//   pnpm fixtures:partner
// Needs SUPABASE_DEV_URL / _PUBLISHABLE_KEY and DEMO_PASSWORD in .env; prints no secrets.
import { mkdirSync, readdirSync, readFileSync, writeFileSync } from 'node:fs';
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
const out = join(root, 'apps/partner/test/fixtures');
mkdirSync(out, { recursive: true });
// Real people can use dev too (the owner trying the app): anyone whose phone isn't a demo
// number (+24991200…/+24991210…) is replaced by a placeholder before anything is saved.
const demoPhone = /^\+2499121?0{2}/;
const strangers = new Map();
const findStrangers = (v) => {
  if (Array.isArray(v)) return v.forEach(findStrangers);
  if (v && typeof v === 'object') {
    if (typeof v.phone === 'string' && !demoPhone.test(v.phone)) {
      strangers.set(v.phone, v.name ?? v.display_name ?? v.buyer_name ?? null);
    }
    Object.values(v).forEach(findStrangers);
  }
};
const scrub = (text) => {
  for (const [phone, name] of strangers) {
    text = text.split(phone).join('+249912000099');
    if (name) text = text.split(JSON.stringify(name)).join(JSON.stringify('زبون تجريبي'));
  }
  return text;
};
const save = (name, data) => {
  findStrangers(data);
  writeFileSync(join(out, `${name}.json`), scrub(JSON.stringify(data, null, 2)) + '\n');
};
const must = ({ data, error }, what) => {
  if (error) throw new Error(`${what}: ${error.message}`);
  return data;
};
const signIn = async (email) => {
  const client = createClient(dev.url, dev.publishableKey, { auth: { persistSession: false } });
  must(await client.auth.signInWithPassword({ email, password: env.DEMO_PASSWORD }), email);
  return client;
};

const anon = createClient(dev.url, dev.publishableKey, { auth: { persistSession: false } });
save(
  'catalogue_snapshot',
  must(await anon.rpc('catalogue_snapshot', { p_since: null }), 'snapshot'),
);
save('public_settings', must(await anon.rpc('public_settings'), 'settings'));

// The shop.
const owner = await signIn('owner.nour@demo.alghali.invalid');
const ownerMe = must(await owner.rpc('me'), 'me');
save('shop_me', ownerMe);
const shopId = ownerMe.shops[0].shop_id;
save('shop_detail', must(await owner.rpc('shop_detail', { p_shop_id: shopId }), 'shop'));
const orders = must(
  await owner.rpc('shop_orders', {
    p_shop_id: shopId,
    p_statuses: null,
    p_limit: 100,
    p_offset: 0,
  }),
  'orders',
);
save('shop_orders', orders);
save(
  'shop_listings',
  must(
    await owner.rpc('shop_listings', { p_shop_id: shopId, p_q: '', p_limit: 500, p_offset: 0 }),
    'stock',
  ),
);
save(
  'shop_open_requests',
  must(
    await owner.rpc('shop_open_requests', { p_shop_id: shopId, p_limit: 30, p_offset: 0 }),
    'requests',
  ),
);
const chats = must(
  await owner.rpc('shop_conversations', { p_shop_id: shopId, p_limit: 50 }),
  'chats',
);
save('shop_conversations', chats);
save(
  'messages',
  chats[0]
    ? must(
        await owner
          .from('messages')
          .select()
          .eq('conversation_id', chats[0].id)
          .order('created_at', { ascending: false })
          .limit(50),
        'messages',
      )
    : [],
);
save('shop_staff', must(await owner.rpc('shop_staff', { p_shop_id: shopId }), 'staff'));
save(
  'shop_statement',
  must(
    await owner.rpc('shop_statement', { p_shop_id: shopId, p_from: null, p_to: null }),
    'statement',
  ),
);
save(
  'shop_insights',
  must(await owner.rpc('shop_insights', { p_shop_id: shopId, p_days: 7 }), 'insights'),
);
save(
  'suggest_parts',
  must(
    await owner.rpc('suggest_parts', { p_q: 'لمبة', p_shop_id: shopId, p_category_id: null }),
    'suggest',
  ),
);
save(
  'shop_notifications',
  must(
    await owner
      .from('notifications')
      .select()
      .eq('app', 'partner')
      .order('created_at', { ascending: false })
      .limit(50),
    'inbox',
  ),
);
save(
  'templates',
  must(await owner.from('notification_templates').select('code, locale, title, body'), 'templates'),
);

// The technician (the same select as TechnicianRepository.me()).
const tech = await signIn('tech.omar@demo.alghali.invalid');
save('tech_me_account', must(await tech.rpc('me'), 'tech me'));
const techSelect =
  '*, technician_job_types(labour_sdg, job_types(id, code, name_ar, name_en)), technician_makes(make_id), ' +
  'availability_rules(*), time_off(*), bay:shops!technicians_home_bay_shop_id_fkey(id, name_ar, name_en, plot_no, zone_id)';
const uid = (await tech.auth.getUser()).data.user.id;
save(
  'technician',
  must(
    await tech.from('technicians').select(techSelect).eq('user_id', uid).maybeSingle(),
    'technician',
  ),
);
for (const scope of ['OFFERS', 'UPCOMING', 'PAST']) {
  save(
    `tech_${scope.toLowerCase()}`,
    must(await tech.rpc('tech_bookings', { p_scope: scope, p_limit: 50 }), scope),
  );
}
save(
  'tech_statement',
  must(await tech.rpc('tech_statement', { p_from: null, p_to: null }), 'earnings'),
);
save(
  'tech_notifications',
  must(
    await tech
      .from('notifications')
      .select()
      .eq('app', 'partner')
      .order('created_at', { ascending: false })
      .limit(50),
    'tech inbox',
  ),
);

// A stranger first seen in a later file may appear in an earlier one: scrub them all again.
for (const f of readdirSync(out).filter((n) => n.endsWith('.json'))) {
  writeFileSync(join(out, f), scrub(readFileSync(join(out, f), 'utf8')));
}
console.log(
  `fixtures saved to apps/partner/test/fixtures (${orders.length} shop orders, ${chats.length} chats, ` +
    `${strangers.size} non-demo people replaced)`,
);
