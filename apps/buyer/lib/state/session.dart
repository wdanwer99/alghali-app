import 'package:alghali_core/alghali_core.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';

@immutable
class BuyerSession {
  const BuyerSession({this.name, this.email, this.phone});

  static const guest = BuyerSession();

  final String? name;
  final String? email;
  final String? phone;

  bool get signedIn => email != null;
}

/// Email + password sign-in (D-030). In the demo any valid email and a
/// policy-compliant password sign in to a sample account.
class SessionController extends Notifier<BuyerSession> {
  static const _key = 'demo_session';

  @override
  BuyerSession build() {
    final saved = ref.watch(sharedPreferencesProvider).getStringList(_key);
    if (saved == null || saved.length != 3) return BuyerSession.guest;
    return BuyerSession(name: saved[0], email: saved[1], phone: saved[2].isEmpty ? null : saved[2]);
  }

  Future<void> signIn({required String email, required String password}) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    await _save(BuyerSession(name: _nameFrom(email), email: email.trim()));
  }

  Future<void> signUp({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    await _save(BuyerSession(name: name.trim(), email: email.trim(), phone: phone.trim()));
  }

  Future<void> signOut() async {
    state = BuyerSession.guest;
    await ref.read(sharedPreferencesProvider).remove(_key);
  }

  Future<void> _save(BuyerSession s) async {
    state = s;
    await ref.read(sharedPreferencesProvider).setStringList(_key, [
      s.name!,
      s.email!,
      s.phone ?? '',
    ]);
  }

  /// "ahmed.m@example.com" → "Ahmed".
  static String _nameFrom(String email) {
    final local = email
        .split('@')
        .first
        .split(RegExp(r'[._\-+0-9]'))
        .firstWhere((w) => w.isNotEmpty, orElse: () => 'Ahmed');
    return local[0].toUpperCase() + local.substring(1).toLowerCase();
  }
}

final sessionProvider = NotifierProvider<SessionController, BuyerSession>(SessionController.new);

/// Password rule shared with the auth config (D-046): 8+ characters, letters and digits.
bool isStrongPassword(String p) =>
    p.length >= 8 && anyLetter.hasMatch(p) && RegExp(r'\d').hasMatch(p);

bool isEmail(String e) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]{2,}$').hasMatch(e.trim());

/// Sudanese mobile numbers: 10 digits starting with 0 (e.g. 09xxxxxxxx).
bool isSudanPhone(String p) => RegExp(r'^0\d{9}$').hasMatch(p.replaceAll(' ', ''));
