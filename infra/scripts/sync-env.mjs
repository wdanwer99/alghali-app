// Copies client-safe values from the root .env into the admin and Flutter app configs,
// and each Android app's Firebase entry from secrets/google-services.json (D-109).
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
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

// The Firebase values identify the app (every APK carries them); push needs them.
const servicesPath = join(root, 'secrets', 'google-services.json');
const services = existsSync(servicesPath) ? JSON.parse(readFileSync(servicesPath, 'utf8')) : null;
function firebaseFor(packageName) {
  const client = services?.client?.find(
    (c) => c.client_info?.android_client_info?.package_name === packageName,
  );
  if (!client) return {};
  return {
    FIREBASE_API_KEY: client.api_key?.[0]?.current_key ?? '',
    FIREBASE_APP_ID: client.client_info.mobilesdk_app_id ?? '',
    FIREBASE_SENDER_ID: services.project_info?.project_number ?? '',
    FIREBASE_PROJECT_ID: services.project_info?.project_id ?? '',
  };
}

writeFileSync(join(root, 'apps/admin/.env.local'), adminEnvLocal);
const withPush = [];
for (const app of ['buyer', 'partner']) {
  const dir = join(root, 'apps', app, 'env');
  mkdirSync(dir, { recursive: true });
  const firebase = firebaseFor(`sd.alghali.${app}`);
  if (firebase.FIREBASE_APP_ID) withPush.push(app);
  writeFileSync(
    join(dir, 'dev.json'),
    JSON.stringify({ ...flutterDefines, ...firebase }, null, 2) + '\n',
  );
}

const dev = supabaseTarget(env ?? {}, 'DEV');
console.log(
  dev.url
    ? `env synced → admin/.env.local, buyer+partner env/dev.json (dev project ${dev.projectRef || dev.url})`
    : 'env synced with empty Supabase values (dev project not configured yet)',
);
console.log(
  withPush.length
    ? `push (Firebase) set up for: ${withPush.join(', ')}`
    : 'no secrets/google-services.json: the apps run without push',
);
