import 'server-only';
import type { Supabase } from '@/lib/supabase/server';
import { must } from './util';

export type AlertApp = 'buyer' | 'partner' | 'admin';

export type Wording = { title: string; body: string };

export type AlertWording = {
  code: string;
  app: AlertApp;
  /** Also sent by SMS once a provider exists (D-061). */
  sms: boolean;
  ar: Wording;
  en: Wording;
  /** `{name}` placeholders the current wording uses: the data each alert carries. */
  placeholders: string[];
};

const placeholdersIn = (s: string) => [...s.matchAll(/\{([a-z_]+)\}/g)].map((m) => m[1] as string);

/** Every alert code with its Arabic and English wording (what push and the inboxes show). */
export async function loadAlertWording(supabase: Supabase): Promise<AlertWording[]> {
  const [codes, templates] = await Promise.all([
    supabase.from('notification_codes').select('code, app, sms').order('code').then(must),
    supabase.from('notification_templates').select('code, locale, title, body').then(must),
  ]);
  const byKey = new Map(templates.map((t) => [`${t.code}:${t.locale}`, t]));
  const order: AlertApp[] = ['buyer', 'partner', 'admin'];
  return codes
    .map((c) => {
      const ar = byKey.get(`${c.code}:ar`);
      const en = byKey.get(`${c.code}:en`);
      const text = [ar?.title, ar?.body, en?.title, en?.body].join(' ');
      return {
        code: c.code,
        app: c.app as AlertApp,
        sms: c.sms,
        ar: { title: ar?.title ?? '', body: ar?.body ?? '' },
        en: { title: en?.title ?? '', body: en?.body ?? '' },
        placeholders: [...new Set(placeholdersIn(text))],
      };
    })
    .sort((a, b) => order.indexOf(a.app) - order.indexOf(b.app) || a.code.localeCompare(b.code));
}
