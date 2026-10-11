import 'package:alghali_core/alghali_core.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A job offered to this technician; it times out after
/// `tech_accept_timeout_minutes` and goes to the next match (D-024).
@immutable
class JobOffer {
  const JobOffer({required this.booking, required this.expiresAt});

  final Booking booking;
  final DateTime expiresAt;

  String get id => booking.id;
}

/// Photos and job-code attempts kept per job.
@immutable
class JobProgress {
  const JobProgress({
    this.before = 0,
    this.after = 0,
    this.codeAttemptsLeft = 5,
    this.partReady = true,
  });

  final int before;
  final int after;

  /// Five wrong codes lock completion and alert the admin (D-028).
  final int codeAttemptsLeft;
  final bool partReady;

  JobProgress copyWith({int? before, int? after, int? codeAttemptsLeft}) => JobProgress(
    before: before ?? this.before,
    after: after ?? this.after,
    codeAttemptsLeft: codeAttemptsLeft ?? this.codeAttemptsLeft,
    partReady: partReady,
  );
}

@immutable
class TechJobs {
  const TechJobs({required this.offers, required this.jobs, required this.progress});

  final List<JobOffer> offers;
  final List<Booking> jobs;
  final Map<String, JobProgress> progress;

  JobProgress progressOf(String id) => progress[id] ?? const JobProgress();
}

enum CodeResult { ok, wrong, locked, needPhoto }

Booking _booking({
  required String id,
  required String buyer,
  required String variant,
  required BookingStatus status,
  required BookingPlace place,
  required DateTime start,
  required int minutes,
  required int labour,
  required LocalizedText title,
  required JobType job,
  int travel = 0,
  Address? address,
  String? partShopId,
  PaymentMethod method = PaymentMethod.bankak,
  String code = '4815',
}) => Booking(
  id: id,
  ref: _refFor(id),
  status: status,
  technicianId: 'tc-osman',
  place: place,
  bayShopId: place == BookingPlace.bay ? 'sh-nour' : null,
  address: address,
  startAt: start,
  durationMin: minutes,
  labourSdg: labour,
  travelFeeSdg: travel,
  bookingFeeSdg: 2000,
  method: method,
  jobCode: code,
  partShopId: partShopId,
  buyerName: buyer,
  variantId: variant,
  items: [BookingItem(title: title, jobType: job, minutes: minutes)],
  events: [StatusEvent(status, start.subtract(const Duration(days: 1)))],
);

/// A stable, valid 8-digit reference for a sample booking id.
String _refFor(String id) {
  var h = 0x811c9dc5;
  for (final c in id.codeUnits) {
    h = ((h ^ c) * 0x01000193) & 0xffffffff;
  }
  final body = '${1000000 + h % 9000000}';
  return '$body${luhnCheckDigit(body)}';
}

/// Khartoum wall-clock [hour]:[minute] on the day [days] after today.
DateTime _at(DateTime now, int days, int hour, [int minute = 0]) =>
    khartoumDay(now)
        .add(Duration(days: days, hours: hour, minutes: minute))
        .subtract(khartoumOffset);

class TechJobsController extends Notifier<TechJobs> {
  @override
  TechJobs build() {
    final now = ref.read(clockProvider)();
    const riyadh = Address(
      id: 'ad-r',
      label: LocalizedText('الرياض، شارع 15', 'Riyadh, Street 15'),
      description: LocalizedText('منزل 7، بجوار المسجد', 'House 7, next to the mosque'),
      distanceKm: 3.4,
    );
    const amarat = Address(
      id: 'ad-a',
      label: LocalizedText('العمارات، شارع 41', 'Amarat, Street 41'),
      description: LocalizedText('مكتب الطابق الثاني', 'Second-floor office'),
      distanceKm: 6.2,
    );
    return TechJobs(
      offers: [
        JobOffer(
          booking: _booking(
            id: 'bk-701',
            buyer: 'أحمد م.',
            variant: 'v-hilux-16p',
            status: BookingStatus.pendingTechAccept,
            place: BookingPlace.customer,
            start: _at(now, 1, 16),
            minutes: 30,
            labour: 6000,
            travel: 3000,
            address: riyadh,
            partShopId: 'sh-nour',
            title: const LocalizedText('لمبة هالوجين H4', 'H4 halogen bulb'),
            job: JobType.lighting,
            code: '2741',
          ),
          expiresAt: now.add(const Duration(minutes: 14, seconds: 32)),
        ),
      ],
      jobs: [
        _booking(
          id: 'bk-702',
          buyer: 'هالة ع.',
          variant: 'v-corolla-14',
          status: BookingStatus.accepted,
          place: BookingPlace.bay,
          start: _at(now, 0, 11, 30),
          minutes: 20,
          labour: 4000,
          partShopId: 'sh-nour',
          title: const LocalizedText('بطارية 55 أمبير', '55 Ah battery'),
          job: JobType.battery,
          code: '3906',
        ),
        _booking(
          id: 'bk-703',
          buyer: 'Sami K.',
          variant: 'v-accent-18',
          status: BookingStatus.accepted,
          place: BookingPlace.customer,
          start: _at(now, 0, 17),
          minutes: 60,
          labour: 12000,
          travel: 6000,
          address: amarat,
          method: PaymentMethod.cash,
          title: const LocalizedText('فحص كهرباء وتغيير فيوزات', 'Electrical check and fuses'),
          job: JobType.electrical,
          code: '5512',
        ),
        _booking(
          id: 'bk-704',
          buyer: 'عادل ك.',
          variant: 'v-sunny-12',
          status: BookingStatus.accepted,
          place: BookingPlace.bay,
          start: _at(now, 1, 9, 30),
          minutes: 30,
          labour: 6000,
          partShopId: 'sh-nour',
          title: const LocalizedText('لمبات أمامية LED مقاس H4', 'H4 LED headlight bulbs'),
          job: JobType.lighting,
        ),
      ],
      progress: const {'bk-702': JobProgress(), 'bk-703': JobProgress(partReady: false)},
    );
  }

  DateTime get _now => ref.read(clockProvider)();

  Booking? job(String id) =>
      state.jobs.where((b) => b.id == id).firstOrNull ??
      state.offers.where((o) => o.id == id).firstOrNull?.booking;

  void accept(String id) {
    final offer = state.offers.firstWhere((o) => o.id == id);
    state = TechJobs(
      offers: state.offers.where((o) => o.id != id).toList(),
      jobs: [...state.jobs, offer.booking.copyWith(status: BookingStatus.accepted, at: _now)]
        ..sort((a, b) => a.startAt.compareTo(b.startAt)),
      progress: state.progress,
    );
  }

  void decline(String id) => state = TechJobs(
    offers: state.offers.where((o) => o.id != id).toList(),
    jobs: state.jobs,
    progress: state.progress,
  );

  void onMyWay(String id) => _set(id, BookingStatus.enRoute);
  void checkIn(String id) => _set(id, BookingStatus.inProgress);
  void partDoesNotFit(String id) => _set(id, BookingStatus.partDoesNotFit);

  void addPhoto(String id, {required bool after}) {
    final p = state.progressOf(id);
    _progress(id, after ? p.copyWith(after: p.after + 1) : p.copyWith(before: p.before + 1));
  }

  /// Checks the buyer's code (the server does this in `tech_complete`).
  CodeResult complete(String id, String code) {
    final b = job(id)!;
    final p = state.progressOf(id);
    if (p.codeAttemptsLeft <= 0) return CodeResult.locked;
    if (p.after == 0) return CodeResult.needPhoto;
    if (code != b.jobCode) {
      _progress(id, p.copyWith(codeAttemptsLeft: p.codeAttemptsLeft - 1));
      return p.codeAttemptsLeft - 1 <= 0 ? CodeResult.locked : CodeResult.wrong;
    }
    _set(id, BookingStatus.completed);
    return CodeResult.ok;
  }

  /// Demo only: a new job comes in.
  void demoNewOffer() {
    final now = _now;
    state = TechJobs(
      offers: [
        JobOffer(
          booking: _booking(
            id: 'bk-${now.microsecondsSinceEpoch}',
            buyer: 'Huda K.',
            variant: 'v-elantra-16',
            status: BookingStatus.pendingTechAccept,
            place: BookingPlace.bay,
            start: _at(now, 2, 10),
            minutes: 20,
            labour: 4000,
            partShopId: 'sh-baraka',
            title: const LocalizedText('بطارية 55 أمبير', '55 Ah battery'),
            job: JobType.battery,
          ),
          expiresAt: now.add(const Duration(minutes: 20)),
        ),
        ...state.offers,
      ],
      jobs: state.jobs,
      progress: state.progress,
    );
  }

  void _set(String id, BookingStatus status) => state = TechJobs(
    offers: state.offers,
    jobs: [for (final b in state.jobs) b.id == id ? b.copyWith(status: status, at: _now) : b],
    progress: state.progress,
  );

  void _progress(String id, JobProgress p) => state = TechJobs(
    offers: state.offers,
    jobs: state.jobs,
    progress: {...state.progress, id: p},
  );
}

final techJobsProvider = NotifierProvider<TechJobsController, TechJobs>(TechJobsController.new);

class OnlineController extends Notifier<bool> {
  @override
  bool build() => true;

  void set(bool v) => state = v;
}

final techOnlineProvider = NotifierProvider<OnlineController, bool>(OnlineController.new);

@immutable
class TechSchedule {
  const TechSchedule({required this.hours, required this.timeOff, this.blockedUntil});

  /// By [DateTime.weekday]; empty list = day off.
  final Map<int, List<AvailabilityWindow>> hours;
  final List<TimeOff> timeOff;

  /// Quick block (`tech_quick_block`): no new jobs until then.
  final DateTime? blockedUntil;
}

class ScheduleController extends Notifier<TechSchedule> {
  @override
  TechSchedule build() => const TechSchedule(hours: defaultWeeklyHours, timeOff: []);

  void toggleDay(int weekday, bool working) => state = TechSchedule(
    hours: {...state.hours, weekday: working ? defaultWeeklyHours[DateTime.saturday]! : const []},
    timeOff: state.timeOff,
    blockedUntil: state.blockedUntil,
  );

  void block(Duration? d) {
    final now = ref.read(clockProvider)();
    // Null = the rest of today (Khartoum midnight).
    final until = d == null
        ? khartoumDay(now).add(const Duration(days: 1)).subtract(khartoumOffset)
        : now.add(d);
    state = TechSchedule(hours: state.hours, timeOff: state.timeOff, blockedUntil: until);
  }

  void unblock() => state = TechSchedule(hours: state.hours, timeOff: state.timeOff);

  void addDayOffTomorrow() {
    final now = ref.read(clockProvider)();
    final from = khartoumDay(now).add(const Duration(days: 1)).subtract(khartoumOffset);
    state = TechSchedule(
      hours: state.hours,
      timeOff: [
        ...state.timeOff,
        TimeOff(
          id: 'to-${state.timeOff.length + 1}',
          from: from,
          to: from.add(const Duration(days: 1)),
          reason: const LocalizedText('إجازة', 'Day off'),
        ),
      ],
      blockedUntil: state.blockedUntil,
    );
  }

  void removeTimeOff(String id) => state = TechSchedule(
    hours: state.hours,
    timeOff: state.timeOff.where((t) => t.id != id).toList(),
    blockedUntil: state.blockedUntil,
  );
}

final scheduleProvider = NotifierProvider<ScheduleController, TechSchedule>(ScheduleController.new);

/// Labour prices, work mode and radius the technician can edit.
@immutable
class TechProfile {
  const TechProfile({required this.labour, required this.mode, required this.radiusKm});

  final Map<JobType, int> labour;
  final WorkMode mode;
  final int radiusKm;
}

class TechProfileController extends Notifier<TechProfile> {
  @override
  TechProfile build() {
    final t = ref.watch(catalogueProvider).technician('tc-osman');
    return TechProfile(labour: t.labourSdg, mode: t.mode, radiusKm: t.radiusKm);
  }

  void setLabour(JobType job, int sdg) => state = TechProfile(
    labour: {...state.labour, job: sdg},
    mode: state.mode,
    radiusKm: state.radiusKm,
  );

  void setMode(WorkMode m) =>
      state = TechProfile(labour: state.labour, mode: m, radiusKm: state.radiusKm);

  void setRadius(int km) =>
      state = TechProfile(labour: state.labour, mode: state.mode, radiusKm: km);
}

final techProfileProvider = NotifierProvider<TechProfileController, TechProfile>(
  TechProfileController.new,
);

@immutable
class TechEarnings {
  const TechEarnings({
    required this.weekSdg,
    required this.weekJobs,
    required this.balanceSdg,
    required this.cashHeldSdg,
    required this.lines,
    required this.nextPayout,
  });

  final int weekSdg;
  final int weekJobs;
  final int balanceSdg;
  final int cashHeldSdg;
  final List<LedgerLine> lines;
  final DateTime nextPayout;
}

final techEarningsProvider = Provider<TechEarnings>((ref) {
  final now = ref.watch(clockProvider)();
  final done = ref.watch(techJobsProvider).jobs.where((b) => b.status == BookingStatus.completed);
  DateTime ago(int h) => now.subtract(Duration(hours: h));
  final lines = <LedgerLine>[
    for (final b in done) ...[
      LedgerLine(id: '${b.id}-l', kind: LedgerKind.labour, amountSdg: b.labourSdg, at: now),
      if (b.travelFeeSdg > 0)
        LedgerLine(id: '${b.id}-t', kind: LedgerKind.travelFee, amountSdg: b.travelFeeSdg, at: now),
    ],
    LedgerLine(id: 'tl-1', kind: LedgerKind.labour, amountSdg: 6000, at: ago(5)),
    LedgerLine(id: 'tl-2', kind: LedgerKind.travelFee, amountSdg: 3000, at: ago(5)),
    LedgerLine(id: 'tl-3', kind: LedgerKind.cashCollected, amountSdg: -18000, at: ago(28)),
    LedgerLine(id: 'tl-4', kind: LedgerKind.labour, amountSdg: 12000, at: ago(28)),
    LedgerLine(id: 'tl-5', kind: LedgerKind.bookingFee, amountSdg: -2000, at: ago(28)),
    LedgerLine(id: 'tl-6', kind: LedgerKind.labour, amountSdg: 4000, at: ago(50)),
  ];
  final extra = done.fold(0, (s, b) => s + b.labourSdg + b.travelFeeSdg);
  return TechEarnings(
    weekSdg: 54000 + extra,
    weekJobs: 6 + done.length,
    balanceSdg: 31000 + extra,
    cashHeldSdg: 18000,
    lines: lines,
    nextPayout: _nextSunday(now),
  );
});

DateTime _nextSunday(DateTime now) {
  var d = khartoumDay(now).add(const Duration(days: 1));
  while (d.weekday != DateTime.sunday) {
    d = d.add(const Duration(days: 1));
  }
  return d.add(const Duration(hours: 10));
}
