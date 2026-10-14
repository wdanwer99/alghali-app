/// Build-time configuration, passed with `--dart-define-from-file=env/dev.json`
/// (written by `pnpm env:sync` from the repo-root `.env` and `secrets/google-services.json`).
class AppEnv {
  const AppEnv({
    required this.supabaseUrl,
    required this.supabasePublishableKey,
    this.sentryDsn = '',
    this.firebaseApiKey = '',
    this.firebaseAppId = '',
    this.firebaseSenderId = '',
    this.firebaseProjectId = '',
  });

  factory AppEnv.fromEnvironment() => const AppEnv(
    supabaseUrl: String.fromEnvironment('SUPABASE_URL'),
    supabasePublishableKey: String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY'),
    sentryDsn: String.fromEnvironment('SENTRY_DSN'),
    firebaseApiKey: String.fromEnvironment('FIREBASE_API_KEY'),
    firebaseAppId: String.fromEnvironment('FIREBASE_APP_ID'),
    firebaseSenderId: String.fromEnvironment('FIREBASE_SENDER_ID'),
    firebaseProjectId: String.fromEnvironment('FIREBASE_PROJECT_ID'),
  );

  /// An app built without keys still runs; backend features show "not set up".
  static const empty = AppEnv(supabaseUrl: '', supabasePublishableKey: '');

  final String supabaseUrl;
  final String supabasePublishableKey;
  final String sentryDsn;

  /// The app's entry in the Firebase project (D-109). These identify the app; they are
  /// not secrets (every APK carries them), but they stay out of Git with the rest of env.
  final String firebaseApiKey;
  final String firebaseAppId;
  final String firebaseSenderId;
  final String firebaseProjectId;

  bool get isConfigured => supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty;

  bool get hasFirebase =>
      firebaseApiKey.isNotEmpty &&
      firebaseAppId.isNotEmpty &&
      firebaseSenderId.isNotEmpty &&
      firebaseProjectId.isNotEmpty;

  /// Public link to a listing photo in `media-public`: [size] is `thumb` (160 px),
  /// `medium` (480 px) or `large` (1080 px), WebP (D-008).
  String mediaUrl(String baseKey, {String size = 'thumb'}) =>
      '$supabaseUrl/storage/v1/object/public/media-public/$baseKey/$size.webp';
}
