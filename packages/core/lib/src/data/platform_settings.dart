import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/catalogue.dart';

@immutable
class FeeBand {
  const FeeBand(this.maxKm, this.sdg);

  final double maxKm;
  final int sdg;
}

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
  });

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
