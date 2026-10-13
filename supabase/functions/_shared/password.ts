/**
 * The password rule set in the hosted auth settings (D-073): 8–72 characters,
 * with at least one letter and one digit (Arabic letters and digits count).
 * The admin console checks the same rule before sending (apps/admin/src/lib/password.ts).
 */
export function strongEnough(password: string): boolean {
  return (
    password.length >= 8 &&
    password.length <= 72 &&
    /\p{L}/u.test(password) &&
    /\p{Nd}/u.test(password)
  );
}
