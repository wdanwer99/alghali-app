import 'dart:ui' show Locale;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Arabic first; English second.
const supportedLocales = [Locale('ar'), Locale('en')];
const defaultLocale = Locale('ar');

final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('Override sharedPreferencesProvider in main()'),
);

class LocaleState {
  const LocaleState({required this.locale, required this.chosen});

  final Locale locale;

  /// False until the user confirms a language on first launch.
  final bool chosen;
}

class LocaleController extends Notifier<LocaleState> {
  static const _key = 'locale';

  @override
  LocaleState build() {
    final saved = ref.watch(sharedPreferencesProvider).getString(_key);
    final match = supportedLocales.where((l) => l.languageCode == saved);
    return LocaleState(
      locale: match.isEmpty ? defaultLocale : match.first,
      chosen: match.isNotEmpty,
    );
  }

  Future<void> select(Locale locale) async {
    await ref.read(sharedPreferencesProvider).setString(_key, locale.languageCode);
    state = LocaleState(locale: locale, chosen: true);
  }

  /// Previews a language on the picker screen without marking it as chosen.
  void preview(Locale locale) => state = LocaleState(locale: locale, chosen: state.chosen);

  Future<void> toggle() =>
      select(state.locale.languageCode == 'ar' ? const Locale('en') : const Locale('ar'));
}

final localeControllerProvider = NotifierProvider<LocaleController, LocaleState>(
  LocaleController.new,
);
