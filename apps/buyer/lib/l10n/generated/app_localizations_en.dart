// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Alghali Street';

  @override
  String get welcomeHeadline => 'Car parts and fitting in one place';

  @override
  String get welcomeBody =>
      'Browse the shops of Alghali Street, order the right part for your car, and book a technician to fit it.';

  @override
  String get homeComingSoon => 'Search, cart and technician booking are coming soon.';
}
