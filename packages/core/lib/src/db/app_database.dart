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

  Future<void> putCache(String key, String json) => into(cacheEntries).insertOnConflictUpdate(
    CacheEntriesCompanion.insert(key: key, json: json, updatedAt: DateTime.now().toUtc()),
  );

  Future<CacheEntry?> getCache(String key) =>
      (select(cacheEntries)..where((c) => c.key.equals(key))).getSingleOrNull();
}

final appDatabaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError('Override appDatabaseProvider in main()'),
);
