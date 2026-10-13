// Deploys every Edge Function in supabase/functions to a hosted project, bundled on
// Supabase's side (no Docker needed):
//   node functions.mjs deploy <dev|test>
// Needs `npx supabase login` once.
import { spawnSync } from 'node:child_process';
import { readdirSync } from 'node:fs';
import { join } from 'node:path';
import { readEnvFile, supabaseTarget } from './lib/env.mjs';
import { root, supabaseCommand } from './lib/paths.mjs';

const [command, which] = process.argv.slice(2);
const target = { dev: 'DEV', test: 'TEST' }[which];
if (command !== 'deploy' || !target) {
  console.error('usage: functions.mjs deploy <dev|test>');
  process.exit(2);
}

const t = supabaseTarget(readEnvFile(join(root, '.env')) ?? {}, target);
if (!t.projectRef) {
  console.error(`SUPABASE_${target}_PROJECT_REF is not set in .env.`);
  process.exit(1);
}

const names = readdirSync(join(root, 'supabase/functions'), { withFileTypes: true })
  .filter((d) => d.isDirectory() && !d.name.startsWith('_'))
  .map((d) => d.name);

const [cli, ...cliArgs] = supabaseCommand();
for (const name of names) {
  const r = spawnSync(
    cli,
    [...cliArgs, 'functions', 'deploy', name, '--project-ref', t.projectRef, '--use-api'],
    {
      cwd: root,
      stdio: 'inherit',
    },
  );
  if (r.status !== 0) process.exit(r.status ?? 1);
}
