// The acceptance journey (brief §12) on a phone, the partner's part, in two runs:
//   'offer' — step 5a: the technician accepts the fitting;
//   'jobday' — step 5b: the shop readies the bulbs and hands them over; step 7: on the way,
//     check-in, before and after photos, the buyer's code. Run by `pnpm journey:e2e`,
// which sets the accounts up on alghali-test, has the buyer app place the order first and
// passes what this test needs. The photo picker and GPS are swapped for fixed answers:
// a device test can't use the camera or answer Android's permission prompt.
import 'dart:convert';

import 'package:alghali_partner/l10n/generated/app_localizations.dart';
import 'package:alghali_partner/main.dart' as app;
import 'package:alghali_partner/state/tech.dart';
import 'package:alghali_partner/widgets/partner_widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';

const _techEmail = String.fromEnvironment('E2E_TECH_EMAIL');
const _techPassword = String.fromEnvironment('E2E_TECH_PASSWORD');
const _shopEmail = String.fromEnvironment('E2E_SHOP_EMAIL');
const _shopPassword = String.fromEnvironment('E2E_SHOP_PASSWORD');
const _orderRef = String.fromEnvironment('E2E_ORDER_REF');
const _jobCode = String.fromEnvironment('E2E_JOB_CODE');
const _part = String.fromEnvironment('E2E_PART_NAME');

/// A 1×1 JPEG standing in for the job photos.
final _jpeg = base64Decode(
  '/9j/4AAQSkZJRgABAQEASABIAAD/2wBDAAMCAgICAgMCAgIDAwMDBAYEBAQEBAgGBgUGCQgKCgkICQkKDA8MCgsOCwkJDRENDg8QEBEQCgwSExIQEw8QEBD/yQALCAABAAEBAREA/8wABgAQEAX/2gAIAQEAAD8A0s8g/9k=',
);

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

/// Scrolls the page until [finder] is built, then taps it.
Future<void> scrollTo(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(finder, 300, scrollable: find.byType(Scrollable).last);
  }
  await tapOn(tester, finder);
}

AppLocalizations t(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(Scaffold).last));

/// "1234 5678" as the app shows order numbers (inside invisible direction marks).
String shown(String ref) => '${ref.substring(0, 4)} ${ref.substring(4)}';

Future<void> signIn(WidgetTester tester, String email, String password) async {
  await waitFor(tester, find.byType(TextFormField));
  await tester.enterText(find.byType(TextFormField).at(0), email);
  await tester.enterText(find.byType(TextFormField).at(1), password);
  await tapText(tester, t(tester).signInSubmit);
}

Future<void> signOut(WidgetTester tester) async {
  await scrollTo(tester, find.byIcon(Icons.logout));
  await tapOn(
    tester,
    find.descendant(of: find.byType(AlertDialog), matching: find.text(t(tester).signOut)),
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// The app as on a phone, with a fixed photo and position; the welcome screen passed.
  Future<void> launch(WidgetTester tester) async {
    expect(_jobCode, isNotEmpty, reason: 'run with pnpm journey:e2e');
    await app.runPartnerApp(
      overrides: [
        photoPickerProvider.overrideWithValue(
          ({required bool camera}) async => (bytes: _jpeg, fileName: 'job.jpg'),
        ),
        gpsProvider.overrideWithValue(() async => (lat: 15.605, lng: 32.5)),
      ],
    );
    // Welcome: Arabic, right to left.
    await tapText(tester, 'متابعة');
  }

  testWidgets('acceptance (offer): the technician accepts the fitting', (tester) async {
    await launch(tester);
    // 5a. The technician accepts the fitting.
    await signIn(tester, _techEmail, _techPassword);
    await waitFor(tester, find.text(t(tester).newOffers), seconds: 40);
    await tapText(tester, t(tester).accept);
    await waitFor(tester, find.text(t(tester).jobAccepted), seconds: 40);
    expect(tester.takeException(), isNull);
  });

  // (the reminders go out in between: step 6)

  testWidgets('acceptance (jobday): the shop hands over, the job is done', (tester) async {
    await launch(tester);

    // 5b. The shop accepts the paid order, readies the bulbs and hands them to the technician.
    await signIn(tester, _shopEmail, _shopPassword);
    await waitFor(tester, find.text(t(tester).needsAction), seconds: 40);
    await tapOn(tester, find.textContaining(shown(_orderRef)), seconds: 40);
    await tapText(tester, t(tester).orderAccept);
    await tapText(tester, t(tester).markReady, seconds: 40);
    await tapText(tester, t(tester).handToTech, seconds: 40);
    await waitFor(tester, find.text(t(tester).orderHandedOver), seconds: 40);
    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(seconds: 1));
    await tapText(tester, t(tester).shopNavMore);
    await signOut(tester);

    // 7. The job day: on the way, check in, photos, Ahmed's code.
    await signIn(tester, _techEmail, _techPassword);
    await tapOn(tester, find.text(_part), seconds: 40);
    await tapText(tester, t(tester).onMyWay, seconds: 40);
    await tapText(tester, t(tester).checkIn, seconds: 40);
    // Checked in: the finish button shows; the photos and the code are further down.
    await waitFor(tester, find.text(t(tester).finishJob), seconds: 40);
    for (final title in [t(tester).photosBefore, t(tester).photosAfter]) {
      final add = find.descendant(
        of: find.ancestor(of: find.text(title), matching: find.byType(Card)),
        matching: find.byIcon(Icons.add_a_photo_outlined),
      );
      await scrollTo(tester, add);
      await tapOn(tester, find.byIcon(Icons.photo_library_outlined));
      // Uploaded: a tile shows the photo (or its placeholder while the link is made).
      await waitFor(
        tester,
        find.descendant(
          of: find.ancestor(of: find.text(title), matching: find.byType(Card)),
          matching: find.byWidgetPredicate(
            (w) =>
                w is Image ||
                (w is Icon &&
                    (w.icon == Icons.image_outlined || w.icon == Icons.broken_image_outlined)),
          ),
        ),
        seconds: 40,
      );
    }
    final code = find.byType(TextField).last;
    if (code.evaluate().isEmpty) {
      await tester.scrollUntilVisible(code, 300, scrollable: find.byType(Scrollable).last);
    }
    await tester.ensureVisible(code);
    await tester.enterText(code, _jobCode);
    await tester.pump(const Duration(milliseconds: 500));
    await tapText(tester, t(tester).finishJob);
    await waitFor(tester, find.text(t(tester).jobDone), seconds: 40);
    expect(tester.takeException(), isNull);
  });
}
