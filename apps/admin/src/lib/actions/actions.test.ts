import { readdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { describe, expect, it } from 'vitest';

/**
 * Server Actions are public endpoints: anyone can post to them, signed in or not. Each one
 * must check the admin itself before touching data (M7 security review), even though the
 * database checks again.
 */
const dir = import.meta.dirname;
const PUBLIC = ['auth.ts:signIn', 'auth.ts:signOut'];
/** Shared result helpers, not actions. */
const HELPERS = ['result.ts'];
const actionFiles = () =>
  readdirSync(dir).filter(
    (f) => f.endsWith('.ts') && !f.endsWith('.test.ts') && !HELPERS.includes(f),
  );

function actions(): { name: string; body: string }[] {
  return actionFiles().flatMap((file) =>
    readFileSync(join(dir, file), 'utf8')
      .split(/^(?=export async function )/m)
      .flatMap((part) => {
        const name = /^export async function (\w+)/.exec(part)?.[1];
        return name ? [{ name: `${file}:${name}`, body: part }] : [];
      }),
  );
}

describe('server actions', () => {
  it('every action checks the admin, except signing in and out', () => {
    const all = actions();
    expect(all.length).toBeGreaterThan(25);
    const unchecked = all.filter((a) => !a.body.includes('requireAdmin(')).map((a) => a.name);
    expect(unchecked.sort()).toEqual(PUBLIC);
  });

  it("every action file is a server-only 'use server' module", () => {
    for (const f of actionFiles()) {
      expect(readFileSync(join(dir, f), 'utf8').startsWith("'use server'"), f).toBe(true);
    }
  });
});
