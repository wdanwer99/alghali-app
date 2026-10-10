export type EnvMap = Record<string, string>;

export interface SupabaseTarget {
  projectRef: string;
  url: string;
  publishableKey: string;
  secretKey: string;
  dbUrl: string;
}

export function parseEnv(text: string): EnvMap;
export function readEnvFile(path: string): EnvMap | null;
export function isSet(value: string | undefined): boolean;
export function supabaseTarget(env: EnvMap, target: 'DEV' | 'TEST'): SupabaseTarget;
export function clientConfigs(env: EnvMap): {
  adminEnvLocal: string;
  flutterDefines: { SUPABASE_URL: string; SUPABASE_PUBLISHABLE_KEY: string; SENTRY_DSN: string };
};
