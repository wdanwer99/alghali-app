import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show immutable;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/catalogue.dart';
import '../models/commerce.dart';
import '../models/tint.dart';
import 'backend_error.dart';
import 'read_cache.dart';
import 'uploads.dart';

/// One line the buyer is about to buy: a listing (any quantity) or a shop's offer on
/// their photo request (always 1), at the price the buyer saw.
@immutable
class CheckoutLine {
  const CheckoutLine.listing(String this.listingId, {required this.qty, required this.seenPriceSdg})
    : offerId = null,
      tintShopId = null,
      tint = null;
  const CheckoutLine.offer(String this.offerId, {required this.seenPriceSdg})
    : listingId = null,
      tintShopId = null,
      tint = null,
      qty = 1;

  /// Window tint from [tintShopId], always one (D-149).
  const CheckoutLine.tint(
    String this.tintShopId,
    TintChoice this.tint, {
    required this.seenPriceSdg,
  }) : listingId = null,
       offerId = null,
       qty = 1;

  final String? listingId;
  final String? offerId;
  final String? tintShopId;
  final TintChoice? tint;
  final int qty;
  final int seenPriceSdg;

  Json toJson() => {
    if (listingId != null) 'listing_id': listingId,
    if (offerId != null) 'offer_id': offerId,
    if (tintShopId != null) 'tint_shop_id': tintShopId,
    if (tint != null) 'tint': tint!.toJson(),
    'qty': qty,
    'seen_price_sdg': seenPriceSdg,
  };
}

/// Checkout found a price or stock change: nothing was placed. [lines] say what changed
/// so the app can show it and let the buyer accept the new prices.
class CartChangedException extends BackendException {
  CartChangedException(this.lines) : super(cartChanged, status: 409);

  static const cartChanged = 'CART_CHANGED';

  final List<CartCheck> lines;
}

/// The buyer's orders: checkout, Bankak receipts, cancelling, confirming receipt and
/// returns. Order lists are read directly (row level security shows only the buyer's own).
class OrdersRepository with CachedReads {
  OrdersRepository(this._client, {this.cache});

  final SupabaseClient _client;
  @override
  final ReadCache? cache;

  static const _orderSelect =
      '*, payments(*), refunds(*), sub_orders(*, shop:shops(id, name_ar, name_en, phone, whatsapp, '
      'zone_id, plot_no, pos_m), order_items(*), suborder_events(*), returns(*))';

  /// Checks the lines against current prices and stock without placing anything.
  /// Works for guests too.
  Future<List<CartCheck>> validate(List<CheckoutLine> lines) => guard(() async {
    final res = await _client.rpc<List<dynamic>>(
      'cart_validate',
      params: {
        'p_items': [for (final l in lines) l.toJson()],
      },
    );
    return [for (final r in res.cast<Json>()) CartCheck.fromJson(r)];
  });

  /// Places the order: one sub-order per shop. [fulfilment] maps shop ids to pickup or
  /// delivery (pickup when missing); delivery needs [addressId]. Throws
  /// [CartChangedException] when a price or stock changed, PHONE_REQUIRED when the buyer
  /// has no phone yet.
  ///
  /// With [bookingId] (a held fitting, `BookingsRepository.hold`) the fitting is paid in
  /// the same order and its parts go to the technician; [lines] may then be empty for a
  /// part bought elsewhere (D-097). HOLD_EXPIRED when the hold lapsed.
  Future<Order> checkout(
    List<CheckoutLine> lines,
    PaymentMethod method, {
    Map<String, FulfilmentType> fulfilment = const {},
    String? addressId,
    String? bookingId,
    String? idem,
  }) async {
    try {
      final row = await _client.rpc<Json>(
        'checkout',
        params: {
          'p_items': [for (final l in lines) l.toJson()],
          'p_method': method.code,
          'p_fulfilment': {
            for (final MapEntry(:key, :value) in fulfilment.entries) key: value.code,
          },
          'p_address_id': addressId,
          'p_idem': idem ?? newIdempotencyKey(),
          'p_booking_id': bookingId,
        },
      );
      return Order.fromJson(row);
    } on Object catch (e) {
      final error = BackendException.from(e);
      if (error.code == CartChangedException.cartChanged && error.detail != null) {
        final lines = jsonDecode(error.detail!) as List;
        throw CartChangedException([for (final l in lines.cast<Json>()) CartCheck.fromJson(l)]);
      }
      throw error;
    }
  }

  /// Newest first. The first page is kept for offline use.
  Future<List<Order>> list({int limit = 30, int offset = 0}) => cachedRead(
    offset == 0 ? '@orders' : '@orders:$offset',
    () => _client
        .from('orders')
        .select(_orderSelect)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1),
    _orders,
  );

  /// The saved first page, without asking the network.
  Future<List<Order>?> peek() => cachedPeek('@orders', _orders);

  static List<Order> _orders(Object? raw) => [
    for (final r in (raw! as List).cast<Json>()) Order.fromJson(r),
  ];

  /// Null when it isn't the buyer's order.
  Future<Order?> get(String orderId) => cachedRead(
    '@order:$orderId',
    () => _client.from('orders').select(_orderSelect).eq('id', orderId).maybeSingle(),
    (raw) => raw == null ? null : Order.fromJson(raw as Json),
  );

  /// Sends the Bankak transfer: the transaction number, a screenshot or PDF of the
  /// receipt, or both (one is required). Can be sent again after a rejection.
  /// DUPLICATE_TXN when the number was already used; PAYMENT_EXPIRED after the window.
  Future<Order> submitReceipt(
    String orderId, {
    String? txnNo,
    Uint8List? receipt,
    String? fileName,
    String? idem,
  }) => guard(() async {
    String? key;
    if (receipt != null) {
      final name = fileName ?? 'receipt.jpg';
      key = '${signedInUserId(_client)}/${newIdempotencyKey()}${extensionOf(name)}';
      await _client.storage
          .from('receipts')
          .uploadBinary(key, receipt, fileOptions: FileOptions(contentType: mimeOf(name)));
    }
    final row = await _client.rpc<Json>(
      'submit_bankak_receipt',
      params: {
        'p_order_id': orderId,
        'p_txn_no': txnNo,
        'p_receipt_key': key,
        'p_idem': idem ?? newIdempotencyKey(),
      },
    );
    return Order.fromJson(row);
  });

  /// Before any shop has started (waiting for payment, or a cash order no shop has
  /// accepted yet). CANNOT_CANCEL otherwise.
  Future<Order> cancel(String orderId, {String? reason}) => guard(() async {
    final row = await _client.rpc<Json>(
      'cancel_order',
      params: {'p_order_id': orderId, 'p_reason': reason},
    );
    return Order.fromJson(row);
  });

  /// The buyer got the parts; the sale is final once the return window passes.
  Future<Order> confirmReceived(String subOrderId) => guard(() async {
    final row = await _client.rpc<Json>('confirm_received', params: {'p_sub_order_id': subOrderId});
    return Order.fromJson(row);
  });

  /// Asks to return a whole sub-order within the return window; an admin decides.
  Future<Order> requestReturn(String subOrderId, String reason) => guard(() async {
    final row = await _client.rpc<Json>(
      'request_return',
      params: {'p_sub_order_id': subOrderId, 'p_reason': reason},
    );
    return Order.fromJson(row);
  });

  /// The account's cart (`cart_items`), each line with its listing and part, or its
  /// photo-request offer, so the app can show it after signing in on another phone.
  Future<List<Json>> accountCart() => guard(() async {
    final rows = await _client
        .from('cart_items')
        .select(
          'listing_id, offer_id, tint_shop_id, tint, qty, seen_price_sdg, '
          'listing:listings(id, shop_id, condition, warranty_days, listing_images(base_key), '
          'part:parts(id, category_id, name_ar, name_en, installable)), '
          'offer:part_offers(id, shop_id, title_ar, title_en, condition, warranty_days, image_key, '
          'request:part_requests(category_id))',
        )
        .order('created_at');
    return rows.cast<Json>();
  });

  /// The Bankak account refunds are sent to.
  Future<void> setRefundAccount(String account) =>
      guard(() => _client.rpc<void>('set_refund_account', params: {'p_account': account}));
}
