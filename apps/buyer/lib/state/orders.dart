import 'dart:async';
import 'dart:typed_data';

import 'package:alghali_core/alghali_core.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'bookings.dart';
import 'cart.dart';
import 'connection.dart';
import 'session.dart';

/// What the buyer picked on the checkout screen.
@immutable
class CheckoutChoice {
  const CheckoutChoice({required this.method, required this.fulfilment, this.addressId});

  final PaymentMethod method;

  /// Per shop, for shops without a fitting (those always hand over to the technician).
  final Map<String, FulfilmentType> fulfilment;

  /// Where deliveries go.
  final String? addressId;
}

const _activeOrder = {
  SubOrderStatus.pendingPayment,
  SubOrderStatus.paymentReview,
  SubOrderStatus.confirmed,
  SubOrderStatus.ready,
  SubOrderStatus.outForDelivery,
  SubOrderStatus.handedToTechnician,
};

extension OrderState on Order {
  bool get isActive => subOrders.any((s) => _activeOrder.contains(s.status));

  bool get isCancelled => subOrders.every(
    (s) => s.status == SubOrderStatus.cancelled || s.status == SubOrderStatus.rejectedByShop,
  );

  /// While waiting for payment, or a cash order no shop has accepted yet (`cancel_order`).
  bool get canCancel =>
      !isCancelled &&
      subOrders.every(
        (s) =>
            s.status == SubOrderStatus.pendingPayment ||
            s.status == SubOrderStatus.paymentReview ||
            (method == PaymentMethod.cash &&
                s.status == SubOrderStatus.confirmed &&
                s.acknowledgedAt == null),
      );

  /// A Bankak transfer (the order's or a cash order's deposit) is still to be sent.
  bool get needsTransfer =>
      !isCancelled &&
      bankakDueSdg > 0 &&
      (bankakStatus == PaymentStatus.awaitingTransfer || bankakStatus == PaymentStatus.rejected);

  bool get receiptBeingChecked => !isCancelled && bankakStatus == PaymentStatus.receiptSubmitted;

  /// Sub-orders in the order a buyer walks the street to collect them (brief §6).
  List<SubOrder> streetOrder(CatalogueData c) =>
      [...subOrders]..sort((a, b) => c.shop(a.shopId).posM.compareTo(c.shop(b.shopId).posM));
}

/// The buyer's orders, newest first: the saved copy at once, then the server's.
class OrdersController extends AsyncNotifier<List<Order>> with CachedList<List<Order>> {
  @override
  Future<List<Order>> build() async {
    final uid = ref.watch(sessionProvider.select((s) => s.userId));
    if (uid == null) return const [];
    return load();
  }

  OrdersRepository get _repo => ref.read(ordersRepositoryProvider);

  @override
  Future<List<Order>?> peek() => _repo.peek();

  @override
  Future<List<Order>> fetch() => _repo.list();

  Order? byId(String id) => state.value?.where((o) => o.id == id).firstOrNull;

  /// Places the cart: every line, and the held fitting if there is one. [idem] stays the
  /// same while the buyer retries the same cart, so a lost answer never orders twice.
  ///
  /// Throws [CartChangedException] after updating the cart to the new prices and stock,
  /// and HOLD_EXPIRED after dropping the lapsed fitting.
  Future<Order> checkout(CheckoutChoice choice, {required String idem}) async {
    final cart = ref.read(cartProvider);
    final fitting = cart.fitting;
    final fittedShops = {
      for (final l in cart.lines)
        if (cart.fitted(l.id)) l.shopId,
    };
    final Order order;
    try {
      order = await _repo.checkout(
        [for (final l in cart.lines) l.checkoutLine],
        choice.method,
        fulfilment: {
          for (final MapEntry(:key, :value) in choice.fulfilment.entries)
            if (!fittedShops.contains(key)) key: value,
        },
        addressId: choice.addressId,
        bookingId: fitting?.booking.id,
        idem: idem,
      );
    } on CartChangedException catch (e) {
      ref.read(cartProvider.notifier).applyChecks(e.lines);
      rethrow;
    } on BackendException catch (e) {
      if (e.code == 'HOLD_EXPIRED' || e.code == 'BOOKING_NOT_FOUND') {
        ref.read(cartProvider.notifier).dropFitting();
      }
      rethrow;
    }
    ref.read(cartProvider.notifier).clear();
    put(order);
    if (fitting != null) ref.invalidate(bookingsProvider);
    return order;
  }

  /// Pays for a held fitting on its own (a part bought elsewhere or earlier, D-097).
  Future<Order> checkoutFitting(Booking held, PaymentMethod method, {required String idem}) async {
    final order = await _repo.checkout(const [], method, bookingId: held.id, idem: idem);
    put(order);
    ref.invalidate(bookingsProvider);
    return order;
  }

  /// Puts a fresh copy of [order] in the list.
  void put(Order order) {
    final list = state.value ?? const <Order>[];
    final i = list.indexWhere((o) => o.id == order.id);
    state = AsyncData(
      i < 0 ? [order, ...list] : [for (final o in list) o.id == order.id ? order : o],
    );
  }
}

final ordersProvider = AsyncNotifierProvider<OrdersController, List<Order>>(OrdersController.new);

/// One order, with the buyer's actions on it.
class OrderController extends AsyncNotifier<Order?> {
  OrderController(this.id);

  final String id;

  OrdersRepository get _repo => ref.read(ordersRepositoryProvider);

  @override
  Future<Order?> build() async {
    final listed = ref.read(ordersProvider).value?.where((o) => o.id == id).firstOrNull;
    if (listed != null) {
      unawaited(Future.microtask(refresh));
      return listed;
    }
    return _repo.get(id);
  }

  Future<void> refresh() async {
    try {
      final o = await _repo.get(id);
      if (!ref.mounted) return;
      state = AsyncData(o);
      if (o != null) ref.read(ordersProvider.notifier).put(o);
    } on Object catch (e, st) {
      if (ref.mounted && !state.hasValue) state = AsyncError(e, st);
    }
  }

  Order _apply(Order o) {
    if (ref.mounted) state = AsyncData(o);
    ref.read(ordersProvider.notifier).put(o);
    return o;
  }

  /// The transaction number, a photo of the receipt, or both (D-084).
  Future<Order> submitReceipt({
    String? txnNo,
    Uint8List? receipt,
    String? fileName,
    required String idem,
  }) async => _apply(
    await _repo.submitReceipt(
      id,
      txnNo: txnNo == null || txnNo.isEmpty ? null : txnNo,
      receipt: receipt,
      fileName: fileName,
      idem: idem,
    ),
  );

  Future<Order> cancel() async {
    final o = _apply(await _repo.cancel(id));
    ref.invalidate(bookingsProvider);
    return o;
  }

  Future<Order> confirmReceived(String subOrderId) async =>
      _apply(await _repo.confirmReceived(subOrderId));

  Future<Order> requestReturn(String subOrderId, String reason) async =>
      _apply(await _repo.requestReturn(subOrderId, reason));
}

final orderProvider = AsyncNotifierProvider.autoDispose.family<OrderController, Order?, String>(
  OrderController.new,
);
