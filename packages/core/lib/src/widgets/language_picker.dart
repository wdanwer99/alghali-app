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
/// On continue the wheel rolls off the far edge before [onContinue] runs.
class LanguagePickerScreen extends ConsumerStatefulWidget {
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
  ConsumerState<LanguagePickerScreen> createState() => _LanguagePickerScreenState();
}

class _LanguagePickerScreenState extends ConsumerState<LanguagePickerScreen>
    with SingleTickerProviderStateMixin {
  static const _wheelSize = 64.0;

  // Short enough that the next page's transition still feels like one motion.
  late final _roll = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
  var _leaving = false;

  @override
  void dispose() {
    _roll.dispose();
    super.dispose();
  }

  Future<void> _continue(Locale locale) async {
    if (_leaving) return;
    _leaving = true;
    await Future.wait([
      ref.read(localeControllerProvider.notifier).select(locale),
      if (!MediaQuery.disableAnimationsOf(context)) _roll.forward(),
    ]);
    if (mounted) widget.onContinue();
  }

  /// Rolls toward the end side without slipping: the wheel turns one radian
  /// for every radius it travels, and speeds up as it drives off.
  Widget _rollingWheel(BuildContext context, Widget? wheel) {
    final distance = Curves.easeInCubic.transform(_roll.value) * MediaQuery.sizeOf(context).width;
    final sign = Directionality.of(context) == TextDirection.rtl ? -1.0 : 1.0;
    return Transform.translate(
      offset: Offset(sign * distance, 0),
      child: Transform.rotate(angle: sign * distance / (_wheelSize / 2), child: wheel),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                      AnimatedBuilder(
                        animation: _roll,
                        builder: _rollingWheel,
                        child: AlghaliWheel(size: _wheelSize, variant: widget.variant),
                      ),
                      const SizedBox(height: Space.xl),
                      Text(
                        widget.title,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: colors.onBrandSurface,
                        ),
                      ),
                      const SizedBox(height: Space.lg),
                      for (final p in widget.points)
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
                onPressed: () => _continue(current),
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
