// Uploads supabase/templates/* to the public `templates` bucket of a hosted project, so the
// partner app can link to the stock import sheet:
//   node upload-templates.mjs <dev|test|live>
// Public URL: <project url>/storage/v1/object/public/templates/inventory-template.xlsx
import { readdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { createClient } from '@supabase/supabase-js';
import { readEnvFile, supabaseTarget } from './lib/env.mjs';
import { root } from './lib/paths.mjs';

const which = process.argv[2];
const target = { dev: 'DEV', test: 'TEST', live: 'LIVE' }[which];
if (!target) {
  console.error('usage: upload-templates.mjs <dev|test|live>');
  process.exit(2);
}
const t = supabaseTarget(readEnvFile(join(root, '.env')) ?? {}, target);
if (!t.url || !t.secretKey) {
  console.error(`SUPABASE_${target}_URL / _SECRET_KEY are not set in .env.`);
  process.exit(1);
}

const types = {
  '.xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  '.csv': 'text/csv',
};
const storage = createClient(t.url, t.secretKey, { auth: { persistSession: false } }).storage.from(
  'templates',
);
const dir = join(root, 'supabase/templates');
for (const name of readdirSync(dir)) {
  const contentType = types[name.slice(name.lastIndexOf('.'))];
  if (!contentType) continue;
  const { error } = await storage.upload(name, readFileSync(join(dir, name)), {
    contentType,
    upsert: true,
  });
  if (error) {
    console.error(`${name}: ${error.message}`);
    process.exit(1);
  }
  console.log(`${which}: ${storage.getPublicUrl(name).data.publicUrl}`);
}
