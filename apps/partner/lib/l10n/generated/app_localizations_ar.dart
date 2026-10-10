// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'شركاء الغالي';

  @override
  String get welcomeHeadline => 'تطبيق المحلات والفنيين';

  @override
  String get roleShop => 'صاحب محل';

  @override
  String get roleShopHint => 'أضف قطعك، حدّث الأسعار، واستلم الطلبات.';

  @override
  String get roleTechnician => 'فني تركيب';

  @override
  String get roleTechnicianHint => 'حدّد أوقاتك، استقبل الحجوزات، ونفّذ أعمال التركيب.';

  @override
  String get comingSoon => 'قريبًا';
}
