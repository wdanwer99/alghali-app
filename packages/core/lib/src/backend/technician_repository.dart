import 'dart:typed_data';

import 'package:flutter/foundation.dart' show immutable;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/catalogue.dart';
import '../models/commerce.dart';
import '../models/installation.dart';
import '../models/partner.dart';
import 'backend_error.dart';
import 'uploads.dart';

/// What `tech_complete` answers. A wrong code isn't an error (the try must be counted):
/// [ok] is false with [attemptsLeft]; at zero the code locks and only an admin can close
/// the job (D-028).
@immutable
class CompleteResult {
  const CompleteResult({required this.ok, this.error, this.attemptsLeft, this.booking});

  final bool ok;

  /// WRONG_JOB_CODE or JOB_CODE_LOCKED.
  final String? error;
  final int? attemptsLeft;
  final Booking? booking;
}

/// The partner app's technician side: applying, profile, prices, hours and time off, job
/// offers and the job day (on the way, check-in, photos, the buyer's code), and earnings.
class TechnicianRepository {
  TechnicianRepository(this._client);

  final SupabaseClient _client;

  static const _select =
      '*, technician_job_types(labour_sdg, job_types(id, code, name_ar, name_en)), technician_makes(make_id), '
      'availability_rules(*), time_off(*), bay:shops!technicians_home_bay_shop_id_fkey(id, name_ar, name_en, plot_no, zone_id)';

  static List<Json> _jobs(Map<String, int> labourByJobTypeId) => [
    for (final MapEntry(:key, :value) in labourByJobTypeId.entries)
      {'job_type_id': key, 'labour_sdg': value},
  ];

  /// [labourByJobTypeId]: job type id → labour SDG. BAY and BOTH need [bayShopId];
  /// MOBILE and BOTH need the home point. An admin approves the application.
  Future<void> apply({
    required WorkMode mode,
    required Map<String, int> labourByJobTypeId,
    required String phone,
    Set<String> makeIds = const {},
    String? bayShopId,
    double? homeLat,
    double? homeLng,
    int radiusKm = 10,
    int yearsExperience = 0,
    String? bio,
    String? idem,
  }) => guard(
    () => _client.rpc<Json>(
      'apply_as_technician',
      params: {
        'p_work_mode': workModeCode(mode),
        'p_job_types': _jobs(labourByJobTypeId),
        'p_phone': phone,
        'p_make_ids': makeIds.toList(),
        'p_home_bay_shop_id': bayShopId,
        'p_home_lat': homeLat,
        'p_home_lng': homeLng,
        'p_radius_km': radiusKm,
        'p_years_experience': yearsExperience,
        'p_bio_ar': bio,
        'p_idem': idem ?? newIdempotencyKey(),
      },
    ),
  );

  /// Null until the user applies.
  Future<MyTechnician?> me() => guard(() async {
    final uid = signedInUserId(_client);
    final row = await _client.from('technicians').select(_select).eq('user_id', uid).maybeSingle();
    return row == null ? null : MyTechnician.fromJson(row);
  });

  /// Only the keys in [patch] change: work_mode, home_bay_shop_id, home_lat, home_lng,
  /// radius_km, years_experience, bio_ar, bio_en, avatar_key, employer_shop_id.
  Future<void> updateProfile(Json patch) =>
      guard(() => _client.rpc<Json>('tech_update_profile', params: {'p_patch': patch}));

  Future<void> setJobs(Map<String, int> labourByJobTypeId) => guard(
    () => _client.rpc<Json>('tech_set_job_types', params: {'p_items': _jobs(labourByJobTypeId)}),
  );

  /// Empty: every make.
  Future<void> setMakes(Set<String> makeIds) =>
      guard(() => _client.rpc<Json>('tech_set_makes', params: {'p_make_ids': makeIds.toList()}));

  /// Weekly hours are the technician's own rows (RLS); [weekday] 0 = Sunday, Khartoum time.
  Future<AvailabilityRule> addRule({
    required String technicianId,
    required int weekday,
    required int startMin,
    required int endMin,
    WorkMode modes = WorkMode.both,
  }) => guard(() async {
    final row = await _client
        .from('availability_rules')
        .insert({
          'technician_id': technicianId,
          'weekday': weekday,
          'start_min': startMin,
          'end_min': endMin,
          'modes': workModeCode(modes),
        })
        .select()
        .single();
    return AvailabilityRule.fromJson(row);
  });

  Future<void> removeRule(String ruleId) =>
      guard(() => _client.from('availability_rules').delete().eq('id', ruleId));

  Future<void> addTimeOff({
    required String technicianId,
    required DateTime from,
    required DateTime to,
    String? reason,
  }) => guard(
    () => _client.from('time_off').insert({
      'technician_id': technicianId,
      'period': '[${from.toUtc().toIso8601String()},${to.toUtc().toIso8601String()})',
      'reason': reason,
    }),
  );

  Future<void> removeTimeOff(String timeOffId) =>
      guard(() => _client.from('time_off').delete().eq('id', timeOffId));

  /// "Busy for the next [minutes]" (5–720).
  Future<void> quickBlock(int minutes, {String? reason}) => guard(
    () => _client.rpc<Json>('tech_quick_block', params: {'p_minutes': minutes, 'p_reason': reason}),
  );

  // ---------------------------------------------------------------- jobs

  Future<List<Booking>> _scope(String scope, int limit) => guard(() async {
    final rows = await _client.rpc<List<dynamic>>(
      'tech_bookings',
      params: {'p_scope': scope, 'p_limit': limit},
    );
    return [for (final r in rows.cast<Json>()) Booking.fromJson(r)];
  });

  /// Jobs offered to this technician, waiting for an answer ([Booking.offer] has the deadline).
  Future<List<Booking>> offers() => _scope('OFFERS', 50);

  /// Accepted, on the way and in progress, soonest first.
  Future<List<Booking>> upcoming() => _scope('UPCOMING', 50);
  Future<List<Booking>> past({int limit = 50}) => _scope('PAST', limit);

  /// Declining passes the job to the next technician for the same time.
  Future<Booking> respond(String offerId, {required bool accept, String? reason}) =>
      guard(() async {
        final row = await _client.rpc<Json>(
          'tech_respond_offer',
          params: {'p_offer_id': offerId, 'p_accept': accept, 'p_reason': reason},
        );
        return Booking.fromJson(row);
      });

  /// Jobs at the buyer's place only; the parts must be collected first (PARTS_NOT_COLLECTED).
  Future<Booking> enRoute(String bookingId) => _booking('tech_en_route', bookingId);

  /// While on the way; the buyer sees it live.
  Future<void> updateLocation(String bookingId, double lat, double lng) => guard(
    () => _client.rpc<void>(
      'tech_update_location',
      params: {'p_booking_id': bookingId, 'p_lat': lat, 'p_lng': lng},
    ),
  );

  /// At most two hours before the start.
  Future<Booking> checkIn(String bookingId) => _booking('tech_check_in', bookingId);

  /// Uploads to booking-photos/{booking id}/…, then attaches it (up to 10).
  Future<Booking> addPhoto(
    String bookingId,
    Uint8List jpeg, {
    required bool before,
    String fileName = 'photo.jpg',
  }) => guard(() async {
    final key = '$bookingId/${newIdempotencyKey()}${extensionOf(fileName)}';
    await _client.storage
        .from('booking-photos')
        .uploadBinary(key, jpeg, fileOptions: FileOptions(contentType: mimeOf(fileName)));
    final row = await _client.rpc<Json>(
      'tech_add_photo',
      params: {
        'p_booking_id': bookingId,
        'p_kind': before ? 'BEFORE' : 'AFTER',
        'p_image_key': key,
      },
    );
    return Booking.fromJson(row);
  });

  /// Closes the job with the buyer's 4-digit code.
  Future<CompleteResult> complete(String bookingId, String code) => guard(() async {
    final row = await _client.rpc<Json>(
      'tech_complete',
      params: {'p_booking_id': bookingId, 'p_code': code},
    );
    final booking = row['booking'] as Json?;
    return CompleteResult(
      ok: row['ok'] as bool,
      error: row['error'] as String?,
      attemptsLeft: row['attempts_left'] as int?,
      booking: booking == null ? null : Booking.fromJson(booking),
    );
  });

  /// At check-in the part doesn't fit: the buyer pays the travel fee only (D-019).
  Future<Booking> partDoesNotFit(String bookingId, String reason) => guard(() async {
    final row = await _client.rpc<Json>(
      'tech_part_not_fit',
      params: {'p_booking_id': bookingId, 'p_reason': reason},
    );
    return Booking.fromJson(row);
  });

  /// Drops an accepted job before starting; it goes to the next free technician.
  Future<void> cancel(String bookingId, String reason) => guard(
    () => _client.rpc<Json>('tech_cancel', params: {'p_booking_id': bookingId, 'p_reason': reason}),
  );

  Future<Booking> _booking(String fn, String bookingId) => guard(() async {
    final row = await _client.rpc<Json>(fn, params: {'p_booking_id': bookingId});
    return Booking.fromJson(row);
  });

  /// Earnings: labour and travel fees, cash taken, payouts (positive = the platform owes).
  Future<ShopStatement> statement({DateTime? from, DateTime? to}) => guard(() async {
    final row = await _client.rpc<Json>(
      'tech_statement',
      params: {'p_from': from?.toUtc().toIso8601String(), 'p_to': to?.toUtc().toIso8601String()},
    );
    return ShopStatement.fromJson(row);
  });
}
