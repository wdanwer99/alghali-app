import 'dart:async';
import 'dart:convert';

import 'package:alghali_core/alghali_core.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the app was built with backend keys (tests switch it on with a fake server).
final backendReadyProvider = Provider<bool>((ref) => ref.watch(appEnvProvider).isConfigured);

enum PartnerRole { shop, technician }

/// A partner account can run shops (up to three) and be a technician; the app shows one
/// shop's or the technician's screens at a time (D-123).
@immutable
class PartnerSession {
  const PartnerSession({
    this.userId,
    this.name,
    this.email,
    this.phone,
    this.shops = const [],
    this.technician,
    this.role,
    this.shopId,
    this.loaded = false,
  });

  static const signedOut = PartnerSession(loaded: true);

  final String? userId;
  final String? name;
  final String? email;

  /// +249… as the server keeps it.
  final String? phone;
  final List<ShopMembership> shops;

  /// Null until the user applies as a technician.
  final TechnicianMembership? technician;
  final PartnerRole? role;

  /// The shop open in the app when [role] is [PartnerRole.shop].
  final String? shopId;

  /// The account (shops, technician record) is known: from the server, or saved on the
  /// phone. Until then the app waits instead of guessing where the partner belongs.
  final bool loaded;

  bool get signedIn => userId != null;

  /// Has a shop or a technician record (even one still waiting for approval).
  bool get isPartner => shops.isNotEmpty || technician != null;

  ShopMembership? get shop => shops.where((s) => s.shopId == shopId).firstOrNull;
  bool get isOwner => shop?.role == StaffRole.owner;

  /// The homes this account can open: each shop, and the technician's jobs.
  int get homeCount => shops.length + (technician == null ? 0 : 1);

  PartnerSession copyWith({
    String? name,
    String? email,
    String? phone,
    List<ShopMembership>? shops,
    TechnicianMembership? technician,
    bool clearTechnician = false,
    PartnerRole? role,
    String? shopId,
    bool clearRole = false,
    bool? loaded,
  }) => PartnerSession(
    userId: userId,
    name: name ?? this.name,
    email: email ?? this.email,
    phone: phone ?? this.phone,
    shops: shops ?? this.shops,
    technician: clearTechnician ? null : technician ?? this.technician,
    role: clearRole ? null : role ?? this.role,
    shopId: clearRole ? null : shopId ?? this.shopId,
    loaded: loaded ?? this.loaded,
  );

  Json toJson() => {
    'user_id': userId,
    'name': name,
    'email': email,
    'phone': phone,
    'shops': [
      for (final s in shops)
        {
          'shop_id': s.shopId,
          'role': s.role == StaffRole.owner ? 'OWNER' : 'STAFF',
          'status': s.status.code,
          'status_reason': s.statusReason,
          'name_ar': s.name.ar,
          'name_en': s.name.en,
        },
    ],
    'technician': technician == null
        ? null
        : {
            'technician_id': technician!.id,
            'status': technician!.status.code,
            'status_reason': technician!.statusReason,
          },
    'role': role?.name,
    'shop_id': shopId,
  };

  factory PartnerSession.fromJson(Json j) => PartnerSession(
    userId: j['user_id'] as String?,
    name: j['name'] as String?,
    email: j['email'] as String?,
    phone: j['phone'] as String?,
    shops: [for (final s in (j['shops'] as List).cast<Json>()) ShopMembership.fromJson(s)],
    technician: j['technician'] == null
        ? null
        : TechnicianMembership.fromJson(j['technician'] as Json),
    role: PartnerRole.values.where((r) => r.name == j['role']).firstOrNull,
    shopId: j['shop_id'] as String?,
    loaded: true,
  );
}

/// Email + password accounts (D-059). Supabase keeps the session on the phone; the
/// account (name, shops, technician record, chosen role) is kept here too, so the app
/// opens signed in without a connection.
class PartnerSessionController extends Notifier<PartnerSession> {
  static const _key = 'partner_account';

  @override
  PartnerSession build() {
    if (!ref.watch(backendReadyProvider)) return PartnerSession.signedOut;
    final auth = ref.watch(authRepositoryProvider);
    final sub = auth.userChanges.listen((uid) {
      // Signed out elsewhere, or the session could not be renewed.
      if (uid == null && state.signedIn) state = PartnerSession.signedOut;
    });
    ref.onDispose(sub.cancel);

    final uid = auth.userId;
    if (uid == null) return PartnerSession.signedOut;
    Future.microtask(refreshAccount);
    final saved = ref.read(sharedPreferencesProvider).getString(_key);
    if (saved != null) {
      try {
        final s = PartnerSession.fromJson(jsonDecode(saved) as Json);
        if (s.userId == uid) return s;
      } on Object {
        // An older format: start again from the server.
      }
    }
    return PartnerSession(userId: uid);
  }

  AuthRepository get _auth => ref.read(authRepositoryProvider);

  /// The account is fetched before anything is shown, so the app opens the right home.
  Future<void> signIn({required String email, required String password}) async {
    await _auth.signIn(email: email, password: password);
    await refreshAccount(
      base: PartnerSession(userId: _auth.userId, email: email.trim()),
    );
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
    await refreshAccount(
      base: PartnerSession(userId: _auth.userId, name: name.trim(), email: email.trim()),
    );
  }

  Future<void> sendPasswordReset(String email) => _auth.sendPasswordReset(email);

  /// Opens a shop's screens or the technician's.
  Future<void> chooseRole(PartnerRole role, {String? shopId}) =>
      _save(state.copyWith(role: role, shopId: role == PartnerRole.shop ? shopId : null));

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
    state = PartnerSession.signedOut;
    await ref.read(sharedPreferencesProvider).remove(_key);
  }

  /// Fetches the account again (after signing in or applying, or when an admin decided).
  /// Keeps the chosen home while it still exists, and picks the only one there is.
  Future<void> refreshAccount({PartnerSession? base}) async {
    Account? account;
    try {
      account = await _auth.me();
    } on BackendException {
      account = null; // Offline: keep the saved account.
    }
    if (!ref.mounted) return;
    final s = base ?? state;
    if (account == null) {
      if (!s.loaded) await _save(s.copyWith(loaded: true));
      return;
    }
    final p = account.profile;
    var next = s.copyWith(
      name: p.displayName.isEmpty ? s.name : p.displayName,
      email: p.email.isEmpty ? s.email : p.email,
      phone: p.phone,
      shops: account.shops,
      technician: account.technician,
      clearTechnician: account.technician == null,
    );
    final roleGone = switch (next.role) {
      PartnerRole.shop => next.shop == null,
      PartnerRole.technician => next.technician == null,
      null => true,
    };
    if (roleGone) next = next.copyWith(clearRole: true);
    next = next.copyWith(loaded: true);
    if (next.role == null && next.homeCount == 1) {
      next = next.shops.isNotEmpty
          ? next.copyWith(role: PartnerRole.shop, shopId: next.shops.first.shopId)
          : next.copyWith(role: PartnerRole.technician);
    }
    await _save(next);
  }

  /// Changes the name or phone (empty clears it) on the server.
  Future<void> updateProfile({String? name, String? phone}) async {
    final p = await _auth.updateProfile(displayName: name, phone: phone);
    await _save(state.copyWith(name: p.displayName, phone: p.phone));
  }

  Future<void> _save(PartnerSession s) async {
    state = s;
    await ref.read(sharedPreferencesProvider).setString(_key, jsonEncode(s.toJson()));
  }
}

final partnerSessionProvider = NotifierProvider<PartnerSessionController, PartnerSession>(
  PartnerSessionController.new,
);

/// The shop whose screens are open, or null in the technician's.
final currentShopIdProvider = Provider<String?>(
  (ref) =>
      ref.watch(partnerSessionProvider.select((s) => s.role == PartnerRole.shop ? s.shopId : null)),
);

bool isEmail(String e) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]{2,}$').hasMatch(e.trim());

/// Password rule shared with the auth config (D-046): 8+ characters, letters and digits.
bool isStrongPassword(String p) =>
    p.length >= 8 && anyLetter.hasMatch(p) && RegExp(r'\d').hasMatch(p);

/// Sudanese mobile numbers: 10 digits starting with 0 (e.g. 09xxxxxxxx).
bool isSudanPhone(String p) => RegExp(r'^0\d{9}$').hasMatch(p.replaceAll(' ', ''));

/// "+249912345678" → "0912345678", as Sudanese partners write it.
String localPhone(String? e164) {
  if (e164 == null) return '';
  return e164.startsWith('+249') ? '0${e164.substring(4)}' : e164;
}

/// Midnight in Khartoum at the end of [now]'s day, as UTC.
DateTime endOfKhartoumDay(DateTime now) =>
    khartoumDay(now).add(const Duration(days: 1)).subtract(khartoumOffset);
