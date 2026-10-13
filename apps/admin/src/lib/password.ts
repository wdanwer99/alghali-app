/**
 * Twin of supabase/functions/_shared/password.ts (D-073), so the console can say
 * "too weak" before calling the server; tests/functions/password.test.ts keeps
 * the two in step.
 */
export function strongEnough(password: string): boolean {
  return (
    password.length >= 8 &&
    password.length <= 72 &&
    /\p{L}/u.test(password) &&
    /\p{Nd}/u.test(password)
  );
}

const LETTERS = 'abcdefghjkmnpqrstuvwxyz';
const DIGITS = '23456789';

/** Easy to read out over the phone: 4 letters + 4 digits, no look-alikes (l/1, o/0). */
export function temporaryPassword(): string {
  const pick = (set: string, n: number) =>
    Array.from(crypto.getRandomValues(new Uint32Array(n)), (x) => set[x % set.length]).join('');
  return pick(LETTERS, 4) + pick(DIGITS, 4);
}
