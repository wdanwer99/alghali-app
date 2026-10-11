import { createRequire } from 'node:module';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

export const root = resolve(dirname(fileURLToPath(import.meta.url)), '../../..');
export const flutterPackages = ['packages/core', 'apps/buyer', 'apps/partner'];

/**
 * Command (program + leading args) that runs the Supabase CLI from the `supabase` npm package,
 * no shell needed. Follows the package's `bin` entry: a JS file since 2.x, a native binary before.
 */
export function supabaseCommand() {
  const require = createRequire(join(root, 'package.json'));
  const pkgJson = require.resolve('supabase/package.json');
  const { bin } = require(pkgJson);
  const entry = join(dirname(pkgJson), typeof bin === 'string' ? bin : bin.supabase);
  return /\.[cm]?js$/.test(entry) ? [process.execPath, entry] : [entry];
}
