// Copies client-safe values from the root .env into the admin and Flutter app configs.
import { mkdirSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { clientConfigs, readEnvFile, supabaseTarget } from './lib/env.mjs';
import { root } from './lib/paths.mjs';

const env = readEnvFile(join(root, '.env'));
if (!env) {
  console.warn(
    'No .env found — copy .env.example to .env and fill it in. Apps will run in "not set up" mode.',
  );
}
const { adminEnvLocal, flutterDefines } = clientConfigs(env ?? {});

writeFileSync(join(root, 'apps/admin/.env.local'), adminEnvLocal);
for (const app of ['buyer', 'partner']) {
  const dir = join(root, 'apps', app, 'env');
  mkdirSync(dir, { recursive: true });
  writeFileSync(join(dir, 'dev.json'), JSON.stringify(flutterDefines, null, 2) + '\n');
}

const dev = supabaseTarget(env ?? {}, 'DEV');
console.log(
  dev.url
    ? `env synced → admin/.env.local, buyer+partner env/dev.json (dev project ${dev.projectRef || dev.url})`
    : 'env synced with empty Supabase values (dev project not configured yet)',
);
