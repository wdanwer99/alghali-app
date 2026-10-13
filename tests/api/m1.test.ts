import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import * as XLSX from '../../supabase/functions/_shared/vendor/sheetjs/xlsx.mjs';
import { TEMPLATE_HEADERS } from '../../supabase/functions/_shared/inventory/parse.ts';
import { anonClient, api, apiSkipReason, Fixtures, hasApi } from '../support/api.ts';
import { must } from '../support/db.ts';

const XLSX_MIME = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

function sheet(rows: unknown[][]): Uint8Array {
  const book = XLSX.utils.book_new();
  XLSX.utils.book_append_sheet(
    book,
    XLSX.utils.aoa_to_sheet([[...TEMPLATE_HEADERS], ...rows]),
    'المخزون',
  );
  return new Uint8Array(XLSX.write(book, { type: 'array', bookType: 'xlsx' }) as ArrayBuffer);
}

describe.skipIf(!hasApi)('M1 over HTTP', () => {
  let f: Fixtures;
  beforeAll(() => {
    f = new Fixtures();
  });
  afterAll(() => f.cleanup());

  describe('auth', () => {
    it('sign-up returns a session and fills the profile from the sign-up form', async () => {
      const client = anonClient();
      const email = `signup-${crypto.randomUUID().slice(0, 12)}@test.alghali.invalid`;
      const { data, error } = await client.auth.signUp({
        email,
        password: 'abc12345',
        options: { data: { display_name: 'سارة', phone: '0912345678', locale: 'ar' } },
      });
      expect(error).toBeNull();
      f.track(must(data.user).id);
      expect(data.session).not.toBeNull(); // email confirmation is off (D-031)
      const me = await client.rpc('me');
      expect(me.data).toMatchObject({
        profile: { email, display_name: 'سارة', phone: '+249912345678' },
        roles: ['BUYER'],
        shops: [],
      });
    });

    it('enforces the password rule: 8+ characters with letters and digits', async () => {
      const { data, error } = await anonClient().auth.signUp({
        email: `weak-${crypto.randomUUID().slice(0, 8)}@test.alghali.invalid`,
        password: 'abcdefgh',
      });
      if (data.user) f.track(data.user.id);
      expect(error?.message).toMatch(/password/i);
    });

    it('rejects a wrong password', async () => {
      const u = await f.user();
      const { error } = await anonClient().auth.signInWithPassword({
        email: u.email,
        password: 'wrong-123',
      });
      expect(error).not.toBeNull();
    });
  });

  describe('row level security through PostgREST', () => {
    it('anon reads the catalogue and street, but no profiles or settings', async () => {
      const anon = anonClient();
      const zones = await anon.from('zones').select('seq').order('seq');
      expect(zones.data?.map((z) => z.seq)).toEqual([1, 2, 3, 4]);
      const makes = await anon.from('vehicle_makes').select('slug').eq('slug', 'toyota');
      expect(makes.data).toHaveLength(1);
      expect((await anon.from('profiles').select('id')).error?.code).toBe('42501');
      expect((await anon.from('app_settings').select('key')).error?.code).toBe('42501');
    });

    it('a user sees only their own profile and garage', async () => {
      const a = await f.user();
      const b = await f.user();
      const { data: variant } = await a.client
        .from('vehicle_variants')
        .select('id')
        .limit(1)
        .single();
      const car = await a.client
        .from('garage_vehicles')
        .insert({ variant_id: must(variant).id })
        .select()
        .single();
      expect(car.error).toBeNull();
      expect((await b.client.from('garage_vehicles').select('id')).data).toEqual([]);
      expect((await b.client.from('profiles').select('id')).data).toEqual([{ id: b.id }]);
    });

    it('RPC errors reach the app as machine codes', async () => {
      const u = await f.user();
      const { error } = await u.client.rpc('update_profile', { p_phone: '123' });
      expect(error).toMatchObject({ code: '22023', message: 'INVALID_PHONE' });
      const forbidden = await u.client.rpc('admin_settings');
      expect(forbidden.error).toMatchObject({ code: '42501', message: 'FORBIDDEN' });
    });
  });

  describe('storage', () => {
    it('shop members upload listing photos to their folder; strangers cannot', async () => {
      const { owner, shopId } = await f.shop();
      const stranger = await f.user();
      const path = `shops/${shopId}/listings/${crypto.randomUUID()}/thumb.webp`;
      const bytes = new Uint8Array([0x52, 0x49, 0x46, 0x46]);
      f.trackFile('media-public', path);

      const ok = await owner.client.storage
        .from('media-public')
        .upload(path, bytes, { contentType: 'image/webp' });
      expect(ok.error).toBeNull();
      const otherPath = `shops/${shopId}/listings/${crypto.randomUUID()}/thumb.webp`;
      const denied = await stranger.client.storage
        .from('media-public')
        .upload(otherPath, bytes, { contentType: 'image/webp' });
      expect(denied.error).not.toBeNull();

      const publicUrl = owner.client.storage.from('media-public').getPublicUrl(path).data.publicUrl;
      expect((await fetch(publicUrl)).status).toBe(200);
    });

    it('buckets refuse the wrong file types', async () => {
      const { owner, shopId } = await f.shop();
      const path = `shops/${shopId}/listings/${crypto.randomUUID()}/orig.jpg`;
      f.trackFile('media-public', path);
      const res = await owner.client.storage
        .from('media-public')
        .upload(path, new TextEncoder().encode('<script>'), { contentType: 'text/html' });
      expect(res.error).not.toBeNull();
    });

    it('stock sheets are private to the shop', async () => {
      const { owner, shopId } = await f.shop();
      const stranger = await f.user();
      const path = `${shopId}/${crypto.randomUUID()}.xlsx`;
      f.trackFile('imports', path);
      expect(
        (
          await owner.client.storage
            .from('imports')
            .upload(path, sheet([]), { contentType: XLSX_MIME })
        ).error,
      ).toBeNull();
      expect((await stranger.client.storage.from('imports').download(path)).error).not.toBeNull();
      expect((await anonClient().storage.from('imports').download(path)).error).not.toBeNull();
    });
  });

  describe('inventory-import Edge Function', () => {
    it('imports an uploaded sheet and reports the rows it skipped', async () => {
      const { owner, shopId } = await f.shop();
      const path = `${shopId}/${crypto.randomUUID()}.xlsx`;
      f.trackFile('imports', path);
      const file = sheet([
        [
          'IMP-1',
          'فحمات فرامل أمامية',
          'الفرامل',
          'أصلي',
          '65,000',
          10,
          '6 أشهر',
          'Toyota',
          'هايلكس',
          '04465-0K290',
        ],
        ['', 'زيت محرك 5W-30', 'الزيوت والفلاتر', 'جديد', 42000, 60, '', 'Shell', '', ''],
        ['', 'شيء', 'فئة غير موجودة', 'جديد', 100, 1, '', '', '', ''],
        ['', 'شيء آخر', 'الفرامل', 'ممتاز', 100, 1, '', '', '', ''],
      ]);
      expect(
        (await owner.client.storage.from('imports').upload(path, file, { contentType: XLSX_MIME }))
          .error,
      ).toBeNull();

      const dry = await owner.client.functions.invoke('inventory-import', {
        body: { shop_id: shopId, file_key: path, dry_run: true },
      });
      expect(dry.error).toBeNull();
      expect(dry.data).toMatchObject({ dry_run: true, created: 2, failed: 2 });

      const { data, error } = await owner.client.functions.invoke('inventory-import', {
        body: { shop_id: shopId, file_key: path, file_name: 'مخزون.xlsx' },
        headers: { 'Idempotency-Key': crypto.randomUUID() },
      });
      expect(error).toBeNull();
      expect(data).toMatchObject({
        total: 4,
        created: 2,
        updated: 0,
        failed: 2,
        errors: [
          { row: 4, code: 'CATEGORY_NOT_FOUND' },
          { row: 5, code: 'INVALID_CONDITION', column: 'condition' },
        ],
      });

      const found = await anonClient().rpc('search_parts', { p_q: 'فحمات', p_shop_id: shopId });
      expect(found.data).toEqual([
        expect.objectContaining({ name_ar: 'فحمات فرامل أمامية', from_sdg: 65000 }),
      ]);
    });

    it('refuses callers who are not signed in or not in the shop', async () => {
      const { shopId } = await f.shop();
      const stranger = await f.user();
      const body = { shop_id: shopId, file_key: `${shopId}/x.xlsx` };

      const anonRes = await fetch(`${api.url}/functions/v1/inventory-import`, {
        method: 'POST',
        headers: { apikey: api.publishableKey, 'Content-Type': 'application/json' },
        body: JSON.stringify(body),
      });
      expect(anonRes.status).toBe(401);

      const res = await stranger.client.functions.invoke('inventory-import', { body });
      expect(res.error).not.toBeNull();
      const status = (res.error as { context?: Response }).context?.status;
      expect([403, 404]).toContain(status);
    });
  });
});

describe.runIf(!hasApi)('M1 over HTTP (skipped)', () => {
  it.skip(apiSkipReason, () => undefined);
});
