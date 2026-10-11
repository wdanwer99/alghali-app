import 'dart:math' as math;

import 'package:flutter/foundation.dart' show immutable;

import '../format/formatters.dart' show khartoumOffset, toKhartoum;
import '../models/catalogue.dart';
import '../models/commerce.dart';
import '../models/partner.dart';

/// Default weekly hours in Khartoum time: Saturday–Thursday, with a midday
/// break; Friday off. Keyed by [DateTime.weekday] (Monday = 1).
const defaultWeeklyHours = <int, List<AvailabilityWindow>>{
  DateTime.saturday: _day,
  DateTime.sunday: _day,
  DateTime.monday: _day,
  DateTime.tuesday: _day,
  DateTime.wednesday: _day,
  DateTime.thursday: _day,
  DateTime.friday: [],
};
const _day = [
  AvailabilityWindow(startMin: 9 * 60, endMin: 13 * 60),
  AvailabilityWindow(startMin: 16 * 60, endMin: 21 * 60),
];

@immutable
class SlotOption {
  const SlotOption(this.slot, {required this.available});

  final Slot slot;
  final bool available;
}

/// The Khartoum calendar day containing [t], as midnight wall-clock time.
DateTime khartoumDay(DateTime t) {
  final k = toKhartoum(t);
  return DateTime.utc(k.year, k.month, k.day);
}

/// The next [count] Khartoum days starting today.
List<DateTime> upcomingDays(DateTime now, {int count = 7}) {
  final first = khartoumDay(now);
  return [for (var i = 0; i < count; i++) first.add(Duration(days: i))];
}

/// Demo twin of the `booking-slots` Edge Function (PLAN §5): expands the
/// weekly hours for [day], applies the part-ready buffer, cuts a 30-minute
/// grid and marks some times as already booked (deterministic sample load).
List<SlotOption> slotsFor({
  required String technicianId,
  required DateTime day,
  required int durationMin,
  required DateTime now,
  int readyBufferMin = 120,
  Map<int, List<AvailabilityWindow>> hours = defaultWeeklyHours,
}) {
  final earliest = _roundUp(now.toUtc().add(Duration(minutes: readyBufferMin)), 15);
  final out = <SlotOption>[];
  for (final w in hours[day.weekday] ?? const <AvailabilityWindow>[]) {
    for (var m = w.startMin; m + durationMin <= w.endMin; m += 30) {
      // Wall-clock minutes on [day] in Khartoum → a real UTC instant.
      final start = day.add(Duration(minutes: m)).subtract(khartoumOffset);
      if (start.isBefore(earliest)) continue;
      out.add(SlotOption(Slot(start, durationMin), available: !_sampleBusy(technicianId, start)));
    }
  }
  return out;
}

/// For "any available technician": a time is open if anyone eligible is free.
List<SlotOption> slotsForAny({
  required List<String> technicianIds,
  required DateTime day,
  required int durationMin,
  required DateTime now,
  int readyBufferMin = 120,
}) {
  final perTech = [
    for (final id in technicianIds)
      slotsFor(
        technicianId: id,
        day: day,
        durationMin: durationMin,
        now: now,
        readyBufferMin: readyBufferMin,
      ),
  ];
  if (perTech.isEmpty) return const [];
  return [
    for (var i = 0; i < perTech.first.length; i++)
      SlotOption(perTech.first[i].slot, available: perTech.any((s) => s[i].available)),
  ];
}

bool isFree(String technicianId, DateTime start) => !_sampleBusy(technicianId, start);

/// PLAN §5 ranking: rating, experience and closeness.
double technicianScore(Technician t) {
  final rating = (t.rating - 3).clamp(0, 2) / 2;
  final jobs = math.log(t.completedJobs + 1) / math.log(1000);
  final near = 1 - (t.distanceKm / t.radiusKm).clamp(0, 1);
  return 0.5 * rating + 0.3 * jobs.clamp(0, 1) + 0.2 * near;
}

DateTime _roundUp(DateTime t, int minutes) {
  final step = minutes * 60 * 1000;
  final ms = t.millisecondsSinceEpoch;
  return DateTime.fromMillisecondsSinceEpoch(((ms + step - 1) ~/ step) * step, isUtc: true);
}

/// About one slot in five is taken, stable per technician and time.
bool _sampleBusy(String technicianId, DateTime start) {
  var h = 0x811c9dc5;
  for (final c in '$technicianId${start.millisecondsSinceEpoch ~/ 60000}'.codeUnits) {
    h = ((h ^ c) * 0x01000193) & 0xffffffff;
  }
  return h % 5 == 0;
}
