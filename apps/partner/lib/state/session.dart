import 'package:alghali_core/alghali_core.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum PartnerRole { shop, technician }

/// A partner account can hold both roles (a shop owner who also fits parts);
/// the app shows one role's home at a time.
@immutable
class PartnerSession {
  const PartnerSession({this.name, this.email, this.role});

  static const signedOut = PartnerSession();

  final String? name;
  final String? email;
  final PartnerRole? role;

  bool get signedIn => email != null;

  /// The demo account runs Al-Nour Auto Parts and is technician Mohamed Osman.
  String get shopId => 'sh-nour';
  String get technicianId => 'tc-osman';
}

class PartnerSessionController extends Notifier<PartnerSession> {
  static const _key = 'partner_session';

  @override
  PartnerSession build() {
    final saved = ref.watch(sharedPreferencesProvider).getStringList(_key);
    if (saved == null || saved.length != 3) return PartnerSession.signedOut;
    return PartnerSession(
      name: saved[0],
      email: saved[1],
      role: PartnerRole.values.where((r) => r.name == saved[2]).firstOrNull,
    );
  }

  Future<void> signIn({required String email, required String password}) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    final local = email
        .split('@')
        .first
        .split(RegExp(r'[._\-+0-9]'))
        .firstWhere((w) => w.isNotEmpty, orElse: () => 'Mohamed');
    await _save(
      PartnerSession(
        name: local[0].toUpperCase() + local.substring(1).toLowerCase(),
        email: email.trim(),
      ),
    );
  }

  Future<void> chooseRole(PartnerRole role) =>
      _save(PartnerSession(name: state.name, email: state.email, role: role));

  Future<void> signOut() async {
    state = PartnerSession.signedOut;
    await ref.read(sharedPreferencesProvider).remove(_key);
  }

  Future<void> _save(PartnerSession s) async {
    state = s;
    await ref.read(sharedPreferencesProvider).setStringList(_key, [
      s.name ?? '',
      s.email ?? '',
      s.role?.name ?? '',
    ]);
  }
}

final partnerSessionProvider = NotifierProvider<PartnerSessionController, PartnerSession>(
  PartnerSessionController.new,
);

bool isEmail(String e) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]{2,}$').hasMatch(e.trim());

bool isStrongPassword(String p) =>
    p.length >= 8 && anyLetter.hasMatch(p) && RegExp(r'\d').hasMatch(p);
