import 'dart:async';

import 'package:alghali_buyer/router.dart';
import 'package:alghali_buyer/state/cart.dart';
import 'package:alghali_buyer/state/outbox.dart';
import 'package:alghali_core/alghali_core.dart';
import 'package:alghali_core/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'support/backend.dart';

/// Acceptance journey steps 2–4 (brief §12) against the fake server, plus what happens
/// with no connection: saved data on screen, changes waiting in the outbox.
void main() {
  setUpAll(loadAppFonts);

  final shopId =
      (((fixture('search_shop') as List).first as Json)['listings'] as List)
              .cast<Json>()
              .first['shop_id']
          as String;

  testWidgets('a fitting at a workshop is held from the cart and paid with the parts', (
    tester,
  ) async {
    final backend = FakeBackend();
    final c = await pumpApp(tester, backend);
    final detail = PartDetail.fromJson(fixture('part_detail') as Json);
    c.read(cartProvider.notifier).addListing(detail.offers.first.listing, detail.part);
    c.read(routerProvider).go(Routes.cart);
    await settle(tester);

    await tester.tap(find.text('أضف التركيب'));
    await settle(tester);
    await tester.tap(find.text('في ورشة على شارع الغالي'));
    await settle(tester);
    await tester.tap(find.text('التالي'));
    await settle(tester);
    await tester.tap(find.text('أول فني متاح'));
    await settle(tester);
    await tester.tap(find.text('التالي'));
    await settle(tester);
    // The first free time today (the slot engine's answer).
    await tester.tap(find.byType(ChoiceChip).first);
    await settle(tester);
    await tester.tap(find.text('التالي'));
    await settle(tester);
    await tester.tap(find.text('احجز هذا الموعد'));
    await settle(tester);

    final hold = jsonBody(backend.server.to('/rest/v1/rpc/create_booking_hold').single);
    expect(hold['p_place'], 'BAY');
    expect(hold['p_assignment_mode'], 'ANY');
    expect(hold['p_items'], [
      {'listing_id': detail.offers.first.listing.id},
    ]);
    final fitting = c.read(cartProvider).fitting!;
    expect(fitting.lineIds, {c.read(cartProvider).lines.single.id});
    expect(find.text('التركيب'), findsWidgets);
    expect(find.textContaining('محجوز لك'), findsOneWidget);

    unawaited(c.read(routerProvider).push(Routes.checkout));
    await settle(tester);
    expect(find.textContaining('يسلّم المحل القطعة لفنيك'), findsOneWidget);
    await tester.tap(find.text('تأكيد الطلب'));
    await settle(tester);
    final checkout = jsonBody(backend.server.to('/rest/v1/rpc/checkout').single);
    expect(checkout['p_booking_id'], fitting.booking.id);
    // The fitted shop hands over to the technician; the server decides that, not the app.
    expect(checkout['p_fulfilment'], isEmpty);
    expect(c.read(cartProvider).fitting, isNull);
  });

  testWidgets('a hold someone else just took sends the buyer back to pick another time', (
    tester,
  ) async {
    final backend = FakeBackend();
    backend.server.on('/rest/v1/rpc/create_booking_hold', (_) => rpcError('SLOT_TAKEN'));
    final c = await pumpApp(tester, backend, locale: 'en');
    final detail = PartDetail.fromJson(fixture('part_detail') as Json);
    c.read(cartProvider.notifier).addListing(detail.offers.first.listing, detail.part);
    final line = c.read(cartProvider).lines.single;
    unawaited(c.read(routerProvider).push(Routes.bookLine(line.id)));
    await settle(tester);
    for (final step in [
      'At a workshop on Alghali Street',
      'Next',
      'First available technician',
      'Next',
    ]) {
      await tester.tap(find.text(step));
      await settle(tester);
    }
    await tester.tap(find.byType(ChoiceChip).first);
    await settle(tester);
    await tester.tap(find.text('Next'));
    await settle(tester);
    await tester.tap(find.text('Hold this time'));
    await settle(tester);
    expect(find.text('Someone just took this time. Pick another.'), findsOneWidget);
    expect(find.text('Pick a time to continue'), findsOneWidget);
    expect(c.read(cartProvider).fitting, isNull);
  });

  testWidgets('chat written offline waits with a clock, then goes out once', (tester) async {
    final db = memoryDatabase();
    addTearDown(db.close);
    var clock = now;
    final backend = FakeBackend();
    final c = await pumpApp(
      tester,
      backend,
      db: db,
      clock: () => clock,
      prefs: {'chat:$buyerId:$shopId': 'conv-1'},
    );
    c.read(routerProvider).go(Routes.chat(shopId));
    await settle(tester);

    backend.server.offline = true;
    await tester.enterText(find.byType(TextField), 'عندكم لمبة H4؟');
    await settle(tester);
    await tester.tap(find.byTooltip('إرسال'));
    await settle(tester);
    expect(find.text('عندكم لمبة H4؟'), findsOneWidget);
    expect(find.byIcon(Icons.schedule), findsOneWidget);
    expect(backend.messages, isEmpty);
    expect((await db.pending()).single.operation, BuyerOps.chatSend);

    // Back online after the back-off.
    backend.server.offline = false;
    clock = now.add(const Duration(minutes: 1));
    await tester.runAsync(() => c.read(outboxProvider)!.flush());
    await settle(tester);
    expect(backend.messages.single['body'], 'عندكم لمبة H4؟');
    expect(find.byIcon(Icons.schedule), findsNothing);

    // The answer to the first try was lost and it is sent again: the server already
    // has it (same id), so it counts as sent and nothing is duplicated.
    final sent = backend.messages.single;
    await tester.runAsync(
      () => c.read(outboxProvider)!.add(BuyerOps.chatSend, {
        'id': sent['id'],
        'conversation_id': 'conv-1',
        'body': sent['body'],
      }),
    );
    await tester.runAsync(() => c.read(outboxProvider)!.flush());
    expect(backend.messages, hasLength(1));
    expect(await db.pending(), isEmpty);
  });

  testWidgets('orders saved on the phone still show with no connection', (tester) async {
    final db = memoryDatabase();
    addTearDown(db.close);
    final backend = FakeBackend();
    final c = await pumpApp(tester, backend, db: db, locale: 'en');
    c.read(routerProvider).go(Routes.orders);
    await settle(tester);
    expect(find.textContaining('7249'), findsOneWidget);

    // A new start of the app, offline.
    backend.server.offline = true;
    final c2 = await pumpApp(tester, backend, db: db, locale: 'en', signedIn: false);
    c2.read(routerProvider).go(Routes.orders);
    await settle(tester);
    expect(find.textContaining('7249'), findsOneWidget);
  });
}
