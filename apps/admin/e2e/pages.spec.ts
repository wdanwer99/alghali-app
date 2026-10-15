import { expect, test } from '@playwright/test';
import { dictionaries, openPage, type Locale } from './support';

/**
 * Every console page in Arabic (right to left) and English (left to right): the page and
 * its data load, the direction is right, and nothing throws in the browser.
 */
const PAGES = [
  ['', 'overview'],
  ['/reports', 'reports'],
  ['/approvals', 'approvals'],
  ['/shops', 'shops'],
  ['/payouts', 'payouts'],
  ['/users', 'users'],
  ['/catalogue', 'catalogue'],
  ['/street', 'street'],
  ['/alerts', 'alerts'],
  ['/settings', 'settings'],
  ['/payments', 'payments'],
  ['/orders', 'orders'],
  ['/bookings', 'bookings'],
  ['/cash', 'cash'],
  ['/disputes', 'disputes'],
] as const;

for (const locale of ['ar', 'en'] as Locale[]) {
  const d = dictionaries[locale];
  for (const [path, key] of PAGES) {
    test(`${key} (${locale})`, async ({ page }) => {
      const errors = await openPage(page, locale, path, d[key].title);
      expect(errors).toEqual([]);
    });
  }

  test(`orders and bookings open their detail pages (${locale})`, async ({ page }) => {
    for (const [path, key] of [
      ['/orders', 'orders'],
      ['/bookings', 'bookings'],
    ] as const) {
      const errors = await openPage(page, locale, path, d[key].title);
      const first = page.locator(`main a[href*="/${locale}${path}/"]`).first();
      if ((await first.count()) === 0) continue; // nothing to open on this stack
      await first.click();
      await expect(page).toHaveURL(new RegExp(`/${locale}${path}/[0-9a-f-]{36}`));
      await expect(page.locator('[aria-busy="true"]')).toHaveCount(0);
      await expect(page.getByText(d.common.errorTitle)).toHaveCount(0);
      expect(errors).toEqual([]);
    }
  });
}

test('reports: another period, and the CSV download', async ({ page }) => {
  const d = dictionaries.en;
  await openPage(page, 'en', '/reports', d.reports.title);
  await page.getByRole('link', { name: d.reports.lastDays.replace('{n}', '7') }).click();
  await expect(page).toHaveURL(/days=7/);
  await expect(page.locator('[aria-busy="true"]')).toHaveCount(0);
  const download = page.waitForEvent('download');
  await page.getByRole('button', { name: d.reports.download }).click();
  expect((await download).suggestedFilename()).toMatch(
    /^alghali-report-\d{4}-\d{2}-\d{2}-\d{4}-\d{2}-\d{2}\.csv$/,
  );
  await page.getByRole('button', { name: d.reports.showTable }).click();
  await expect(page.getByRole('columnheader', { name: d.reports.colDay })).toBeVisible();
});

test('alert wording: search, and the edit dialog lists the placeholders', async ({ page }) => {
  const d = dictionaries.en;
  await openPage(page, 'en', '/alerts', d.alerts.title);
  await page.getByRole('searchbox', { name: d.alerts.search }).fill('NEW_ORDER');
  await expect(page.getByText('NEW_ORDER', { exact: true })).toBeVisible();
  await expect(page.getByText('PAYMENT_CONFIRMED', { exact: true })).toHaveCount(0);
  await page.getByRole('button', { name: `${d.common.edit} NEW_ORDER` }).click();
  await expect(page.getByRole('dialog')).toContainText('{ref}');
  await page.getByRole('button', { name: d.common.cancel }).click();
  await expect(page.getByRole('dialog')).toHaveCount(0);
});

test('cash: every partner row can be adjusted', async ({ page }) => {
  const d = dictionaries.en;
  await openPage(page, 'en', '/cash', d.cash.title);
  const rows = page.locator('main tbody tr');
  const adjust = page.getByRole('button', { name: new RegExp(`^${d.cash.adjust} `) });
  await expect(adjust).toHaveCount(await rows.count());
});

test('every page is sent with the browser protections (M7 security review)', async ({ page }) => {
  const res = await page.request.get('/ar/login');
  const h = res.headers();
  expect(h['x-frame-options']).toBe('DENY');
  expect(h['content-security-policy']).toContain("frame-ancestors 'none'");
  expect(h['x-content-type-options']).toBe('nosniff');
  expect(h['referrer-policy']).toBe('strict-origin-when-cross-origin');
  expect(h['x-powered-by']).toBeUndefined();
  // The admin's session can't be read by scripts in the page.
  const session = (await page.context().cookies()).filter((c) => c.name.startsWith('sb-'));
  expect(session.length).toBeGreaterThan(0);
  expect(session.every((c) => c.httpOnly)).toBe(true);
});

test.describe('signed out', () => {
  test.use({ storageState: { cookies: [], origins: [] } });

  for (const locale of ['ar', 'en'] as Locale[]) {
    test(`the app download page is open to everyone (${locale})`, async ({ page }) => {
      const d = dictionaries[locale].download;
      await page.goto(`/${locale}/download`);
      await expect(page).toHaveURL(new RegExp(`/${locale}/download$`));
      await expect(page.locator('html')).toHaveAttribute('dir', locale === 'ar' ? 'rtl' : 'ltr');
      await expect(page.getByRole('heading', { level: 1, name: d.title })).toBeVisible();
      // Each app: the download for this phone, or "coming soon" before the first release.
      for (const name of [d.buyerTitle, d.partnerTitle]) {
        const card = page.getByRole('region', { name });
        await expect(
          card.getByRole('link', { name: d.download }).or(card.getByText(d.soon)),
        ).toBeVisible();
      }
    });
  }

  test('the console itself still asks for sign-in', async ({ page }) => {
    await page.goto('/en/orders');
    await expect(page).toHaveURL(/\/en\/login/);
  });
});
