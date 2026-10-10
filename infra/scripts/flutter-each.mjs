// Runs `flutter <args>` in every Flutter package, e.g. `node flutter-each.mjs test`.
import { spawnSync } from 'node:child_process';
import { join } from 'node:path';
import { flutterPackages, root } from './lib/paths.mjs';

const args = process.argv.slice(2);
const failed = [];
for (const pkg of flutterPackages) {
  console.log(`\n▶ flutter ${args.join(' ')}  (${pkg})`);
  const r = spawnSync('flutter', args, { cwd: join(root, pkg), stdio: 'inherit', shell: true });
  if (r.status !== 0) failed.push(pkg);
}
if (failed.length) {
  console.error(`\n✖ failed in: ${failed.join(', ')}`);
  process.exit(1);
}
