import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'backend.dart';
import 'repositories.dart';

/// How far the server's clock is from the phone's, from one `ping()`: positive when the
/// phone is behind. Null when the call fails. Under a minute counts as none: that much is
/// network delay, and countdowns would otherwise jump by a second after every sync.
Future<Duration?> measureClockOffset(
  SupabaseClient client, {
  DateTime Function() now = DateTime.now,
}) async {
  try {
    final sent = now();
    final row = await client.rpc<Map<String, dynamic>>('ping');
    final back = now();
    final server = DateTime.parse(row['server_time'] as String);
    final offset = server.difference(sent.add(back.difference(sent) ~/ 2));
    return offset.abs() < const Duration(minutes: 1) ? Duration.zero : offset;
  } on Object {
    return null;
  }
}

/// The server's clock as seen from this phone (D-143). Phones with automatic time switched
/// off are often minutes or hours out, and a job offer's 20 minutes then looked over before
/// they began. The apps [sync] when they start and when they come back to the front;
/// [clockProvider] adds the offset.
class ServerClockOffset extends Notifier<Duration> {
  @override
  Duration build() => Duration.zero;

  /// Measures again; offline or unconfigured, the last offset stays.
  Future<void> sync() async {
    if (!ref.read(appEnvProvider).isConfigured) return;
    final offset = await measureClockOffset(ref.read(supabaseClientProvider));
    if (offset != null && ref.mounted) state = offset;
  }
}

final serverClockOffsetProvider = NotifierProvider<ServerClockOffset, Duration>(
  ServerClockOffset.new,
);
