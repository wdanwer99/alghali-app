// Firebase Cloud Messaging (HTTP v1) with a service account, using only Web Crypto so it
// runs in Edge Functions without extra packages. The service account JSON comes from the
// FCM_SERVICE_ACCOUNT_B64 secret (D-061, D-146); without it the dispatcher records pushes as
// stubs.

export interface ServiceAccount {
  project_id: string;
  client_email: string;
  private_key: string;
  token_uri?: string;
}

/**
 * The service account from the function's secrets, or why there is none: `missing` (not set
 * up: pushes are stubs) or `unreadable` (set, but not a key: an error to fix, D-146).
 * The key is stored base64-encoded (`FCM_SERVICE_ACCOUNT_B64`): as raw JSON in an env file,
 * the `\n`s of its private key came back as real line breaks and the JSON no longer parsed.
 */
export function serviceAccountFrom(
  get: (name: string) => string | undefined,
): ServiceAccount | 'missing' | 'unreadable' {
  const b64 = get('FCM_SERVICE_ACCOUNT_B64');
  const raw = get('FCM_SERVICE_ACCOUNT');
  if (!b64 && !raw) return 'missing';
  try {
    const text = b64
      ? new TextDecoder().decode(Uint8Array.from(atob(b64), (c) => c.charCodeAt(0)))
      : raw!;
    const sa = JSON.parse(text) as ServiceAccount;
    return sa.project_id && sa.client_email && sa.private_key?.includes('PRIVATE KEY')
      ? sa
      : 'unreadable';
  } catch {
    return 'unreadable';
  }
}

export interface PushMessage {
  token: string;
  title: string;
  body: string;
  data: Record<string, string>;
}

export interface PushResult {
  ok: boolean;
  httpStatus: number;
  fcmStatus?: string;
  name?: string;
}

const b64url = (bytes: Uint8Array) =>
  btoa(String.fromCharCode(...bytes))
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/, '');
const b64urlText = (s: string) => b64url(new TextEncoder().encode(s));

function pemToDer(pem: string): ArrayBuffer {
  const body = pem.replace(/-----[^-]+-----/g, '').replace(/\s+/g, '');
  const bin = atob(body);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out.buffer;
}

/** A signed JWT asking Google for an FCM access token. */
export async function signedAssertion(
  sa: ServiceAccount,
  nowSec = Math.floor(Date.now() / 1000),
): Promise<string> {
  const header = b64urlText(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const claims = b64urlText(
    JSON.stringify({
      iss: sa.client_email,
      scope: 'https://www.googleapis.com/auth/firebase.messaging',
      aud: sa.token_uri ?? 'https://oauth2.googleapis.com/token',
      iat: nowSec,
      exp: nowSec + 3600,
    }),
  );
  const key = await crypto.subtle.importKey(
    'pkcs8',
    pemToDer(sa.private_key),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const sig = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key,
    new TextEncoder().encode(`${header}.${claims}`),
  );
  return `${header}.${claims}.${b64url(new Uint8Array(sig))}`;
}

export async function accessToken(
  sa: ServiceAccount,
  fetcher: typeof fetch = fetch,
): Promise<string> {
  const res = await fetcher(sa.token_uri ?? 'https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: await signedAssertion(sa),
    }),
  });
  if (!res.ok) throw new Error(`FCM_AUTH_${res.status}`);
  return ((await res.json()) as { access_token: string }).access_token;
}

export async function sendPush(
  sa: ServiceAccount,
  token: string,
  msg: PushMessage,
  fetcher: typeof fetch = fetch,
): Promise<PushResult> {
  const res = await fetcher(
    `https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`,
    {
      method: 'POST',
      headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        message: {
          token: msg.token,
          notification: { title: msg.title, body: msg.body },
          data: msg.data,
          android: { priority: 'high', notification: { channel_id: 'alerts' } },
        },
      }),
    },
  );
  const json = (await res.json().catch(() => ({}))) as {
    name?: string;
    error?: { status?: string; details?: { errorCode?: string }[] };
  };
  const fcmStatus = json.error?.details?.find((d) => d.errorCode)?.errorCode ?? json.error?.status;
  return { ok: res.ok, httpStatus: res.status, fcmStatus, name: json.name };
}
