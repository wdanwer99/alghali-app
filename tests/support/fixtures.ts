import { actAs, type Tx, must } from './db.ts';

/** Back to the migration owner (no JWT), e.g. to set up fixtures mid-test. */
export async function asSystem(tx: Tx): Promise<void> {
  await tx`select set_config('request.jwt.claims', '', true)`;
  await tx.unsafe('reset role');
}

export const asUser = (tx: Tx, uid: string) => actAs(tx, 'authenticated', uid);
export const asAnon = (tx: Tx) => actAs(tx, 'anon');

export interface DbError {
  code: string;
  message: string;
}

/**
 * Runs `fn` in a savepoint and returns the error it raised, so the surrounding
 * transaction stays usable. Fails the test if nothing was raised.
 */
export async function failure(tx: Tx, fn: (sp: Tx) => Promise<unknown>): Promise<DbError> {
  try {
    await tx.savepoint(async (sp) => {
      await fn(sp as unknown as Tx);
    });
  } catch (e) {
    const err = e as { code?: string; message?: string };
    return { code: err.code ?? '', message: err.message ?? String(e) };
  }
  throw new Error('expected the statement to fail, but it succeeded');
}

/** Inserts an auth user the way GoTrue does; the new-user trigger adds profile + BUYER. */
export async function createUser(
  tx: Tx,
  opts: { email?: string; meta?: Record<string, unknown> } = {},
): Promise<string> {
  await asSystem(tx);
  const id = crypto.randomUUID();
  const email = opts.email ?? `u-${id.slice(0, 8)}@test.alghali.invalid`;
  await tx`
    insert into auth.users (id, instance_id, aud, role, email, raw_user_meta_data, raw_app_meta_data,
                            created_at, updated_at)
    values (${id}, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', ${email},
            ${tx.json((opts.meta ?? {}) as never)}, '{}'::jsonb, now(), now())`;
  return id;
}

export async function createAdmin(tx: Tx): Promise<string> {
  const id = await createUser(tx);
  await tx`insert into public.user_roles (user_id, role) values (${id}, 'ADMIN')`;
  return id;
}

export type ShopStatus = 'PENDING' | 'APPROVED' | 'REJECTED' | 'SUSPENDED';

/** A shop with `ownerId` as OWNER, inserted directly (bypassing the application flow). */
export async function createShop(
  tx: Tx,
  ownerId: string,
  opts: { status?: ShopStatus; name?: string; zoneSeq?: number } = {},
): Promise<string> {
  await asSystem(tx);
  const status = opts.status ?? 'APPROVED';
  const [zone] = await tx<{ id: string }[]>`
    select z.id from public.zones z join public.streets s on s.id = z.street_id
    where s.slug = 'alghali' and z.seq = ${opts.zoneSeq ?? 1}`;
  const [shop] = await tx<{ id: string }[]>`
    insert into public.shops (zone_id, name_ar, phone, status, created_by, approved_at, pos_m)
    values (${must(zone).id}, ${opts.name ?? 'محل الاختبار'}, '+249912345678', ${status}::public.partner_status,
            ${ownerId}, case when ${status} = 'APPROVED' then now() end, 100)
    returning id`;
  await tx`insert into public.shop_members (shop_id, user_id, role) values (${must(shop).id}, ${ownerId}, 'OWNER')`;
  if (status === 'APPROVED') {
    await tx`insert into public.user_roles (user_id, role) values (${ownerId}, 'SHOP_OWNER') on conflict do nothing`;
  }
  return must(shop).id;
}

export async function categoryId(tx: Tx, slug: string): Promise<string> {
  const [row] = await tx<
    { id: string }[]
  >`select id from public.part_categories where slug = ${slug}`;
  if (!row) throw new Error(`no category ${slug}`);
  return row.id;
}

export async function modelId(tx: Tx, make: string, model: string): Promise<string> {
  const [row] = await tx<{ id: string }[]>`
    select m.id from public.vehicle_models m join public.vehicle_makes mk on mk.id = m.make_id
    where mk.slug = ${make} and m.slug = ${model}`;
  if (!row) throw new Error(`no model ${make}/${model}`);
  return row.id;
}

export async function variantIds(tx: Tx, make: string, model: string): Promise<string[]> {
  const rows = await tx<{ id: string }[]>`
    select v.id from public.vehicle_variants v
    join public.vehicle_models m on m.id = v.model_id
    join public.vehicle_makes mk on mk.id = m.make_id
    where mk.slug = ${make} and m.slug = ${model}
    order by v.sort`;
  return rows.map((r) => r.id);
}

/** Calls shop_upsert_listing for a new listing with a part typed in by the shop. */
export async function quickListing(
  tx: Tx,
  shopId: string,
  opts: {
    name: string;
    category: string;
    price?: number;
    qty?: number;
    condition?: 'NEW_OEM' | 'NEW_AFTERMARKET' | 'USED';
    modelIds?: string[];
    brand?: string;
    warranty?: number;
  },
): Promise<{ id: string; version: number; part_id: string }> {
  const part = {
    name_ar: opts.name,
    category_id: await categoryId(tx, opts.category),
    ...(opts.modelIds ? { model_ids: opts.modelIds } : {}),
  };
  const [row] = await tx<{ r: { id: string; version: number; part_id: string } }[]>`
    select public.shop_upsert_listing(
      p_shop_id => ${shopId},
      p_condition => ${opts.condition ?? 'NEW_AFTERMARKET'}::public.listing_condition,
      p_stock_qty => ${opts.qty ?? 5},
      p_price_sdg => ${opts.price ?? 10000},
      p_warranty_days => ${opts.warranty ?? 0},
      p_brand => ${opts.brand ?? null},
      p_new_part => ${tx.json(part as never)}
    ) as r`;
  return must(row).r;
}
