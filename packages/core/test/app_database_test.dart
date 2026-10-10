import 'package:alghali_core/alghali_core.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('outbox keeps entries in the order they were queued', () async {
    await db.enqueue(idempotencyKey: 'k1', operation: 'rpc:cart_upsert', payload: '{"qty":1}');
    await db.enqueue(idempotencyKey: 'k2', operation: 'rpc:cart_remove', payload: '{}');

    final pending = await db.pending();
    expect(pending.map((e) => e.idempotencyKey), ['k1', 'k2']);
    expect(pending.first.attempts, 0);
  });

  test('queuing the same idempotency key twice keeps one entry', () async {
    await db.enqueue(idempotencyKey: 'same', operation: 'rpc:a', payload: '{}');
    await db.enqueue(idempotencyKey: 'same', operation: 'rpc:a', payload: '{}');

    expect(await db.pending(), hasLength(1));
  });

  test('cache overwrites by key', () async {
    await db.putCache('catalogue', '{"v":1}');
    await db.putCache('catalogue', '{"v":2}');

    expect((await db.getCache('catalogue'))?.json, '{"v":2}');
    expect(await db.getCache('missing'), isNull);
  });
}
