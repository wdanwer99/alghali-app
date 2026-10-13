import type { Locale } from '@/i18n/config';

/** Text stored in both languages (`*_ar` / `*_en` columns). */
export type Named = { ar: string; en: string };

export const named = (n: Named, locale: Locale) => n[locale] || n.ar;

/** Unwraps a Supabase result, throwing on error so the page's error boundary shows it. */
export function must<T>({ data, error }: { data: T | null; error: { message: string } | null }): T {
  if (error) throw new Error(error.message);
  return data as T;
}
