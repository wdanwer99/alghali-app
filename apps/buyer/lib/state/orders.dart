import 'package:alghali_core/alghali_core.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'cart.dart';
import 'demo_account.dart';
import 'garage.dart';
import 'session.dart';

/// What the buyer picked on the checkout screen.
@immutable
class CheckoutChoice {
  const CheckoutChoice({required this.method, required this.fulfilment, this.deliveryAddress});

  final PaymentMethod method;

  /// Per shop, for shops without a fitting (those always hand over to the technician).
  final Map<String, FulfilmentType> fulfilment;
  final Address? deliveryAddress;
}

const _activeOrder = {
  SubOrderStatus.pendingPayment,
  SubOrderStatus.paymentReview,
  SubOrderStatus.confirmed,
  SubOrderStatus.ready,
  SubOrderStatus.outForDelivery,
};

extension OrderState on Order {
  bool get isActive => subOrders.any((s) => _activeOrder.contains(s.status));

  bool get isCancelled => subOrders.every((s) => s.status == SubOrderStatus.cancelled);

  /// Buyers may cancel until a shop has confirmed (PLAN §3.10).
  bool get canCancel => subOrders.every(
    (s) => s.status == SubOrderStatus.pendingPayment || s.status == SubOrderStatus.paymentReview,
  );

  bool get needsTransfer =>
      paymentStatus == PaymentStatus.awaitingTransfer && bankakDueSdg > 0 && !isCancelled;
}

/// The buyer's orders. Demo: checkout and status changes happen in memory;
/// in M4 these call `checkout`, `submit_bankak_receipt` and friends.
class OrdersController extends Notifier<List<Order>> {
  @override
  List<Order> build() {
    final signedIn = ref.watch(sessionProvider.select((s) => s.signedIn));
    return signedIn ? demoOrders(ref.read(clockProvider)()) : const [];
  }

  DateTime get _now => ref.read(clockProvider)();

  Order? byId(String id) => state.where((o) => o.id == id).firstOrNull;

  Order place({required List<CartLine> lines, required CheckoutChoice choice}) {
    final now = _now;
    final catalogue = ref.read(catalogueProvider);
    final settings = ref.read(platformSettingsProvider);
    final session = ref.read(sessionProvider);
    final cash = choice.method == PaymentMethod.cash;
    final orderId = 'ord-${now.microsecondsSinceEpoch}';

    final shops = <String>{for (final l in lines) l.shopId};
    final subOrders = <SubOrder>[];
    for (final shopId in shops) {
      final shopLines = lines.where((l) => l.shopId == shopId).toList();
      final fulfilment = shopLines.any((l) => l.fitting != null)
          ? FulfilmentType.toTechnician
          : choice.fulfilment[shopId] ?? FulfilmentType.pickup;
      // Cash orders skip the payment check and go straight to the shop.
      final status = cash ? SubOrderStatus.confirmed : SubOrderStatus.pendingPayment;
      subOrders.add(
        SubOrder(
          id: '$orderId-${subOrders.length + 1}',
          shopId: shopId,
          status: status,
          fulfilment: fulfilment,
          deliveryFeeSdg: fulfilment == FulfilmentType.delivery
              ? settings.deliveryFee(choice.deliveryAddress?.distanceKm ?? 0) ?? 0
              : 0,
          events: [StatusEvent(status, now)],
          items: [
            for (final l in shopLines)
              OrderItem(
                listingId: l.listingId ?? l.offerId!,
                partId: l.partId ?? '',
                title: l.title,
                condition: l.condition,
                unitPriceSdg: l.unitPriceSdg,
                qty: l.qty,
                warrantyDays: l.warrantyDays,
              ),
          ],
        ),
      );
    }

    final bookings = <Booking>[];
    for (final l in lines) {
      final f = l.fitting;
      if (f == null) continue;
      final category = catalogue.category(l.categoryId);
      final atHome = f.place == BookingPlace.customer;
      final deposit = cash && atHome ? settings.mobileDepositSdg : 0;
      final status = !cash || deposit > 0
          ? BookingStatus.awaitingPayment
          : BookingStatus.pendingTechAccept;
      bookings.add(
        Booking(
          id: 'bk-${now.microsecondsSinceEpoch}-${bookings.length}',
          ref: newOrderRef(),
          status: status,
          technicianId: f.technicianId,
          place: f.place,
          bayShopId: atHome ? null : catalogue.technician(f.technicianId).bayShopId,
          address: f.address,
          startAt: f.slot.start,
          durationMin: f.slot.durationMin,
          labourSdg: f.labourSdg,
          travelFeeSdg: f.travelFeeSdg,
          bookingFeeSdg: settings.bookingFeeSdg,
          depositSdg: deposit,
          method: choice.method,
          jobCode: newJobCode(),
          orderId: orderId,
          partShopId: l.shopId,
          variantId: ref.read(selectedVariantProvider),
          items: [
            BookingItem(
              title: l.title,
              jobType: category.jobType ?? JobType.service,
              minutes: f.slot.durationMin,
            ),
          ],
          events: [
            StatusEvent(BookingStatus.held, now.subtract(const Duration(minutes: 2))),
            StatusEvent(status, now),
          ],
        ),
      );
    }

    final deposit = bookings.fold(0, (s, b) => s + b.depositSdg);
    final order = Order(
      id: orderId,
      ref: newOrderRef(),
      createdAt: now,
      payBy: now.add(Duration(minutes: settings.paymentWindowMinutes)),
      method: choice.method,
      paymentStatus: !cash || deposit > 0 ? PaymentStatus.awaitingTransfer : PaymentStatus.due,
      subOrders: subOrders,
      bookingId: bookings.firstOrNull?.id,
      bookingFeeSdg: bookings.fold(0, (s, b) => s + b.bookingFeeSdg),
      labourSdg: bookings.fold(0, (s, b) => s + b.labourSdg),
      travelFeeSdg: bookings.fold(0, (s, b) => s + b.travelFeeSdg),
      depositSdg: deposit,
      buyerName: session.name ?? '',
    );
    state = [order, ...state];
    ref.read(bookingsProvider.notifier).addAll(bookings);
    ref.read(cartProvider.notifier).clear();
    return order;
  }

  void submitReceipt(String orderId, {String? txnNo}) {
    _update(
      orderId,
      (o) => o.copyWith(
        paymentStatus: PaymentStatus.receiptSubmitted,
        txnNo: txnNo,
        subOrders: [
          for (final s in o.subOrders)
            s.status == SubOrderStatus.pendingPayment
                ? s.copyWith(status: SubOrderStatus.paymentReview, at: _now)
                : s,
        ],
      ),
    );
  }

  void cancel(String orderId) {
    final order = byId(orderId);
    if (order == null || !order.canCancel) return;
    _update(
      orderId,
      (o) => o.copyWith(
        subOrders: [
          for (final s in o.subOrders) s.copyWith(status: SubOrderStatus.cancelled, at: _now),
        ],
      ),
    );
    final bookings = ref.read(bookingsProvider.notifier);
    for (final b in ref.read(bookingsProvider).where((b) => b.orderId == orderId)) {
      bookings.cancel(b.id);
    }
  }

  void requestReturn(String orderId, String subOrderId) => _update(
    orderId,
    (o) => o.copyWith(
      subOrders: [
        for (final s in o.subOrders)
          s.id == subOrderId ? s.copyWith(status: SubOrderStatus.returnRequested, at: _now) : s,
      ],
    ),
  );

  /// Demo only: plays the next move of the admin, shop or courier.
  void demoAdvance(String orderId) {
    final order = byId(orderId);
    if (order == null || order.isCancelled) return;
    final now = _now;
    switch (order.paymentStatus) {
      case PaymentStatus.awaitingTransfer:
        submitReceipt(orderId, txnNo: '2009${now.millisecond}${now.second}');
        return;
      case PaymentStatus.receiptSubmitted:
        _update(
          orderId,
          (o) => o.copyWith(
            paymentStatus: o.method == PaymentMethod.cash
                ? PaymentStatus.due
                : PaymentStatus.confirmed,
            subOrders: [
              for (final s in o.subOrders)
                s.status == SubOrderStatus.paymentReview ||
                        s.status == SubOrderStatus.pendingPayment
                    ? s.copyWith(status: SubOrderStatus.confirmed, at: now, acknowledgedAt: now)
                    : s,
            ],
          ),
        );
        for (final b in ref.read(bookingsProvider).where((b) => b.orderId == orderId)) {
          if (b.status == BookingStatus.awaitingPayment) {
            ref.read(bookingsProvider.notifier).setStatus(b.id, BookingStatus.pendingTechAccept);
          }
        }
        return;
      default:
    }
    final next = order.subOrders.indexWhere((s) => _nextStatus(s) != null);
    if (next < 0) return;
    final sub = order.subOrders[next];
    final status = _nextStatus(sub)!;
    _update(
      orderId,
      (o) => o.copyWith(
        paymentStatus: status == SubOrderStatus.pickedUp && o.paymentStatus == PaymentStatus.due
            ? PaymentStatus.collected
            : null,
        subOrders: [
          for (final s in o.subOrders) s.id == sub.id ? s.copyWith(status: status, at: now) : s,
        ],
      ),
    );
  }

  /// Called when a booking finishes: its part's sub-order completes too (D-021).
  void completeHandedOver(String orderId) => _update(
    orderId,
    (o) => o.copyWith(
      subOrders: [
        for (final s in o.subOrders)
          s.status == SubOrderStatus.handedToTechnician
              ? s.copyWith(status: SubOrderStatus.completed, at: _now)
              : s,
      ],
    ),
  );

  static SubOrderStatus? _nextStatus(SubOrder s) => switch (s.status) {
    SubOrderStatus.confirmed => SubOrderStatus.ready,
    SubOrderStatus.ready => switch (s.fulfilment) {
      FulfilmentType.pickup => SubOrderStatus.pickedUp,
      FulfilmentType.delivery => SubOrderStatus.outForDelivery,
      FulfilmentType.toTechnician => SubOrderStatus.handedToTechnician,
    },
    SubOrderStatus.outForDelivery => SubOrderStatus.delivered,
    SubOrderStatus.pickedUp || SubOrderStatus.delivered => SubOrderStatus.completed,
    _ => null,
  };

  void _update(String id, Order Function(Order) change) =>
      state = [for (final o in state) o.id == id ? change(o) : o];
}

final ordersProvider = NotifierProvider<OrdersController, List<Order>>(OrdersController.new);

class BookingsController extends Notifier<List<Booking>> {
  @override
  List<Booking> build() {
    final signedIn = ref.watch(sessionProvider.select((s) => s.signedIn));
    return signedIn ? demoBookings(ref.read(clockProvider)()) : const [];
  }

  DateTime get _now => ref.read(clockProvider)();

  Booking? byId(String id) => state.where((b) => b.id == id).firstOrNull;

  void addAll(List<Booking> bookings) => state = [...bookings, ...state];

  /// A fitting for a part bought elsewhere (booking_items.external_desc).
  Booking createStandalone({
    required FittingDraft draft,
    required JobType jobType,
    required String description,
    required PaymentMethod method,
    String? variantId,
  }) {
    final now = _now;
    final settings = ref.read(platformSettingsProvider);
    final atHome = draft.place == BookingPlace.customer;
    final deposit = method == PaymentMethod.cash && atHome ? settings.mobileDepositSdg : 0;
    final needsBankak = method == PaymentMethod.bankak || deposit > 0;
    final status = needsBankak ? BookingStatus.awaitingPayment : BookingStatus.pendingTechAccept;
    final booking = Booking(
      id: 'bk-${now.microsecondsSinceEpoch}',
      ref: newOrderRef(),
      status: status,
      technicianId: draft.technicianId,
      place: draft.place,
      bayShopId: atHome
          ? null
          : ref.read(catalogueProvider).technician(draft.technicianId).bayShopId,
      address: draft.address,
      startAt: draft.slot.start,
      durationMin: draft.slot.durationMin,
      labourSdg: draft.labourSdg,
      travelFeeSdg: draft.travelFeeSdg,
      bookingFeeSdg: settings.bookingFeeSdg,
      depositSdg: deposit,
      method: method,
      jobCode: newJobCode(),
      variantId: variantId,
      externalPart: description,
      paymentStatus: needsBankak ? PaymentStatus.awaitingTransfer : PaymentStatus.due,
      items: [
        BookingItem(
          title: LocalizedText(description, description),
          jobType: jobType,
          minutes: draft.slot.durationMin,
        ),
      ],
      events: [StatusEvent(BookingStatus.held, now), StatusEvent(status, now)],
    );
    state = [booking, ...state];
    return booking;
  }

  void submitReceipt(String bookingId) =>
      _update(bookingId, (b) => b.copyWith(paymentStatus: PaymentStatus.receiptSubmitted));

  void setStatus(String id, BookingStatus status) =>
      _update(id, (b) => b.copyWith(status: status, at: _now));

  void cancel(String id) => setStatus(id, BookingStatus.cancelledByBuyer);

  /// Demo only: payment check → technician accepts → on the way → done.
  void demoAdvance(String id) {
    final b = byId(id);
    if (b == null) return;
    if (b.paymentStatus == PaymentStatus.awaitingTransfer) {
      submitReceipt(id);
      return;
    }
    if (b.paymentStatus == PaymentStatus.receiptSubmitted) {
      _update(id, (b) => b.copyWith(paymentStatus: PaymentStatus.confirmed));
    }
    final next = switch (b.status) {
      BookingStatus.held => BookingStatus.awaitingPayment,
      BookingStatus.awaitingPayment => BookingStatus.pendingTechAccept,
      BookingStatus.pendingTechAccept => BookingStatus.accepted,
      BookingStatus.accepted =>
        b.place == BookingPlace.customer ? BookingStatus.enRoute : BookingStatus.inProgress,
      BookingStatus.enRoute => BookingStatus.inProgress,
      BookingStatus.inProgress => BookingStatus.completed,
      _ => null,
    };
    if (next == null) return;
    // The shop hands the part over before the technician can start (PLAN §3.10 guard).
    final orderId = b.orderId;
    if (orderId != null && (next == BookingStatus.enRoute || next == BookingStatus.inProgress)) {
      final orders = ref.read(ordersProvider.notifier);
      for (var i = 0; i < 6 && _partPending(orders.byId(orderId)); i++) {
        orders.demoAdvance(orderId);
      }
    }
    setStatus(id, next);
    if (next == BookingStatus.completed && b.orderId != null) {
      ref.read(ordersProvider.notifier).completeHandedOver(b.orderId!);
    }
  }

  static bool _partPending(Order? o) =>
      o != null &&
      !o.isCancelled &&
      o.subOrders.any(
        (s) =>
            s.fulfilment == FulfilmentType.toTechnician &&
            s.status != SubOrderStatus.handedToTechnician &&
            s.status != SubOrderStatus.completed,
      );

  void _update(String id, Booking Function(Booking) change) =>
      state = [for (final b in state) b.id == id ? change(b) : b];
}

final bookingsProvider = NotifierProvider<BookingsController, List<Booking>>(
  BookingsController.new,
);

class RequestsController extends Notifier<List<PartRequest>> {
  @override
  List<PartRequest> build() {
    final signedIn = ref.watch(sessionProvider.select((s) => s.signedIn));
    return signedIn ? demoRequests(ref.read(clockProvider)()) : const [];
  }

  PartRequest? byId(String id) => state.where((r) => r.id == id).firstOrNull;

  PartRequest create({
    required String note,
    required int photoCount,
    String? variantId,
    String? categoryId,
  }) {
    final now = ref.read(clockProvider)();
    final request = PartRequest(
      id: 'rq-${now.microsecondsSinceEpoch}',
      note: note,
      status: RequestStatus.open,
      createdAt: now,
      expiresAt: now.add(const Duration(hours: 24)),
      offers: const [],
      variantId: variantId,
      categoryId: categoryId,
      photoCount: photoCount,
    );
    state = [request, ...state];
    return request;
  }

  void close(String id) => _update(id, (r) => _copy(r, status: RequestStatus.closed));

  /// Demo only: a shop answers the request.
  void demoAddOffer(String id) {
    final now = ref.read(clockProvider)();
    _update(id, (r) {
      const shops = ['sh-amin', 'sh-farouq', 'sh-safi', 'sh-zain'];
      final shopId = shops[r.offers.length % shops.length];
      final title = LocalizedText(r.note, r.note);
      return _copy(
        r,
        offers: [
          ...r.offers,
          PartOffer(
            id: 'of-${now.microsecondsSinceEpoch}',
            shopId: shopId,
            title: title,
            condition: shopId == 'sh-safi'
                ? ListingCondition.used
                : ListingCondition.newAftermarket,
            priceSdg: shopId == 'sh-safi' ? 14000 : 27000 + 1000 * r.offers.length,
            warrantyDays: shopId == 'sh-safi' ? 0 : 30,
            validUntil: now.add(const Duration(hours: 24)),
          ),
        ],
      );
    });
  }

  PartRequest _copy(PartRequest r, {RequestStatus? status, List<PartOffer>? offers}) => PartRequest(
    id: r.id,
    note: r.note,
    status: status ?? r.status,
    createdAt: r.createdAt,
    expiresAt: r.expiresAt,
    offers: offers ?? r.offers,
    variantId: r.variantId,
    categoryId: r.categoryId,
    photoCount: r.photoCount,
  );

  void _update(String id, PartRequest Function(PartRequest) change) =>
      state = [for (final r in state) r.id == id ? change(r) : r];
}

final requestsProvider = NotifierProvider<RequestsController, List<PartRequest>>(
  RequestsController.new,
);

class NotificationsController extends Notifier<List<AppNotification>> {
  @override
  List<AppNotification> build() {
    final signedIn = ref.watch(sessionProvider.select((s) => s.signedIn));
    return signedIn ? demoNotifications(ref.read(clockProvider)()) : const [];
  }

  void markAllRead() => state = [
    for (final n in state)
      AppNotification(
        id: n.id,
        kind: n.kind,
        title: n.title,
        body: n.body,
        at: n.at,
        read: true,
        route: n.route,
      ),
  ];
}

final notificationsProvider = NotifierProvider<NotificationsController, List<AppNotification>>(
  NotificationsController.new,
);

final unreadCountProvider = Provider<int>(
  (ref) => ref.watch(notificationsProvider).where((n) => !n.read).length,
);

class ChatController extends Notifier<Map<String, List<ChatMessage>>> {
  @override
  Map<String, List<ChatMessage>> build() {
    final signedIn = ref.watch(sessionProvider.select((s) => s.signedIn));
    return signedIn ? demoChats(ref.read(clockProvider)()) : const {};
  }

  void send(String shopId, {String? text, int? voiceSecs}) {
    final now = ref.read(clockProvider)();
    state = {
      ...state,
      shopId: [
        ...?state[shopId],
        ChatMessage(
          id: 'm-${now.microsecondsSinceEpoch}',
          mine: true,
          at: now,
          text: text,
          voiceSecs: voiceSecs,
        ),
      ],
    };
  }
}

final chatProvider = NotifierProvider<ChatController, Map<String, List<ChatMessage>>>(
  ChatController.new,
);

class AddressesController extends Notifier<List<Address>> {
  @override
  List<Address> build() => demoAddresses;

  Address addCurrentLocation() {
    const here = Address(
      id: 'ad-here',
      label: LocalizedText('موقعي الحالي', 'My current location'),
      description: LocalizedText('حُدد بالـ GPS', 'Set by GPS'),
      distanceKm: 4.1,
    );
    if (!state.any((a) => a.id == here.id)) state = [...state, here];
    return here;
  }
}

final addressesProvider = NotifierProvider<AddressesController, List<Address>>(
  AddressesController.new,
);

/// Sub-orders and bookings the buyer has already rated.
class ReviewedController extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  void add(String key) => state = {...state, key};
}

final reviewedProvider = NotifierProvider<ReviewedController, Set<String>>(ReviewedController.new);
