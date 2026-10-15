import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../backend/backend.dart';
import '../backend/backend_error.dart';
import '../l10n/labels.dart';
import '../l10n/localized.dart';
import '../sync/connection.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import 'common.dart';

/// The thumbnail link for a photo in `media-public` (null when there is none).
String? thumbUrl(WidgetRef ref, String? baseKey, {String size = 'thumb'}) {
  if (baseKey == null || baseKey.isEmpty) return null;
  final env = ref.watch(appEnvProvider);
  return env.isConfigured ? env.mediaUrl(baseKey, size: size) : null;
}

/// Shows why a backend call failed.
void showError(BuildContext context, Object error) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(context.core.error(error))));
}

/// The usual body for a list or page from the server: skeleton while loading, the
/// error with "try again" when nothing could be loaded, otherwise [data] under a
/// pull-to-refresh, with the offline banner when the phone has no connection.
class AsyncBody<T> extends ConsumerWidget {
  const AsyncBody({super.key, required this.value, required this.data, required this.onRefresh});

  final AsyncValue<T> value;
  final Widget Function(T value) data;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final body = switch (value) {
      AsyncValue(:final value?, hasValue: true) => data(value),
      AsyncError(:final error) => ListView(
        children: [
          EmptyState(
            icon: error is BackendException && error.offline
                ? Icons.cloud_off_outlined
                : Icons.error_outline,
            title: context.core.error(error),
            action: OutlinedButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh),
              label: Text(context.core.actionRetry),
            ),
          ),
        ],
      ),
      _ => const SkeletonList(),
    };
    return Column(
      children: [
        const OfflineBanner(),
        Expanded(
          child: RefreshIndicator(onRefresh: onRefresh, child: body),
        ),
      ],
    );
  }
}

/// "You're offline — showing saved data", while the last read found no connection.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = ref.watch(onlineProvider);
    return AnimatedSize(
      duration: Motion.medium,
      child: online
          ? const SizedBox(width: double.infinity)
          : Material(
              color: AppColors.of(context).warningContainer,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.page, vertical: Space.sm),
                child: Row(
                  children: [
                    Icon(
                      Icons.cloud_off_outlined,
                      size: 18,
                      color: AppColors.of(context).onWarningContainer,
                    ),
                    const SizedBox(width: Space.sm),
                    Expanded(
                      child: Text(
                        context.core.offlineBanner,
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: AppColors.of(context).onWarningContainer),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
