// How smoothly the buyer app scrolls on a low-end phone (PLAN §2 M7: Android 8, 2 GB).
// `pnpm perf:e2e` runs it in profile mode against alghali-dev as a guest (it only reads)
// and prints the frame times; docs/PERFORMANCE.md has the results.
import 'package:alghali_buyer/l10n/generated/app_localizations.dart';
import 'package:alghali_buyer/main.dart' as app;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';

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
Future<void> scroll(WidgetTester tester, {bool horizontal = false}) async {
  final list = find.byType(Scrollable).first;
  for (final dy in [-700.0, -700.0, 700.0, 700.0]) {
    await tester.fling(list, horizontal ? Offset(dy, 0) : Offset(0, dy), 2500);
    await run(tester, 900);
  }
}

AppLocalizations t(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(Scaffold).last));

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized()
    ..framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('buyer: home, street, search and a part', (tester) async {
    await app.main();
    await waitFor(tester, find.text('متابعة'));
    await tester.tap(find.text('متابعة'));
    await waitFor(tester, find.text(t(tester).navHome));
    await run(tester, 3000);

    await binding.watchPerformance(() async {
      await scroll(tester); // home
      await tester.tap(find.text(t(tester).navStreet));
      await run(tester, 1500);
      await scroll(tester); // the street and its shops
      await tester.tap(find.text(t(tester).navHome));
      await run(tester, 800);
      await tester.tap(find.textContaining('ابحث').first);
      await run(tester, 800);
      await tester.enterText(find.byType(TextField).first, 'لمبات');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await run(tester, 4000);
      await scroll(tester); // search results with photos
    }, reportKey: 'buyer');
  });
}
