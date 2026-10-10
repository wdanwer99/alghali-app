import 'package:alghali_core/alghali_core.dart';
import 'package:alghali_partner/app.dart';
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
      child: const PartnerApp(),
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
    expect(find.text('شركاء الغالي'), findsOneWidget);
    expect(directionOf(tester), TextDirection.rtl);
  });

  testWidgets('home shows both partner roles in Arabic', (tester) async {
    await pumpApp(tester, {'locale': 'ar'});

    expect(find.text('صاحب محل'), findsOneWidget);
    expect(find.text('فني تركيب'), findsOneWidget);
    expect(directionOf(tester), TextDirection.rtl);
  });

  testWidgets('English home is left-to-right', (tester) async {
    await pumpApp(tester, {'locale': 'en'});

    expect(find.text('Shop owner'), findsOneWidget);
    expect(find.text('Installation technician'), findsOneWidget);
    expect(directionOf(tester), TextDirection.ltr);
  });
}
