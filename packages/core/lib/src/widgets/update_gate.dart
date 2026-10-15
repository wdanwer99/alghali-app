import 'package:material_ui/material_ui.dart';

import '../data/platform_settings.dart';
import '../l10n/generated/core_localizations.dart';
import '../platform/device.dart';
import '../theme/app_tokens.dart';
import 'common.dart';

/// Shows [child], or, when [appBuild] is below the release's minimum, a screen that asks
/// for the new version and nothing else (D-058). Wraps each app's root.
class UpdateGate extends StatelessWidget {
  const UpdateGate({super.key, required this.release, required this.appBuild, required this.child});

  final AppRelease release;

  /// This app's build number (the `+N` in pubspec.yaml).
  final int appBuild;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!release.updateRequired(appBuild)) return child;
    final core = CoreLocalizations.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: Space.pageInsets,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.system_update_outlined, size: 56, color: theme.colorScheme.primary),
                const SizedBox(height: Space.lg),
                Text(
                  core.updateTitle,
                  style: theme.textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: Space.sm),
                Text(
                  core.updateRequiredBody,
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: Space.xl),
                FilledButton.icon(
                  onPressed: () => Launch.open(release.apkFor()!),
                  icon: const Icon(Icons.download_rounded),
                  label: Text(core.updateDownload),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "A new version is available" with a download button, when there is one.
class UpdateBanner extends StatelessWidget {
  const UpdateBanner({super.key, required this.release, required this.appBuild});

  final AppRelease release;

  /// This app's build number (the `+N` in pubspec.yaml).
  final int appBuild;

  @override
  Widget build(BuildContext context) {
    if (!release.updateAvailable(appBuild)) return const SizedBox.shrink();
    final core = CoreLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.md),
      child: InfoBanner(
        icon: Icons.system_update_outlined,
        message: core.updateAvailableBody,
        action: FilledButton(
          onPressed: () => Launch.open(release.apkFor()!),
          child: Text(core.updateDownload),
        ),
      ),
    );
  }
}
