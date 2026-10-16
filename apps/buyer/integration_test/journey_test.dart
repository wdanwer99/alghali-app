// The buyer's happy path on a phone (or emulator) against the dev server (PLAN §2 M4:
// "integration test of the happy path on emulator"). It signs in as a demo buyer, adds
// the Hilux, finds bulbs, holds a fitting at a workshop, places a cash order, then
// cancels it so the dev data stays tidy. Run with `pnpm buyer:e2e` (it passes the demo
// account from .env; nothing else is needed on the device).
import 'package:alghali_buyer/main.dart' as app;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';

const _email = String.fromEnvironment('E2E_EMAIL');
const _password = String.fromEnvironment('E2E_PASSWORD');

/// Pumps until [finder] shows (the real server takes its time), or fails after [seconds].
Future<void> waitFor(WidgetTester tester, Finder finder, {int seconds = 30}) async {
  final end = DateTime.now().add(Duration(seconds: seconds));
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 250));
    if (finder.evaluate().isNotEmpty) return;
  }
  throw TestFailure('Timed out waiting for $finder');
}

Future<void> tapText(WidgetTester tester, String text, {bool contains = false}) async {
  final finder = contains ? find.textContaining(text) : find.text(text);
  await waitFor(tester, finder);
  await tester.ensureVisible(finder.first);
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(finder.first);
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('buyer journey on the dev server', (tester) async {
    expect(_email, isNotEmpty, reason: 'pass E2E_EMAIL and E2E_PASSWORD with --dart-define');
    await app.main();

    // Welcome: Arabic, right to left.
    await waitFor(
      tester,
      find.text('تخطي').hitTestable(),
    ); // the welcome tour, once the splash has gone
    await tapText(tester, 'تخطي');

    // Sign in.
    await tapText(tester, 'حسابي');
    await tapText(tester, 'تسجيل الدخول');
    await waitFor(tester, find.byType(TextFormField));
    await tester.enterText(find.byType(TextFormField).at(0), _email);
    await tester.enterText(find.byType(TextFormField).at(1), _password);
    await tapText(tester, 'دخول');
    // Signed in: the account card shows the email.
    await waitFor(tester, find.text(_email), seconds: 40);

    // My garage: the Hilux.
    await tapText(tester, 'سياراتي');
    await tapText(tester, 'إضافة سيارة');
    await tapText(tester, 'تويوتا');
    await tapText(tester, 'هايلكس');
    await tapText(tester, '2016', contains: true);
    // Saving the car closes its screen; let that finish, then leave My garage.
    await waitFor(tester, find.textContaining('هايلكس'));
    await tester.pump(const Duration(seconds: 2));
    // The phone's back button (the app's AppBar comes from material_ui, which
    // `pageBack` doesn't recognise).
    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(seconds: 1));

    // Search "لمبات": bulbs that fit.
    await tapText(tester, 'الرئيسية');
    await tapText(tester, 'ابحث', contains: true);
    await tester.enterText(find.byType(TextField).first, 'لمبات');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await waitFor(tester, find.text('يناسب سيارتك'));
    await tester.tap(find.text('يناسب سيارتك').first);
    await tester.pump(const Duration(seconds: 1));

    // The cheapest shop's offer into the cart.
    await tapText(tester, 'أضف للسلة');
    await tapText(tester, 'عرض السلة');

    // A fitting at a workshop with the first free technician, first free time.
    await tapText(tester, 'أضف التركيب');
    await tapText(tester, 'في ورشة على شارع الغالي');
    await tapText(tester, 'التالي');
    await tapText(tester, 'أول فني متاح', contains: true);
    await tapText(tester, 'التالي');
    await waitFor(tester, find.byType(ChoiceChip));
    await tester.tap(find.byType(ChoiceChip).first);
    await tester.pump(const Duration(milliseconds: 500));
    await tapText(tester, 'التالي');
    await tapText(tester, 'احجز هذا الموعد');
    await waitFor(tester, find.textContaining('محجوز لك'), seconds: 40);

    // Cash order.
    await tapText(tester, 'متابعة الدفع');
    await tapText(tester, 'نقدًا');
    await tapText(tester, 'تأكيد الطلب');
    // The order page: its number at the top, then its fitting (loaded a moment later,
    // waiting for the technician), and "cancel" at the bottom.
    await waitFor(tester, find.text('رقم الطلب'), seconds: 40);
    await waitFor(tester, find.text('بانتظار موافقة الفني'), seconds: 40);
    await tester.scrollUntilVisible(
      find.text('إلغاء الطلب'),
      300,
      scrollable: find.byType(Scrollable).last,
    );

    // Tidy up: cancel it.
    await tapText(tester, 'إلغاء الطلب');
    await waitFor(tester, find.text('هل تريد إلغاء الطلب؟'));
    await tester.tap(find.widgetWithText(TextButton, 'إلغاء الطلب'));
    await waitFor(tester, find.text('أُلغي هذا الطلب.'), seconds: 40);
  });
}
