import 'package:alghali_buyer/router.dart';
import 'package:alghali_core/alghali_core.dart';
import 'package:alghali_core/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'support/backend.dart';

/// The tint preview (D-149): clear glass until a shade is picked, then a handle that
/// compares clear and tinted glass, two views, and meters that follow the darkness.
void main() {
  setUpAll(loadAppFonts);

  testWidgets('drag to compare, switch views, meters follow the darkness', (tester) async {
    final semantics = tester.ensureSemantics();
    final c = await pumpApp(tester, FakeBackend(), locale: 'en');
    c.read(routerProvider).go(Routes.tint);
    await settle(tester);
    for (final step in ['Saloon', 'Next', 'Full car', 'Next']) {
      await tester.tap(find.text(step));
      await settle(tester);
    }

    expect(find.text('Pick a darkness to see the glass'), findsOneWidget);
    expect(find.byIcon(Icons.compare_arrows), findsNothing);
    expect(find.text('Light in'), findsNothing);

    await tester.tap(find.widgetWithText(ChoiceChip, ltr('70%')));
    await settle(tester);
    expect(find.text('Light in'), findsOneWidget);
    // The 30% light-in figure sits beside the 30% chip.
    expect(find.text(ltr('30%')), findsNWidgets(2));
    expect(find.text('High'), findsOneWidget);

    final glass = find.bySemanticsLabel(RegExp('^Glass preview'));
    int compare() => int.parse(tester.getSemantics(glass).value.replaceAll('%', ''));
    expect(compare(), 40);
    await tester.drag(find.byIcon(Icons.compare_arrows), const Offset(60, 0));
    await settle(tester);
    expect(compare(), greaterThan(40));

    await tester.tap(find.text('From inside'));
    await settle(tester);
    await tester.tap(find.widgetWithText(ChoiceChip, ltr('20%')));
    await settle(tester);
    expect(find.text('Low'), findsOneWidget);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}
