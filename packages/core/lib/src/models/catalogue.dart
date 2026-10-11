import 'dart:ui' show Locale;

import 'package:flutter/foundation.dart' show immutable;

/// Bilingual text from the catalogue: Arabic is required, English second.
@immutable
class LocalizedText {
  const LocalizedText(this.ar, this.en);

  final String ar;
  final String en;

  String of(Locale locale) => locale.languageCode == 'ar' ? ar : en;
}

// ---------------------------------------------------------------- vehicles --

@immutable
class VehicleMake {
  const VehicleMake({required this.id, required this.name});

  final String id;
  final LocalizedText name;
}

@immutable
class VehicleModel {
  const VehicleModel({required this.id, required this.makeId, required this.name});

  final String id;
  final String makeId;
  final LocalizedText name;
}

@immutable
class VehicleVariant {
  const VehicleVariant({
    required this.id,
    required this.modelId,
    required this.yearFrom,
    required this.yearTo,
    required this.engine,
  });

  final String id;
  final String modelId;
  final int yearFrom;
  final int yearTo;
  final LocalizedText engine;

  /// "2016–2025", isolated left-to-right so Arabic text doesn't flip the range.
  String get years =>
      '${String.fromCharCode(0x2066)}$yearFrom–$yearTo${String.fromCharCode(0x2069)}';
}

/// A car the buyer saved in My Garage.
@immutable
class GarageVehicle {
  const GarageVehicle({required this.id, required this.variantId, this.nickname});

  final String id;
  final String variantId;
  final String? nickname;
}

// --------------------------------------------------------------- catalogue --

/// Kinds of installation job; each technician sets a labour price per type.
enum JobType { lighting, brakes, service, battery, electrical, ac, suspension, tyres }

/// Which icon a category shows (mapped to an [IconData] in the UI layer).
enum CategoryIcon {
  lighting,
  brakes,
  oil,
  battery,
  electrical,
  ac,
  suspension,
  tyres,
  engine,
  accessories,
}

@immutable
class PartCategory {
  const PartCategory({
    required this.id,
    required this.name,
    required this.icon,
    this.jobType,
    this.standardMinutes,
  });

  final String id;
  final LocalizedText name;
  final CategoryIcon icon;

  /// Null when parts in this category are not fitted by technicians.
  final JobType? jobType;
  final int? standardMinutes;
}

@immutable
class Part {
  const Part({
    required this.id,
    required this.categoryId,
    required this.name,
    this.description,
    this.oemNumbers = const [],
    this.installable = true,
    this.standardMinutes,
    this.fitment,
    this.keywords = const [],
  });

  final String id;
  final String categoryId;
  final LocalizedText name;
  final LocalizedText? description;
  final List<String> oemNumbers;
  final bool installable;

  /// Overrides the category's standard job duration.
  final int? standardMinutes;

  /// Variant ids this part is known to fit. Null means no fitment data yet,
  /// so the buyer is asked to check with the shop.
  final Set<String>? fitment;

  /// Extra search words (colloquial names, spellings) beyond the names.
  final List<String> keywords;
}

/// Whether a part fits the buyer's selected car.
enum Fit { fits, check, noFit }

// ------------------------------------------------------------ street, shops --

enum StreetSide { a, b }

/// A stretch of Alghali Street, measured in metres from the north entrance.
@immutable
class Zone {
  const Zone({
    required this.id,
    required this.seq,
    required this.name,
    required this.fromM,
    required this.toM,
  });

  final String id;
  final int seq;
  final LocalizedText name;
  final int fromM;
  final int toM;
}

@immutable
class Shop {
  const Shop({
    required this.id,
    required this.zoneId,
    required this.name,
    required this.plotNo,
    required this.side,
    required this.landmark,
    required this.posM,
    required this.rating,
    required this.ratingCount,
    required this.hours,
    required this.about,
    this.verified = false,
    this.specialityIds = const [],
    this.makeIds = const [],
    this.openNow = true,
    this.memberSince = 2026,
  });

  final String id;
  final String zoneId;
  final LocalizedText name;
  final String plotNo;
  final StreetSide side;
  final LocalizedText landmark;

  /// Position along the street, used to order pickup stops and draw the strip.
  final int posM;
  final double rating;
  final int ratingCount;
  final LocalizedText hours;
  final LocalizedText about;
  final bool verified;
  final List<String> specialityIds;
  final List<String> makeIds;
  final bool openNow;
  final int memberSince;
}

enum ListingCondition { newOem, newAftermarket, used }

/// One shop's offer of one part.
@immutable
class Listing {
  const Listing({
    required this.id,
    required this.shopId,
    required this.partId,
    required this.condition,
    required this.priceSdg,
    required this.stockQty,
    this.warrantyDays = 0,
    this.wasSdg,
    this.brand,
  });

  final String id;
  final String shopId;
  final String partId;
  final ListingCondition condition;
  final int priceSdg;
  final int stockQty;
  final int warrantyDays;

  /// Previous price when the shop has lowered it (shown as a deal).
  final int? wasSdg;
  final String? brand;

  bool get inStock => stockQty > 0;

  int? get discountPercent =>
      wasSdg == null || wasSdg! <= priceSdg ? null : ((wasSdg! - priceSdg) * 100 / wasSdg!).round();
}

// ------------------------------------------------------------- technicians --

enum WorkMode { bay, mobile, both }

@immutable
class Technician {
  const Technician({
    required this.id,
    required this.name,
    required this.rating,
    required this.ratingCount,
    required this.completedJobs,
    required this.mode,
    required this.labourSdg,
    required this.distanceKm,
    required this.bio,
    required this.yearsExperience,
    this.bayShopId,
    this.makeIds = const {},
    this.verified = true,
    this.radiusKm = 10,
  });

  final String id;
  final LocalizedText name;
  final double rating;
  final int ratingCount;
  final int completedJobs;
  final WorkMode mode;

  /// Labour price per job type, set by the technician (D-010).
  final Map<JobType, int> labourSdg;

  /// Straight-line distance from the buyer (demo: fixed per technician).
  final double distanceKm;
  final LocalizedText bio;
  final int yearsExperience;

  /// The workshop bay on the street where they work, if any.
  final String? bayShopId;

  /// Makes they work on; empty means all makes.
  final Set<String> makeIds;
  final bool verified;
  final int radiusKm;

  bool get worksAtBay => mode != WorkMode.mobile;
  bool get comesToYou => mode != WorkMode.bay;
}

@immutable
class Address {
  const Address({
    required this.id,
    required this.label,
    required this.description,
    required this.distanceKm,
  });

  final String id;
  final LocalizedText label;
  final LocalizedText description;

  /// Distance from the street's origin, used for travel and delivery fee bands.
  final double distanceKm;
}

@immutable
class Review {
  const Review({
    required this.id,
    required this.author,
    required this.rating,
    required this.comment,
    required this.at,
    this.shopId,
    this.technicianId,
  });

  final String id;
  final String author;
  final int rating;
  final LocalizedText comment;
  final DateTime at;
  final String? shopId;
  final String? technicianId;
}
