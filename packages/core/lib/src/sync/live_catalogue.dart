import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../backend/repositories.dart';
import '../data/catalogue_data.dart';
import '../data/catalogue_snapshot.dart';
import '../data/platform_settings.dart';
import '../db/app_database.dart';
import '../models/catalogue.dart';

/// The offline catalogue (cars, categories, the street's zones and shops) and the public
/// settings, as last fetched, read from the phone before the first frame so the app
/// opens with something to show (brief §1).
class OfflineSeed {
  const OfflineSeed({this.snapshot, this.settings});

  static const none = OfflineSeed();

  static const snapshotKey = 'c:catalogue_snapshot';
  static const settingsKey = 'c:public_settings';

  /// Raw merged `catalogue_snapshot`; null before the first sync.
  final Json? snapshot;

  /// Raw `public_settings()`; null before the first sync.
  final Json? settings;

  static Future<OfflineSeed> load(AppDatabase db) async {
    Json? read(CacheEntry? e) => e == null ? null : jsonDecode(e.json) as Json;
    try {
      return OfflineSeed(
        snapshot: read(await db.getCache(snapshotKey)),
        settings: read(await db.getCache(settingsKey)),
      );
    } on Object {
      return none; // a corrupt cache never blocks the app; the next sync replaces it
    }
  }
}

/// Merges a `catalogue_snapshot(since)` delta into the cached snapshot: rows replace the
/// ones with the same id, new rows are added. A full answer replaces everything.
/// Deactivated rows and shops no longer approved stay in the raw data and are dropped
/// when it is read ([CatalogueSnapshot.fromJson]).
Json mergeSnapshot(Json? base, Json delta) {
  if (base == null || delta['full'] == true) return {...delta, 'full': true};
  final out = <String, dynamic>{...base, 'server_time': delta['server_time'], 'full': true};
  for (final MapEntry(:key, :value) in delta.entries) {
    if (value is! List) continue;
    final rows = <String, Json>{
      for (final r in [...?(base[key] as List?)?.cast<Json>()]) r['id'] as String: r,
    };
    for (final r in value.cast<Json>()) {
      rows[r['id'] as String] = {...?rows[r['id']], ...r};
    }
    out[key] = rows.values.toList();
  }
  return out;
}

final offlineSeedProvider = Provider<OfflineSeed>((ref) => OfflineSeed.none);

/// The live catalogue: the cached snapshot at once, then a sync that fetches only what
/// changed since the last one ([refresh], also on pull-to-refresh and app resume).
class LiveCatalogue extends Notifier<CatalogueData> {
  Json? _raw;
  Future<bool>? _syncing;
  DateTime? _syncedAt;

  @override
  CatalogueData build() {
    _raw = ref.watch(offlineSeedProvider).snapshot;
    Future.microtask(refresh);
    return _parse(_raw);
  }

  static CatalogueData _parse(Json? raw) {
    if (raw == null) return CatalogueData.empty;
    try {
      return CatalogueData.fromSnapshot(CatalogueSnapshot.fromJson(raw));
    } on Object {
      return CatalogueData.empty;
    }
  }

  /// Whether anything has been loaded yet (first launch without a connection: no).
  bool get loaded => _raw != null;

  /// Fetches the changes since the last sync. [ifOlderThan] skips it when the last sync
  /// is more recent. Failures (no connection) keep what is cached; the answer says
  /// whether the catalogue is up to date.
  Future<bool> refresh({Duration? ifOlderThan}) {
    final last = _syncedAt;
    if (ifOlderThan != null && last != null && DateTime.now().difference(last) < ifOlderThan) {
      return Future.value(true);
    }
    return _syncing ??= _sync()
        .then((_) => true, onError: (Object _) => false)
        .whenComplete(() => _syncing = null);
  }

  Future<void> _sync() async {
    final repo = ref.read(catalogueRepositoryProvider);
    final since = DateTime.tryParse(_raw?['server_time'] as String? ?? '');
    final delta = await repo.snapshotJson(since: since);
    final merged = mergeSnapshot(_raw, delta);
    _raw = merged;
    _syncedAt = DateTime.now();
    state = _parse(merged);
    final db = ref.read(appDatabaseOrNullProvider);
    await db?.putCache(OfflineSeed.snapshotKey, jsonEncode(merged));
  }
}

final liveCatalogueProvider = NotifierProvider<LiveCatalogue, CatalogueData>(LiveCatalogue.new);

/// The public settings (fees, Bankak account, windows): cached, then refreshed.
class LiveSettings extends Notifier<PlatformSettings> {
  @override
  PlatformSettings build() {
    final seed = ref.watch(offlineSeedProvider).settings;
    Future.microtask(refresh);
    return _parse(seed) ?? PlatformSettings.demo;
  }

  static PlatformSettings? _parse(Json? raw) {
    if (raw == null) return null;
    try {
      return PlatformSettings.fromJson(raw);
    } on Object {
      return null;
    }
  }

  Future<void> refresh() async {
    try {
      final raw = await ref.read(catalogueRepositoryProvider).settingsJson();
      final parsed = _parse(raw);
      if (parsed == null) return;
      state = parsed;
      await ref.read(appDatabaseOrNullProvider)?.putCache(OfflineSeed.settingsKey, jsonEncode(raw));
    } on Object {
      // Keep the cached settings; the server re-checks every amount anyway.
    }
  }
}

final liveSettingsProvider = NotifierProvider<LiveSettings, PlatformSettings>(LiveSettings.new);

/// The app database when there is one (null in tests that don't set it up).
final appDatabaseOrNullProvider = Provider<AppDatabase?>((ref) {
  try {
    return ref.watch(appDatabaseProvider);
  } on Object {
    return null;
  }
});
