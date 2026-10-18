import 'dart:async';
import 'dart:typed_data';

import 'package:alghali_core/alghali_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'outbox.dart';
import 'session.dart';

// ----------------------------------------------------------------------------- the shop

/// The shop whose screens are open, as its members see it (also while its application
/// is waiting).
class MyShopController extends AsyncNotifier<Shop?> with CachedList<Shop?> {
  @override
  Future<Shop?> build() async {
    final shopId = ref.watch(currentShopIdProvider);
    if (shopId == null) return null;
    return load();
  }

  @override
  Future<Shop?> fetch() async {
    final shopId = ref.read(currentShopIdProvider);
    return shopId == null ? null : ref.read(shopRepositoryProvider).detail(shopId);
  }

  /// "Closed today" until midnight, or open again (D-119). Needs a connection.
  Future<void> setOpen(bool open) async {
    final shopId = ref.read(currentShopIdProvider);
    if (shopId == null) return;
    final until = open ? null : endOfKhartoumDay(ref.read(clockProvider)());
    final shop = await ref.read(shopRepositoryProvider).setClosed(shopId, until);
    if (ref.mounted) state = AsyncData(shop);
  }

  /// Saves the keys in [patch] (`shop_update_profile`); owners only.
  Future<void> updateProfile(Json patch) async {
    final shopId = ref.read(currentShopIdProvider);
    if (shopId == null) return;
    final shop = await ref.read(shopRepositoryProvider).updateProfile(shopId, patch);
    if (ref.mounted) state = AsyncData(shop);
  }
}

final myShopProvider = AsyncNotifierProvider<MyShopController, Shop?>(MyShopController.new);

/// The shop's window-tint offer (D-149). Saving needs a connection.
class ShopTintController extends AsyncNotifier<ShopTintSettings?>
    with CachedList<ShopTintSettings?> {
  @override
  Future<ShopTintSettings?> build() async {
    if (ref.watch(currentShopIdProvider) == null) return null;
    return load();
  }

  @override
  Future<ShopTintSettings?> fetch() async {
    final shopId = ref.read(currentShopIdProvider);
    return shopId == null ? null : ref.read(shopRepositoryProvider).tintSettings(shopId);
  }

  Future<void> save({
    required bool active,
    required Set<int> darkness,
    required Set<TintColour> colours,
    required Map<(TintCarSize, TintItem), int> prices,
  }) async {
    final shopId = ref.read(currentShopIdProvider);
    if (shopId == null) return;
    final saved = await ref
        .read(shopRepositoryProvider)
        .setTint(shopId, active: active, darkness: darkness, colours: colours, prices: prices);
    if (ref.mounted) state = AsyncData(saved);
  }
}

final shopTintProvider = AsyncNotifierProvider<ShopTintController, ShopTintSettings?>(
  ShopTintController.new,
);

/// Whether the shop shows as open to buyers right now: inside its hours and not closed
/// for the day. A shop with no hours set counts as open.
bool shopOpenNow(Shop shop, DateTime now) {
  final closed = shop.closedUntil;
  if (closed != null && closed.isAfter(now)) return false;
  if (shop.openingHours.isEmpty) return true;
  final k = toKhartoum(now);
  final minute = k.hour * 60 + k.minute;
  return (shop.openingHours[k.weekday % 7] ?? const []).any((w) => minute >= w.$1 && minute < w.$2);
}

// ---------------------------------------------------------------------------- orders

/// Where a sub-order is, in the shop's terms.
extension ShopOrderStage on ShopSubOrder {
  SubOrderStatus get status => subOrder.status;
  String get id => subOrder.id;

  /// Paid (or a cash order) and not accepted yet (D-020: a time stamp, not a status).
  bool get isNew => status == SubOrderStatus.confirmed && subOrder.acknowledgedAt == null;
  bool get isPreparing => status == SubOrderStatus.confirmed && subOrder.acknowledgedAt != null;
  bool get isReady => status == SubOrderStatus.ready;
  bool get isDone => !isNew && !isPreparing && !isReady;

  /// The shop takes cash for it (from the buyer, or the technician who collects it).
  bool get cashDue => paymentStatus == PaymentStatus.due;

  /// What the shop is paid for it once the commission is taken (the delivery fee is
  /// the shop's).
  int get shopGetsSdg => subOrder.itemsSdg - commissionSdg + subOrder.deliveryFeeSdg;
}

/// The shop's orders, newest first. Each step is checked by the server at once.
class ShopOrdersController extends AsyncNotifier<List<ShopSubOrder>>
    with CachedList<List<ShopSubOrder>> {
  @override
  Future<List<ShopSubOrder>> build() async {
    if (ref.watch(currentShopIdProvider) == null) return const [];
    return load();
  }

  @override
  Future<List<ShopSubOrder>> fetch() async {
    final shopId = ref.read(currentShopIdProvider);
    if (shopId == null) return const [];
    return ref.read(shopRepositoryProvider).orders(shopId, limit: 100);
  }

  ShopRepository get _repo => ref.read(shopRepositoryProvider);

  Future<void> accept(String id) => _act(_repo.acknowledge(id));
  Future<void> reject(String id, String reason) => _act(_repo.reject(id, reason));
  Future<void> markReady(String id) => _act(_repo.markReady(id));
  Future<void> handOver(String id) => _act(_repo.handOver(id));
  Future<void> markDelivered(String id) => _act(_repo.markDelivered(id));

  Future<void> _act(Future<ShopSubOrder> call) async {
    final updated = await call;
    if (!ref.mounted) return;
    final list = state.value ?? const <ShopSubOrder>[];
    state = AsyncData([for (final o in list) o.id == updated.id ? updated : o]);
    // The money and the dashboard follow the order.
    ref.invalidate(shopInsightsProvider);
    ref.invalidate(shopStatementProvider);
  }
}

final shopOrdersProvider = AsyncNotifierProvider<ShopOrdersController, List<ShopSubOrder>>(
  ShopOrdersController.new,
);

final shopOrderProvider = Provider.family<ShopSubOrder?, String>(
  (ref, id) => ref.watch(shopOrdersProvider).value?.where((o) => o.id == id).firstOrNull,
);

// ----------------------------------------------------------------------------- stock

/// A quick listing waiting in the outbox (shown in the stock list until it is sent).
ShopListing _queuedListing(Json payload) {
  final draft = ListingDraft.fromParams(payload['params'] as Json);
  final name = draft.newPart?.nameAr ?? payload['title'] as String? ?? '';
  return ShopListing(
    id: payload['local_id'] as String,
    version: 0,
    partId: draft.partId ?? '',
    partName: LocalizedText(name, draft.newPart?.nameEn ?? name),
    categoryId: draft.newPart?.categoryId ?? payload['category_id'] as String? ?? '',
    condition: draft.condition,
    priceSdg: draft.priceSdg,
    priceOnRequest: draft.priceOnRequest,
    stockQty: draft.stockQty,
    availableQty: draft.stockQty,
    warrantyDays: draft.warrantyDays,
    active: draft.active,
    ownPart: draft.partId == null,
    modelIds: {...?draft.newPart?.modelIds},
    images: const [],
  );
}

/// The shop's listings. Edits show at once and go out through the outbox (D-122); new
/// listings made offline show as waiting until they are sent.
class StockController extends AsyncNotifier<List<ShopListing>> with CachedList<List<ShopListing>> {
  @override
  Future<List<ShopListing>> build() async {
    final shopId = ref.watch(currentShopIdProvider);
    if (shopId == null) return const [];
    final sub = ref.watch(outboxResultsProvider).listen((r) {
      if (r.payload['shop_id'] != shopId) return;
      if (r.operation != PartnerOps.stockEdit && r.operation != PartnerOps.listingCreate) {
        return;
      }
      ref.read(stockPendingProvider.notifier).done(r.payload);
      unawaited(refresh());
    });
    ref.onDispose(sub.cancel);
    return load();
  }

  @override
  Future<List<ShopListing>> fetch() async {
    final shopId = ref.read(currentShopIdProvider);
    if (shopId == null) return const [];
    final listings = await ref.read(shopRepositoryProvider).listings(shopId, limit: 500);
    final queued = await ref.read(outboxProvider)?.queued() ?? const [];
    final waiting = [
      for (final q in queued)
        if (q.operation == PartnerOps.listingCreate && q.payload['shop_id'] == shopId)
          _queuedListing(q.payload),
    ];
    final pending = ref.read(stockPendingProvider.notifier);
    for (final q in queued) {
      if (q.payload['shop_id'] == shopId) pending.add(q.payload);
    }
    return [...waiting, ...listings];
  }

  String? get _shopId => ref.read(currentShopIdProvider);

  /// Changes price, stock or visibility. Nothing is sent when nothing changed.
  Future<void> edit(ShopListing l, {int? priceSdg, int? stockQty, bool? active}) async {
    final item = <String, Object?>{
      'listing_id': l.id,
      'version': l.version,
      if (priceSdg != null && priceSdg != l.priceSdg) 'price_sdg': priceSdg,
      if (stockQty != null && stockQty != l.stockQty) 'stock_qty': stockQty,
      if (active != null && active != l.active) 'is_active': active,
    };
    if (item.length == 2) return;
    await _queueEdits([item]);
  }

  /// Raises or lowers the price of [ids] by [percent], rounded to the nearest 500 SDG.
  /// Returns how many changed.
  Future<int> bulkPercent(Set<String> ids, int percent) async {
    final items = [
      for (final l in state.value ?? const <ShopListing>[])
        if (ids.contains(l.id) && l.priceSdg != null)
          if ((l.priceSdg! * (100 + percent) / 100 / 500).round() * 500 case final price
              when price > 0 && price != l.priceSdg)
            {'listing_id': l.id, 'version': l.version, 'price_sdg': price},
    ];
    if (items.isEmpty) return 0;
    await _queueEdits(items);
    return items.length;
  }

  Future<void> _queueEdits(List<Json> items) async {
    final shopId = _shopId;
    if (shopId == null) return;
    final byId = {for (final i in items) i['listing_id'] as String: i};
    state = AsyncData([
      for (final l in state.value ?? const <ShopListing>[])
        if (byId[l.id] case final i?)
          l.copyWith(
            priceSdg: i['price_sdg'] as int?,
            stockQty: i['stock_qty'] as int?,
            active: i['is_active'] as bool?,
            version: l.version + 1,
          )
        else
          l,
    ]);
    final payload = {'shop_id': shopId, 'items': items};
    ref.read(stockPendingProvider.notifier).add(payload);
    await queue(ref, PartnerOps.stockEdit, payload);
  }

  /// A quick listing (D-122): kept on the phone with its photo and sent when online.
  /// [draft] hidden from buyers until published.
  Future<void> create(ListingDraft listing, {Uint8List? photo}) async {
    final shopId = _shopId;
    if (shopId == null) return;
    final localId = newId();
    final path = photo == null
        ? null
        : await ref.read(photoStoreProvider).keep(photo, '$localId.jpg');
    final payload = <String, Object?>{
      'shop_id': shopId,
      'local_id': localId,
      'params': listing.toParams(shopId),
      'photo_path': ?path,
    };
    state = AsyncData([_queuedListing(payload), ...?state.value]);
    ref.read(stockPendingProvider.notifier).add(payload);
    await queue(ref, PartnerOps.listingCreate, payload);
  }
}

final stockProvider = AsyncNotifierProvider<StockController, List<ShopListing>>(
  StockController.new,
);

/// Listings with a change still waiting in the outbox (shown with a clock).
class StockPending extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  static Iterable<String> _ids(Json payload) => [
    if (payload['local_id'] case final String id) id,
    for (final i in [...?(payload['items'] as List?)?.cast<Json>()]) i['listing_id'] as String,
  ];

  void add(Json payload) => state = {...state, ..._ids(payload)};
  void done(Json payload) => state = {...state}..removeAll(_ids(payload));
}

final stockPendingProvider = NotifierProvider<StockPending, Set<String>>(StockPending.new);

/// Catalogue parts and the shop's own while typing a quick listing (needs a connection;
/// offline the typed name makes a new part).
final partSuggestionsProvider = FutureProvider.autoDispose
    .family<List<PartSuggestion>, ({String query, String? categoryId})>((ref, q) async {
      final shopId = ref.watch(currentShopIdProvider);
      if (shopId == null || q.query.trim().length < 2) return const [];
      try {
        return await ref
            .read(shopRepositoryProvider)
            .suggestParts(shopId, q.query.trim(), categoryId: q.categoryId);
      } on BackendException {
        return const [];
      }
    });

// --------------------------------------------------------------------- photo requests

/// Buyers' open photo requests in the shop's specialities (`shop_open_requests`).
class QuotesController extends AsyncNotifier<List<OpenRequest>> with CachedList<List<OpenRequest>> {
  @override
  Future<List<OpenRequest>> build() async {
    if (ref.watch(currentShopIdProvider) == null) return const [];
    return load();
  }

  @override
  Future<List<OpenRequest>> fetch() async {
    final shopId = ref.read(currentShopIdProvider);
    if (shopId == null) return const [];
    return ref.read(requestsRepositoryProvider).openForShop(shopId);
  }

  /// Replaces the shop's earlier offer, if any. Needs a connection.
  Future<void> offer(String requestId, OfferDraft offer) async {
    final shopId = ref.read(currentShopIdProvider);
    if (shopId == null) return;
    await ref.read(requestsRepositoryProvider).makeOffer(shopId, requestId, offer);
    await refresh();
  }
}

final quotesProvider = AsyncNotifierProvider<QuotesController, List<OpenRequest>>(
  QuotesController.new,
);

/// Hour-long links to a request's photos, by key (keys joined with new lines).
final requestPhotoUrlsProvider = FutureProvider.autoDispose.family<Map<String, String>, String>((
  ref,
  keys,
) async {
  if (keys.isEmpty) return const {};
  try {
    return await ref.read(requestsRepositoryProvider).photoUrls(keys.split('\n'));
  } on BackendException {
    return const {};
  }
});

// ------------------------------------------------------------------------ money

/// The last 30 days of the shop's statement: sales, commission, cash, payouts.
class ShopStatementController extends AsyncNotifier<ShopStatement?>
    with CachedList<ShopStatement?> {
  @override
  Future<ShopStatement?> build() async {
    if (ref.watch(currentShopIdProvider) == null) return null;
    return load();
  }

  @override
  Future<ShopStatement?> fetch() async {
    final shopId = ref.read(currentShopIdProvider);
    return shopId == null ? null : ref.read(shopRepositoryProvider).statement(shopId);
  }
}

final shopStatementProvider = AsyncNotifierProvider<ShopStatementController, ShopStatement?>(
  ShopStatementController.new,
);

/// Sales per day for the week, best sellers and rating.
class ShopInsightsController extends AsyncNotifier<ShopInsights?> with CachedList<ShopInsights?> {
  @override
  Future<ShopInsights?> build() async {
    if (ref.watch(currentShopIdProvider) == null) return null;
    return load();
  }

  @override
  Future<ShopInsights?> fetch() async {
    final shopId = ref.read(currentShopIdProvider);
    return shopId == null ? null : ref.read(shopRepositoryProvider).insights(shopId);
  }
}

final shopInsightsProvider = AsyncNotifierProvider<ShopInsightsController, ShopInsights?>(
  ShopInsightsController.new,
);

/// Next Sunday (payout_schedule weekday 0) at noon Khartoum time.
DateTime nextSunday(DateTime now) {
  var d = khartoumDay(now).add(const Duration(days: 1));
  while (d.weekday != DateTime.sunday) {
    d = d.add(const Duration(days: 1));
  }
  return d.add(const Duration(hours: 10));
}

// ------------------------------------------------------------------------ staff

/// The shop's owner and staff. Colleagues sign up in the partner app first; the owner
/// then adds them by email.
class StaffController extends AsyncNotifier<List<StaffMember>> with CachedList<List<StaffMember>> {
  @override
  Future<List<StaffMember>> build() async {
    if (ref.watch(currentShopIdProvider) == null) return const [];
    return load();
  }

  @override
  Future<List<StaffMember>> fetch() async {
    final shopId = ref.read(currentShopIdProvider);
    if (shopId == null) return const [];
    return ref.read(shopRepositoryProvider).staff(shopId);
  }

  Future<void> add(String email) async {
    await ref.read(shopRepositoryProvider).addStaff(ref.read(currentShopIdProvider)!, email);
    await refresh();
  }

  Future<void> remove(String userId) async {
    await ref.read(shopRepositoryProvider).removeStaff(ref.read(currentShopIdProvider)!, userId);
    await refresh();
  }
}

final staffProvider = AsyncNotifierProvider<StaffController, List<StaffMember>>(
  StaffController.new,
);
