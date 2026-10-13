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

  @override
  String money(String amount) {
    return '$amount ج.س';
  }

  @override
  String moneyFrom(String amount) {
    return 'من $amount';
  }

  @override
  String km(String value) {
    return '$value كم';
  }

  @override
  String minutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count دقيقة',
      few: '$count دقائق',
      two: 'دقيقتان',
      one: 'دقيقة',
    );
    return '$_temp0';
  }

  @override
  String warrantyDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'ضمان $days يومًا',
      few: 'ضمان $days أيام',
      two: 'ضمان يومين',
      one: 'ضمان يوم',
      zero: 'بدون ضمان',
    );
    return '$_temp0';
  }

  @override
  String warrantyMonths(int months) {
    String _temp0 = intl.Intl.pluralLogic(
      months,
      locale: localeName,
      other: 'ضمان $months شهرًا',
      few: 'ضمان $months أشهر',
      two: 'ضمان شهرين',
      one: 'ضمان شهر',
    );
    return '$_temp0';
  }

  @override
  String get warrantyYear => 'ضمان سنة';

  @override
  String inStock(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count قطعة متوفرة',
      few: '$count قطع متوفرة',
      two: 'قطعتان متبقيتان',
      one: 'قطعة واحدة متبقية',
    );
    return '$_temp0';
  }

  @override
  String get outOfStock => 'نفدت الكمية';

  @override
  String ratingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count تقييمًا',
      few: '$count تقييمات',
      two: 'تقييمان',
      one: 'تقييم واحد',
      zero: 'لا تقييمات',
    );
    return '$_temp0';
  }

  @override
  String jobsDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count عملًا',
      few: '$count أعمال',
      two: 'عملان',
      one: 'عمل واحد',
      zero: 'لا أعمال بعد',
    );
    return '$_temp0';
  }

  @override
  String agoMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'قبل $count دقيقة',
      few: 'قبل $count دقائق',
      two: 'قبل دقيقتين',
      one: 'قبل دقيقة',
      zero: 'الآن',
    );
    return '$_temp0';
  }

  @override
  String agoHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'قبل $count ساعة',
      few: 'قبل $count ساعات',
      two: 'قبل ساعتين',
      one: 'قبل ساعة',
    );
    return '$_temp0';
  }

  @override
  String agoDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'قبل $count يومًا',
      few: 'قبل $count أيام',
      two: 'قبل يومين',
      one: 'أمس',
    );
    return '$_temp0';
  }

  @override
  String get today => 'اليوم';

  @override
  String get tomorrow => 'غدًا';

  @override
  String get conditionNewOem => 'جديد أصلي';

  @override
  String get conditionNewAftermarket => 'جديد تجاري';

  @override
  String get conditionUsed => 'مستعمل';

  @override
  String get fitFits => 'يناسب سيارتك';

  @override
  String get fitCheck => 'تأكّد من المناسبة';

  @override
  String get fitNoFit => 'لا يناسب سيارتك';

  @override
  String get verifiedShop => 'محل موثّق';

  @override
  String get verifiedTechnician => 'فني موثّق';

  @override
  String get payBankak => 'بنكك';

  @override
  String get payCash => 'نقدًا';

  @override
  String get fulfilPickup => 'استلام من المحل';

  @override
  String get fulfilDelivery => 'توصيل';

  @override
  String get fulfilToTechnician => 'يسلّمها المحل للفني';

  @override
  String get subPendingPayment => 'بانتظار الدفع';

  @override
  String get subPaymentReview => 'جارٍ التحقق من الدفع';

  @override
  String get subConfirmed => 'مؤكَّد';

  @override
  String get subReady => 'جاهز';

  @override
  String get subPickedUp => 'تم الاستلام';

  @override
  String get subOutForDelivery => 'في الطريق إليك';

  @override
  String get subDelivered => 'تم التوصيل';

  @override
  String get subHandedToTechnician => 'سُلّم للفني';

  @override
  String get subCompleted => 'مكتمل';

  @override
  String get subCancelled => 'ملغى';

  @override
  String get subRejectedByShop => 'رفضه المحل';

  @override
  String get subReturnRequested => 'طلب إرجاع';

  @override
  String get subReturned => 'مُرجَع';

  @override
  String get payAwaitingTransfer => 'بانتظار التحويل';

  @override
  String get payReceiptSubmitted => 'جارٍ التحقق من الدفع';

  @override
  String get payConfirmed => 'تم الدفع';

  @override
  String get payRejected => 'رُفض الإيصال';

  @override
  String get payDue => 'يُدفع نقدًا';

  @override
  String get payCollected => 'تم التحصيل';

  @override
  String get payExpired => 'انتهت مهلة الدفع';

  @override
  String get bkHeld => 'الموعد محجوز مؤقتًا';

  @override
  String get bkAwaitingPayment => 'بانتظار تأكيد الدفع';

  @override
  String get bkPendingTechAccept => 'بانتظار موافقة الفني';

  @override
  String get bkAccepted => 'مؤكَّد';

  @override
  String get bkEnRoute => 'الفني في الطريق';

  @override
  String get bkInProgress => 'جارٍ العمل';

  @override
  String get bkCompleted => 'مكتمل';

  @override
  String get bkNeedsReschedule => 'يحتاج موعدًا جديدًا';

  @override
  String get bkExpired => 'انتهى الحجز المؤقت';

  @override
  String get bkCancelledByBuyer => 'ألغيته';

  @override
  String get bkCancelledByTech => 'ألغاه الفني';

  @override
  String get bkCancelledByAdmin => 'ألغته الإدارة';

  @override
  String get bkPartDoesNotFit => 'القطعة لم تناسب';

  @override
  String get jobLighting => 'إضاءة';

  @override
  String get jobBrakes => 'فرامل';

  @override
  String get jobService => 'صيانة دورية';

  @override
  String get jobBattery => 'بطاريات';

  @override
  String get jobElectrical => 'كهرباء';

  @override
  String get jobAc => 'تكييف';

  @override
  String get jobSuspension => 'عفشة';

  @override
  String get jobTyres => 'إطارات';

  @override
  String get jobMechanical => 'ميكانيكا';

  @override
  String get modeBay => 'في الورشة';

  @override
  String get modeMobile => 'يأتي إليك';

  @override
  String get modeBoth => 'في الورشة أو يأتي إليك';

  @override
  String get sideA => 'الجهة أ';

  @override
  String get sideB => 'الجهة ب';

  @override
  String plot(String number) {
    return 'قطعة $number';
  }

  @override
  String get actionCancel => 'إلغاء';

  @override
  String get actionSave => 'حفظ';

  @override
  String get actionDone => 'تم';

  @override
  String get actionNext => 'التالي';

  @override
  String get actionBack => 'رجوع';

  @override
  String get actionClose => 'إغلاق';

  @override
  String get actionRetry => 'إعادة المحاولة';

  @override
  String get actionSeeAll => 'عرض الكل';

  @override
  String get actionCall => 'اتصال';

  @override
  String get actionWhatsApp => 'واتساب';

  @override
  String get actionChat => 'محادثة';

  @override
  String get actionCopy => 'نسخ';

  @override
  String get copied => 'تم النسخ';

  @override
  String get actionDirections => 'الاتجاهات';

  @override
  String get actionEdit => 'تعديل';

  @override
  String get actionRemove => 'حذف';

  @override
  String get actionConfirm => 'تأكيد';

  @override
  String get optional => 'اختياري';

  @override
  String get errorGeneric => 'حدث خطأ ما';

  @override
  String get errorGenericBody => 'لم نتمكن من إكمال الطلب. تحقّق من الاتصال وحاول مرة أخرى.';

  @override
  String get offlineBanner => 'لا يوجد اتصال — نعرض آخر بيانات محفوظة';

  @override
  String get demoBadge => 'نسخة تجريبية';

  @override
  String get demoNote => 'هذه نسخة تجريبية ببيانات نموذجية. لا تتم أي عمليات دفع أو اتصال حقيقية.';

  @override
  String get demoActionDisabled => 'هذا الإجراء معطّل في النسخة التجريبية.';

  @override
  String get brandName => 'شارع الغالي';

  @override
  String get brandTagline => 'قطع الغيار والتركيب';

  @override
  String get fieldRequired => 'هذا الحقل مطلوب';

  @override
  String get fieldEmailInvalid => 'اكتب بريدًا إلكترونيًا صحيحًا، مثل name@example.com';

  @override
  String get fieldPasswordWeak => '8 أحرف على الأقل، وفيها حروف وأرقام';

  @override
  String get fieldPhoneInvalid => 'اكتب رقمًا سودانيًا من 10 أرقام يبدأ بـ 0';

  @override
  String get fieldNumberInvalid => 'اكتب رقمًا صحيحًا';

  @override
  String thousands(String value) {
    return '$value ألف';
  }
}
