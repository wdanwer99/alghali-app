// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Alghali Partners';

  @override
  String get welcomeHeadline => 'The app for shops and technicians';

  @override
  String get roleShop => 'Shop owner';

  @override
  String get roleShopHint => 'Add your parts, update prices and receive orders.';

  @override
  String get roleTechnician => 'Installation technician';

  @override
  String get roleTechnicianHint => 'Set your hours, receive bookings and do the fitting.';

  @override
  String get comingSoon => 'Coming soon';
}
