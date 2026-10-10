import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../backend/backend.dart';
import '../l10n/generated/core_localizations.dart';

class BackendStatusChip extends ConsumerWidget {
  const BackendStatusChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = CoreLocalizations.of(context);
    final status = ref.watch(backendStatusProvider);
    final (label, icon) = switch (status) {
      AsyncData(value: BackendOk()) => (t.backendOk, Icons.cloud_done_outlined),
      AsyncData(value: BackendNotConfigured()) => (
        t.backendNotConfigured,
        Icons.cloud_off_outlined,
      ),
      AsyncData(value: BackendUnreachable()) || AsyncError() => (t.backendError, Icons.cloud_off),
      _ => (t.backendChecking, Icons.cloud_sync_outlined),
    };
    return Chip(avatar: Icon(icon, size: 18), label: Text('${t.backendStatus}: $label'));
  }
}
