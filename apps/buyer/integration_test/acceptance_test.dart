// The acceptance journey (brief §12) on a phone, the buyer's part. Run by
// `pnpm journey:e2e`, which sets the accounts up on alghali-test and runs:
//   'acceptance: order' — steps 1–4: sign in, the Hilux into My Garage, "لمبات" shows only
//     bulbs that fit, from two shops; the bulbs into the cart with a fitting at Ahmed's
//     place on Thursday at 4 pm; Bankak, with the transaction number; "being checked".
//   (the admin confirms, then the partner app's test does steps 5 and 7)
//   'acceptance: rate' — step 8: Ahmed rates the shop and the technician.
import 'package:alghali_buyer/l10n/generated/app_localizations.dart';
import 'package:alghali_buyer/main.dart' as app;
import 'package:alghali_core/alghali_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';

const _email = String.fromEnvironment('E2E_EMAIL');
const _password = String.fromEnvironment('E2E_PASSWORD');
const _part = String.fromEnvironment('E2E_PART_NAME');
const _decoy = String.fromEnvironment('E2E_DECOY_NAME');
const _tech = String.fromEnvironment('E2E_TECH_NAME');
const _txn = String.fromEnvironment('E2E_TXN');
const _orderRef = String.fromEnvironment('E2E_ORDER_REF');

/// Pumps until [finder] shows (the real server takes its time), or fails after [seconds].
Future<void> waitFor(WidgetTester tester, Finder finder, {int seconds = 30}) async {
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

Future<void> tapOn(WidgetTester tester, Finder finder, {int seconds = 30}) async {
  await waitFor(tester, finder, seconds: seconds);
  for (final m in tester.stateList<ScaffoldMessengerState>(find.byType(ScaffoldMessenger))) {
    m.clearSnackBars();
  }
  await tester.ensureVisible(finder.first);
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(finder.first);
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> tapText(WidgetTester tester, String text, {bool contains = false, int seconds = 30}) =>
    tapOn(tester, contains ? find.textContaining(text) : find.text(text), seconds: seconds);

/// Scrolls the page until [finder] is built, then taps it.
Future<void> scrollTo(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(finder, 300, scrollable: find.byType(Scrollable).last);
  }
  await tapOn(tester, finder);
}

BuildContext ctx(WidgetTester tester) => tester.element(find.byType(Scaffold).last);
AppLocalizations t(WidgetTester tester) => AppLocalizations.of(ctx(tester));
CoreLocalizations core(WidgetTester tester) => CoreLocalizations.of(ctx(tester));

/// "1234 5678" as the app shows order numbers (inside invisible direction marks).
String shown(String ref) => '${ref.substring(0, 4)} ${ref.substring(4)}';

Future<void> signIn(WidgetTester tester) async {
  await tapText(tester, 'متابعة'); // the welcome screen: Arabic, right to left
  await tapText(tester, 'حسابي');
  await tapText(tester, 'تسجيل الدخول');
  await waitFor(tester, find.byType(TextFormField));
  await tester.enterText(find.byType(TextFormField).at(0), _email);
  await tester.enterText(find.byType(TextFormField).at(1), _password);
  await tapText(tester, 'دخول');
  await waitFor(tester, find.text(_email), seconds: 40);
}

/// Thursday at 4 pm in Khartoum within the next six days (tomorrow at 4 pm when today is
/// Thursday, since the next one is past the booking window), with its index in the day strip.
({DateTime start, int day}) thursdayAtFour() {
  final k = DateTime.now().toUtc().add(khartoumOffset);
  for (var d = 1; d <= 6; d++) {
    final day = DateTime.utc(k.year, k.month, k.day + d);
    if (day.weekday == DateTime.thursday) {
      return (
        start: DateTime.utc(day.year, day.month, day.day, 16).subtract(khartoumOffset),
        day: d,
      );
    }
  }
  return (start: DateTime.utc(k.year, k.month, k.day + 1, 16).subtract(khartoumOffset), day: 1);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('acceptance: order', (tester) async {
    expect(_txn, isNotEmpty, reason: 'run with pnpm journey:e2e');
    await app.main();

    // 1. Sign in, and the Hilux into My Garage.
    await signIn(tester);
    await tapText(tester, 'سياراتي');
    await tapText(tester, 'إضافة سيارة');
    await tapText(tester, 'تويوتا');
    await tapText(tester, 'هايلكس');
    await tapText(tester, '2016', contains: true);
    await waitFor(tester, find.textContaining('هايلكس'));
    await tester.pump(const Duration(seconds: 2));
    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(seconds: 1));

    // 2. "لمبات": the bulb that fits, not the other car's.
    await tapText(tester, t(tester).navHome);
    await tapText(tester, 'ابحث', contains: true);
    await tester.enterText(find.byType(TextField).first, 'لمبات');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await waitFor(tester, find.text(_part), seconds: 40);
    expect(find.text(_decoy), findsNothing);
    await tapText(tester, _part);
    // Two shops, cheapest first, each with its price.
    await waitFor(tester, find.textContaining('12,000'), seconds: 40);
    expect(find.textContaining('14,000'), findsWidgets);

    // 3. Into the cart, with a fitting at his place, his technician, Thursday at 4 pm.
    await tapText(tester, t(tester).partAddToCart);
    await tapText(tester, t(tester).partViewCart);
    await tapText(tester, t(tester).cartAddFitting);
    await tapText(tester, t(tester).bookPlaceHome, seconds: 40);
    await tapText(tester, core(tester).actionNext);
    await tapText(tester, _tech, contains: true, seconds: 40);
    await tapText(tester, core(tester).actionNext);
    final when = thursdayAtFour();
    await waitFor(tester, find.byType(ChoiceChip), seconds: 40);
    final dayLabel = when.day == 1 ? core(tester).tomorrow : ctx(tester).weekday(when.start);
    await tapText(tester, dayLabel);
    await tapOn(tester, find.widgetWithText(ChoiceChip, ctx(tester).time(when.start)));
    await tapText(tester, core(tester).actionNext);
    await tapText(tester, t(tester).bookHold);
    await waitFor(tester, find.textContaining('محجوز لك'), seconds: 40);

    // 4. Bankak: the account and his order number, then the transaction number.
    await tapText(tester, t(tester).cartCheckout);
    await tapText(tester, t(tester).checkoutBankak);
    await tapText(tester, t(tester).checkoutPlace);
    await waitFor(tester, find.text(t(tester).bankakAccountNumber), seconds: 40);
    expect(find.text(t(tester).bankakRef), findsOneWidget);
    final txn = find.byWidgetPredicate(
      (w) => w is TextField && (w.decoration?.labelText ?? '').startsWith(t(tester).bankakTxn),
    );
    await tester.ensureVisible(txn);
    await tester.enterText(txn, _txn);
    await tester.pump(const Duration(milliseconds: 500));
    await scrollTo(tester, find.text(t(tester).bankakSubmit));
    await waitFor(tester, find.text(t(tester).bankakChecking), seconds: 40);
    expect(tester.takeException(), isNull);
  });

  testWidgets('acceptance: rate', (tester) async {
    expect(_orderRef, isNotEmpty, reason: 'run with pnpm journey:e2e');
    await app.main();
    await signIn(tester);

    // 8. The order: rate the shop; then its fitting: rate the technician.
    await tapText(tester, t(tester).navOrders);
    await tapOn(tester, find.textContaining(shown(_orderRef)), seconds: 40);
    for (final rate in [t(tester).orderRateShop, t(tester).bookingRate]) {
      if (rate == t(tester).bookingRate) {
        await scrollTo(tester, find.byIcon(Icons.handyman_outlined));
      }
      await scrollTo(tester, find.text(rate));
      await tapOn(tester, find.byTooltip('5/5'));
      await tapText(tester, t(tester).reviewSubmit);
      await waitFor(tester, find.text(t(tester).reviewThanks), seconds: 40);
    }
    expect(tester.takeException(), isNull);
  });
}
