import 'dart:async';
import 'dart:typed_data';

import 'package:alghali_core/alghali_core.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'session.dart';

/// Breaks the technician takes from the jobs screen: "busy for an hour" and "offline for
/// the rest of today". They are time off like any other, marked by their reason, so
/// switching back on removes just these (D-124).
const quickBlockReason = 'QUICK_BLOCK';
const offlineReason = 'OFFLINE';

/// Whether the technician's screens are open (and signed-in as a technician).
final techActiveProvider = Provider<bool>(
  (ref) => ref.watch(partnerSessionProvider.select((s) => s.role == PartnerRole.technician)),
);

// --------------------------------------------------------------------- the technician

extension TechnicianBreaks on MyTechnician {
  /// The quick blocks and "offline" breaks going on at [now].
  List<TimeOff> breaksAt(DateTime now) => [
    for (final t in timeOff)
      if ((t.reason.ar == quickBlockReason || t.reason.ar == offlineReason) &&
          !t.from.isAfter(now) &&
          t.to.isAfter(now))
        t,
  ];

  /// When the current break ends; null when taking new jobs.
  DateTime? busyUntil(DateTime now) {
    final b = breaksAt(now);
    if (b.isEmpty) return null;
    return b.map((t) => t.to).reduce((a, c) => c.isAfter(a) ? c : a);
  }

  /// Planned days off still to come (not the quick breaks), soonest first.
  List<TimeOff> plannedOff(DateTime now) => [
    for (final t in timeOff)
      if (t.reason.ar != quickBlockReason && t.reason.ar != offlineReason && t.to.isAfter(now)) t,
  ]..sort((a, b) => a.from.compareTo(b.from));

  /// Weekly windows by database weekday (0 = Sunday … 6 = Saturday).
  Map<int, List<AvailabilityRule>> get hoursByDay {
    final out = <int, List<AvailabilityRule>>{};
    for (final r in rules) {
      (out[r.weekday] ??= []).add(r);
    }
    return out;
  }
}

/// The technician's own record: prices, how they work, hours and time off. Every change
/// needs a connection and reloads the record.
class MyTechnicianController extends AsyncNotifier<MyTechnician?> with CachedList<MyTechnician?> {
  @override
  Future<MyTechnician?> build() async {
    final hasRecord = ref.watch(partnerSessionProvider.select((s) => s.technician != null));
    if (!hasRecord) return null;
    return load();
  }

  @override
  Future<MyTechnician?> fetch() => ref.read(technicianRepositoryProvider).me();

  TechnicianRepository get _repo => ref.read(technicianRepositoryProvider);
  DateTime get _now => ref.read(clockProvider)();

  Future<void> _then(Future<Object?> change) async {
    await change;
    final fresh = await fetch();
    if (ref.mounted) state = AsyncData(fresh);
  }

  /// One job type's labour price; the others stay.
  Future<void> setLabour(String jobTypeId, int sdg) {
    final me = state.value;
    if (me == null) return Future.value();
    return _then(
      _repo.setJobs({for (final j in me.jobs) j.jobTypeId: j.labourSdg, jobTypeId: sdg}),
    );
  }

  Future<void> setMode(WorkMode mode) =>
      _then(_repo.updateProfile({'work_mode': workModeCode(mode)}));
  Future<void> setRadius(int km) => _then(_repo.updateProfile({'radius_km': km}));

  /// Where visits are measured from: the phone's position now.
  Future<void> setHomeHere() async {
    final (:lat, :lng) = await ref.read(gpsProvider)();
    await _then(_repo.updateProfile({'home_lat': lat, 'home_lng': lng}));
  }

  /// Replaces one weekday's hours (database weekday, 0 = Sunday); empty = day off.
  Future<void> setDay(int weekday, List<(int, int)> windows) async {
    final me = state.value;
    if (me == null) return;
    for (final r in me.rules.where((r) => r.weekday == weekday)) {
      await _repo.removeRule(r.id);
    }
    for (final (start, end) in windows) {
      await _repo.addRule(technicianId: me.id, weekday: weekday, startMin: start, endMin: end);
    }
    await _then(Future.value());
  }

  Future<void> addTimeOff(DateTime from, DateTime to, {String? reason}) {
    final me = state.value;
    if (me == null) return Future.value();
    return _then(_repo.addTimeOff(technicianId: me.id, from: from, to: to, reason: reason));
  }

  Future<void> removeTimeOff(String id) => _then(_repo.removeTimeOff(id));

  /// Busy for the next [minutes] (`tech_quick_block`, 5–720).
  Future<void> quickBlock(int minutes) => _then(_repo.quickBlock(minutes));

  /// No new jobs until midnight.
  Future<void> goOffline() => addTimeOff(_now, endOfKhartoumDay(_now), reason: offlineReason);

  /// Back to taking jobs: ends the quick blocks and "offline" breaks going on now.
  Future<void> goOnline() async {
    final me = state.value;
    if (me == null) return;
    for (final t in me.breaksAt(_now)) {
      await _repo.removeTimeOff(t.id);
    }
    await _then(Future.value());
  }
}

final myTechnicianProvider = AsyncNotifierProvider<MyTechnicianController, MyTechnician?>(
  MyTechnicianController.new,
);

// ------------------------------------------------------------------------------ jobs

@immutable
class TechJobs {
  const TechJobs({this.offers = const [], this.upcoming = const [], this.past = const []});

  /// Waiting for an answer; [Booking.offer] has the deadline.
  final List<Booking> offers;

  /// Accepted, on the way and in progress, soonest first.
  final List<Booking> upcoming;
  final List<Booking> past;

  Booking? byId(String id) =>
      [...offers, ...upcoming, ...past].where((b) => b.id == id).firstOrNull;

  TechJobs replace(Booking b) {
    List<Booking> swap(List<Booking> list) => [for (final x in list) x.id == b.id ? b : x];
    return TechJobs(offers: swap(offers), upcoming: swap(upcoming), past: swap(past));
  }
}

/// Offers, upcoming and past jobs. Every step of the job day is checked by the server at
/// once (`tech_*` RPCs) and needs a connection.
class TechJobsController extends AsyncNotifier<TechJobs> with CachedList<TechJobs> {
  @override
  Future<TechJobs> build() async {
    final approved = ref.watch(
      partnerSessionProvider.select((s) => s.technician?.status == PartnerStatus.approved),
    );
    if (!approved) return const TechJobs();
    return load();
  }

  @override
  Future<TechJobs> fetch() async {
    final repo = ref.read(technicianRepositoryProvider);
    final (offers, upcoming, past) = await (
      repo.offers(),
      repo.upcoming(),
      repo.past(limit: 30),
    ).wait;
    return TechJobs(
      offers: [
        for (final b in offers)
          if (b.offer?.open ?? false) b,
      ],
      upcoming: upcoming,
      past: past,
    );
  }

  TechnicianRepository get _repo => ref.read(technicianRepositoryProvider);

  /// Accepting or declining refreshes the lists (a decline passes the job on, D-102).
  Future<void> respond(Booking b, {required bool accept, String? reason}) async {
    await _repo.respond(b.offer!.id, accept: accept, reason: reason);
    await refresh();
  }

  Future<Booking> enRoute(String id) => _step(_repo.enRoute(id));
  Future<Booking> checkIn(String id) => _step(_repo.checkIn(id));

  Future<Booking> addPhoto(String id, Uint8List jpeg, {required bool before}) =>
      _step(_repo.addPhoto(id, jpeg, before: before));

  Future<Booking> partDoesNotFit(String id, String reason) async {
    final b = await _step(_repo.partDoesNotFit(id, reason));
    unawaited(refresh());
    return b;
  }

  /// Drops an accepted job before the parts are collected; it goes to the next technician.
  Future<void> cancel(String id, String reason) async {
    await _repo.cancel(id, reason);
    await refresh();
  }

  /// Closes the job with the buyer's code. A wrong code isn't an error: the result says
  /// how many tries are left (D-028, D-103).
  Future<CompleteResult> complete(String id, String code) async {
    final result = await _repo.complete(id, code);
    if (result.booking case final b?) _replace(b);
    if (result.ok) {
      unawaited(refresh());
      ref.invalidate(techStatementProvider);
    }
    return result;
  }

  Future<Booking> _step(Future<Booking> call) async {
    final b = await call;
    _replace(b);
    return b;
  }

  void _replace(Booking b) {
    if (!ref.mounted) return;
    final jobs = state.value;
    // jobDetailProvider follows this list, so the job's page updates too.
    if (jobs != null) state = AsyncData(jobs.replace(b));
  }
}

final techJobsProvider = AsyncNotifierProvider<TechJobsController, TechJobs>(
  TechJobsController.new,
);

/// One job: from the lists when it is there, else from the server (an alert about an
/// older job).
final jobDetailProvider = FutureProvider.autoDispose.family<Booking, String>((ref, id) async {
  final listed = ref.watch(techJobsProvider).value?.byId(id);
  if (listed != null) return listed;
  return ref.read(bookingsRepositoryProvider).get(id);
});

/// Hour-long links to a job's photos, by key (keys joined with new lines).
final jobPhotoUrlsProvider = FutureProvider.autoDispose.family<Map<String, String>, String>((
  ref,
  keys,
) async {
  if (keys.isEmpty) return const {};
  try {
    return await ref.read(bookingsRepositoryProvider).photoUrls(keys.split('\n'));
  } on BackendException {
    return const {};
  }
});

// -------------------------------------------------------------------- live location

/// Shares the technician's position while a job is on the way (D-029): at once, then
/// every 30 seconds while the app is open. Stops when no job is on the way.
class LocationSharing extends Notifier<String?> {
  Timer? _timer;

  @override
  String? build() {
    ref.onDispose(() => _timer?.cancel());
    final enRoute = ref.watch(
      techJobsProvider.select(
        (jobs) =>
            jobs.value?.upcoming.where((b) => b.status == BookingStatus.enRoute).firstOrNull?.id,
      ),
    );
    _timer?.cancel();
    _timer = null;
    if (enRoute != null && ref.watch(locationSharingEnabledProvider)) {
      unawaited(_send(enRoute));
      _timer = Timer.periodic(const Duration(seconds: 30), (_) => unawaited(_send(enRoute)));
    }
    return enRoute;
  }

  Future<void> _send(String bookingId) async {
    try {
      final (:lat, :lng) = await ref.read(gpsProvider)();
      await ref.read(technicianRepositoryProvider).updateLocation(bookingId, lat, lng);
    } on Object {
      // No fix or no connection this time; the next tick tries again.
    }
  }
}

final locationSharingProvider = NotifierProvider<LocationSharing, String?>(LocationSharing.new);

/// Off in widget tests (no GPS there).
final locationSharingEnabledProvider = Provider<bool>((ref) => true);

/// The phone's position (asks for permission the first time); device tests give a fixed
/// one, since they can't answer Android's permission prompt.
final gpsProvider = Provider<Future<({double lat, double lng})> Function()>((ref) => Gps.here);

// -------------------------------------------------------------------------- earnings

/// The last 30 days of labour, travel fees, cash taken and payouts (`tech_statement`).
class TechStatementController extends AsyncNotifier<ShopStatement?>
    with CachedList<ShopStatement?> {
  @override
  Future<ShopStatement?> build() async {
    final approved = ref.watch(
      partnerSessionProvider.select((s) => s.technician?.status == PartnerStatus.approved),
    );
    if (!approved) return null;
    return load();
  }

  @override
  Future<ShopStatement?> fetch() => ref.read(technicianRepositoryProvider).statement();
}

final techStatementProvider = AsyncNotifierProvider<TechStatementController, ShopStatement?>(
  TechStatementController.new,
);

/// The week's figures from the statement.
@immutable
class TechEarnings {
  const TechEarnings({
    required this.weekSdg,
    required this.weekJobs,
    required this.balanceSdg,
    required this.cashSdg,
  });

  factory TechEarnings.of(ShopStatement s, DateTime now) {
    final weekAgo = now.subtract(const Duration(days: 7));
    final week = s.lines.where((l) => l.at.isAfter(weekAgo));
    return TechEarnings(
      weekSdg: week
          .where((l) => l.kind == LedgerKind.labour || l.kind == LedgerKind.travelFee)
          .fold(0, (sum, l) => sum + l.amountSdg),
      weekJobs: {
        for (final l in week)
          if (l.kind == LedgerKind.labour) l.ref ?? l.id,
      }.length,
      balanceSdg: s.closingSdg,
      // Cash taken from buyers for others (parts, fees) and not handed over yet.
      cashSdg: -s.lines
          .where((l) => l.kind == LedgerKind.cashCollected || l.kind == LedgerKind.cashHandover)
          .fold(0, (sum, l) => sum + l.amountSdg),
    );
  }

  final int weekSdg;
  final int weekJobs;

  /// Positive: the platform owes the technician.
  final int balanceSdg;
  final int cashSdg;
}
