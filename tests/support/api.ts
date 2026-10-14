import { join } from 'node:path';
import { createClient, type SupabaseClient } from '@supabase/supabase-js';
import { readEnvFile, supabaseTarget } from '../../infra/scripts/lib/env.mjs';
import { connect, type Sql, must } from './db.ts';

/**
 * End-to-end tests over HTTP, exactly as the apps call Supabase (Auth, PostgREST, Storage,
 * Edge Functions). CI sets API_URL / API_PUBLISHABLE_KEY / API_SECRET_KEY for the local
 * stack; locally they come from the alghali-test entries in the root .env.
 * These tests create real rows, so `Fixtures.cleanup()` deletes everything they made.
 */
function config() {
  const env = readEnvFile(join(import.meta.dirname, '../../.env')) ?? {};
  const test = supabaseTarget(env, 'TEST');
  return {
    url: process.env.API_URL ?? test.url,
    publishableKey: process.env.API_PUBLISHABLE_KEY ?? test.publishableKey,
    secretKey: process.env.API_SECRET_KEY ?? test.secretKey,
  };
}

export const api = config();
export const hasApi = Boolean(api.url && api.publishableKey && api.secretKey);
export const apiSkipReason =
  'No test API: set the SUPABASE_TEST_* URL and keys in .env (or API_* in CI) to run API tests.';

const noSession = {
  auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false },
};

export const anonClient = (): SupabaseClient =>
  createClient(api.url, api.publishableKey, noSession);

export interface TestUser {
  id: string;
  email: string;
  password: string;
  client: SupabaseClient;
}

export class Fixtures {
  readonly admin: SupabaseClient = createClient(api.url, api.secretKey, noSession);
  readonly sql: Sql = connect();
  private readonly users: string[] = [];
  private readonly files: [bucket: string, path: string][] = [];

  /** A confirmed account, signed in on its own client. */
  async user(meta: Record<string, unknown> = {}): Promise<TestUser> {
    const email = `api-${crypto.randomUUID().slice(0, 12)}@test.alghali.invalid`;
    const password = `Pw-${crypto.randomUUID()}1`;
    const { data, error } = await this.admin.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: meta,
    });
    if (error || !data.user) throw error ?? new Error('createUser failed');
    this.users.push(data.user.id);
    const client = anonClient();
    const signIn = await client.auth.signInWithPassword({ email, password });
    if (signIn.error) throw signIn.error;
    return { id: data.user.id, email, password, client };
  }

  /** Remembers an account created some other way (e.g. public sign-up) for cleanup. */
  track(userId: string): void {
    this.users.push(userId);
  }

  trackFile(bucket: string, path: string): void {
    this.files.push([bucket, path]);
  }

  /** An approved shop owned by a fresh user. */
  async shop(): Promise<{ owner: TestUser; shopId: string }> {
    const owner = await this.user();
    const { data: zone } = await owner.client
      .from('zones')
      .select('id')
      .order('seq')
      .limit(1)
      .single();
    const { data, error } = await owner.client.rpc('apply_as_shop', {
      p_name_ar: 'محل اختبار',
      p_zone_id: must(zone).id,
      p_phone: '0912345678',
    });
    if (error) throw error;
    const shopId = (data as { id: string }).id;
    await this
      .sql`update public.shops set status = 'APPROVED', approved_at = now() where id = ${shopId}`;
    return { owner, shopId };
  }

  /**
   * An approved technician (bay and mobile) with a fresh account: LIGHTING at 6,000,
   * every day all day, home at the street's starting point, bay at a fresh shop.
   */
  async technician(): Promise<{ user: TestUser; techId: string; bayShopId: string }> {
    const user = await this.user({ phone: '0911111111', display_name: 'الفني عمر' });
    const { shopId } = await this.shop();
    const [t] = await this.sql<{ id: string }[]>`
      insert into public.technicians (user_id, status, work_mode, home_bay_shop_id, home_lat, home_lng, radius_km, approved_at)
      values (${user.id}, 'APPROVED', 'BOTH', ${shopId}, 15.6, 32.5, 10, now()) returning id`;
    const techId = must(t).id;
    await this.sql`
      insert into public.technician_job_types (technician_id, job_type_id, labour_sdg)
      select ${techId}, id, 6000 from public.job_types where code = 'LIGHTING'`;
    await this.sql`
      insert into public.availability_rules (technician_id, weekday, start_min, end_min)
      select ${techId}, d, 0, 1440 from generate_series(0, 6) d`;
    await this
      .sql`insert into public.user_roles (user_id, role) values (${user.id}, 'TECHNICIAN') on conflict do nothing`;
    await this.sql`select public.tech_account(${techId})`;
    return { user, techId, bayShopId: shopId };
  }

  async cleanup(): Promise<void> {
    if (this.files.length) {
      const byBucket = new Map<string, string[]>();
      for (const [bucket, path] of this.files)
        byBucket.set(bucket, [...(byBucket.get(bucket) ?? []), path]);
      for (const [bucket, paths] of byBucket) await this.admin.storage.from(bucket).remove(paths);
    }
    if (this.users.length) {
      const shops = await this.sql<{ id: string }[]>`
        select distinct shop_id as id from public.shop_members where user_id = any (${this.users}::uuid[])`;
      const shopIds = shops.map((s) => s.id);
      // Orders first (they point at shops, listings and buyers); the ledger keeps its
      // history, since journals hold ids without foreign keys.
      await this.sql`
        delete from public.orders
        where buyer_id = any (${this.users}::uuid[])
           or id in (select order_id from public.sub_orders where shop_id = any (${shopIds}::uuid[]))`;
      await this.sql`
        delete from public.bookings
        where buyer_id = any (${this.users}::uuid[])
           or technician_id in (select id from public.technicians where user_id = any (${this.users}::uuid[]))`;
      await this.sql`delete from public.technicians where user_id = any (${this.users}::uuid[])`;
      await this.sql`delete from public.listings where shop_id = any (${shopIds}::uuid[])`;
      await this.sql`delete from public.parts where created_by_shop_id = any (${shopIds}::uuid[])`;
      await this.sql`delete from public.shops where id = any (${shopIds}::uuid[])`;
      for (const id of this.users) await this.admin.auth.admin.deleteUser(id);
    }
    await this.sql.end();
  }
}
