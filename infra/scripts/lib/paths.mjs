import { createRequire } from 'node:module';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

export const root = resolve(dirname(fileURLToPath(import.meta.url)), '../../..');
export const flutterPackages = ['packages/core', 'apps/buyer', 'apps/partner'];

/** Path to the Supabase CLI binary from the `supabase` npm package (no shell needed). */
export function supabaseBin() {
  const require = createRequire(join(root, 'package.json'));
  const pkgDir = dirname(require.resolve('supabase/package.json'));
  return join(pkgDir, 'bin', process.platform === 'win32' ? 'supabase.exe' : 'supabase');
}
