import 'dart:async';

import 'package:alghali_core/alghali_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the last backend read found no connection (told by the read cache): screens
/// then show the "you're offline, showing saved data" banner over what was cached.
class ConnectionController extends Notifier<bool> {
  @override
  bool build() => true;

  void online() {
    if (!state) state = true;
  }

  void offline() {
    if (state) state = false;
  }

  /// Records what [error] says about the connection.
  void sawError(Object error) {
    if (error is BackendException && error.offline) offline();
  }
}

final onlineProvider = NotifierProvider<ConnectionController, bool>(ConnectionController.new);

/// Shared "cache first, then the network" loading for the buyer's lists: shows the saved
/// copy at once (if any), then replaces it with a fresh one. With no connection the
/// repositories answer from the saved copy themselves.
mixin CachedList<T> on AsyncNotifier<T> {
  Future<T?> peek() async => null;
  Future<T> fetch();

  Future<T> load() async {
    final saved = await peek().catchError((Object _) => null);
    if (saved != null) {
      unawaited(Future.microtask(refresh));
      return saved;
    }
    return fetch();
  }

  /// Fetches again; a failure keeps what is shown (or shows the error if nothing is).
  Future<void> refresh() async {
    try {
      final fresh = await fetch();
      if (ref.mounted) state = AsyncData(fresh);
    } on Object catch (e, st) {
      if (ref.mounted && !state.hasValue) state = AsyncError(e, st);
    }
  }
}
