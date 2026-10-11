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
  String get navHome => 'الرئيسية';

  @override
  String get navStreet => 'الشارع';

  @override
  String get navCart => 'السلة';

  @override
  String get navOrders => 'طلباتي';

  @override
  String get navAccount => 'حسابي';

  @override
  String get welcomeTitle => 'قطع الغيار والتركيب في مكان واحد';

  @override
  String get welcomePointFit => 'قطع تناسب سيارتك من محلات شارع الغالي';

  @override
  String get welcomePointCompare => 'قارن الأسعار بين المحلات قبل الشراء';

  @override
  String get welcomePointInstall => 'احجز فنيًا يركّبها في الورشة أو عندك';

  @override
  String get homeSearchHint => 'ابحث عن قطعة، مثل: لمبات، فحمات';

  @override
  String get homeAddCar => 'أضف سيارتك لترى القطع المناسبة';

  @override
  String get homeChangeCar => 'تغيير';

  @override
  String get homeQuickPhotoTitle => 'أرسل صورة القطعة';

  @override
  String get homeQuickPhotoBody => 'لم تجدها؟ المحلات ترسل لك عروضًا';

  @override
  String get homeQuickBookTitle => 'احجز فني تركيب';

  @override
  String get homeQuickBookBody => 'في الورشة أو في مكانك';

  @override
  String get homeCategories => 'تسوّق حسب القسم';

  @override
  String homeDealsFor(String model) {
    return 'عروض لسيارتك $model';
  }

  @override
  String get homeDeals => 'عروض اليوم';

  @override
  String get homeStreetTitle => 'محلات الشارع';

  @override
  String homeStreetBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count محلًا على طول شارع الغالي',
      few: '$count محلات على طول شارع الغالي',
      two: 'محلان على طول شارع الغالي',
      one: 'محل واحد على طول شارع الغالي',
    );
    return '$_temp0';
  }

  @override
  String get homeStreetOpen => 'افتح خريطة الشارع';

  @override
  String get homeTrustPay => 'ادفع ببنكك أو نقدًا';

  @override
  String get homeTrustTech => 'فنيون موثّقون ومقيّمون';

  @override
  String homeTrustReturns(int days) {
    return 'إرجاع خلال $days أيام';
  }

  @override
  String get homeNextFitting => 'موعد التركيب القادم';

  @override
  String get homeCurrentOrder => 'طلبك الحالي';

  @override
  String get notificationsTitle => 'الإشعارات';

  @override
  String get notificationsMarkRead => 'تعيين الكل كمقروء';

  @override
  String get notificationsEmpty => 'لا توجد إشعارات';

  @override
  String get notificationsEmptyBody => 'سنخبرك هنا بتأكيد الدفع وعروض المحلات ومواعيدك.';

  @override
  String get searchHint => 'ابحث عن قطعة أو رقم قطعة';

  @override
  String get searchFilters => 'الفلاتر';

  @override
  String get searchFitsOnly => 'يناسب سيارتي فقط';

  @override
  String get sortRelevance => 'الأنسب';

  @override
  String get sortPriceLow => 'الأقل سعرًا';

  @override
  String get sortPriceHigh => 'الأعلى سعرًا';

  @override
  String get sortRating => 'الأعلى تقييمًا';

  @override
  String searchShowingFor(String car) {
    return 'نعرض القطع المناسبة لـ $car';
  }

  @override
  String get searchNoCar => 'أضف سيارتك لنعرض القطع المناسبة فقط';

  @override
  String get searchRecent => 'عمليات بحث سابقة';

  @override
  String get searchPopular => 'الأكثر طلبًا';

  @override
  String searchResults(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count نتيجة',
      few: '$count نتائج',
      two: 'نتيجتان',
      one: 'نتيجة واحدة',
      zero: 'لا نتائج',
    );
    return '$_temp0';
  }

  @override
  String shopsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count محلًا',
      few: '$count محلات',
      two: 'محلان',
      one: 'محل واحد',
    );
    return '$_temp0';
  }

  @override
  String get searchNoResults => 'لم نجد قطعًا مطابقة';

  @override
  String get searchNoResultsBody => 'جرّب كلمة أخرى، أو أرسل صورة القطعة وستصلك عروض من المحلات.';

  @override
  String get searchSendPhoto => 'أرسل صورة القطعة';

  @override
  String get filtersTitle => 'الفلاتر';

  @override
  String get filtersCondition => 'الحالة';

  @override
  String get filtersMaxPrice => 'أقصى سعر';

  @override
  String get filtersAnyPrice => 'أي سعر';

  @override
  String filtersUpTo(String amount) {
    return 'حتى $amount';
  }

  @override
  String get filtersSort => 'الترتيب';

  @override
  String get filtersReset => 'مسح الكل';

  @override
  String get filtersApply => 'عرض النتائج';

  @override
  String partFits(String car) {
    return 'يناسب $car';
  }

  @override
  String get partCheck => 'لا تتوفر لدينا بيانات المطابقة لهذه القطعة. اسأل المحل قبل الشراء.';

  @override
  String partNoFit(String car) {
    return 'هذه القطعة لا تناسب $car.';
  }

  @override
  String get partNoCar => 'أضف سيارتك لنتأكد أن القطعة تناسبها.';

  @override
  String get partOem => 'رقم القطعة الأصلي';

  @override
  String partCompare(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'قارن بين $count محلًا',
      few: 'قارن بين $count محلات',
      two: 'قارن بين محلين',
      one: 'محل واحد يبيعها',
    );
    return '$_temp0';
  }

  @override
  String get partBestPrice => 'أفضل سعر';

  @override
  String get partAddToCart => 'أضف للسلة';

  @override
  String get partAdded => 'أُضيفت إلى السلة';

  @override
  String get partViewCart => 'عرض السلة';

  @override
  String get partFittingTitle => 'تحتاج تركيبًا؟';

  @override
  String partFittingBody(String amount) {
    return 'أضف التركيب من السلة: في ورشة على الشارع أو في مكانك. أجرة التركيب من $amount.';
  }

  @override
  String get partAbout => 'عن القطعة';

  @override
  String get shopOpen => 'مفتوح الآن';

  @override
  String get shopClosed => 'مغلق الآن';

  @override
  String get shopOnStreet => 'اعرضه على الشارع';

  @override
  String get shopParts => 'القطع';

  @override
  String get shopReviews => 'التقييمات';

  @override
  String get shopAbout => 'عن المحل';

  @override
  String shopSince(String year) {
    return 'على المنصة منذ $year';
  }

  @override
  String get shopNoReviews => 'لا توجد تقييمات بعد';

  @override
  String get viewShop => 'عرض المحل';

  @override
  String get streetHint => 'اضغط على أي محل لعرض تفاصيله';

  @override
  String get streetAll => 'الكل';

  @override
  String get streetNorth => 'شمال';

  @override
  String get streetSouth => 'جنوب';

  @override
  String get cartEmpty => 'سلتك فارغة';

  @override
  String get cartEmptyBody => 'ابحث عن القطعة التي تحتاجها وأضفها هنا.';

  @override
  String get cartBrowse => 'تصفّح القطع';

  @override
  String get cartAddFitting => 'أضف التركيب';

  @override
  String cartFittingFrom(String amount) {
    return 'أجرة التركيب من $amount';
  }

  @override
  String get cartFitting => 'التركيب';

  @override
  String get cartAnyTech => 'أول فني متاح';

  @override
  String get placeBay => 'في الورشة';

  @override
  String get placeHome => 'في مكانك';

  @override
  String cartHeldFor(String time) {
    return 'محجوز لك $time';
  }

  @override
  String get cartHoldExpired => 'انتهى الحجز المؤقت. اختر موعدًا جديدًا.';

  @override
  String get cartChange => 'تغيير';

  @override
  String get cartRemoveFitting => 'إزالة التركيب';

  @override
  String get cartRemoveItem => 'إزالة من السلة';

  @override
  String get cartSummary => 'ملخص الطلب';

  @override
  String get costParts => 'القطع';

  @override
  String get costLabour => 'أجرة التركيب';

  @override
  String get costTravel => 'رسوم المشوار';

  @override
  String get costBookingFee => 'رسوم الحجز';

  @override
  String get costDelivery => 'التوصيل';

  @override
  String get costTotal => 'الإجمالي';

  @override
  String get costFree => 'مجانًا';

  @override
  String get cartDeliveryLater => 'تختار الاستلام أو التوصيل في الخطوة التالية.';

  @override
  String get cartCheckout => 'متابعة الدفع';

  @override
  String itemsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count قطعة',
      few: '$count قطع',
      two: 'قطعتان',
      one: 'قطعة واحدة',
    );
    return '$_temp0';
  }

  @override
  String get bookTitle => 'حجز التركيب';

  @override
  String get bookStepWhat => 'القطعة';

  @override
  String get bookStepPlace => 'المكان';

  @override
  String get bookStepTech => 'الفني';

  @override
  String get bookStepTime => 'الموعد';

  @override
  String get bookWhatTitle => 'ماذا تريد أن تركّب؟';

  @override
  String get bookWhatHint => 'صف القطعة، مثل: لمبة أمامية يمين';

  @override
  String get bookWhatJob => 'نوع العمل';

  @override
  String get bookWhatNote => 'اشتريت القطعة من مكان آخر؟ لا مشكلة، أحضرها معك أو جهّزها للفني.';

  @override
  String get bookPlaceTitle => 'أين تريد التركيب؟';

  @override
  String get bookPlaceBay => 'في ورشة على شارع الغالي';

  @override
  String get bookPlaceBayBody => 'بدون رسوم مشوار. تُحضر السيارة إلى الورشة.';

  @override
  String get bookPlaceHome => 'في مكانك';

  @override
  String bookPlaceHomeBody(String amount) {
    return 'يأتيك الفني إلى البيت أو العمل. رسوم المشوار من $amount.';
  }

  @override
  String get bookAddress => 'العنوان';

  @override
  String get bookUseLocation => 'استخدم موقعي الحالي';

  @override
  String get bookTechTitle => 'اختر الفني';

  @override
  String get bookAnyTech => 'أول فني متاح';

  @override
  String get bookAnyTechBody => 'نختار لك أفضل فني متاح في الموعد الذي تختاره.';

  @override
  String bookAtBay(String shop) {
    return 'ورشة $shop';
  }

  @override
  String bookAway(String distance) {
    return 'يبعد $distance';
  }

  @override
  String bookYears(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'خبرة $count سنة',
      few: 'خبرة $count سنوات',
      two: 'خبرة سنتين',
      one: 'خبرة سنة',
    );
    return '$_temp0';
  }

  @override
  String get bookNoTechs => 'لا يوجد فني متاح لهذا العمل في هذا المكان حاليًا. جرّب مكانًا آخر.';

  @override
  String get bookTimeTitle => 'اختر الموعد';

  @override
  String get bookEarliest => 'أقرب موعد بعد ساعتين، حتى يجهّز المحل القطعة.';

  @override
  String get bookNoSlots => 'لا توجد مواعيد متاحة في هذا اليوم. اختر يومًا آخر.';

  @override
  String get bookDayOff => 'لا عمل في هذا اليوم.';

  @override
  String get bookReviewTitle => 'راجع الحجز';

  @override
  String get bookDuration => 'المدة المتوقعة';

  @override
  String bookCancelNote(int hours) {
    return 'الإلغاء مجاني حتى $hours ساعات قبل الموعد.';
  }

  @override
  String get bookHold => 'احجز هذا الموعد';

  @override
  String bookHoldNote(int minutes) {
    return 'نحجز لك الموعد $minutes دقائق حتى تُكمل الدفع.';
  }

  @override
  String get bookConfirm => 'تأكيد الحجز';

  @override
  String bookDepositNote(String amount) {
    return 'يُدفع عربون $amount عبر بنكك لتأكيد زيارة الفني، والباقي نقدًا.';
  }

  @override
  String get bookPickTime => 'اختر موعدًا للمتابعة';

  @override
  String get bookWhen => 'الموعد';

  @override
  String get checkoutTitle => 'إتمام الطلب';

  @override
  String get checkoutReceive => 'طريقة الاستلام';

  @override
  String checkoutPickupBody(String place) {
    return '$place — مجانًا';
  }

  @override
  String checkoutDeliveryTo(String address) {
    return 'إلى $address';
  }

  @override
  String get checkoutToTechBody => 'يسلّم المحل القطعة لفنيك قبل الموعد.';

  @override
  String get checkoutPayment => 'طريقة الدفع';

  @override
  String get checkoutBankak => 'تحويل بنكك';

  @override
  String get checkoutBankakBody => 'حوّل المبلغ ثم ارفع الإيصال. نؤكد الدفع خلال ساعات العمل.';

  @override
  String get checkoutCash => 'نقدًا';

  @override
  String get checkoutCashBody => 'ادفع عند الاستلام أو التوصيل أو للفني.';

  @override
  String get checkoutPayWithin => 'ادفع خلال ساعتين، وإلا يُلغى الطلب تلقائيًا وتعود القطع للمحل.';

  @override
  String get checkoutDueNow => 'المطلوب الآن عبر بنكك';

  @override
  String get checkoutRestCash => 'الباقي نقدًا';

  @override
  String get checkoutPlace => 'تأكيد الطلب';

  @override
  String get checkoutTerms => 'بتأكيد الطلب أنت توافق على شروط الاستخدام وسياسة الإرجاع.';

  @override
  String get checkoutSignIn => 'سجّل الدخول لإتمام الطلب';

  @override
  String get bankakTitle => 'الدفع عبر بنكك';

  @override
  String get bankakAmount => 'حوّل هذا المبلغ بالضبط';

  @override
  String get bankakStep1 => 'افتح تطبيق بنكك وحوّل إلى هذا الحساب';

  @override
  String get bankakAccountName => 'اسم الحساب';

  @override
  String get bankakAccountNumber => 'رقم الحساب';

  @override
  String get bankakSample => 'حساب تجريبي — لا تحوّل إليه';

  @override
  String get bankakStep2 => 'اكتب رقم الطلب في خانة التعليق';

  @override
  String get bankakRef => 'رقم الطلب';

  @override
  String get bankakStep3 => 'ارفع صورة الإيصال أو اكتب رقم العملية';

  @override
  String get bankakUpload => 'ارفع صورة الإيصال';

  @override
  String get bankakUploaded => 'تم إرفاق صورة الإيصال';

  @override
  String get bankakTxn => 'رقم العملية';

  @override
  String get bankakTxnHint => 'يظهر في إيصال بنكك';

  @override
  String get bankakSubmit => 'إرسال للتحقق';

  @override
  String get bankakNeedProof => 'ارفع الإيصال أو اكتب رقم العملية.';

  @override
  String bankakTimeLeft(String time) {
    return 'الوقت المتبقي للدفع: $time';
  }

  @override
  String get bankakChecking => 'جارٍ التحقق من الدفع';

  @override
  String get bankakCheckingBody =>
      'نطابق تحويلك مع كشف الحساب، عادةً خلال 30 دقيقة بين 8 ص و10 م. سنرسل لك إشعارًا.';

  @override
  String get bankakNever =>
      'لا نعتبر الطلب مدفوعًا من صورة الإيصال وحدها، بل بعد مطابقتها مع البنك.';

  @override
  String get ordersTabOrders => 'الطلبات';

  @override
  String get ordersTabBookings => 'الحجوزات';

  @override
  String get ordersTabRequests => 'طلبات الصور';

  @override
  String get ordersEmpty => 'لا توجد طلبات بعد';

  @override
  String get ordersEmptyBody => 'ستظهر طلباتك هنا بعد الشراء.';

  @override
  String get bookingsEmpty => 'لا توجد حجوزات';

  @override
  String get bookingsEmptyBody => 'احجز فنيًا لتركيب قطعتك في الورشة أو في مكانك.';

  @override
  String get requestsEmpty => 'لا توجد طلبات صور';

  @override
  String get requestsEmptyBody => 'أرسل صورة القطعة وستصلك عروض من المحلات.';

  @override
  String get ordersSignIn => 'سجّل الدخول لترى طلباتك';

  @override
  String get ordersSignInBody => 'تابع طلباتك وحجوزاتك وعروض المحلات من مكان واحد.';

  @override
  String orderRef(String ref) {
    return 'طلب $ref';
  }

  @override
  String bookingRefTitle(String ref) {
    return 'حجز $ref';
  }

  @override
  String get orderTitle => 'تفاصيل الطلب';

  @override
  String orderPlacedOn(String date) {
    return 'تاريخ الطلب: $date';
  }

  @override
  String get orderPayNow => 'ادفع الآن';

  @override
  String get orderAwaiting => 'بانتظار تحويلك';

  @override
  String orderAwaitingBody(String amount, String time) {
    return 'حوّل $amount عبر بنكك قبل $time وإلا يُلغى الطلب.';
  }

  @override
  String orderPickupWhere(String place) {
    return 'الاستلام: $place';
  }

  @override
  String get orderCancel => 'إلغاء الطلب';

  @override
  String get orderCancelConfirm => 'هل تريد إلغاء الطلب؟';

  @override
  String get orderCancelBody => 'تعود القطع للمحل ويُلغى أي موعد تركيب مرتبط بالطلب.';

  @override
  String get orderKeep => 'الاحتفاظ بالطلب';

  @override
  String get orderReturn => 'طلب إرجاع';

  @override
  String orderReturnBody(int days) {
    return 'يمكنك الإرجاع خلال $days أيام من الاستلام.';
  }

  @override
  String get orderReturnSent => 'أرسلنا طلب الإرجاع، سيتواصل معك المحل.';

  @override
  String get orderRateShop => 'قيّم المحل';

  @override
  String get orderFitting => 'موعد التركيب';

  @override
  String get tlPlaced => 'تم الطلب';

  @override
  String get tlPaymentChecked => 'تأكيد الدفع';

  @override
  String get tlShopConfirmed => 'أكّد المحل';

  @override
  String get tlReady => 'القطعة جاهزة';

  @override
  String get tlPickedUp => 'استلمت القطعة';

  @override
  String get tlOnTheWay => 'في الطريق إليك';

  @override
  String get tlDelivered => 'وصلت إليك';

  @override
  String get tlHanded => 'سُلّمت للفني';

  @override
  String get tlCompleted => 'اكتمل';

  @override
  String get tlBooked => 'تم الحجز';

  @override
  String get tlTechAccepted => 'وافق الفني';

  @override
  String get tlEnRoute => 'الفني في الطريق';

  @override
  String get tlWorking => 'جارٍ العمل';

  @override
  String get tlJobDone => 'اكتمل العمل';

  @override
  String get orderCancelled => 'أُلغي هذا الطلب.';

  @override
  String get demoControls => 'أدوات العرض التجريبي';

  @override
  String get demoNextStep => 'محاكاة الخطوة التالية';

  @override
  String get demoNextStepBody => 'يحرّك الطلب كما لو أن الإدارة والمحل والفني قاموا بدورهم.';

  @override
  String get bookingTitle => 'موعد التركيب';

  @override
  String get bookingCode => 'رمز إنهاء العمل';

  @override
  String get bookingCodeBody => 'أعطِ هذا الرمز للفني فقط بعد انتهاء العمل ورضاك عنه.';

  @override
  String get bookingTech => 'الفني';

  @override
  String get bookingWhere => 'المكان';

  @override
  String get bookingJob => 'العمل';

  @override
  String bookingEnRoute(String name) {
    return '$name في الطريق إليك، يصل خلال 15 دقيقة تقريبًا.';
  }

  @override
  String bookingWaitingTech(int minutes) {
    return 'ننتظر موافقة الفني، عادةً خلال $minutes دقيقة.';
  }

  @override
  String get bookingReschedule => 'تغيير الموعد';

  @override
  String get bookingCancel => 'إلغاء الموعد';

  @override
  String bookingCancelFree(String time) {
    return 'الإلغاء مجاني حتى $time.';
  }

  @override
  String get bookingCancelConfirm => 'هل تريد إلغاء الموعد؟';

  @override
  String get bookingKeep => 'الاحتفاظ بالموعد';

  @override
  String get bookingRate => 'قيّم الفني';

  @override
  String get bookingRescheduleSoon => 'اختر موعدًا جديدًا من خطوة الموعد.';

  @override
  String get requestNewTitle => 'اطلب بالصورة';

  @override
  String get requestNewIntro =>
      'صوّر القطعة القديمة أو مكانها في السيارة. ترسل لك المحلات عروضًا، عادةً خلال ساعة.';

  @override
  String get requestAddPhoto => 'إضافة صورة';

  @override
  String requestPhotos(int count) {
    return 'الصور ($count من 3)';
  }

  @override
  String get requestCar => 'السيارة';

  @override
  String get requestCategory => 'القسم';

  @override
  String get requestNote => 'صف القطعة';

  @override
  String get requestNoteHint => 'مثال: مقبض الباب الخلفي اليمين، كروم';

  @override
  String get requestSend => 'إرسال للمحلات';

  @override
  String get requestNeedPhoto => 'أضف صورة واحدة على الأقل.';

  @override
  String get requestTitle => 'طلب بالصورة';

  @override
  String requestOffers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count عرضًا',
      few: '$count عروض',
      two: 'عرضان',
      one: 'عرض واحد',
      zero: 'لا عروض بعد',
    );
    return '$_temp0';
  }

  @override
  String get requestNoOffersBody => 'أبلغنا المحلات المتخصصة. سنرسل لك إشعارًا عند وصول عرض.';

  @override
  String requestExpiresIn(int count) {
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
  String requestValidUntil(String time) {
    return 'صالح حتى $time';
  }

  @override
  String get requestClose => 'إغلاق الطلب';

  @override
  String get requestStatusOpen => 'مفتوح';

  @override
  String get requestStatusClosed => 'مغلق';

  @override
  String get requestStatusExpired => 'منتهٍ';

  @override
  String get requestSent => 'أرسلنا طلبك للمحلات.';

  @override
  String photoPlaceholder(int index) {
    return 'صورة $index';
  }

  @override
  String get chatHint => 'اكتب رسالة';

  @override
  String get chatVoice => 'رسالة صوتية';

  @override
  String get chatSend => 'إرسال';

  @override
  String get chatRecord => 'تسجيل رسالة صوتية';

  @override
  String get chatVoiceSoon => 'اضغط مطولًا على الميكروفون للتسجيل، حتى 60 ثانية.';

  @override
  String get chatEmpty => 'اسأل المحل عن القطعة أو السعر أو موعد التجهيز.';

  @override
  String reviewTitle(String name) {
    return 'قيّم $name';
  }

  @override
  String get reviewTags => 'ما الذي أعجبك؟';

  @override
  String get reviewTagGenuine => 'قطعة أصلية';

  @override
  String get reviewTagFast => 'سريع';

  @override
  String get reviewTagPrice => 'سعر مناسب';

  @override
  String get reviewTagPolite => 'تعامل محترم';

  @override
  String get reviewTagOnTime => 'في الموعد';

  @override
  String get reviewComment => 'أضف تعليقًا (اختياري)';

  @override
  String get reviewSubmit => 'إرسال التقييم';

  @override
  String get reviewThanks => 'شكرًا على تقييمك';

  @override
  String get accountGuestTitle => 'سجّل الدخول لتتابع طلباتك';

  @override
  String get accountGuestBody => 'احفظ سياراتك وتابع طلباتك وحجوزاتك.';

  @override
  String get accountSignIn => 'تسجيل الدخول';

  @override
  String get accountSignUp => 'إنشاء حساب';

  @override
  String get accountShopping => 'التسوّق';

  @override
  String get accountSettings => 'إعدادات التطبيق';

  @override
  String get accountSupport => 'الدعم';

  @override
  String get accountGarage => 'سياراتي';

  @override
  String get accountAddresses => 'عناويني';

  @override
  String get accountNotifications => 'الإشعارات';

  @override
  String get accountLanguage => 'اللغة';

  @override
  String get accountAppearance => 'المظهر';

  @override
  String get appearanceSystem => 'حسب الجهاز';

  @override
  String get appearanceLight => 'فاتح';

  @override
  String get appearanceDark => 'داكن';

  @override
  String get accountDataSaver => 'توفير البيانات';

  @override
  String get accountDataSaverBody => 'صور مصغّرة فقط حتى تضغط على الصورة';

  @override
  String get accountHelp => 'المساعدة والدعم';

  @override
  String get accountTerms => 'الشروط والخصوصية';

  @override
  String get accountTermsBody => 'ستُنشر الشروط وسياسة الخصوصية وسياسة الإرجاع هنا قبل الإطلاق.';

  @override
  String get accountAbout => 'عن التطبيق';

  @override
  String accountVersion(String version) {
    return 'الإصدار $version';
  }

  @override
  String get accountLicenses => 'تراخيص البرامج';

  @override
  String get accountSignOut => 'تسجيل الخروج';

  @override
  String get accountSignOutConfirm => 'هل تريد تسجيل الخروج؟';

  @override
  String accountCars(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count سيارة',
      few: '$count سيارات',
      two: 'سيارتان',
      one: 'سيارة واحدة',
      zero: 'لا سيارات',
    );
    return '$_temp0';
  }

  @override
  String get garageTitle => 'سياراتي';

  @override
  String get garageEmpty => 'لم تُضف سيارة بعد';

  @override
  String get garageEmptyBody => 'أضف سيارتك لنعرض لك القطع المناسبة فقط.';

  @override
  String get garageAdd => 'إضافة سيارة';

  @override
  String get garageSelected => 'المختارة';

  @override
  String get garageUse => 'اختيار';

  @override
  String get garageRemove => 'إزالة السيارة';

  @override
  String garageRemoveConfirm(String car) {
    return 'إزالة $car من سياراتك؟';
  }

  @override
  String get addCarTitle => 'إضافة سيارة';

  @override
  String get addCarMake => 'اختر الشركة المصنّعة';

  @override
  String get addCarModel => 'اختر الموديل';

  @override
  String get addCarYear => 'اختر سنة الصنع والمحرك';

  @override
  String addCarSaved(String car) {
    return 'أُضيفت $car';
  }

  @override
  String get signInTitle => 'تسجيل الدخول';

  @override
  String get signInSubtitle => 'أهلًا بعودتك';

  @override
  String get fieldEmail => 'البريد الإلكتروني';

  @override
  String get fieldPassword => 'كلمة المرور';

  @override
  String get showPassword => 'إظهار كلمة المرور';

  @override
  String get hidePassword => 'إخفاء كلمة المرور';

  @override
  String get signInForgot => 'نسيت كلمة المرور؟';

  @override
  String get signInForgotSent => 'سنرسل رابط إعادة التعيين إلى بريدك عند تفعيل خدمة البريد.';

  @override
  String get signInSubmit => 'دخول';

  @override
  String get signInNoAccount => 'ليس لديك حساب؟';

  @override
  String get signInCreate => 'أنشئ حسابًا';

  @override
  String get signInDemoHint =>
      'في النسخة التجريبية يعمل أي بريد صحيح مع كلمة مرور من 8 أحرف فيها أرقام.';

  @override
  String get signUpTitle => 'إنشاء حساب';

  @override
  String get fieldName => 'الاسم';

  @override
  String get fieldPhone => 'رقم الهاتف';

  @override
  String get fieldPhoneHelp => 'تتصل بك المحلات والفنيون على هذا الرقم.';

  @override
  String get signUpSubmit => 'إنشاء الحساب';

  @override
  String get signUpHaveAccount => 'لديك حساب؟';

  @override
  String get signUpTerms => 'بإنشاء الحساب أنت توافق على الشروط وسياسة الخصوصية.';

  @override
  String signInWelcome(String name) {
    return 'أهلًا $name';
  }

  @override
  String get continueAsGuest => 'تصفّح بدون حساب';
}
