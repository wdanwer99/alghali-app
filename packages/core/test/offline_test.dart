import 'package:alghali_core/alghali_core.dart';
import 'package:alghali_core/testing.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fixtures.dart';

void main() {
  group('outbox', () {
    late AppDatabase db;
    var now = DateTime.utc(2026, 10, 14, 10);

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      now = DateTime.utc(2026, 10, 14, 10);
    });
    tearDown(() => db.close());

    test('replays changes in the order they were made, each with its own key', () async {
      final seen = <(String, String)>[];
      final outbox = Outbox(
        db,
        clock: () => now,
        handlers: {'op': (p, idem) async => seen.add((p['n'] as String, idem))},
      );
      await outbox.add('op', {'n': 'a'}, idem: 'k1');
      await outbox.add('op', {'n': 'b'}, idem: 'k2');
      await outbox.flush();
      expect(seen, [('a', 'k1'), ('b', 'k2')]);
      expect(await db.pending(), isEmpty);
      expect(outbox.pending.value, 0);
      outbox.dispose();
    });

    test('with no connection it keeps the change, then replays it with the same key', () async {
      var online = false;
      final seen = <String>[];
      final outbox = Outbox(
        db,
        clock: () => now,
        handlers: {
          'op': (p, idem) async {
            if (!online) throw const BackendException(BackendException.offlineCode);
            seen.add(idem);
          },
        },
      );
      await outbox.add('op', {}, idem: 'k1');
      await outbox.add('op', {}, idem: 'k2');
      expect(await outbox.flush(), 2);
      expect((await db.pending()).first.attempts, 1);

      // Not due yet: the back-off holds it.
      online = true;
      expect(await outbox.flush(), 2);

      now = now.add(const Duration(minutes: 1));
      expect(await outbox.flush(), 0);
      expect(seen, ['k1', 'k2']);
      outbox.dispose();
    });

    test('a refusal is reported and dropped; later changes still go out', () async {
      final seen = <String>[];
      final outbox = Outbox(
        db,
        clock: () => now,
        handlers: {
          'bad': (_, _) async => throw const BackendException('INVALID_PHONE', status: 400),
          'good': (p, _) async => seen.add(p['n'] as String),
        },
      );
      final results = <OutboxResult>[];
      final sub = outbox.results.listen(results.add);
      await outbox.add('bad', {});
      await outbox.add('good', {'n': 'x'});
      await outbox.flush();
      await Future<void>.delayed(Duration.zero);
      expect(seen, ['x']);
      expect(results.map((r) => r.error?.code), ['INVALID_PHONE', null]);
      await sub.cancel();
      outbox.dispose();
    });

    test('queuing the same key twice sends it once', () async {
      var calls = 0;
      final outbox = Outbox(db, clock: () => now, handlers: {'op': (_, _) async => calls++});
      await db.enqueue(idempotencyKey: 'same', operation: 'op', payload: '{}');
      await db.enqueue(idempotencyKey: 'same', operation: 'op', payload: '{}');
      await outbox.flush();
      expect(calls, 1);
      outbox.dispose();
    });
  });

  group('offline catalogue', () {
    Json row(String id, [Json extra = const {}]) => {'id': id, ...extra};

    test('a delta replaces changed rows, adds new ones and keeps the rest', () {
      final base = {
        'server_time': '2026-10-14T00:00:00Z',
        'full': true,
        'shops': [
          row('s1', {'name_ar': 'أ', 'status': 'APPROVED'}),
          row('s2', {'name_ar': 'ب', 'status': 'APPROVED'}),
        ],
        'zones': [row('z1')],
      };
      final delta = {
        'server_time': '2026-10-14T06:00:00Z',
        'full': false,
        'shops': [
          {'id': 's2', 'status': 'SUSPENDED'},
          row('s3', {'name_ar': 'ج', 'status': 'APPROVED'}),
        ],
        'zones': <Json>[],
      };
      final merged = mergeSnapshot(base, delta);
      expect(merged['server_time'], '2026-10-14T06:00:00Z');
      final shops = (merged['shops'] as List).cast<Json>();
      expect(shops.map((s) => s['id']), ['s1', 's2', 's3']);
      // The suspended shop keeps its other columns but is dropped when read.
      expect(shops[1]['name_ar'], 'ب');
      expect(shops[1]['status'], 'SUSPENDED');
      expect((merged['zones'] as List).length, 1);
    });

    test('a full answer replaces the cache', () {
      final merged = mergeSnapshot(
        {
          'shops': [row('old')],
        },
        {
          'full': true,
          'server_time': 't',
          'shops': [row('new')],
        },
      );
      expect((merged['shops'] as List).cast<Json>().map((s) => s['id']), ['new']);
    });

    test('the merged snapshot reads as the catalogue, without shops no longer approved', () {
      final snap = fixture('catalogue_snapshot')! as Json;
      final shop = (snap['shops'] as List).cast<Json>().first;
      final merged = mergeSnapshot(snap, {
        'server_time': '2026-10-15T00:00:00Z',
        'full': false,
        'shops': [
          {'id': shop['id'], 'status': 'SUSPENDED'},
        ],
      });
      final c = CatalogueData.fromSnapshot(CatalogueSnapshot.fromJson(merged));
      expect(c.hasShop(shop['id'] as String), isFalse);
      expect(c.categories, isNotEmpty);
      // Unknown ids read as empty placeholders instead of throwing.
      expect(c.shop('gone').name.ar, '');
      expect(c.variant('gone').years, isNotEmpty);
    });
  });

  group('saved answers', () {
    test('with no connection a read answers from the last saved copy', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final reachable = <bool>[];
      final cache = DriftReadCache(db, userId: () => 'u1', onReachable: reachable.add);
      final server = FakeServer()
        ..on('/rest/v1/rpc/my_bookings', (_) => jsonResponse(fixture('my_bookings')));
      final repo = BookingsRepository(server.client(), cache: cache);

      final first = await repo.mine();
      await Future<void>.delayed(Duration.zero);
      server.offline = true;
      final again = await repo.mine();
      expect(again.map((b) => b.id), first.map((b) => b.id));
      expect(reachable, [true, false]);
      expect(await repo.peek(), hasLength(first.length));

      // Another account on the same phone sees nothing of it.
      final other = BookingsRepository(
        server.client(),
        cache: DriftReadCache(db, userId: () => 'u2'),
      );
      expect(
        other.mine(),
        throwsA(isA<BackendException>().having((e) => e.offline, 'offline', true)),
      );
    });
  });

  group('alert wording', () {
    test('fills placeholders like the push dispatcher', () {
      final t = AlertTemplates.fromRows([
        {
          'code': 'PAYMENT_REJECTED',
          'locale': 'ar',
          'title': 'لم نتمكن',
          'body': 'أرسله قبل {pay_by}.',
        },
        {
          'code': 'PAYMENT_REJECTED',
          'locale': 'en',
          'title': 'Not confirmed',
          'body': 'Send it by {pay_by} for {amount_sdg}.',
        },
      ]);
      final item = InboxItem(
        id: '1',
        code: 'PAYMENT_REJECTED',
        payload: const {'pay_by': '2026-10-16T14:00:00Z', 'amount_sdg': 12000},
        at: DateTime.utc(2026),
      );
      expect(t.render(item, 'ar')!.body, 'أرسله قبل الجمعة 16 أكتوبر 4:00 م.');
      expect(t.render(item, 'en')!.body, 'Send it by Fri 16 Oct 4:00 PM for SDG 12,000.');
      expect(
        t.render(
          InboxItem(id: '2', code: 'UNKNOWN', payload: const {}, at: DateTime.utc(2026)),
          'ar',
        ),
        isNull,
      );
    });

    test('every captured template renders with an empty payload', () {
      final t = AlertTemplates.fromRows((fixture('templates')! as List).cast<Json>());
      for (final r in (fixture('templates')! as List).cast<Json>()) {
        final text = t.render(
          InboxItem(id: '', code: r['code'] as String, payload: const {}, at: DateTime.utc(2026)),
          r['locale'] as String,
        );
        expect(text?.title, isNotEmpty, reason: r['code'] as String);
        expect(text!.body, isNot(contains('{')), reason: r['code'] as String);
      }
    });

    test('kinds follow the code', () {
      expect(alertKind('PAYMENT_CONFIRMED'), NotificationKind.payment);
      expect(alertKind('ORDER_READY'), NotificationKind.order);
      expect(alertKind('TECH_EN_ROUTE'), NotificationKind.booking);
      expect(alertKind('NEW_OFFER'), NotificationKind.offer);
      expect(alertKind('DISPUTE_REPLY'), NotificationKind.system);
    });
  });
}
