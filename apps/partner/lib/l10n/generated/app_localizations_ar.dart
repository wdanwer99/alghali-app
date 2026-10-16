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
  String get signInForgotSent => 'إذا كان لهذا البريد حساب، سيصلك رابط لتغيير كلمة المرور.';

  @override
  String get signInApply => 'محل أو فني جديد؟ أنشئ حساباً';

  @override
  String get roleTitle => 'كيف تريد المتابعة؟';

  @override
  String get roleBody => 'اختر ما تريد فتحه من أعمالك. يمكنك التبديل في أي وقت من القائمة.';

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
  String get timeOffAdded => 'أضيفت الإجازة';

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
  String get forgotSend => 'أرسل الرابط';

  @override
  String get signUpTitle => 'حساب شريك جديد';

  @override
  String get signUpBody => 'لأصحاب المحلات وموظفيهم وفنيي التركيب. بعدها تختار كيف تعمل معنا.';

  @override
  String get fieldName => 'الاسم الكامل';

  @override
  String get fieldPhone => 'رقم الجوال';

  @override
  String get fieldWhatsapp => 'رقم واتساب (اختياري)';

  @override
  String get signUpSubmit => 'إنشاء الحساب';

  @override
  String get signUpHaveAccount => 'لديك حساب؟ سجّل الدخول';

  @override
  String get roleShopStaff => 'موظف في المحل';

  @override
  String get applyAddShop => 'أضف محلاً';

  @override
  String get applyAsTechnician => 'قدّم كفني تركيب';

  @override
  String get statusPending => 'قيد المراجعة';

  @override
  String get statusApproved => 'معتمد';

  @override
  String get statusRejected => 'مرفوض';

  @override
  String get statusSuspended => 'موقوف';

  @override
  String get statusRejectedBody => 'لم يُعتمد طلبك. تواصل مع فريق المنصة لمعرفة المطلوب.';

  @override
  String get statusSuspendedBody => 'الحساب موقوف مؤقتاً، ولا يظهر للمشترين. تواصل مع فريق المنصة.';

  @override
  String statusReason(String reason) {
    return 'السبب: $reason';
  }

  @override
  String get shopPendingBody =>
      'طلب المحل قيد المراجعة. جهّز قطعك وأسعارك الآن، وستظهر للمشترين بعد الاعتماد.';

  @override
  String get techPendingBody =>
      'طلبك قيد المراجعة. ستصلك عروض العمل بعد الاعتماد؛ أكمل ساعات عملك وأسعارك الآن.';

  @override
  String get applyTitle => 'انضم إلى شارع الغالي';

  @override
  String applyHello(String name) {
    return 'أهلاً $name';
  }

  @override
  String get applyBody => 'كيف ستعمل معنا؟ يراجع فريق المنصة طلبك عادة خلال يوم عمل.';

  @override
  String get applyShopTitle => 'عندي محل في الشارع';

  @override
  String get applyShopBody => 'اعرض قطعك، واستقبل الطلبات وطلبات الأسعار.';

  @override
  String get applyTechTitle => 'أنا فني تركيب';

  @override
  String get applyTechBody => 'استقبل أعمال التركيب في ورشة على الشارع أو عند الزبون.';

  @override
  String get applyStaffNote =>
      'تعمل في محل مسجّل؟ لا تقدّم طلباً — اطلب من صاحب المحل إضافتك ببريدك هذا.';

  @override
  String get applyShopNote => 'اسم المحل ومكانه في الشارع يظهران للمشترين بعد الاعتماد.';

  @override
  String get applySectionShop => 'المحل';

  @override
  String get applySectionPlace => 'المكان في الشارع';

  @override
  String get applySectionContact => 'التواصل';

  @override
  String get applySubmit => 'أرسل الطلب';

  @override
  String get applySent => 'أرسلنا طلبك للمراجعة';

  @override
  String get shopNameAr => 'اسم المحل بالعربية';

  @override
  String get shopNameEn => 'اسم المحل بالإنجليزية (اختياري)';

  @override
  String get shopZone => 'المنطقة';

  @override
  String get shopPlot => 'رقم القطعة';

  @override
  String get shopSideA => 'الجهة أ';

  @override
  String get shopSideB => 'الجهة ب';

  @override
  String get shopLandmark => 'علامة مميزة';

  @override
  String get shopLandmarkHint => 'مثلاً: مقابل محطة الوقود';

  @override
  String get shopAbout => 'عن المحل (اختياري)';

  @override
  String get shopHours => 'ساعات العمل';

  @override
  String get shopSells => 'ماذا تبيع؟';

  @override
  String get shopMakes => 'السيارات التي تخدمها';

  @override
  String get shopMakesBody => 'اتركها فارغة إذا كنت تخدم كل الأنواع.';

  @override
  String get applyTechNote => 'يراجع الفريق خبرتك قبل وصول أول عرض عمل.';

  @override
  String get techApplyBay => 'الورشة التي تعمل فيها';

  @override
  String get techApplyBayHelp => 'محل أو ورشة على الشارع يركّب فيه الزبائن';

  @override
  String get techApplyHome => 'حدّد موقعي الحالي كنقطة الانطلاق';

  @override
  String get techApplyHomeSet => 'حُدّد موقعك';

  @override
  String get techApplyHomeBody => 'تُحسب مسافة الزيارات من هنا، ولا يراها الزبائن.';

  @override
  String get techApplyJobsBody => 'اكتب سعر المصنعية لكل نوع عمل تقوم به، واترك الباقي فارغاً.';

  @override
  String get techApplyMakes => 'السيارات التي تعمل عليها';

  @override
  String get techApplyMakesBody => 'اتركها فارغة إذا كنت تعمل على كل الأنواع.';

  @override
  String get techApplyYears => 'سنوات الخبرة';

  @override
  String get techApplyBio => 'نبذة عنك (اختياري)';

  @override
  String get techApplyNeedJob => 'اختر نوع عمل واحداً على الأقل مع سعره.';

  @override
  String get techApplyNeedBay => 'اختر الورشة التي تعمل فيها.';

  @override
  String get techApplyNeedHome => 'حدّد موقع انطلاقك للزيارات.';

  @override
  String get homeUpdate => 'حدّث موقع الانطلاق';

  @override
  String get addJobType => 'أضف نوع عمل';

  @override
  String get chatsTitle => 'الرسائل';

  @override
  String get notificationsTitle => 'التنبيهات';

  @override
  String get shopClosedToday => 'المحل مغلق اليوم — يظهر مغلقاً للمشترين';

  @override
  String get shopOutsideHours => 'خارج ساعات العمل الآن';

  @override
  String get orderAccepted => 'قُبل الطلب';

  @override
  String get orderRejected => 'اعتذرت عن الطلب، وسيُعاد المبلغ للمشتري';

  @override
  String get orderMarkedReady => 'القطعة جاهزة';

  @override
  String get orderHandedOver => 'تم التسليم';

  @override
  String get orderDelivered => 'تم التوصيل';

  @override
  String get orderNotHere => 'لم نجد هذا الطلب في محلك';

  @override
  String returnRequested(String reason) {
    return 'طلب المشتري الإرجاع: $reason';
  }

  @override
  String get waitTechAccept => 'سلّم القطعة بعد أن يقبل الفني العمل.';

  @override
  String get callTechnician => 'اتصل بالفني';

  @override
  String get cashCollected => 'استلمت المبلغ نقداً';

  @override
  String get rejectOtherLabel => 'اكتب السبب للمشتري';

  @override
  String get openOrder => 'افتح الطلب';

  @override
  String get chatsEmpty => 'لا توجد رسائل بعد';

  @override
  String get chatsEmptyBody => 'عندما يراسلك مشترٍ ستظهر محادثته هنا.';

  @override
  String get chatEmpty => 'ابدأ المحادثة';

  @override
  String get chatHint => 'اكتب رسالة';

  @override
  String get chatSend => 'إرسال';

  @override
  String get chatVoiceNote => 'رسالة صوتية';

  @override
  String get notificationsEmpty => 'لا توجد تنبيهات';

  @override
  String get notificationsEmptyBody => 'ستصلك هنا الطلبات الجديدة وعروض العمل والرسائل.';

  @override
  String get notificationsGeneric => 'تنبيه';

  @override
  String get notificationsMarkRead => 'تعليم الكل كمقروء';

  @override
  String get helpBody => 'فريق المنصة يساعدك في الطلبات والمدفوعات والحساب.';

  @override
  String get stockEmpty => 'لا توجد قطع بعد';

  @override
  String get stockEmptyBody => 'أضف قطعة بالصورة، أو استورد ملف Excel.';

  @override
  String get stockNoMatch => 'لا توجد قطع تطابق البحث';

  @override
  String reservedQty(int count) {
    return 'محجوز $count';
  }

  @override
  String reservedNote(int count) {
    return '$count محجوزة لطلبات مفتوحة';
  }

  @override
  String get priceOnRequest => 'السعر عند الطلب';

  @override
  String get archive => 'احذف من المحل';

  @override
  String get archiveTitle => 'حذف القطعة؟';

  @override
  String get archiveBody => 'لن تظهر للمشترين بعد الآن. الطلبات المؤكدة لا تتأثر.';

  @override
  String get listingQueued => 'هذه القطعة بانتظار الاتصال لإرسالها. عدّلها بعد ظهورها في القائمة.';

  @override
  String get listingSavedOffline => 'حُفظت القطعة وستُرسل عند عودة الاتصال';

  @override
  String get retakePhoto => 'صورة أخرى';

  @override
  String get noPhoto => 'بدون صورة الآن';

  @override
  String get fromCatalogue => 'من دليل القطع';

  @override
  String get suggestionsTitle => 'هل تقصد؟';

  @override
  String get carsFromCatalogue => 'السيارات المناسبة لهذه القطعة محددة في الدليل.';

  @override
  String get importCheckTitle => 'فحص الملف';

  @override
  String importCheckBody(int created, int updated, int failed) {
    return 'سيُضاف $created ويُحدَّث $updated، وفيه $failed صفوف بها مشاكل.';
  }

  @override
  String importRow(int row) {
    return 'الصف $row';
  }

  @override
  String importGo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'استورد $count صفاً',
      few: 'استورد $count صفوف',
      two: 'استورد صفين',
      one: 'استورد صفاً واحداً',
    );
    return '$_temp0';
  }

  @override
  String importDone(int created, int updated, int failed) {
    return 'أضيفت $created وحُدّثت $updated، وتُركت $failed';
  }

  @override
  String get importErrName => 'اسم القطعة ناقص';

  @override
  String get importErrCategory => 'الفئة ناقصة أو غير معروفة';

  @override
  String get importErrCondition => 'الحالة ناقصة أو غير صحيحة';

  @override
  String get importErrPrice => 'السعر ناقص أو غير صحيح';

  @override
  String get importErrQty => 'الكمية غير صحيحة';

  @override
  String get importErrWarranty => 'الضمان غير صحيح';

  @override
  String get importErrSku => 'الرمز مكرر';

  @override
  String get importErrReserved => 'الكمية أقل من المحجوز لطلبات مفتوحة';

  @override
  String get importErrValue => 'قيمة غير صحيحة';

  @override
  String get importWarnModel => 'سيارة غير معروفة (تجاهلناها):';

  @override
  String get changeOffer => 'تعديل';

  @override
  String get statementEmpty => 'لا حركات في آخر 30 يوماً';

  @override
  String staffAdded(String date) {
    return 'أضيف $date';
  }

  @override
  String staffRemoveTitle(String name) {
    return 'إزالة $name؟';
  }

  @override
  String get staffRemoveBody => 'لن يستطيع إدارة طلبات المحل ومخزونه بعد الآن.';

  @override
  String get insightsNoSales => 'لا مبيعات في هذه الأيام بعد';

  @override
  String get profileNameNote => 'لتغيير الاسم أو المكان في الشارع، تواصل مع فريق المنصة.';

  @override
  String get atCustomerPlace => 'عند الزبون';

  @override
  String jobAndMore(String first, int count) {
    return '$first و$count أخرى';
  }

  @override
  String jobRef(String ref) {
    return 'رقم العمل $ref';
  }

  @override
  String get onMyWayDone => 'الزبون يرى موقعك الآن حتى تصل';

  @override
  String get checkedIn => 'بدأ العمل';

  @override
  String get sharingLocation => 'يُشارك موقعك مع الزبون أثناء الطريق.';

  @override
  String partCollected(String shop) {
    return 'استلمت القطعة من $shop';
  }

  @override
  String get partNotFitReason => 'ما المشكلة؟';

  @override
  String get partNotFitDone => 'سُجّل أن القطعة لا تناسب، وفُتح طلب إرجاع';

  @override
  String get dropJob => 'لا أستطيع الحضور';

  @override
  String get dropJobReason => 'السبب';

  @override
  String get dropJobBody => 'يذهب العمل لفني آخر في نفس الموعد. الاعتذار المتكرر يؤثر على تقييمك.';

  @override
  String get dropJobDone => 'أُرسل العمل لفني آخر';

  @override
  String get youEarnLabel => 'لك';

  @override
  String get editHours => 'تعديل الساعات';

  @override
  String get addPeriod => 'أضف فترة';

  @override
  String get periodsOverlap => 'تأكد أن كل فترة تنتهي بعد بدايتها ولا تتداخل مع غيرها.';

  @override
  String get timeOffDefault => 'إجازة';

  @override
  String get earningsNotYet => 'ستظهر أرباحك هنا بعد الاعتماد';

  @override
  String get ledgerAdjustment => 'تعديل من الإدارة';

  @override
  String get complaintsTitle => 'الشكاوى';

  @override
  String get complaintsMenuBody => 'شكاوى المشترين عن طلباتك أو أعمالك، وما أبلغت عنه';

  @override
  String get complaintsEmpty => 'لا توجد شكاوى';

  @override
  String get complaintsEmptyBody =>
      'إن أبلغ مشترٍ عن مشكلة في أحد طلباتك أو أعمالك تظهر هنا. ويمكنك الإبلاغ عن مشكلة من صفحة الطلب أو العمل.';

  @override
  String get complaintReport => 'الإبلاغ عن مشكلة';

  @override
  String get complaintIntro => 'اختر نوع المشكلة واشرح ما حدث. يرد فريقنا عادةً خلال يوم عمل.';

  @override
  String get complaintDescribe => 'ماذا حدث؟';

  @override
  String get complaintSend => 'إرسال';

  @override
  String get complaintNotReceived => 'لم يستلم القطعة';

  @override
  String get complaintWrongPart => 'قطعة خاطئة';

  @override
  String get complaintDamaged => 'تلف أو عطل';

  @override
  String get complaintNotFitted => 'التركيب لم يتم كما يجب';

  @override
  String get complaintPayment => 'مشكلة في الدفع';

  @override
  String get complaintBehaviour => 'سوء معاملة';

  @override
  String get complaintOther => 'أخرى';

  @override
  String get complaintOpen => 'مفتوحة';

  @override
  String get complaintInReview => 'قيد المراجعة';

  @override
  String get complaintResolved => 'تم الحل';

  @override
  String get complaintRejected => 'مغلقة';

  @override
  String get complaintTitle => 'الشكوى';

  @override
  String complaintFrom(String name) {
    return 'فتحها $name';
  }

  @override
  String get complaintOutcome => 'القرار';

  @override
  String get complaintYou => 'أنت';

  @override
  String get complaintTeam => 'فريق شارع الغالي';

  @override
  String get complaintReply => 'اكتب ردًا';

  @override
  String get tourOrdersTitle => 'الطلبات وأعمال التركيب تصلك';

  @override
  String get tourOrdersBody => 'يصلك تنبيه بكل طلب أو عمل جديد، وتردّ على المشترين في المحادثة.';

  @override
  String get tourStockTitle => 'مخزونك حتى بدون إنترنت';

  @override
  String get tourStockBody => 'عدّل الأسعار والكميات متى شئت، وتُرسل وحدها عند عودة الاتصال.';

  @override
  String get tourEarnTitle => 'تابع أرباحك';

  @override
  String get tourEarnBody => 'اعرف ما كسبته من كل طلب وكل تركيب، وما تبقّى لك عند المنصة.';

  @override
  String get shopLocation => 'موقع المحل على الخريطة';

  @override
  String get shopLocationBody =>
      'اختياري. يظهر للزبائن زر يفتح خرائط جوجل بالطريق إلى محلك، ولا يظهر إن لم تحدّده.';

  @override
  String get shopLocationPick => 'حدّد موقع المحل';

  @override
  String get shopLocationIsSet => 'حُدّد الموقع';

  @override
  String get shopLocationChange => 'تغيير';

  @override
  String get shopLocationView => 'عرض في الخرائط';

  @override
  String get shopLocationRemove => 'إزالة';

  @override
  String get pickLocationTitle => 'موقع المحل';

  @override
  String get pickLocationHint => 'حرّك الخريطة حتى يقع الدبوس على باب محلك.';

  @override
  String get pickLocationHere => 'موقعي الحالي';

  @override
  String get pickLocationConfirm => 'اعتمد هذا الموقع';
}
