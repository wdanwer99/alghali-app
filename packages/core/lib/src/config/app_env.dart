/// Build-time configuration, passed with `--dart-define-from-file=env/dev.json`
/// (written by `pnpm env:sync` from the repo-root `.env`).
class AppEnv {
  const AppEnv({
    required this.supabaseUrl,
    required this.supabasePublishableKey,
    this.sentryDsn = '',
  });

  factory AppEnv.fromEnvironment() => const AppEnv(
    supabaseUrl: String.fromEnvironment('SUPABASE_URL'),
    supabasePublishableKey: String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY'),
    sentryDsn: String.fromEnvironment('SENTRY_DSN'),
  );

  /// An app built without keys still runs; backend features show "not set up".
  static const empty = AppEnv(supabaseUrl: '', supabasePublishableKey: '');

  final String supabaseUrl;
  final String supabasePublishableKey;
  final String sentryDsn;

  bool get isConfigured => supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty;
}
