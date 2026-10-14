import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show ValueListenable, ValueNotifier, immutable;

import '../backend/backend_error.dart';
import '../db/app_database.dart';
import '../models/catalogue.dart';

/// Runs one queued change against the backend. [idem] is the entry's idempotency key,
/// the same on every attempt, so a replay after a lost answer never applies twice.
typedef OutboxHandler = Future<void> Function(Json payload, String idem);

/// What became of a queued change.
@immutable
class OutboxResult {
  const OutboxResult(this.operation, this.payload, {this.error});

  final String operation;
  final Json payload;

  /// Null when it went through; otherwise the backend's refusal (it won't be retried).
  final BackendException? error;

  bool get ok => error == null;
}

/// Changes made without a connection wait here and go out in the order they were made
/// (brief §8: "Offline outbox in packages/core"). Each entry keeps its idempotency key,
/// so the backend applies it once however often it is replayed.
///
/// - [add] stores the change, then tries to send everything due.
/// - A connection problem stops the run and keeps the entry for later (back-off up to
///   five minutes); [flush] runs again on a timer, when the app returns to the
///   foreground and after each new change.
/// - A refusal (any other [BackendException]) drops the entry and reports it on
///   [results], so the screen can say what didn't go through.
class Outbox {
  Outbox(
    this._db, {
    required this._handlers,
    this._clock = DateTime.now,
    this._retryEvery = const Duration(seconds: 30),
  });

  final AppDatabase _db;
  final Map<String, OutboxHandler> _handlers;
  final DateTime Function() _clock;
  final Duration _retryEvery;

  final _results = StreamController<OutboxResult>.broadcast();
  final _pending = ValueNotifier<int>(0);
  Timer? _timer;
  Future<int>? _running;
  Future<int>? _next;

  /// How many changes are still waiting to be sent.
  ValueListenable<int> get pending => _pending;

  Stream<OutboxResult> get results => _results.stream;

  /// Queues [operation] (a key of the handlers) and tries to send it straight away.
  Future<void> add(String operation, Json payload, {String? idem}) async {
    assert(_handlers.containsKey(operation), 'no outbox handler for $operation');
    await _db.enqueue(
      idempotencyKey: idem ?? newIdempotencyKey(),
      operation: operation,
      payload: jsonEncode(payload),
    );
    unawaited(flush());
  }

  /// Sends every due entry, oldest first. Returns how many are still waiting.
  /// A call made while a run is going waits for it, then runs once more (the running one
  /// may have missed what was just queued).
  Future<int> flush() {
    final current = _running;
    if (current == null) {
      return _running = _flush().whenComplete(() => _running = null);
    }
    return _next ??= current.then((_) {
      _next = null;
      return flush();
    });
  }

  Future<int> _flush() async {
    final now = _clock().toUtc();
    for (final e in await _db.pending()) {
      // Order matters: nothing goes out ahead of an older change still backing off.
      final wait = e.nextAttemptAt;
      if (wait != null && wait.isAfter(now)) break;
      final handler = _handlers[e.operation];
      final payload = jsonDecode(e.payload) as Json;
      if (handler == null) {
        await _db.removeOutbox(e.id);
        continue;
      }
      try {
        await handler(payload, e.idempotencyKey);
        await _db.removeOutbox(e.id);
        _results.add(OutboxResult(e.operation, payload));
      } on Object catch (error) {
        final failure = BackendException.from(error);
        if (failure.offline || failure.code == 'SESSION_EXPIRED' || (failure.status ?? 0) >= 500) {
          // Keep the order: nothing after this entry goes out before it.
          final wait = Duration(seconds: (15 << e.attempts.clamp(0, 4)).clamp(15, 300));
          await _db.retryOutboxLater(e, error: failure.code, at: _clock().toUtc().add(wait));
          break;
        }
        await _db.removeOutbox(e.id);
        _results.add(OutboxResult(e.operation, payload, error: failure));
      }
    }
    final left = (await _db.pending()).length;
    _pending.value = left;
    _schedule(left);
    return left;
  }

  void _schedule(int left) {
    _timer?.cancel();
    _timer = left == 0 ? null : Timer(_retryEvery, () => unawaited(flush()));
  }

  /// Forgets everything queued (the user signed out).
  Future<void> clear() async {
    await _db.clearOutbox();
    _pending.value = 0;
    _schedule(0);
  }

  void dispose() {
    _timer?.cancel();
    unawaited(_results.close());
    _pending.dispose();
  }
}
