import 'package:flutter/services.dart' show SystemUiOverlayStyle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../i18n/locale_controller.dart';
import '../l10n/generated/core_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import 'brand.dart';
import 'common.dart';

/// One benefit line on the welcome panel.
@immutable
class WelcomePoint {
  const WelcomePoint(this.icon, this.text);

  final IconData icon;
  final String text;
}

/// First launch: brand panel + language choice (Arabic preselected).
/// Tapping a language previews it at once, so the screen flips direction live.
class LanguagePickerScreen extends ConsumerWidget {
  const LanguagePickerScreen({
    required this.onContinue,
    required this.title,
    this.points = const [],
    this.variant = MarkVariant.buyer,
    super.key,
  });

  final VoidCallback onContinue;
  final String title;
  final List<WelcomePoint> points;
  final MarkVariant variant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = CoreLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final current = ref.watch(localeControllerProvider).locale;
    final controller = ref.read(localeControllerProvider.notifier);

    Widget option(Locale locale, String label) => Padding(
      padding: const EdgeInsets.only(bottom: Space.md),
      child: ChoiceCard(
        selected: current.languageCode == locale.languageCode,
        onTap: () => controller.preview(locale),
        title: label,
      ),
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: theme.colorScheme.surface,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: colors.brandSurface,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(Space.xxl, Space.xxl, Space.xxl, Space.xxxl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AlghaliMark(size: 64, variant: variant),
                      const SizedBox(height: Space.xl),
                      Text(
                        title,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: colors.onBrandSurface,
                        ),
                      ),
                      const SizedBox(height: Space.lg),
                      for (final p in points)
                        Padding(
                          padding: const EdgeInsets.only(bottom: Space.sm),
                          child: Row(
                            children: [
                              Icon(p.icon, size: 22, color: colors.onBrandSurfaceMuted),
                              const SizedBox(width: Space.md),
                              Expanded(
                                child: Text(
                                  p.text,
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    color: colors.onBrandSurface,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(Space.xxl, Space.xxl, Space.xxl, Space.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(t.chooseLanguage, style: theme.textTheme.titleLarge),
                      const SizedBox(height: Space.xs),
                      Text(
                        t.chooseLanguageHint,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: Space.lg),
                      option(const Locale('ar'), t.languageArabic),
                      option(const Locale('en'), t.languageEnglish),
                    ],
                  ),
                ),
              ),
            ),
            BottomActionBar(
              child: FilledButton(
                onPressed: () async {
                  await controller.select(current);
                  onContinue();
                },
                child: Text(t.continueAction),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// App-bar action that flips between Arabic and English.
class LanguageToggleButton extends ConsumerWidget {
  const LanguageToggleButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = CoreLocalizations.of(context);
    final isArabic = ref.watch(localeControllerProvider).locale.languageCode == 'ar';
    return TextButton(
      onPressed: () => ref.read(localeControllerProvider.notifier).toggle(),
      child: Tooltip(
        message: t.switchLanguage,
        child: Text(isArabic ? t.languageEnglish : t.languageArabic),
      ),
    );
  }
}
