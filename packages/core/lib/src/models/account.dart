import 'package:flutter/foundation.dart' show immutable;

import 'catalogue.dart';
import 'partner.dart';

/// Roles a user can hold at once (`app_role` in the database).
enum AppRole {
  buyer('BUYER'),
  shopOwner('SHOP_OWNER'),
  shopStaff('SHOP_STAFF'),
  technician('TECHNICIAN'),
  admin('ADMIN');

  const AppRole(this.code);

  final String code;

  static AppRole? fromCode(String code) => _byCode[code];
  static final _byCode = {for (final r in values) r.code: r};
}

/// Review state of a shop or technician (`partner_status`).
enum PartnerStatus {
  pending('PENDING'),
  approved('APPROVED'),
  rejected('REJECTED'),
  suspended('SUSPENDED');

  const PartnerStatus(this.code);

  final String code;

  static PartnerStatus fromCode(String code) => _byCode[code]!;
  static final _byCode = {for (final s in values) s.code: s};
}

@immutable
class Profile {
  const Profile({
    required this.id,
    required this.email,
    required this.displayName,
    required this.locale,
    required this.dataSaver,
    this.phone,
  });

  factory Profile.fromJson(Json j) => Profile(
    id: j['id'] as String,
    email: j['email'] as String? ?? '',
    displayName: j['display_name'] as String? ?? '',
    locale: j['locale'] as String? ?? 'ar',
    dataSaver: j['data_saver'] as bool? ?? true,
    phone: j['phone'] as String?,
  );

  final String id;
  final String email;
  final String displayName;

  /// E.164, e.g. +249912345678. Not verified until phone sign-in exists (D-030).
  final String? phone;
  final String locale;
  final bool dataSaver;
}

/// A shop the user owns or works at, with its review state.
@immutable
class ShopMembership {
  const ShopMembership({
    required this.shopId,
    required this.role,
    required this.status,
    required this.name,
    this.statusReason,
  });

  factory ShopMembership.fromJson(Json j) => ShopMembership(
    shopId: j['shop_id'] as String,
    role: j['role'] == 'OWNER' ? StaffRole.owner : StaffRole.staff,
    status: PartnerStatus.fromCode(j['status'] as String),
    name: LocalizedText.fromJson(j, 'name'),
    statusReason: j['status_reason'] as String?,
  );

  final String shopId;
  final StaffRole role;
  final PartnerStatus status;
  final LocalizedText name;

  /// Why the shop was rejected or suspended.
  final String? statusReason;
}

/// The user's technician record and its review state (`me().technician`).
@immutable
class TechnicianMembership {
  const TechnicianMembership({required this.id, required this.status, this.statusReason});

  factory TechnicianMembership.fromJson(Json j) => TechnicianMembership(
    id: j['technician_id'] as String,
    status: PartnerStatus.fromCode(j['status'] as String),
    statusReason: j['status_reason'] as String?,
  );

  final String id;
  final PartnerStatus status;
  final String? statusReason;
}

/// The signed-in user, from the `me()` RPC.
@immutable
class Account {
  const Account({required this.profile, required this.roles, required this.shops, this.technician});

  factory Account.fromJson(Json j) => Account(
    profile: Profile.fromJson(j['profile'] as Json),
    roles: {for (final r in (j['roles'] as List).cast<String>()) ?AppRole.fromCode(r)},
    shops: [for (final s in (j['shops'] as List).cast<Json>()) ShopMembership.fromJson(s)],
    technician: j['technician'] == null
        ? null
        : TechnicianMembership.fromJson(j['technician'] as Json),
  );

  final Profile profile;
  final Set<AppRole> roles;
  final List<ShopMembership> shops;

  /// Null until the user applies as a technician.
  final TechnicianMembership? technician;

  bool get isAdmin => roles.contains(AppRole.admin);
  bool has(AppRole role) => roles.contains(role);
}
