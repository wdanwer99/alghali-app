import 'dart:async';

import 'package:alghali_core/alghali_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:material_ui/material_ui.dart';

import 'l10n/generated/app_localizations.dart';
import 'router.dart';
import 'state/bookings.dart';
import 'state/inbox.dart';
import 'state/orders.dart';
import 'state/outbox.dart';
import 'state/push.dart';
import 'widgets/buyer_widgets.dart';

/// The catalogue and settings come from the server (cached on the phone), not the
/// sample data the core package falls back to.
final liveDataOverrides = <Override>[
  catalogueProvider.overrideWith((ref) => ref.watch(liveCatalogueProvider)),
  platformSettingsProvider.overrideWith((ref) => ref.watch(liveSettingsProvider)),
];

/// Snack bars shown from outside a screen (alerts that arrive, outbox refusals).
final messengerKey = GlobalKey<ScaffoldMessengerState>();

class BuyerApp extends ConsumerStatefulWidget {
  const BuyerApp({super.key});

  @override
  ConsumerState<BuyerApp> createState() => _BuyerAppState();
}

class _BuyerAppState extends ConsumerState<BuyerApp> {
  late final AppLifecycleListener _lifecycle;
  final _subs = <StreamSubscription<Object?>>[];

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _resumed);
    final push = ref.read(pushControllerProvider.notifier);
    _subs
      ..add(push.taps.listen((route) => ref.read(routerProvider).push(route)))
      ..add(push.alerts.listen(_showAlert));
    final outbox = ref.read(outboxProvider);
    if (outbox != null) _subs.add(outbox.results.listen(_outboxResult));
    unawaited(ref.read(serverClockOffsetProvider.notifier).sync());
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    for (final s in _subs) {
      unawaited(s.cancel());
    }
    super.dispose();
  }

  /// Back in the app: send what waited, and fetch what may have changed meanwhile
  /// (the phone's clock too).
  void _resumed() {
    unawaited(ref.read(serverClockOffsetProvider.notifier).sync());
    unawaited(ref.read(outboxProvider)?.flush());
    unawaited(
      ref.read(liveCatalogueProvider.notifier).refresh(ifOlderThan: const Duration(hours: 1)),
    );
    unawaited(ref.read(inboxProvider.notifier).refresh());
    unawaited(ref.read(ordersProvider.notifier).refresh());
    unawaited(ref.read(bookingsProvider.notifier).refresh());
  }

  /// A context under the app's localizations (the messenger sits above them).
  BuildContext? get _screen => ref.read(routerProvider).routerDelegate.navigatorKey.currentContext;

  Future<void> _showAlert(ForegroundAlert alert) async {
    // The server's wording (already in the reader's language), else the templates.
    final sent = alert.data['_title'];
    final text = sent != null
        ? (title: sent, body: alert.data['_body'] ?? '')
        : (await ref.read(alertTemplatesProvider.future)).render(
            InboxItem(id: '', code: alert.code, payload: alert.data, at: DateTime.now()),
            ref.read(localeControllerProvider).locale.languageCode,
          );
    final context = _screen;
    if (text == null || context == null || !context.mounted) return;
    final route = alertRoute(alert.code, alert.data);
    messengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('${text.title}\n${text.body}'),
          duration: const Duration(seconds: 6),
          action: route == null
              ? null
              : SnackBarAction(
                  label: CoreLocalizations.of(context).actionOpen,
                  onPressed: () => ref.read(routerProvider).push(route),
                ),
        ),
      );
  }

  void _outboxResult(OutboxResult r) {
    final error = r.error;
    final context = _screen;
    if (error == null || context == null) return;
    final core = CoreLocalizations.of(context);
    messengerKey.currentState?.showSnackBar(
      SnackBar(content: Text(core.notSent(core.error(error)))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final catalogue = ref.watch(catalogueProvider);
    ref.watch(pushControllerProvider);
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      scaffoldMessengerKey: messengerKey,
      locale: ref.watch(localeControllerProvider.select((s) => s.locale)),
      supportedLocales: supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        CoreLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ref.watch(themeModeProvider),
      routerConfig: ref.watch(routerProvider),
      debugShowCheckedModeBanner: false,
      // Below the minimum build, only the update screen (D-058).
      builder: (context, child) => CatalogueScope(
        catalogue: catalogue,
        child: SplashGate(
          // The session and the saved catalogue are loaded in main(), before the first frame.
          ready: true,
          child: UpdateGate(
            release: ref.watch(platformSettingsProvider).buyerRelease,
            appBuild: buyerBuild,
            child: child!,
          ),
        ),
      ),
    );
  }
}

extension AppL10n on BuildContext {
  AppLocalizations get t => AppLocalizations.of(this);
}
