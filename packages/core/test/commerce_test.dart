import 'dart:convert';
import 'dart:typed_data';

import 'package:alghali_core/alghali_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/fake_server.dart';
import 'support/fixtures.dart';

List<Json> rows(String name) => (fixture(name)! as List).cast<Json>();

void main() {
  group('parsing M2 responses', () {
    test('orders read directly come with payments, sub-orders, items, events and returns', () {
      final orders = [for (final r in rows('orders_select')) Order.fromJson(r)];
      final returned = orders.firstWhere((o) => o.ref == '28743185');
      expect(returned.method, PaymentMethod.bankak);
      expect(returned.paymentStatus, PaymentStatus.confirmed);
      expect(returned.txnNo, '193843080');
      final sub = returned.subOrders.single;
      expect(sub.status, SubOrderStatus.returnRequested);
      expect(sub.events, hasLength(6));
      expect(sub.events.first.status, SubOrderStatus.pendingPayment);
      expect(sub.events.last.status, SubOrderStatus.returnRequested);
      expect(sub.returnRequest?.state, ReturnState.requested);
      expect(sub.returnRequest?.reason, isNotEmpty);
      expect(returned.totalSdg, rows('orders_select').first['total_sdg']);

      final cash = orders.firstWhere((o) => o.ref == '72420508');
      expect(cash.method, PaymentMethod.cash);
      expect(cash.paymentStatus, PaymentStatus.due);
      expect(cash.txnNo, isNull);
      expect(cash.payBy, cash.createdAt);

      final review = orders.firstWhere((o) => o.ref == '74242322');
      expect(review.paymentStatus, PaymentStatus.receiptSubmitted);
      expect(review.subOrders.single.status, SubOrderStatus.paymentReview);
      expect(review.subOrders.single.returnRequest, isNull);
    });

    test('order_json (checkout and order actions) has the same shape', () {
      final json = fixture('order_json')! as Json;
      final order = Order.fromJson(json);
      expect(order.ref, '29027703');
      expect(order.paymentStatus, PaymentStatus.due);
      final item = order.subOrders.single.items.single;
      expect(item.title.ar, 'لمبات إشارة خلفية (طقم 4)');
      expect(item.title.en, 'Rear indicator bulbs (set of 4)');
      expect(item.condition, ListingCondition.newAftermarket);
      expect(order.totalSdg, json['total_sdg']);
      expect(order.subOrders.single.events.single.status, SubOrderStatus.confirmed);
    });

    test('cart lines report problems and current prices', () {
      final ok = CartCheck.fromJson(rows('cart_validate').single);
      expect(ok.ok, isTrue);
      expect(ok.problem, isNull);
      expect(ok.priceSdg, 5500);
      expect(ok.availableQty, 12);
    });

    test('notifications become inbox items', () {
      final items = [for (final r in rows('notifications')) InboxItem.fromJson(r)];
      expect(items.first.code, 'ORDER_CANCELLED');
      expect(items.first.payload['ref'], '29027703');
      expect(items.every((i) => !i.read), isTrue);
    });

    test('a shop sees its sub-order with the buyer, payment and commission', () {
      final order = ShopSubOrder.fromJson(rows('shop_orders').single);
      expect(order.ref, '58156415');
      expect(order.buyerName, 'أحمد محمد');
      expect(order.buyerPhone, '+249912000001');
      expect(order.method, PaymentMethod.bankak);
      expect(order.paymentStatus, PaymentStatus.confirmed);
      expect(order.commissionSdg, 7250);
      expect(order.address, isNull);
      expect(order.subOrder.status, SubOrderStatus.completed);
      expect(order.subOrder.acknowledgedAt, isNotNull);
      expect(order.subOrder.events.map((e) => e.status), [
        SubOrderStatus.pendingPayment,
        SubOrderStatus.paymentReview,
        SubOrderStatus.confirmed,
        SubOrderStatus.ready,
        SubOrderStatus.pickedUp,
        SubOrderStatus.completed,
      ]);
    });

    test('a statement balances: opening plus lines is closing', () {
      final st = ShopStatement.fromJson(fixture('shop_statement')! as Json);
      expect(st.lines.map((l) => l.kind), [LedgerKind.sale, LedgerKind.commission]);
      expect(st.lines.first.ref, '58156415');
      expect(st.openingSdg + st.lines.fold(0, (n, l) => n + l.amountSdg), st.closingSdg);
      expect(st.payouts, isEmpty);
    });

    test('ledger kinds this app version does not know are skipped', () {
      expect(
        LedgerLine.fromJson({
          'id': 'x',
          'kind': 'SOMETHING_NEW',
          'amount_sdg': 1,
          'at': '2026-10-14T00:00:00Z',
        }),
        isNull,
      );
      expect(
        LedgerLine.fromJson({
          'id': 'x',
          'kind': 'SALE_REVERSAL',
          'amount_sdg': -100,
          'at': '2026-10-14T00:00:00Z',
        })?.kind,
        LedgerKind.refund,
      );
    });

    test('a shop inbox entry shows the buyer and the last message', () {
      final c = Conversation.forShop({
        'id': 'c1',
        'shop_id': 's1',
        'buyer_id': 'b1',
        'sub_order_id': null,
        'buyer_name': 'منى',
        'order_ref': null,
        'last': {'body': null, 'voice_secs': 12, 'at': '2026-10-14T08:00:00Z', 'mine': false},
        'unread': true,
      });
      expect(c.title.ar, 'منى');
      expect(c.last?.voiceSecs, 12);
      expect(c.last?.mine, isFalse);
      expect(c.unread, isTrue);
    });

    test('a buyer inbox entry is unread when a message came after they last read', () {
      final c = Conversation.forBuyer({
        'id': 'c1',
        'shop_id': 's1',
        'sub_order_id': 'so1',
        'last_message_at': '2026-10-14T08:00:00Z',
        'buyer_read_at': '2026-10-14T07:00:00Z',
        'shop': {'name_ar': 'النور لقطع الغيار', 'name_en': 'Al Noor Spares'},
        'sub_order': {
          'order': {'ref': '28743185'},
        },
        'messages': [
          {
            'id': 'm1',
            'sender_id': 'shop-user',
            'body': 'متوفر',
            'voice_key': null,
            'voice_secs': null,
            'created_at': '2026-10-14T08:00:00Z',
          },
        ],
      }, myId: 'me');
      expect(c.title.en, 'Al Noor Spares');
      expect(c.orderRef, '28743185');
      expect(c.last?.text, 'متوفر');
      expect(c.last?.mine, isFalse);
      expect(c.unread, isTrue);
    });
  });

  group('OrdersRepository', () {
    late FakeServer server;
    setUp(() => server = FakeServer());

    test('checkout sends lines, method, fulfilment per shop and an idempotency key', () async {
      server.on('/rest/v1/rpc/checkout', (_) => json(fixture('order_json')!));
      final order = await OrdersRepository(server.client()).checkout(
        const [
          CheckoutLine.listing('l1', qty: 2, seenPriceSdg: 5500),
          CheckoutLine.offer('o1', seenPriceSdg: 30000),
        ],
        PaymentMethod.cash,
        fulfilment: {'s1': FulfilmentType.delivery},
        addressId: 'a1',
      );
      expect(order.ref, '29027703');
      final body = server.body(0);
      expect(body['p_items'], [
        {'listing_id': 'l1', 'qty': 2, 'seen_price_sdg': 5500},
        {'offer_id': 'o1', 'qty': 1, 'seen_price_sdg': 30000},
      ]);
      expect(body['p_method'], 'CASH');
      expect(body['p_fulfilment'], {'s1': 'DELIVERY'});
      expect(body['p_address_id'], 'a1');
      expect(body['p_idem'], matches(RegExp(r'^[0-9a-f-]{36}$')));
    });

    test('a changed price comes back as CartChangedException with the checked lines', () async {
      server.on('/rest/v1/rpc/checkout', (_) => json(fixture('cart_changed_error')!, 409));
      final repo = OrdersRepository(server.client());
      await expectLater(
        repo.checkout(const [
          CheckoutLine.listing('l1', qty: 1, seenPriceSdg: 1),
        ], PaymentMethod.bankak),
        throwsA(
          isA<CartChangedException>()
              .having((e) => e.code, 'code', 'CART_CHANGED')
              .having((e) => e.status, 'status', 409)
              .having((e) => e.lines.single.problem, 'problem', CartProblem.priceChanged)
              .having((e) => e.lines.single.priceSdg, 'price', 5500),
        ),
      );
    });

    test('other checkout errors keep their code', () async {
      server.on(
        '/rest/v1/rpc/checkout',
        (_) => json({'code': '22023', 'message': 'PHONE_REQUIRED'}, 400),
      );
      await expectLater(
        OrdersRepository(
          server.client(),
        ).checkout(const [CheckoutLine.listing('l1', qty: 1, seenPriceSdg: 1)], PaymentMethod.cash),
        throwsA(isA<BackendException>().having((e) => e.code, 'code', 'PHONE_REQUIRED')),
      );
    });

    test('orders are read with everything the order screens need', () async {
      server.on('/rest/v1/orders', (_) => json(fixture('orders_select')!));
      final orders = await OrdersRepository(server.client()).list(limit: 10);
      expect(orders, hasLength(3));
      final url = server.requests.single.url;
      expect(url.queryParameters['select'], contains('sub_orders('));
      expect(url.queryParameters['select'], contains('suborder_events('));
      expect(url.queryParameters['order'], startsWith('created_at.desc'));
    });

    test('a receipt with only a transaction number skips the upload', () async {
      server.on('/rest/v1/rpc/submit_bankak_receipt', (_) => json(fixture('order_json')!));
      await OrdersRepository(server.client()).submitReceipt('ord1', txnNo: '123456789');
      expect(server.requests, hasLength(1));
      expect(server.body(0), containsPair('p_txn_no', '123456789'));
      expect(server.body(0), containsPair('p_receipt_key', null));
    });

    test('a receipt photo needs a signed-in user', () async {
      await expectLater(
        OrdersRepository(server.client()).submitReceipt('ord1', receipt: Uint8List(3)),
        throwsA(isA<BackendException>().having((e) => e.code, 'code', 'SESSION_EXPIRED')),
      );
      expect(server.requests, isEmpty);
    });
  });

  group('ShopRepository orders', () {
    late FakeServer server;
    setUp(() => server = FakeServer());

    test('the to-do tab filters by status codes', () async {
      server.on('/rest/v1/rpc/shop_orders', (_) => json(fixture('shop_orders')!));
      final orders = await ShopRepository(server.client())
          .orders('s1', statuses: {SubOrderStatus.confirmed, SubOrderStatus.ready});
      expect(orders.single.ref, '58156415');
      expect(server.body(0), {
        'p_shop_id': 's1',
        'p_statuses': ['CONFIRMED', 'READY'],
        'p_limit': 50,
        'p_offset': 0,
      });
    });

    test('actions send the sub-order and return it updated', () async {
      server.on('/rest/v1/rpc/shop_reject_suborder', (_) => json(rows('shop_orders').single));
      final order = await ShopRepository(server.client()).reject('so1', 'OUT_OF_STOCK');
      expect(order.ref, '58156415');
      expect(server.body(0), {'p_sub_order_id': 'so1', 'p_reason': 'OUT_OF_STOCK'});
    });

    test('the statement period is sent in UTC', () async {
      server.on('/rest/v1/rpc/shop_statement', (_) => json(fixture('shop_statement')!));
      await ShopRepository(server.client())
          .statement('s1', from: DateTime.utc(2026, 10), to: DateTime.utc(2026, 10, 14));
      expect(server.body(0), {
        'p_shop_id': 's1',
        'p_from': '2026-10-01T00:00:00.000Z',
        'p_to': '2026-10-14T00:00:00.000Z',
      });
    });
  });

  group('RequestsRepository and chat', () {
    late FakeServer server;
    setUp(() => server = FakeServer());

    test('an offer sends every field under the SQL parameter names', () async {
      server.on(
        '/rest/v1/rpc/shop_make_offer',
        (_) => json({
          'id': 'o1',
          'request_id': 'r1',
          'shop_id': 's1',
          'title_ar': 'فلتر زيت',
          'title_en': '',
          'condition': 'USED',
          'price_sdg': 9000,
          'warranty_days': 0,
          'note_ar': null,
          'image_key': null,
          'status': 'OFFERED',
          'valid_until': '2026-10-16T00:00:00Z',
        }),
      );
      final offer = await RequestsRepository(server.client()).makeOffer(
        's1',
        'r1',
        const OfferDraft(title: 'فلتر زيت', condition: ListingCondition.used, priceSdg: 9000),
      );
      expect(offer.live, isTrue);
      expect(offer.title.en, 'فلتر زيت');
      final body = server.body(0);
      expect(body..remove('p_idem'), {
        'p_shop_id': 's1',
        'p_request_id': 'r1',
        'p_title_ar': 'فلتر زيت',
        'p_condition': 'USED',
        'p_price_sdg': 9000,
        'p_warranty_days': 0,
        'p_note_ar': null,
        'p_part_id': null,
        'p_image_key': null,
        'p_valid_hours': 48,
      });
    });

    test('open requests carry the shop’s own offer and the offer count', () async {
      server.on(
        '/rest/v1/rpc/shop_open_requests',
        (_) => json([
          {
            'id': 'r1',
            'note': 'فلتر هواء لكورولا 2012',
            'status': 'OPEN',
            'image_keys': ['u1/a.jpg'],
            'created_at': '2026-10-14T00:00:00Z',
            'expires_at': '2026-10-17T00:00:00Z',
            'buyer_name': 'سارة',
            'my_offer': null,
            'offer_count': 2,
          },
        ]),
      );
      final open = await RequestsRepository(server.client()).openForShop('s1');
      expect(open.single.request.buyerName, 'سارة');
      expect(open.single.request.imageKeys, ['u1/a.jpg']);
      expect(open.single.offerCount, 2);
      expect(open.single.myOffer, isNull);
    });

    test('marking the inbox read sends the ids, or null for all', () async {
      server.on('/rest/v1/rpc/mark_notifications_read', (_) => json(3));
      final repo = NotificationsRepository(server.client());
      expect(await repo.markRead(), 3);
      await repo.markRead(['n1']);
      expect(server.body(0), {'p_ids': null});
      expect(server.body(1), {
        'p_ids': ['n1'],
      });
    });

    test('starting a chat returns the conversation id', () async {
      server.on(
        '/rest/v1/rpc/start_conversation',
        (_) => json({'id': 'c1', 'buyer_id': 'b1', 'shop_id': 's1', 'sub_order_id': 'so1'}),
      );
      final id = await ChatRepository(server.client()).start('s1', subOrderId: 'so1');
      expect(id, 'c1');
      expect(jsonDecode(server.requests.single.body), {'p_shop_id': 's1', 'p_sub_order_id': 'so1'});
    });

    test('upload content types follow the file name', () {
      expect(mimeOf('r.PDF'), 'application/pdf');
      expect(mimeOf('v.m4a'), 'audio/mp4');
      expect(mimeOf('photo'), 'image/jpeg');
    });
  });

  test('enum codes round-trip with the database', () {
    for (final s in SubOrderStatus.values) {
      expect(SubOrderStatus.fromCode(s.code), s);
    }
    expect(SubOrderStatus.handedToTechnician.code, 'HANDED_TO_TECHNICIAN');
    expect(PaymentStatus.fromCode('RECEIPT_SUBMITTED'), PaymentStatus.receiptSubmitted);
    expect(FulfilmentType.toTechnician.code, 'TO_TECHNICIAN');
  });

  test('PostgrestException details survive as the error detail', () {
    final e = BackendException.from(
      const PostgrestException(message: 'CART_CHANGED', code: 'PT409', details: '[]'),
    );
    expect(e.code, 'CART_CHANGED');
    expect(e.status, 409);
    expect(e.detail, '[]');
  });
}
