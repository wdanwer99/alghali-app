// `pnpm buyer:e2e [-- -d <device>]`: the buyer's happy path on a running emulator or
// phone, against alghali-dev (apps/buyer/integration_test/journey_test.dart). Signs in as
// a demo buyer; the account comes from .env through a temporary defines file, so it never
// shows on a command line. Needs the demo data (pnpm db:seed:dev).
import { spawnSync } from 'node:child_process';
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { readEnvFile } from './lib/env.mjs';
import { root } from './lib/paths.mjs';

const env = readEnvFile(join(root, '.env')) ?? {};
if (!env.DEMO_PASSWORD) {
  console.error('DEMO_PASSWORD is not set in .env (the demo accounts come from pnpm db:seed:dev).');
  process.exit(1);
}
const app = join(root, 'apps', 'buyer');
const defines = JSON.parse(readFileSync(join(app, 'env', 'dev.json'), 'utf8'));
const dir = mkdtempSync(join(tmpdir(), 'alghali-e2e-'));
const file = join(dir, 'defines.json');
try {
  writeFileSync(
    file,
    JSON.stringify({
      ...defines,
      E2E_EMAIL: 'buyer.omer@demo.alghali.invalid',
      E2E_PASSWORD: env.DEMO_PASSWORD,
    }),
    { mode: 0o600 },
  );
  const r = spawnSync(
    'flutter',
    [
      'test',
      'integration_test/journey_test.dart',
      `--dart-define-from-file=${file}`,
      ...process.argv.slice(2).filter((a) => a !== '--'),
    ],
    { cwd: app, stdio: 'inherit', shell: true },
  );
  process.exitCode = r.status ?? 1;
} finally {
  rmSync(dir, { recursive: true, force: true });
  // The test build lists the integration_test plugin here; a release build that reuses
  // the file fails, and Flutter writes it again when it is missing.
  rmSync(join(app, 'android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java'), {
    force: true,
  });
}
