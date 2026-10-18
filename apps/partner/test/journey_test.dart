import 'package:alghali_core/alghali_core.dart';
import 'package:alghali_core/testing.dart';
import 'package:alghali_partner/router.dart';
import 'package:alghali_partner/state/outbox.dart';
import 'package:alghali_partner/state/session.dart';
import 'package:alghali_partner/state/shop.dart';
import 'package:alghali_partner/state/tech.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'support/backend.dart';

/// The shop's and the technician's day against the fake server (acceptance journey
/// step 5 and 7, brief §12), and what happens with no connection.
void main() {
  setUpAll(loadAppFonts);

  Future<void> tap(WidgetTester tester, String label) async {
    final f = find.text(label);
    // Lists build only what is on screen: scroll to what is further down.
    if (f.evaluate().isEmpty) {
      await tester.scrollUntilVisible(f, 300, scrollable: find.byType(Scrollable).first);
    }
    // To the middle, clear of a bar along the bottom.
    await Scrollable.ensureVisible(tester.element(f.first), alignment: 0.5);
    await tester.pumpAndSettle();
    await tester.tap(f.first);
    await settle(tester);
  }

  testWidgets('a new cash order: accept, ready, handed to the buyer', (tester) async {
    final backend = FakeBackend();
    final c = await pumpApp(tester, backend);
    expect(find.textContaining('6104 2177'), findsOneWidget); // On the home screen, to accept.

    c.read(routerProvider).go(Routes.shopOrder('so-new'));
    await settle(tester);
    await tap(tester, text('orderAccept'));
    expect(backend.calls('shop_ack_suborder').single['p_sub_order_id'], 'so-new');
    await tap(tester, text('markReady'));
    expect(backend.calls('shop_mark_ready'), hasLength(1));
    await tap(tester, text('handToBuyer'));
    expect(backend.calls('shop_hand_over'), hasLength(1));
    final order = c.read(shopOrderProvider('so-new'))!;
    expect(order.status, SubOrderStatus.pickedUp);
    expect(order.isDone, isTrue);
  });

  testWidgets('declining tells the buyer why, in the words the shop chose', (tester) async {
    final backend = FakeBackend();
    final c = await pumpApp(tester, backend);
    c.read(routerProvider).go(Routes.shopOrder('so-new'));
    await settle(tester);
    await tap(tester, text('orderReject'));
    await tap(tester, text('rejectOther'));
    await tester.enterText(find.byType(TextField), 'المحل مغلق للصيانة');
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, text('orderReject')));
    await settle(tester);
    final call = backend.calls('shop_reject_suborder').single;
    expect(call['p_reason'], 'المحل مغلق للصيانة');
    expect(c.read(shopOrderProvider('so-new'))!.status, SubOrderStatus.rejectedByShop);
  });

  testWidgets('a part for a fitting is handed over only once the technician accepted', (
    tester,
  ) async {
    final backend = FakeBackend();
    final ready = fixtureList('shop_orders').firstWhere((o) => o['status'] == 'READY');
    backend.orders = [
      for (final o in backend.orders)
        o['id'] == ready['id']
            ? {
                ...o,
                'booking': {...(o['booking'] as Json), 'status': 'PENDING_TECH_ACCEPT'},
              }
            : o,
    ];
    final c = await pumpApp(tester, backend);
    c.read(routerProvider).go(Routes.shopOrder(ready['id'] as String));
    await settle(tester);
    expect(find.text(text('waitTechAccept')), findsOneWidget);
    final hand = find.widgetWithText(FilledButton, text('handToTech'));
    expect(tester.widget<FilledButton>(hand).onPressed, isNull);
  });

  testWidgets('stock edits made offline wait, then go out in order with their versions', (
    tester,
  ) async {
    final db = memoryDatabase();
    addTearDown(db.close);
    final backend = FakeBackend();
    var clock = now;
    final c = await pumpApp(tester, backend, db: db, clock: () => clock);
    c.read(routerProvider).go(Routes.shopStock);
    await settle(tester);
    final first = c.read(stockProvider).value!.first;

    backend.server.offline = true;
    final stock = c.read(stockProvider.notifier);
    await tester.runAsync(() => stock.edit(first, priceSdg: 99000));
    await tester.runAsync(() => stock.edit(c.read(stockProvider).value!.first, stockQty: 40));
    await settle(tester);
    // On screen at once, with the clock of a change still to send.
    expect(c.read(stockProvider).value!.first.priceSdg, 99000);
    final core = CoreLocalizations.of(tester.element(find.byType(Scaffold).last));
    expect(find.text(core.queuedOffline), findsWidgets);
    final queued = await tester.runAsync(db.pending);
    expect(queued!.map((e) => e.operation), [PartnerOps.stockEdit, PartnerOps.stockEdit]);

    // Back online after the back-off.
    backend.server.offline = false;
    clock = now.add(const Duration(minutes: 1));
    await tester.runAsync(() => c.read(outboxProvider)!.flush());
    await settle(tester);
    final edits = backend.calls('shop_bulk_update');
    expect(edits, hasLength(2));
    final one = (edits[0]['p_items'] as List).single as Json;
    final two = (edits[1]['p_items'] as List).single as Json;
    expect(one, {'listing_id': first.id, 'version': first.version, 'price_sdg': 99000});
    // The second edit was made before the first reached the server: it carries the
    // version the first one makes (D-122).
    expect(two, {'listing_id': first.id, 'version': first.version + 1, 'stock_qty': 40});
    final saved = backend.listings.firstWhere((l) => l['id'] == first.id);
    expect(saved['price_sdg'], 99000);
    expect(saved['stock_qty'], 40);
    expect(await tester.runAsync(db.pending), isEmpty);
    expect(c.read(stockPendingProvider), isEmpty);
  });

  testWidgets('a stock edit someone else beat is refused and the shop is told', (tester) async {
    final db = memoryDatabase();
    addTearDown(db.close);
    final backend = FakeBackend();
    final c = await pumpApp(tester, backend, db: db, locale: 'en');
    c.read(routerProvider).go(Routes.shopStock);
    await settle(tester);
    final first = c.read(stockProvider).value!.first;
    // A colleague changed it on another phone meanwhile.
    backend.listings[0] = {...backend.listings[0], 'version': first.version + 5};
    await tester.runAsync(() => c.read(stockProvider.notifier).edit(first, priceSdg: 1000));
    await settle(tester);
    expect(find.textContaining('Someone else just changed this part'), findsOneWidget);
    expect(await tester.runAsync(db.pending), isEmpty);
    // The list shows the server's copy again.
    expect(c.read(stockProvider).value!.first.version, first.version + 5);
  });

  testWidgets('a quick listing made offline keeps its photo and is sent when back online', (
    tester,
  ) async {
    final db = memoryDatabase();
    addTearDown(db.close);
    final backend = FakeBackend();
    final photos = MemoryPhotoStore();
    var clock = now;
    final c = await pumpApp(tester, backend, db: db, photos: photos, clock: () => clock);
    c.read(routerProvider).go(Routes.shopAdd);
    await settle(tester);
    backend.server.offline = true;

    await tap(tester, text('takePhoto'));
    await tap(tester, CoreLocalizations.of(tester.element(find.byType(Scaffold).last)).photoCamera);
    await tap(tester, CoreLocalizations.of(tester.element(find.byType(Scaffold).last)).actionNext);
    final category = c.read(catalogueProvider).categories.first;
    await tap(tester, category.name.ar);
    await tester.enterText(find.byType(TextField), 'حساس حرارة المحرك');
    await settle(tester);
    await tap(tester, CoreLocalizations.of(tester.element(find.byType(Scaffold).last)).actionNext);
    await tap(tester, text('carsUnknown'));
    await tap(tester, CoreLocalizations.of(tester.element(find.byType(Scaffold).last)).actionNext);
    await tester.enterText(find.byType(TextField), '18000');
    await settle(tester);
    await tap(tester, text('publish'));

    // Waiting on the phone with its photo, shown in the stock list.
    final queued = (await tester.runAsync(db.pending))!.single;
    expect(queued.operation, PartnerOps.listingCreate);
    expect(photos.files, hasLength(1));
    expect(c.read(stockProvider).value!.first.partName.ar, 'حساس حرارة المحرك');

    backend.server.offline = false;
    clock = now.add(const Duration(minutes: 1));
    await tester.runAsync(() => c.read(outboxProvider)!.flush());
    await settle(tester);
    final uploads = [
      for (final r in backend.server.to('/storage/v1/object/media-public/')) r.url.path,
    ];
    expect(uploads, hasLength(4));
    expect(uploads.every((p) => p.contains('/shops/$shopId/listings/')), isTrue);
    expect(uploads.map((p) => p.split('/').last), [
      'thumb.webp',
      'medium.webp',
      'large.webp',
      'orig.jpg',
    ]);
    final upsert = backend.calls('shop_upsert_listing').single;
    expect(upsert['p_new_part'], {
      'name_ar': 'حساس حرارة المحرك',
      'category_id': category.id,
      'model_ids': <String>[],
    });
    expect(upsert['p_price_sdg'], 18000);
    expect(upsert['p_is_active'], isTrue);
    expect(upsert['p_idem'], queued.idempotencyKey);
    final images = backend.calls('shop_set_listing_images').single;
    expect((images['p_base_keys'] as List).single, contains('shops/$shopId/listings/'));
    expect(photos.files, isEmpty);
    expect(await tester.runAsync(db.pending), isEmpty);
  });

  testWidgets('an offer on a photo request', (tester) async {
    final backend = FakeBackend();
    final c = await pumpApp(tester, backend);
    c.read(routerProvider).go(Routes.shopQuotes);
    await settle(tester);
    await tap(tester, text('makeOffer'));
    await tester.enterText(find.byType(TextField).at(1), '25000');
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, text('makeOffer')).last);
    await settle(tester);
    final offer = backend.calls('shop_make_offer').single;
    expect(offer['p_request_id'], 'rq-1');
    expect(offer['p_price_sdg'], 25000);
    expect(offer['p_title_ar'], 'مرآة جانبية يسار مع إشارة');
    expect(find.textContaining('25,000'), findsOneWidget);
  });

  testWidgets('closed for today, then open again', (tester) async {
    final backend = FakeBackend();
    final c = await pumpApp(tester, backend);
    await tester.tap(find.byType(Switch).first);
    await settle(tester);
    final until = DateTime.parse(backend.calls('shop_set_closed').single['p_until'] as String);
    // Midnight in Khartoum at the end of today.
    expect(until, DateTime.utc(2026, 10, 15, 22));
    expect(find.text(text('shopClosedToday')), findsOneWidget);
    await tester.tap(find.byType(Switch).first);
    await settle(tester);
    expect(backend.calls('shop_set_closed').last['p_until'], isNull);
    expect(c.read(myShopProvider).value!.closedUntil, isNull);
  });

  testWidgets('a stock sheet: the dry run lists problems, then it is imported', (tester) async {
    final backend = FakeBackend();
    final c = await pumpApp(tester, backend, locale: 'en');
    c.read(routerProvider).go(Routes.shopStock);
    await settle(tester);
    await tap(tester, text('importExcel', 'en'));
    await tap(tester, text('uploadFile', 'en'));
    expect(find.text('Row 4'), findsOneWidget);
    expect(find.text('Price missing or wrong'), findsOneWidget);
    await tap(tester, 'Import 3 rows');
    final calls = [
      for (final r in backend.server.to('/functions/v1/inventory-import')) jsonBody(r),
    ];
    expect(calls.map((b) => b['dry_run']), [true, false]);
    expect(calls.first['shop_id'], shopId);
  });

  testWidgets('a technician accepts an offer and does the job with the buyer\'s code', (
    tester,
  ) async {
    final backend = FakeBackend(who: Who.tech);
    final c = await pumpApp(tester, backend, role: PartnerRole.technician);
    expect(find.text(text('newOffers')), findsOneWidget);
    await tap(tester, text('accept'));
    expect(backend.calls('tech_respond_offer').single, {
      'p_offer_id': 'of-1',
      'p_accept': true,
      'p_reason': null,
    });
    expect(c.read(techJobsProvider).value!.offers, isEmpty);

    // The bay job today: check in, photos, the code.
    final job = fixtureList('tech_upcoming').first['id'] as String;
    c.read(routerProvider).go(Routes.techJob(job));
    await settle(tester);
    await tap(tester, text('checkIn'));
    expect(backend.calls('tech_check_in').single['p_booking_id'], job);

    await tap(tester, text('finishJob'));
    final needPhoto = find.text(text('needAfterPhoto'));
    await tester.scrollUntilVisible(needPhoto, 300, scrollable: find.byType(Scrollable).first);
    expect(needPhoto, findsOneWidget);
    final add = find.text(text('addPhoto'));
    await tester.ensureVisible(add.last);
    await tester.tap(add.last);
    await settle(tester);
    await tap(tester, CoreLocalizations.of(tester.element(find.byType(Scaffold).last)).photoCamera);
    expect(backend.calls('tech_add_photo').single['p_kind'], 'AFTER');

    await tester.enterText(find.byType(TextField).last, '1111');
    await tap(tester, text('finishJob'));
    expect(find.textContaining('4'), findsWidgets); // "Wrong code. 4 attempts left."
    expect(c.read(techJobsProvider).value!.byId(job)!.status, BookingStatus.inProgress);

    await tester.enterText(find.byType(TextField).last, FakeBackend.jobCode);
    await tap(tester, text('finishJob'));
    expect(backend.calls('tech_complete').last['p_code'], FakeBackend.jobCode);
    expect(c.read(techJobsProvider).value!.byId(job)!.status, BookingStatus.completed);
  });

  testWidgets('going offline stops new offers until midnight; resuming ends the break', (
    tester,
  ) async {
    final backend = FakeBackend(who: Who.tech);
    final c = await pumpApp(tester, backend, role: PartnerRole.technician);
    await tester.tap(find.byType(Switch).first);
    await settle(tester);
    final off = backend.timeOff.single;
    expect(off['reason'], offlineReason);
    expect(off['period'], contains('2026-10-15T22:00:00.000Z'));
    expect(c.read(myTechnicianProvider).value!.busyUntil(now), DateTime.utc(2026, 10, 15, 22));
    expect(find.text(text('techOffline')), findsOneWidget);

    await tap(tester, text('unblock'));
    expect(backend.timeOff, isEmpty);
    expect(find.text(text('techOnline')), findsOneWidget);
  });

  testWidgets('a day off in the weekly hours removes that day\'s periods', (tester) async {
    final backend = FakeBackend(who: Who.tech);
    final c = await pumpApp(tester, backend, role: PartnerRole.technician);
    c.read(routerProvider).go(Routes.techSchedule);
    await settle(tester);
    // Saturday (weekday 6) is the first row; the demo technician works two periods.
    expect(backend.rules.where((r) => r['weekday'] == 6), hasLength(2));
    await tester.tap(find.byType(Switch).first);
    await settle(tester);
    expect(backend.rules.where((r) => r['weekday'] == 6), isEmpty);
    await tester.tap(find.byType(Switch).first);
    await settle(tester);
    expect(backend.rules.where((r) => r['weekday'] == 6).single, containsPair('start_min', 540));
  });

  testWidgets('push: registered for the partner app; a job alert opens the technician side', (
    tester,
  ) async {
    final backend = FakeBackend(who: Who.both);
    final push = FakePush();
    final c = await pumpApp(tester, backend, push: push, locale: 'en');
    final device = jsonBody(backend.server.to('/rest/v1/rpc/register_device').single);
    expect(device['p_app'], 'partner');
    expect(device['p_app_build'], 6);

    push.arrive({'code': 'NEW_ORDER', 'sub_order_id': 'so-new', 'ref': '61042177'});
    await settle(tester);
    expect(find.textContaining('New order 61042177'), findsOneWidget);
    await tap(tester, 'Open');
    expect(c.read(routerProvider).state.uri.path, Routes.shopOrder('so-new'));

    push.tap({'code': 'NEW_JOB_OFFER', 'booking_id': 'bk-offer', 'ref': '30217749'});
    await settle(tester);
    expect(c.read(partnerSessionProvider).role, PartnerRole.technician);
    expect(c.read(routerProvider).state.uri.path, Routes.techJob('bk-offer'));
  });

  testWidgets('a complaint: reported from an order, answered, and its alert opens it', (
    tester,
  ) async {
    final backend = FakeBackend();
    final push = FakePush();
    final c = await pumpApp(tester, backend, push: push);
    c.read(routerProvider).go(Routes.shopOrder('so-new'));
    await settle(tester);
    await tester.tap(find.byTooltip(text('complaintReport')));
    await settle(tester);
    await tap(tester, text('complaintPayment'));
    await tester.enterText(find.byType(TextField), 'المشتري لم يدفع عند الاستلام');
    await settle(tester);
    await tap(tester, text('complaintSend'));
    expect(backend.calls('open_dispute').single, {
      'p_category': 'PAYMENT',
      'p_description': 'المشتري لم يدفع عند الاستلام',
      'p_sub_order_id': 'so-new',
      'p_booking_id': null,
    });
    expect(c.read(routerProvider).state.uri.path, Routes.complaint('dp-2'));

    await tester.enterText(find.byType(TextField), 'أرفقت صورة الإيصال');
    await settle(tester);
    await tester.tap(find.byTooltip(text('chatSend')));
    await settle(tester);
    expect(backend.calls('dispute_reply').single, {
      'p_dispute_id': 'dp-2',
      'p_body': 'أرفقت صورة الإيصال',
    });
    expect(find.text('أرفقت صورة الإيصال'), findsOneWidget);

    push.tap({'code': 'DISPUTE_FILED', 'dispute_id': 'dp-1', 'ref': '61042177'});
    await settle(tester);
    expect(c.read(routerProvider).state.uri.path, Routes.complaint('dp-1'));
    expect(find.text('وصلتني مرآة يمين بدل اليسار'), findsOneWidget);
    expect(c.read(partnerSessionProvider).role, PartnerRole.shop);
  });

  testWidgets('signing in with one shop opens it; with a shop and a job profile, asks', (
    tester,
  ) async {
    final backend = FakeBackend();
    final c = await pumpApp(tester, backend, signedIn: false);
    await tester.enterText(find.byType(TextFormField).at(0), 'owner.nour@demo.alghali.invalid');
    await tester.enterText(find.byType(TextFormField).at(1), 'secret123');
    await tap(tester, text('signInSubmit'));
    expect(c.read(partnerSessionProvider).shopId, shopId);
    expect(c.read(routerProvider).state.uri.path, Routes.shopHome);

    final both = FakeBackend(who: Who.both);
    final c2 = await pumpApp(tester, both, signedIn: false, locale: 'en');
    await tester.enterText(find.byType(TextFormField).at(0), 'owner.nour@demo.alghali.invalid');
    await tester.enterText(find.byType(TextFormField).at(1), 'secret123');
    await tap(tester, text('signInSubmit', 'en'));
    expect(c2.read(routerProvider).state.uri.path, Routes.role);
    await tap(tester, text('roleTechnician', 'en'));
    expect(c2.read(routerProvider).state.uri.path, Routes.techJobs);
  });

  testWidgets('a new partner applies as a shop and can prepare stock while it is reviewed', (
    tester,
  ) async {
    final backend = FakeBackend(who: Who.fresh);
    final c = await pumpApp(tester, backend, role: null);
    expect(c.read(routerProvider).state.uri.path, Routes.apply);
    await tap(tester, text('applyShopTitle'));
    await tester.enterText(find.byType(TextFormField).at(0), 'محل الأمل');
    // The pin is optional; set it on the map (it opens at the street's starting point).
    await tap(tester, text('shopLocationPick'));
    expect(find.text(text('pickLocationHint')), findsOneWidget);
    await tap(tester, text('pickLocationConfirm'));
    expect(find.text(text('shopLocationIsSet')), findsOneWidget);
    final phone = find.widgetWithText(TextFormField, text('fieldPhone'));
    await tester.scrollUntilVisible(phone, 300, scrollable: find.byType(Scrollable).first);
    await tester.enterText(phone, '0912345678');
    await settle(tester);
    await tap(tester, text('applySubmit'));
    final apply = backend.calls('apply_as_shop').single;
    expect(apply['p_name_ar'], 'محل الأمل');
    expect(apply['p_phone'], '0912345678');
    expect(apply['p_lat'], isA<double>());
    expect(apply['p_lng'], isA<double>());
    expect((apply['p_opening_hours'] as Json).keys, containsAll(['6', '0', '4']));
    expect(c.read(routerProvider).state.uri.path, Routes.shopHome);
    expect(find.text(text('shopPendingBody')), findsOneWidget);
  });

  testWidgets('the owner sets the shop pin in the profile, then removes it', (tester) async {
    final backend = FakeBackend();
    final c = await pumpApp(tester, backend);
    c.read(routerProvider).go(Routes.shopProfile);
    await settle(tester);
    final save = CoreLocalizations.of(tester.element(find.byType(Scaffold).last)).actionSave;

    await tap(tester, text('shopLocationPick'));
    await tap(tester, text('pickLocationConfirm'));
    await tap(tester, save);
    final set = backend.calls('shop_update_profile').last['p_patch'] as Json;
    expect(set['lat'], isA<double>());
    expect(set['lng'], isA<double>());

    final remove = find.text(text('shopLocationRemove'));
    await tester.scrollUntilVisible(remove, -300, scrollable: find.byType(Scrollable).first);
    await tap(tester, text('shopLocationRemove'));
    expect(find.text(text('shopLocationPick')), findsOneWidget);
    // The first "saved" message would cover the button.
    ScaffoldMessenger.of(tester.element(find.byType(Scaffold).last)).clearSnackBars();
    await settle(tester);
    await tap(tester, save);
    final removed = backend.calls('shop_update_profile').last['p_patch'] as Json;
    expect(removed, containsPair('lat', null));
    expect(removed, containsPair('lng', null));
  });

  testWidgets('the shop sets its window-tint offer, prices typed on an Arabic keyboard (D-149)', (
    tester,
  ) async {
    final backend = FakeBackend();
    final c = await pumpApp(tester, backend);
    c.read(routerProvider).go(Routes.shopMore);
    await settle(tester);
    await tap(tester, text('moreTint'));
    expect(find.text(text('tintBayCount').replaceFirst('{count}', '1')), findsOneWidget);

    await tester.tap(find.widgetWithText(FilterChip, ltr('70%')));
    await settle(tester);
    await tap(tester, CoreLocalizations.of(tester.element(find.byType(Scaffold).last)).tintBlue);
    final core = CoreLocalizations.of(tester.element(find.byType(Scaffold).last));
    await tap(tester, core.tintSizeMinibus);
    final minibusFull = find.byKey(const ValueKey('tint-MINIBUS-FULL'));
    await tester.scrollUntilVisible(minibusFull, 200, scrollable: find.byType(Scrollable).first);
    await tester.enterText(minibusFull, '٨٠٠٠٠');
    await settle(tester);
    expect(find.descendant(of: minibusFull, matching: find.text('80000')), findsOneWidget);
    await tap(tester, core.actionSave);

    final call = backend.calls('shop_set_tint').single;
    expect(call['p_is_active'], isTrue);
    expect(call['p_darkness'], [30, 50, 70, 100]);
    expect(call['p_colours'], containsAll(['BLACK', 'BLUE', 'SMOKE', 'BRONZE']));
    final prices = (call['p_prices'] as List).cast<Json>();
    expect(prices, contains(equals({'car_size': 'MINIBUS', 'item': 'FULL', 'price_sdg': 80000})));
    expect(prices, contains(equals({'car_size': 'SALOON', 'item': 'FULL', 'price_sdg': 70000})));
    expect(find.text(text('saved')), findsOneWidget);
  });
}
