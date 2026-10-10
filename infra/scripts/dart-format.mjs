// Formats (or with --check, verifies) hand-written Dart files.
// Generated *.g.dart files keep their generator's formatting.
import { execFileSync, spawnSync } from 'node:child_process';
import { root } from './lib/paths.mjs';

const check = process.argv.includes('--check');
const tracked = execFileSync(
  'git',
  ['ls-files', '--cached', '--others', '--exclude-standard', '--', '*.dart'],
  {
    cwd: root,
    encoding: 'utf8',
  },
)
  .split('\n')
  .filter((f) => f && !f.endsWith('.g.dart'));

const args = check
  ? ['format', '--output=none', '--set-exit-if-changed', ...tracked]
  : ['format', ...tracked];
const r = spawnSync('dart', args, {
  cwd: root,
  stdio: 'inherit',
  shell: process.platform === 'win32',
});
process.exit(r.status ?? 1);
