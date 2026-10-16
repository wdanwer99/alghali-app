import 'package:alghali_buyer/router.dart';
import 'package:alghali_buyer/state/cart.dart';
import 'package:alghali_buyer/state/orders.dart';
import 'package:alghali_buyer/state/session.dart';
import 'package:alghali_core/alghali_core.dart';
import 'package:alghali_core/testing.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'support/backend.dart';

Future<void> go(WidgetTester tester, ProviderContainer c, String location) async {
  c.read(routerProvider).go(location);
  await settle(tester);
}

TextDirection directionOf(WidgetTester tester) =>
    Directionality.of(tester.element(find.byType(Scaffold).first));

/// The Hilux in the captured catalogue.
String hiluxVariant() {
  final s = fixture('catalogue_snapshot') as Json;
  final model = (s['models'] as List).cast<Json>().firstWhere((m) => m['name_en'] == 'Hilux');
  return (s['variants'] as List).cast<Json>().firstWhere((v) => v['model_id'] == model['id'])['id']
      as String;
}

Map<String, Object> withHilux() => {
  'garage': ['8f1c3c1e-0000-4000-8000-000000000001|${hiluxVariant()}'],
  'garage_selected': '8f1c3c1e-0000-4000-8000-000000000001',
};

void main() {
  // Real fonts, so text widths (and any overflow) match the phone.
  setUpAll(loadAppFonts);

  group('first launch', () {
    testWidgets('shows the welcome tour in Arabic, right-to-left', (tester) async {
      final backend = FakeBackend();
      await pumpApp(tester, backend, signedIn: false, prefs: {}, locale: 'ar');
      final c = ProviderScope.containerOf(tester.element(find.byType(Scaffold).first));
      c.read(routerProvider).go(Routes.welcome);
      await settle(tester);
      expect(find.text('كل محلات الشارع في جيبك'), findsOneWidget);
      expect(find.text('تخطي'), findsOneWidget);
      expect(directionOf(tester), TextDirection.rtl);
    });
  });

  testWidgets('home shows the live categories and the street', (tester) async {
    final backend = FakeBackend();
    await pumpApp(tester, backend, locale: 'en', prefs: withHilux());
    expect(find.text('Shop by category'), findsOneWidget);
    expect(find.text('Lighting'), findsWidgets);
    expect(find.textContaining('Toyota Hilux'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('searching "لمبات" shows the bulbs that fit the Hilux', (tester) async {
    final backend = FakeBackend();
    final c = await pumpApp(tester, backend, prefs: withHilux());
    await go(tester, c, Routes.searchFor(q: 'لمبات'));
    expect(find.text('لمبة هالوجين H4'), findsOneWidget);
    expect(find.text('يناسب سيارتك'), findsNWidgets(3));
    final call = backend.server.to('/rest/v1/rpc/search_parts').last;
    expect(call.body, contains(hiluxVariant()));
  });

  testWidgets('a guest is asked to sign in before checkout', (tester) async {
    final backend = FakeBackend();
    final c = await pumpApp(tester, backend, signedIn: false, locale: 'en');
    final detail = PartDetail.fromJson(fixture('part_detail') as Json);
    c.read(cartProvider.notifier).addListing(detail.offers.first.listing, detail.part);
    await go(tester, c, Routes.cart);
    expect(find.text('Sign in to check out'), findsOneWidget);
    expect(c.read(sessionProvider).signedIn, isFalse);
  });

  testWidgets('Bankak checkout places the order and sends the transaction number', (tester) async {
    final backend = FakeBackend();
    final c = await pumpApp(tester, backend, prefs: withHilux());
    final detail = PartDetail.fromJson(fixture('part_detail') as Json);
    c.read(cartProvider.notifier).addListing(detail.offers.first.listing, detail.part);
    await go(tester, c, Routes.checkout);
    await tester.tap(find.text('تأكيد الطلب'));
    await settle(tester);

    final checkout = jsonBody(backend.server.to('/rest/v1/rpc/checkout').single);
    expect(checkout['p_method'], 'BANKAK');
    expect(checkout['p_idem'], isNotNull);
    expect(find.text('حوّل هذا المبلغ بالضبط'), findsOneWidget);
    expect(c.read(cartProvider).lines, isEmpty);

    await tester.tap(find.text('إرسال للتحقق'));
    await settle(tester);
    expect(find.text('ارفع الإيصال أو اكتب رقم العملية.'), findsOneWidget);

    final txn = find.byType(TextField);
    await tester.enterText(txn, '200987361');
    await tester.tap(find.text('إرسال للتحقق'));
    await settle(tester);
    final receipt = jsonBody(backend.server.to('/rest/v1/rpc/submit_bankak_receipt').single);
    expect(receipt['p_txn_no'], '200987361');
    final order = c.read(ordersProvider).value!.first;
    expect(order.bankakStatus, PaymentStatus.receiptSubmitted);
  });

  testWidgets(
    'push: the phone registers after sign-in; alerts show a banner and open their screen',
    (tester) async {
      final backend = FakeBackend();
      final push = FakePush();
      final c = await pumpApp(tester, backend, push: push, locale: 'en');

      final device = jsonBody(backend.server.to('/rest/v1/rpc/register_device').single);
      expect(device['p_app'], 'buyer');
      expect(device['p_fcm_token'], 'fcm-token-1');
      expect(device['p_app_build'], 4);
      expect(device['p_locale'], 'en');

      // An alert while the app is open: worded from the templates, with a way in.
      final order = (fixture('orders') as List).cast<Json>().firstWhere(
        (o) => (o['sub_orders'] as List).isNotEmpty,
      );
      push.arrive({'code': 'ORDER_READY', 'order_id': order['id'] as String, 'ref': '72491962'});
      await settle(tester);
      expect(find.textContaining('Your order is ready'), findsOneWidget);
      expect(find.textContaining('Order 72491962 is ready at the shop.'), findsOneWidget);
      await tester.tap(find.text('Open'));
      await settle(tester);
      expect(c.read(routerProvider).state.uri.path, Routes.order(order['id'] as String));

      // Tapping an alert in the notification tray opens its fitting.
      final booking = (fixture('my_bookings') as List).cast<Json>().first;
      push.tap({'code': 'BOOKING_ACCEPTED', 'booking_id': booking['id'] as String});
      await settle(tester);
      expect(c.read(routerProvider).state.uri.path, Routes.booking(booking['id'] as String));
    },
  );
}
