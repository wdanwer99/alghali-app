import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_env.dart';

final appEnvProvider = Provider<AppEnv>((ref) => AppEnv.empty);

/// Connects the Supabase client. Safe to call without keys: it does nothing.
///
/// Reads retry once and give up after 20 seconds, so with a bad connection the screens
/// fall back to what is saved on the phone quickly instead of waiting on stalled requests.
Future<void> initBackend(AppEnv env) async {
  if (!env.isConfigured) return;
  await Supabase.initialize(
    url: env.supabaseUrl,
    publishableKey: env.supabasePublishableKey,
    postgrestOptions: const PostgrestClientOptions(
      retryCount: 1,
      requestTimeout: Duration(seconds: 20),
    ),
  );
}

sealed class BackendStatus {
  const BackendStatus();
}

class BackendNotConfigured extends BackendStatus {
  const BackendNotConfigured();
}

class BackendOk extends BackendStatus {
  const BackendOk(this.serverTime);
  final DateTime serverTime;
}

class BackendUnreachable extends BackendStatus {
  const BackendUnreachable(this.reason);
  final String reason;
}

/// Calls the `ping()` RPC to show whether the backend is reachable.
final backendStatusProvider = FutureProvider<BackendStatus>((ref) async {
  if (!ref.watch(appEnvProvider).isConfigured) return const BackendNotConfigured();
  try {
    final result = await Supabase.instance.client.rpc<Map<String, dynamic>>('ping');
    return BackendOk(DateTime.parse(result['server_time'] as String));
  } on Object catch (e) {
    return BackendUnreachable(e.toString());
  }
});
