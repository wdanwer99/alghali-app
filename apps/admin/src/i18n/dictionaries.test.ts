import { describe, expect, it } from 'vitest';
import { defaultLocale, dirOf, isLocale } from './config';
import ar from './dictionaries/ar.json';
import en from './dictionaries/en.json';

/** Lists every leaf key path, e.g. "home.queue.payments". */
function keyPaths(value: unknown, prefix = ''): string[] {
  if (value === null || typeof value !== 'object') return [prefix];
  return Object.entries(value).flatMap(([k, v]) => keyPaths(v, prefix ? `${prefix}.${k}` : k));
}

describe('admin i18n', () => {
  it('Arabic and English dictionaries have exactly the same keys', () => {
    expect(keyPaths(en).sort()).toEqual(keyPaths(ar).sort());
  });

  it('has no empty strings', () => {
    for (const dict of [ar, en]) {
      const leaves = keyPaths(dict).map((path) =>
        path.split('.').reduce<unknown>((node, k) => (node as Record<string, unknown>)[k], dict),
      );
      expect(leaves.every((v) => typeof v === 'string' && v.trim().length > 0)).toBe(true);
    }
  });

  it('defaults to Arabic, right-to-left', () => {
    expect(defaultLocale).toBe('ar');
    expect(dirOf('ar')).toBe('rtl');
    expect(dirOf('en')).toBe('ltr');
    expect(isLocale('fr')).toBe(false);
  });
});
