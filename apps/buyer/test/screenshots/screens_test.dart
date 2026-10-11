// Renders every main screen to PNGs for design review and store listings.
// Skipped in normal runs; generate with:
//   cd apps/buyer
//   flutter test test/screenshots --dart-define=SCREENSHOTS=true --update-goldens
// Output: apps/buyer/build/screenshots/*.png (git-ignored).
import 'package:alghali_buyer/app.dart';
import 'package:alghali_buyer/router.dart';
import 'package:alghali_buyer/state/cart.dart';
import 'package:alghali_buyer/state/demo_account.dart';
import 'package:alghali_buyer/state/orders.dart';
import 'package:alghali_core/alghali_core.dart';
import 'package:alghali_core/testing.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _enabled = bool.fromEnvironment('SCREENSHOTS');

/// Wednesday 14 Oct 2026, 09:30 in Khartoum.
final _now = DateTime.utc(2026, 10, 14, 7, 30);

Future<ProviderContainer> _boot(
  WidgetTester tester, {
  String locale = 'ar',
  bool signedIn = true,
  bool dark = false,
  bool chosen = true,
}) async {
  tester.view.physicalSize = const Size(360 * 2.5, 780 * 2.5);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({
    if (chosen) 'locale': locale,
    'theme_mode': dark ? 'dark' : 'light',
    if (signedIn) ...{
      'demo_session': ['Ahmed', 'ahmed@example.com', '0912000000'],
      'garage': ['gv-1|v-hilux-16p'],
      'garage_selected': 'gv-1',
    },
  });
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        clockProvider.overrideWithValue(() => _now),
      ],
      child: const BuyerApp(),
    ),
  );
  await _settle(tester);
  return ProviderScope.containerOf(tester.element(find.byType(BuyerApp)));
}

/// Countdown timers tick forever, so pump a fixed time instead of settling.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _shot(WidgetTester tester, ProviderContainer c, String path, String name) async {
  c.read(routerProvider).go(path);
  await _settle(tester);
  await expectLater(find.byType(BuyerApp), matchesGoldenFile('../../build/screenshots/$name.png'));
}

void _fillCart(ProviderContainer c, {bool fitting = true}) {
  final catalogue = c.read(catalogueProvider);
  final cart = c.read(cartProvider.notifier)
    ..addListing(catalogue.listing('ls-04'), catalogue.part('pt-h4-halogen'))
    ..addListing(catalogue.listing('ls-13'), catalogue.part('pt-pads-hilux'));
  if (!fitting) return;
  final line = c.read(cartProvider).first;
  cart.attachFitting(
    line.id,
    FittingDraft(
      place: BookingPlace.customer,
      technicianId: 'tc-osman',
      anyTechnician: false,
      slot: Slot(DateTime.utc(2026, 10, 15, 14), 30),
      labourSdg: 6000,
      travelFeeSdg: 3000,
      heldUntil: _now.add(const Duration(minutes: 9, seconds: 32)),
      address: demoAddresses.first,
    ),
  );
}

void main() {
  setUpAll(loadAppFonts);

  for (final (locale, dark) in [('ar', false), ('en', false), ('ar', true)]) {
    final tag = '${locale}_${dark ? 'dark' : 'light'}';

    testWidgets('buyer screens $tag', skip: !_enabled, (tester) async {
      final c = await _boot(tester, locale: locale, dark: dark);
      await _shot(tester, c, Routes.home, '${tag}_01_home');
      await _shot(
        tester,
        c,
        Routes.searchFor(q: locale == 'ar' ? 'لمبات' : 'bulb'),
        '${tag}_02_search',
      );
      await _shot(tester, c, Routes.part('pt-h4-halogen'), '${tag}_03_part');
      await _shot(tester, c, Routes.street, '${tag}_04_street');
      await _shot(tester, c, Routes.shop('sh-nour'), '${tag}_05_shop');
      _fillCart(c);
      await _shot(tester, c, Routes.cart, '${tag}_06_cart');
      await _shot(tester, c, Routes.checkout, '${tag}_07_checkout');
      await _shot(tester, c, Routes.orders, '${tag}_08_orders');
      await _shot(tester, c, Routes.order('ord-1002'), '${tag}_09_order');
      await _shot(tester, c, Routes.booking('bk-2001'), '${tag}_10_booking');
      await _shot(tester, c, Routes.request('rq-3001'), '${tag}_11_request');
      await _shot(tester, c, Routes.chat('sh-farouq'), '${tag}_12_chat');
      await _shot(tester, c, Routes.account, '${tag}_13_account');
      await _shot(tester, c, Routes.notifications, '${tag}_14_notifications');
      await _shot(tester, c, Routes.garage, '${tag}_15_garage');
    });
  }

  testWidgets('buyer flows ar', skip: !_enabled, (tester) async {
    final c = await _boot(tester);
    _fillCart(c, fitting: false);
    final lineId = c.read(cartProvider).first.id;
    await _shot(tester, c, Routes.bookLine(lineId), 'ar_light_20_book_place');
    await tester.tap(find.text('في مكانك').first);
    await _settle(tester);
    await expectLater(
      find.byType(BuyerApp),
      matchesGoldenFile('../../build/screenshots/ar_light_21_book_place_home.png'),
    );
    await tester.tap(find.text('التالي'));
    await _settle(tester);
    await tester.tap(find.text('محمد عثمان'));
    await _settle(tester);
    await expectLater(
      find.byType(BuyerApp),
      matchesGoldenFile('../../build/screenshots/ar_light_22_book_tech.png'),
    );
    await tester.tap(find.text('التالي'));
    await _settle(tester);
    await tester.tap(find.text('غدًا'));
    await _settle(tester);
    await expectLater(
      find.byType(BuyerApp),
      matchesGoldenFile('../../build/screenshots/ar_light_23_book_time.png'),
    );
    await tester.tap(find.byType(ChoiceChip).at(2));
    await _settle(tester);
    await tester.tap(find.text('التالي'));
    await _settle(tester);
    await expectLater(
      find.byType(BuyerApp),
      matchesGoldenFile('../../build/screenshots/ar_light_24_book_review.png'),
    );

    _fillCart(c, fitting: false);
    final placed = c
        .read(ordersProvider.notifier)
        .place(
          lines: c.read(cartProvider),
          choice: const CheckoutChoice(method: PaymentMethod.bankak, fulfilment: {}),
        );
    await _shot(tester, c, Routes.payOrder(placed.id), 'ar_light_25_bankak');
    await _shot(tester, c, Routes.order(placed.id), 'ar_light_25b_order_new');
    await _shot(tester, c, Routes.newRequest, 'ar_light_26_new_request');
    await _shot(tester, c, Routes.addCar, 'ar_light_27_add_car');
    await _shot(tester, c, Routes.signIn, 'ar_light_28_sign_in');
    await _shot(tester, c, Routes.bookExternal, 'ar_light_29_book_external');
  });

  testWidgets('first launch and guest', skip: !_enabled, (tester) async {
    var c = await _boot(tester, signedIn: false, chosen: false);
    await expectLater(
      find.byType(BuyerApp),
      matchesGoldenFile('../../build/screenshots/ar_light_00_welcome.png'),
    );
    await tester.tap(find.text('English'));
    await _settle(tester);
    await expectLater(
      find.byType(BuyerApp),
      matchesGoldenFile('../../build/screenshots/en_light_00_welcome.png'),
    );
    c = await _boot(tester, signedIn: false);
    await _shot(tester, c, Routes.home, 'ar_light_30_home_guest');
    await _shot(tester, c, Routes.orders, 'ar_light_31_orders_guest');
    await _shot(tester, c, Routes.cart, 'ar_light_32_cart_empty');
    await _shot(tester, c, Routes.searchFor(q: 'xyz'), 'ar_light_33_search_empty');
  });
}
