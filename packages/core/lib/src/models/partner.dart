import 'package:flutter/foundation.dart' show immutable;

import 'catalogue.dart';

/// A line on a shop's or technician's statement. Positive = the platform owes
/// the partner; negative = the partner owes the platform (e.g. cash commission).
@immutable
class LedgerLine {
  const LedgerLine({
    required this.id,
    required this.kind,
    required this.amountSdg,
    required this.at,
    this.ref,
  });

  final String id;
  final LedgerKind kind;
  final int amountSdg;
  final DateTime at;
  final String? ref;
}

enum LedgerKind {
  sale,
  commission,
  labour,
  travelFee,
  bookingFee,
  cashCollected,
  cashHandover,
  payout,
  refund,
}

enum PayoutStatus { draft, approved, paid }

@immutable
class Payout {
  const Payout({
    required this.id,
    required this.from,
    required this.to,
    required this.amountSdg,
    required this.status,
    this.paidAt,
  });

  final String id;
  final DateTime from;
  final DateTime to;
  final int amountSdg;
  final PayoutStatus status;
  final DateTime? paidAt;
}

enum StaffRole { owner, staff }

@immutable
class StaffMember {
  const StaffMember({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.lastActive,
  });

  final String id;
  final String name;
  final String email;
  final StaffRole role;
  final DateTime lastActive;
}

/// A weekly working window in Khartoum wall-clock time (PLAN §3.8).
@immutable
class AvailabilityWindow {
  const AvailabilityWindow({required this.startMin, required this.endMin});

  /// Minutes after midnight.
  final int startMin;
  final int endMin;
}

@immutable
class TimeOff {
  const TimeOff({required this.id, required this.from, required this.to, required this.reason});

  final String id;
  final DateTime from;
  final DateTime to;
  final LocalizedText reason;
}

/// Sales per day for the last 7 days, oldest first, for the shop's insights.
@immutable
class SalesDay {
  const SalesDay(this.day, this.sdg, this.orders);

  final DateTime day;
  final int sdg;
  final int orders;
}
