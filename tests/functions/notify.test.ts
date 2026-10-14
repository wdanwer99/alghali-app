import type { webcrypto } from 'node:crypto';
import { describe, expect, it } from 'vitest';
import {
  accessToken,
  sendPush,
  signedAssertion,
  type ServiceAccount,
} from '../../supabase/functions/_shared/notify/fcm.ts';
import {
  dataOf,
  money,
  render,
  retryable,
  when,
} from '../../supabase/functions/_shared/notify/render.ts';

describe('push wording', () => {
  it('money and times read the way the apps show them, with Western digits (D-048)', () => {
    expect(money(12000, 'ar')).toBe('12,000 ج.س');
    expect(money(12000, 'en')).toBe('SDG 12,000');
    // 14:00 UTC is 4 pm in Khartoum, Thursday 15 October 2026.
    expect(when('2026-10-15T14:00:00Z', 'ar')).toBe('الخميس 15 أكتوبر 4:00 م');
    expect(when('2026-10-15T14:00:00Z', 'en')).toBe('Thu 15 Oct 4:00 PM');
    expect(when('2026-10-15T22:30:00Z', 'en')).toBe('Fri 16 Oct 12:30 AM');
  });

  it('fills placeholders from the payload and drops the ones it has no value for', () => {
    const payload = {
      ref: '12345678',
      start_at: '2026-10-15T14:00:00Z',
      amount_sdg: 2500,
      nested: { x: 1 },
    };
    expect(render('تركيب {ref} يوم {start_at}.', payload, 'ar')).toBe(
      'تركيب 12345678 يوم الخميس 15 أكتوبر 4:00 م.',
    );
    expect(render('We sent you {amount_sdg}, transaction {txn}.', payload, 'en')).toBe(
      'We sent you SDG 2,500, transaction.',
    );
    expect(render('{nested} {ref}', payload, 'en')).toBe('12345678');
  });

  it('push data carries the code and the plain payload values as strings', () => {
    expect(
      dataOf('NEW_ORDER', { ref: '1', amount_sdg: 5, ok: true, nested: {}, gone: null }),
    ).toEqual({
      code: 'NEW_ORDER',
      ref: '1',
      amount_sdg: '5',
      ok: 'true',
    });
  });

  it('only server trouble is retried; a dead token is not', () => {
    expect(retryable(503)).toBe(true);
    expect(retryable(429)).toBe(true);
    expect(retryable(404, 'UNREGISTERED')).toBe(false);
    expect(retryable(400, 'INVALID_ARGUMENT')).toBe(false);
    expect(retryable(401)).toBe(false);
  });
});

describe('FCM client', () => {
  async function account(): Promise<{ sa: ServiceAccount; publicKey: webcrypto.CryptoKey }> {
    const pair = await crypto.subtle.generateKey(
      {
        name: 'RSASSA-PKCS1-v1_5',
        modulusLength: 2048,
        publicExponent: new Uint8Array([1, 0, 1]),
        hash: 'SHA-256',
      },
      true,
      ['sign', 'verify'],
    );
    const der = new Uint8Array(await crypto.subtle.exportKey('pkcs8', pair.privateKey));
    const pem = `-----BEGIN PRIVATE KEY-----\n${btoa(String.fromCharCode(...der))}\n-----END PRIVATE KEY-----\n`;
    return {
      sa: {
        project_id: 'alghali-test',
        client_email: 'push@alghali-test.iam.gserviceaccount.com',
        private_key: pem,
      },
      publicKey: pair.publicKey,
    };
  }

  it('signs the token request with the service account key (RS256)', async () => {
    const { sa, publicKey } = await account();
    const jwt = await signedAssertion(sa, 1_800_000_000);
    const [h, c, s] = jwt.split('.') as [string, string, string];
    const decode = (x: string) => JSON.parse(Buffer.from(x, 'base64url').toString());
    expect(decode(h)).toEqual({ alg: 'RS256', typ: 'JWT' });
    expect(decode(c)).toMatchObject({
      iss: sa.client_email,
      scope: 'https://www.googleapis.com/auth/firebase.messaging',
      iat: 1_800_000_000,
      exp: 1_800_003_600,
    });
    const ok = await crypto.subtle.verify(
      'RSASSA-PKCS1-v1_5',
      publicKey,
      Buffer.from(s, 'base64url'),
      new TextEncoder().encode(`${h}.${c}`),
    );
    expect(ok).toBe(true);
  });

  it('exchanges it for an access token, then sends a high-priority push', async () => {
    const { sa } = await account();
    const calls: { url: string; body: string }[] = [];
    const fake = (async (url: string | URL | Request, init?: RequestInit) => {
      calls.push({ url: String(url), body: String(init?.body) });
      if (String(url).includes('oauth2'))
        return new Response(JSON.stringify({ access_token: 'ya29.x' }));
      return new Response(JSON.stringify({ name: 'projects/alghali-test/messages/1' }));
    }) as typeof fetch;
    const token = await accessToken(sa, fake);
    expect(token).toBe('ya29.x');
    const r = await sendPush(
      sa,
      token,
      { token: 'device', title: 'T', body: 'B', data: { code: 'X' } },
      fake,
    );
    expect(r).toEqual({
      ok: true,
      httpStatus: 200,
      fcmStatus: undefined,
      name: 'projects/alghali-test/messages/1',
    });
    expect(calls[1]?.url).toBe('https://fcm.googleapis.com/v1/projects/alghali-test/messages:send');
    expect(JSON.parse(calls[1]?.body ?? '{}').message).toMatchObject({
      token: 'device',
      notification: { title: 'T', body: 'B' },
      android: { priority: 'high' },
    });
  });

  it('reports FCM’s error code for a dead token', async () => {
    const { sa } = await account();
    const fake = (async () =>
      new Response(
        JSON.stringify({
          error: { status: 'NOT_FOUND', details: [{ errorCode: 'UNREGISTERED' }] },
        }),
        { status: 404 },
      )) as typeof fetch;
    const r = await sendPush(sa, 't', { token: 'd', title: 'T', body: 'B', data: {} }, fake);
    expect(r).toMatchObject({ ok: false, httpStatus: 404, fcmStatus: 'UNREGISTERED' });
  });
});
