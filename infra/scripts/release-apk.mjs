// `pnpm release:apk <buyer|partner> <dev|test|live> [--required]`: publishes a new version
// of an Android app (D-058, D-134, D-135).
//   1. Builds the release APKs against that project, signed with the release key from
//      secrets/, one per processor type (32-bit and 64-bit ARM) with the same version code,
//      so a phone can move between them.
//   2. Uploads them to the project's public app-releases bucket.
//   3. Points latest_app_versions at them: the apps offer the update, and with
//      --required the older builds stop until updated.
// Bump the version in the app's pubspec.yaml (and its build constant in state/push.dart)
// first. The project's secret key is read from .env and never printed.
import { spawnSync } from 'node:child_process';
import { mkdtempSync, readFileSync, rmSync, writeFileSync, existsSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { createClient } from '@supabase/supabase-js';
import { readEnvFile, supabaseTarget } from './lib/env.mjs';
import { root } from './lib/paths.mjs';

const args = process.argv.slice(2).filter((a) => a !== '--');
const [app, target] = args;
const required = args.includes('--required');
if (!['buyer', 'partner'].includes(app) || !['dev', 'test', 'live'].includes(target)) {
  console.error('Usage: pnpm release:apk <buyer|partner> <dev|test|live> [--required]');
  process.exit(1);
}

const env = readEnvFile(join(root, '.env')) ?? {};
const project = supabaseTarget(env, target.toUpperCase());
if (!project.url || !project.publishableKey || !project.secretKey) {
  console.error(
    `SUPABASE_${target.toUpperCase()}_URL, _PUBLISHABLE_KEY and _SECRET_KEY must be set in .env.`,
  );
  process.exit(1);
}
if (!existsSync(join(root, 'secrets', 'android-release.properties'))) {
  console.error(
    'The release key is missing (secrets/android-release.properties and alghali-release.jks).\n' +
      'Restore them from the backup: APKs signed with another key cannot update installed apps.',
  );
  process.exit(1);
}

// The version, and the build number the app reports for update checks.
const dir = join(root, 'apps', app);
const pubspec = readFileSync(join(dir, 'pubspec.yaml'), 'utf8');
const [, versionName, build] = pubspec.match(/^version:\s*([\d.]+)\+(\d+)\s*$/m) ?? [];
const constant = readFileSync(join(dir, 'lib', 'state', 'push.dart'), 'utf8').match(
  /^const \w+Build = (\d+);$/m,
)?.[1];
if (!build || constant !== build) {
  console.error(
    `pubspec.yaml says build ${build}, lib/state/push.dart says ${constant}: make them the same.`,
  );
  process.exit(1);
}

const admin = createClient(project.url, project.secretKey, { auth: { persistSession: false } });
const { data: current, error: readError } = await admin
  .from('app_settings')
  .select('value')
  .eq('key', 'latest_app_versions')
  .single();
if (readError) throw new Error(`Reading latest_app_versions: ${readError.message}`);
const releases = current.value;
if (Number(build) <= releases[app].latest_build) {
  console.error(
    `Build ${build} isn't newer than the published ${releases[app].latest_build}: bump the version first.`,
  );
  process.exit(1);
}

// 1. Build.
const defines = JSON.parse(readFileSync(join(dir, 'env', 'dev.json'), 'utf8'));
const tmp = mkdtempSync(join(tmpdir(), 'alghali-release-'));
const file = join(tmp, 'defines.json');
try {
  writeFileSync(
    file,
    JSON.stringify({
      ...defines,
      SUPABASE_URL: project.url,
      SUPABASE_PUBLISHABLE_KEY: project.publishableKey,
    }),
    { mode: 0o600 },
  );
  const r = spawnSync(
    'flutter',
    [
      'build',
      'apk',
      '--release',
      '--split-per-abi',
      '--target-platform',
      'android-arm,android-arm64',
      '-P',
      'force-version-code-ignoring-abi=true',
      `--dart-define-from-file=${file}`,
    ],
    { cwd: dir, stdio: 'inherit', shell: true },
  );
  if (r.status !== 0) process.exit(r.status ?? 1);
} finally {
  rmSync(tmp, { recursive: true, force: true });
}

// 2. Upload, one file per processor type.
const out = join(dir, 'build', 'app', 'outputs', 'flutter-apk');
const name = (abi) => `${app}/alghali-${app}-${versionName}-${build}-${abi}.apk`;
for (const abi of ['armeabi-v7a', 'arm64-v8a']) {
  const bytes = readFileSync(join(out, `app-${abi}-release.apk`));
  const { error } = await admin.storage
    .from('app-releases')
    .upload(name(abi), bytes, { contentType: 'application/vnd.android.package-archive' });
  if (error) throw new Error(`Uploading ${abi}: ${error.message}`);
  console.log(`Uploaded ${name(abi)} (${(bytes.length / 1048576).toFixed(1)} MB)`);
}

// 3. Announce it. The apps put their processor type where {abi} is (D-135).
const apkUrl = `${project.url}/storage/v1/object/public/app-releases/${name('{abi}')}`;
releases[app] = {
  latest_build: Number(build),
  min_build: required ? Number(build) : releases[app].min_build,
  apk_url: apkUrl,
};
const { error: saveError } = await admin
  .from('app_settings')
  .update({ value: releases, updated_at: new Date().toISOString() })
  .eq('key', 'latest_app_versions');
if (saveError) throw new Error(`Saving latest_app_versions: ${saveError.message}`);
console.log(
  `${app} ${versionName} (build ${build}) is published on ${target}` +
    (required ? '; older builds must update.' : '; older builds are offered the update.'),
);
