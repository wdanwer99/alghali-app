// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'core_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class CoreLocalizationsEn extends CoreLocalizations {
  CoreLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get backendStatus => 'Backend status';

  @override
  String get backendOk => 'Connected';

  @override
  String get backendError => 'Can\'t connect';

  @override
  String get backendNotConfigured => 'Not set up yet';

  @override
  String get backendChecking => 'Checking…';

  @override
  String get languageArabic => 'العربية';

  @override
  String get languageEnglish => 'English';

  @override
  String get chooseLanguage => 'Choose your language';

  @override
  String get chooseLanguageHint => 'You can change it later in settings.';

  @override
  String get continueAction => 'Continue';

  @override
  String get switchLanguage => 'Change language';
}
