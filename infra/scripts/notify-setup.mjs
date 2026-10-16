// Connects a hosted project's notification queue to its notify-dispatch Edge Function:
//   node notify-setup.mjs <dev|test|live> [--fcm path/to/firebase-service-account.json]
// - makes a fresh shared token and stores it twice: in the database's Vault (for pg_cron)
//   and as the function's NOTIFY_DISPATCH_TOKEN secret;
// - stores the function's address in Vault;
// - with --fcm, sets FCM_SERVICE_ACCOUNT_B64 so pushes really go out (D-061); without it, the
//   dispatcher records pushes as stubs.
// Needs `npx supabase login` once. Secrets are never printed.
import { spawnSync } from 'node:child_process';
import { randomBytes } from 'node:crypto';
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import postgres from 'postgres';
import { readEnvFile, supabaseTarget } from './lib/env.mjs';
import { root, supabaseCommand } from './lib/paths.mjs';

const [which, flag, fcmPath] = process.argv.slice(2);
const target = { dev: 'DEV', test: 'TEST', live: 'LIVE' }[which];
if (!target || (flag && (flag !== '--fcm' || !fcmPath))) {
  console.error('usage: notify-setup.mjs <dev|test|live> [--fcm path/to/service-account.json]');
  process.exit(2);
}
const t = supabaseTarget(readEnvFile(join(root, '.env')) ?? {}, target);
if (!t.projectRef || !t.url || !t.dbUrl) {
  console.error(`SUPABASE_${target}_PROJECT_REF / _URL / _DB_URL are not set in .env.`);
  process.exit(1);
}

const secrets = { NOTIFY_DISPATCH_TOKEN: randomBytes(32).toString('hex') };
if (fcmPath) {
  const sa = JSON.parse(readFileSync(fcmPath, 'utf8'));
  if (!sa.project_id || !sa.client_email || !sa.private_key) {
    console.error(
      'That file is not a Firebase service account key (project_id, client_email, private_key).',
    );
    process.exit(1);
  }
  // Base64: as raw JSON the private key's \n escapes came back as line breaks (D-146).
  secrets.FCM_SERVICE_ACCOUNT_B64 = Buffer.from(JSON.stringify(sa)).toString('base64');
}

// Function secrets, through a temporary env file so they never appear on a command line.
const dir = mkdtempSync(join(tmpdir(), 'alghali-notify-'));
try {
  const file = join(dir, 'secrets.env');
  writeFileSync(
    file,
    Object.entries(secrets)
      .map(([k, v]) => `${k}=${JSON.stringify(v)}`)
      .join('\n'),
    { mode: 0o600 },
  );
  const [cli, ...cliArgs] = supabaseCommand();
  const r = spawnSync(
    cli,
    [...cliArgs, 'secrets', 'set', '--env-file', file, '--project-ref', t.projectRef],
    {
      cwd: root,
      stdio: ['ignore', 'ignore', 'inherit'],
    },
  );
  if (r.status !== 0) process.exit(r.status ?? 1);
} finally {
  rmSync(dir, { recursive: true, force: true });
}

// The same token and the function's address, in Vault for pg_cron.
const sql = postgres(t.dbUrl, { max: 1, onnotice: () => undefined });
try {
  const put = async (name, value) => {
    const [row] = await sql`select id from vault.secrets where name = ${name}`;
    if (row) await sql`select vault.update_secret(${row.id}, ${value})`;
    else await sql`select vault.create_secret(${value}, ${name})`;
  };
  await put('notify_dispatch_url', `${t.url.replace(/\/$/, '')}/functions/v1/notify-dispatch`);
  await put('notify_dispatch_token', secrets.NOTIFY_DISPATCH_TOKEN);
} finally {
  await sql.end();
}
console.log(
  `notify-dispatch is set up on ${which}${fcmPath ? ' with Firebase push' : ' (pushes are recorded as stubs until --fcm is given)'}.`,
);
