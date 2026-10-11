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
  String get welcomeTitle => 'أدر محلك وأعمالك من هاتفك';

  @override
  String get welcomePointOrders => 'استلم الطلبات وجهّزها بسرعة';

  @override
  String get welcomePointStock => 'حدّث الأسعار والكميات في ثوانٍ';

  @override
  String get welcomePointJobs => 'استقبل أعمال التركيب وتابع أرباحك';

  @override
  String get signInTitle => 'تسجيل دخول الشركاء';

  @override
  String get signInSubtitle => 'للمحلات والفنيين على شارع الغالي';

  @override
  String get fieldEmail => 'البريد الإلكتروني';

  @override
  String get fieldPassword => 'كلمة المرور';

  @override
  String get showPassword => 'إظهار كلمة المرور';

  @override
  String get hidePassword => 'إخفاء كلمة المرور';

  @override
  String get signInSubmit => 'دخول';

  @override
  String get signInForgot => 'نسيت كلمة المرور؟';

  @override
  String get signInForgotSent => 'سنرسل رابط إعادة التعيين إلى بريدك عند تفعيل خدمة البريد.';

  @override
  String get signInDemoHint =>
      'في النسخة التجريبية يعمل أي بريد صحيح مع كلمة مرور من 8 أحرف فيها أرقام.';

  @override
  String get signInApply => 'محل أو فني جديد؟ قدّم طلب انضمام';

  @override
  String get applySoon => 'يُفتح التقديم من التطبيق قريبًا. تواصل مع فريق المنصة حاليًا.';

  @override
  String get roleTitle => 'كيف تريد المتابعة؟';

  @override
  String get roleBody => 'حسابك مرتبط بمحل وبملف فني تركيب.';

  @override
  String get roleShop => 'صاحب محل';

  @override
  String get roleTechnician => 'فني تركيب';

  @override
  String get roleSwitch => 'تبديل الدور';

  @override
  String get shopNavHome => 'الرئيسية';

  @override
  String get shopNavOrders => 'الطلبات';

  @override
  String get shopNavStock => 'المخزون';

  @override
  String get shopNavQuotes => 'التسعير';

  @override
  String get shopNavMore => 'المزيد';

  @override
  String hello(String name) {
    return 'أهلًا، $name';
  }

  @override
  String get shopIsOpen => 'المحل مفتوح لاستقبال الطلبات';

  @override
  String get shopIsClosed => 'المحل مغلق — لن تظهر قطعك للمشترين';

  @override
  String get kpiNewOrders => 'طلبات جديدة';

  @override
  String get kpiToPrepare => 'للتجهيز';

  @override
  String get kpiCashToCollect => 'نقد للتحصيل';

  @override
  String get kpiTodaySales => 'مبيعات اليوم';

  @override
  String get needsAction => 'يحتاج إجراء';

  @override
  String ackWithin(int minutes) {
    return 'أكّد خلال $minutes دقيقة';
  }

  @override
  String get ackLate => 'تأخر التأكيد — تم تنبيه الإدارة';

  @override
  String get quickAddPart => 'إضافة قطعة';

  @override
  String get quickUpdatePrices => 'تحديث الأسعار';

  @override
  String get quickQuotes => 'طلبات التسعير';

  @override
  String get lowStock => 'مخزون منخفض';

  @override
  String lowStockBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count قطعة تحتاج إعادة تعبئة',
      few: '$count قطع تحتاج إعادة تعبئة',
      two: 'قطعتان تحتاجان إعادة تعبئة',
      one: 'قطعة واحدة تحتاج إعادة تعبئة',
    );
    return '$_temp0';
  }

  @override
  String get allCaughtUp => 'لا شيء بانتظارك الآن';

  @override
  String get tabNew => 'جديدة';

  @override
  String get tabPreparing => 'قيد التجهيز';

  @override
  String get tabReady => 'جاهزة';

  @override
  String get tabDone => 'منتهية';

  @override
  String get ordersEmpty => 'لا توجد طلبات هنا';

  @override
  String orderRef(String ref) {
    return 'طلب $ref';
  }

  @override
  String orderFrom(String buyer) {
    return 'من $buyer';
  }

  @override
  String get orderAwaitingPayment => 'بانتظار دفع المشتري — لا تجهّز بعد';

  @override
  String toTechWith(String name, String time) {
    return 'للفني $name · $time';
  }

  @override
  String get orderAccept => 'قبول الطلب';

  @override
  String get orderReject => 'رفض';

  @override
  String get rejectTitle => 'لماذا ترفض الطلب؟';

  @override
  String get rejectOutOfStock => 'القطعة غير متوفرة';

  @override
  String get rejectPrice => 'السعر تغيّر';

  @override
  String get rejectOther => 'سبب آخر';

  @override
  String get rejectNote => 'سيُعاد المبلغ للمشتري، وتؤثر حالات الرفض على تقييم المحل.';

  @override
  String get markReady => 'القطعة جاهزة';

  @override
  String get handToBuyer => 'سلّمتها للمشتري';

  @override
  String get handToTech => 'سلّمتها للفني';

  @override
  String get outForDelivery => 'خرجت للتوصيل';

  @override
  String get markDelivered => 'تم التوصيل';

  @override
  String collectCash(String amount) {
    return 'حصّل $amount نقدًا عند التسليم';
  }

  @override
  String cashFromTech(String amount) {
    return 'يسلّمك الفني $amount نقدًا ثمن القطعة';
  }

  @override
  String get paidBankak => 'مدفوع عبر بنكك — تصلك قيمته في الدفعة القادمة';

  @override
  String get sectionBuyer => 'المشتري';

  @override
  String get sectionItems => 'القطع';

  @override
  String get sectionHandover => 'التسليم';

  @override
  String get sectionMoney => 'المبلغ';

  @override
  String commission(int percent) {
    return 'عمولة المنصة ($percent%)';
  }

  @override
  String get youReceive => 'صافي لك';

  @override
  String receivedAgo(String ago) {
    return 'استُلم $ago';
  }

  @override
  String get stockSearch => 'ابحث في قطعك';

  @override
  String get filterAll => 'الكل';

  @override
  String get filterLow => 'منخفض';

  @override
  String get filterOut => 'نفد';

  @override
  String get filterHidden => 'مخفي';

  @override
  String qty(int count) {
    return 'الكمية: $count';
  }

  @override
  String get hiddenFromBuyers => 'مخفي عن المشترين';

  @override
  String get editListing => 'تعديل السعر والكمية';

  @override
  String get priceField => 'السعر (ج.س)';

  @override
  String get qtyField => 'الكمية';

  @override
  String get visibleToBuyers => 'ظاهر للمشترين';

  @override
  String get saved => 'تم الحفظ';

  @override
  String get bulkEdit => 'تعديل جماعي';

  @override
  String selectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count قطعة محددة',
      few: '$count قطع محددة',
      two: 'قطعتان محددتان',
      one: 'قطعة محددة',
    );
    return '$_temp0';
  }

  @override
  String get bulkPriceBy => 'تغيير الأسعار بنسبة';

  @override
  String get bulkApply => 'تطبيق';

  @override
  String bulkDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'حُدّثت أسعار $count قطعة',
      few: 'حُدّثت أسعار $count قطع',
      two: 'حُدّث سعر قطعتين',
      one: 'حُدّث سعر قطعة واحدة',
    );
    return '$_temp0';
  }

  @override
  String get importExcel => 'استيراد من Excel';

  @override
  String get importBody => 'نزّل القالب، املأه، ثم ارفعه لتحديث مئات القطع دفعة واحدة.';

  @override
  String get downloadTemplate => 'تنزيل القالب';

  @override
  String get uploadFile => 'رفع الملف';

  @override
  String get priceLockNote => 'الطلبات المؤكدة تحتفظ بسعرها القديم.';

  @override
  String get addTitle => 'إضافة قطعة';

  @override
  String get stepPhoto => 'الصورة';

  @override
  String get stepPart => 'القطعة';

  @override
  String get stepCars => 'السيارات';

  @override
  String get stepPrice => 'السعر';

  @override
  String get photoTitle => 'صوّر القطعة';

  @override
  String get photoBody =>
      'صورة واضحة على خلفية فاتحة تزيد مبيعاتك. نصغّرها تلقائيًا لتوفير البيانات.';

  @override
  String get takePhoto => 'التقاط صورة';

  @override
  String get photoAdded => 'تمت إضافة الصورة';

  @override
  String get categoryTitle => 'ما القطعة؟';

  @override
  String get partName => 'اسم القطعة';

  @override
  String get partNameHint => 'مثال: لمبة هالوجين H4';

  @override
  String get carsTitle => 'لأي سيارات تناسب؟';

  @override
  String get carsUnknown => 'لست متأكدًا — سيُطلب من المشتري التأكد';

  @override
  String get conditionLabel => 'الحالة';

  @override
  String get warrantyLabel => 'الضمان';

  @override
  String get publish => 'نشر القطعة';

  @override
  String get saveDraft => 'حفظ كمسودة';

  @override
  String get draftOffline => 'تُحفظ المسودات على هاتفك وتُرسل عند عودة الاتصال.';

  @override
  String get published => 'نُشرت القطعة';

  @override
  String get draftSaved => 'حُفظت المسودة';

  @override
  String get draft => 'مسودة';

  @override
  String get quotesBody => 'مشترون أرسلوا صورًا لقطع يبحثون عنها. أرسل عرضك قبل انتهاء الطلب.';

  @override
  String get quotesEmpty => 'لا توجد طلبات تسعير حاليًا';

  @override
  String expiresIn(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ينتهي خلال $count ساعة',
      few: 'ينتهي خلال $count ساعات',
      two: 'ينتهي خلال ساعتين',
      one: 'ينتهي خلال ساعة',
    );
    return '$_temp0';
  }

  @override
  String otherOffers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count عرضًا من محلات أخرى',
      few: '$count عروض من محلات أخرى',
      two: 'عرضان من محلات أخرى',
      one: 'عرض واحد من محل آخر',
      zero: 'لا عروض بعد — كن الأول',
    );
    return '$_temp0';
  }

  @override
  String get makeOffer => 'أرسل عرضًا';

  @override
  String get offerSent => 'تم إرسال عرضك';

  @override
  String yourOffer(String amount) {
    return 'عرضك: $amount';
  }

  @override
  String get offerTitle => 'عرض سعر';

  @override
  String get offerPart => 'وصف القطعة';

  @override
  String get offerNote => 'ملاحظة للمشتري (اختياري)';

  @override
  String get moreMoney => 'المال والدفعات';

  @override
  String get moreStaff => 'الموظفون';

  @override
  String get moreInsights => 'الأداء';

  @override
  String get moreProfile => 'ملف المحل';

  @override
  String get moreLanguage => 'اللغة';

  @override
  String get moreAppearance => 'المظهر';

  @override
  String get appearanceSystem => 'حسب الجهاز';

  @override
  String get appearanceLight => 'فاتح';

  @override
  String get appearanceDark => 'داكن';

  @override
  String get moreHelp => 'المساعدة';

  @override
  String get signOut => 'تسجيل الخروج';

  @override
  String get signOutConfirm => 'هل تريد تسجيل الخروج؟';

  @override
  String get moneyOwedToYou => 'المنصة مدينة لك بـ';

  @override
  String get moneyYouOwe => 'أنت مدين للمنصة بـ';

  @override
  String nextPayout(String date) {
    return 'الدفعة القادمة: $date عبر بنكك';
  }

  @override
  String commissionNote(int percent) {
    return 'العمولة $percent% على القطع فقط، وتُخصم من الدفعة.';
  }

  @override
  String get statement => 'كشف الحساب';

  @override
  String get payouts => 'الدفعات';

  @override
  String get ledgerSale => 'بيع';

  @override
  String get ledgerCommission => 'عمولة';

  @override
  String get ledgerLabour => 'أجرة تركيب';

  @override
  String get ledgerTravel => 'رسوم مشوار';

  @override
  String get ledgerBookingFee => 'رسوم حجز';

  @override
  String get ledgerCash => 'نقد محصّل';

  @override
  String get ledgerHandover => 'تسليم نقد';

  @override
  String get ledgerPayout => 'دفعة';

  @override
  String get ledgerRefund => 'استرداد';

  @override
  String get payoutPaid => 'مدفوعة';

  @override
  String get payoutApproved => 'معتمدة';

  @override
  String get payoutDraft => 'قيد الإعداد';

  @override
  String get staffOwner => 'المالك';

  @override
  String get staffMember => 'موظف';

  @override
  String get staffInvite => 'دعوة موظف';

  @override
  String get staffInviteBody => 'يستطيع الموظفون إدارة الطلبات والمخزون فقط، دون الوصول إلى المال.';

  @override
  String get staffInviteSent => 'أُرسلت الدعوة';

  @override
  String lastActive(String ago) {
    return 'آخر نشاط $ago';
  }

  @override
  String get insightsSales7 => 'المبيعات آخر 7 أيام';

  @override
  String get insightsOrders => 'الطلبات';

  @override
  String get insightsAvgOrder => 'متوسط الطلب';

  @override
  String get insightsRating => 'التقييم';

  @override
  String get insightsTop => 'الأكثر مبيعًا';

  @override
  String get showTable => 'عرض كجدول';

  @override
  String get showChart => 'عرض كرسم';

  @override
  String get colDay => 'اليوم';

  @override
  String get colSales => 'المبيعات';

  @override
  String get colOrders => 'الطلبات';

  @override
  String soldCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'بيعت $count مرة',
      few: 'بيعت $count مرات',
      two: 'بيعت مرتين',
      one: 'بيعت مرة',
    );
    return '$_temp0';
  }

  @override
  String get techNavJobs => 'الأعمال';

  @override
  String get techNavSchedule => 'الجدول';

  @override
  String get techNavEarnings => 'الأرباح';

  @override
  String get techNavProfile => 'حسابي';

  @override
  String get techOnline => 'متاح لاستقبال الأعمال';

  @override
  String get techOffline => 'غير متاح — لن تصلك عروض جديدة';

  @override
  String get newOffers => 'عروض جديدة';

  @override
  String get todayJobs => 'أعمال اليوم';

  @override
  String get upcomingJobs => 'القادمة';

  @override
  String get noJobsToday => 'لا أعمال اليوم بعد';

  @override
  String get noJobsTodayBody => 'تأكد أنك متاح وأن جدولك محدّث لتصلك العروض.';

  @override
  String respondIn(String time) {
    return 'رد خلال $time';
  }

  @override
  String get accept => 'قبول';

  @override
  String get decline => 'اعتذار';

  @override
  String get declineBody => 'سيُعرض العمل على فني آخر في نفس الموعد.';

  @override
  String get jobAccepted => 'قبلت العمل';

  @override
  String get offerExpired => 'انتهت مهلة العرض';

  @override
  String youEarn(String amount) {
    return 'تكسب $amount';
  }

  @override
  String get atYourBay => 'في ورشتك';

  @override
  String atCustomer(String distance) {
    return 'عند العميل · $distance';
  }

  @override
  String partReadyAt(String shop) {
    return 'القطعة جاهزة في $shop';
  }

  @override
  String partPendingAt(String shop) {
    return 'القطعة قيد التجهيز في $shop';
  }

  @override
  String get partWithCustomer => 'القطعة مع العميل';

  @override
  String get jobTitle => 'تفاصيل العمل';

  @override
  String get jobCustomer => 'العميل';

  @override
  String get jobCar => 'السيارة';

  @override
  String get jobWork => 'العمل';

  @override
  String get jobWhere => 'المكان';

  @override
  String get jobPay => 'الأجر';

  @override
  String get onMyWay => 'أنا في الطريق';

  @override
  String get checkIn => 'وصلت — ابدأ العمل';

  @override
  String get photosBefore => 'صور قبل العمل';

  @override
  String get photosAfter => 'صور بعد العمل';

  @override
  String get addPhoto => 'إضافة صورة';

  @override
  String get enterCode => 'أدخل رمز العميل لإنهاء العمل';

  @override
  String get codeHint => 'اطلب من العميل الرمز المكوّن من 4 أرقام بعد رضاه عن العمل.';

  @override
  String codeWrong(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'الرمز غير صحيح. $count محاولة متبقية.',
      few: 'الرمز غير صحيح. $count محاولات متبقية.',
      two: 'الرمز غير صحيح. محاولتان متبقيتان.',
      one: 'الرمز غير صحيح. محاولة واحدة متبقية.',
      zero: 'الرمز غير صحيح. أُوقف الإنهاء وتم تنبيه الإدارة.',
    );
    return '$_temp0';
  }

  @override
  String get finishJob => 'إنهاء العمل';

  @override
  String get jobDone => 'اكتمل العمل — أُضيف الأجر إلى أرباحك';

  @override
  String get partNotFit => 'القطعة لا تناسب';

  @override
  String get partNotFitBody => 'يدفع العميل رسوم المشوار فقط، ويُفتح طلب إرجاع للقطعة.';

  @override
  String collectFromCustomer(String amount) {
    return 'حصّل $amount نقدًا من العميل';
  }

  @override
  String handCashToShop(String amount) {
    return 'سلّم $amount للمحل ثمن القطعة';
  }

  @override
  String pickUpPart(String shop) {
    return 'استلم القطعة من $shop قبل الموعد';
  }

  @override
  String get needAfterPhoto => 'أضف صورة واحدة على الأقل بعد العمل.';

  @override
  String get weeklyHours => 'ساعات العمل الأسبوعية';

  @override
  String get dayOff => 'إجازة';

  @override
  String get quickBlock => 'إيقاف سريع';

  @override
  String get quickBlockBody => 'طارئ؟ أوقف استقبال الأعمال مؤقتًا دون تعديل جدولك.';

  @override
  String get block1h => 'ساعة';

  @override
  String get block2h => 'ساعتان';

  @override
  String get blockDay => 'بقية اليوم';

  @override
  String blockedUntil(String time) {
    return 'لن تصلك أعمال حتى $time';
  }

  @override
  String get unblock => 'إلغاء الإيقاف';

  @override
  String get timeOff => 'الإجازات';

  @override
  String get addTimeOff => 'إضافة إجازة';

  @override
  String get noTimeOff => 'لا توجد إجازات قادمة';

  @override
  String get timeOffAdded => 'أُضيفت إجازة غدًا طوال اليوم';

  @override
  String get earningsWeek => 'أرباح هذا الأسبوع';

  @override
  String jobsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count عملًا',
      few: '$count أعمال',
      two: 'عملان',
      one: 'عمل واحد',
      zero: 'لا أعمال',
    );
    return '$_temp0';
  }

  @override
  String get cashWithYou => 'نقد معك';

  @override
  String get cashWithYouBody => 'حصّلته من العملاء ويُخصم من دفعتك.';

  @override
  String get recentActivity => 'آخر العمليات';

  @override
  String get skillsAndPrices => 'الأعمال وأسعارك';

  @override
  String get howYouWork => 'طريقة العمل';

  @override
  String maxDistance(int km) {
    return 'أقصى مسافة للزيارات: $km كم';
  }

  @override
  String yourBay(String shop) {
    return 'ورشتك: $shop';
  }

  @override
  String labourFor(String job) {
    return 'أجرة $job';
  }

  @override
  String get demoControls => 'أدوات العرض التجريبي';

  @override
  String get demoNewOrder => 'محاكاة طلب جديد';

  @override
  String get demoNewOffer => 'محاكاة عرض عمل جديد';

  @override
  String get demoNewQuote => 'محاكاة طلب تسعير جديد';
}
