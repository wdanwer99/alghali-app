import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../i18n/locale_controller.dart';
import '../l10n/generated/core_localizations.dart';

/// First-launch language choice (Arabic preselected). Shared by both apps.
class LanguagePickerScreen extends ConsumerWidget {
  const LanguagePickerScreen({required this.onContinue, this.header, super.key});

  final VoidCallback onContinue;
  final Widget? header;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = CoreLocalizations.of(context);
    final current = ref.watch(localeControllerProvider).locale;
    final controller = ref.read(localeControllerProvider.notifier);

    Widget option(Locale locale, String label) => RadioListTile<String>(
      value: locale.languageCode,
      title: Text(label, style: Theme.of(context).textTheme.titleLarge),
    );

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ?header,
              const SizedBox(height: 24),
              Text(t.chooseLanguage, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(t.chooseLanguageHint),
              const SizedBox(height: 16),
              RadioGroup<String>(
                groupValue: current.languageCode,
                onChanged: (code) {
                  if (code != null) controller.preview(Locale(code));
                },
                child: Column(
                  children: [
                    option(const Locale('ar'), t.languageArabic),
                    option(const Locale('en'), t.languageEnglish),
                  ],
                ),
              ),
              const Spacer(),
              FilledButton(
                onPressed: () async {
                  await controller.select(current);
                  onContinue();
                },
                child: Text(t.continueAction),
              ),
            ],
          ),
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
