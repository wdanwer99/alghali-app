import 'dart:async';

import 'package:alghali_core/alghali_core.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the app was built with backend keys (tests switch it on with a fake server).
/// Without them the app still opens, as a guest with an empty catalogue.
final backendReadyProvider = Provider<bool>((ref) => ref.watch(appEnvProvider).isConfigured);

@immutable
class BuyerSession {
  const BuyerSession({this.userId, this.name, this.email, this.phone, this.dataSaver = true});

  static const guest = BuyerSession();

  final String? userId;
  final String? name;
  final String? email;

  /// +249… as the server keeps it; null until the buyer adds one.
  final String? phone;
  final bool dataSaver;

  bool get signedIn => userId != null;

  BuyerSession withProfile(Profile p) => BuyerSession(
    userId: userId,
    name: p.displayName.isEmpty ? name : p.displayName,
    email: p.email.isEmpty ? email : p.email,
    phone: p.phone,
    dataSaver: p.dataSaver,
  );
}

/// Email + password accounts (D-059). The session itself is kept by Supabase on the
/// phone; the profile is kept here too, so the app opens signed in without a connection.
class SessionController extends Notifier<BuyerSession> {
  static const _key = 'profile';

  @override
  BuyerSession build() {
    if (!ref.watch(backendReadyProvider)) return BuyerSession.guest;
    final auth = ref.watch(authRepositoryProvider);
    final sub = auth.userChanges.listen((uid) {
      // Signed out elsewhere, or the session could not be renewed.
      if (uid == null && state.signedIn) state = BuyerSession.guest;
    });
    ref.onDispose(sub.cancel);

    final uid = auth.userId;
    if (uid == null) return BuyerSession.guest;
    Future.microtask(_loadProfile);
    final saved = ref.read(sharedPreferencesProvider).getStringList(_key);
    if (saved != null && saved.length == 4 && saved[0] == uid) {
      return BuyerSession(
        userId: uid,
        name: saved[1],
        email: saved[2],
        phone: saved[3].isEmpty ? null : saved[3],
      );
    }
    return BuyerSession(userId: uid);
  }

  AuthRepository get _auth => ref.read(authRepositoryProvider);

  Future<void> signIn({required String email, required String password}) async {
    await _auth.signIn(email: email, password: password);
    state = BuyerSession(userId: _auth.userId, email: email.trim());
    await _loadProfile();
  }

  /// [phone] is a local number (09…); the server stores it as +249….
  Future<void> signUp({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    await _auth.signUp(
      email: email,
      password: password,
      displayName: name,
      locale: ref.read(localeControllerProvider).locale.languageCode,
      phone: phone,
    );
    state = BuyerSession(userId: _auth.userId, name: name.trim(), email: email.trim());
    await _loadProfile();
  }

  Future<void> signOut() async {
    final push = ref.read(pushClientProvider);
    String? token;
    try {
      token = await push.token();
    } on Object {
      token = null;
    }
    // The saved copies are filed under the user's id: forget them while it is known.
    await ref.read(readCacheProvider)?.clearUser();
    try {
      await _auth.signOut(fcmToken: token);
    } on BackendException {
      // Offline: Supabase still forgets the session on this phone.
    }
    state = BuyerSession.guest;
    await ref.read(sharedPreferencesProvider).remove(_key);
  }

  Future<void> sendPasswordReset(String email) => _auth.sendPasswordReset(email);

  /// Changes the name, phone (empty clears it) or language on the server.
  Future<void> updateProfile({String? name, String? phone, String? locale, bool? dataSaver}) async {
    final p = await _auth.updateProfile(
      displayName: name,
      phone: phone,
      locale: locale,
      dataSaver: dataSaver,
    );
    await _save(state.withProfile(p));
  }

  Future<void> _loadProfile() async {
    try {
      final account = await _auth.me();
      if (account == null) return;
      await _save(state.withProfile(account.profile));
    } on BackendException {
      // Offline: keep the saved profile.
    }
  }

  Future<void> _save(BuyerSession s) async {
    state = s;
    await ref.read(sharedPreferencesProvider).setStringList(_key, [
      s.userId ?? '',
      s.name ?? '',
      s.email ?? '',
      s.phone ?? '',
    ]);
  }
}

final sessionProvider = NotifierProvider<SessionController, BuyerSession>(SessionController.new);

/// Password rule shared with the auth config (D-046): 8+ characters, letters and digits.
bool isStrongPassword(String p) =>
    p.length >= 8 && anyLetter.hasMatch(p) && RegExp(r'\d').hasMatch(p);

bool isEmail(String e) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]{2,}$').hasMatch(e.trim());

/// Sudanese mobile numbers: 10 digits starting with 0 (e.g. 09xxxxxxxx).
bool isSudanPhone(String p) => RegExp(r'^0\d{9}$').hasMatch(p.replaceAll(' ', ''));

/// "+249912345678" → "0912345678", as Sudanese buyers write it.
String localPhone(String? e164) {
  if (e164 == null) return '';
  return e164.startsWith('+249') ? '0${e164.substring(4)}' : e164;
}
