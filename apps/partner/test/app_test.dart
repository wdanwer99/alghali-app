import 'package:alghali_core/alghali_core.dart';
import 'package:alghali_core/testing.dart';
import 'package:alghali_partner/app.dart';
import 'package:alghali_partner/router.dart';
import 'package:alghali_partner/state/shop_state.dart';
import 'package:alghali_partner/state/tech_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Wednesday 14 Oct 2026, 09:30 in Khartoum.
final now = DateTime.utc(2026, 10, 14, 7, 30);

Map<String, Object> signedInAs(String role, [String locale = 'ar']) => {
  'locale': locale,
  'partner_session': ['Mohamed', 'mohamed@example.com', role],
};

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
      child: const PartnerApp(),
    ),
  );
  await settle(tester);
  return ProviderScope.containerOf(tester.element(find.byType(PartnerApp)));
}

/// Offer and acknowledge countdowns tick every second; pump a fixed time.
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
  setUpAll(loadAppFonts);

  testWidgets('first launch: Arabic welcome → sign in → choose the shop role', (tester) async {
    await pumpApp(tester, {});
    expect(find.text('أدر محلك وأعمالك من هاتفك'), findsOneWidget);
    expect(directionOf(tester), TextDirection.rtl);

    await tester.tap(find.text('متابعة'));
    await settle(tester);
    expect(find.text('تسجيل دخول الشركاء'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), 'mohamed@example.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'secret123');
    await tester.tap(find.text('دخول'));
    await tester.pump(const Duration(milliseconds: 500));
    await settle(tester);
    expect(find.text('كيف تريد المتابعة؟'), findsOneWidget);

    await tester.tap(find.text('صاحب محل'));
    await settle(tester);
    expect(find.text('النور لقطع الغيار'), findsOneWidget);
    expect(find.text('يحتاج إجراء'), findsOneWidget);
  });

  testWidgets('a weak password is rejected with the policy message', (tester) async {
    await pumpApp(tester, {'locale': 'en'});
    await tester.enterText(find.byType(TextFormField).at(0), 'shop@example.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'short');
    await tester.tap(find.text('Sign in'));
    await settle(tester);
    expect(find.text('At least 8 characters, with letters and numbers'), findsOneWidget);
  });

  testWidgets('shop accepts, prepares and hands an order to the technician', (tester) async {
    final c = await pumpApp(tester, signedInAs('shop'));
    await go(tester, c, Routes.shopOrder('so-901'));
    await tester.tap(find.text('قبول الطلب'));
    await settle(tester);
    expect(c.read(shopOrdersProvider.notifier).byId('so-901')!.isPreparing, isTrue);

    await tester.tap(find.text('القطعة جاهزة'));
    await settle(tester);
    await tester.tap(find.text('سلّمتها للفني'));
    await settle(tester);
    expect(
      c.read(shopOrdersProvider.notifier).byId('so-901')!.sub.status,
      SubOrderStatus.handedToTechnician,
    );
  });

  test('bulk +10% rounds prices to the nearest 500 SDG', () {
    final c = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(_FakePrefs()),
        clockProvider.overrideWithValue(() => now),
      ],
    );
    addTearDown(c.dispose);
    final before = c.read(stockProvider).firstWhere((s) => s.id == 'ls-04').priceSdg; // 12,000
    c.read(stockProvider.notifier).bulkPercent({'ls-04'}, 10);
    final after = c.read(stockProvider).firstWhere((s) => s.id == 'ls-04').priceSdg;
    expect(before, 12000);
    expect(after, 13000);
  });

  testWidgets('technician accepts an offer and it moves to their jobs', (tester) async {
    final c = await pumpApp(tester, signedInAs('technician'));
    expect(find.text('عروض جديدة'), findsOneWidget);
    await tester.tap(find.text('قبول'));
    await settle(tester);
    final jobs = c.read(techJobsProvider);
    expect(jobs.offers, isEmpty);
    expect(jobs.jobs.any((b) => b.id == 'bk-701' && b.status == BookingStatus.accepted), isTrue);
  });

  test('job code: needs an after photo, five wrong codes lock completion (D-028)', () {
    final c = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(_FakePrefs()),
        clockProvider.overrideWithValue(() => now),
      ],
    );
    addTearDown(c.dispose);
    final jobs = c.read(techJobsProvider.notifier)..checkIn('bk-702');
    expect(jobs.complete('bk-702', '3906'), CodeResult.needPhoto);
    jobs.addPhoto('bk-702', after: true);
    for (var i = 0; i < 4; i++) {
      expect(jobs.complete('bk-702', '0000'), CodeResult.wrong);
    }
    expect(jobs.complete('bk-702', '0000'), CodeResult.locked);
    expect(jobs.complete('bk-702', '3906'), CodeResult.locked);
  });

  test('the right code completes the job and adds the pay to earnings', () {
    final c = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(_FakePrefs()),
        clockProvider.overrideWithValue(() => now),
      ],
    );
    addTearDown(c.dispose);
    final before = c.read(techEarningsProvider).weekSdg;
    final jobs = c.read(techJobsProvider.notifier)
      ..checkIn('bk-702')
      ..addPhoto('bk-702', after: true);
    expect(jobs.complete('bk-702', '3906'), CodeResult.ok);
    expect(c.read(techEarningsProvider).weekSdg, before + 4000);
  });

  group('every screen lays out at 360 dp without overflow', () {
    const shop = [
      Routes.shopHome,
      Routes.shopOrders,
      Routes.shopStock,
      Routes.shopQuotes,
      Routes.shopMore,
      Routes.shopMoney,
      Routes.shopStaff,
      Routes.shopInsights,
      Routes.shopAdd,
    ];
    const tech = [Routes.techJobs, Routes.techSchedule, Routes.techEarnings, Routes.techProfile];
    for (final locale in ['ar', 'en']) {
      testWidgets('shop $locale', (tester) async {
        final c = await pumpApp(tester, signedInAs('shop', locale));
        for (final r in [
          ...shop,
          for (final id in ['so-901', 'so-902', 'so-903', 'so-904', 'so-905']) Routes.shopOrder(id),
        ]) {
          await go(tester, c, r);
          expect(tester.takeException(), isNull, reason: r);
        }
      });
      testWidgets('technician $locale', (tester) async {
        final c = await pumpApp(tester, signedInAs('technician', locale));
        for (final r in [
          ...tech,
          for (final id in ['bk-701', 'bk-702', 'bk-703', 'bk-704']) Routes.techJob(id),
        ]) {
          await go(tester, c, r);
          expect(tester.takeException(), isNull, reason: r);
        }
      });
    }
  });
}

/// Minimal in-memory prefs for container-only tests.
class _FakePrefs implements SharedPreferences {
  final _data = <String, Object>{};

  @override
  String? getString(String key) => _data[key] as String?;

  @override
  List<String>? getStringList(String key) => _data[key] as List<String>?;

  @override
  bool? getBool(String key) => _data[key] as bool?;

  @override
  Future<bool> setString(String key, String value) async => (_data[key] = value) == value;

  @override
  Future<bool> setStringList(String key, List<String> value) async {
    _data[key] = value;
    return true;
  }

  @override
  Future<bool> setBool(String key, bool value) async {
    _data[key] = value;
    return true;
  }

  @override
  Future<bool> remove(String key) async => _data.remove(key) != null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
