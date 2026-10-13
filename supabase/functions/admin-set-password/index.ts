// POST /functions/v1/admin-set-password
// Body: { user_id, password }. Called by the admin console with the admin's session.
// An admin gives a temporary password to a user who called support (D-064). The
// caller's role is checked with their own token; only then is the service key used,
// and only for this one change. The change is written to the audit log (never the
// password itself).
import { createClient } from 'npm:@supabase/supabase-js@2.117.3';
import { strongEnough } from '../_shared/password.ts';

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, apikey, content-type, x-client-info',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function reply(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, 'Content-Type': 'application/json; charset=utf-8' },
  });
}

function serviceKey(): string | undefined {
  const legacy = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (legacy) return legacy;
  // Newer projects expose named secret keys as JSON: {"default": "sb_secret_…"}.
  try {
    const keys = JSON.parse(Deno.env.get('SUPABASE_SECRET_KEYS') ?? '{}') as Record<string, string>;
    return keys.default ?? Object.values(keys)[0];
  } catch {
    return undefined;
  }
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response(null, { headers: cors });
  if (req.method !== 'POST') return reply(405, { error: 'METHOD_NOT_ALLOWED' });

  const authorization = req.headers.get('Authorization');
  const apikey = req.headers.get('apikey') ?? Deno.env.get('SUPABASE_ANON_KEY') ?? '';
  if (!authorization) return reply(401, { error: 'NOT_AUTHENTICATED' });

  let body: { user_id?: unknown; password?: unknown };
  try {
    body = await req.json();
  } catch {
    return reply(400, { error: 'INVALID_BODY' });
  }
  const userId = typeof body.user_id === 'string' ? body.user_id : '';
  const password = typeof body.password === 'string' ? body.password : '';
  if (!UUID.test(userId)) return reply(400, { error: 'INVALID_BODY' });
  if (!strongEnough(password)) return reply(400, { error: 'WEAK_PASSWORD' });

  const url = Deno.env.get('SUPABASE_URL')!;
  const caller = createClient(url, apikey, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: me, error: meError } = await caller.auth.getUser();
  if (meError || !me.user) return reply(401, { error: 'NOT_AUTHENTICATED' });
  const { data: isAdmin, error: roleError } = await caller.rpc('is_admin');
  if (roleError || isAdmin !== true) return reply(403, { error: 'FORBIDDEN' });

  const key = serviceKey();
  if (!key) return reply(500, { error: 'NOT_CONFIGURED' });
  const admin = createClient(url, key, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { error } = await admin.auth.admin.updateUserById(userId, { password });
  if (error) {
    if (error.status === 404) return reply(404, { error: 'USER_NOT_FOUND' });
    if (error.code === 'weak_password') return reply(400, { error: 'WEAK_PASSWORD' });
    return reply(500, { error: 'FAILED' });
  }
  await admin.from('audit_log').insert({
    actor_id: me.user.id,
    action: 'SET_PASSWORD',
    entity: 'user',
    entity_id: userId,
  });
  return reply(200, { ok: true });
});
