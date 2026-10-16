// POST /functions/v1/notify-dispatch — called once a minute by pg_cron (through pg_net)
// when pushes are waiting, with `Authorization: Bearer <NOTIFY_DISPATCH_TOKEN>`. Deployed
// without JWT verification; the shared token is checked here instead.
//
// Claims due pushes (notify_claim), words them in the reader's language, sends them by
// FCM, and reports each result (notify_report), which retries failures with backoff.
// Without the FCM_SERVICE_ACCOUNT_B64 secret every push is recorded as a STUB (D-061); a
// secret that isn't a readable key fails every push with FCM_ACCOUNT_UNREADABLE (D-146).
import { createClient } from 'npm:@supabase/supabase-js@2.117.3';
import { accessToken, sendPush, serviceAccountFrom } from '../_shared/notify/fcm.ts';
import { dataOf, render, retryable, type Locale } from '../_shared/notify/render.ts';

interface Claimed {
  id: string;
  target: string;
  locale: Locale;
  code: string;
  title: string;
  body: string;
  payload: Record<string, unknown>;
}

function serviceKey(): string | undefined {
  const legacy = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (legacy) return legacy;
  try {
    const keys = JSON.parse(Deno.env.get('SUPABASE_SECRET_KEYS') ?? '{}') as Record<string, string>;
    return keys.default ?? Object.values(keys)[0];
  } catch {
    return undefined;
  }
}

const json = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } });

Deno.serve(async (req) => {
  const expected = Deno.env.get('NOTIFY_DISPATCH_TOKEN');
  if (!expected || req.headers.get('Authorization') !== `Bearer ${expected}`) {
    return json(401, { error: 'NOT_AUTHENTICATED' });
  }
  const key = serviceKey();
  if (!key) return json(500, { error: 'NO_SERVICE_KEY' });
  const db = createClient(Deno.env.get('SUPABASE_URL')!, key, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const account = serviceAccountFrom((name) => Deno.env.get(name));
  const sa = typeof account === 'string' ? null : account;
  let token: string | null = null;
  let sent = 0;
  for (let round = 0; round < 5; round++) {
    const { data, error } = await db.rpc('notify_claim', { p_limit: 100 });
    if (error) return json(500, { error: error.message });
    const batch = (data ?? []) as Claimed[];
    if (batch.length === 0) break;

    const results: Record<string, unknown>[] = [];
    if (account === 'missing') {
      for (const c of batch)
        results.push({ id: c.id, ok: false, stub: true, error: 'NO_FCM_ACCOUNT' });
    } else if (!sa) {
      // Retried, so the pushes go out once the key is installed again.
      for (const c of batch)
        results.push({ id: c.id, ok: false, retry: true, error: 'FCM_ACCOUNT_UNREADABLE' });
    } else {
      try {
        token ??= await accessToken(sa);
      } catch (e) {
        for (const c of batch) results.push({ id: c.id, ok: false, retry: true, error: String(e) });
      }
      if (token) {
        for (const c of batch) {
          try {
            const r = await sendPush(sa, token, {
              token: c.target,
              title: render(c.title, c.payload, c.locale),
              body: render(c.body, c.payload, c.locale),
              data: dataOf(c.code, c.payload),
            });
            results.push(
              r.ok
                ? { id: c.id, ok: true, provider_ref: r.name }
                : {
                    id: c.id,
                    ok: false,
                    retry: retryable(r.httpStatus, r.fcmStatus),
                    error: r.fcmStatus ?? `HTTP_${r.httpStatus}`,
                  },
            );
          } catch (e) {
            results.push({ id: c.id, ok: false, retry: true, error: String(e) });
          }
        }
      }
    }
    const { error: reportError } = await db.rpc('notify_report', { p_results: results });
    if (reportError) return json(500, { error: reportError.message });
    sent += results.filter((r) => r.ok).length;
    if (batch.length < 100) break;
  }
  return json(200, {
    ok: true,
    sent,
    fcm: sa !== null,
    account: typeof account === 'string' ? account : 'ok',
  });
});
