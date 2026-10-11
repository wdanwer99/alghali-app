// Renders the partner app's main screens to PNGs for design review.
// Skipped in normal runs; generate with:
//   cd apps/partner
//   flutter test test/screenshots --dart-define=SCREENSHOTS=true --update-goldens
// Output: apps/partner/build/screenshots/*.png (git-ignored).
import 'package:alghali_core/alghali_core.dart';
import 'package:alghali_core/testing.dart';
import 'package:alghali_partner/app.dart';
import 'package:alghali_partner/router.dart';
import 'package:alghali_partner/state/tech_state.dart';
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
  String? role = 'shop',
  bool dark = false,
  bool chosen = true,
  bool signedIn = true,
}) async {
  tester.view.physicalSize = const Size(360 * 2.5, 780 * 2.5);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({
    if (chosen) 'locale': locale,
    'theme_mode': dark ? 'dark' : 'light',
    if (signedIn) 'partner_session': ['Mohamed', 'mohamed@example.com', role ?? ''],
  });
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        clockProvider.overrideWithValue(() => _now),
      ],
      child: const PartnerApp(),
    ),
  );
  await _settle(tester);
  return ProviderScope.containerOf(tester.element(find.byType(PartnerApp)));
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _snap(WidgetTester tester, String name) =>
    expectLater(find.byType(PartnerApp), matchesGoldenFile('../../build/screenshots/$name.png'));

Future<void> _shot(WidgetTester tester, ProviderContainer c, String path, String name) async {
  c.read(routerProvider).go(path);
  await _settle(tester);
  await _snap(tester, name);
}

void main() {
  setUpAll(loadAppFonts);

  for (final (locale, dark) in [('ar', false), ('en', false), ('ar', true)]) {
    final tag = '${locale}_${dark ? 'dark' : 'light'}';

    testWidgets('shop screens $tag', skip: !_enabled, (tester) async {
      final c = await _boot(tester, locale: locale, dark: dark);
      await _shot(tester, c, Routes.shopHome, '${tag}_s01_home');
      await _shot(tester, c, Routes.shopOrders, '${tag}_s02_orders');
      await _shot(tester, c, Routes.shopOrder('so-901'), '${tag}_s03_order_new');
      await _shot(tester, c, Routes.shopOrder('so-902'), '${tag}_s04_order_cash');
      await _shot(tester, c, Routes.shopStock, '${tag}_s05_stock');
      await _shot(tester, c, Routes.shopQuotes, '${tag}_s06_quotes');
      await _shot(tester, c, Routes.shopMore, '${tag}_s07_more');
      await _shot(tester, c, Routes.shopMoney, '${tag}_s08_money');
      await _shot(tester, c, Routes.shopInsights, '${tag}_s09_insights');
      await _shot(tester, c, Routes.shopAdd, '${tag}_s10_add');
    });

    testWidgets('technician screens $tag', skip: !_enabled, (tester) async {
      final c = await _boot(tester, locale: locale, dark: dark, role: 'technician');
      await _shot(tester, c, Routes.techJobs, '${tag}_t01_jobs');
      await _shot(tester, c, Routes.techJob('bk-703'), '${tag}_t02_job');
      await _shot(tester, c, Routes.techSchedule, '${tag}_t03_schedule');
      await _shot(tester, c, Routes.techEarnings, '${tag}_t04_earnings');
      await _shot(tester, c, Routes.techProfile, '${tag}_t05_profile');
      c.read(techJobsProvider.notifier).checkIn('bk-702');
      await _shot(tester, c, Routes.techJob('bk-702'), '${tag}_t06_job_in_progress');
    });
  }

  testWidgets('partner onboarding', skip: !_enabled, (tester) async {
    await _boot(tester, chosen: false, signedIn: false);
    await _snap(tester, 'ar_light_00_welcome');
    var c = await _boot(tester, signedIn: false);
    await _snap(tester, 'ar_light_00b_sign_in');
    c = await _boot(tester, role: null);
    c.read(routerProvider).go(Routes.role);
    await _settle(tester);
    await _snap(tester, 'ar_light_00c_role');
    c = await _boot(tester);
    c.read(routerProvider).go(Routes.shopInsights);
    await _settle(tester);
    await tester.tap(find.text('عرض كجدول'));
    await _settle(tester);
    await _snap(tester, 'ar_light_s11_insights_table');
  });
}
