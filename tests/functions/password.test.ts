import { describe, expect, it } from 'vitest';
import { strongEnough } from '../../supabase/functions/_shared/password.ts';
import { strongEnough as consoleRule } from '../../apps/admin/src/lib/password.ts';

describe('temporary password rule (D-073)', () => {
  const cases: [string, boolean][] = [
    ['abc12345', true],
    ['كلمة1234', true],
    ['abcd١٢٣٤', true],
    ['abc1234', false], // 7 characters
    ['abcdefgh', false], // no digit
    ['12345678', false], // no letter
    ['a1'.repeat(36) + 'x', false], // 73 characters
  ];

  it.each(cases)('%s → %s', (password, ok) => {
    expect(strongEnough(password)).toBe(ok);
  });

  it('the admin console checks the same rule before sending', () => {
    for (const [password] of cases) expect(consoleRule(password)).toBe(strongEnough(password));
  });
});
