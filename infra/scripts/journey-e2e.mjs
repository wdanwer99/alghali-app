// `pnpm journey:e2e [-- -d <device>]`: the acceptance journey (brief §12) on a running
// emulator or phone, against alghali-test with fresh accounts that are deleted afterwards
// (tests/device/acceptance.device.ts drives the buyer and partner apps' device tests).
import { spawnSync } from 'node:child_process';
import { join } from 'node:path';
import { root } from './lib/paths.mjs';

const args = process.argv.slice(2).filter((a) => a !== '--');
const i = args.indexOf('-d');
const device = i >= 0 ? args[i + 1] : undefined;
const r = spawnSync('pnpm', ['exec', 'vitest', 'run', '--config', 'vitest.device.config.ts'], {
  cwd: join(root, 'tests'),
  stdio: 'inherit',
  shell: true,
  env: { ...process.env, ...(device ? { E2E_DEVICE: device } : {}) },
});
process.exitCode = r.status ?? 1;
