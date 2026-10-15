// The partner's happy path on a phone (or emulator) against the dev server (PLAN §2 M5:
// "same bar as M4"). `pnpm partner:e2e` first places a cash order at the demo shop and
// books a fitting with the demo technician (as a demo buyer), then this test:
//   1. signs in as the shop owner, closes the shop for the day and opens it again,
//      accepts the new order and marks it ready;
//   2. signs out, signs in as the technician and accepts the job offer.
// The script cancels the order and the fitting afterwards, so dev stays tidy.
import 'package:alghali_partner/l10n/generated/app_localizations.dart';
import 'package:alghali_partner/main.dart' as app;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';

const _shopEmail = String.fromEnvironment('E2E_SHOP_EMAIL');
const _techEmail = String.fromEnvironment('E2E_TECH_EMAIL');
const _password = String.fromEnvironment('E2E_PASSWORD');
const _orderRef = String.fromEnvironment('E2E_ORDER_REF');
const _bookingRef = String.fromEnvironment('E2E_BOOKING_REF');

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
  final dialogs = find.byType(AlertDialog).evaluate().length;
  throw TestFailure('Timed out waiting for $finder. Dialogs: $dialogs. On screen: $shown');
}

Future<void> tapOn(WidgetTester tester, Finder finder, {int seconds = 30}) async {
  await waitFor(tester, finder, seconds: seconds);
  // A snack bar from the last step can sit over the next button.
  for (final m in tester.stateList<ScaffoldMessengerState>(find.byType(ScaffoldMessenger))) {
    m.clearSnackBars();
  }
  await tester.ensureVisible(finder.first);
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(finder.first);
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> tapText(WidgetTester tester, String text, {int seconds = 30}) =>
    tapOn(tester, find.text(text), seconds: seconds);

AppLocalizations t(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(Scaffold).last));

/// "1234 5678" as the app shows order numbers (inside invisible direction marks).
String shown(String ref) => '${ref.substring(0, 4)} ${ref.substring(4)}';

Future<void> signIn(WidgetTester tester, String email) async {
  await waitFor(tester, find.byType(TextFormField));
  await tester.enterText(find.byType(TextFormField).at(0), email);
  await tester.enterText(find.byType(TextFormField).at(1), _password);
  await tapText(tester, t(tester).signInSubmit);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('partner journey on the dev server', (tester) async {
    expect(_shopEmail, isNotEmpty, reason: 'run with pnpm partner:e2e');
    await app.main();

    // Welcome: Arabic, right to left.
    await tapText(tester, 'متابعة');

    // 1. The shop.
    await signIn(tester, _shopEmail);
    await waitFor(tester, find.text(t(tester).needsAction), seconds: 40);

    // Closed for the day, then open again (buyers see it at once). The switch works once
    // the shop's details are in.
    final enabled = find.byWidgetPredicate((w) => w is Switch && w.onChanged != null);
    await tapOn(tester, enabled, seconds: 40);
    await waitFor(tester, find.text(t(tester).shopClosedToday));
    await tapOn(tester, enabled);
    // Open again: "open" or "outside opening hours", depending on the time of day.
    await waitFor(tester, find.byWidgetPredicate((w) => w is Switch && w.value));

    // The order the script placed waits for the shop: accept it, then mark it ready.
    await tapOn(tester, find.textContaining(shown(_orderRef)), seconds: 40);
    await tapText(tester, t(tester).orderAccept);
    await tapText(tester, t(tester).markReady, seconds: 40);
    await waitFor(tester, find.text(t(tester).handToBuyer), seconds: 40);

    // Sign out (from More).
    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(seconds: 1));
    await tapText(tester, t(tester).shopNavMore);
    await tapOn(tester, find.byIcon(Icons.logout));
    await tapOn(
      tester,
      find.descendant(of: find.byType(AlertDialog), matching: find.text(t(tester).signOut)),
    );

    // 2. The technician: the fitting the script booked is offered to them.
    await signIn(tester, _techEmail);
    await waitFor(tester, find.text(t(tester).newOffers), seconds: 40);
    await tapText(tester, t(tester).accept);
    await waitFor(tester, find.text(t(tester).jobAccepted), seconds: 40);
    expect(_bookingRef, isNotEmpty);
    expect(find.text(t(tester).newOffers), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
