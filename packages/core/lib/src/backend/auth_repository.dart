import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/account.dart';
import '../models/catalogue.dart';
import 'backend_error.dart';

/// Email + password accounts for everyone (D-030, D-059). Every failure is a
/// [BackendException]: e.g. INVALID_CREDENTIALS, USER_ALREADY_EXISTS, WEAK_PASSWORD,
/// OVER_REQUEST_RATE_LIMIT, OFFLINE.
class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;

  bool get signedIn => _client.auth.currentSession != null;
  String? get userId => _client.auth.currentUser?.id;
  Stream<AuthState> get changes => _client.auth.onAuthStateChange;

  /// The signed-in user's id after every auth change; null once signed out.
  Stream<String?> get userChanges => changes.map((c) => c.session?.user.id);

  /// Creates the account and signs in (email confirmation is off until launch SMTP, D-031).
  /// The phone is saved unverified; the server normalises it to +249….
  Future<void> signUp({
    required String email,
    required String password,
    required String displayName,
    required String locale,
    String? phone,
  }) => guard(
    () => _client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {
        'display_name': displayName.trim(),
        'locale': locale,
        if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
      },
    ),
  );

  Future<void> signIn({required String email, required String password}) =>
      guard(() => _client.auth.signInWithPassword(email: email.trim(), password: password));

  /// Stops this phone's notifications for the account, then signs out.
  Future<void> signOut({String? fcmToken}) => guard(() async {
    if (fcmToken != null && signedIn) {
      await _client.rpc<void>('unregister_device', params: {'p_fcm_token': fcmToken});
    }
    await _client.auth.signOut();
  });

  Future<void> sendPasswordReset(String email, {String? redirectTo}) =>
      guard(() => _client.auth.resetPasswordForEmail(email.trim(), redirectTo: redirectTo));

  /// The signed-in user with roles and shops; null when signed out.
  Future<Account?> me() async {
    if (!signedIn) return null;
    return guard(() async => Account.fromJson(await _client.rpc<Json>('me')));
  }

  /// Null arguments leave a field unchanged; an empty [phone] clears it.
  Future<Profile> updateProfile({
    String? displayName,
    String? phone,
    String? locale,
    bool? dataSaver,
  }) => guard(() async {
    final row = await _client.rpc<Json>(
      'update_profile',
      params: {
        'p_display_name': displayName,
        'p_phone': phone,
        'p_locale': locale,
        'p_data_saver': dataSaver,
      },
    );
    return Profile.fromJson(row);
  });

  Future<void> registerDevice({
    required String app,
    required String fcmToken,
    String platform = 'android',
    int? appBuild,
    String? locale,
  }) => guard(
    () => _client.rpc<Json>(
      'register_device',
      params: {
        'p_app': app,
        'p_platform': platform,
        'p_fcm_token': fcmToken,
        'p_app_build': appBuild,
        'p_locale': locale,
      },
    ),
  );
}
