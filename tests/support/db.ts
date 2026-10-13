import { join } from 'node:path';
import postgres from 'postgres';
import { readEnvFile, supabaseTarget } from '../../infra/scripts/lib/env.mjs';

/**
 * Connection string for the database under test:
 *   - CI sets DB_URL to the local `supabase start` database;
 *   - locally we use SUPABASE_TEST_DB_URL from the root .env (never the dev project).
 */
function testDbUrl(): string {
  if (process.env.DB_URL) return process.env.DB_URL;
  const env = readEnvFile(join(import.meta.dirname, '../../.env'));
  return supabaseTarget(env ?? {}, 'TEST').dbUrl;
}

export const dbUrl = testDbUrl();
export const hasDb = dbUrl !== '';
export const skipReason =
  'No test database: set SUPABASE_TEST_DB_URL in .env (or DB_URL in CI) to run DB tests.';

export { must } from './must.ts';

export type Sql = postgres.Sql;
export type Tx = postgres.TransactionSql;

export function connect(): Sql {
  return postgres(dbUrl, { max: 4, idle_timeout: 5, onnotice: () => undefined });
}

class Rollback extends Error {}

/** Runs `fn` in a transaction that is always rolled back, so tests leave no trace. */
export async function withRollback<T>(sql: Sql, fn: (tx: Tx) => Promise<T>): Promise<T> {
  let result: T | undefined;
  try {
    await sql.begin(async (tx) => {
      result = await fn(tx);
      throw new Rollback();
    });
  } catch (e) {
    if (!(e instanceof Rollback)) throw e;
  }
  return result as T;
}

/**
 * Switches the transaction to a Supabase API role, as PostgREST would.
 * `sub` simulates a signed-in user (auth.uid()).
 */
export async function actAs(tx: Tx, role: 'anon' | 'authenticated', sub?: string): Promise<void> {
  const claims = JSON.stringify(sub ? { sub, role } : { role });
  await tx`select set_config('request.jwt.claims', ${claims}, true)`;
  await tx.unsafe(`set local role ${role}`);
}
