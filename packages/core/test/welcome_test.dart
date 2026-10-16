import 'package:alghali_core/alghali_core.dart';
import 'package:alghali_core/testing.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// [home] inside a MaterialApp that follows the locale controller, on a small phone.
Future<ProviderContainer> pump(
  WidgetTester tester,
  Widget Function(BuildContext context) home, {
  Map<String, Object> prefs = const {},
  bool reducedMotion = false,
}) async {
  tester.view.physicalSize = const Size(360, 640) * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  if (reducedMotion) {
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
      disableAnimations: true,
    );
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  }
  SharedPreferences.setMockInitialValues(prefs);
  final instance = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(instance)],
      child: Consumer(
        builder: (context, ref, _) => MaterialApp(
          locale: ref.watch(localeControllerProvider).locale,
          supportedLocales: supportedLocales,
          localizationsDelegates: const [
            CoreLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          theme: AppTheme.light(),
          home: Builder(builder: home),
        ),
      ),
    ),
  );
  return ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
}

/// Frame by frame, as on a phone: the splash moves on at most a frame per frame.
Future<void> play(WidgetTester tester, int ms) async {
  for (var t = 0; t < ms; t += 16) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

const slides = [
  TourSlide(icon: Icons.storefront_outlined, chips: [Icons.search], title: 'One', body: 'First'),
  TourSlide(chips: [Icons.handyman_outlined], title: 'Two', body: 'The wheel'),
  TourSlide(icon: Icons.payments_outlined, title: 'Three', body: 'Last'),
];

void main() {
  setUpAll(loadAppFonts);

  group('splash', () {
    var taps = 0;
    Widget app(BuildContext _, {required bool ready}) => SplashGate(
      ready: ready,
      child: Scaffold(
        body: Center(
          child: TextButton(onPressed: () => taps++, child: const Text('Under')),
        ),
      ),
    );

    setUp(() => taps = 0);

    testWidgets('plays through once, then lets the app through', (tester) async {
      await pump(tester, (c) => app(c, ready: true));
      expect(find.text('شارع الغالي'), findsOneWidget);
      await tester.tap(find.text('Under'), warnIfMissed: false);
      expect(taps, 0, reason: 'the splash takes the taps while it shows');

      await play(tester, 1000);
      expect(find.text('شارع الغالي'), findsOneWidget, reason: 'still playing');
      await play(tester, 900);
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('شارع الغالي'), findsNothing);
      await tester.tap(find.text('Under'));
      expect(taps, 1);
    });

    testWidgets('waits for the app, but not for ever', (tester) async {
      await pump(tester, (c) => app(c, ready: false));
      await play(tester, 3000);
      expect(find.text('شارع الغالي'), findsOneWidget, reason: 'loading: the street keeps going');
      await play(tester, 3000);
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('شارع الغالي'), findsNothing);
    });

    testWidgets('leaves as soon as the app is ready', (tester) async {
      final ready = ValueNotifier(false);
      addTearDown(ready.dispose);
      await pump(
        tester,
        (c) => ValueListenableBuilder(
          valueListenable: ready,
          builder: (c, r, _) => app(c, ready: r),
        ),
      );
      await play(tester, 2000);
      expect(find.text('شارع الغالي'), findsOneWidget);
      ready.value = true;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('شارع الغالي'), findsNothing);
    });

    testWidgets('a long stall at start-up does not skip the show', (tester) async {
      await pump(tester, (c) => app(c, ready: true));
      await tester.pump(const Duration(seconds: 3)); // one very slow frame
      await play(tester, 300);
      expect(find.text('شارع الغالي'), findsOneWidget, reason: 'the street is still lighting up');
      await play(tester, 1600);
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('شارع الغالي'), findsNothing);
    });

    testWidgets('with animations off it shows the finished street and goes', (tester) async {
      await pump(tester, (c) => app(c, ready: true), reducedMotion: true);
      await tester.pump();
      expect(find.text('شارع الغالي'), findsNothing);
      expect(find.text('Under'), findsOneWidget);
    });
  });

  group('welcome tour', () {
    testWidgets('Next walks the pages; the last saves Arabic and goes on', (tester) async {
      var done = 0;
      final c = await pump(tester, (_) => WelcomeTour(slides: slides, onDone: () => done++));
      await tester.pumpAndSettle();
      expect(find.text('One'), findsOneWidget);
      expect(Directionality.of(tester.element(find.text('One'))), TextDirection.rtl);

      await tester.tap(find.text('التالي'));
      await tester.pumpAndSettle();
      expect(find.text('Two'), findsOneWidget);
      expect(find.byType(AlghaliWheel), findsOneWidget);
      await tester.tap(find.text('التالي'));
      await tester.pumpAndSettle();
      expect(find.text('Three'), findsOneWidget);
      expect(c.read(localeControllerProvider).chosen, isFalse);

      await tester.tap(find.text('ابدأ'));
      await tester.pumpAndSettle();
      expect(done, 1);
      expect(c.read(localeControllerProvider).chosen, isTrue);
      expect(c.read(sharedPreferencesProvider).getString('locale'), 'ar');
      expect(tester.takeException(), isNull);
    });

    testWidgets('choosing English flips the screen; Skip keeps it', (tester) async {
      var done = 0;
      final c = await pump(tester, (_) => WelcomeTour(slides: slides, onDone: () => done++));
      await tester.pumpAndSettle();
      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();
      expect(Directionality.of(tester.element(find.text('One'))), TextDirection.ltr);
      expect(c.read(localeControllerProvider).chosen, isFalse, reason: 'only a preview');

      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      expect(done, 1);
      expect(c.read(sharedPreferencesProvider).getString('locale'), 'en');
    });

    testWidgets('swiping turns the page', (tester) async {
      await pump(tester, (_) => WelcomeTour(slides: slides, onDone: () {}));
      await tester.pumpAndSettle();
      // Right to left: the next page comes in from the left.
      await tester.fling(find.text('One'), const Offset(300, 0), 1500);
      await tester.pumpAndSettle();
      expect(find.text('Two'), findsOneWidget);
      expect(find.text('التالي'), findsOneWidget);
    });

    testWidgets('fits a small phone in both languages, partner colours too', (tester) async {
      const long = TourSlide(
        icon: Icons.inventory_2_outlined,
        chips: [Icons.cloud_off_outlined, Icons.sync, Icons.sell_outlined],
        title: 'Your stock, even offline, with a title that wraps',
        body:
            'Change prices and quantities any time; they are sent by themselves when you '
            'are back online.',
      );
      for (final locale in ['ar', 'en']) {
        await pump(
          tester,
          (_) =>
              WelcomeTour(variant: MarkVariant.partner, slides: const [long, long], onDone: () {}),
          prefs: {'locale': locale},
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: locale);
      }
    });
  });
}
