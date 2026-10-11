import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('ar'), Locale('en')];

  /// App name in the title bar and launcher
  ///
  /// In ar, this message translates to:
  /// **'شارع الغالي'**
  String get appTitle;

  /// Bottom navigation tab
  ///
  /// In ar, this message translates to:
  /// **'الرئيسية'**
  String get navHome;

  /// Bottom navigation tab: the street map of shops
  ///
  /// In ar, this message translates to:
  /// **'الشارع'**
  String get navStreet;

  /// Bottom navigation tab
  ///
  /// In ar, this message translates to:
  /// **'السلة'**
  String get navCart;

  /// Bottom navigation tab: orders, bookings and photo requests
  ///
  /// In ar, this message translates to:
  /// **'طلباتي'**
  String get navOrders;

  /// Bottom navigation tab
  ///
  /// In ar, this message translates to:
  /// **'حسابي'**
  String get navAccount;

  /// Headline on the first-launch screen
  ///
  /// In ar, this message translates to:
  /// **'قطع الغيار والتركيب في مكان واحد'**
  String get welcomeTitle;

  /// Benefit line on the first-launch screen
  ///
  /// In ar, this message translates to:
  /// **'قطع تناسب سيارتك من محلات شارع الغالي'**
  String get welcomePointFit;

  /// Benefit line on the first-launch screen
  ///
  /// In ar, this message translates to:
  /// **'قارن الأسعار بين المحلات قبل الشراء'**
  String get welcomePointCompare;

  /// Benefit line on the first-launch screen
  ///
  /// In ar, this message translates to:
  /// **'احجز فنيًا يركّبها في الورشة أو عندك'**
  String get welcomePointInstall;

  /// Placeholder of the search box on home
  ///
  /// In ar, this message translates to:
  /// **'ابحث عن قطعة، مثل: لمبات، فحمات'**
  String get homeSearchHint;

  /// Button on home when the garage is empty
  ///
  /// In ar, this message translates to:
  /// **'أضف سيارتك لترى القطع المناسبة'**
  String get homeAddCar;

  /// Link to change the selected car
  ///
  /// In ar, this message translates to:
  /// **'تغيير'**
  String get homeChangeCar;

  /// Quick action: photo request
  ///
  /// In ar, this message translates to:
  /// **'أرسل صورة القطعة'**
  String get homeQuickPhotoTitle;

  /// Quick action subtitle
  ///
  /// In ar, this message translates to:
  /// **'لم تجدها؟ المحلات ترسل لك عروضًا'**
  String get homeQuickPhotoBody;

  /// Quick action: book a technician for a part you already have
  ///
  /// In ar, this message translates to:
  /// **'احجز فني تركيب'**
  String get homeQuickBookTitle;

  /// Quick action subtitle
  ///
  /// In ar, this message translates to:
  /// **'في الورشة أو في مكانك'**
  String get homeQuickBookBody;

  /// Section title
  ///
  /// In ar, this message translates to:
  /// **'تسوّق حسب القسم'**
  String get homeCategories;

  /// Section title with the selected car model
  ///
  /// In ar, this message translates to:
  /// **'عروض لسيارتك {model}'**
  String homeDealsFor(String model);

  /// Section title when no car is selected
  ///
  /// In ar, this message translates to:
  /// **'عروض اليوم'**
  String get homeDeals;

  /// Section title
  ///
  /// In ar, this message translates to:
  /// **'محلات الشارع'**
  String get homeStreetTitle;

  /// Shop count on the street
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{محل واحد على طول شارع الغالي} =2{محلان على طول شارع الغالي} few{{count} محلات على طول شارع الغالي} other{{count} محلًا على طول شارع الغالي}}'**
  String homeStreetBody(int count);

  /// Button to the street tab
  ///
  /// In ar, this message translates to:
  /// **'افتح خريطة الشارع'**
  String get homeStreetOpen;

  /// Trust line
  ///
  /// In ar, this message translates to:
  /// **'ادفع ببنكك أو نقدًا'**
  String get homeTrustPay;

  /// Trust line
  ///
  /// In ar, this message translates to:
  /// **'فنيون موثّقون ومقيّمون'**
  String get homeTrustTech;

  /// Trust line
  ///
  /// In ar, this message translates to:
  /// **'إرجاع خلال {days} أيام'**
  String homeTrustReturns(int days);

  /// Card title for the next booking
  ///
  /// In ar, this message translates to:
  /// **'موعد التركيب القادم'**
  String get homeNextFitting;

  /// Card title for an order in progress
  ///
  /// In ar, this message translates to:
  /// **'طلبك الحالي'**
  String get homeCurrentOrder;

  /// Screen title
  ///
  /// In ar, this message translates to:
  /// **'الإشعارات'**
  String get notificationsTitle;

  /// Action
  ///
  /// In ar, this message translates to:
  /// **'تعيين الكل كمقروء'**
  String get notificationsMarkRead;

  /// Empty state
  ///
  /// In ar, this message translates to:
  /// **'لا توجد إشعارات'**
  String get notificationsEmpty;

  /// Empty state
  ///
  /// In ar, this message translates to:
  /// **'سنخبرك هنا بتأكيد الدفع وعروض المحلات ومواعيدك.'**
  String get notificationsEmptyBody;

  /// Search field placeholder
  ///
  /// In ar, this message translates to:
  /// **'ابحث عن قطعة أو رقم قطعة'**
  String get searchHint;

  /// Open the filters sheet
  ///
  /// In ar, this message translates to:
  /// **'الفلاتر'**
  String get searchFilters;

  /// Filter chip
  ///
  /// In ar, this message translates to:
  /// **'يناسب سيارتي فقط'**
  String get searchFitsOnly;

  /// Sort option
  ///
  /// In ar, this message translates to:
  /// **'الأنسب'**
  String get sortRelevance;

  /// Sort option
  ///
  /// In ar, this message translates to:
  /// **'الأقل سعرًا'**
  String get sortPriceLow;

  /// Sort option
  ///
  /// In ar, this message translates to:
  /// **'الأعلى سعرًا'**
  String get sortPriceHigh;

  /// Sort option
  ///
  /// In ar, this message translates to:
  /// **'الأعلى تقييمًا'**
  String get sortRating;

  /// Line above results
  ///
  /// In ar, this message translates to:
  /// **'نعرض القطع المناسبة لـ {car}'**
  String searchShowingFor(String car);

  /// Line above results without a car
  ///
  /// In ar, this message translates to:
  /// **'أضف سيارتك لنعرض القطع المناسبة فقط'**
  String get searchNoCar;

  /// Section title
  ///
  /// In ar, this message translates to:
  /// **'عمليات بحث سابقة'**
  String get searchRecent;

  /// Section title
  ///
  /// In ar, this message translates to:
  /// **'الأكثر طلبًا'**
  String get searchPopular;

  /// Result count
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{لا نتائج} =1{نتيجة واحدة} =2{نتيجتان} few{{count} نتائج} other{{count} نتيجة}}'**
  String searchResults(int count);

  /// Number of shops
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{محل واحد} =2{محلان} few{{count} محلات} other{{count} محلًا}}'**
  String shopsCount(int count);

  /// Empty state
  ///
  /// In ar, this message translates to:
  /// **'لم نجد قطعًا مطابقة'**
  String get searchNoResults;

  /// Empty state
  ///
  /// In ar, this message translates to:
  /// **'جرّب كلمة أخرى، أو أرسل صورة القطعة وستصلك عروض من المحلات.'**
  String get searchNoResultsBody;

  /// Empty-state action
  ///
  /// In ar, this message translates to:
  /// **'أرسل صورة القطعة'**
  String get searchSendPhoto;

  /// Sheet title
  ///
  /// In ar, this message translates to:
  /// **'الفلاتر'**
  String get filtersTitle;

  /// Filter group
  ///
  /// In ar, this message translates to:
  /// **'الحالة'**
  String get filtersCondition;

  /// Filter group
  ///
  /// In ar, this message translates to:
  /// **'أقصى سعر'**
  String get filtersMaxPrice;

  /// Price option
  ///
  /// In ar, this message translates to:
  /// **'أي سعر'**
  String get filtersAnyPrice;

  /// Price option
  ///
  /// In ar, this message translates to:
  /// **'حتى {amount}'**
  String filtersUpTo(String amount);

  /// Filter group
  ///
  /// In ar, this message translates to:
  /// **'الترتيب'**
  String get filtersSort;

  /// Reset filters
  ///
  /// In ar, this message translates to:
  /// **'مسح الكل'**
  String get filtersReset;

  /// Apply filters
  ///
  /// In ar, this message translates to:
  /// **'عرض النتائج'**
  String get filtersApply;

  /// Banner on part screen
  ///
  /// In ar, this message translates to:
  /// **'يناسب {car}'**
  String partFits(String car);

  /// Banner when fitment is unknown
  ///
  /// In ar, this message translates to:
  /// **'لا تتوفر لدينا بيانات المطابقة لهذه القطعة. اسأل المحل قبل الشراء.'**
  String get partCheck;

  /// Banner when the part does not fit
  ///
  /// In ar, this message translates to:
  /// **'هذه القطعة لا تناسب {car}.'**
  String partNoFit(String car);

  /// Banner without a car
  ///
  /// In ar, this message translates to:
  /// **'أضف سيارتك لنتأكد أن القطعة تناسبها.'**
  String get partNoCar;

  /// OEM number label
  ///
  /// In ar, this message translates to:
  /// **'رقم القطعة الأصلي'**
  String get partOem;

  /// Section title above shop offers
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{محل واحد يبيعها} =2{قارن بين محلين} few{قارن بين {count} محلات} other{قارن بين {count} محلًا}}'**
  String partCompare(int count);

  /// Pill on the cheapest offer
  ///
  /// In ar, this message translates to:
  /// **'أفضل سعر'**
  String get partBestPrice;

  /// Button
  ///
  /// In ar, this message translates to:
  /// **'أضف للسلة'**
  String get partAddToCart;

  /// Snackbar
  ///
  /// In ar, this message translates to:
  /// **'أُضيفت إلى السلة'**
  String get partAdded;

  /// Snackbar action
  ///
  /// In ar, this message translates to:
  /// **'عرض السلة'**
  String get partViewCart;

  /// Card title
  ///
  /// In ar, this message translates to:
  /// **'تحتاج تركيبًا؟'**
  String get partFittingTitle;

  /// Card body
  ///
  /// In ar, this message translates to:
  /// **'أضف التركيب من السلة: في ورشة على الشارع أو في مكانك. أجرة التركيب من {amount}.'**
  String partFittingBody(String amount);

  /// Section title
  ///
  /// In ar, this message translates to:
  /// **'عن القطعة'**
  String get partAbout;

  /// Pill
  ///
  /// In ar, this message translates to:
  /// **'مفتوح الآن'**
  String get shopOpen;

  /// Pill
  ///
  /// In ar, this message translates to:
  /// **'مغلق الآن'**
  String get shopClosed;

  /// Button
  ///
  /// In ar, this message translates to:
  /// **'اعرضه على الشارع'**
  String get shopOnStreet;

  /// Tab
  ///
  /// In ar, this message translates to:
  /// **'القطع'**
  String get shopParts;

  /// Tab
  ///
  /// In ar, this message translates to:
  /// **'التقييمات'**
  String get shopReviews;

  /// Section title
  ///
  /// In ar, this message translates to:
  /// **'عن المحل'**
  String get shopAbout;

  /// Membership line
  ///
  /// In ar, this message translates to:
  /// **'على المنصة منذ {year}'**
  String shopSince(String year);

  /// Empty state
  ///
  /// In ar, this message translates to:
  /// **'لا توجد تقييمات بعد'**
  String get shopNoReviews;

  /// Button
  ///
  /// In ar, this message translates to:
  /// **'عرض المحل'**
  String get viewShop;

  /// Hint above the street strip
  ///
  /// In ar, this message translates to:
  /// **'اضغط على أي محل لعرض تفاصيله'**
  String get streetHint;

  /// Filter chip: all categories
  ///
  /// In ar, this message translates to:
  /// **'الكل'**
  String get streetAll;

  /// Compass label at one end of the street
  ///
  /// In ar, this message translates to:
  /// **'شمال'**
  String get streetNorth;

  /// Compass label at the other end
  ///
  /// In ar, this message translates to:
  /// **'جنوب'**
  String get streetSouth;

  /// Empty state
  ///
  /// In ar, this message translates to:
  /// **'سلتك فارغة'**
  String get cartEmpty;

  /// Empty state
  ///
  /// In ar, this message translates to:
  /// **'ابحث عن القطعة التي تحتاجها وأضفها هنا.'**
  String get cartEmptyBody;

  /// Empty-state action
  ///
  /// In ar, this message translates to:
  /// **'تصفّح القطع'**
  String get cartBrowse;

  /// Button under an installable item
  ///
  /// In ar, this message translates to:
  /// **'أضف التركيب'**
  String get cartAddFitting;

  /// Hint next to the add-fitting button
  ///
  /// In ar, this message translates to:
  /// **'أجرة التركيب من {amount}'**
  String cartFittingFrom(String amount);

  /// Label of the fitting block
  ///
  /// In ar, this message translates to:
  /// **'التركيب'**
  String get cartFitting;

  /// Technician name when the buyer chose any
  ///
  /// In ar, this message translates to:
  /// **'أول فني متاح'**
  String get cartAnyTech;

  /// Fitting place
  ///
  /// In ar, this message translates to:
  /// **'في الورشة'**
  String get placeBay;

  /// Fitting place
  ///
  /// In ar, this message translates to:
  /// **'في مكانك'**
  String get placeHome;

  /// Countdown on a held slot, e.g. 'held for 9:32'
  ///
  /// In ar, this message translates to:
  /// **'محجوز لك {time}'**
  String cartHeldFor(String time);

  /// Shown when the slot hold lapsed
  ///
  /// In ar, this message translates to:
  /// **'انتهى الحجز المؤقت. اختر موعدًا جديدًا.'**
  String get cartHoldExpired;

  /// Change the fitting
  ///
  /// In ar, this message translates to:
  /// **'تغيير'**
  String get cartChange;

  /// Remove the fitting
  ///
  /// In ar, this message translates to:
  /// **'إزالة التركيب'**
  String get cartRemoveFitting;

  /// Remove an item
  ///
  /// In ar, this message translates to:
  /// **'إزالة من السلة'**
  String get cartRemoveItem;

  /// Section title
  ///
  /// In ar, this message translates to:
  /// **'ملخص الطلب'**
  String get cartSummary;

  /// Cost line
  ///
  /// In ar, this message translates to:
  /// **'القطع'**
  String get costParts;

  /// Cost line
  ///
  /// In ar, this message translates to:
  /// **'أجرة التركيب'**
  String get costLabour;

  /// Cost line: technician travel fee
  ///
  /// In ar, this message translates to:
  /// **'رسوم المشوار'**
  String get costTravel;

  /// Cost line
  ///
  /// In ar, this message translates to:
  /// **'رسوم الحجز'**
  String get costBookingFee;

  /// Cost line
  ///
  /// In ar, this message translates to:
  /// **'التوصيل'**
  String get costDelivery;

  /// Cost line
  ///
  /// In ar, this message translates to:
  /// **'الإجمالي'**
  String get costTotal;

  /// Free
  ///
  /// In ar, this message translates to:
  /// **'مجانًا'**
  String get costFree;

  /// Note in the cart summary
  ///
  /// In ar, this message translates to:
  /// **'تختار الاستلام أو التوصيل في الخطوة التالية.'**
  String get cartDeliveryLater;

  /// Main cart button
  ///
  /// In ar, this message translates to:
  /// **'متابعة الدفع'**
  String get cartCheckout;

  /// Number of items
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{قطعة واحدة} =2{قطعتان} few{{count} قطع} other{{count} قطعة}}'**
  String itemsCount(int count);

  /// Booking flow title
  ///
  /// In ar, this message translates to:
  /// **'حجز التركيب'**
  String get bookTitle;

  /// Step label
  ///
  /// In ar, this message translates to:
  /// **'القطعة'**
  String get bookStepWhat;

  /// Step label
  ///
  /// In ar, this message translates to:
  /// **'المكان'**
  String get bookStepPlace;

  /// Step label
  ///
  /// In ar, this message translates to:
  /// **'الفني'**
  String get bookStepTech;

  /// Step label
  ///
  /// In ar, this message translates to:
  /// **'الموعد'**
  String get bookStepTime;

  /// Step title for a part bought elsewhere
  ///
  /// In ar, this message translates to:
  /// **'ماذا تريد أن تركّب؟'**
  String get bookWhatTitle;

  /// Field hint
  ///
  /// In ar, this message translates to:
  /// **'صف القطعة، مثل: لمبة أمامية يمين'**
  String get bookWhatHint;

  /// Field label
  ///
  /// In ar, this message translates to:
  /// **'نوع العمل'**
  String get bookWhatJob;

  /// Hint for parts bought elsewhere
  ///
  /// In ar, this message translates to:
  /// **'اشتريت القطعة من مكان آخر؟ لا مشكلة، أحضرها معك أو جهّزها للفني.'**
  String get bookWhatNote;

  /// Step title
  ///
  /// In ar, this message translates to:
  /// **'أين تريد التركيب؟'**
  String get bookPlaceTitle;

  /// Option
  ///
  /// In ar, this message translates to:
  /// **'في ورشة على شارع الغالي'**
  String get bookPlaceBay;

  /// Option detail
  ///
  /// In ar, this message translates to:
  /// **'بدون رسوم مشوار. تُحضر السيارة إلى الورشة.'**
  String get bookPlaceBayBody;

  /// Option
  ///
  /// In ar, this message translates to:
  /// **'في مكانك'**
  String get bookPlaceHome;

  /// Option detail
  ///
  /// In ar, this message translates to:
  /// **'يأتيك الفني إلى البيت أو العمل. رسوم المشوار من {amount}.'**
  String bookPlaceHomeBody(String amount);

  /// Address group label
  ///
  /// In ar, this message translates to:
  /// **'العنوان'**
  String get bookAddress;

  /// Adds the phone's current location as an address
  ///
  /// In ar, this message translates to:
  /// **'استخدم موقعي الحالي'**
  String get bookUseLocation;

  /// Step title
  ///
  /// In ar, this message translates to:
  /// **'اختر الفني'**
  String get bookTechTitle;

  /// Option
  ///
  /// In ar, this message translates to:
  /// **'أول فني متاح'**
  String get bookAnyTech;

  /// Option detail
  ///
  /// In ar, this message translates to:
  /// **'نختار لك أفضل فني متاح في الموعد الذي تختاره.'**
  String get bookAnyTechBody;

  /// Where a technician works
  ///
  /// In ar, this message translates to:
  /// **'ورشة {shop}'**
  String bookAtBay(String shop);

  /// Distance of a mobile technician
  ///
  /// In ar, this message translates to:
  /// **'يبعد {distance}'**
  String bookAway(String distance);

  /// Years of experience
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{خبرة سنة} =2{خبرة سنتين} few{خبرة {count} سنوات} other{خبرة {count} سنة}}'**
  String bookYears(int count);

  /// Empty state
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد فني متاح لهذا العمل في هذا المكان حاليًا. جرّب مكانًا آخر.'**
  String get bookNoTechs;

  /// Step title
  ///
  /// In ar, this message translates to:
  /// **'اختر الموعد'**
  String get bookTimeTitle;

  /// Note on the time step
  ///
  /// In ar, this message translates to:
  /// **'أقرب موعد بعد ساعتين، حتى يجهّز المحل القطعة.'**
  String get bookEarliest;

  /// Empty state
  ///
  /// In ar, this message translates to:
  /// **'لا توجد مواعيد متاحة في هذا اليوم. اختر يومًا آخر.'**
  String get bookNoSlots;

  /// The day is a day off (Friday)
  ///
  /// In ar, this message translates to:
  /// **'لا عمل في هذا اليوم.'**
  String get bookDayOff;

  /// Step title
  ///
  /// In ar, this message translates to:
  /// **'راجع الحجز'**
  String get bookReviewTitle;

  /// Summary label
  ///
  /// In ar, this message translates to:
  /// **'المدة المتوقعة'**
  String get bookDuration;

  /// Policy note
  ///
  /// In ar, this message translates to:
  /// **'الإلغاء مجاني حتى {hours} ساعات قبل الموعد.'**
  String bookCancelNote(int hours);

  /// Button that holds the slot
  ///
  /// In ar, this message translates to:
  /// **'احجز هذا الموعد'**
  String get bookHold;

  /// Hold explanation
  ///
  /// In ar, this message translates to:
  /// **'نحجز لك الموعد {minutes} دقائق حتى تُكمل الدفع.'**
  String bookHoldNote(int minutes);

  /// Button for a stand-alone booking
  ///
  /// In ar, this message translates to:
  /// **'تأكيد الحجز'**
  String get bookConfirm;

  /// Cash + home visit rule
  ///
  /// In ar, this message translates to:
  /// **'يُدفع عربون {amount} عبر بنكك لتأكيد زيارة الفني، والباقي نقدًا.'**
  String bookDepositNote(String amount);

  /// Disabled-button hint
  ///
  /// In ar, this message translates to:
  /// **'اختر موعدًا للمتابعة'**
  String get bookPickTime;

  /// Summary label
  ///
  /// In ar, this message translates to:
  /// **'الموعد'**
  String get bookWhen;

  /// Screen title
  ///
  /// In ar, this message translates to:
  /// **'إتمام الطلب'**
  String get checkoutTitle;

  /// Section title
  ///
  /// In ar, this message translates to:
  /// **'طريقة الاستلام'**
  String get checkoutReceive;

  /// Pickup option detail
  ///
  /// In ar, this message translates to:
  /// **'{place} — مجانًا'**
  String checkoutPickupBody(String place);

  /// Delivery option detail
  ///
  /// In ar, this message translates to:
  /// **'إلى {address}'**
  String checkoutDeliveryTo(String address);

  /// Fulfilment when fitting is booked
  ///
  /// In ar, this message translates to:
  /// **'يسلّم المحل القطعة لفنيك قبل الموعد.'**
  String get checkoutToTechBody;

  /// Section title
  ///
  /// In ar, this message translates to:
  /// **'طريقة الدفع'**
  String get checkoutPayment;

  /// Payment option
  ///
  /// In ar, this message translates to:
  /// **'تحويل بنكك'**
  String get checkoutBankak;

  /// Payment option detail
  ///
  /// In ar, this message translates to:
  /// **'حوّل المبلغ ثم ارفع الإيصال. نؤكد الدفع خلال ساعات العمل.'**
  String get checkoutBankakBody;

  /// Payment option
  ///
  /// In ar, this message translates to:
  /// **'نقدًا'**
  String get checkoutCash;

  /// Payment option detail
  ///
  /// In ar, this message translates to:
  /// **'ادفع عند الاستلام أو التوصيل أو للفني.'**
  String get checkoutCashBody;

  /// Payment window rule
  ///
  /// In ar, this message translates to:
  /// **'ادفع خلال ساعتين، وإلا يُلغى الطلب تلقائيًا وتعود القطع للمحل.'**
  String get checkoutPayWithin;

  /// Amount paid upfront
  ///
  /// In ar, this message translates to:
  /// **'المطلوب الآن عبر بنكك'**
  String get checkoutDueNow;

  /// Amount paid in cash later
  ///
  /// In ar, this message translates to:
  /// **'الباقي نقدًا'**
  String get checkoutRestCash;

  /// Main button
  ///
  /// In ar, this message translates to:
  /// **'تأكيد الطلب'**
  String get checkoutPlace;

  /// Legal note
  ///
  /// In ar, this message translates to:
  /// **'بتأكيد الطلب أنت توافق على شروط الاستخدام وسياسة الإرجاع.'**
  String get checkoutTerms;

  /// Shown to guests
  ///
  /// In ar, this message translates to:
  /// **'سجّل الدخول لإتمام الطلب'**
  String get checkoutSignIn;

  /// Screen title
  ///
  /// In ar, this message translates to:
  /// **'الدفع عبر بنكك'**
  String get bankakTitle;

  /// Amount label
  ///
  /// In ar, this message translates to:
  /// **'حوّل هذا المبلغ بالضبط'**
  String get bankakAmount;

  /// Instruction step
  ///
  /// In ar, this message translates to:
  /// **'افتح تطبيق بنكك وحوّل إلى هذا الحساب'**
  String get bankakStep1;

  /// Field label
  ///
  /// In ar, this message translates to:
  /// **'اسم الحساب'**
  String get bankakAccountName;

  /// Field label
  ///
  /// In ar, this message translates to:
  /// **'رقم الحساب'**
  String get bankakAccountNumber;

  /// Warning in the demo
  ///
  /// In ar, this message translates to:
  /// **'حساب تجريبي — لا تحوّل إليه'**
  String get bankakSample;

  /// Instruction step
  ///
  /// In ar, this message translates to:
  /// **'اكتب رقم الطلب في خانة التعليق'**
  String get bankakStep2;

  /// Field label
  ///
  /// In ar, this message translates to:
  /// **'رقم الطلب'**
  String get bankakRef;

  /// Instruction step
  ///
  /// In ar, this message translates to:
  /// **'ارفع صورة الإيصال أو اكتب رقم العملية'**
  String get bankakStep3;

  /// Button
  ///
  /// In ar, this message translates to:
  /// **'ارفع صورة الإيصال'**
  String get bankakUpload;

  /// Upload done
  ///
  /// In ar, this message translates to:
  /// **'تم إرفاق صورة الإيصال'**
  String get bankakUploaded;

  /// Field label
  ///
  /// In ar, this message translates to:
  /// **'رقم العملية'**
  String get bankakTxn;

  /// Field help
  ///
  /// In ar, this message translates to:
  /// **'يظهر في إيصال بنكك'**
  String get bankakTxnHint;

  /// Main button
  ///
  /// In ar, this message translates to:
  /// **'إرسال للتحقق'**
  String get bankakSubmit;

  /// Validation
  ///
  /// In ar, this message translates to:
  /// **'ارفع الإيصال أو اكتب رقم العملية.'**
  String get bankakNeedProof;

  /// Countdown
  ///
  /// In ar, this message translates to:
  /// **'الوقت المتبقي للدفع: {time}'**
  String bankakTimeLeft(String time);

  /// Banner title after submitting
  ///
  /// In ar, this message translates to:
  /// **'جارٍ التحقق من الدفع'**
  String get bankakChecking;

  /// Banner body
  ///
  /// In ar, this message translates to:
  /// **'نطابق تحويلك مع كشف الحساب، عادةً خلال 30 دقيقة بين 8 ص و10 م. سنرسل لك إشعارًا.'**
  String get bankakCheckingBody;

  /// Trust note
  ///
  /// In ar, this message translates to:
  /// **'لا نعتبر الطلب مدفوعًا من صورة الإيصال وحدها، بل بعد مطابقتها مع البنك.'**
  String get bankakNever;

  /// Tab
  ///
  /// In ar, this message translates to:
  /// **'الطلبات'**
  String get ordersTabOrders;

  /// Tab
  ///
  /// In ar, this message translates to:
  /// **'الحجوزات'**
  String get ordersTabBookings;

  /// Tab
  ///
  /// In ar, this message translates to:
  /// **'طلبات الصور'**
  String get ordersTabRequests;

  /// Empty state
  ///
  /// In ar, this message translates to:
  /// **'لا توجد طلبات بعد'**
  String get ordersEmpty;

  /// Empty state
  ///
  /// In ar, this message translates to:
  /// **'ستظهر طلباتك هنا بعد الشراء.'**
  String get ordersEmptyBody;

  /// Empty state
  ///
  /// In ar, this message translates to:
  /// **'لا توجد حجوزات'**
  String get bookingsEmpty;

  /// Empty state
  ///
  /// In ar, this message translates to:
  /// **'احجز فنيًا لتركيب قطعتك في الورشة أو في مكانك.'**
  String get bookingsEmptyBody;

  /// Empty state
  ///
  /// In ar, this message translates to:
  /// **'لا توجد طلبات صور'**
  String get requestsEmpty;

  /// Empty state
  ///
  /// In ar, this message translates to:
  /// **'أرسل صورة القطعة وستصلك عروض من المحلات.'**
  String get requestsEmptyBody;

  /// Guest state
  ///
  /// In ar, this message translates to:
  /// **'سجّل الدخول لترى طلباتك'**
  String get ordersSignIn;

  /// Guest state
  ///
  /// In ar, this message translates to:
  /// **'تابع طلباتك وحجوزاتك وعروض المحلات من مكان واحد.'**
  String get ordersSignInBody;

  /// Order title with reference
  ///
  /// In ar, this message translates to:
  /// **'طلب {ref}'**
  String orderRef(String ref);

  /// Booking title with reference
  ///
  /// In ar, this message translates to:
  /// **'حجز {ref}'**
  String bookingRefTitle(String ref);

  /// Screen title
  ///
  /// In ar, this message translates to:
  /// **'تفاصيل الطلب'**
  String get orderTitle;

  /// Order date
  ///
  /// In ar, this message translates to:
  /// **'تاريخ الطلب: {date}'**
  String orderPlacedOn(String date);

  /// Button
  ///
  /// In ar, this message translates to:
  /// **'ادفع الآن'**
  String get orderPayNow;

  /// Banner title
  ///
  /// In ar, this message translates to:
  /// **'بانتظار تحويلك'**
  String get orderAwaiting;

  /// Banner body
  ///
  /// In ar, this message translates to:
  /// **'حوّل {amount} عبر بنكك قبل {time} وإلا يُلغى الطلب.'**
  String orderAwaitingBody(String amount, String time);

  /// Pickup location line
  ///
  /// In ar, this message translates to:
  /// **'الاستلام: {place}'**
  String orderPickupWhere(String place);

  /// Button
  ///
  /// In ar, this message translates to:
  /// **'إلغاء الطلب'**
  String get orderCancel;

  /// Dialog title
  ///
  /// In ar, this message translates to:
  /// **'هل تريد إلغاء الطلب؟'**
  String get orderCancelConfirm;

  /// Dialog body
  ///
  /// In ar, this message translates to:
  /// **'تعود القطع للمحل ويُلغى أي موعد تركيب مرتبط بالطلب.'**
  String get orderCancelBody;

  /// Dialog button
  ///
  /// In ar, this message translates to:
  /// **'الاحتفاظ بالطلب'**
  String get orderKeep;

  /// Button
  ///
  /// In ar, this message translates to:
  /// **'طلب إرجاع'**
  String get orderReturn;

  /// Return policy
  ///
  /// In ar, this message translates to:
  /// **'يمكنك الإرجاع خلال {days} أيام من الاستلام.'**
  String orderReturnBody(int days);

  /// Snackbar
  ///
  /// In ar, this message translates to:
  /// **'أرسلنا طلب الإرجاع، سيتواصل معك المحل.'**
  String get orderReturnSent;

  /// Button
  ///
  /// In ar, this message translates to:
  /// **'قيّم المحل'**
  String get orderRateShop;

  /// Linked booking card title
  ///
  /// In ar, this message translates to:
  /// **'موعد التركيب'**
  String get orderFitting;

  /// Timeline step
  ///
  /// In ar, this message translates to:
  /// **'تم الطلب'**
  String get tlPlaced;

  /// Timeline step
  ///
  /// In ar, this message translates to:
  /// **'تأكيد الدفع'**
  String get tlPaymentChecked;

  /// Timeline step
  ///
  /// In ar, this message translates to:
  /// **'أكّد المحل'**
  String get tlShopConfirmed;

  /// Timeline step
  ///
  /// In ar, this message translates to:
  /// **'القطعة جاهزة'**
  String get tlReady;

  /// Timeline step
  ///
  /// In ar, this message translates to:
  /// **'استلمت القطعة'**
  String get tlPickedUp;

  /// Timeline step
  ///
  /// In ar, this message translates to:
  /// **'في الطريق إليك'**
  String get tlOnTheWay;

  /// Timeline step
  ///
  /// In ar, this message translates to:
  /// **'وصلت إليك'**
  String get tlDelivered;

  /// Timeline step
  ///
  /// In ar, this message translates to:
  /// **'سُلّمت للفني'**
  String get tlHanded;

  /// Timeline step
  ///
  /// In ar, this message translates to:
  /// **'اكتمل'**
  String get tlCompleted;

  /// Timeline step
  ///
  /// In ar, this message translates to:
  /// **'تم الحجز'**
  String get tlBooked;

  /// Timeline step
  ///
  /// In ar, this message translates to:
  /// **'وافق الفني'**
  String get tlTechAccepted;

  /// Timeline step
  ///
  /// In ar, this message translates to:
  /// **'الفني في الطريق'**
  String get tlEnRoute;

  /// Timeline step
  ///
  /// In ar, this message translates to:
  /// **'جارٍ العمل'**
  String get tlWorking;

  /// Timeline step
  ///
  /// In ar, this message translates to:
  /// **'اكتمل العمل'**
  String get tlJobDone;

  /// Banner
  ///
  /// In ar, this message translates to:
  /// **'أُلغي هذا الطلب.'**
  String get orderCancelled;

  /// Card title (demo only)
  ///
  /// In ar, this message translates to:
  /// **'أدوات العرض التجريبي'**
  String get demoControls;

  /// Button (demo only)
  ///
  /// In ar, this message translates to:
  /// **'محاكاة الخطوة التالية'**
  String get demoNextStep;

  /// Explains the demo button
  ///
  /// In ar, this message translates to:
  /// **'يحرّك الطلب كما لو أن الإدارة والمحل والفني قاموا بدورهم.'**
  String get demoNextStepBody;

  /// Screen title
  ///
  /// In ar, this message translates to:
  /// **'موعد التركيب'**
  String get bookingTitle;

  /// Job code card title
  ///
  /// In ar, this message translates to:
  /// **'رمز إنهاء العمل'**
  String get bookingCode;

  /// Job code explanation
  ///
  /// In ar, this message translates to:
  /// **'أعطِ هذا الرمز للفني فقط بعد انتهاء العمل ورضاك عنه.'**
  String get bookingCodeBody;

  /// Section label
  ///
  /// In ar, this message translates to:
  /// **'الفني'**
  String get bookingTech;

  /// Section label
  ///
  /// In ar, this message translates to:
  /// **'المكان'**
  String get bookingWhere;

  /// Section label
  ///
  /// In ar, this message translates to:
  /// **'العمل'**
  String get bookingJob;

  /// Banner
  ///
  /// In ar, this message translates to:
  /// **'{name} في الطريق إليك، يصل خلال 15 دقيقة تقريبًا.'**
  String bookingEnRoute(String name);

  /// Banner
  ///
  /// In ar, this message translates to:
  /// **'ننتظر موافقة الفني، عادةً خلال {minutes} دقيقة.'**
  String bookingWaitingTech(int minutes);

  /// Button
  ///
  /// In ar, this message translates to:
  /// **'تغيير الموعد'**
  String get bookingReschedule;

  /// Button
  ///
  /// In ar, this message translates to:
  /// **'إلغاء الموعد'**
  String get bookingCancel;

  /// Policy line
  ///
  /// In ar, this message translates to:
  /// **'الإلغاء مجاني حتى {time}.'**
  String bookingCancelFree(String time);

  /// Dialog title
  ///
  /// In ar, this message translates to:
  /// **'هل تريد إلغاء الموعد؟'**
  String get bookingCancelConfirm;

  /// Dialog button
  ///
  /// In ar, this message translates to:
  /// **'الاحتفاظ بالموعد'**
  String get bookingKeep;

  /// Button
  ///
  /// In ar, this message translates to:
  /// **'قيّم الفني'**
  String get bookingRate;

  /// Snackbar
  ///
  /// In ar, this message translates to:
  /// **'اختر موعدًا جديدًا من خطوة الموعد.'**
  String get bookingRescheduleSoon;

  /// Screen title
  ///
  /// In ar, this message translates to:
  /// **'اطلب بالصورة'**
  String get requestNewTitle;

  /// Explanation
  ///
  /// In ar, this message translates to:
  /// **'صوّر القطعة القديمة أو مكانها في السيارة. ترسل لك المحلات عروضًا، عادةً خلال ساعة.'**
  String get requestNewIntro;

  /// Button
  ///
  /// In ar, this message translates to:
  /// **'إضافة صورة'**
  String get requestAddPhoto;

  /// Photo counter
  ///
  /// In ar, this message translates to:
  /// **'الصور ({count} من 3)'**
  String requestPhotos(int count);

  /// Field label
  ///
  /// In ar, this message translates to:
  /// **'السيارة'**
  String get requestCar;

  /// Field label
  ///
  /// In ar, this message translates to:
  /// **'القسم'**
  String get requestCategory;

  /// Field label
  ///
  /// In ar, this message translates to:
  /// **'صف القطعة'**
  String get requestNote;

  /// Field hint
  ///
  /// In ar, this message translates to:
  /// **'مثال: مقبض الباب الخلفي اليمين، كروم'**
  String get requestNoteHint;

  /// Main button
  ///
  /// In ar, this message translates to:
  /// **'إرسال للمحلات'**
  String get requestSend;

  /// Validation
  ///
  /// In ar, this message translates to:
  /// **'أضف صورة واحدة على الأقل.'**
  String get requestNeedPhoto;

  /// Screen title
  ///
  /// In ar, this message translates to:
  /// **'طلب بالصورة'**
  String get requestTitle;

  /// Offer count
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{لا عروض بعد} =1{عرض واحد} =2{عرضان} few{{count} عروض} other{{count} عرضًا}}'**
  String requestOffers(int count);

  /// Empty state
  ///
  /// In ar, this message translates to:
  /// **'أبلغنا المحلات المتخصصة. سنرسل لك إشعارًا عند وصول عرض.'**
  String get requestNoOffersBody;

  /// Request expiry
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{ينتهي خلال ساعة} =2{ينتهي خلال ساعتين} few{ينتهي خلال {count} ساعات} other{ينتهي خلال {count} ساعة}}'**
  String requestExpiresIn(int count);

  /// Offer validity
  ///
  /// In ar, this message translates to:
  /// **'صالح حتى {time}'**
  String requestValidUntil(String time);

  /// Button
  ///
  /// In ar, this message translates to:
  /// **'إغلاق الطلب'**
  String get requestClose;

  /// Status
  ///
  /// In ar, this message translates to:
  /// **'مفتوح'**
  String get requestStatusOpen;

  /// Status
  ///
  /// In ar, this message translates to:
  /// **'مغلق'**
  String get requestStatusClosed;

  /// Status
  ///
  /// In ar, this message translates to:
  /// **'منتهٍ'**
  String get requestStatusExpired;

  /// Snackbar
  ///
  /// In ar, this message translates to:
  /// **'أرسلنا طلبك للمحلات.'**
  String get requestSent;

  /// Accessibility label for a sample photo
  ///
  /// In ar, this message translates to:
  /// **'صورة {index}'**
  String photoPlaceholder(int index);

  /// Composer hint
  ///
  /// In ar, this message translates to:
  /// **'اكتب رسالة'**
  String get chatHint;

  /// Voice note label
  ///
  /// In ar, this message translates to:
  /// **'رسالة صوتية'**
  String get chatVoice;

  /// Send button tooltip
  ///
  /// In ar, this message translates to:
  /// **'إرسال'**
  String get chatSend;

  /// Mic button tooltip
  ///
  /// In ar, this message translates to:
  /// **'تسجيل رسالة صوتية'**
  String get chatRecord;

  /// Voice note hint
  ///
  /// In ar, this message translates to:
  /// **'اضغط مطولًا على الميكروفون للتسجيل، حتى 60 ثانية.'**
  String get chatVoiceSoon;

  /// Empty chat hint
  ///
  /// In ar, this message translates to:
  /// **'اسأل المحل عن القطعة أو السعر أو موعد التجهيز.'**
  String get chatEmpty;

  /// Sheet title
  ///
  /// In ar, this message translates to:
  /// **'قيّم {name}'**
  String reviewTitle(String name);

  /// Tag group label
  ///
  /// In ar, this message translates to:
  /// **'ما الذي أعجبك؟'**
  String get reviewTags;

  /// Review tag
  ///
  /// In ar, this message translates to:
  /// **'قطعة أصلية'**
  String get reviewTagGenuine;

  /// Review tag
  ///
  /// In ar, this message translates to:
  /// **'سريع'**
  String get reviewTagFast;

  /// Review tag
  ///
  /// In ar, this message translates to:
  /// **'سعر مناسب'**
  String get reviewTagPrice;

  /// Review tag
  ///
  /// In ar, this message translates to:
  /// **'تعامل محترم'**
  String get reviewTagPolite;

  /// Review tag
  ///
  /// In ar, this message translates to:
  /// **'في الموعد'**
  String get reviewTagOnTime;

  /// Field label
  ///
  /// In ar, this message translates to:
  /// **'أضف تعليقًا (اختياري)'**
  String get reviewComment;

  /// Button
  ///
  /// In ar, this message translates to:
  /// **'إرسال التقييم'**
  String get reviewSubmit;

  /// Snackbar
  ///
  /// In ar, this message translates to:
  /// **'شكرًا على تقييمك'**
  String get reviewThanks;

  /// Guest card title
  ///
  /// In ar, this message translates to:
  /// **'سجّل الدخول لتتابع طلباتك'**
  String get accountGuestTitle;

  /// Guest card body
  ///
  /// In ar, this message translates to:
  /// **'احفظ سياراتك وتابع طلباتك وحجوزاتك.'**
  String get accountGuestBody;

  /// Button
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الدخول'**
  String get accountSignIn;

  /// Button
  ///
  /// In ar, this message translates to:
  /// **'إنشاء حساب'**
  String get accountSignUp;

  /// Section title
  ///
  /// In ar, this message translates to:
  /// **'التسوّق'**
  String get accountShopping;

  /// Section title
  ///
  /// In ar, this message translates to:
  /// **'إعدادات التطبيق'**
  String get accountSettings;

  /// Section title
  ///
  /// In ar, this message translates to:
  /// **'الدعم'**
  String get accountSupport;

  /// Menu row
  ///
  /// In ar, this message translates to:
  /// **'سياراتي'**
  String get accountGarage;

  /// Menu row
  ///
  /// In ar, this message translates to:
  /// **'عناويني'**
  String get accountAddresses;

  /// Menu row
  ///
  /// In ar, this message translates to:
  /// **'الإشعارات'**
  String get accountNotifications;

  /// Menu row
  ///
  /// In ar, this message translates to:
  /// **'اللغة'**
  String get accountLanguage;

  /// Menu row
  ///
  /// In ar, this message translates to:
  /// **'المظهر'**
  String get accountAppearance;

  /// Theme option
  ///
  /// In ar, this message translates to:
  /// **'حسب الجهاز'**
  String get appearanceSystem;

  /// Theme option
  ///
  /// In ar, this message translates to:
  /// **'فاتح'**
  String get appearanceLight;

  /// Theme option
  ///
  /// In ar, this message translates to:
  /// **'داكن'**
  String get appearanceDark;

  /// Menu row
  ///
  /// In ar, this message translates to:
  /// **'توفير البيانات'**
  String get accountDataSaver;

  /// Menu row detail
  ///
  /// In ar, this message translates to:
  /// **'صور مصغّرة فقط حتى تضغط على الصورة'**
  String get accountDataSaverBody;

  /// Menu row
  ///
  /// In ar, this message translates to:
  /// **'المساعدة والدعم'**
  String get accountHelp;

  /// Menu row
  ///
  /// In ar, this message translates to:
  /// **'الشروط والخصوصية'**
  String get accountTerms;

  /// Placeholder until legal texts exist
  ///
  /// In ar, this message translates to:
  /// **'ستُنشر الشروط وسياسة الخصوصية وسياسة الإرجاع هنا قبل الإطلاق.'**
  String get accountTermsBody;

  /// Menu row
  ///
  /// In ar, this message translates to:
  /// **'عن التطبيق'**
  String get accountAbout;

  /// App version
  ///
  /// In ar, this message translates to:
  /// **'الإصدار {version}'**
  String accountVersion(String version);

  /// Open-source licences
  ///
  /// In ar, this message translates to:
  /// **'تراخيص البرامج'**
  String get accountLicenses;

  /// Button
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الخروج'**
  String get accountSignOut;

  /// Dialog title
  ///
  /// In ar, this message translates to:
  /// **'هل تريد تسجيل الخروج؟'**
  String get accountSignOutConfirm;

  /// Car count
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{لا سيارات} =1{سيارة واحدة} =2{سيارتان} few{{count} سيارات} other{{count} سيارة}}'**
  String accountCars(int count);

  /// Screen title
  ///
  /// In ar, this message translates to:
  /// **'سياراتي'**
  String get garageTitle;

  /// Empty state
  ///
  /// In ar, this message translates to:
  /// **'لم تُضف سيارة بعد'**
  String get garageEmpty;

  /// Empty state
  ///
  /// In ar, this message translates to:
  /// **'أضف سيارتك لنعرض لك القطع المناسبة فقط.'**
  String get garageEmptyBody;

  /// Button
  ///
  /// In ar, this message translates to:
  /// **'إضافة سيارة'**
  String get garageAdd;

  /// Pill on the selected car
  ///
  /// In ar, this message translates to:
  /// **'المختارة'**
  String get garageSelected;

  /// Select this car
  ///
  /// In ar, this message translates to:
  /// **'اختيار'**
  String get garageUse;

  /// Button
  ///
  /// In ar, this message translates to:
  /// **'إزالة السيارة'**
  String get garageRemove;

  /// Dialog title
  ///
  /// In ar, this message translates to:
  /// **'إزالة {car} من سياراتك؟'**
  String garageRemoveConfirm(String car);

  /// Screen title
  ///
  /// In ar, this message translates to:
  /// **'إضافة سيارة'**
  String get addCarTitle;

  /// Step title
  ///
  /// In ar, this message translates to:
  /// **'اختر الشركة المصنّعة'**
  String get addCarMake;

  /// Step title
  ///
  /// In ar, this message translates to:
  /// **'اختر الموديل'**
  String get addCarModel;

  /// Step title
  ///
  /// In ar, this message translates to:
  /// **'اختر سنة الصنع والمحرك'**
  String get addCarYear;

  /// Snackbar
  ///
  /// In ar, this message translates to:
  /// **'أُضيفت {car}'**
  String addCarSaved(String car);

  /// Screen title
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الدخول'**
  String get signInTitle;

  /// Greeting
  ///
  /// In ar, this message translates to:
  /// **'أهلًا بعودتك'**
  String get signInSubtitle;

  /// Field label
  ///
  /// In ar, this message translates to:
  /// **'البريد الإلكتروني'**
  String get fieldEmail;

  /// Field label
  ///
  /// In ar, this message translates to:
  /// **'كلمة المرور'**
  String get fieldPassword;

  /// Tooltip
  ///
  /// In ar, this message translates to:
  /// **'إظهار كلمة المرور'**
  String get showPassword;

  /// Tooltip
  ///
  /// In ar, this message translates to:
  /// **'إخفاء كلمة المرور'**
  String get hidePassword;

  /// Link
  ///
  /// In ar, this message translates to:
  /// **'نسيت كلمة المرور؟'**
  String get signInForgot;

  /// Snackbar (needs custom SMTP, D-031)
  ///
  /// In ar, this message translates to:
  /// **'سنرسل رابط إعادة التعيين إلى بريدك عند تفعيل خدمة البريد.'**
  String get signInForgotSent;

  /// Button
  ///
  /// In ar, this message translates to:
  /// **'دخول'**
  String get signInSubmit;

  /// Prompt
  ///
  /// In ar, this message translates to:
  /// **'ليس لديك حساب؟'**
  String get signInNoAccount;

  /// Link
  ///
  /// In ar, this message translates to:
  /// **'أنشئ حسابًا'**
  String get signInCreate;

  /// Demo hint
  ///
  /// In ar, this message translates to:
  /// **'في النسخة التجريبية يعمل أي بريد صحيح مع كلمة مرور من 8 أحرف فيها أرقام.'**
  String get signInDemoHint;

  /// Screen title
  ///
  /// In ar, this message translates to:
  /// **'إنشاء حساب'**
  String get signUpTitle;

  /// Field label
  ///
  /// In ar, this message translates to:
  /// **'الاسم'**
  String get fieldName;

  /// Field label
  ///
  /// In ar, this message translates to:
  /// **'رقم الهاتف'**
  String get fieldPhone;

  /// Field help
  ///
  /// In ar, this message translates to:
  /// **'تتصل بك المحلات والفنيون على هذا الرقم.'**
  String get fieldPhoneHelp;

  /// Button
  ///
  /// In ar, this message translates to:
  /// **'إنشاء الحساب'**
  String get signUpSubmit;

  /// Prompt
  ///
  /// In ar, this message translates to:
  /// **'لديك حساب؟'**
  String get signUpHaveAccount;

  /// Legal note
  ///
  /// In ar, this message translates to:
  /// **'بإنشاء الحساب أنت توافق على الشروط وسياسة الخصوصية.'**
  String get signUpTerms;

  /// Snackbar after signing in
  ///
  /// In ar, this message translates to:
  /// **'أهلًا {name}'**
  String signInWelcome(String name);

  /// Skip sign-in
  ///
  /// In ar, this message translates to:
  /// **'تصفّح بدون حساب'**
  String get continueAsGuest;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
