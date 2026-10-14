// Loads supabase/seed/demo.json into alghali-dev: demo accounts (an admin, buyers, one owner
// per shop, technicians), approved shops, demo parts with fitment, listings with a few price
// cuts, orders and fittings at different stages. Everything goes through the same RPCs the
// apps call. Safe to re-run.
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

  // Demo orders, placed and moved along through the same RPCs the apps call. Only when
  // the demo buyers have no orders yet, so a re-run adds nothing.
  const buyers = {};
  for (const [key, b] of Object.entries(demo.buyers))
    buyers[key] = await account(b.email, b.name, b.phone);
  const [{ n: existingOrders }] = await sql`
    select count(*)::int as n from public.orders where buyer_id = any (${Object.values(buyers)}::uuid[])`;
  let placedOrders = 0;
  if (existingOrders === 0) {
    const txn = () => String(100000000 + Math.floor(Math.random() * 899999999));
    for (const spec of demo.orders) {
      const buyer = buyers[spec.buyer];
      const items = [];
      for (const [shopKey, partKey, condition, qty] of spec.lines) {
        const [l] = await sql`
          select id, price_sdg from public.listings
          where shop_id = ${shops[shopKey]} and part_id = ${parts[partKey]} and condition = ${condition}::public.listing_condition`;
        items.push({ listing_id: l.id, qty, seen_price_sdg: Number(l.price_sdg) });
      }
      const order = await as(buyer, async (tx) => {
        const [{ o }] =
          await tx`select public.checkout(${tx.json(items)}, ${spec.method}::public.payment_method) as o`;
        return o;
      });
      const shopKeys = spec.lines.map(([shopKey]) => shopKey);
      const subFor = (shopKey) => order.sub_orders.find((s) => s.shop_id === shops[shopKey]).id;
      const byShop = async (fn) => {
        for (const shopKey of new Set(shopKeys)) {
          await as(owners[shopKey], (tx) => fn(tx, subFor(shopKey)));
        }
      };
      const stage = spec.stage;
      if (spec.method === 'BANKAK' && stage !== 'awaiting') {
        await as(buyer, (tx) => tx`select public.submit_bankak_receipt(${order.id}, ${txn()})`);
        if (stage !== 'receipt') {
          const payment = order.payments.find((p) => p.method === 'BANKAK');
          await as(admin, (tx) => tx`select public.admin_confirm_payment(${payment.id})`);
        }
      }
      if (stage === 'rejected_refund') {
        await byShop(
          (tx, sub) => tx`select public.shop_reject_suborder(${sub}, 'نفدت الكمية من المخزن')`,
        );
      }
      if (['ready', 'completed', 'cash_completed', 'return_requested'].includes(stage)) {
        await byShop(async (tx, sub) => {
          await tx`select public.shop_ack_suborder(${sub})`;
          await tx`select public.shop_mark_ready(${sub})`;
        });
      }
      if (['completed', 'cash_completed', 'return_requested'].includes(stage)) {
        await byShop((tx, sub) => tx`select public.shop_hand_over(${sub})`);
      }
      if (['completed', 'cash_completed'].includes(stage)) {
        for (const s of order.sub_orders) {
          await as(buyer, (tx) => tx`select public.confirm_received(${s.id})`);
        }
      }
      if (stage === 'return_requested') {
        const sub = order.sub_orders[0].id;
        await as(
          buyer,
          (tx) => tx`select public.request_return(${sub}, 'الفلتر لا يناسب السيارة')`,
        );
      }
      placedOrders++;
    }
  }

  // Demo technicians: they apply in the partner app's way, set their hours, and an admin
  // approves all but the last two (left for the admin's applications queue).
  const jobTypes = Object.fromEntries(
    (await sql`select code, id from public.job_types`).map((r) => [r.code, r.id]),
  );
  const techs = {};
  const techUsers = {};
  let newTechs = 0;
  for (const t of demo.technicians) {
    const user = await account(`tech.${t.key}@demo.alghali.invalid`, t.name, t.phone);
    techUsers[t.key] = user;
    let [row] = await sql`select id from public.technicians where user_id = ${user}`;
    if (!row) {
      row = await as(user, async (tx) => {
        const [{ r }] = await tx`
          select public.apply_as_technician(
            p_work_mode => ${t.mode}::public.work_mode,
            p_job_types => ${tx.json(Object.entries(t.jobs).map(([code, labour]) => ({ job_type_id: jobTypes[code], labour_sdg: labour })))},
            p_phone => ${t.phone},
            p_make_ids => (select coalesce(array_agg(id), '{}') from public.vehicle_makes where slug = any (${t.makes}::text[])),
            p_home_bay_shop_id => ${t.bay ? shops[t.bay] : null},
            p_home_lat => ${t.home?.[0] ?? null}, p_home_lng => ${t.home?.[1] ?? null},
            p_radius_km => ${t.radius ?? 10}, p_years_experience => ${t.years},
            p_bio_ar => ${t.bio_ar}) as r`;
        await tx`select public.tech_update_profile(${tx.json({ bio_en: t.bio_en })})`;
        for (const [weekday, windows] of Object.entries(demo.tech_hours)) {
          for (const [start, end] of windows) {
            await tx`insert into public.availability_rules (technician_id, weekday, start_min, end_min)
                     values (${r.id}, ${Number(weekday)}, ${start}, ${end})`;
          }
        }
        return r;
      });
      if (!t.pending) {
        await as(
          admin,
          (tx) => tx`select public.admin_set_technician_status(${row.id}, 'APPROVED')`,
        );
        if (t.verified)
          await as(admin, (tx) => tx`select public.admin_verify_technician(${row.id}, true)`);
        // A track record, so ranking has something to rank (demo only).
        await sql`update public.technicians set rating_avg = ${t.rating}, rating_count = ${Math.round(t.jobs_done / 3)},
                    completed_jobs = ${t.jobs_done} where id = ${row.id}`;
      }
      newTechs++;
    }
    techs[t.key] = row.id;
  }

  // Demo fittings at the bay, only while the demo buyers have none.
  const [{ n: existingBookings }] = await sql`
    select count(*)::int as n from public.bookings where buyer_id = any (${Object.values(buyers)}::uuid[])`;
  let newBookings = 0;
  if (existingBookings === 0) {
    const txn = () => String(100000000 + Math.floor(Math.random() * 899999999));
    // Weekday afternoons from tomorrow (Khartoum), skipping Friday; one slot per fitting.
    const [{ days }] = await sql`
      select array_agg(to_char(d, 'YYYY-MM-DD') order by d) as days
      from generate_series((now() at time zone 'Africa/Khartoum')::date + 1,
                           (now() at time zone 'Africa/Khartoum')::date + 6, interval '1 day') d
      where extract(dow from d) <> 5`;
    let slot = 0;
    for (const spec of demo.bookings) {
      const buyer = buyers[spec.buyer];
      const day = days[Math.floor(slot / 3) % days.length];
      const start = new Date(
        `${day}T${String(16 + (slot % 3)).padStart(2, '0')}:00:00+02:00`,
      ).toISOString();
      slot++;
      let lines = [];
      let item;
      if (spec.part) {
        const [l] = await sql`
          select id, price_sdg from public.listings where shop_id = ${shops[spec.shop]} and part_id = ${parts[spec.part]}
          order by price_sdg limit 1`;
        lines = [{ listing_id: l.id, qty: 1, seen_price_sdg: Number(l.price_sdg) }];
        item = { listing_id: l.id };
      } else {
        const [c] = await sql`select id from public.part_categories where slug = ${spec.category}`;
        item = { category_id: c.id, description: spec.note };
      }
      const booking = await as(buyer, async (tx) => {
        const [{ b }] = await tx`
          select public.create_booking_hold(p_technician_id => ${techs[spec.tech]}, p_start_at => ${start},
                                            p_items => ${tx.json([item])}, p_place => 'BAY') as b`;
        return b;
      });
      const order = await as(buyer, async (tx) => {
        const [{ o }] = await tx`
          select public.checkout(p_items => ${tx.json(lines)}, p_method => ${spec.method}::public.payment_method,
                                 p_booking_id => ${booking.id}) as o`;
        return o;
      });
      const stage = spec.stage;
      if (spec.method === 'BANKAK' && stage !== 'awaiting') {
        await as(buyer, (tx) => tx`select public.submit_bankak_receipt(${order.id}, ${txn()})`);
        if (stage !== 'receipt') {
          const payment = order.payments.find((p) => p.method === 'BANKAK');
          await as(admin, (tx) => tx`select public.admin_confirm_payment(${payment.id})`);
        }
      }
      if (['accepted', 'completed'].includes(stage)) {
        const [offer] =
          await sql`select id from public.booking_offers where booking_id = ${booking.id} and status = 'OFFERED'`;
        await as(
          techUsers[spec.tech],
          (tx) => tx`select public.tech_respond_offer(${offer.id}, true)`,
        );
        for (const s of order.sub_orders) {
          const owner = owners[spec.shop];
          await as(owner, async (tx) => {
            await tx`select public.shop_ack_suborder(${s.id})`;
            await tx`select public.shop_mark_ready(${s.id})`;
            if (stage === 'completed') await tx`select public.shop_hand_over(${s.id})`;
          });
        }
      }
      if (stage === 'completed') {
        // Done earlier today: the job is moved into the past (demo only), then closed the usual way.
        await sql`update public.bookings set start_at = now() - interval '3 hours', end_at = now() - interval '2 hours',
                    block_from = now() - interval '3 hours', block_to = now() - interval '2 hours' where id = ${booking.id}`;
        const [{ code }] =
          await sql`select code from public.booking_codes where booking_id = ${booking.id}`;
        await as(techUsers[spec.tech], async (tx) => {
          await tx`select public.tech_check_in(${booking.id})`;
          await tx`select public.tech_complete(${booking.id}, ${code})`;
        });
        await as(buyer, async (tx) => {
          await tx`select public.create_review(5, p_booking_id => ${booking.id}, p_comment => 'شغل نظيف وفي الموعد')`;
          for (const s of order.sub_orders) {
            await tx`select public.create_review(4, p_sub_order_id => ${s.id}, p_comment => 'القطعة أصلية')`;
          }
        });
      }
      newBookings++;
    }
  }

  console.log(
    `${which} seeded: ${demo.shops.length} shops, ${Object.keys(parts).length} demo parts, ${added} new listings, ${placedOrders} new orders, ${newTechs} new technicians, ${newBookings} new bookings.`,
  );
  console.log(
    `Demo sign-in: ${demo.people.buyer.email}, ${demo.people.admin.email}, owner.<shop>@ and tech.<name>@demo.alghali.invalid`,
  );
  console.log('Password: DEMO_PASSWORD in .env');
} finally {
  await sql.end();
}
