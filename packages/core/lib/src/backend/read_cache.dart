import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestBuilder;

import '../db/app_database.dart';
import 'backend_error.dart';

/// The last answer of each read, kept on the phone so screens still show something with
/// no connection (brief §1: catalogue, garage, orders and the street map are cached).
///
/// Keys starting with `@` belong to the signed-in user and are stored under their id,
/// so another account on the same phone never sees them.
abstract class ReadCache {
  Future<Object?> read(String key);
  Future<void> write(String key, Object? json);

  /// Forgets the signed-in user's entries (on sign-out).
  Future<void> clearUser();

  /// Told after each read whether the network answered (true) or the saved copy was used
  /// because there was no connection (false), so the app can show it is offline.
  void reachable(bool online) {}
}

/// [ReadCache] in the app's Drift database (`cache_entries`).
class DriftReadCache extends ReadCache {
  DriftReadCache(this._db, {required this._userId, this._onReachable});

  final AppDatabase _db;
  final String? Function() _userId;
  final void Function(bool online)? _onReachable;

  @override
  void reachable(bool online) => _onReachable?.call(online);

  String? _key(String key) {
    if (!key.startsWith('@')) return 'c:$key';
    final uid = _userId();
    return uid == null ? null : 'u:$uid:${key.substring(1)}';
  }

  @override
  Future<Object?> read(String key) async {
    final k = _key(key);
    if (k == null) return null;
    final row = await _db.getCache(k);
    return row == null ? null : jsonDecode(row.json);
  }

  @override
  Future<void> write(String key, Object? json) async {
    final k = _key(key);
    if (k != null) await _db.putCache(k, jsonEncode(json));
  }

  @override
  Future<void> clearUser() async {
    final uid = _userId();
    if (uid != null) await _db.clearCache('u:$uid:');
  }
}

/// Null in tests and when no database is set up: reads go straight to the network.
final readCacheProvider = Provider<ReadCache?>((ref) => null);

/// How reads behave on a bad connection: one retry and 20 seconds per attempt, so the
/// saved copy shows soon instead of after a long wait. Set here because the Supabase
/// client applies its own options to function calls only, not to table reads.
abstract final class ReadPolicy {
  static int retries = 1;
  static Duration timeout = const Duration(seconds: 20);
}

/// Network first; with no connection, the last saved answer (else the OFFLINE error).
mixin CachedReads {
  ReadCache? get cache;

  Future<T> cachedRead<T>(
    String key,
    Future<Object?> Function() fetch,
    T Function(Object? raw) parse,
  ) async {
    try {
      final raw = await guard(() {
        final call = fetch();
        return call is PostgrestBuilder
            ? call.retry(count: ReadPolicy.retries, requestTimeout: ReadPolicy.timeout)
            : call;
      });
      final c = cache;
      if (c != null) {
        c.reachable(true);
        unawaited(c.write(key, raw).catchError((Object _) {}));
      }
      return parse(raw);
    } on BackendException catch (e) {
      final c = cache;
      if (!e.offline || c == null) rethrow;
      c.reachable(false);
      final saved = await c.read(key);
      if (saved == null) rethrow;
      return parse(saved);
    }
  }

  /// The saved answer without asking the network, for showing something at once.
  Future<T?> cachedPeek<T>(String key, T Function(Object? raw) parse) async {
    final saved = await cache?.read(key);
    return saved == null ? null : parse(saved);
  }
}
