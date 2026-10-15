import 'dart:async';
import 'dart:convert';

import 'package:alghali_core/alghali_core.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'session.dart';

/// The buyer's fittings, newest first: the saved copy at once, then the server's.
class BookingsController extends AsyncNotifier<List<Booking>> with CachedList<List<Booking>> {
  @override
  Future<List<Booking>> build() async {
    final uid = ref.watch(sessionProvider.select((s) => s.userId));
    if (uid == null) return const [];
    return load();
  }

  BookingsRepository get _repo => ref.read(bookingsRepositoryProvider);

  @override
  Future<List<Booking>?> peek() => _repo.peek();

  // A HELD booking is still being checked out; the cart shows it.
  @override
  Future<List<Booking>> fetch() async =>
      (await _repo.mine()).where((b) => b.status != BookingStatus.held).toList();

  void put(Booking b) {
    final list = state.value ?? const <Booking>[];
    final i = list.indexWhere((x) => x.id == b.id);
    state = AsyncData(i < 0 ? [b, ...list] : [for (final x in list) x.id == b.id ? b : x]);
  }
}

final bookingsProvider = AsyncNotifierProvider<BookingsController, List<Booking>>(
  BookingsController.new,
);

/// One fitting, with the buyer's actions on it.
class BookingController extends AsyncNotifier<Booking> {
  BookingController(this.id);

  final String id;

  BookingsRepository get _repo => ref.read(bookingsRepositoryProvider);

  @override
  Future<Booking> build() async {
    final listed = ref.read(bookingsProvider).value?.where((b) => b.id == id).firstOrNull;
    if (listed != null) {
      unawaited(Future.microtask(refresh));
      return listed;
    }
    return _repo.get(id);
  }

  Future<void> refresh() async {
    try {
      final b = await _repo.get(id);
      if (!ref.mounted) return;
      state = AsyncData(b);
      ref.read(bookingsProvider.notifier).put(b);
    } on Object catch (e, st) {
      if (ref.mounted && !state.hasValue) state = AsyncError(e, st);
    }
  }

  Booking _apply(Booking b) {
    if (ref.mounted) state = AsyncData(b);
    ref.read(bookingsProvider.notifier).put(b);
    return b;
  }

  Future<Booking> cancel({String? reason}) async => _apply(await _repo.cancel(id, reason: reason));

  /// After NEEDS_RESCHEDULE: a new start, maybe with another technician.
  Future<Booking> reschedule(DateTime start, {String? technicianId}) async =>
      _apply(await _repo.reschedule(id, start, technicianId: technicianId));
}

final bookingProvider = AsyncNotifierProvider.autoDispose
    .family<BookingController, Booking, String>(BookingController.new);

/// Where the technician is while on the way (D-029), live.
final technicianLocationProvider = StreamProvider.autoDispose
    .family<({double lat, double lng, DateTime at}), String>(
      (ref, bookingId) => ref.watch(bookingsRepositoryProvider).technicianLocation(bookingId),
    );

/// Signed links for a job's before/after photos.
final bookingPhotoUrlsProvider = FutureProvider.autoDispose.family<Map<String, String>, String>((
  ref,
  keys,
) {
  final list = keys.isEmpty ? const <String>[] : keys.split('\n');
  return ref.watch(bookingsRepositoryProvider).photoUrls(list);
});

/// What the booking flow asks `booking-slots` for. Equal queries share one answer.
@immutable
class FittingQuery {
  const FittingQuery({
    required this.items,
    required this.place,
    this.addressId,
    this.variantId,
    this.technicianId,
  });

  final List<FittingItem> items;
  final BookingPlace place;
  final String? addressId;
  final String? variantId;
  final String? technicianId;

  FittingQuery forTechnician(String? id) => FittingQuery(
    items: items,
    place: place,
    addressId: addressId,
    variantId: variantId,
    technicianId: id,
  );

  String get _key => jsonEncode([
    for (final i in items) i.toJson(),
    place.code,
    addressId,
    variantId,
    technicianId,
  ]);

  @override
  bool operator ==(Object other) => other is FittingQuery && other._key == _key;

  @override
  int get hashCode => _key.hashCode;
}

/// Technicians and free times for a job (the slot engine, PLAN §5).
final bookingOptionsProvider = FutureProvider.autoDispose.family<BookingOptions, FittingQuery>((
  ref,
  q,
) async {
  final options = await ref
      .watch(bookingsRepositoryProvider)
      .options(
        items: q.items,
        place: q.place,
        addressId: q.addressId,
        variantId: q.variantId,
        technicianId: q.technicianId,
      );
  ref.read(onlineProvider.notifier).online();
  return options;
});

/// A technician's public profile, for the booking screen.
final technicianProfileProvider = FutureProvider.autoDispose.family<TechnicianProfile?, String>(
  (ref, id) => ref.watch(bookingsRepositoryProvider).technician(id),
);
