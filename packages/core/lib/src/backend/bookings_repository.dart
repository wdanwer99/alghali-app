import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/catalogue.dart';
import '../models/commerce.dart';
import '../models/installation.dart';
import 'backend_error.dart';
import 'read_cache.dart';

/// The buyer's fittings: technicians and free times (the `booking-slots` Edge Function),
/// holding a time, then paying through checkout (`OrdersRepository.checkout` with the
/// booking), and afterwards cancelling, picking a new time, following the technician,
/// rating and complaining.
class BookingsRepository with CachedReads {
  BookingsRepository(this._client, {this.cache});

  final SupabaseClient _client;
  @override
  final ReadCache? cache;

  /// Technicians who can fit [items] and their free starts over the next days. For a job
  /// at the buyer's place give [addressId] (signed in) or [lat]/[lng] (guests).
  /// [technicianId] lists that technician's every start.
  Future<BookingOptions> options({
    required List<FittingItem> items,
    required BookingPlace place,
    String? addressId,
    double? lat,
    double? lng,
    String? variantId,
    String? technicianId,
  }) => guard(() async {
    final res = await _client.functions.invoke(
      'booking-slots',
      body: {
        'items': [for (final i in items) i.toJson()],
        'place': place.code,
        'address_id': ?addressId,
        'lat': ?lat,
        'lng': ?lng,
        'variant_id': ?variantId,
        'technician_id': ?technicianId,
      },
    );
    return BookingOptions.fromJson(res.data as Json);
  });

  /// Holds [start] with the technician for a few minutes while the buyer checks out
  /// (D-022). SLOT_TAKEN when someone was quicker. [any]: the technician came from the
  /// "any available" list.
  Future<Booking> hold({
    required String technicianId,
    required DateTime start,
    required List<FittingItem> items,
    required BookingPlace place,
    String? addressId,
    String? locationNote,
    String? variantId,
    bool any = false,
    String? idem,
  }) => guard(() async {
    final row = await _client.rpc<Json>(
      'create_booking_hold',
      params: {
        'p_technician_id': technicianId,
        'p_start_at': start.toUtc().toIso8601String(),
        'p_items': [for (final i in items) i.toJson()],
        'p_place': place.code,
        'p_address_id': addressId,
        'p_location_note': locationNote,
        'p_variant_id': variantId,
        'p_assignment_mode': any ? 'ANY' : 'CHOSEN',
        'p_idem': idem ?? newIdempotencyKey(),
      },
    );
    return Booking.fromJson(row);
  });

  Future<void> release(String bookingId) =>
      guard(() => _client.rpc<void>('release_booking_hold', params: {'p_booking_id': bookingId}));

  /// Newest first. The first page is kept for offline use.
  Future<List<Booking>> mine({int limit = 30, int offset = 0}) => cachedRead(
    offset == 0 ? '@bookings' : '@bookings:$offset',
    () => _client.rpc<List<dynamic>>('my_bookings', params: {'p_limit': limit, 'p_offset': offset}),
    _bookings,
  );

  /// The saved first page, without asking the network.
  Future<List<Booking>?> peek() => cachedPeek('@bookings', _bookings);

  static List<Booking> _bookings(Object? raw) => [
    for (final r in (raw! as List).cast<Json>()) Booking.fromJson(r),
  ];

  Future<Booking> get(String bookingId) => cachedRead(
    '@booking:$bookingId',
    () => _client.rpc<Json>('booking_detail', params: {'p_booking_id': bookingId}),
    (raw) => Booking.fromJson(raw! as Json),
  );

  /// Free until cancel_cutoff_hours before the start; later the booking fee and travel
  /// fee are kept (D-099). While still unpaid, the whole order is cancelled.
  Future<Booking> cancel(String bookingId, {String? reason}) => guard(() async {
    final row = await _client.rpc<Json>(
      'buyer_cancel_booking',
      params: {'p_booking_id': bookingId, 'p_reason': reason},
    );
    return Booking.fromJson(row);
  });

  /// After NEEDS_RESCHEDULE: a new start from [options], maybe with another technician.
  Future<Booking> reschedule(String bookingId, DateTime start, {String? technicianId}) =>
      guard(() async {
        final row = await _client.rpc<Json>(
          'buyer_reschedule',
          params: {
            'p_booking_id': bookingId,
            'p_start_at': start.toUtc().toIso8601String(),
            'p_technician_id': technicianId,
          },
        );
        return Booking.fromJson(row);
      });

  Future<TechnicianProfile?> technician(String technicianId) => guard(() async {
    final row = await _client.rpc<Json?>(
      'technician_profile',
      params: {'p_technician_id': technicianId},
    );
    return row == null ? null : TechnicianProfile.fromJson(row);
  });

  /// The technician's position while on the way (D-029), live; ends at check-in.
  Stream<({double lat, double lng, DateTime at})> technicianLocation(String bookingId) {
    late final RealtimeChannel channel;
    late final StreamController<({double lat, double lng, DateTime at})> controller;
    void emit(Json row) => controller.add((
      lat: (row['lat'] as num).toDouble(),
      lng: (row['lng'] as num).toDouble(),
      at: DateTime.parse(row['updated_at'] as String),
    ));
    controller = StreamController(
      onListen: () async {
        channel = _client
            .channel('tech-location:$bookingId')
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'tech_locations',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'booking_id',
                value: bookingId,
              ),
              callback: (payload) {
                if (payload.newRecord.isNotEmpty) emit(payload.newRecord);
              },
            )
            .subscribe();
        try {
          final now = await _client
              .from('tech_locations')
              .select()
              .eq('booking_id', bookingId)
              .maybeSingle();
          if (now != null) emit(now);
        } on Object catch (_) {
          // The live updates still come.
        }
      },
      onCancel: () => _client.removeChannel(channel),
    );
    return controller.stream;
  }

  /// Hour-long links to the job's before/after photos, by key; ones that can't be signed
  /// are left out.
  Future<Map<String, String>> photoUrls(List<String> keys) => guard(() async {
    if (keys.isEmpty) return const {};
    final urls = await _client.storage.from('booking-photos').createSignedUrlsResult(keys, 3600);
    return {for (final u in urls.whereType<SignedUrlSuccess>()) u.path: u.signedUrl};
  });

  // ---------------------------------------------------------------- reviews

  /// Rates the shop for a received sub-order, or the technician for a finished fitting.
  /// Rating again within 30 days changes the review.
  Future<void> review({
    required int rating,
    String? subOrderId,
    String? bookingId,
    String? comment,
  }) => guard(
    () => _client.rpc<Json>(
      'create_review',
      params: {
        'p_rating': rating,
        'p_sub_order_id': subOrderId,
        'p_booking_id': bookingId,
        'p_comment': comment,
      },
    ),
  );

  Future<List<Review>> reviews({String? shopId, String? technicianId, int limit = 20}) =>
      guard(() async {
        final rows = await _client.rpc<List<dynamic>>(
          'reviews_for',
          params: {'p_shop_id': shopId, 'p_technician_id': technicianId, 'p_limit': limit},
        );
        return [
          for (final r in rows.cast<Json>())
            reviewFromJson(r, shopId: shopId, technicianId: technicianId),
        ];
      });

  // --------------------------------------------------------------- disputes

  /// Opened by the buyer, a shop member (sub-order) or the technician (booking).
  Future<Dispute> openDispute({
    required DisputeCategory category,
    required String description,
    String? subOrderId,
    String? bookingId,
  }) => guard(() async {
    final row = await _client.rpc<Json>(
      'open_dispute',
      params: {
        'p_category': disputeCategoryCode(category),
        'p_description': description,
        'p_sub_order_id': subOrderId,
        'p_booking_id': bookingId,
      },
    );
    return Dispute.fromJson(row);
  });

  Future<Dispute> replyDispute(String disputeId, String body) => guard(() async {
    final row = await _client.rpc<Json>(
      'dispute_reply',
      params: {'p_dispute_id': disputeId, 'p_body': body},
    );
    return Dispute.fromJson(row);
  });

  Future<List<Dispute>> disputes({int limit = 30}) => guard(() async {
    final rows = await _client.rpc<List<dynamic>>('my_disputes', params: {'p_limit': limit});
    return [for (final r in rows.cast<Json>()) Dispute.fromJson(r)];
  });
}
