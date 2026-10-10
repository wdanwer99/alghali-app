// Supabase helpers that work without Docker (hosted projects):
//   node db.mjs push <dev|test>   apply supabase/migrations to that project
//   node db.mjs types dev         regenerate packages/db-types/src/database.ts
//   node db.mjs seed <dev|test>   run supabase/seed.sql against that project
import { spawnSync } from 'node:child_process';
import { readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { readEnvFile, supabaseTarget } from './lib/env.mjs';
import { root, supabaseBin } from './lib/paths.mjs';

const [command, which = 'dev'] = process.argv.slice(2);
const target = { dev: 'DEV', test: 'TEST' }[which];
if (!target || !['push', 'types', 'seed'].includes(command)) {
  console.error('usage: db.mjs <push|types|seed> <dev|test>');
  process.exit(2);
}

const env = readEnvFile(join(root, '.env'));
const t = supabaseTarget(env ?? {}, target);
if (!t.dbUrl || !t.projectRef) {
  console.error(`SUPABASE_${target}_DB_URL / _PROJECT_REF are not set in .env (see .env.example).`);
  process.exit(1);
}

const run = (args, opts = {}) =>
  spawnSync(supabaseBin(), args, { cwd: root, encoding: 'utf8', ...opts });

if (command === 'push') {
  const r = run(['db', 'push', '--db-url', t.dbUrl, '--include-all'], { stdio: 'inherit' });
  process.exit(r.status ?? 1);
}

if (command === 'types') {
  // Uses the Management API (needs `npx supabase login` once); no Docker required.
  const r = run(['gen', 'types', 'typescript', '--project-id', t.projectRef, '--schema', 'public']);
  if (r.status !== 0) {
    process.stderr.write(r.stderr);
    process.exit(r.status ?? 1);
  }
  const header =
    '// GENERATED FILE — do not edit by hand.\n// Regenerate with `pnpm db:types`.\n\n';
  writeFileSync(join(root, 'packages/db-types/src/database.ts'), header + r.stdout);
  console.log('packages/db-types/src/database.ts updated');
}

if (command === 'seed') {
  const sql = readFileSync(join(root, 'supabase/seed.sql'), 'utf8');
  const { default: postgres } = await import('postgres');
  const db = postgres(t.dbUrl, { max: 1 });
  try {
    await db.unsafe(sql);
    console.log(`seed applied to ${which}`);
  } finally {
    await db.end();
  }
}
