import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

part 'app_database.g.dart';

/// Mutations made while offline, replayed in order by the sync engine (M4).
/// The idempotency key travels with the request so a replay never applies twice.
class OutboxEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get idempotencyKey => text().unique()();

  /// What to call, e.g. `rpc:cart_upsert`.
  TextColumn get operation => text()();

  /// JSON-encoded arguments.
  TextColumn get payload => text()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get nextAttemptAt => dateTime().nullable()();
}

/// Read-through cache for catalogue, garage, orders and the street map.
class CacheEntries extends Table {
  TextColumn get key => text()();
  TextColumn get json => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

@DriftDatabase(tables: [OutboxEntries, CacheEntries])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  /// On-device database file for one app (e.g. `alghali_buyer`).
  factory AppDatabase.open(String name) => AppDatabase(driftDatabase(name: name));

  @override
  int get schemaVersion => 1;

  Future<int> enqueue({
    required String idempotencyKey,
    required String operation,
    required String payload,
  }) => into(outboxEntries).insert(
    OutboxEntriesCompanion.insert(
      idempotencyKey: idempotencyKey,
      operation: operation,
      payload: payload,
    ),
    mode: InsertMode.insertOrIgnore,
  );

  /// Oldest first, so replays keep the order the user acted in.
  Future<List<OutboxEntry>> pending() =>
      (select(outboxEntries)..orderBy([(e) => OrderingTerm.asc(e.id)])).get();

  Future<void> removeOutbox(int id) => (delete(outboxEntries)..where((e) => e.id.equals(id))).go();

  /// Records a failed attempt; the entry waits until [nextAttemptAt].
  Future<void> retryOutboxLater(OutboxEntry e, {required String error, required DateTime at}) =>
      (update(outboxEntries)..where((x) => x.id.equals(e.id))).write(
        OutboxEntriesCompanion(
          attempts: Value(e.attempts + 1),
          lastError: Value(error),
          nextAttemptAt: Value(at),
        ),
      );

  Future<void> putCache(String key, String json) => into(cacheEntries).insertOnConflictUpdate(
    CacheEntriesCompanion.insert(key: key, json: json, updatedAt: DateTime.now().toUtc()),
  );

  Future<CacheEntry?> getCache(String key) =>
      (select(cacheEntries)..where((c) => c.key.equals(key))).getSingleOrNull();

  /// Forgets cached answers not refreshed since [before], except keys starting with
  /// one of [keep] (the catalogue).
  Future<int> pruneCache(DateTime before, {List<String> keep = const []}) =>
      (delete(cacheEntries)..where((c) {
            var cond = c.updatedAt.isSmallerThanValue(before);
            for (final k in keep) {
              cond = cond & c.key.like('$k%').not();
            }
            return cond;
          }))
          .go();

  /// Drops cached answers under [prefix] (e.g. a signed-out user's orders).
  Future<int> clearCache(String prefix) =>
      (delete(cacheEntries)..where((c) => c.key.like('$prefix%'))).go();

  /// Empties the outbox (signing out: queued changes belong to the old account).
  Future<int> clearOutbox() => delete(outboxEntries).go();
}

final appDatabaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError('Override appDatabaseProvider in main()'),
);
