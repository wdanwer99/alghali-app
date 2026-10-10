import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_env.dart';

final appEnvProvider = Provider<AppEnv>((ref) => AppEnv.empty);

/// Connects the Supabase client. Safe to call without keys: it does nothing.
Future<void> initBackend(AppEnv env) async {
  if (!env.isConfigured) return;
  await Supabase.initialize(url: env.supabaseUrl, publishableKey: env.supabasePublishableKey);
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
