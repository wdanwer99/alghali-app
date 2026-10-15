import 'dart:convert';
import 'dart:typed_data';

import 'package:alghali_core/alghali_core.dart';
import 'package:alghali_core/testing.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// What the partner app adds in M5: the shop's own reads (detail, insights, closing for the
/// day), listing photos in every size, where a fitting's parts are, and the outbox
/// showing what still waits.
void main() {
  late FakeServer server;
  setUp(() => server = FakeServer());

  Json shopRow({String? closedUntil}) => {
    'id': 'shop1',
    'zone_id': 'z1',
    'name_ar': 'النور',
    'name_en': 'Al-Nour',
    'status': 'PENDING',
    'opening_hours': {
      '0': [
        [480, 1200],
      ],
    },
    'closed_until': closedUntil,
    'open_now': closedUntil == null,
    'category_ids': <String>[],
    'make_ids': <String>[],
  };

  group('shop repository', () {
    test('reads its own shop and closes it for the day', () async {
      server
        ..on('/rest/v1/rpc/shop_detail', (_) => jsonResponse(shopRow()))
        ..on('/rest/v1/rpc/shop_set_closed', (r) {
          return jsonResponse(shopRow(closedUntil: jsonBody(r)['p_until'] as String?));
        });
      final repo = ShopRepository(server.client());
      expect((await repo.detail('shop1')).closedUntil, isNull);
      final closed = await repo.setClosed('shop1', DateTime.utc(2026, 10, 15, 22));
      expect(closed.closedUntil, DateTime.utc(2026, 10, 15, 22));
      expect(closed.openNow, isFalse);
      expect(jsonBody(server.requests.last), {
        'p_shop_id': 'shop1',
        'p_until': '2026-10-15T22:00:00.000Z',
      });
    });

    test('insights: a day per Khartoum date, best sellers and rating', () async {
      server.on('/rest/v1/rpc/shop_insights', (_) {
        return jsonResponse({
          'days': [
            {'day': '2026-10-14', 'sales_sdg': 0, 'orders': 0},
            {'day': '2026-10-15', 'sales_sdg': 36000, 'orders': 2},
          ],
          'top': [
            {'part_id': 'p1', 'title_ar': 'لمبة', 'title_en': 'Bulb', 'qty': 3, 'sales_sdg': 36000},
          ],
          'rating_avg': 4.5,
          'rating_count': 12,
        });
      });
      final i = await ShopRepository(server.client()).insights('shop1');
      expect(i.days.last.day, DateTime.utc(2026, 10, 15));
      expect(i.days.last.sdg, 36000);
      expect(i.top.single.title.en, 'Bulb');
      expect(i.rating, 4.5);
    });

    test('a listing photo goes up in every size under one base key', () async {
      server.on('/storage/v1/object/media-public/', (_) => jsonResponse({'Key': 'x'}));
      final bytes = Uint8List.fromList([1]);
      final base = await ShopRepository(server.client()).uploadListingPhoto('shop1', (
        thumb: bytes,
        medium: bytes,
        large: bytes,
        orig: bytes,
      ), id: 'aaaaaaaa-0000-4000-8000-000000000001');
      expect(base, 'shops/shop1/listings/aaaaaaaa-0000-4000-8000-000000000001');
      expect(
        [for (final r in server.requests) r.url.path],
        [
          for (final f in ['thumb.webp', 'medium.webp', 'large.webp', 'orig.jpg'])
            '/storage/v1/object/media-public/$base/$f',
        ],
      );
      // Each file's type travels inside its multipart body.
      String body(int i) => latin1.decode(server.requests[i].bodyBytes);
      expect(body(0), contains('content-type: image/webp'));
      expect(body(3), contains('content-type: image/jpeg'));
      // A replay from the outbox overwrites the same files.
      expect(server.requests.every((r) => r.headers['x-upsert'] == 'true'), isTrue);
    });
  });

  group('models', () {
    test('a quick listing survives the outbox: toParams and back', () {
      const draft = ListingDraft(
        condition: ListingCondition.used,
        stockQty: 3,
        priceSdg: 18000,
        warrantyDays: 30,
        active: false,
        newPart: NewPart(nameAr: 'حساس', categoryId: 'c1', modelIds: ['m1']),
      );
      final back = ListingDraft.fromParams(jsonDecode(jsonEncode(draft.toParams('shop1'))) as Json);
      expect(back.toParams('shop1'), draft.toParams('shop1'));
    });

    test('an edited listing keeps what open orders reserved', () {
      final l = ShopListing.fromJson({
        'id': 'l1',
        'version': 4,
        'part': {
          'id': 'p1',
          'name_ar': 'لمبة',
          'name_en': 'Bulb',
          'category_id': 'c1',
          'model_ids': <String>[],
        },
        'condition': 'NEW_OEM',
        'price_sdg': 12000,
        'stock_qty': 10,
        'available_qty': 7,
        'images': <String>[],
      });
      final edited = l.copyWith(stockQty: 20, version: 5);
      expect(edited.availableQty, 17);
      expect(edited.priceSdg, 12000);
      expect(edited.version, 5);
    });

    test('a shop order knows its fitting; a fitting knows where its parts are', () {
      final o = ShopSubOrder.fromJson({
        'id': 'so1',
        'shop_id': 'shop1',
        'status': 'READY',
        'fulfilment': 'TO_TECHNICIAN',
        'items': <Json>[],
        'events': <Json>[],
        'ref': '72491962',
        'payment_method': 'CASH',
        'placed_at': '2026-10-14T01:00:00Z',
        'buyer': {'name': 'أحمد', 'phone': '+249912000001'},
        'booking': {
          'id': 'b1',
          'ref': '60047982',
          'status': 'ACCEPTED',
          'start_at': '2026-10-15T14:00:00Z',
          'technician': {'name': 'عمر', 'phone': '+249912100001'},
        },
      });
      expect(o.booking!.status, BookingStatus.accepted);
      expect(o.booking!.technicianPhone, '+249912100001');

      final part = BookingPart.fromJson({
        'sub_order_id': 'so1',
        'shop_id': 'shop1',
        'name_ar': 'النور',
        'name_en': 'Al-Nour',
        'status': 'HANDED_TO_TECHNICIAN',
        'items_sdg': 45000,
      });
      expect(part.collected, isTrue);
      expect(part.itemsSdg, 45000);
    });

    test('the account says whether the user is a technician, and how far along', () {
      final a = Account.fromJson({
        'profile': {'id': 'u1', 'email': 'tech@x.invalid'},
        'roles': ['BUYER', 'TECHNICIAN'],
        'shops': <Json>[],
        'technician': {
          'technician_id': 't1',
          'status': 'SUSPENDED',
          'status_reason': 'شكاوى متكررة',
          'work_mode': 'BOTH',
        },
      });
      expect(a.technician!.status, PartnerStatus.suspended);
      expect(a.technician!.statusReason, 'شكاوى متكررة');
    });
  });

  test('the partner inbox asks for partner alerts only; templates come for every app', () async {
    server
      ..on('/rest/v1/notifications', (_) => jsonResponse(<Json>[]))
      ..on('/rest/v1/notification_templates', (_) => jsonResponse(<Json>[]));
    final repo = NotificationsRepository(server.client());
    await repo.list(app: 'partner');
    await repo.templates();
    expect(server.requests.first.url.queryParameters['app'], 'eq.partner');
    expect(
      server.requests.last.url.queryParameters.keys,
      isNot(contains('notification_codes.app')),
    );
  });

  test('the outbox lists what still waits, oldest first', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final outbox = Outbox(
      db,
      handlers: {'op': (_, _) async => throw const BackendException(BackendException.offlineCode)},
    );
    addTearDown(outbox.dispose);
    await outbox.add('op', {'n': 1});
    await outbox.add('op', {'n': 2});
    await outbox.flush();
    expect([for (final q in await outbox.queued()) q.payload['n']], [1, 2]);
  });
}
