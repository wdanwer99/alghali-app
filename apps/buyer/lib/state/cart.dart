import 'package:alghali_core/alghali_core.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A held fitting slot attached to one cart line (installation per part).
@immutable
class FittingDraft {
  const FittingDraft({
    required this.place,
    required this.technicianId,
    required this.anyTechnician,
    required this.slot,
    required this.labourSdg,
    required this.travelFeeSdg,
    required this.heldUntil,
    this.address,
  });

  final BookingPlace place;

  /// The technician who holds the slot; for "any" it's the best one free then.
  final String technicianId;
  final bool anyTechnician;
  final Slot slot;
  final int labourSdg;
  final int travelFeeSdg;

  /// The HELD booking lapses at this time (D-022).
  final DateTime heldUntil;
  final Address? address;
}

/// A cart line: a shop listing or a photo-request offer, plus optional fitting.
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
    this.fitting,
  });

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
  final FittingDraft? fitting;

  int get lineSdg => unitPriceSdg * qty;

  CartLine copyWith({int? qty, FittingDraft? Function()? fitting}) => CartLine(
    id: id,
    shopId: shopId,
    categoryId: categoryId,
    title: title,
    condition: condition,
    unitPriceSdg: unitPriceSdg,
    qty: qty ?? this.qty,
    listingId: listingId,
    offerId: offerId,
    partId: partId,
    warrantyDays: warrantyDays,
    installable: installable,
    fitting: fitting == null ? this.fitting : fitting(),
  );
}

class CartController extends Notifier<List<CartLine>> {
  var _seq = 0;

  @override
  List<CartLine> build() => const [];

  void addListing(Listing listing, Part part) {
    final i = state.indexWhere((l) => l.listingId == listing.id);
    if (i >= 0) {
      setQty(state[i].id, state[i].qty + 1);
      return;
    }
    state = [
      ...state,
      CartLine(
        id: 'cl-${++_seq}',
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
      ),
    ];
  }

  void addOffer(PartOffer offer, {required String categoryId}) {
    if (state.any((l) => l.offerId == offer.id)) return;
    state = [
      ...state,
      CartLine(
        id: 'cl-${++_seq}',
        shopId: offer.shopId,
        categoryId: categoryId,
        title: offer.title,
        condition: offer.condition,
        unitPriceSdg: offer.priceSdg,
        qty: 1,
        offerId: offer.id,
        warrantyDays: offer.warrantyDays,
      ),
    ];
  }

  void setQty(String lineId, int qty) =>
      state = [for (final l in state) l.id == lineId ? l.copyWith(qty: qty) : l];

  void remove(String lineId) => state = state.where((l) => l.id != lineId).toList();

  void attachFitting(String lineId, FittingDraft draft) =>
      state = [for (final l in state) l.id == lineId ? l.copyWith(fitting: () => draft) : l];

  void removeFitting(String lineId) =>
      state = [for (final l in state) l.id == lineId ? l.copyWith(fitting: () => null) : l];

  void clear() => state = const [];
}

final cartProvider = NotifierProvider<CartController, List<CartLine>>(CartController.new);

final cartCountProvider = Provider<int>(
  (ref) => ref.watch(cartProvider).fold(0, (n, l) => n + l.qty),
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
  final lines = ref.watch(cartProvider);
  final fee = ref.watch(platformSettingsProvider).bookingFeeSdg;
  final fittings = [for (final l in lines) ?l.fitting];
  return CartTotals(
    partsSdg: lines.fold(0, (s, l) => s + l.lineSdg),
    labourSdg: fittings.fold(0, (s, f) => s + f.labourSdg),
    travelSdg: fittings.fold(0, (s, f) => s + f.travelFeeSdg),
    bookingFeeSdg: fee * fittings.length,
  );
});
