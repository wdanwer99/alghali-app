import 'dart:async';

import 'package:alghali_core/alghali_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'connection.dart';
import 'outbox.dart';
import 'session.dart';

/// Distance from the street's starting point (D-077), or 0 while it isn't set.
double kmFromStreet(CatalogueData c, double? lat, double? lng) {
  final o = c.streetOrigin;
  if (o == null || lat == null || lng == null) return 0;
  return distanceKm(o.lat, o.lng, lat, lng);
}

/// The buyer's saved addresses (`addresses`, written directly under RLS), for deliveries
/// and fittings at their place. Each needs a GPS point; distances are measured from the
/// street's starting point.
class AddressesController extends AsyncNotifier<List<Address>> {
  @override
  Future<List<Address>> build() async {
    final uid = ref.watch(sessionProvider.select((s) => s.userId));
    if (uid == null) return const [];
    final catalogue = ref.watch(catalogueProvider);
    final rows = await ref.read(addressesRepositoryProvider).list();
    return [
      for (final r in rows)
        Address.fromJson(
          r,
          distanceKm: kmFromStreet(
            catalogue,
            (r['lat'] as num?)?.toDouble(),
            (r['lng'] as num?)?.toDouble(),
          ),
        ),
    ];
  }

  /// Saves a point the phone's GPS gave, with a label ("Home") and written directions.
  Future<Address> add({
    required String label,
    required String description,
    required double lat,
    required double lng,
  }) async {
    final row = await ref
        .read(addressesRepositoryProvider)
        .add(
          label: label,
          description: description,
          lat: lat,
          lng: lng,
          makeDefault: (state.value ?? const []).isEmpty,
        );
    final a = Address.fromJson(
      row,
      distanceKm: kmFromStreet(ref.read(catalogueProvider), lat, lng),
    );
    state = AsyncData([...?state.value, a]);
    return a;
  }

  Future<void> remove(String id) async {
    await ref.read(addressesRepositoryProvider).remove(id);
    state = AsyncData([
      for (final a in state.value ?? const <Address>[])
        if (a.id != id) a,
    ]);
  }
}

final addressesProvider = AsyncNotifierProvider<AddressesController, List<Address>>(
  AddressesController.new,
);

/// Sub-orders and bookings the buyer has rated on this phone (`shop:<sub_order>` or
/// `tech:<booking>`); the server also lets them change a rating for 30 days.
class ReviewedController extends Notifier<Set<String>> {
  static const _key = 'reviewed';

  @override
  Set<String> build() => {...?ref.watch(sharedPreferencesProvider).getStringList(_key)};

  /// Sends the rating (through the outbox, so it also works offline).
  Future<void> rate({
    required int stars,
    String? comment,
    String? subOrderId,
    String? bookingId,
  }) async {
    final key = subOrderId != null ? 'shop:$subOrderId' : 'tech:$bookingId';
    state = {...state, key};
    await ref.read(sharedPreferencesProvider).setStringList(_key, state.toList());
    await queue(ref, BuyerOps.review, {
      'rating': stars,
      'sub_order_id': subOrderId,
      'booking_id': bookingId,
      'comment': comment == null || comment.trim().isEmpty ? null : comment.trim(),
    });
  }
}

final reviewedProvider = NotifierProvider<ReviewedController, Set<String>>(ReviewedController.new);

/// The buyer's complaints (D-105), newest first.
class DisputesController extends AsyncNotifier<List<Dispute>> with CachedList<List<Dispute>> {
  @override
  Future<List<Dispute>> build() async {
    final uid = ref.watch(sessionProvider.select((s) => s.userId));
    if (uid == null) return const [];
    return load();
  }

  BookingsRepository get _repo => ref.read(bookingsRepositoryProvider);

  @override
  Future<List<Dispute>> fetch() => _repo.disputes();

  Future<Dispute> open({
    required DisputeCategory category,
    required String description,
    String? subOrderId,
    String? bookingId,
  }) async {
    final d = await _repo.openDispute(
      category: category,
      description: description,
      subOrderId: subOrderId,
      bookingId: bookingId,
    );
    state = AsyncData([d, ...?state.value]);
    return d;
  }

  Future<Dispute> reply(String id, String body) async {
    final d = await _repo.replyDispute(id, body);
    state = AsyncData([for (final x in state.value ?? const <Dispute>[]) x.id == id ? d : x]);
    return d;
  }
}

final disputesProvider = AsyncNotifierProvider<DisputesController, List<Dispute>>(
  DisputesController.new,
);
