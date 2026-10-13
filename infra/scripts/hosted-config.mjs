// Previews or applies infra/hosted/supabase/config.toml on a hosted project:
//   node hosted-config.mjs <diff|push> <dev|test>
// Only the properties declared in that file change. Needs `npx supabase login` once.
import { spawnSync } from 'node:child_process';
import { join } from 'node:path';
import { readEnvFile, supabaseTarget } from './lib/env.mjs';
import { root, supabaseCommand } from './lib/paths.mjs';

const [command, which] = process.argv.slice(2);
const target = { dev: 'DEV', test: 'TEST' }[which];
if (!['diff', 'push'].includes(command) || !target) {
  console.error('usage: hosted-config.mjs <diff|push> <dev|test>');
  process.exit(2);
}

const t = supabaseTarget(readEnvFile(join(root, '.env')) ?? {}, target);
if (!t.projectRef) {
  console.error(`SUPABASE_${target}_PROJECT_REF is not set in .env.`);
  process.exit(1);
}

const [cli, ...cliArgs] = supabaseCommand();
const args = [
  'config',
  command,
  '--project-ref',
  t.projectRef,
  '--workdir',
  join(root, 'infra/hosted'),
];
const r = spawnSync(cli, [...cliArgs, ...args, ...(command === 'push' ? ['--yes'] : [])], {
  cwd: root,
  stdio: 'inherit',
});
process.exit(r.status ?? 1);
