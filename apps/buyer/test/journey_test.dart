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

  testWidgets('window tint: chosen, put in the cart, fitted at the shop, then paid (D-149)', (
    tester,
  ) async {
    final backend = FakeBackend();
    final c = await pumpApp(tester, backend);
    final tintShop = (backend.snapshot['shops'] as List).cast<Json>()[1];

    // From the home screen's categories (the tile is at the end of the row).
    final tile = find.text('تظليل الزجاج');
    unawaited(Scrollable.ensureVisible(tester.element(tile), alignment: 0.5));
    await settle(tester);
    unawaited(Scrollable.ensureVisible(tester.element(tile), alignment: 0.5));
    await settle(tester);
    await tester.tap(tile);
    await settle(tester);
    await tester.tap(find.text('صالون'));
    await settle(tester);
    await tester.tap(find.text('التالي'));
    await settle(tester);
    await tester.tap(find.text('السيارة كاملة'));
    await settle(tester);
    expect(jsonBody(backend.server.to('/rest/v1/rpc/tint_offers').last), {
      'p_car_size': 'SALOON',
      'p_package': 'FULL',
      'p_windows': null,
    });
    await tester.tap(find.text('التالي'));
    await settle(tester);
    // 100% only at the second shop; bronze too.
    await tester.tap(find.widgetWithText(ChoiceChip, ltr('100%')));
    await settle(tester);
    // Below the glass preview: scroll to the colours first.
    await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'برونزي'));
    await settle(tester);
    await tester.tap(find.widgetWithText(ChoiceChip, 'برونزي'));
    await settle(tester);
    await tester.tap(find.text('التالي'));
    await settle(tester);
    expect(find.text(tintShop['name_ar'] as String), findsOneWidget);
    expect(find.textContaining('يركّب في المحل'), findsOneWidget);
    await tester.tap(find.text(tintShop['name_ar'] as String));
    await settle(tester);
    await tester.tap(find.text('أضف للسلة واحجز التركيب'));
    await settle(tester);

    final line = c.read(cartProvider).lines.single;
    expect(line.tint?.toJson(), {
      'car_size': 'SALOON',
      'package': 'FULL',
      'darkness': 100,
      'colour': 'BRONZE',
    });
    expect(line.unitPriceSdg, 70000);
    expect(backend.cartItems.single['tint_shop_id'], tintShop['id']);

    // Straight into booking its fitting, at the shop that sells it.
    await tester.tap(find.text('في ${tintShop['name_ar']}'));
    await settle(tester);
    await tester.tap(find.text('التالي'));
    await settle(tester);
    final slots = jsonBody(backend.server.to('/functions/v1/booking-slots').first);
    expect(slots['items'], [
      {'tint_shop_id': tintShop['id'], 'tint': line.tint!.toJson()},
    ]);
    await tester.tap(find.text('أول فني متاح'));
    await settle(tester);
    await tester.tap(find.text('التالي'));
    await settle(tester);
    await tester.tap(find.byType(ChoiceChip).first);
    await settle(tester);
    await tester.tap(find.text('التالي'));
    await settle(tester);
    await tester.tap(find.text('احجز هذا الموعد'));
    await settle(tester);
    expect(c.read(cartProvider).fitted(line.id), isTrue);

    unawaited(c.read(routerProvider).push(Routes.checkout));
    await settle(tester);
    await tester.tap(find.text('تأكيد الطلب'));
    await settle(tester);
    final checkout = jsonBody(backend.server.to('/rest/v1/rpc/checkout').single);
    expect(checkout['p_items'], [
      {
        'tint_shop_id': tintShop['id'],
        'tint': line.tint!.toJson(),
        'qty': 1,
        'seen_price_sdg': 70000,
      },
    ]);
  });

  testWidgets('tint without a fitting cannot go to checkout', (tester) async {
    final c = await pumpApp(tester, FakeBackend(), locale: 'en');
    final category = c.read(catalogueProvider).tintCategory!;
    c
        .read(cartProvider.notifier)
        .addTint(
          shopId: 'shop-1',
          category: category,
          choice: const TintChoice(
            carSize: TintCarSize.suv,
            selection: TintSelection.package(TintItem.sides),
            darkness: 50,
            colour: TintColour.black,
          ),
          priceSdg: 40000,
        );
    c.read(routerProvider).go(Routes.cart);
    await settle(tester);
    expect(find.text('Window tint needs a fitting booked before you pay.'), findsOneWidget);
    expect(find.textContaining('Sides only · 50% · Black · 4x4'), findsOneWidget);
    final checkout = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Checkout'));
    expect(checkout.onPressed, isNull);
  });

  testWidgets('directions open Google Maps only for shops that set their pin', (tester) async {
    final pickup = (fixture('orders') as List).cast<Json>().firstWhere((o) {
      final subs = (o['sub_orders'] as List).cast<Json>();
      return subs.length == 1 &&
          subs.single['fulfilment'] == 'PICKUP' &&
          subs.single['status'] == 'READY';
    });
    final pickupShop = ((pickup['sub_orders'] as List).single as Json)['shop_id'] as String;
    final detail = fixture('part_detail') as Json;
    final part = (detail['part'] as Json)['id'] as String;
    final sellers = {
      for (final l in (detail['listings'] as List).cast<Json>())
        (l['shop'] as Json)['id'] as String,
    };
    final directions = 'الاتجاهات';

    // No pins: no button anywhere.
    final c = await pumpApp(tester, FakeBackend());
    c.read(routerProvider).go(Routes.order(pickup['id'] as String));
    await settle(tester);
    expect(find.text(directions), findsNothing);
    c.read(routerProvider).go(Routes.part(part));
    await settle(tester);
    expect(find.byTooltip(directions), findsNothing);

    // The pickup shop and one seller set their pins.
    final pinned = FakeBackend()
      ..pins[pickupShop] = (lat: 15.5901, lng: 32.5352)
      ..pins[sellers.first] = (lat: 15.5903, lng: 32.5349);
    final c2 = await pumpApp(tester, pinned);
    c2.read(routerProvider).go(Routes.order(pickup['id'] as String));
    await settle(tester);
    expect(find.text(directions), findsOneWidget);
    c2.read(routerProvider).go(Routes.part(part));
    await settle(tester);
    expect(find.byTooltip(directions), findsOneWidget);
  });
}
