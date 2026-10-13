import 'package:flutter/foundation.dart' show immutable;

import 'catalogue.dart';
import 'commerce.dart';

// ------------------------------------------------------------- shop orders --

/// One sub-order as the shop sees it (`shop_sub_order_json`): the order reference, the
/// buyer's name and phone to call, how the buyer pays, and where to deliver.
@immutable
class ShopSubOrder {
  const ShopSubOrder({
    required this.subOrder,
    required this.ref,
    required this.method,
    required this.placedAt,
    required this.buyerName,
    this.buyerPhone,
    this.paymentStatus,
    this.address,
    this.commissionSdg = 0,
  });

  factory ShopSubOrder.fromJson(Json j) {
    final buyer = j['buyer'] as Json? ?? const {};
    final address = j['address'] as Json?;
    return ShopSubOrder(
      subOrder: SubOrder.fromJson(j),
      ref: j['ref'] as String,
      method: PaymentMethod.fromCode(j['payment_method'] as String),
      placedAt: DateTime.parse(j['placed_at'] as String),
      buyerName: buyer['name'] as String? ?? '',
      buyerPhone: buyer['phone'] as String?,
      paymentStatus: j['payment_status'] == null
          ? null
          : PaymentStatus.fromCode(j['payment_status'] as String),
      address: address == null
          ? null
          : DeliveryAddress(
              label: address['label'] as String? ?? '',
              directions: address['description_ar'] as String?,
              lat: (address['lat'] as num?)?.toDouble(),
              lng: (address['lng'] as num?)?.toDouble(),
            ),
      commissionSdg: j['commission_sdg'] as int? ?? 0,
    );
  }

  final SubOrder subOrder;
  final String ref;
  final PaymentMethod method;
  final DateTime placedAt;
  final String buyerName;
  final String? buyerPhone;

  /// Cash: due or collected by this shop. Bankak: the order's transfer.
  final PaymentStatus? paymentStatus;
  final DeliveryAddress? address;
  final int commissionSdg;
}

/// An open photo request as a shop sees it (`shop_open_requests`): the buyer's first
/// name, this shop's latest offer and how many live offers it has.
@immutable
class OpenRequest {
  const OpenRequest({required this.request, required this.offerCount, this.myOffer});

  factory OpenRequest.fromJson(Json j) {
    final mine = j['my_offer'] as Json?;
    return OpenRequest(
      request: PartRequest.fromJson(j),
      offerCount: j['offer_count'] as int? ?? 0,
      myOffer: mine == null ? null : PartOffer.fromJson(mine),
    );
  }

  final PartRequest request;
  final int offerCount;
  final PartOffer? myOffer;
}

/// What a shop offers on a photo request.
@immutable
class OfferDraft {
  const OfferDraft({
    required this.title,
    required this.condition,
    required this.priceSdg,
    this.warrantyDays = 0,
    this.note,
    this.partId,
    this.imageKey,
    this.validHours = 48,
  });

  final String title;
  final ListingCondition condition;
  final int priceSdg;
  final int warrantyDays;
  final String? note;
  final String? partId;

  /// A photo already uploaded under shops/{shop id}/… in the public media bucket.
  final String? imageKey;

  /// 1–168 hours; 48 by default.
  final int validHours;
}

@immutable
class DeliveryAddress {
  const DeliveryAddress({required this.label, this.directions, this.lat, this.lng});

  final String label;
  final String? directions;
  final double? lat;
  final double? lng;
}

/// A shop's statement (`shop_statement`). Amounts: positive = the platform owes the shop.
@immutable
class ShopStatement {
  const ShopStatement({
    required this.from,
    required this.to,
    required this.openingSdg,
    required this.closingSdg,
    required this.lines,
    required this.payouts,
  });

  factory ShopStatement.fromJson(Json j) => ShopStatement(
    from: DateTime.parse(j['from'] as String),
    to: DateTime.parse(j['to'] as String),
    openingSdg: j['opening_sdg'] as int,
    closingSdg: j['closing_sdg'] as int,
    lines: [for (final l in (j['lines'] as List).cast<Json>()) ?LedgerLine.fromJson(l)],
    payouts: [for (final p in (j['payouts'] as List).cast<Json>()) Payout.fromJson(p)],
  );

  final DateTime from;
  final DateTime to;
  final int openingSdg;
  final int closingSdg;
  final List<LedgerLine> lines;
  final List<Payout> payouts;
}

// ------------------------------------------------------------- shop stock --

/// One of the shop's own listings, as the stock screens see it (`listing_json()`).
@immutable
class ShopListing {
  const ShopListing({
    required this.id,
    required this.version,
    required this.partId,
    required this.partName,
    required this.categoryId,
    required this.condition,
    required this.priceSdg,
    required this.priceOnRequest,
    required this.stockQty,
    required this.availableQty,
    required this.warrantyDays,
    required this.active,
    required this.ownPart,
    required this.modelIds,
    required this.images,
    this.sku,
    this.brand,
    this.note,
    this.wasSdg,
  });

  factory ShopListing.fromJson(Json j) {
    final part = j['part'] as Json;
    return ShopListing(
      id: j['id'] as String,
      version: j['version'] as int,
      partId: part['id'] as String,
      partName: LocalizedText.fromJson(part, 'name'),
      categoryId: part['category_id'] as String,
      condition: ListingCondition.fromCode(j['condition'] as String),
      priceSdg: j['price_sdg'] as int?,
      priceOnRequest: j['price_on_request'] as bool? ?? false,
      stockQty: j['stock_qty'] as int,
      availableQty: j['available_qty'] as int,
      warrantyDays: j['warranty_days'] as int? ?? 0,
      active: j['is_active'] as bool? ?? true,
      ownPart: part['own'] as bool? ?? false,
      modelIds: {...(part['model_ids'] as List).cast<String>()},
      images: [...(j['images'] as List).cast<String>()],
      sku: j['sku'] as String?,
      brand: j['brand'] as String?,
      note: j['note_ar'] as String?,
      wasSdg: j['was_sdg'] as int?,
    );
  }

  final String id;

  /// Send back with the next edit; a newer version on the server means someone else
  /// (or another phone) changed it first.
  final int version;
  final String partId;
  final LocalizedText partName;
  final String categoryId;
  final ListingCondition condition;
  final int? priceSdg;
  final bool priceOnRequest;
  final int stockQty;

  /// Stock minus what open orders have reserved.
  final int availableQty;
  final int warrantyDays;
  final bool active;

  /// The shop typed this part in and may still edit its name and cars (D-067).
  final bool ownPart;
  final Set<String> modelIds;
  final List<String> images;
  final String? sku;
  final String? brand;
  final String? note;
  final int? wasSdg;
}

/// A part the shop types in during quick listing. Empty [modelIds] = "not sure which cars".
@immutable
class NewPart {
  const NewPart({
    required this.nameAr,
    required this.categoryId,
    this.nameEn,
    this.modelIds = const [],
  });

  final String nameAr;
  final String? nameEn;
  final String categoryId;
  final List<String> modelIds;

  Json toJson() => {
    'name_ar': nameAr,
    if (nameEn != null) 'name_en': nameEn,
    'category_id': categoryId,
    'model_ids': modelIds,
  };
}

/// What the quick-listing and edit screens send to `shop_upsert_listing`.
/// Give either [partId] (a catalogue part) or [newPart]; editing needs [listingId] and
/// the [version] last seen.
@immutable
class ListingDraft {
  const ListingDraft({
    required this.condition,
    required this.stockQty,
    this.priceSdg,
    this.priceOnRequest = false,
    this.warrantyDays = 0,
    this.brand,
    this.sku,
    this.note,
    this.active = true,
    this.partId,
    this.newPart,
    this.listingId,
    this.version,
  });

  final ListingCondition condition;
  final int stockQty;
  final int? priceSdg;
  final bool priceOnRequest;
  final int warrantyDays;
  final String? brand;
  final String? sku;
  final String? note;
  final bool active;
  final String? partId;
  final NewPart? newPart;
  final String? listingId;
  final int? version;

  Json toParams(String shopId) => {
    'p_shop_id': shopId,
    'p_condition': condition.code,
    'p_stock_qty': stockQty,
    'p_price_sdg': priceSdg,
    'p_price_on_request': priceOnRequest,
    'p_warranty_days': warrantyDays,
    'p_brand': brand,
    'p_sku': sku,
    'p_note_ar': note,
    'p_is_active': active,
    'p_part_id': partId,
    'p_new_part': newPart?.toJson(),
    'p_listing_id': listingId,
    'p_version': version,
  };
}

/// One line of a bulk price/stock edit. Fields left null stay as they are.
@immutable
class BulkEdit {
  const BulkEdit({
    required this.listingId,
    required this.version,
    this.priceSdg,
    this.stockQty,
    this.active,
  });

  final String listingId;
  final int version;
  final int? priceSdg;
  final int? stockQty;
  final bool? active;

  Json toJson() => {
    'listing_id': listingId,
    'version': version,
    'price_sdg': ?priceSdg,
    'stock_qty': ?stockQty,
    'is_active': ?active,
  };
}

@immutable
class BulkResult {
  const BulkResult({
    required this.listingId,
    required this.ok,
    this.error,
    this.version,
    this.current,
  });

  factory BulkResult.fromJson(Json j) => BulkResult(
    listingId: j['listing_id'] as String,
    ok: j['ok'] as bool,
    error: j['error'] as String?,
    version: j['version'] as int?,
    current: j['current'] as Json?,
  );

  final String listingId;
  final bool ok;

  /// VERSION_CONFLICT, LISTING_NOT_FOUND, PRICE_REQUIRED, INVALID_QTY, STOCK_BELOW_RESERVED…
  final String? error;
  final int? version;

  /// On VERSION_CONFLICT: the server's price_sdg, stock_qty and is_active.
  final Json? current;
}

/// A problem with one row of an imported sheet. [row] is the Excel row number.
@immutable
class ImportIssue {
  const ImportIssue({required this.row, required this.code, this.column, this.value});

  factory ImportIssue.fromJson(Json j) => ImportIssue(
    row: j['row'] as int,
    code: j['code'] as String,
    column: j['column'] as String?,
    value: j['value'] as String?,
  );

  final int row;
  final String code;
  final String? column;
  final String? value;
}

/// What the `inventory-import` Edge Function reports back.
@immutable
class ImportReport {
  const ImportReport({
    required this.total,
    required this.created,
    required this.updated,
    required this.failed,
    required this.dryRun,
    required this.errors,
    required this.warnings,
    this.jobId,
  });

  factory ImportReport.fromJson(Json j) => ImportReport(
    total: j['total'] as int,
    created: j['created'] as int,
    updated: j['updated'] as int,
    failed: j['failed'] as int,
    dryRun: j['dry_run'] as bool? ?? false,
    errors: [for (final e in (j['errors'] as List).cast<Json>()) ImportIssue.fromJson(e)],
    warnings: [for (final w in (j['warnings'] as List).cast<Json>()) ImportIssue.fromJson(w)],
    jobId: j['job_id'] as String?,
  );

  final int total;
  final int created;
  final int updated;
  final int failed;
  final bool dryRun;
  final List<ImportIssue> errors;
  final List<ImportIssue> warnings;
  final String? jobId;
}

/// A shop owner's application (`apply_as_shop`); an admin approves it.
@immutable
class ShopApplication {
  const ShopApplication({
    required this.nameAr,
    required this.zoneId,
    required this.phone,
    this.nameEn = '',
    this.plotNo,
    this.side,
    this.landmarkAr,
    this.whatsapp,
    this.lat,
    this.lng,
    this.aboutAr,
    this.openingHours = const <int, List<(int, int)>>{},
    this.categoryIds = const [],
    this.makeIds = const [],
  });

  final String nameAr;
  final String nameEn;
  final String zoneId;
  final String phone;
  final String? plotNo;
  final StreetSide? side;
  final String? landmarkAr;
  final String? whatsapp;
  final double? lat;
  final double? lng;
  final String? aboutAr;
  final OpeningHours openingHours;
  final List<String> categoryIds;
  final List<String> makeIds;

  Json toParams() => {
    'p_name_ar': nameAr,
    'p_name_en': nameEn,
    'p_zone_id': zoneId,
    'p_phone': phone,
    'p_plot_no': plotNo,
    'p_side': side?.code,
    'p_landmark_ar': landmarkAr,
    'p_whatsapp': whatsapp,
    'p_lat': lat,
    'p_lng': lng,
    'p_about_ar': aboutAr,
    'p_opening_hours': openingHoursToJson(openingHours),
    'p_category_ids': categoryIds,
    'p_make_ids': makeIds,
  };
}

/// A line on a shop's or technician's statement. Positive = the platform owes
/// the partner; negative = the partner owes the platform (e.g. cash commission).
@immutable
class LedgerLine {
  const LedgerLine({
    required this.id,
    required this.kind,
    required this.amountSdg,
    required this.at,
    this.ref,
  });

  /// A `shop_statement` line. Reversals show under their kind with the opposite sign
  /// (a reversed sale reads as a refund). Null for kinds this app version doesn't know.
  static LedgerLine? fromJson(Json j) {
    final kind = switch (j['kind']) {
      'SALE' => LedgerKind.sale,
      'SALE_REVERSAL' || 'CASH_RETURNED' || 'REFUND' => LedgerKind.refund,
      'COMMISSION' || 'COMMISSION_REVERSAL' => LedgerKind.commission,
      'CASH_COLLECTED' => LedgerKind.cashCollected,
      'CASH_HANDOVER' => LedgerKind.cashHandover,
      'PAYOUT' => LedgerKind.payout,
      'LABOUR' => LedgerKind.labour,
      'TRAVEL_FEE' => LedgerKind.travelFee,
      'BOOKING_FEE' => LedgerKind.bookingFee,
      _ => null,
    };
    if (kind == null) return null;
    return LedgerLine(
      id: j['id'] as String,
      kind: kind,
      amountSdg: j['amount_sdg'] as int,
      at: DateTime.parse(j['at'] as String),
      ref: j['ref'] as String?,
    );
  }

  final String id;
  final LedgerKind kind;
  final int amountSdg;
  final DateTime at;
  final String? ref;
}

enum LedgerKind {
  sale,
  commission,
  labour,
  travelFee,
  bookingFee,
  cashCollected,
  cashHandover,
  payout,
  refund,
}

enum PayoutStatus { draft, approved, paid }

@immutable
class Payout {
  const Payout({
    required this.id,
    required this.from,
    required this.to,
    required this.amountSdg,
    required this.status,
    this.paidAt,
  });

  /// A payout listed in `shop_statement` (its period isn't included there: from = to = created).
  factory Payout.fromJson(Json j) {
    final created = DateTime.parse(j['created_at'] as String);
    return Payout(
      id: j['id'] as String,
      from: created,
      to: created,
      amountSdg: j['amount_sdg'] as int,
      status: PayoutStatus.values.byName((j['status'] as String).toLowerCase()),
      paidAt: DateTime.tryParse(j['paid_at'] as String? ?? ''),
    );
  }

  final String id;
  final DateTime from;
  final DateTime to;
  final int amountSdg;
  final PayoutStatus status;
  final DateTime? paidAt;
}

enum StaffRole { owner, staff }

@immutable
class StaffMember {
  const StaffMember({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.lastActive,
  });

  final String id;
  final String name;
  final String email;
  final StaffRole role;
  final DateTime lastActive;
}

/// A weekly working window in Khartoum wall-clock time (PLAN §3.8).
@immutable
class AvailabilityWindow {
  const AvailabilityWindow({required this.startMin, required this.endMin});

  /// Minutes after midnight.
  final int startMin;
  final int endMin;
}

@immutable
class TimeOff {
  const TimeOff({required this.id, required this.from, required this.to, required this.reason});

  final String id;
  final DateTime from;
  final DateTime to;
  final LocalizedText reason;
}

/// Sales per day for the last 7 days, oldest first, for the shop's insights.
@immutable
class SalesDay {
  const SalesDay(this.day, this.sdg, this.orders);

  final DateTime day;
  final int sdg;
  final int orders;
}
