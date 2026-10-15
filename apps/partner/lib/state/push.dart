import 'dart:async';

import 'package:alghali_core/alghali_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'inbox.dart';
import 'outbox.dart';
import 'session.dart';
import 'shop.dart';
import 'tech.dart';

/// This build's number, sent with the push token and compared with
/// `latest_app_versions.partner` (D-058). Keep it equal to the `+N` in pubspec.yaml.
const partnerBuild = 5;

/// An alert that arrived while the app was open, for the banner on screen.
typedef ForegroundAlert = ({String code, Map<String, String> data});

/// Push (D-109): registers this phone for the partner app once signed in (and again when
/// the token or the language changes), refreshes what an alert is about when one
/// arrives, and opens the right screen when one is tapped.
class PushController extends Notifier<int> {
  final _alerts = StreamController<ForegroundAlert>.broadcast();
  final _taps = StreamController<({String route, PartnerRole role})>.broadcast();

  /// Alerts received with the app open.
  Stream<ForegroundAlert> get alerts => _alerts.stream;

  /// Screens to open, from tapped alerts.
  Stream<({String route, PartnerRole role})> get taps => _taps.stream;

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
    ref.listen(partnerSessionProvider.select((s) => s.userId), (prev, next) {
      if (next != null && next != prev) unawaited(_register(askPermission: prev == null));
    }, fireImmediately: true);
    ref.listen(localeControllerProvider.select((s) => s.locale.languageCode), (prev, next) {
      if (prev == null || prev == next || !ref.read(partnerSessionProvider).signedIn) return;
      unawaited(_register());
      unawaited(queue(ref, PartnerOps.profile, {'locale': next}));
    });
    unawaited(
      push.initialTap().then((data) {
        if (data != null) _onTap(data);
      }),
    );
    return 0;
  }

  Future<void> _register({bool askPermission = false}) async {
    if (!ref.read(partnerSessionProvider).signedIn) return;
    final push = ref.read(pushClientProvider);
    try {
      if (askPermission) await push.requestPermission();
      final token = await push.token();
      if (token == null) return;
      await ref
          .read(authRepositoryProvider)
          .registerDevice(
            app: 'partner',
            fcmToken: token,
            appBuild: partnerBuild,
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
    final target = alertRoute(code, data, current: ref.read(partnerSessionProvider).role);
    if (target != null) _taps.add(target);
  }

  /// What an alert is about changed on the server: fetch it again.
  void _refreshFor(String code, PushData data) {
    unawaited(ref.read(inboxProvider.notifier).refresh());
    if (data['sub_order_id'] != null || code == 'NEW_ORDER') {
      unawaited(ref.read(shopOrdersProvider.notifier).refresh());
    }
    if (code == 'NEW_PART_REQUEST') unawaited(ref.read(quotesProvider.notifier).refresh());
    if (code == 'NEW_MESSAGE') unawaited(ref.read(shopChatsProvider.notifier).refresh());
    if (data['booking_id'] != null) {
      unawaited(ref.read(techJobsProvider.notifier).refresh());
      ref.invalidate(jobDetailProvider(data['booking_id']!));
    }
    if (code == 'TECHNICIAN_STATUS') {
      unawaited(ref.read(partnerSessionProvider.notifier).refreshAccount());
    }
    if (code == 'PAYOUT_PAID') {
      ref
        ..invalidate(shopStatementProvider)
        ..invalidate(techStatementProvider);
    }
  }
}

final pushControllerProvider = NotifierProvider<PushController, int>(PushController.new);
