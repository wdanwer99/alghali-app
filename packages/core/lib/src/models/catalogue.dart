import 'dart:ui' show Locale;

import 'package:flutter/foundation.dart' show immutable;

/// A JSON object from the backend (PostgREST row or RPC result).
typedef Json = Map<String, dynamic>;

/// Bilingual text from the catalogue: Arabic is required, English second.
@immutable
class LocalizedText {
  const LocalizedText(this.ar, this.en);

  /// Reads `{prefix}_ar` and `{prefix}_en`; an empty English text falls back to Arabic.
  factory LocalizedText.fromJson(Json j, String prefix) {
    final ar = j['${prefix}_ar'] as String? ?? '';
    final en = j['${prefix}_en'] as String? ?? '';
    return LocalizedText(ar, en.isEmpty ? ar : en);
  }

  final String ar;
  final String en;

  String of(Locale locale) => locale.languageCode == 'ar' ? ar : en;
}

// ---------------------------------------------------------------- vehicles --

@immutable
class VehicleMake {
  const VehicleMake({required this.id, required this.name});

  factory VehicleMake.fromJson(Json j) =>
      VehicleMake(id: j['id'] as String, name: LocalizedText.fromJson(j, 'name'));

  final String id;
  final LocalizedText name;
}

@immutable
class VehicleModel {
  const VehicleModel({required this.id, required this.makeId, required this.name});

  factory VehicleModel.fromJson(Json j) => VehicleModel(
    id: j['id'] as String,
    makeId: j['make_id'] as String,
    name: LocalizedText.fromJson(j, 'name'),
  );

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

  factory VehicleVariant.fromJson(Json j) => VehicleVariant(
    id: j['id'] as String,
    modelId: j['model_id'] as String,
    yearFrom: j['year_from'] as int,
    yearTo: j['year_to'] as int,
    engine: LocalizedText.fromJson(j, 'engine'),
  );

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
  const GarageVehicle({
    required this.id,
    required this.variantId,
    this.nickname,
    this.vin,
    this.plate,
    this.isDefault = false,
  });

  factory GarageVehicle.fromJson(Json j) => GarageVehicle(
    id: j['id'] as String,
    variantId: j['variant_id'] as String,
    nickname: j['nickname'] as String?,
    vin: j['vin'] as String?,
    plate: j['plate'] as String?,
    isDefault: j['is_default'] as bool? ?? false,
  );

  final String id;
  final String variantId;
  final String? nickname;
  final String? vin;
  final String? plate;
  final bool isDefault;
}

// --------------------------------------------------------------- catalogue --

/// Kinds of installation job; each technician sets a labour price per type.
/// [code] is the `job_types.code` in the database.
enum JobType {
  lighting('LIGHTING'),
  brakes('BRAKES'),
  service('SERVICE'),
  battery('BATTERY'),
  electrical('ELECTRICAL'),
  ac('AC'),
  suspension('SUSPENSION'),
  tyres('TYRES'),
  mechanical('MECHANICAL');

  const JobType(this.code);

  final String code;

  /// Null for codes this app version doesn't know (admins can add job types).
  static JobType? fromCode(String? code) => _byCode[code];
  static final _byCode = {for (final j in values) j.code: j};
}

/// Which icon a category shows (mapped to an [IconData] in the UI layer).
/// The names match `part_categories.icon` in the database.
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
  transmission,
  body,
  accessories;

  static CategoryIcon fromName(String? name) => values.asNameMap()[name] ?? accessories;
}

@immutable
class PartCategory {
  const PartCategory({
    required this.id,
    required this.name,
    required this.icon,
    this.jobType,
    this.standardMinutes,
    this.parentId,
  });

  /// [jobTypes] maps `job_types.id` to the app's [JobType] (from the catalogue snapshot).
  factory PartCategory.fromJson(Json j, Map<String, JobType> jobTypes) => PartCategory(
    id: j['id'] as String,
    name: LocalizedText.fromJson(j, 'name'),
    icon: CategoryIcon.fromName(j['icon'] as String?),
    jobType: jobTypes[j['job_type_id']],
    standardMinutes: j['std_job_minutes'] as int?,
    parentId: j['parent_id'] as String?,
  );

  final String id;
  final String? parentId;
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
    this.verified = true,
    this.fitmentModelIds = const <String>{},
  });

  /// A part from `search_parts` (row) or `part_detail` (its `part` object). The server
  /// decides fit, so [fitment] stays null; [fitmentModelIds] lists the models it fits.
  factory Part.fromJson(Json j) {
    final desc = LocalizedText.fromJson(j, 'desc');
    return Part(
      id: (j['part_id'] ?? j['id']) as String,
      categoryId: j['category_id'] as String,
      name: LocalizedText.fromJson(j, 'name'),
      description: desc.ar.isEmpty ? null : desc,
      oemNumbers: [...?(j['oem_numbers'] as List?)?.cast<String>()],
      installable: j['installable'] as bool? ?? true,
      standardMinutes: j['std_job_minutes'] as int?,
      verified: j['is_verified'] as bool? ?? true,
      fitmentModelIds: {...?(j['fitment_model_ids'] as List?)?.cast<String>()},
    );
  }

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

  /// False for a part a shop typed in that an admin hasn't checked yet (D-067).
  final bool verified;

  /// Models the part is known to fit (from `part_detail`); empty when unknown.
  final Set<String> fitmentModelIds;
}

/// Whether a part fits the buyer's selected car.
enum Fit {
  fits('FITS'),
  check('CHECK_FITMENT'),
  noFit('NO_FIT');

  const Fit(this.code);

  final String code;

  /// Null when no car was selected.
  static Fit? fromCode(String? code) => _byCode[code];
  static final _byCode = {for (final f in values) f.code: f};
}

// ------------------------------------------------------------ street, shops --

enum StreetSide {
  a('A'),
  b('B');

  const StreetSide(this.code);

  final String code;

  static StreetSide fromCode(String? code) => code == 'B' ? b : a;
}

/// Weekly opening windows in Khartoum time: weekday (0 = Sunday … 6 = Saturday) →
/// `(startMinute, endMinute)` pairs. A missing weekday means closed.
typedef OpeningHours = Map<int, List<(int, int)>>;

Json openingHoursToJson(OpeningHours hours) => {
  for (final MapEntry(:key, :value) in hours.entries)
    '$key': [
      for (final (from, to) in value) [from, to],
    ],
};

OpeningHours openingHoursFromJson(Object? json) => {
  if (json is Map)
    for (final MapEntry(:key, :value) in json.entries)
      int.parse(key as String): [
        for (final w in (value as List).cast<List<dynamic>>()) (w[0] as int, w[1] as int),
      ],
};

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

  factory Zone.fromJson(Json j) => Zone(
    id: j['id'] as String,
    seq: j['seq'] as int,
    name: LocalizedText.fromJson(j, 'name'),
    fromM: j['from_m'] as int,
    toM: j['to_m'] as int,
  );

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
    this.openingHours = const <int, List<(int, int)>>{},
    this.phone,
    this.whatsapp,
    this.storefrontKey,
    this.lat,
    this.lng,
    this.closedUntil,
  });

  /// From `shop_json()` (catalogue snapshot, shop RPCs). [hours] is left empty: the UI
  /// words [openingHours] in the reader's language.
  factory Shop.fromJson(Json j) => Shop(
    id: j['id'] as String,
    zoneId: j['zone_id'] as String,
    name: LocalizedText.fromJson(j, 'name'),
    plotNo: j['plot_no'] as String? ?? '',
    side: StreetSide.fromCode(j['side'] as String?),
    landmark: LocalizedText.fromJson(j, 'landmark'),
    posM: j['pos_m'] as int? ?? 0,
    rating: (j['rating_avg'] as num?)?.toDouble() ?? 0,
    ratingCount: j['rating_count'] as int? ?? 0,
    hours: const LocalizedText('', ''),
    about: LocalizedText.fromJson(j, 'about'),
    verified: j['verified'] as bool? ?? false,
    specialityIds: [...?(j['category_ids'] as List?)?.cast<String>()],
    makeIds: [...?(j['make_ids'] as List?)?.cast<String>()],
    openNow: j['open_now'] as bool? ?? false,
    memberSince: DateTime.tryParse(j['approved_at'] as String? ?? '')?.year ?? DateTime.now().year,
    openingHours: openingHoursFromJson(j['opening_hours']),
    phone: j['phone'] as String?,
    whatsapp: j['whatsapp'] as String?,
    storefrontKey: j['storefront_key'] as String?,
    lat: (j['lat'] as num?)?.toDouble(),
    lng: (j['lng'] as num?)?.toDouble(),
    closedUntil: DateTime.tryParse(j['closed_until'] as String? ?? ''),
  );

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
  final OpeningHours openingHours;
  final String? phone;
  final String? whatsapp;
  final String? storefrontKey;

  /// The shop's map pin; delivery is measured from here (D-087), else from the street's
  /// starting point.
  final double? lat;
  final double? lng;

  /// "Closed today": the shop closed itself until then (D-119).
  final DateTime? closedUntil;
}

enum ListingCondition {
  newOem('NEW_OEM'),
  newAftermarket('NEW_AFTERMARKET'),
  used('USED');

  const ListingCondition(this.code);

  final String code;

  static ListingCondition fromCode(String code) => _byCode[code]!;
  static final _byCode = {for (final c in values) c.code: c};
}

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
    this.priceOnRequest = false,
    this.imageKey,
  });

  /// An offer inside a `search_parts` row. [stockQty] is what's available to buy
  /// (stock minus what open orders reserved); a "price on request" offer has price 0.
  factory Listing.fromJson(Json j, {required String partId}) => Listing(
    id: j['id'] as String,
    shopId: j['shop_id'] as String,
    partId: partId,
    condition: ListingCondition.fromCode(j['condition'] as String),
    priceSdg: j['price_sdg'] as int? ?? 0,
    stockQty: j['available_qty'] as int? ?? 0,
    warrantyDays: j['warranty_days'] as int? ?? 0,
    wasSdg: j['was_sdg'] as int?,
    brand: j['brand'] as String?,
    priceOnRequest: j['price_on_request'] as bool? ?? false,
    imageKey: j['image_key'] as String?,
  );

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
  final bool priceOnRequest;

  /// Storage prefix of the first photo in `media-public` ({key}/thumb.webp …).
  final String? imageKey;

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
    this.lat,
    this.lng,
    this.isDefault = false,
  });

  /// A row of `addresses`. [distanceKm] is measured by the caller from the street's
  /// starting point (0 when it isn't set yet).
  factory Address.fromJson(Json j, {double distanceKm = 0}) {
    final label = j['label'] as String? ?? '';
    final description = j['description_ar'] as String? ?? '';
    return Address(
      id: j['id'] as String,
      label: LocalizedText(label, label),
      description: LocalizedText(description, description),
      distanceKm: distanceKm,
      lat: (j['lat'] as num?)?.toDouble(),
      lng: (j['lng'] as num?)?.toDouble(),
      isDefault: j['is_default'] as bool? ?? false,
    );
  }

  final String id;
  final LocalizedText label;
  final LocalizedText description;

  /// Distance from the street's origin, used for travel and delivery fee bands.
  final double distanceKm;
  final double? lat;
  final double? lng;
  final bool isDefault;
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
