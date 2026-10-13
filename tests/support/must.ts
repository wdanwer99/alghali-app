/** The value, or a test failure saying what was missing (instead of a `!` assertion). */
export function must<T>(value: T | null | undefined, what = 'value'): T {
  if (value === null || value === undefined) throw new Error(`expected ${what}, got ${value}`);
  return value;
}
