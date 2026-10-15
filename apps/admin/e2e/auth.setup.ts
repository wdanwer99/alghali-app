import { expect, test as setup } from '@playwright/test';
import { dictionaries } from './support';

/** Signs in once as the demo admin; every other test reuses the session. */
setup('sign in as an admin', async ({ page }) => {
  const email = process.env.E2E_ADMIN_EMAIL ?? 'admin@demo.alghali.invalid';
  const password = process.env.E2E_ADMIN_PASSWORD;
  if (!password)
    throw new Error('E2E_ADMIN_PASSWORD is not set (pnpm admin:e2e reads it from .env).');
  const en = dictionaries.en;
  await page.goto('/en/login');
  await page.getByLabel(en.login.email).fill(email);
  await page.getByLabel(en.login.password, { exact: true }).fill(password);
  await page.getByRole('button', { name: en.login.submit, exact: true }).click();
  // A dev server compiles each page on its first visit: give it time.
  await expect(page.getByRole('heading', { level: 1, name: en.overview.title })).toBeVisible({
    timeout: 120_000,
  });
  await page.context().storageState({ path: 'e2e/.auth/admin.json' });
});
