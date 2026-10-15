// `pnpm admin:e2e [-- <playwright args>]`: the admin console's browser smoke tests (apps/admin/e2e)
// against alghali-dev, signed in as the demo admin. Read-only here: the tests that change data
// run only in CI's throwaway stack (E2E_WRITES=1). The password goes through the environment,
// never the command line. Needs the demo data (pnpm db:seed:dev) and `npx playwright install chromium`.
import { spawnSync } from 'node:child_process';
import { rmSync } from 'node:fs';
import { join } from 'node:path';
import { readEnvFile } from './lib/env.mjs';
import { root } from './lib/paths.mjs';

const env = readEnvFile(join(root, '.env')) ?? {};
if (!env.DEMO_PASSWORD) {
  console.error('DEMO_PASSWORD is not set in .env (the demo accounts come from pnpm db:seed:dev).');
  process.exit(1);
}
// Next allows one dev server per folder: reuse `pnpm dev` (port 3000) when it is running.
const running = await fetch('http://localhost:3000/ar/login')
  .then((res) => res.ok)
  .catch(() => false);
const r = spawnSync(
  'pnpm',
  ['exec', 'playwright', 'test', ...process.argv.slice(2).filter((a) => a !== '--')],
  {
    cwd: join(root, 'apps', 'admin'),
    stdio: 'inherit',
    shell: true,
    env: {
      ...process.env,
      E2E_ADMIN_PASSWORD: env.DEMO_PASSWORD,
      E2E_WRITES: '',
      ...(running ? { E2E_PORT: '3000' } : {}),
    },
  },
);
process.exitCode = r.status ?? 1;
// Failure snapshots and traces record what was typed, the password included: read the
// failure in the output above, then they go.
for (const dir of ['test-results', 'playwright-report', 'e2e/.auth']) {
  rmSync(join(root, 'apps', 'admin', dir), { recursive: true, force: true });
}
