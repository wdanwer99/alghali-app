import 'package:alghali_core/alghali_core.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'session.dart';

/// A sub-order as the shop sees it: who bought it and how it leaves the shop.
@immutable
class ShopOrder {
  const ShopOrder({
    required this.sub,
    required this.ref,
    required this.buyerName,
    required this.method,
    required this.paymentStatus,
    required this.placedAt,
    this.technicianId,
    this.fittingAt,
    this.deliveryTo,
  });

  final SubOrder sub;
  final String ref;
  final String buyerName;
  final PaymentMethod method;
  final PaymentStatus paymentStatus;
  final DateTime placedAt;
  final String? technicianId;
  final DateTime? fittingAt;
  final Address? deliveryTo;

  String get id => sub.id;

  /// Confirmed but not yet accepted by the shop (D-020: a timestamp, not a status).
  bool get isNew => sub.status == SubOrderStatus.confirmed && sub.acknowledgedAt == null;
  bool get isPreparing => sub.status == SubOrderStatus.confirmed && sub.acknowledgedAt != null;
  bool get isReady => sub.status == SubOrderStatus.ready;
  bool get isDone => const {
    SubOrderStatus.pickedUp,
    SubOrderStatus.delivered,
    SubOrderStatus.handedToTechnician,
    SubOrderStatus.completed,
    SubOrderStatus.cancelled,
    SubOrderStatus.rejectedByShop,
    SubOrderStatus.outForDelivery,
  }.contains(sub.status);

  ShopOrder copyWith(SubOrder sub) => ShopOrder(
    sub: sub,
    ref: ref,
    buyerName: buyerName,
    method: method,
    paymentStatus: paymentStatus,
    placedAt: placedAt,
    technicianId: technicianId,
    fittingAt: fittingAt,
    deliveryTo: deliveryTo,
  );
}

OrderItem _item(CatalogueData c, String listingId, int qty) {
  final l = c.listing(listingId);
  final p = c.part(l.partId);
  return OrderItem(
    listingId: l.id,
    partId: p.id,
    title: p.name,
    condition: l.condition,
    unitPriceSdg: l.priceSdg,
    qty: qty,
    warrantyDays: l.warrantyDays,
  );
}

String _ref(String seven) => '$seven${luhnCheckDigit(seven)}';

List<ShopOrder> demoShopOrders(CatalogueData c, DateTime now) {
  DateTime ago(int minutes) => now.subtract(Duration(minutes: minutes));
  SubOrder sub(
    String id,
    SubOrderStatus status,
    FulfilmentType f,
    List<OrderItem> items, {
    DateTime? ack,
    int delivery = 0,
    required DateTime at,
  }) => SubOrder(
    id: id,
    shopId: 'sh-nour',
    status: status,
    fulfilment: f,
    items: items,
    deliveryFeeSdg: delivery,
    acknowledgedAt: ack,
    events: [StatusEvent(status, at)],
  );
  final tomorrow4pm = khartoumDay(now)
      .add(const Duration(days: 1, hours: 16))
      .subtract(khartoumOffset);
  return [
    ShopOrder(
      sub: sub('so-901', SubOrderStatus.confirmed, FulfilmentType.toTechnician, [
        _item(c, 'ls-04', 1),
      ], at: ago(6)),
      ref: _ref('6604217'),
      buyerName: 'أحمد م.',
      method: PaymentMethod.bankak,
      paymentStatus: PaymentStatus.confirmed,
      placedAt: ago(19),
      technicianId: 'tc-osman',
      fittingAt: tomorrow4pm,
    ),
    ShopOrder(
      sub: sub(
        'so-902',
        SubOrderStatus.confirmed,
        FulfilmentType.pickup,
        [_item(c, 'ls-01', 1)],
        ack: ago(40),
        at: ago(45),
      ),
      ref: _ref('6603985'),
      buyerName: 'سارة ع.',
      method: PaymentMethod.cash,
      paymentStatus: PaymentStatus.due,
      placedAt: ago(45),
    ),
    ShopOrder(
      sub: sub(
        'so-903',
        SubOrderStatus.ready,
        FulfilmentType.delivery,
        [_item(c, 'ls-31', 1)],
        ack: ago(150),
        delivery: 3000,
        at: ago(60),
      ),
      ref: _ref('6603551'),
      buyerName: 'عثمان ب.',
      method: PaymentMethod.bankak,
      paymentStatus: PaymentStatus.confirmed,
      placedAt: ago(180),
      deliveryTo: const Address(
        id: 'ad-x',
        label: LocalizedText('المنزل', 'Home'),
        description: LocalizedText('الرياض، شارع 21', 'Riyadh, Street 21'),
        distanceKm: 2.9,
      ),
    ),
    ShopOrder(
      sub: sub('so-904', SubOrderStatus.pendingPayment, FulfilmentType.pickup, [
        _item(c, 'ls-24', 2),
      ], at: ago(12)),
      ref: _ref('6604302'),
      buyerName: 'منى ح.',
      method: PaymentMethod.bankak,
      paymentStatus: PaymentStatus.awaitingTransfer,
      placedAt: ago(12),
    ),
    ShopOrder(
      sub: sub(
        'so-905',
        SubOrderStatus.handedToTechnician,
        FulfilmentType.toTechnician,
        [_item(c, 'ls-11', 1)],
        ack: ago(300),
        at: ago(200),
      ),
      ref: _ref('6602877'),
      buyerName: 'خالد س.',
      method: PaymentMethod.bankak,
      paymentStatus: PaymentStatus.confirmed,
      placedAt: ago(320),
      technicianId: 'tc-tayeb',
      fittingAt: ago(120),
    ),
    ShopOrder(
      sub: sub(
        'so-906',
        SubOrderStatus.completed,
        FulfilmentType.pickup,
        [_item(c, 'ls-08', 2)],
        ack: ago(1500),
        at: ago(1400),
      ),
      ref: _ref('6601790'),
      buyerName: 'ياسر م.',
      method: PaymentMethod.bankak,
      paymentStatus: PaymentStatus.confirmed,
      placedAt: ago(1560),
    ),
  ];
}

/// The shop's orders. Demo: changes stay in memory; in M4 each action calls
/// `shop_ack_suborder`, `shop_mark_ready`, `shop_hand_over` and so on.
class ShopOrdersController extends Notifier<List<ShopOrder>> {
  @override
  List<ShopOrder> build() =>
      demoShopOrders(ref.watch(catalogueProvider), ref.read(clockProvider)());

  DateTime get _now => ref.read(clockProvider)();

  ShopOrder? byId(String id) => state.where((o) => o.id == id).firstOrNull;

  void accept(String id) => _update(id, (s) => s.copyWith(acknowledgedAt: _now));

  void reject(String id) =>
      _update(id, (s) => s.copyWith(status: SubOrderStatus.rejectedByShop, at: _now));

  void markReady(String id) =>
      _update(id, (s) => s.copyWith(status: SubOrderStatus.ready, at: _now));

  void handOver(String id) => _update(
    id,
    (s) => s.copyWith(
      at: _now,
      status: switch (s.fulfilment) {
        FulfilmentType.pickup => SubOrderStatus.pickedUp,
        FulfilmentType.delivery => SubOrderStatus.outForDelivery,
        FulfilmentType.toTechnician => SubOrderStatus.handedToTechnician,
      },
    ),
  );

  void markDelivered(String id) =>
      _update(id, (s) => s.copyWith(status: SubOrderStatus.delivered, at: _now));

  /// Demo only: a buyer pays for a new order.
  void demoNewOrder() {
    final now = _now;
    final c = ref.read(catalogueProvider);
    final n = state.length;
    state = [
      ShopOrder(
        sub: SubOrder(
          id: 'so-${now.microsecondsSinceEpoch}',
          shopId: 'sh-nour',
          status: SubOrderStatus.confirmed,
          fulfilment: FulfilmentType.pickup,
          items: [_item(c, n.isEven ? 'ls-04' : 'ls-34', 1)],
          events: [StatusEvent(SubOrderStatus.confirmed, now)],
        ),
        ref: newOrderRef(),
        buyerName: n.isEven ? 'هبة ي.' : 'Tariq A.',
        method: PaymentMethod.bankak,
        paymentStatus: PaymentStatus.confirmed,
        placedAt: now,
      ),
      ...state,
    ];
  }

  void _update(String id, SubOrder Function(SubOrder) change) =>
      state = [for (final o in state) o.id == id ? o.copyWith(change(o.sub)) : o];
}

final shopOrdersProvider = NotifierProvider<ShopOrdersController, List<ShopOrder>>(
  ShopOrdersController.new,
);

/// One of the shop's listings, as editable stock.
@immutable
class StockItem {
  const StockItem({
    required this.id,
    required this.title,
    required this.categoryId,
    required this.condition,
    required this.priceSdg,
    required this.qty,
    this.warrantyDays = 0,
    this.visible = true,
    this.draft = false,
  });

  final String id;
  final LocalizedText title;
  final String categoryId;
  final ListingCondition condition;
  final int priceSdg;
  final int qty;
  final int warrantyDays;
  final bool visible;
  final bool draft;

  static const lowAt = 5;
  bool get isLow => qty > 0 && qty <= lowAt;

  StockItem copyWith({int? priceSdg, int? qty, bool? visible}) => StockItem(
    id: id,
    title: title,
    categoryId: categoryId,
    condition: condition,
    priceSdg: priceSdg ?? this.priceSdg,
    qty: qty ?? this.qty,
    warrantyDays: warrantyDays,
    visible: visible ?? this.visible,
    draft: draft,
  );
}

class StockController extends Notifier<List<StockItem>> {
  @override
  List<StockItem> build() {
    final c = ref.watch(catalogueProvider);
    final shopId = ref.watch(partnerSessionProvider.select((s) => s.shopId));
    return [
      for (final l in c.shopListings(shopId))
        StockItem(
          id: l.id,
          title: c.part(l.partId).name,
          categoryId: c.part(l.partId).categoryId,
          condition: l.condition,
          priceSdg: l.priceSdg,
          qty: l.id == 'ls-11' ? 2 : l.stockQty,
          warrantyDays: l.warrantyDays,
        ),
      const StockItem(
        id: 'ls-draft-1',
        title: LocalizedText('حساس حرارة المحرك', 'Engine temperature sensor'),
        categoryId: 'cat-electrical',
        condition: ListingCondition.newAftermarket,
        priceSdg: 18000,
        qty: 6,
        visible: false,
        draft: true,
      ),
    ];
  }

  void update(String id, {required int priceSdg, required int qty, required bool visible}) =>
      state = [
        for (final s in state)
          s.id == id ? s.copyWith(priceSdg: priceSdg, qty: qty, visible: visible) : s,
      ];

  /// Bulk price change by [percent] (e.g. +10 or −5), rounded to the nearest 500 SDG.
  int bulkPercent(Set<String> ids, int percent) {
    state = [
      for (final s in state)
        ids.contains(s.id)
            ? s.copyWith(priceSdg: ((s.priceSdg * (100 + percent) / 100) / 500).round() * 500)
            : s,
    ];
    return ids.length;
  }

  void add(StockItem item) => state = [item, ...state];
}

final stockProvider = NotifierProvider<StockController, List<StockItem>>(StockController.new);

/// A buyer's photo request as the shop sees it.
@immutable
class QuoteRequest {
  const QuoteRequest({
    required this.request,
    required this.buyerName,
    required this.otherOffers,
    this.myOfferSdg,
  });

  final PartRequest request;
  final String buyerName;
  final int otherOffers;
  final int? myOfferSdg;
}

class QuotesController extends Notifier<List<QuoteRequest>> {
  @override
  List<QuoteRequest> build() {
    final now = ref.read(clockProvider)();
    PartRequest req(String id, String note, String? variant, int hoursLeft, int photos) =>
        PartRequest(
          id: id,
          note: note,
          status: RequestStatus.open,
          createdAt: now.subtract(Duration(hours: 24 - hoursLeft)),
          expiresAt: now.add(Duration(hours: hoursLeft)),
          offers: const [],
          variantId: variant,
          photoCount: photos,
        );
    return [
      QuoteRequest(
        request: req('rq-501', 'مرآة جانبية يسار مع إشارة', 'v-hilux-16p', 18, 2),
        buyerName: 'عمر ط.',
        otherOffers: 1,
      ),
      QuoteRequest(
        request: req('rq-502', 'لمبة سقف داخلية LED', 'v-corolla-14', 5, 1),
        buyerName: 'ريم أ.',
        otherOffers: 0,
      ),
      QuoteRequest(
        request: req('rq-503', 'بوري أصلي لهايس', 'v-hiace-05', 9, 1),
        buyerName: 'الطيب س.',
        otherOffers: 3,
        myOfferSdg: 20000,
      ),
    ];
  }

  void sendOffer(String requestId, int priceSdg) => state = [
    for (final q in state)
      q.request.id == requestId
          ? QuoteRequest(
              request: q.request,
              buyerName: q.buyerName,
              otherOffers: q.otherOffers,
              myOfferSdg: priceSdg,
            )
          : q,
  ];

  /// Demo only: a buyer sends a new photo request.
  void demoNew() {
    final now = ref.read(clockProvider)();
    state = [
      QuoteRequest(
        request: PartRequest(
          id: 'rq-${now.microsecondsSinceEpoch}',
          note: 'فيوز 30 أمبير (طقم)',
          status: RequestStatus.open,
          createdAt: now,
          expiresAt: now.add(const Duration(hours: 24)),
          offers: const [],
          variantId: 'v-accent-11',
        ),
        buyerName: 'Nada K.',
        otherOffers: 0,
      ),
      ...state,
    ];
  }
}

final quotesProvider = NotifierProvider<QuotesController, List<QuoteRequest>>(QuotesController.new);

class ShopOpenController extends Notifier<bool> {
  @override
  bool build() => true;

  void set(bool open) => state = open;
}

final shopOpenProvider = NotifierProvider<ShopOpenController, bool>(ShopOpenController.new);

@immutable
class ShopMoney {
  const ShopMoney({
    required this.balanceSdg,
    required this.nextPayout,
    required this.lines,
    required this.payouts,
  });

  /// Positive: the platform owes the shop.
  final int balanceSdg;
  final DateTime nextPayout;
  final List<LedgerLine> lines;
  final List<Payout> payouts;
}

/// Next Sunday (payout_schedule weekday 0) at noon Khartoum time.
DateTime nextSunday(DateTime now) {
  var d = khartoumDay(now).add(const Duration(days: 1));
  while (d.weekday != DateTime.sunday) {
    d = d.add(const Duration(days: 1));
  }
  return d.add(const Duration(hours: 10));
}

final shopMoneyProvider = Provider<ShopMoney>((ref) {
  final now = ref.watch(clockProvider)();
  DateTime ago(int h) => now.subtract(Duration(hours: h));
  // Since the last payout: two Bankak sales and one cash sale the shop
  // collected itself (so it owes that sale's commission). Sum = balance.
  final a = _ref('6601790');
  final b = _ref('6601422');
  final c = _ref('6601108');
  final lines = [
    LedgerLine(id: 'lg-1', kind: LedgerKind.sale, amountSdg: 12000, at: ago(20), ref: a),
    LedgerLine(id: 'lg-2', kind: LedgerKind.commission, amountSdg: -600, at: ago(20), ref: a),
    LedgerLine(id: 'lg-3', kind: LedgerKind.sale, amountSdg: 145000, at: ago(44), ref: b),
    LedgerLine(id: 'lg-4', kind: LedgerKind.commission, amountSdg: -7250, at: ago(44), ref: b),
    LedgerLine(id: 'lg-5', kind: LedgerKind.cashCollected, amountSdg: -45000, at: ago(50), ref: c),
    LedgerLine(id: 'lg-6', kind: LedgerKind.sale, amountSdg: 45000, at: ago(50), ref: c),
    LedgerLine(id: 'lg-7', kind: LedgerKind.commission, amountSdg: -2250, at: ago(50), ref: c),
    LedgerLine(id: 'lg-8', kind: LedgerKind.payout, amountSdg: -310500, at: ago(72)),
  ];
  return ShopMoney(
    balanceSdg: lines
        .where((l) => l.kind != LedgerKind.payout)
        .fold(0, (sum, l) => sum + l.amountSdg),
    nextPayout: nextSunday(now),
    lines: lines,
    payouts: [
      Payout(
        id: 'po-3',
        from: ago(24 * 10),
        to: ago(24 * 3),
        amountSdg: 310500,
        status: PayoutStatus.paid,
        paidAt: ago(72),
      ),
      Payout(
        id: 'po-2',
        from: ago(24 * 17),
        to: ago(24 * 10),
        amountSdg: 268000,
        status: PayoutStatus.paid,
        paidAt: ago(24 * 10),
      ),
    ],
  );
});

class StaffController extends Notifier<List<StaffMember>> {
  @override
  List<StaffMember> build() {
    final now = ref.read(clockProvider)();
    final session = ref.watch(partnerSessionProvider);
    return [
      StaffMember(
        id: 'st-1',
        name: session.name ?? 'Mohamed',
        email: session.email ?? '',
        role: StaffRole.owner,
        lastActive: now,
      ),
      StaffMember(
        id: 'st-2',
        name: 'مجدي عبدالله',
        email: 'magdi@example.com',
        role: StaffRole.staff,
        lastActive: now.subtract(const Duration(hours: 2)),
      ),
    ];
  }

  void invite(String email) => state = [
    ...state,
    StaffMember(
      id: 'st-${state.length + 1}',
      name: email.split('@').first,
      email: email,
      role: StaffRole.staff,
      lastActive: ref.read(clockProvider)(),
    ),
  ];
}

final staffProvider = NotifierProvider<StaffController, List<StaffMember>>(StaffController.new);

/// Sales for the last 7 days (closed Fridays sell nothing), oldest first.
final weekSalesProvider = Provider<List<SalesDay>>((ref) {
  final now = ref.watch(clockProvider)();
  const amounts = [86000, 132500, 74000, 158000, 121000, 97500, 64500];
  const orders = [5, 8, 4, 9, 7, 6, 3];
  final today = khartoumDay(now);
  return [
    for (var i = 0; i < 7; i++)
      () {
        final day = today.subtract(Duration(days: 6 - i));
        final closed = day.weekday == DateTime.friday;
        return SalesDay(day, closed ? 0 : amounts[i], closed ? 0 : orders[i]);
      }(),
  ];
});
