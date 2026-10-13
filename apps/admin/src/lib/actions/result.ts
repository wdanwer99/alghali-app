import 'server-only';
import { refresh } from 'next/cache';

/** `error` is the backend's machine code (D-069); the client translates it. */
export type ActionResult = { ok: true } | { ok: false; error: string };

export const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export const fail = (error: string): ActionResult => ({ ok: false, error });

export function code(error: { message: string; code?: string }): string {
  if (/^[A-Z][A-Z_]+$/.test(error.message)) return error.message;
  if (error.code === '42501') return 'FORBIDDEN';
  return 'FAILED';
}

/** Turns a Supabase error into a result; on success re-renders the page with fresh data. */
export function done(error: { message: string; code?: string } | null): ActionResult {
  if (error) return fail(code(error));
  refresh();
  return { ok: true };
}
