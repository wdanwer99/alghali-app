import { defineConfig, devices } from '@playwright/test';

/**
 * Browser smoke tests for every console page and queue (PLAN §2 M6), in Arabic and English.
 * Locally `pnpm admin:e2e` runs them against alghali-dev, reading only; CI runs them against
 * its throwaway local stack with the demo data, where they also act (E2E_WRITES=1).
 */
// A dev server already running (pnpm dev, port 3000) is reused; Next allows one per folder.
const port = Number(process.env.E2E_PORT ?? 3100);

export default defineConfig({
  testDir: './e2e',
  timeout: 180_000,
  // A dev server compiles each page on its first visit.
  expect: { timeout: 60_000 },
  workers: 1,
  retries: process.env.CI ? 1 : 0,
  reporter: process.env.CI ? 'github' : 'list',
  use: { baseURL: `http://localhost:${port}`, trace: 'retain-on-failure' },
  projects: [
    { name: 'setup', testMatch: /auth\.setup\.ts/ },
    {
      name: 'console',
      dependencies: ['setup'],
      testIgnore: /auth\.setup\.ts/,
      use: { ...devices['Desktop Chrome'], storageState: 'e2e/.auth/admin.json' },
    },
  ],
  webServer: {
    command:
      process.env.E2E_SERVER === 'start'
        ? `pnpm exec next start -p ${port}`
        : `pnpm exec next dev -p ${port}`,
    url: `http://localhost:${port}/ar/login`,
    reuseExistingServer: !process.env.CI,
    timeout: 240_000,
  },
});
