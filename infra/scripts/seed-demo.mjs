// Loads supabase/seed/demo.json into alghali-dev: demo accounts (an admin, a buyer and one
// owner per shop), approved shops, demo parts with fitment, and listings with a few price
// cuts. Shops and listings go through the same RPCs the apps call. Safe to re-run.
//   node seed-demo.mjs dev     alghali-dev, keys from the root .env
//   node seed-demo.mjs local   CI's local stack: API_URL, API_SECRET_KEY, DB_URL from the environment
// Refuses every other project: demo data must never reach the live project (D-051, D-053).
// All demo accounts share DEMO_PASSWORD from the root .env (generated on first run).
import { randomBytes } from 'node:crypto';
import { appendFileSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { createClient } from '@supabase/supabase-js';
import postgres from 'postgres';
import { isSet, readEnvFile, supabaseTarget } from './lib/env.mjs';
import { root } from './lib/paths.mjs';

const which = process.argv[2];
if (which !== 'dev' && which !== 'local') {
  console.error('usage: seed-demo.mjs <dev|local>   (demo data never goes to the live project)');
  process.exit(2);
}

const envPath = join(root, '.env');
const env = readEnvFile(envPath) ?? {};
const dev =
  which === 'dev'
    ? supabaseTarget(env, 'DEV')
    : {
        url: process.env.API_URL,
        secretKey: process.env.API_SECRET_KEY,
        dbUrl: process.env.DB_URL,
      };
if (!dev.url || !dev.secretKey || !dev.dbUrl) {
  console.error(
    which === 'dev'
      ? 'SUPABASE_DEV_URL / _SECRET_KEY / _DB_URL must be set in .env.'
      : 'API_URL / API_SECRET_KEY / DB_URL must be set.',
  );
  process.exit(1);
}
if (which === 'local' && !/^http:\/\/(127\.0\.0\.1|localhost)[:/]/.test(dev.url)) {
  console.error('local means a local stack (http://127.0.0.1…).');
  process.exit(2);
}

let password = isSet(env.DEMO_PASSWORD) ? env.DEMO_PASSWORD : (process.env.DEMO_PASSWORD ?? '');
if (!password && which === 'local') {
  password = `Demo-${randomBytes(9).toString('base64url')}7`;
} else if (!password) {
  password = `Demo-${randomBytes(9).toString('base64url')}7`;
  appendFileSync(
    envPath,
    `\n# Password of every demo account on alghali-dev (pnpm db:seed:dev).\nDEMO_PASSWORD=${password}\n`,
  );
  console.log('Generated DEMO_PASSWORD and saved it in .env.');
}

const demo = JSON.parse(readFileSync(join(root, 'supabase/seed/demo.json'), 'utf8'));
const auth = createClient(dev.url, dev.secretKey, {
  auth: { persistSession: false, autoRefreshToken: false },
});
const sql = postgres(dev.dbUrl, { max: 1, onnotice: () => undefined });

/** Runs fn in a transaction as `uid`, the way PostgREST runs an RPC. */
function as(uid, fn) {
  return sql.begin(async (tx) => {
    await tx`select set_config('request.jwt.claims', ${JSON.stringify({ sub: uid, role: 'authenticated' })}, true)`;
    await tx.unsafe('set local role authenticated');
    return fn(tx);
  });
}

async function account(email, name, phone) {
  const [found] = await sql`select id from auth.users where email = ${email}`;
  if (found) return found.id;
  const { data, error } = await auth.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
    user_metadata: { display_name: name, ...(phone ? { phone } : {}), locale: 'ar' },
  });
  if (error) throw error;
  return data.user.id;
}

try {
  const admin = await account(demo.people.admin.email, demo.people.admin.name);
  await sql`insert into public.user_roles (user_id, role) values (${admin}, 'ADMIN') on conflict do nothing`;
  await account(demo.people.buyer.email, demo.people.buyer.name, demo.people.buyer.phone);

  // Demo parts are verified catalogue parts, so several shops' offers group under one card.
  const parts = {};
  for (const [key, p] of Object.entries(demo.parts)) {
    const [existing] =
      await sql`select id from public.parts where name_ar = ${p.ar} and created_by_shop_id is null`;
    let id = existing?.id;
    if (!id) {
      [{ id }] = await sql`
        insert into public.parts (category_id, name_ar, name_en, oem_numbers, keywords, installable, std_job_minutes)
        select c.id, ${p.ar}, ${p.en}, ${p.oem ?? []}, ${p.keywords ?? []},
               coalesce(${p.installable ?? null}::boolean, c.job_type_id is not null), ${p.minutes ?? null}
        from public.part_categories c where c.slug = ${p.cat}
        returning id`;
      for (const model of p.models ?? []) {
        const [make, slug] = model.split('/');
        await sql`
          insert into public.part_fitments (part_id, variant_id)
          select ${id}, v.id from public.vehicle_variants v
          join public.vehicle_models m on m.id = v.model_id join public.vehicle_makes mk on mk.id = m.make_id
          where mk.slug = ${make} and m.slug = ${slug}
          on conflict do nothing`;
      }
    }
    parts[key] = id;
  }

  const shops = {};
  const owners = {};
  for (const s of demo.shops) {
    const owner = await account(`owner.${s.key}@demo.alghali.invalid`, s.owner, null);
    owners[s.key] = owner;
    let [shop] =
      await sql`select shop_id as id from public.shop_members where user_id = ${owner} and role = 'OWNER'`;
    if (!shop) {
      const [zone] = await sql`
        select z.id from public.zones z join public.streets st on st.id = z.street_id
        where st.slug = 'alghali' and z.seq = ${s.zone}`;
      shop = await as(owner, async (tx) => {
        const [{ r }] = await tx`
          select public.apply_as_shop(
            p_name_ar => ${s.ar}, p_name_en => ${s.en}, p_zone_id => ${zone.id}, p_phone => '0912345678',
            p_plot_no => ${s.plot}, p_side => ${s.side}, p_landmark_ar => ${s.landmark_ar},
            p_about_ar => ${s.about_ar}, p_opening_hours => ${tx.json(demo.hours[s.hours ?? 'standard'])},
            p_category_ids => (select coalesce(array_agg(id), '{}') from public.part_categories
                               where slug = any (${s.cats ?? []}::text[])),
            p_make_ids => (select coalesce(array_agg(id), '{}') from public.vehicle_makes
                           where slug = any (${s.makes ?? []}::text[]))) as r`;
        return r;
      });
      await as(admin, (tx) => tx`select public.admin_set_shop_status(${shop.id}, 'APPROVED')`);
      await as(
        admin,
        (tx) => tx`
        select public.shop_update_profile(${shop.id}, ${tx.json({
          landmark_en: s.landmark_en,
          about_en: s.about_en,
          pos_m: s.pos,
        })})`,
      );
      if (s.verified)
        await as(admin, (tx) => tx`select public.admin_verify_shop(${shop.id}, true)`);
    }
    shops[s.key] = shop.id;
  }

  let added = 0;
  for (const [shopKey, partKey, condition, price, was, qty, warranty, brand] of demo.listings) {
    const shop = shops[shopKey];
    const [existing] = await sql`
      select id from public.listings
      where shop_id = ${shop} and part_id = ${parts[partKey]} and condition = ${condition}::public.listing_condition`;
    if (existing) continue;
    await as(owners[shopKey], async (tx) => {
      const [{ r }] = await tx`
        select public.shop_upsert_listing(
          p_shop_id => ${shop}, p_part_id => ${parts[partKey]},
          p_condition => ${condition}::public.listing_condition, p_stock_qty => ${qty},
          p_price_sdg => ${was ?? price}, p_warranty_days => ${warranty}, p_brand => ${brand}) as r`;
      if (was) {
        await tx`select public.shop_bulk_update(${shop}, ${tx.json([{ listing_id: r.id, version: r.version, price_sdg: price }])})`;
      }
    });
    added++;
  }

  console.log(
    `${which} seeded: ${demo.shops.length} shops, ${Object.keys(parts).length} demo parts, ${added} new listings.`,
  );
  console.log(
    `Demo sign-in: ${demo.people.buyer.email}, ${demo.people.admin.email}, owner.<shop>@demo.alghali.invalid`,
  );
  console.log('Password: DEMO_PASSWORD in .env');
} finally {
  await sql.end();
}
