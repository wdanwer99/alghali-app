import { describe, expect, it } from 'vitest';
import { clientConfigs, parseEnv, supabaseTarget } from '../../infra/scripts/lib/env.mjs';

describe('env sync', () => {
  const env = parseEnv(`
# comment
SUPABASE_DEV_PROJECT_REF=abcd
SUPABASE_DEV_URL="https://abcd.supabase.co"
SUPABASE_DEV_PUBLISHABLE_KEY=sb_publishable_real
SUPABASE_DEV_SECRET_KEY=sb_secret_real
SUPABASE_DEV_DB_URL=postgresql://postgres.abcd:p%40ss=word@host:5432/postgres
SUPABASE_TEST_URL=https://your-test-project-ref.supabase.co
SENTRY_DSN=
`);

  it('parses values, quotes and "=" inside values', () => {
    expect(env.SUPABASE_DEV_URL).toBe('https://abcd.supabase.co');
    expect(env.SUPABASE_DEV_DB_URL).toBe(
      'postgresql://postgres.abcd:p%40ss=word@host:5432/postgres',
    );
  });

  it('treats .env.example placeholders as unset', () => {
    expect(supabaseTarget(env, 'TEST').url).toBe('');
    expect(supabaseTarget(env, 'DEV').url).toBe('https://abcd.supabase.co');
  });

  it('never copies secret keys or DB URLs into app configs', () => {
    const { adminEnvLocal, flutterDefines } = clientConfigs(env);
    const everything = adminEnvLocal + JSON.stringify(flutterDefines);
    expect(everything).not.toContain('sb_secret_real');
    expect(everything).not.toContain('postgresql://');
    expect(flutterDefines.SUPABASE_PUBLISHABLE_KEY).toBe('sb_publishable_real');
    expect(adminEnvLocal).toContain('NEXT_PUBLIC_SUPABASE_URL=https://abcd.supabase.co');
  });
});
