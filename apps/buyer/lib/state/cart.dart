import 'dart:async';
import 'dart:convert';

import 'package:alghali_core/alghali_core.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'outbox.dart';
import 'session.dart';

/// The fitting attached to the cart: a time held with a technician for some of its parts
/// (D-111: one fitting per order, covering one or more parts). Checkout pays for it with
/// the parts; the hold lapses after `slot_hold_minutes` (D-022).
@immutable
class FittingDraft {
  const FittingDraft({required this.booking, required this.lineIds, required this.anyTechnician});

  /// The HELD booking `create_booking_hold` returned.
  final Booking booking;

  /// The cart lines being fitted.
  final Set<String> lineIds;

  /// The buyer chose "any available technician".
  final bool anyTechnician;

  BookingPlace get place => booking.place;
  DateTime get start => booking.startAt;
  int get labourSdg => booking.labourSdg;
  int get travelFeeSdg => booking.travelFeeSdg;
  int get bookingFeeSdg => booking.bookingFeeSdg;
  DateTime heldUntil(DateTime now) => booking.holdExpiresAt ?? now;
}

/// A cart line: a shop listing or a photo-request offer.
@immutable
class CartLine {
  const CartLine({
    required this.id,
    required this.shopId,
    required this.categoryId,
    required this.title,
    required this.condition,
    required this.unitPriceSdg,
    required this.qty,
    this.listingId,
    this.offerId,
    this.partId,
    this.warrantyDays = 0,
    this.installable = true,
    this.imageKey,
  });

  factory CartLine.fromJson(Json j) => CartLine(
    id: j['id'] as String,
    shopId: j['shop_id'] as String,
    categoryId: j['category_id'] as String? ?? '',
    title: LocalizedText.fromJson(j, 'title'),
    condition: ListingCondition.fromCode(j['condition'] as String),
    unitPriceSdg: j['unit_price_sdg'] as int,
    qty: j['qty'] as int,
    listingId: j['listing_id'] as String?,
    offerId: j['offer_id'] as String?,
    partId: j['part_id'] as String?,
    warrantyDays: j['warranty_days'] as int? ?? 0,
    installable: j['installable'] as bool? ?? true,
    imageKey: j['image_key'] as String?,
  );

  final String id;
  final String shopId;
  final String categoryId;
  final LocalizedText title;
  final ListingCondition condition;

  /// Price when added (`cart_items.seen_price_sdg`); re-checked at checkout.
  final int unitPriceSdg;
  final int qty;
  final String? listingId;
  final String? offerId;
  final String? partId;
  final int warrantyDays;
  final bool installable;
  final String? imageKey;

  int get lineSdg => unitPriceSdg * qty;

  CheckoutLine get checkoutLine => listingId != null
      ? CheckoutLine.listing(listingId!, qty: qty, seenPriceSdg: unitPriceSdg)
      : CheckoutLine.offer(offerId!, seenPriceSdg: unitPriceSdg);

  FittingItem get fittingItem =>
      listingId != null ? FittingItem.listing(listingId!) : FittingItem.offer(offerId!);

  /// What the server copy of the line (`cart_items`) holds.
  Json get serverJson => {
    'listing_id': listingId,
    'offer_id': offerId,
    'qty': qty,
    'seen_price_sdg': unitPriceSdg,
  };

  Json toJson() => {
    'id': id,
    'shop_id': shopId,
    'category_id': categoryId,
    'title_ar': title.ar,
    'title_en': title.en,
    'condition': condition.code,
    'unit_price_sdg': unitPriceSdg,
    'qty': qty,
    'listing_id': listingId,
    'offer_id': offerId,
    'part_id': partId,
    'warranty_days': warrantyDays,
    'installable': installable,
    'image_key': imageKey,
  };

  CartLine copyWith({int? qty, int? unitPriceSdg}) => CartLine(
    id: id,
    shopId: shopId,
    categoryId: categoryId,
    title: title,
    condition: condition,
    unitPriceSdg: unitPriceSdg ?? this.unitPriceSdg,
    qty: qty ?? this.qty,
    listingId: listingId,
    offerId: offerId,
    partId: partId,
    warrantyDays: warrantyDays,
    installable: installable,
    imageKey: imageKey,
  );
}

@immutable
class CartState {
  const CartState({this.lines = const [], this.fitting});

  final List<CartLine> lines;
  final FittingDraft? fitting;

  bool fitted(String lineId) => fitting?.lineIds.contains(lineId) ?? false;
}

/// The cart, kept on the phone (works offline and for guests). Signed in, each change is
/// mirrored to `cart_items` through the outbox, and the account's cart is merged in at
/// sign-in (D-092).
class CartController extends Notifier<CartState> {
  static const _key = 'cart';

  @override
  CartState build() {
    ref.listen(sessionProvider.select((s) => s.userId), (prev, next) {
      if (next != null && prev == null) unawaited(_mergeAccountCart());
      if (next == null && prev != null) unawaited(_clearLocal());
    });
    final saved = ref.watch(sharedPreferencesProvider).getStringList(_key) ?? const <String>[];
    final lines = <CartLine>[];
    for (final row in saved) {
      try {
        lines.add(CartLine.fromJson(jsonDecode(row) as Json));
      } on Object {
        // A line saved by an older version: drop it.
      }
    }
    return CartState(lines: lines);
  }

  bool get _signedIn => ref.read(sessionProvider).signedIn;

  void addListing(Listing listing, Part part, {String? imageKey}) {
    final i = state.lines.indexWhere((l) => l.listingId == listing.id);
    if (i >= 0) {
      setQty(state.lines[i].id, state.lines[i].qty + 1);
      return;
    }
    _add(
      CartLine(
        id: newId(),
        shopId: listing.shopId,
        categoryId: part.categoryId,
        title: part.name,
        condition: listing.condition,
        unitPriceSdg: listing.priceSdg,
        qty: 1,
        listingId: listing.id,
        partId: part.id,
        warrantyDays: listing.warrantyDays,
        installable: part.installable,
        imageKey: imageKey ?? listing.imageKey,
      ),
    );
  }

  void addOffer(PartOffer offer, {required String categoryId}) {
    if (state.lines.any((l) => l.offerId == offer.id)) return;
    _add(
      CartLine(
        id: newId(),
        shopId: offer.shopId,
        categoryId: categoryId,
        title: offer.title,
        condition: offer.condition,
        unitPriceSdg: offer.priceSdg,
        qty: 1,
        offerId: offer.id,
        warrantyDays: offer.warrantyDays,
        imageKey: offer.imageKey,
      ),
    );
  }

  void _add(CartLine line) {
    _set(CartState(lines: [...state.lines, line], fitting: state.fitting));
    _mirror(line);
  }

  void setQty(String lineId, int qty) {
    final lines = [for (final l in state.lines) l.id == lineId ? l.copyWith(qty: qty) : l];
    _set(CartState(lines: lines, fitting: state.fitting));
    final line = lines.where((l) => l.id == lineId).firstOrNull;
    if (line != null) _mirror(line);
  }

  /// Removing a part that is being fitted drops the fitting too (its hold no longer
  /// matches the cart); returns true when that happened.
  bool remove(String lineId) {
    final line = state.lines.where((l) => l.id == lineId).firstOrNull;
    if (line == null) return false;
    final dropsFitting = state.fitted(lineId);
    if (dropsFitting) unawaited(releaseFitting());
    _set(
      CartState(
        lines: state.lines.where((l) => l.id != lineId).toList(),
        fitting: dropsFitting ? null : state.fitting,
      ),
    );
    if (_signedIn) {
      unawaited(
        queue(ref, BuyerOps.cartRemove, {'listing_id': line.listingId, 'offer_id': line.offerId}),
      );
    }
    return dropsFitting;
  }

  void attachFitting(FittingDraft draft) => state = CartState(lines: state.lines, fitting: draft);

  /// Drops the fitting and frees the technician's time.
  Future<void> releaseFitting() async {
    final f = state.fitting;
    if (f == null) return;
    state = CartState(lines: state.lines);
    try {
      await ref.read(bookingsRepositoryProvider).release(f.booking.id);
    } on BackendException {
      // The hold lapses on its own after a few minutes.
    }
  }

  /// Forgets the fitting without calling the server (checkout took it, or it lapsed).
  void dropFitting() => state = CartState(lines: state.lines);

  /// Applies what checkout or `cart_validate` found: new prices, less stock, lines gone.
  void applyChecks(List<CartCheck> checks) {
    final lines = <CartLine>[];
    for (final l in state.lines) {
      final c = checks
          .where((c) => c.listingId == l.listingId && c.offerId == l.offerId)
          .firstOrNull;
      if (c == null || c.ok) {
        lines.add(l);
      } else if (c.problem == CartProblem.priceChanged && c.priceSdg != null) {
        lines.add(l.copyWith(unitPriceSdg: c.priceSdg));
      } else if (c.problem == CartProblem.notEnoughStock && (c.availableQty ?? 0) > 0) {
        lines.add(l.copyWith(qty: c.availableQty));
      }
    }
    final keepFitting =
        state.fitting != null && state.fitting!.lineIds.every((id) => lines.any((l) => l.id == id));
    _set(CartState(lines: lines, fitting: keepFitting ? state.fitting : null));
    for (final l in lines) {
      _mirror(l);
    }
  }

  /// After checkout: these lines were bought (the server already emptied its copy).
  void removeBought(Iterable<String> lineIds) {
    final bought = lineIds.toSet();
    _set(CartState(lines: state.lines.where((l) => !bought.contains(l.id)).toList()));
  }

  void clear() => _set(const CartState());

  void _mirror(CartLine line) {
    if (_signedIn) unawaited(queue(ref, BuyerOps.cartPut, line.serverJson));
  }

  void _set(CartState s) {
    state = s;
    unawaited(
      ref.read(sharedPreferencesProvider).setStringList(_key, [
        for (final l in s.lines) jsonEncode(l.toJson()),
      ]),
    );
  }

  Future<void> _clearLocal() async {
    await releaseFitting();
    _set(const CartState());
  }

  /// Signing in: lines saved on the account join the phone's cart, and the phone's lines
  /// are saved to the account.
  Future<void> _mergeAccountCart() async {
    try {
      final rows = await ref.read(ordersRepositoryProvider).accountCart();
      final lines = [...state.lines];
      for (final r in rows) {
        final listing = r['listing'] as Json?;
        final offer = r['offer'] as Json?;
        if (lines.any((l) => l.listingId == r['listing_id'] && l.offerId == r['offer_id'])) {
          continue;
        }
        if (listing != null) {
          final part = listing['part'] as Json? ?? const {};
          lines.add(
            CartLine(
              id: newId(),
              shopId: listing['shop_id'] as String,
              categoryId: part['category_id'] as String? ?? '',
              title: LocalizedText.fromJson(part, 'name'),
              condition: ListingCondition.fromCode(listing['condition'] as String),
              unitPriceSdg: r['seen_price_sdg'] as int,
              qty: r['qty'] as int,
              listingId: listing['id'] as String,
              partId: part['id'] as String?,
              warrantyDays: listing['warranty_days'] as int? ?? 0,
              installable: part['installable'] as bool? ?? true,
              imageKey:
                  ([...?(listing['listing_images'] as List?)?.cast<Json>()]
                          .firstOrNull)?['base_key']
                      as String?,
            ),
          );
        } else if (offer != null) {
          lines.add(
            CartLine(
              id: newId(),
              shopId: offer['shop_id'] as String,
              categoryId: (offer['request'] as Json?)?['category_id'] as String? ?? '',
              title: LocalizedText.fromJson(offer, 'title'),
              condition: ListingCondition.fromCode(offer['condition'] as String),
              unitPriceSdg: r['seen_price_sdg'] as int,
              qty: 1,
              offerId: offer['id'] as String,
              warrantyDays: offer['warranty_days'] as int? ?? 0,
              imageKey: offer['image_key'] as String?,
            ),
          );
        }
      }
      final onAccount = {for (final r in rows) '${r['listing_id']}|${r['offer_id']}'};
      for (final l in state.lines) {
        if (!onAccount.contains('${l.listingId}|${l.offerId}')) _mirror(l);
      }
      _set(CartState(lines: lines, fitting: state.fitting));
    } on BackendException {
      // Offline: the phone's cart goes up with the next change.
    }
  }
}

final cartProvider = NotifierProvider<CartController, CartState>(CartController.new);

final cartCountProvider = Provider<int>(
  (ref) => ref.watch(cartProvider).lines.fold(0, (n, l) => n + l.qty),
);

/// Money in the cart before delivery (delivery is chosen at checkout).
@immutable
class CartTotals {
  const CartTotals({
    required this.partsSdg,
    required this.labourSdg,
    required this.travelSdg,
    required this.bookingFeeSdg,
  });

  final int partsSdg;
  final int labourSdg;
  final int travelSdg;
  final int bookingFeeSdg;

  int get totalSdg => partsSdg + labourSdg + travelSdg + bookingFeeSdg;
}

final cartTotalsProvider = Provider<CartTotals>((ref) {
  final cart = ref.watch(cartProvider);
  final f = cart.fitting;
  return CartTotals(
    partsSdg: cart.lines.fold(0, (s, l) => s + l.lineSdg),
    labourSdg: f?.labourSdg ?? 0,
    travelSdg: f?.travelFeeSdg ?? 0,
    bookingFeeSdg: f?.bookingFeeSdg ?? 0,
  );
});
