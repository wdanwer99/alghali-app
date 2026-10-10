import 'package:alghali_buyer/app.dart';
import 'package:alghali_core/alghali_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> pumpApp(WidgetTester tester, Map<String, Object> prefs) async {
  SharedPreferences.setMockInitialValues(prefs);
  final instance = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(instance)],
      child: const BuyerApp(),
    ),
  );
  await tester.pumpAndSettle();
}

TextDirection directionOf(WidgetTester tester) =>
    Directionality.of(tester.element(find.byType(Scaffold).first));

void main() {
  testWidgets('first launch shows the language picker in Arabic, right-to-left', (tester) async {
    await pumpApp(tester, {});

    expect(find.text('اختر اللغة'), findsOneWidget);
    expect(find.text('شارع الغالي'), findsOneWidget);
    expect(directionOf(tester), TextDirection.rtl);
  });

  testWidgets('choosing English switches the app to left-to-right', (tester) async {
    await pumpApp(tester, {});

    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(find.text('Choose your language'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Car parts and fitting in one place'), findsOneWidget);
    expect(directionOf(tester), TextDirection.ltr);
  });

  testWidgets('returning user lands on home; toggle goes back to Arabic', (tester) async {
    await pumpApp(tester, {'locale': 'en'});
    expect(find.text('Alghali Street'), findsOneWidget);
    expect(find.textContaining('Not set up yet'), findsOneWidget);

    await tester.tap(find.text('العربية'));
    await tester.pumpAndSettle();

    expect(find.text('قطع الغيار والتركيب في مكان واحد'), findsOneWidget);
    expect(directionOf(tester), TextDirection.rtl);
  });
}
