import 'package:flutter/foundation.dart' show immutable;

import 'catalogue.dart';
import 'commerce.dart';
import 'partner.dart';

WorkMode workModeOf(String code) => switch (code) {
  'BAY' => WorkMode.bay,
  'MOBILE' => WorkMode.mobile,
  _ => WorkMode.both,
};

String workModeCode(WorkMode m) => switch (m) {
  WorkMode.bay => 'BAY',
  WorkMode.mobile => 'MOBILE',
  WorkMode.both => 'BOTH',
};

/// What is to be fitted, as the booking calls take it (`resolve_booking_items`).
@immutable
class FittingItem {
  const FittingItem.listing(String this.listingId)
    : offerId = null,
      orderItemId = null,
      partId = null,
      categoryId = null,
      description = null;
  const FittingItem.offer(String this.offerId)
    : listingId = null,
      orderItemId = null,
      partId = null,
      categoryId = null,
      description = null;

  /// A part from one of the buyer's earlier orders.
  const FittingItem.orderItem(String this.orderItemId)
    : listingId = null,
      offerId = null,
      partId = null,
      categoryId = null,
      description = null;

  /// A catalogue part bought elsewhere.
  const FittingItem.part(String this.partId, {this.description})
    : listingId = null,
      offerId = null,
      orderItemId = null,
      categoryId = null;

  /// Something bought elsewhere, described by the buyer.
  const FittingItem.category(String this.categoryId, String this.description)
    : listingId = null,
      offerId = null,
      orderItemId = null,
      partId = null;

  final String? listingId;
  final String? offerId;
  final String? orderItemId;
  final String? partId;
  final String? categoryId;
  final String? description;

  /// The same item again (to pick a new time for a booking).
  static FittingItem? fromBooking(BookingItem i) {
    if (i.orderItemId != null) return FittingItem.orderItem(i.orderItemId!);
    if (i.listingId != null) return FittingItem.listing(i.listingId!);
    if (i.offerId != null) return FittingItem.offer(i.offerId!);
    if (i.partId != null) return FittingItem.part(i.partId!, description: i.description);
    if (i.categoryId != null) return FittingItem.category(i.categoryId!, i.description ?? '');
    return null;
  }

  Json toJson() => {
    if (listingId != null) 'listing_id': listingId,
    if (offerId != null) 'offer_id': offerId,
    if (orderItemId != null) 'order_item_id': orderItemId,
    if (partId != null) 'part_id': partId,
    if (categoryId != null) 'category_id': categoryId,
    if (description != null) 'description': description,
  };
}

/// The workshop bay on the street where a technician works.
@immutable
class Bay {
  const Bay({required this.shopId, required this.name, this.plotNo, this.zoneId});

  factory Bay.fromJson(Json j) => Bay(
    shopId: (j['shop_id'] ?? j['id']) as String,
    name: LocalizedText.fromJson(j, 'name'),
    plotNo: j['plot_no'] as String?,
    zoneId: j['zone_id'] as String?,
  );

  final String shopId;
  final LocalizedText name;
  final String? plotNo;
  final String? zoneId;
}

/// One technician in the `booking-slots` answer: price, ranking score, free times.
@immutable
class TechnicianOption {
  const TechnicianOption({
    required this.id,
    required this.name,
    required this.rating,
    required this.ratingCount,
    required this.completedJobs,
    required this.yearsExperience,
    required this.mode,
    required this.labourSdg,
    required this.score,
    required this.slotCount,
    this.verified = false,
    this.avatarKey,
    this.bio,
    this.distanceKm,
    this.bay,
    this.nextSlot,
    this.slots = const <DateTime>[],
  });

  factory TechnicianOption.fromJson(Json j) {
    final bioAr = j['bio_ar'] as String?;
    return TechnicianOption(
      id: j['id'] as String,
      name: j['name'] as String? ?? '',
      rating: (j['rating_avg'] as num).toDouble(),
      ratingCount: j['rating_count'] as int? ?? 0,
      completedJobs: j['completed_jobs'] as int? ?? 0,
      yearsExperience: j['years_experience'] as int? ?? 0,
      mode: workModeOf(j['work_mode'] as String),
      labourSdg: j['labour_sdg'] as int,
      score: (j['score'] as num?)?.toDouble() ?? 0,
      slotCount: j['slot_count'] as int? ?? 0,
      verified: j['verified'] as bool? ?? false,
      avatarKey: j['avatar_key'] as String?,
      bio: bioAr == null ? null : LocalizedText(bioAr, j['bio_en'] as String? ?? bioAr),
      distanceKm: (j['distance_km'] as num?)?.toDouble(),
      bay: j['bay'] == null ? null : Bay.fromJson(j['bay'] as Json),
      nextSlot: DateTime.tryParse(j['next_slot'] as String? ?? ''),
      slots: [
        for (final s in [...?(j['slots'] as List?)?.cast<String>()]) DateTime.parse(s),
      ],
    );
  }

  final String id;
  final String name;
  final double rating;
  final int ratingCount;
  final int completedJobs;
  final int yearsExperience;
  final WorkMode mode;

  /// For this job, at this technician's prices (one price per job type, D-010).
  final int labourSdg;
  final double score;
  final int slotCount;
  final bool verified;
  final String? avatarKey;
  final LocalizedText? bio;

  /// From the technician's home to the buyer (jobs at the buyer's place only).
  final double? distanceKm;
  final Bay? bay;
  final DateTime? nextSlot;

  /// Every free start; only when one technician was asked for.
  final List<DateTime> slots;
}

/// The `booking-slots` answer: the job's length and fees, the technicians who can do it,
/// and "any available" (each start with the best technician who has it, PLAN §5).
@immutable
class BookingOptions {
  const BookingOptions({
    required this.durationMin,
    required this.travelFeeSdg,
    required this.bookingFeeSdg,
    required this.mobileDepositSdg,
    required this.technicians,
    required this.any,
    this.labourRange,
  });

  factory BookingOptions.fromJson(Json j) {
    final range = (j['labour_range'] as List?)?.cast<int>();
    return BookingOptions(
      durationMin: j['duration_min'] as int,
      travelFeeSdg: j['travel_fee_sdg'] as int? ?? 0,
      bookingFeeSdg: j['booking_fee_sdg'] as int? ?? 0,
      mobileDepositSdg: j['mobile_deposit_sdg'] as int? ?? 0,
      labourRange: range == null || range.length != 2 ? null : (min: range[0], max: range[1]),
      technicians: [
        for (final t in (j['technicians'] as List).cast<Json>()) TechnicianOption.fromJson(t),
      ],
      any: [
        for (final a in [...?(j['any'] as List?)?.cast<Json>()])
          (start: DateTime.parse(a['start'] as String), technicianId: a['technician_id'] as String),
      ],
    );
  }

  final int durationMin;
  final int travelFeeSdg;
  final int bookingFeeSdg;

  /// Paid by Bankak first when paying the rest in cash at the buyer's place (D-019).
  final int mobileDepositSdg;
  final ({int min, int max})? labourRange;
  final List<TechnicianOption> technicians;
  final List<({DateTime start, String technicianId})> any;
}

/// A job type a technician does, at their price.
@immutable
class TechnicianJob {
  const TechnicianJob({
    required this.jobTypeId,
    required this.name,
    required this.labourSdg,
    this.jobType,
  });

  factory TechnicianJob.fromJson(Json j) {
    final nested = j['job_types'] as Json?;
    final src = nested ?? j;
    return TechnicianJob(
      jobTypeId: (src['id'] ?? j['job_type_id']) as String,
      name: LocalizedText.fromJson(src, 'name'),
      jobType: JobType.fromCode(src['code'] as String?),
      labourSdg: j['labour_sdg'] as int,
    );
  }

  final String jobTypeId;
  final LocalizedText name;
  final JobType? jobType;
  final int labourSdg;
}

/// A technician's public profile (`technician_profile`).
@immutable
class TechnicianProfile {
  const TechnicianProfile({
    required this.id,
    required this.name,
    required this.rating,
    required this.ratingCount,
    required this.completedJobs,
    required this.yearsExperience,
    required this.mode,
    required this.jobs,
    required this.makeIds,
    required this.reviews,
    this.verified = false,
    this.avatarKey,
    this.bio,
    this.bay,
    this.radiusKm = 0,
  });

  factory TechnicianProfile.fromJson(Json j) {
    final bioAr = j['bio_ar'] as String?;
    return TechnicianProfile(
      id: j['id'] as String,
      name: j['name'] as String? ?? '',
      rating: (j['rating_avg'] as num).toDouble(),
      ratingCount: j['rating_count'] as int? ?? 0,
      completedJobs: j['completed_jobs'] as int? ?? 0,
      yearsExperience: j['years_experience'] as int? ?? 0,
      mode: workModeOf(j['work_mode'] as String),
      jobs: [for (final t in (j['job_types'] as List).cast<Json>()) TechnicianJob.fromJson(t)],
      makeIds: (j['make_ids'] as List).cast<String>().toSet(),
      reviews: [
        for (final r in (j['reviews'] as List).cast<Json>())
          reviewFromJson(r, technicianId: j['id'] as String),
      ],
      verified: j['verified'] as bool? ?? false,
      avatarKey: j['avatar_key'] as String?,
      bio: bioAr == null ? null : LocalizedText(bioAr, j['bio_en'] as String? ?? bioAr),
      bay: j['bay'] == null ? null : Bay.fromJson(j['bay'] as Json),
      radiusKm: j['radius_km'] as int? ?? 0,
    );
  }

  final String id;
  final String name;
  final double rating;
  final int ratingCount;
  final int completedJobs;
  final int yearsExperience;
  final WorkMode mode;
  final List<TechnicianJob> jobs;

  /// Empty: every make.
  final Set<String> makeIds;
  final List<Review> reviews;
  final bool verified;
  final String? avatarKey;
  final LocalizedText? bio;
  final Bay? bay;
  final int radiusKm;
}

/// A `reviews_for` entry (or a technician profile's review).
Review reviewFromJson(Json j, {String? shopId, String? technicianId}) {
  final comment = j['comment'] as String? ?? '';
  return Review(
    id: j['id'] as String,
    author: j['author'] as String? ?? '',
    rating: j['rating'] as int,
    comment: LocalizedText(comment, comment),
    at: DateTime.parse(j['created_at'] as String),
    shopId: shopId,
    technicianId: technicianId,
  );
}

/// One weekly window of the technician's own hours.
@immutable
class AvailabilityRule {
  const AvailabilityRule({
    required this.id,
    required this.weekday,
    required this.startMin,
    required this.endMin,
    this.modes = WorkMode.both,
  });

  factory AvailabilityRule.fromJson(Json j) => AvailabilityRule(
    id: j['id'] as String,
    weekday: j['weekday'] as int,
    startMin: j['start_min'] as int,
    endMin: j['end_min'] as int,
    modes: workModeOf(j['modes'] as String? ?? 'BOTH'),
  );

  final String id;

  /// 0 = Sunday … 6 = Saturday, Khartoum time.
  final int weekday;
  final int startMin;
  final int endMin;
  final WorkMode modes;
}

enum TechnicianStatus { pending, approved, rejected, suspended }

/// The signed-in technician's own record, as the partner app edits it.
@immutable
class MyTechnician {
  const MyTechnician({
    required this.id,
    required this.status,
    required this.mode,
    required this.radiusKm,
    required this.yearsExperience,
    required this.jobs,
    required this.makeIds,
    required this.rules,
    required this.timeOff,
    this.statusReason,
    this.verified = false,
    this.bay,
    this.homeLat,
    this.homeLng,
    this.bio,
    this.avatarKey,
    this.rating = 0,
    this.ratingCount = 0,
    this.completedJobs = 0,
  });

  /// A direct select of `technicians` with its job types, makes, rules, time off and bay.
  factory MyTechnician.fromJson(Json j) {
    final bioAr = j['bio_ar'] as String?;
    return MyTechnician(
      id: j['id'] as String,
      status: TechnicianStatus.values.byName((j['status'] as String).toLowerCase()),
      statusReason: j['status_reason'] as String?,
      mode: workModeOf(j['work_mode'] as String),
      radiusKm: j['radius_km'] as int,
      yearsExperience: j['years_experience'] as int? ?? 0,
      jobs: [
        for (final t in (j['technician_job_types'] as List).cast<Json>()) TechnicianJob.fromJson(t),
      ],
      makeIds: {
        for (final m in (j['technician_makes'] as List).cast<Json>()) m['make_id'] as String,
      },
      rules: [
        for (final r in (j['availability_rules'] as List).cast<Json>())
          AvailabilityRule.fromJson(r),
      ]..sort((a, b) => a.weekday != b.weekday ? a.weekday - b.weekday : a.startMin - b.startMin),
      timeOff: [
        for (final o in (j['time_off'] as List).cast<Json>())
          if (_range(o['period'] as String) case (final from, final to))
            TimeOff(
              id: o['id'] as String,
              from: from,
              to: to,
              reason: LocalizedText(o['reason'] as String? ?? '', o['reason'] as String? ?? ''),
            ),
      ],
      verified: j['verified'] as bool? ?? false,
      bay: j['bay'] == null ? null : Bay.fromJson(j['bay'] as Json),
      homeLat: (j['home_lat'] as num?)?.toDouble(),
      homeLng: (j['home_lng'] as num?)?.toDouble(),
      bio: bioAr == null ? null : LocalizedText(bioAr, j['bio_en'] as String? ?? bioAr),
      avatarKey: j['avatar_key'] as String?,
      rating: (j['rating_avg'] as num?)?.toDouble() ?? 0,
      ratingCount: j['rating_count'] as int? ?? 0,
      completedJobs: j['completed_jobs'] as int? ?? 0,
    );
  }

  final String id;
  final TechnicianStatus status;
  final String? statusReason;
  final WorkMode mode;
  final int radiusKm;
  final int yearsExperience;
  final List<TechnicianJob> jobs;
  final Set<String> makeIds;
  final List<AvailabilityRule> rules;
  final List<TimeOff> timeOff;
  final bool verified;
  final Bay? bay;
  final double? homeLat;
  final double? homeLng;
  final LocalizedText? bio;
  final String? avatarKey;
  final double rating;
  final int ratingCount;
  final int completedJobs;
}

/// A Postgres tstzrange as PostgREST sends it: `["2026-10-14 08:00:00+00","2026-10-14 09:00:00+00")`.
(DateTime, DateTime)? _range(String text) {
  final m = RegExp(r'^[\[(]"?([^",]+)"?,"?([^",]+)"?[\])]$').firstMatch(text);
  if (m == null) return null;
  final from = DateTime.tryParse(m[1]!.replaceFirst(' ', 'T'));
  final to = DateTime.tryParse(m[2]!.replaceFirst(' ', 'T'));
  return from == null || to == null ? null : (from, to);
}

// ------------------------------------------------------------------ disputes

enum DisputeCategory { notReceived, wrongPart, damaged, notFitted, payment, behaviour, other }

enum DisputeStatus { open, inReview, resolved, rejected }

@immutable
class DisputeMessage {
  const DisputeMessage({
    required this.id,
    required this.body,
    required this.fromAdmin,
    required this.mine,
    required this.at,
    this.sender,
  });

  factory DisputeMessage.fromJson(Json j) => DisputeMessage(
    id: j['id'] as String,
    body: j['body'] as String,
    fromAdmin: j['from_admin'] as bool? ?? false,
    mine: j['mine'] as bool? ?? false,
    at: DateTime.parse(j['at'] as String),
    sender: j['sender'] as String?,
  );

  final String id;
  final String body;
  final bool fromAdmin;
  final bool mine;
  final DateTime at;
  final String? sender;
}

/// A complaint about an order or a fitting (`dispute_json`).
@immutable
class Dispute {
  const Dispute({
    required this.id,
    required this.category,
    required this.description,
    required this.status,
    required this.createdAt,
    required this.messages,
    this.ref,
    this.subOrderId,
    this.bookingId,
    this.resolution,
    this.openerName,
  });

  factory Dispute.fromJson(Json j) => Dispute(
    id: j['id'] as String,
    category: DisputeCategory.values.byName(_camel(j['category'] as String)),
    description: j['description'] as String,
    status: DisputeStatus.values.byName(_camel(j['status'] as String)),
    createdAt: DateTime.parse(j['created_at'] as String),
    messages: [for (final m in (j['messages'] as List).cast<Json>()) DisputeMessage.fromJson(m)],
    ref: j['ref'] as String?,
    subOrderId: j['sub_order_id'] as String?,
    bookingId: j['booking_id'] as String?,
    resolution: j['resolution'] as String?,
    openerName: j['opener_name'] as String?,
  );

  final String id;
  final DisputeCategory category;
  final String description;
  final DisputeStatus status;
  final DateTime createdAt;
  final List<DisputeMessage> messages;
  final String? ref;
  final String? subOrderId;
  final String? bookingId;
  final String? resolution;

  /// Who opened it (a shop or technician sees complaints a buyer opened about them).
  final String? openerName;

  bool get closed => status == DisputeStatus.resolved || status == DisputeStatus.rejected;
}

String _camel(String code) =>
    code.toLowerCase().replaceAllMapped(RegExp('_([a-z])'), (m) => m[1]!.toUpperCase());

String disputeCategoryCode(DisputeCategory c) =>
    c.name.replaceAllMapped(RegExp('[A-Z]'), (m) => '_${m[0]}').toUpperCase();
