import 'package:flutter/foundation.dart' show immutable;

import 'catalogue.dart';

/// "PENDING_PAYMENT" ↔ "pendingPayment": database codes and Dart enum names.
String screamingCase(String camel) =>
    camel.replaceAllMapped(RegExp('[A-Z]'), (m) => '_${m[0]}').toUpperCase();
String camelCase(String screaming) =>
    screaming.toLowerCase().replaceAllMapped(RegExp('_([a-z])'), (m) => m[1]!.toUpperCase());

/// Status changes as shown on tracking timelines.
@immutable
class StatusEvent<S extends Enum> {
  const StatusEvent(this.status, this.at);

  final S status;
  final DateTime at;
}

// ------------------------------------------------------------------ orders --

enum SubOrderStatus {
  pendingPayment,
  paymentReview,
  confirmed,
  ready,
  pickedUp,
  outForDelivery,
  delivered,
  handedToTechnician,
  completed,
  cancelled,
  rejectedByShop,
  returnRequested,
  returned;

  String get code => screamingCase(name);
  static SubOrderStatus fromCode(String code) => values.byName(camelCase(code));
}

enum FulfilmentType {
  pickup,
  delivery,
  toTechnician;

  String get code => screamingCase(name);
  static FulfilmentType fromCode(String code) => values.byName(camelCase(code));
}

enum PaymentMethod {
  bankak,
  cash;

  String get code => screamingCase(name);
  static PaymentMethod fromCode(String code) => values.byName(camelCase(code));
}

enum PaymentStatus {
  awaitingTransfer,
  receiptSubmitted,
  confirmed,
  rejected,
  due,
  collected,
  expired,
  cancelled;

  String get code => screamingCase(name);
  static PaymentStatus fromCode(String code) => values.byName(camelCase(code));
}

/// A refund the platform owes the buyer for one sub-order (shop declined, cancelled
/// after payment, or an approved return).
@immutable
class Refund {
  const Refund({required this.id, required this.amountSdg, required this.sent, this.subOrderId});

  factory Refund.fromJson(Json j) => Refund(
    id: j['id'] as String,
    subOrderId: j['sub_order_id'] as String?,
    amountSdg: j['amount_sdg'] as int,
    sent: j['status'] == 'PAID',
  );

  final String id;
  final String? subOrderId;
  final int amountSdg;
  final bool sent;
}

enum ReturnState { requested, approved, declined }

@immutable
class ReturnRequest {
  const ReturnRequest({required this.reason, required this.state, this.note});

  factory ReturnRequest.fromJson(Json j) => ReturnRequest(
    reason: j['reason'] as String,
    state: ReturnState.values.byName((j['status'] as String).toLowerCase()),
    note: j['decision_note'] as String?,
  );

  final String reason;
  final ReturnState state;

  /// The admin's note when deciding.
  final String? note;
}

/// One cart line checked against the shop's current price and stock (`cart_validate`).
enum CartProblem { priceChanged, notEnoughStock, unavailable }

@immutable
class CartCheck {
  const CartCheck({
    required this.qty,
    required this.seenPriceSdg,
    required this.ok,
    this.listingId,
    this.offerId,
    this.problem,
    this.priceSdg,
    this.availableQty,
  });

  factory CartCheck.fromJson(Json j) => CartCheck(
    listingId: j['listing_id'] as String?,
    offerId: j['offer_id'] as String?,
    qty: j['qty'] as int,
    seenPriceSdg: j['seen_price_sdg'] as int,
    ok: j['ok'] as bool,
    problem: switch (j['problem']) {
      'PRICE_CHANGED' => CartProblem.priceChanged,
      'NOT_ENOUGH_STOCK' => CartProblem.notEnoughStock,
      'UNAVAILABLE' => CartProblem.unavailable,
      _ => null,
    },
    priceSdg: j['price_sdg'] as int?,
    availableQty: j['available_qty'] as int?,
  );

  final String? listingId;
  final String? offerId;
  final int qty;
  final int seenPriceSdg;
  final bool ok;
  final CartProblem? problem;

  /// The price now (null when unavailable).
  final int? priceSdg;
  final int? availableQty;
}

/// A line in a placed order. Title and price are copied at checkout, so later
/// price changes never touch a placed order (the price lock).
@immutable
class OrderItem {
  const OrderItem({
    required this.listingId,
    required this.partId,
    required this.title,
    required this.condition,
    required this.unitPriceSdg,
    required this.qty,
    this.warrantyDays = 0,
  });

  /// A row of `order_items`. [listingId] holds the offer id for an item bought from a
  /// photo-request offer.
  factory OrderItem.fromJson(Json j) => OrderItem(
    listingId: (j['listing_id'] ?? j['offer_id']) as String,
    partId: j['part_id'] as String? ?? '',
    title: LocalizedText.fromJson(j, 'title'),
    condition: ListingCondition.fromCode(j['condition'] as String),
    unitPriceSdg: j['unit_price_sdg'] as int,
    qty: j['qty'] as int,
    warrantyDays: j['warranty_days'] as int? ?? 0,
  );

  final String listingId;
  final String partId;
  final LocalizedText title;
  final ListingCondition condition;
  final int unitPriceSdg;
  final int qty;
  final int warrantyDays;

  int get lineSdg => unitPriceSdg * qty;
}

/// Events come as `{from, to, at}` from the order RPCs, or as `suborder_events` rows.
List<StatusEvent<SubOrderStatus>> _events(Object? list) {
  final rows = [...?(list as List?)?.cast<Json>()];
  rows.sort((a, b) => (a['at'] as String).compareTo(b['at'] as String));
  return [
    for (final e in rows)
      StatusEvent(
        SubOrderStatus.fromCode((e['to'] ?? e['to_status']) as String),
        DateTime.parse(e['at'] as String),
      ),
  ];
}

/// The part of an order that one shop handles.
@immutable
class SubOrder {
  const SubOrder({
    required this.id,
    required this.shopId,
    required this.status,
    required this.fulfilment,
    required this.items,
    required this.events,
    this.deliveryFeeSdg = 0,
    this.acknowledgedAt,
    this.returnRequest,
    this.cancelReason,
  });

  /// From the order RPCs (`items`, `events`, `return`) or a direct select
  /// (`order_items`, `suborder_events`, `returns`).
  factory SubOrder.fromJson(Json j) {
    final ret = j['return'] ?? j['returns'];
    return SubOrder(
      id: j['id'] as String,
      shopId: j['shop_id'] as String,
      status: SubOrderStatus.fromCode(j['status'] as String),
      fulfilment: FulfilmentType.fromCode(j['fulfilment'] as String),
      items: [
        for (final i in ((j['items'] ?? j['order_items']) as List).cast<Json>())
          OrderItem.fromJson(i),
      ],
      events: _events(j['events'] ?? j['suborder_events']),
      deliveryFeeSdg: j['delivery_fee_sdg'] as int? ?? 0,
      acknowledgedAt: DateTime.tryParse(j['shop_ack_at'] as String? ?? ''),
      returnRequest: ret is Json ? ReturnRequest.fromJson(ret) : null,
      cancelReason: j['cancel_reason'] as String?,
    );
  }

  final String id;
  final String shopId;
  final SubOrderStatus status;
  final FulfilmentType fulfilment;
  final List<OrderItem> items;
  final List<StatusEvent<SubOrderStatus>> events;
  final int deliveryFeeSdg;

  /// When the shop tapped "Accept" (D-020: a timestamp, not a status).
  final DateTime? acknowledgedAt;
  final ReturnRequest? returnRequest;

  /// Why the shop declined, or the order was cancelled.
  final String? cancelReason;

  int get itemsSdg => items.fold(0, (sum, i) => sum + i.lineSdg);

  SubOrder copyWith({SubOrderStatus? status, DateTime? at, DateTime? acknowledgedAt}) => SubOrder(
    id: id,
    shopId: shopId,
    status: status ?? this.status,
    fulfilment: fulfilment,
    items: items,
    deliveryFeeSdg: deliveryFeeSdg,
    acknowledgedAt: acknowledgedAt ?? this.acknowledgedAt,
    returnRequest: returnRequest,
    cancelReason: cancelReason,
    events: status == null || status == this.status
        ? events
        : [...events, StatusEvent(status, at ?? DateTime.now())],
  );
}

@immutable
class Order {
  const Order({
    required this.id,
    required this.ref,
    required this.createdAt,
    required this.payBy,
    required this.method,
    required this.paymentStatus,
    required this.subOrders,
    this.bookingId,
    this.bookingFeeSdg = 0,
    this.labourSdg = 0,
    this.travelFeeSdg = 0,
    this.depositSdg = 0,
    this.buyerName = '',
    this.txnNo,
    this.refunds = const <Refund>[],
  });

  /// From `order_json()` (checkout and order RPCs) or a direct select with nested
  /// `payments`, `refunds` and `sub_orders`. A cash order has no pay-by time; it uses
  /// the order time. Its payment state is the shops' cash still due, else collected.
  factory Order.fromJson(Json j) {
    final method = PaymentMethod.fromCode(j['payment_method'] as String);
    final payments = [...?(j['payments'] as List?)?.cast<Json>()];
    final bankak = payments.where(
      (p) => p['method'] == 'BANKAK' && p['purpose'] != 'BOOKING_DEPOSIT',
    );
    final cash = payments.where((p) => p['method'] == 'CASH').map((p) => p['status'] as String);
    final createdAt = DateTime.parse(j['created_at'] as String);
    return Order(
      id: j['id'] as String,
      ref: j['ref'] as String,
      createdAt: createdAt,
      payBy: DateTime.tryParse(j['pay_by'] as String? ?? '') ?? createdAt,
      method: method,
      paymentStatus: bankak.isNotEmpty
          ? PaymentStatus.fromCode(bankak.first['status'] as String)
          : cash.contains('DUE')
          ? PaymentStatus.due
          : cash.contains('COLLECTED')
          ? PaymentStatus.collected
          : PaymentStatus.cancelled,
      txnNo: bankak.isNotEmpty ? bankak.first['bankak_txn_no'] as String? : null,
      subOrders: [for (final s in (j['sub_orders'] as List).cast<Json>()) SubOrder.fromJson(s)],
      bookingFeeSdg: j['booking_fee_sdg'] as int? ?? 0,
      labourSdg: j['labour_sdg'] as int? ?? 0,
      travelFeeSdg: j['travel_sdg'] as int? ?? 0,
      refunds: [
        for (final r in [...?(j['refunds'] as List?)?.cast<Json>()]) Refund.fromJson(r),
      ],
    );
  }

  final String id;

  /// 8 digits with a Luhn check digit (D-016), typed into the Bankak note.
  final String ref;
  final DateTime createdAt;

  /// Unpaid Bankak orders are cancelled after this (D-015).
  final DateTime payBy;
  final PaymentMethod method;
  final PaymentStatus paymentStatus;
  final List<SubOrder> subOrders;
  final String? bookingId;
  final int bookingFeeSdg;
  final int labourSdg;
  final int travelFeeSdg;

  /// For cash bookings at the buyer's location, the part paid by Bankak upfront.
  final int depositSdg;
  final String buyerName;
  final String? txnNo;
  final List<Refund> refunds;

  int get itemsSdg => subOrders.fold(0, (sum, s) => sum + s.itemsSdg);
  int get deliverySdg => subOrders.fold(0, (sum, s) => sum + s.deliveryFeeSdg);
  int get totalSdg => itemsSdg + deliverySdg + bookingFeeSdg + labourSdg + travelFeeSdg;

  /// What the buyer transfers through Bankak right now.
  int get bankakDueSdg => method == PaymentMethod.bankak ? totalSdg : depositSdg;

  int get itemCount => subOrders.fold(0, (n, s) => n + s.items.fold(0, (m, i) => m + i.qty));

  Order copyWith({PaymentStatus? paymentStatus, List<SubOrder>? subOrders, String? txnNo}) => Order(
    id: id,
    ref: ref,
    createdAt: createdAt,
    payBy: payBy,
    method: method,
    paymentStatus: paymentStatus ?? this.paymentStatus,
    subOrders: subOrders ?? this.subOrders,
    bookingId: bookingId,
    bookingFeeSdg: bookingFeeSdg,
    labourSdg: labourSdg,
    travelFeeSdg: travelFeeSdg,
    depositSdg: depositSdg,
    buyerName: buyerName,
    txnNo: txnNo ?? this.txnNo,
    refunds: refunds,
  );
}

// ---------------------------------------------------------------- bookings --

enum BookingStatus {
  held,
  awaitingPayment,
  pendingTechAccept,
  accepted,
  enRoute,
  inProgress,
  completed,
  needsReschedule,
  expired,
  cancelledByBuyer,
  cancelledByTech,
  cancelledByAdmin,
  partDoesNotFit;

  String get code => screamingCase(name);
  static BookingStatus fromCode(String code) => values.byName(camelCase(code));
}

enum BookingPlace {
  bay('BAY'),
  customer('CUSTOMER_LOCATION');

  const BookingPlace(this.code);

  final String code;

  static BookingPlace fromCode(String code) => code == 'BAY' ? bay : customer;
}

@immutable
class BookingItem {
  const BookingItem({
    required this.title,
    required this.jobType,
    required this.minutes,
    this.description,
    this.orderItemId,
  });

  /// An item of `booking_json`. A job type this app version doesn't know reads as SERVICE.
  factory BookingItem.fromJson(Json j) => BookingItem(
    title: LocalizedText.fromJson(j, 'title'),
    jobType: JobType.fromCode(j['job_type_code'] as String?) ?? JobType.service,
    minutes: j['minutes'] as int,
    description: j['description'] as String?,
    orderItemId: j['order_item_id'] as String?,
  );

  final LocalizedText title;
  final JobType jobType;
  final int minutes;

  /// What the buyer wrote about a part bought elsewhere.
  final String? description;
  final String? orderItemId;
}

/// The technician's current offer on a booking (D-024).
@immutable
class BookingOffer {
  const BookingOffer({required this.id, required this.open, required this.expiresAt});

  factory BookingOffer.fromJson(Json j) => BookingOffer(
    id: j['id'] as String,
    open: j['status'] == 'OFFERED',
    expiresAt: DateTime.parse(j['expires_at'] as String),
  );

  final String id;

  /// Still waiting for the technician's answer.
  final bool open;
  final DateTime expiresAt;
}

@immutable
class BookingPhoto {
  const BookingPhoto({
    required this.id,
    required this.before,
    required this.imageKey,
    required this.takenAt,
  });

  factory BookingPhoto.fromJson(Json j) => BookingPhoto(
    id: j['id'] as String,
    before: j['kind'] == 'BEFORE',
    imageKey: j['image_key'] as String,
    takenAt: DateTime.parse(j['taken_at'] as String),
  );

  final String id;
  final bool before;

  /// In the private booking-photos bucket.
  final String imageKey;
  final DateTime takenAt;
}

@immutable
class Booking {
  const Booking({
    required this.id,
    required this.ref,
    required this.status,
    required this.technicianId,
    required this.place,
    required this.startAt,
    required this.durationMin,
    required this.labourSdg,
    required this.items,
    required this.jobCode,
    required this.events,
    this.bayShopId,
    this.address,
    this.travelFeeSdg = 0,
    this.bookingFeeSdg = 0,
    this.depositSdg = 0,
    this.method = PaymentMethod.bankak,
    this.orderId,
    this.partShopId,
    this.buyerName = '',
    this.variantId,
    this.paymentStatus,
    this.externalPart,
    this.orderRef,
    this.technicianName = '',
    this.technicianPhone,
    this.buyerPhone,
    this.offer,
    this.photos = const <BookingPhoto>[],
    this.jobCodeLocked = false,
    this.cancelReason,
    this.locationNote,
    this.bayName,
  });

  /// From `booking_json` (booking RPCs, my_bookings, tech_bookings). The job code is there
  /// for the buyer only; the technician gets the buyer's name and phone instead.
  factory Booking.fromJson(Json j) {
    final tech = j['technician'] as Json? ?? const {};
    final buyer = j['buyer'] as Json?;
    final bay = j['bay'] as Json?;
    final snapshot = j['address_snapshot'] as Json?;
    final offer = j['offer'] as Json?;
    final payments = [...?(j['payments'] as List?)?.cast<Json>()];
    final bankak = payments.where((p) => p['method'] == 'BANKAK').toList();
    final items = [for (final i in (j['items'] as List).cast<Json>()) BookingItem.fromJson(i)];
    final events = [...?(j['events'] as List?)?.cast<Json>()];
    final description = items.map((i) => i.description).whereType<String>().join('، ');
    return Booking(
      id: j['id'] as String,
      ref: j['ref'] as String,
      status: BookingStatus.fromCode(j['status'] as String),
      technicianId: j['technician_id'] as String,
      place: BookingPlace.fromCode(j['place'] as String),
      startAt: DateTime.parse(j['start_at'] as String),
      durationMin: j['duration_min'] as int,
      labourSdg: j['labour_sdg'] as int,
      items: items,
      jobCode: j['job_code'] as String? ?? '',
      events: [
        for (final e in events)
          StatusEvent(BookingStatus.fromCode(e['to'] as String), DateTime.parse(e['at'] as String)),
      ],
      bayShopId: bay?['shop_id'] as String?,
      address: snapshot == null
          ? null
          : Address(
              id: j['address_id'] as String? ?? '',
              label: LocalizedText(
                snapshot['label'] as String? ?? '',
                snapshot['label'] as String? ?? '',
              ),
              description: LocalizedText(
                snapshot['description_ar'] as String? ?? '',
                snapshot['description_ar'] as String? ?? '',
              ),
              distanceKm: 0,
            ),
      travelFeeSdg: j['travel_fee_sdg'] as int? ?? 0,
      bookingFeeSdg: j['booking_fee_sdg'] as int? ?? 0,
      depositSdg: j['deposit_sdg'] as int? ?? 0,
      method: j['payment_method'] == null
          ? PaymentMethod.bankak
          : PaymentMethod.fromCode(j['payment_method'] as String),
      orderId: j['order_id'] as String?,
      buyerName: buyer?['name'] as String? ?? '',
      variantId: j['variant_id'] as String?,
      paymentStatus: bankak.isEmpty
          ? null
          : PaymentStatus.fromCode(bankak.first['status'] as String),
      externalPart: description.isEmpty ? null : description,
      orderRef: j['order_ref'] as String?,
      technicianName: tech['name'] as String? ?? '',
      technicianPhone: tech['phone'] as String?,
      buyerPhone: buyer?['phone'] as String?,
      offer: offer == null ? null : BookingOffer.fromJson(offer),
      photos: [
        for (final p in [...?(j['photos'] as List?)?.cast<Json>()]) BookingPhoto.fromJson(p),
      ],
      jobCodeLocked: j['job_code_locked'] as bool? ?? false,
      cancelReason: j['cancel_reason'] as String?,
      locationNote: j['location_note'] as String?,
      bayName: bay == null ? null : LocalizedText.fromJson(bay, 'name'),
    );
  }

  final String id;
  final String ref;
  final BookingStatus status;
  final String technicianId;
  final BookingPlace place;
  final DateTime startAt;
  final int durationMin;
  final int labourSdg;
  final List<BookingItem> items;

  /// 4 digits only the buyer sees; the technician enters it to finish (D-028).
  final String jobCode;
  final List<StatusEvent<BookingStatus>> events;
  final String? bayShopId;
  final Address? address;
  final int travelFeeSdg;
  final int bookingFeeSdg;
  final int depositSdg;
  final PaymentMethod method;
  final String? orderId;

  /// The shop the part comes from, when it was bought in the same order.
  final String? partShopId;
  final String buyerName;
  final String? variantId;

  /// Only for bookings paid on their own; null when the order covers payment.
  final PaymentStatus? paymentStatus;

  /// What the buyer described when the part was bought elsewhere.
  final String? externalPart;

  /// The order that pays for it (its reference goes in the Bankak note).
  final String? orderRef;
  final String technicianName;

  /// For the buyer once the technician accepted; always for the technician's own view.
  final String? technicianPhone;

  /// For the technician: whom to call.
  final String? buyerPhone;
  final BookingOffer? offer;
  final List<BookingPhoto> photos;

  /// Five wrong job codes: only an admin can close the job now (D-028).
  final bool jobCodeLocked;
  final String? cancelReason;
  final String? locationNote;
  final LocalizedText? bayName;

  DateTime get endAt => startAt.add(Duration(minutes: durationMin));

  /// What the buyer transfers through Bankak for a booking paid on its own.
  int get bankakDueSdg => method == PaymentMethod.bankak ? totalSdg : depositSdg;

  int get totalSdg => labourSdg + travelFeeSdg + bookingFeeSdg;

  bool get isActive => const {
    BookingStatus.held,
    BookingStatus.awaitingPayment,
    BookingStatus.pendingTechAccept,
    BookingStatus.accepted,
    BookingStatus.enRoute,
    BookingStatus.inProgress,
    BookingStatus.needsReschedule,
  }.contains(status);

  Booking copyWith({BookingStatus? status, DateTime? at, PaymentStatus? paymentStatus}) => Booking(
    id: id,
    ref: ref,
    status: status ?? this.status,
    technicianId: technicianId,
    place: place,
    startAt: startAt,
    durationMin: durationMin,
    labourSdg: labourSdg,
    items: items,
    jobCode: jobCode,
    events: status == null || status == this.status
        ? events
        : [...events, StatusEvent(status, at ?? DateTime.now())],
    bayShopId: bayShopId,
    address: address,
    travelFeeSdg: travelFeeSdg,
    bookingFeeSdg: bookingFeeSdg,
    depositSdg: depositSdg,
    method: method,
    orderId: orderId,
    partShopId: partShopId,
    buyerName: buyerName,
    variantId: variantId,
    paymentStatus: paymentStatus ?? this.paymentStatus,
    externalPart: externalPart,
    orderRef: orderRef,
    technicianName: technicianName,
    technicianPhone: technicianPhone,
    buyerPhone: buyerPhone,
    offer: offer,
    photos: photos,
    jobCodeLocked: jobCodeLocked,
    cancelReason: cancelReason,
    locationNote: locationNote,
    bayName: bayName,
  );
}

/// A bookable start time for one technician.
@immutable
class Slot {
  const Slot(this.start, this.durationMin);

  final DateTime start;
  final int durationMin;

  DateTime get end => start.add(Duration(minutes: durationMin));
}

// ---------------------------------------------------------- photo requests --

enum RequestStatus { open, closed, expired }

/// A shop's answer to a buyer's photo request.
@immutable
class PartOffer {
  const PartOffer({
    required this.id,
    required this.shopId,
    required this.title,
    required this.condition,
    required this.priceSdg,
    required this.validUntil,
    this.warrantyDays = 0,
    this.note,
    this.live = true,
    this.imageKey,
  });

  /// A row of `part_offers`.
  factory PartOffer.fromJson(Json j) {
    final note = j['note_ar'] as String?;
    return PartOffer(
      id: j['id'] as String,
      shopId: j['shop_id'] as String,
      title: LocalizedText.fromJson(j, 'title'),
      condition: ListingCondition.fromCode(j['condition'] as String),
      priceSdg: j['price_sdg'] as int,
      validUntil: DateTime.parse(j['valid_until'] as String),
      warrantyDays: j['warranty_days'] as int? ?? 0,
      note: note == null ? null : LocalizedText(note, note),
      live: j['status'] == 'OFFERED',
      imageKey: j['image_key'] as String?,
    );
  }

  final String id;
  final String shopId;
  final LocalizedText title;
  final ListingCondition condition;
  final int priceSdg;
  final DateTime validUntil;
  final int warrantyDays;
  final LocalizedText? note;

  /// Still open to buy (not withdrawn, expired or already ordered).
  final bool live;
  final String? imageKey;
}

@immutable
class PartRequest {
  const PartRequest({
    required this.id,
    required this.note,
    required this.status,
    required this.createdAt,
    required this.expiresAt,
    required this.offers,
    this.variantId,
    this.categoryId,
    this.photoCount = 1,
    this.buyerName = '',
    this.imageKeys = const <String>[],
  });

  /// A row of `part_requests` (with `part_offers` nested for the buyer), or an entry of
  /// `shop_open_requests` (with `buyer_name`).
  factory PartRequest.fromJson(Json j) {
    final images = [...?(j['image_keys'] as List?)?.cast<String>()];
    return PartRequest(
      id: j['id'] as String,
      note: j['note'] as String,
      status: RequestStatus.values.byName((j['status'] as String).toLowerCase()),
      createdAt: DateTime.parse(j['created_at'] as String),
      expiresAt: DateTime.parse(j['expires_at'] as String),
      offers: [
        for (final o in [...?(j['part_offers'] as List?)?.cast<Json>()]) PartOffer.fromJson(o),
      ],
      variantId: j['variant_id'] as String?,
      categoryId: j['category_id'] as String?,
      photoCount: images.length,
      imageKeys: images,
      buyerName: j['buyer_name'] as String? ?? '',
    );
  }

  final String id;
  final String note;
  final RequestStatus status;
  final DateTime createdAt;
  final DateTime expiresAt;
  final List<PartOffer> offers;
  final String? variantId;
  final String? categoryId;
  final int photoCount;
  final String buyerName;

  /// Storage keys in the private request-photos bucket.
  final List<String> imageKeys;
}

// ------------------------------------------------------- inbox and chat --

enum NotificationKind { payment, order, booking, offer, system }

@immutable
class AppNotification {
  const AppNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.at,
    this.read = false,
    this.route,
  });

  final String id;
  final NotificationKind kind;
  final LocalizedText title;
  final LocalizedText body;
  final DateTime at;
  final bool read;
  final String? route;
}

/// One entry of the in-app inbox (`notifications`). The app words it from [code] and
/// [payload] in the reader's language; push (M3) carries the same code.
@immutable
class InboxItem {
  const InboxItem({
    required this.id,
    required this.code,
    required this.payload,
    required this.at,
    this.read = false,
  });

  factory InboxItem.fromJson(Json j) => InboxItem(
    id: j['id'] as String,
    code: j['code'] as String,
    payload: (j['payload'] as Json?) ?? const {},
    at: DateTime.parse(j['created_at'] as String),
    read: j['read_at'] != null,
  );

  /// ORDER_PLACED, PAYMENT_CONFIRMED, PAYMENT_REJECTED, NEW_ORDER, ORDER_READY, NEW_OFFER, …
  final String code;
  final String id;
  final Json payload;
  final DateTime at;
  final bool read;
}

@immutable
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.mine,
    required this.at,
    this.text,
    this.voiceSecs,
    this.voiceKey,
  });

  /// A row of `messages`; [mine] compares the sender with the signed-in user.
  factory ChatMessage.fromJson(Json j, {required String myId}) => ChatMessage(
    id: j['id'] as String,
    mine: j['sender_id'] == myId,
    at: DateTime.parse(j['created_at'] as String),
    text: j['body'] as String?,
    voiceSecs: j['voice_secs'] as int?,
    voiceKey: j['voice_key'] as String?,
  );

  final String id;
  final bool mine;
  final DateTime at;
  final String? text;

  /// Set for voice notes (max 60 s, D-033).
  final int? voiceSecs;

  /// Storage key of the voice note in the private voice-notes bucket.
  final String? voiceKey;
}

/// A chat between a buyer and a shop, optionally about one sub-order.
@immutable
class Conversation {
  const Conversation({
    required this.id,
    required this.shopId,
    required this.title,
    this.subOrderId,
    this.orderRef,
    this.last,
    this.unread = false,
  });

  /// An entry of `shop_conversations`: [title] is the buyer's name.
  factory Conversation.forShop(Json j) {
    final last = j['last'] as Json?;
    final name = j['buyer_name'] as String? ?? '';
    return Conversation(
      id: j['id'] as String,
      shopId: j['shop_id'] as String,
      title: LocalizedText(name, name),
      subOrderId: j['sub_order_id'] as String?,
      orderRef: j['order_ref'] as String?,
      last: last == null
          ? null
          : ChatMessage(
              id: '',
              mine: last['mine'] as bool? ?? false,
              at: DateTime.parse(last['at'] as String),
              text: last['body'] as String?,
              voiceSecs: last['voice_secs'] as int?,
            ),
      unread: j['unread'] as bool? ?? false,
    );
  }

  /// A `conversations` row as the buyer reads it, with `shop`, `sub_order.order.ref` and
  /// the newest of `messages` nested: [title] is the shop's name.
  factory Conversation.forBuyer(Json j, {required String myId}) {
    final shop = j['shop'] as Json? ?? const {};
    final messages = [...?(j['messages'] as List?)?.cast<Json>()];
    final lastAt = DateTime.tryParse(j['last_message_at'] as String? ?? '');
    final readAt = DateTime.tryParse(j['buyer_read_at'] as String? ?? '');
    return Conversation(
      id: j['id'] as String,
      shopId: j['shop_id'] as String,
      title: LocalizedText.fromJson(shop, 'name'),
      subOrderId: j['sub_order_id'] as String?,
      orderRef: ((j['sub_order'] as Json?)?['order'] as Json?)?['ref'] as String?,
      last: messages.isEmpty ? null : ChatMessage.fromJson(messages.first, myId: myId),
      unread: lastAt != null && (readAt == null || lastAt.isAfter(readAt)),
    );
  }

  final String id;
  final String shopId;

  /// The other side: the shop's name for the buyer, the buyer's name for the shop.
  final LocalizedText title;
  final String? subOrderId;
  final String? orderRef;
  final ChatMessage? last;
  final bool unread;
}
