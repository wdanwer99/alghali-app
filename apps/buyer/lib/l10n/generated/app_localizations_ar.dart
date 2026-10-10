// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'شارع الغالي';

  @override
  String get welcomeHeadline => 'قطع الغيار والتركيب في مكان واحد';

  @override
  String get welcomeBody =>
      'تصفّح محلات شارع الغالي، اطلب القطعة المناسبة لسيارتك، واحجز فنيًا لتركيبها.';

  @override
  String get homeComingSoon => 'البحث والسلة وحجز الفنيين قادمة قريبًا.';
}
