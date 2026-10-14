import 'dart:async';

import 'package:alghali_core/alghali_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'state/connection.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerFontLicenses();
  final env = AppEnv.fromEnvironment();
  await initBackend(env);
  final prefs = await SharedPreferences.getInstance();
  final db = AppDatabase.open('alghali_buyer');
  // The catalogue and settings as last synced, so the first screen has them offline.
  final seed = await OfflineSeed.load(db);
  unawaited(
    db
        .pruneCache(
          DateTime.now().toUtc().subtract(const Duration(days: 30)),
          keep: [OfflineSeed.snapshotKey, OfflineSeed.settingsKey],
        )
        .catchError((Object _) => 0),
  );
  final push = await FirebasePush.init(env);

  late final ProviderContainer container;
  final cache = DriftReadCache(
    db,
    userId: () => env.isConfigured ? container.read(authRepositoryProvider).userId : null,
    onReachable: (online) {
      final c = container.read(onlineProvider.notifier);
      online ? c.online() : c.offline();
    },
  );
  container = ProviderContainer(
    overrides: [
      appEnvProvider.overrideWithValue(env),
      sharedPreferencesProvider.overrideWithValue(prefs),
      appDatabaseProvider.overrideWithValue(db),
      offlineSeedProvider.overrideWithValue(seed),
      readCacheProvider.overrideWithValue(cache),
      pushClientProvider.overrideWithValue(push),
      ...liveDataOverrides,
    ],
    // Screens refresh on their own (pull down, app resume, push); no automatic retries.
    retry: (_, _) => null,
  );
  runApp(UncontrolledProviderScope(container: container, child: const BuyerApp()));
}
