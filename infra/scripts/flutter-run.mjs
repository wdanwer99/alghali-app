// `pnpm buyer` / `pnpm partner`: flutter run with the synced dev config.
// Extra args pass through, e.g. `pnpm buyer -- -d emulator-5554`.
import { spawnSync } from 'node:child_process';
import { join } from 'node:path';
import { root } from './lib/paths.mjs';

const [app, ...rest] = process.argv.slice(2);
if (!['buyer', 'partner'].includes(app)) {
  console.error('usage: flutter-run.mjs <buyer|partner> [flutter run args]');
  process.exit(2);
}
const r = spawnSync('flutter', ['run', '--dart-define-from-file=env/dev.json', ...rest], {
  cwd: join(root, 'apps', app),
  stdio: 'inherit',
  shell: true,
});
process.exit(r.status ?? 1);
