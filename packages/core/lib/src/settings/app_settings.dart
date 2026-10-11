import 'package:flutter/foundation.dart' show LicenseEntryWithLineBreaks, LicenseRegistry;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../i18n/locale_controller.dart';

/// The current time. Overridden in tests and screenshots so sample data and
/// countdowns are stable.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Light, dark or follow the phone.
class ThemeModeController extends Notifier<ThemeMode> {
  static const _key = 'theme_mode';

  @override
  ThemeMode build() {
    final saved = ref.watch(sharedPreferencesProvider).getString(_key);
    return ThemeMode.values.where((m) => m.name == saved).firstOrNull ?? ThemeMode.system;
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    await ref.read(sharedPreferencesProvider).setString(_key, mode.name);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(ThemeModeController.new);

/// Data saver loads thumbnails only until a photo is tapped (on by default,
/// PLAN §3.2 `profiles.data_saver`).
class DataSaverController extends Notifier<bool> {
  static const _key = 'data_saver';

  @override
  bool build() => ref.watch(sharedPreferencesProvider).getBool(_key) ?? true;

  Future<void> set(bool on) async {
    state = on;
    await ref.read(sharedPreferencesProvider).setBool(_key, on);
  }
}

final dataSaverProvider = NotifierProvider<DataSaverController, bool>(DataSaverController.new);

/// Adds the bundled font's licence (SIL OFL) to the app's licences page.
void registerFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    final text = await rootBundle.loadString('packages/alghali_core/assets/fonts/OFL.txt');
    yield LicenseEntryWithLineBreaks(['IBM Plex Sans Arabic'], text);
  });
}
