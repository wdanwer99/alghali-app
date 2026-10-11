import 'package:alghali_buyer/app.dart';
import 'package:alghali_buyer/router.dart';
import 'package:alghali_buyer/state/cart.dart';
import 'package:alghali_buyer/state/orders.dart';
import 'package:alghali_core/alghali_core.dart';
import 'package:alghali_core/testing.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Wednesday 14 Oct 2026, 09:30 in Khartoum.
final now = DateTime.utc(2026, 10, 14, 7, 30);

const signedIn = <String, Object>{
  'locale': 'ar',
  'demo_session': ['Ahmed', 'ahmed@example.com', '0912000000'],
  'garage': ['gv-1|v-hilux-16p'],
  'garage_selected': 'gv-1',
};

/// A small Android phone (360 × 780 dp), the narrowest layout we support.
Future<ProviderContainer> pumpApp(WidgetTester tester, Map<String, Object> prefs) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues(prefs);
  final instance = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(instance),
        clockProvider.overrideWithValue(() => now),
      ],
      child: const BuyerApp(),
    ),
  );
  await settle(tester);
  return ProviderScope.containerOf(tester.element(find.byType(BuyerApp)));
}

/// Hold countdowns tick every second, so pump a fixed time rather than settle.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> go(WidgetTester tester, ProviderContainer c, String location) async {
  c.read(routerProvider).go(location);
  await settle(tester);
}

TextDirection directionOf(WidgetTester tester) =>
    Directionality.of(tester.element(find.byType(Scaffold).first));

void main() {
  // Real fonts, so text widths (and any overflow) match the phone.
  setUpAll(loadAppFonts);

  group('first launch', () {
    testWidgets('shows the welcome screen in Arabic, right-to-left', (tester) async {
      await pumpApp(tester, {});
      expect(find.text('اختر اللغة'), findsOneWidget);
      expect(find.text('قطع الغيار والتركيب في مكان واحد'), findsOneWidget);
      expect(directionOf(tester), TextDirection.rtl);
    });

    testWidgets('choosing English flips to left-to-right and lands on home', (tester) async {
      await pumpApp(tester, {});
      await tester.tap(find.text('English'));
      await settle(tester);
      expect(find.text('Choose your language'), findsOneWidget);
      expect(directionOf(tester), TextDirection.ltr);

      await tester.tap(find.text('Continue'));
      await settle(tester);
      expect(find.text('Add your car to see parts that fit'), findsOneWidget);
      expect(find.text('Shop by category'), findsOneWidget);
    });
  });

  testWidgets('a signed-in buyer sees their car and next fitting on home', (tester) async {
    await pumpApp(tester, signedIn);
    expect(find.textContaining('تويوتا هايلكس'), findsOneWidget);
    expect(find.text('موعد التركيب القادم'), findsOneWidget);
  });

  testWidgets('searching "لمبات" finds bulbs that fit the Hilux', (tester) async {
    final c = await pumpApp(tester, signedIn);
    await go(tester, c, Routes.searchFor(q: 'لمبات'));
    expect(find.text('لمبة هالوجين H4'), findsOneWidget);
    expect(find.text('لمبات أمامية LED مقاس H4 (زوج)'), findsOneWidget);
    expect(find.text('يناسب سيارتك'), findsWidgets);
    // Brake pads are not bulbs.
    expect(find.text('فحمات فرامل أمامية'), findsNothing);
  });

  testWidgets('adding the best offer to the cart updates the cart badge', (tester) async {
    final c = await pumpApp(tester, signedIn);
    await go(tester, c, Routes.part('pt-h4-halogen'));
    final add = find.widgetWithText(FilledButton, 'أضف للسلة');
    await tester.ensureVisible(add);
    await settle(tester);
    await tester.tap(add);
    await settle(tester);
    expect(c.read(cartCountProvider), 1);
    expect(find.text('أُضيفت إلى السلة'), findsOneWidget);
  });

  testWidgets('guests are asked to sign in before checkout', (tester) async {
    final c = await pumpApp(tester, {'locale': 'en'});
    final catalogue = c.read(catalogueProvider);
    c
        .read(cartProvider.notifier)
        .addListing(catalogue.listing('ls-04'), catalogue.part('pt-h4-halogen'));
    await go(tester, c, Routes.cart);
    expect(find.text('Sign in to check out'), findsOneWidget);
  });

  testWidgets('Bankak checkout shows the order number and goes to "being checked"', (tester) async {
    final c = await pumpApp(tester, signedIn);
    final catalogue = c.read(catalogueProvider);
    c
        .read(cartProvider.notifier)
        .addListing(catalogue.listing('ls-04'), catalogue.part('pt-h4-halogen'));
    await go(tester, c, Routes.cart);
    await tester.tap(find.text('متابعة الدفع'));
    await settle(tester);
    await tester.tap(find.text('تأكيد الطلب'));
    await settle(tester);

    final order = c.read(ordersProvider).first;
    expect(isValidRef(order.ref), isTrue);
    expect(order.paymentStatus, PaymentStatus.awaitingTransfer);
    expect(find.text('حوّل هذا المبلغ بالضبط'), findsOneWidget);
    expect(find.text('حساب تجريبي — لا تحوّل إليه'), findsOneWidget);

    // Neither receipt nor transaction number: the form explains what's missing.
    await tester.tap(find.text('إرسال للتحقق'));
    await settle(tester);
    final txn = find.byType(TextField);
    await tester.scrollUntilVisible(txn, 200, scrollable: find.byType(Scrollable).first);
    expect(find.text('ارفع الإيصال أو اكتب رقم العملية.'), findsOneWidget);

    await tester.enterText(txn, '200987361');
    await tester.tap(find.text('إرسال للتحقق'));
    await settle(tester);
    expect(c.read(ordersProvider).first.paymentStatus, PaymentStatus.receiptSubmitted);
    expect(find.text('جارٍ التحقق من الدفع'), findsWidgets);
  });

  group('every screen lays out at 360 dp without overflow', () {
    final routes = [
      Routes.home,
      Routes.street,
      Routes.cart,
      Routes.orders,
      Routes.account,
      Routes.searchFor(q: 'فلتر'),
      Routes.part('pt-pads-hilux'),
      Routes.shop('sh-farouq'),
      Routes.garage,
      Routes.addCar,
      Routes.order('ord-1001'),
      Routes.order('ord-1002'),
      Routes.booking('bk-2001'),
      Routes.request('rq-3001'),
      Routes.newRequest,
      Routes.chat('sh-farouq'),
      Routes.notifications,
      Routes.bookExternal,
      Routes.signIn,
      Routes.signUp,
    ];
    for (final locale in ['ar', 'en']) {
      testWidgets(locale, (tester) async {
        final c = await pumpApp(tester, {...signedIn, 'locale': locale});
        for (final r in routes) {
          await go(tester, c, r);
          expect(tester.takeException(), isNull, reason: r);
        }
        expect(directionOf(tester), locale == 'ar' ? TextDirection.rtl : TextDirection.ltr);
      });
    }
  });
}
