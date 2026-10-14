import 'dart:async';

import 'package:alghali_core/alghali_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'bookings.dart';
import 'inbox.dart';
import 'orders.dart';
import 'outbox.dart';
import 'requests.dart';
import 'session.dart';

/// This build's number, sent with the push token and compared with
/// `latest_app_versions.buyer` (D-058). Keep it equal to the `+N` in pubspec.yaml.
const buyerBuild = 4;

/// An alert that arrived while the app was open, for the banner on screen.
typedef ForegroundAlert = ({String code, Map<String, String> data});

/// Push (D-109): registers this phone once the buyer is signed in (and again when the
/// token changes or the language does), refreshes what an alert is about when one
/// arrives, and opens the right screen when one is tapped.
class PushController extends Notifier<int> {
  final _alerts = StreamController<ForegroundAlert>.broadcast();
  final _taps = StreamController<String>.broadcast();

  /// Alerts received with the app open.
  Stream<ForegroundAlert> get alerts => _alerts.stream;

  /// Routes to open, from tapped alerts.
  Stream<String> get taps => _taps.stream;

  @override
  int build() {
    final push = ref.watch(pushClientProvider);
    final subs = <StreamSubscription<Object?>>[
      push.tokenRefresh.listen((_) => unawaited(_register())),
      push.foreground.listen(_onForeground),
      push.taps.listen(_onTap),
    ];
    ref.onDispose(() {
      for (final s in subs) {
        unawaited(s.cancel());
      }
      unawaited(_alerts.close());
      unawaited(_taps.close());
    });
    ref.listen(sessionProvider.select((s) => s.userId), (prev, next) {
      if (next != null && next != prev) unawaited(_register(askPermission: prev == null));
    }, fireImmediately: true);
    ref.listen(localeControllerProvider.select((s) => s.locale.languageCode), (prev, next) {
      if (prev == null || prev == next || !ref.read(sessionProvider).signedIn) return;
      unawaited(_register());
      unawaited(queue(ref, BuyerOps.profile, {'locale': next}));
    });
    unawaited(
      push.initialTap().then((data) {
        if (data != null) _onTap(data);
      }),
    );
    return 0;
  }

  Future<void> _register({bool askPermission = false}) async {
    if (!ref.read(sessionProvider).signedIn) return;
    final push = ref.read(pushClientProvider);
    try {
      if (askPermission) await push.requestPermission();
      final token = await push.token();
      if (token == null) return;
      await ref
          .read(authRepositoryProvider)
          .registerDevice(
            app: 'buyer',
            fcmToken: token,
            appBuild: buyerBuild,
            locale: ref.read(localeControllerProvider).locale.languageCode,
          );
      state++;
    } on Object {
      // Offline or no Google Play services: alerts still reach the in-app inbox.
    }
  }

  void _onForeground(PushData data) {
    final code = data['code'] ?? '';
    _refreshFor(code, data);
    _alerts.add((code: code, data: data));
  }

  void _onTap(PushData data) {
    final code = data['code'] ?? '';
    _refreshFor(code, data);
    final route = alertRoute(code, data);
    if (route != null) _taps.add(route);
  }

  /// What an alert is about changed on the server: fetch it again.
  void _refreshFor(String code, PushData data) {
    unawaited(ref.read(inboxProvider.notifier).refresh());
    if (data['order_id'] != null) {
      unawaited(ref.read(ordersProvider.notifier).refresh());
      ref.invalidate(orderProvider(data['order_id']!));
    }
    if (data['booking_id'] != null) {
      unawaited(ref.read(bookingsProvider.notifier).refresh());
      ref.invalidate(bookingProvider(data['booking_id']!));
    }
    if (data['request_id'] != null) unawaited(ref.read(requestsProvider.notifier).refresh());
  }
}

final pushControllerProvider = NotifierProvider<PushController, int>(PushController.new);
