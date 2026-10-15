import { expect, type Page } from '@playwright/test';
import ar from '../src/i18n/dictionaries/ar.json' with { type: 'json' };
import en from '../src/i18n/dictionaries/en.json' with { type: 'json' };

export const dictionaries = { ar, en } as const;
export type Locale = keyof typeof dictionaries;

/** Actions that change data run only against a throwaway stack (CI), never against dev. */
export const writes = process.env.E2E_WRITES === '1';

/**
 * Opens a console page and waits until its data has streamed in: the header is there,
 * the loading skeleton is gone, and no error panel showed.
 */
export async function openPage(page: Page, locale: Locale, path: string, title: string) {
  const errors: string[] = [];
  page.on('pageerror', (e) => errors.push(e.message));
  await page.goto(`/${locale}${path}`);
  await expect(page.locator('html')).toHaveAttribute('dir', locale === 'ar' ? 'rtl' : 'ltr');
  await expect(page.locator('html')).toHaveAttribute('lang', locale);
  await expect(page.getByRole('heading', { level: 1, name: title, exact: true })).toBeVisible();
  await expect(page.locator('[aria-busy="true"]')).toHaveCount(0);
  await expect(page.getByText(dictionaries[locale].common.errorTitle)).toHaveCount(0);
  return errors;
}
