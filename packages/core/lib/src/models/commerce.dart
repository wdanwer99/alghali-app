import 'package:flutter/foundation.dart' show immutable;

import 'catalogue.dart';

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
  returned,
}

enum FulfilmentType { pickup, delivery, toTechnician }

enum PaymentMethod { bankak, cash }

enum PaymentStatus {
  awaitingTransfer,
  receiptSubmitted,
  confirmed,
  rejected,
  due,
  collected,
  expired,
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

  final String listingId;
  final String partId;
  final LocalizedText title;
  final ListingCondition condition;
  final int unitPriceSdg;
  final int qty;
  final int warrantyDays;

  int get lineSdg => unitPriceSdg * qty;
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
  });

  final String id;
  final String shopId;
  final SubOrderStatus status;
  final FulfilmentType fulfilment;
  final List<OrderItem> items;
  final List<StatusEvent<SubOrderStatus>> events;
  final int deliveryFeeSdg;

  /// When the shop tapped "Accept" (D-020: a timestamp, not a status).
  final DateTime? acknowledgedAt;

  int get itemsSdg => items.fold(0, (sum, i) => sum + i.lineSdg);

  SubOrder copyWith({SubOrderStatus? status, DateTime? at, DateTime? acknowledgedAt}) => SubOrder(
    id: id,
    shopId: shopId,
    status: status ?? this.status,
    fulfilment: fulfilment,
    items: items,
    deliveryFeeSdg: deliveryFeeSdg,
    acknowledgedAt: acknowledgedAt ?? this.acknowledgedAt,
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
  });

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
  partDoesNotFit,
}

enum BookingPlace { bay, customer }

@immutable
class BookingItem {
  const BookingItem({required this.title, required this.jobType, required this.minutes});

  final LocalizedText title;
  final JobType jobType;
  final int minutes;
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
  });

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
  });

  final String id;
  final String shopId;
  final LocalizedText title;
  final ListingCondition condition;
  final int priceSdg;
  final DateTime validUntil;
  final int warrantyDays;
  final LocalizedText? note;
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
  });

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

@immutable
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.mine,
    required this.at,
    this.text,
    this.voiceSecs,
  });

  final String id;
  final bool mine;
  final DateTime at;
  final String? text;

  /// Set for voice notes (max 60 s, D-033).
  final int? voiceSecs;
}
