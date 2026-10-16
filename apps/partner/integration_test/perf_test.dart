// How smoothly the partner app scrolls on a low-end phone (PLAN §2 M7: Android 8, 2 GB).
// `pnpm perf:e2e` runs it in profile mode against alghali-dev, signed in as the demo shop
// owner (it only reads), and prints the frame times; docs/PERFORMANCE.md has the results.
import 'package:alghali_partner/l10n/generated/app_localizations.dart';
import 'package:alghali_partner/main.dart' as app;
import 'package:alghali_partner/router.dart';
import 'package:alghali_partner/state/session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';

const _email = String.fromEnvironment('E2E_SHOP_EMAIL');
const _password = String.fromEnvironment('E2E_PASSWORD');

Future<void> waitFor(WidgetTester tester, Finder finder, {int seconds = 40}) async {
  final end = DateTime.now().add(Duration(seconds: seconds));
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 250));
    if (finder.evaluate().isNotEmpty) return;
  }
  final shown = tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data)
      .whereType<String>()
      .join(' | ');
  throw TestFailure('Timed out waiting for $finder. On screen: $shown');
}

/// Lets frames run for [ms] (images arrive, animations finish) without waiting to settle.
Future<void> run(WidgetTester tester, int ms) async {
  for (var t = 0; t < ms; t += 16) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// Flings the page's main list down and back up, as a thumb would.
Future<void> scroll(WidgetTester tester) async {
  final list = find.byType(Scrollable).first;
  for (final dy in [-700.0, -700.0, 700.0, 700.0]) {
    await tester.fling(list, Offset(0, dy), 2500);
    await run(tester, 900);
  }
}

AppLocalizations t(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(Scaffold).last));

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized()
    ..framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('partner: shop home, orders and stock', (tester) async {
    expect(_email, isNotEmpty, reason: 'run with pnpm perf:e2e');
    await app.main();
    await waitFor(
      tester,
      find.text('تخطي').hitTestable(),
    ); // the welcome tour, once the splash has gone
    await tester.tap(find.text('تخطي').hitTestable());
    await waitFor(tester, find.byType(TextFormField));
    // Signed in the way the sign-in page does it, not by typing: on Android 8 the system
    // keyboard swallows text a test types (this measures scrolling, not the sign-in form).
    final container = ProviderScope.containerOf(tester.element(find.byType(Scaffold).first));
    await container
        .read(partnerSessionProvider.notifier)
        .signIn(email: _email, password: _password);
    container.read(routerProvider).go('/');
    // Signed in: the shop's home with its tabs.
    await waitFor(tester, find.text(t(tester).shopNavOrders));
    await run(tester, 3000);

    await binding.watchPerformance(() async {
      await scroll(tester); // home
      await tester.tap(find.text(t(tester).shopNavOrders));
      await run(tester, 2500);
      await scroll(tester); // orders
      await tester.tap(find.text(t(tester).shopNavStock));
      await run(tester, 3000);
      await scroll(tester); // stock with photos
    }, reportKey: 'partner');
  });
}
