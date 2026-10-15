import 'dart:ffi' show Abi;

import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/catalogue.dart';

@immutable
class FeeBand {
  const FeeBand(this.maxKm, this.sdg);

  final double maxKm;
  final int sdg;
}

/// The newest and minimum Android builds of one app, and where to download it (D-058).
@immutable
class AppRelease {
  const AppRelease({required this.latestBuild, required this.minBuild, this.apkUrl});

  factory AppRelease.fromJson(Json j) => AppRelease(
    latestBuild: j['latest_build'] as int,
    minBuild: j['min_build'] as int,
    apkUrl: j['apk_url'] as String?,
  );

  static const none = AppRelease(latestBuild: 1, minBuild: 1);

  final int latestBuild;
  final int minBuild;
  final String? apkUrl;

  /// A newer build exists; the app offers to update.
  bool updateAvailable(int build) => build < latestBuild && apkUrl != null;

  /// This build is no longer supported; the app asks to update before continuing.
  bool updateRequired(int build) => build < minBuild && apkUrl != null;

  /// The download for this phone: releases come as one APK per processor type, and
  /// [apkUrl] holds `{abi}` where the type goes (D-135). Cheap phones often run a 32-bit
  /// system, which can't install the 64-bit file, and some new ones only run 64-bit.
  String? apkFor([Abi? abi]) => apkUrl?.replaceAll('{abi}', androidAbiName(abi ?? Abi.current()));
}

/// The Android name of a processor type, as in the APK file names.
String androidAbiName(Abi abi) => switch (abi) {
  Abi.androidArm => 'armeabi-v7a',
  Abi.androidX64 => 'x86_64',
  _ => 'arm64-v8a',
};

/// The buyer-visible subset of `app_settings` (the `public_settings()` RPC).
/// SDG values are placeholders until confirmed with real prices (D-034).
@immutable
class PlatformSettings {
  const PlatformSettings({
    required this.bookingFeeSdg,
    required this.mobileDepositSdg,
    required this.slotHoldMinutes,
    required this.paymentWindowMinutes,
    required this.cancelCutoffHours,
    required this.returnWindowDays,
    required this.partReadyBufferMinutes,
    required this.techAcceptTimeoutMinutes,
    required this.commissionPercent,
    required this.travelFeeBands,
    required this.deliveryFeeBands,
    required this.bankakAccountName,
    required this.bankakAccountNumber,
    this.bookingLookaheadDays = 7,
    this.buyerRelease = AppRelease.none,
    this.partnerRelease = AppRelease.none,
    this.supportPhone = '',
    this.supportWhatsapp = '',
  });

  /// From `public_settings()`. Settings the server keeps private (commission,
  /// technician timeout, part-ready buffer) keep the [demo] values; the apps only use
  /// them for estimates the server re-checks.
  factory PlatformSettings.fromJson(Json j) {
    List<FeeBand> bands(String key) => [
      for (final b in (j[key] as List).cast<Json>())
        FeeBand((b['max_km'] as num).toDouble(), b['sdg'] as int),
    ];
    final name = j['bankak_account_name'] as String? ?? '';
    final releases = j['latest_app_versions'] as Json? ?? const {};
    AppRelease release(String app) =>
        releases[app] is Json ? AppRelease.fromJson(releases[app] as Json) : AppRelease.none;
    return PlatformSettings(
      bookingFeeSdg: j['booking_fee_sdg'] as int,
      mobileDepositSdg: j['mobile_deposit_sdg'] as int,
      slotHoldMinutes: j['slot_hold_minutes'] as int,
      paymentWindowMinutes: j['payment_window_minutes'] as int,
      cancelCutoffHours: j['cancel_cutoff_hours'] as int,
      returnWindowDays: j['return_window_days'] as int,
      partReadyBufferMinutes: demo.partReadyBufferMinutes,
      techAcceptTimeoutMinutes: demo.techAcceptTimeoutMinutes,
      commissionPercent: demo.commissionPercent,
      travelFeeBands: bands('travel_fee_bands'),
      deliveryFeeBands: bands('delivery_fee_bands'),
      bankakAccountName: LocalizedText(name, name),
      bankakAccountNumber: j['bankak_account_number'] as String? ?? '',
      bookingLookaheadDays: j['booking_lookahead_days'] as int? ?? 7,
      buyerRelease: release('buyer'),
      partnerRelease: release('partner'),
      supportPhone: j['support_phone'] as String? ?? '',
      supportWhatsapp: j['support_whatsapp'] as String? ?? '',
    );
  }

  static const demo = PlatformSettings(
    bookingFeeSdg: 2000,
    mobileDepositSdg: 5000,
    slotHoldMinutes: 10,
    paymentWindowMinutes: 120,
    cancelCutoffHours: 6,
    returnWindowDays: 3,
    partReadyBufferMinutes: 120,
    techAcceptTimeoutMinutes: 20,
    commissionPercent: 5,
    travelFeeBands: [FeeBand(3, 3000), FeeBand(8, 6000), FeeBand(15, 10000)],
    deliveryFeeBands: [FeeBand(3, 3000), FeeBand(8, 6000), FeeBand(15, 10000)],
    bankakAccountName: LocalizedText(
      'منصة شارع الغالي (تجريبي)',
      'Alghali Street Platform (sample)',
    ),
    // Deliberately not a real account: the demo must never collect money.
    bankakAccountNumber: '0000000000',
  );

  final int bookingFeeSdg;
  final int mobileDepositSdg;
  final int slotHoldMinutes;
  final int paymentWindowMinutes;
  final int cancelCutoffHours;
  final int returnWindowDays;
  final int partReadyBufferMinutes;
  final int techAcceptTimeoutMinutes;
  final int commissionPercent;
  final List<FeeBand> travelFeeBands;
  final List<FeeBand> deliveryFeeBands;
  final LocalizedText bankakAccountName;
  final String bankakAccountNumber;
  final int bookingLookaheadDays;
  final AppRelease buyerRelease;
  final AppRelease partnerRelease;
  final String supportPhone;
  final String supportWhatsapp;

  /// Null when [km] is beyond the last band (not served).
  int? travelFee(double km) => _band(travelFeeBands, km);
  int? deliveryFee(double km) => _band(deliveryFeeBands, km);

  int get minTravelFee => travelFeeBands.first.sdg;

  static int? _band(List<FeeBand> bands, double km) {
    for (final b in bands) {
      if (km <= b.maxKm) return b.sdg;
    }
    return null;
  }
}

final platformSettingsProvider = Provider<PlatformSettings>((ref) => PlatformSettings.demo);
