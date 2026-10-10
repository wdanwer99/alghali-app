// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'core_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class CoreLocalizationsAr extends CoreLocalizations {
  CoreLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get backendStatus => 'حالة الخادم';

  @override
  String get backendOk => 'متصل';

  @override
  String get backendError => 'تعذّر الاتصال';

  @override
  String get backendNotConfigured => 'لم يتم الإعداد بعد';

  @override
  String get backendChecking => 'جارٍ الفحص…';

  @override
  String get languageArabic => 'العربية';

  @override
  String get languageEnglish => 'English';

  @override
  String get chooseLanguage => 'اختر اللغة';

  @override
  String get chooseLanguageHint => 'يمكنك تغيير اللغة لاحقًا من الإعدادات.';

  @override
  String get continueAction => 'متابعة';

  @override
  String get switchLanguage => 'تغيير اللغة';
}
