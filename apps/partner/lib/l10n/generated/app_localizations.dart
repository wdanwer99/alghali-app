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

  /// Partner app name in the title bar and launcher
  ///
  /// In ar, this message translates to:
  /// **'شركاء الغالي'**
  String get appTitle;

  /// Headline on the first-launch screen
  ///
  /// In ar, this message translates to:
  /// **'أدر محلك وأعمالك من هاتفك'**
  String get welcomeTitle;

  /// Benefit line
  ///
  /// In ar, this message translates to:
  /// **'استلم الطلبات وجهّزها بسرعة'**
  String get welcomePointOrders;

  /// Benefit line
  ///
  /// In ar, this message translates to:
  /// **'حدّث الأسعار والكميات في ثوانٍ'**
  String get welcomePointStock;

  /// Benefit line
  ///
  /// In ar, this message translates to:
  /// **'استقبل أعمال التركيب وتابع أرباحك'**
  String get welcomePointJobs;

  /// Screen title
  ///
  /// In ar, this message translates to:
  /// **'تسجيل دخول الشركاء'**
  String get signInTitle;

  /// Subtitle
  ///
  /// In ar, this message translates to:
  /// **'للمحلات والفنيين على شارع الغالي'**
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

  /// Button
  ///
  /// In ar, this message translates to:
  /// **'دخول'**
  String get signInSubmit;

  /// Link
  ///
  /// In ar, this message translates to:
  /// **'نسيت كلمة المرور؟'**
  String get signInForgot;

  /// Snackbar
  ///
  /// In ar, this message translates to:
  /// **'سنرسل رابط إعادة التعيين إلى بريدك عند تفعيل خدمة البريد.'**
  String get signInForgotSent;

  /// Demo hint
  ///
  /// In ar, this message translates to:
  /// **'في النسخة التجريبية يعمل أي بريد صحيح مع كلمة مرور من 8 أحرف فيها أرقام.'**
  String get signInDemoHint;

  /// Link for new partners
  ///
  /// In ar, this message translates to:
  /// **'محل أو فني جديد؟ قدّم طلب انضمام'**
  String get signInApply;

  /// Applying is not in the app yet
  ///
  /// In ar, this message translates to:
  /// **'يُفتح التقديم من التطبيق قريبًا. تواصل مع فريق المنصة حاليًا.'**
  String get applySoon;

  /// Role chooser title
  ///
  /// In ar, this message translates to:
  /// **'كيف تريد المتابعة؟'**
  String get roleTitle;

  /// Role chooser explanation
  ///
  /// In ar, this message translates to:
  /// **'حسابك مرتبط بمحل وبملف فني تركيب.'**
  String get roleBody;

  /// Role
  ///
  /// In ar, this message translates to:
  /// **'صاحب محل'**
  String get roleShop;

  /// Role
  ///
  /// In ar, this message translates to:
  /// **'فني تركيب'**
  String get roleTechnician;

  /// Menu row
  ///
  /// In ar, this message translates to:
  /// **'تبديل الدور'**
  String get roleSwitch;

  /// Tab
  ///
  /// In ar, this message translates to:
  /// **'الرئيسية'**
  String get shopNavHome;

  /// Tab
  ///
  /// In ar, this message translates to:
  /// **'الطلبات'**
  String get shopNavOrders;

  /// Tab
  ///
  /// In ar, this message translates to:
  /// **'المخزون'**
  String get shopNavStock;

  /// Tab: price requests from buyer photos
  ///
  /// In ar, this message translates to:
  /// **'التسعير'**
  String get shopNavQuotes;

  /// Tab
  ///
  /// In ar, this message translates to:
  /// **'المزيد'**
  String get shopNavMore;

  /// Greeting
  ///
  /// In ar, this message translates to:
  /// **'أهلًا، {name}'**
  String hello(String name);

  /// Open toggle on
  ///
  /// In ar, this message translates to:
  /// **'المحل مفتوح لاستقبال الطلبات'**
  String get shopIsOpen;

  /// Open toggle off
  ///
  /// In ar, this message translates to:
  /// **'المحل مغلق — لن تظهر قطعك للمشترين'**
  String get shopIsClosed;

  /// Stat tile
  ///
  /// In ar, this message translates to:
  /// **'طلبات جديدة'**
  String get kpiNewOrders;

  /// Stat tile
  ///
  /// In ar, this message translates to:
  /// **'للتجهيز'**
  String get kpiToPrepare;

  /// Stat tile
  ///
  /// In ar, this message translates to:
  /// **'نقد للتحصيل'**
  String get kpiCashToCollect;

  /// Stat tile
  ///
  /// In ar, this message translates to:
  /// **'مبيعات اليوم'**
  String get kpiTodaySales;

  /// Section title
  ///
  /// In ar, this message translates to:
  /// **'يحتاج إجراء'**
  String get needsAction;

  /// Acknowledge deadline
  ///
  /// In ar, this message translates to:
  /// **'أكّد خلال {minutes} دقيقة'**
  String ackWithin(int minutes);

  /// Acknowledge deadline passed
  ///
  /// In ar, this message translates to:
  /// **'تأخر التأكيد — تم تنبيه الإدارة'**
  String get ackLate;

  /// Quick action
  ///
  /// In ar, this message translates to:
  /// **'إضافة قطعة'**
  String get quickAddPart;

  /// Quick action
  ///
  /// In ar, this message translates to:
  /// **'تحديث الأسعار'**
  String get quickUpdatePrices;

  /// Quick action
  ///
  /// In ar, this message translates to:
  /// **'طلبات التسعير'**
  String get quickQuotes;

  /// Section title
  ///
  /// In ar, this message translates to:
  /// **'مخزون منخفض'**
  String get lowStock;

  /// Low stock count
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{قطعة واحدة تحتاج إعادة تعبئة} =2{قطعتان تحتاجان إعادة تعبئة} few{{count} قطع تحتاج إعادة تعبئة} other{{count} قطعة تحتاج إعادة تعبئة}}'**
  String lowStockBody(int count);

  /// Empty needs-action
  ///
  /// In ar, this message translates to:
  /// **'لا شيء بانتظارك الآن'**
  String get allCaughtUp;

  /// Orders tab
  ///
  /// In ar, this message translates to:
  /// **'جديدة'**
  String get tabNew;

  /// Orders tab
  ///
  /// In ar, this message translates to:
  /// **'قيد التجهيز'**
  String get tabPreparing;

  /// Orders tab
  ///
  /// In ar, this message translates to:
  /// **'جاهزة'**
  String get tabReady;

  /// Orders tab
  ///
  /// In ar, this message translates to:
  /// **'منتهية'**
  String get tabDone;

  /// Empty state
  ///
  /// In ar, this message translates to:
  /// **'لا توجد طلبات هنا'**
  String get ordersEmpty;

  /// Order title
  ///
  /// In ar, this message translates to:
  /// **'طلب {ref}'**
  String orderRef(String ref);

  /// Buyer line
  ///
  /// In ar, this message translates to:
  /// **'من {buyer}'**
  String orderFrom(String buyer);

  /// Banner
  ///
  /// In ar, this message translates to:
  /// **'بانتظار دفع المشتري — لا تجهّز بعد'**
  String get orderAwaitingPayment;

  /// Fulfilment line
  ///
  /// In ar, this message translates to:
  /// **'للفني {name} · {time}'**
  String toTechWith(String name, String time);

  /// Button
  ///
  /// In ar, this message translates to:
  /// **'قبول الطلب'**
  String get orderAccept;

  /// Button
  ///
  /// In ar, this message translates to:
  /// **'رفض'**
  String get orderReject;

  /// Dialog title
  ///
  /// In ar, this message translates to:
  /// **'لماذا ترفض الطلب؟'**
  String get rejectTitle;

  /// Reason
  ///
  /// In ar, this message translates to:
  /// **'القطعة غير متوفرة'**
  String get rejectOutOfStock;

  /// Reason
  ///
  /// In ar, this message translates to:
  /// **'السعر تغيّر'**
  String get rejectPrice;

  /// Reason
  ///
  /// In ar, this message translates to:
  /// **'سبب آخر'**
  String get rejectOther;

  /// Warning
  ///
  /// In ar, this message translates to:
  /// **'سيُعاد المبلغ للمشتري، وتؤثر حالات الرفض على تقييم المحل.'**
  String get rejectNote;

  /// Button
  ///
  /// In ar, this message translates to:
  /// **'القطعة جاهزة'**
  String get markReady;

  /// Button
  ///
  /// In ar, this message translates to:
  /// **'سلّمتها للمشتري'**
  String get handToBuyer;

  /// Button
  ///
  /// In ar, this message translates to:
  /// **'سلّمتها للفني'**
  String get handToTech;

  /// Button
  ///
  /// In ar, this message translates to:
  /// **'خرجت للتوصيل'**
  String get outForDelivery;

  /// Button
  ///
  /// In ar, this message translates to:
  /// **'تم التوصيل'**
  String get markDelivered;

  /// Cash instruction
  ///
  /// In ar, this message translates to:
  /// **'حصّل {amount} نقدًا عند التسليم'**
  String collectCash(String amount);

  /// Cash instruction (D-011)
  ///
  /// In ar, this message translates to:
  /// **'يسلّمك الفني {amount} نقدًا ثمن القطعة'**
  String cashFromTech(String amount);

  /// Payment line
  ///
  /// In ar, this message translates to:
  /// **'مدفوع عبر بنكك — تصلك قيمته في الدفعة القادمة'**
  String get paidBankak;

  /// Section
  ///
  /// In ar, this message translates to:
  /// **'المشتري'**
  String get sectionBuyer;

  /// Section
  ///
  /// In ar, this message translates to:
  /// **'القطع'**
  String get sectionItems;

  /// Section
  ///
  /// In ar, this message translates to:
  /// **'التسليم'**
  String get sectionHandover;

  /// Section
  ///
  /// In ar, this message translates to:
  /// **'المبلغ'**
  String get sectionMoney;

  /// Cost line
  ///
  /// In ar, this message translates to:
  /// **'عمولة المنصة ({percent}%)'**
  String commission(int percent);

  /// Cost line
  ///
  /// In ar, this message translates to:
  /// **'صافي لك'**
  String get youReceive;

  /// Order age
  ///
  /// In ar, this message translates to:
  /// **'استُلم {ago}'**
  String receivedAgo(String ago);

  /// Search hint
  ///
  /// In ar, this message translates to:
  /// **'ابحث في قطعك'**
  String get stockSearch;

  /// Filter
  ///
  /// In ar, this message translates to:
  /// **'الكل'**
  String get filterAll;

  /// Filter
  ///
  /// In ar, this message translates to:
  /// **'منخفض'**
  String get filterLow;

  /// Filter
  ///
  /// In ar, this message translates to:
  /// **'نفد'**
  String get filterOut;

  /// Filter
  ///
  /// In ar, this message translates to:
  /// **'مخفي'**
  String get filterHidden;

  /// Quantity line
  ///
  /// In ar, this message translates to:
  /// **'الكمية: {count}'**
  String qty(int count);

  /// Pill
  ///
  /// In ar, this message translates to:
  /// **'مخفي عن المشترين'**
  String get hiddenFromBuyers;

  /// Sheet title
  ///
  /// In ar, this message translates to:
  /// **'تعديل السعر والكمية'**
  String get editListing;

  /// Field
  ///
  /// In ar, this message translates to:
  /// **'السعر (ج.س)'**
  String get priceField;

  /// Field
  ///
  /// In ar, this message translates to:
  /// **'الكمية'**
  String get qtyField;

  /// Switch
  ///
  /// In ar, this message translates to:
  /// **'ظاهر للمشترين'**
  String get visibleToBuyers;

  /// Snackbar
  ///
  /// In ar, this message translates to:
  /// **'تم الحفظ'**
  String get saved;

  /// Button
  ///
  /// In ar, this message translates to:
  /// **'تعديل جماعي'**
  String get bulkEdit;

  /// Selection count
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{قطعة محددة} =2{قطعتان محددتان} few{{count} قطع محددة} other{{count} قطعة محددة}}'**
  String selectedCount(int count);

  /// Bulk action label
  ///
  /// In ar, this message translates to:
  /// **'تغيير الأسعار بنسبة'**
  String get bulkPriceBy;

  /// Button
  ///
  /// In ar, this message translates to:
  /// **'تطبيق'**
  String get bulkApply;

  /// Snackbar
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{حُدّث سعر قطعة واحدة} =2{حُدّث سعر قطعتين} few{حُدّثت أسعار {count} قطع} other{حُدّثت أسعار {count} قطعة}}'**
  String bulkDone(int count);

  /// Button
  ///
  /// In ar, this message translates to:
  /// **'استيراد من Excel'**
  String get importExcel;

  /// Explanation
  ///
  /// In ar, this message translates to:
  /// **'نزّل القالب، املأه، ثم ارفعه لتحديث مئات القطع دفعة واحدة.'**
  String get importBody;

  /// Button
  ///
  /// In ar, this message translates to:
  /// **'تنزيل القالب'**
  String get downloadTemplate;

  /// Button
  ///
  /// In ar, this message translates to:
  /// **'رفع الملف'**
  String get uploadFile;

  /// Price lock note
  ///
  /// In ar, this message translates to:
  /// **'الطلبات المؤكدة تحتفظ بسعرها القديم.'**
  String get priceLockNote;

  /// Screen title
  ///
  /// In ar, this message translates to:
  /// **'إضافة قطعة'**
  String get addTitle;

  /// Step
  ///
  /// In ar, this message translates to:
  /// **'الصورة'**
  String get stepPhoto;

  /// Step
  ///
  /// In ar, this message translates to:
  /// **'القطعة'**
  String get stepPart;

  /// Step
  ///
  /// In ar, this message translates to:
  /// **'السيارات'**
  String get stepCars;

  /// Step
  ///
  /// In ar, this message translates to:
  /// **'السعر'**
  String get stepPrice;

  /// Step title
  ///
  /// In ar, this message translates to:
  /// **'صوّر القطعة'**
  String get photoTitle;

  /// Explanation
  ///
  /// In ar, this message translates to:
  /// **'صورة واضحة على خلفية فاتحة تزيد مبيعاتك. نصغّرها تلقائيًا لتوفير البيانات.'**
  String get photoBody;

  /// Button
  ///
  /// In ar, this message translates to:
  /// **'التقاط صورة'**
  String get takePhoto;

  /// State
  ///
  /// In ar, this message translates to:
  /// **'تمت إضافة الصورة'**
  String get photoAdded;

  /// Step title
  ///
  /// In ar, this message translates to:
  /// **'ما القطعة؟'**
  String get categoryTitle;

  /// Field
  ///
  /// In ar, this message translates to:
  /// **'اسم القطعة'**
  String get partName;

  /// Field hint
  ///
  /// In ar, this message translates to:
  /// **'مثال: لمبة هالوجين H4'**
  String get partNameHint;

  /// Step title
  ///
  /// In ar, this message translates to:
  /// **'لأي سيارات تناسب؟'**
  String get carsTitle;

  /// Option
  ///
  /// In ar, this message translates to:
  /// **'لست متأكدًا — سيُطلب من المشتري التأكد'**
  String get carsUnknown;

  /// Field
  ///
  /// In ar, this message translates to:
  /// **'الحالة'**
  String get conditionLabel;

  /// Field
  ///
  /// In ar, this message translates to:
  /// **'الضمان'**
  String get warrantyLabel;

  /// Button
  ///
  /// In ar, this message translates to:
  /// **'نشر القطعة'**
  String get publish;

  /// Button
  ///
  /// In ar, this message translates to:
  /// **'حفظ كمسودة'**
  String get saveDraft;

  /// Offline drafts note
  ///
  /// In ar, this message translates to:
  /// **'تُحفظ المسودات على هاتفك وتُرسل عند عودة الاتصال.'**
  String get draftOffline;

  /// Snackbar
  ///
  /// In ar, this message translates to:
  /// **'نُشرت القطعة'**
  String get published;

  /// Snackbar
  ///
  /// In ar, this message translates to:
  /// **'حُفظت المسودة'**
  String get draftSaved;

  /// Pill
  ///
  /// In ar, this message translates to:
  /// **'مسودة'**
  String get draft;

  /// Explanation
  ///
  /// In ar, this message translates to:
  /// **'مشترون أرسلوا صورًا لقطع يبحثون عنها. أرسل عرضك قبل انتهاء الطلب.'**
  String get quotesBody;

  /// Empty state
  ///
  /// In ar, this message translates to:
  /// **'لا توجد طلبات تسعير حاليًا'**
  String get quotesEmpty;

  /// Expiry
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{ينتهي خلال ساعة} =2{ينتهي خلال ساعتين} few{ينتهي خلال {count} ساعات} other{ينتهي خلال {count} ساعة}}'**
  String expiresIn(int count);

  /// Competition
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{لا عروض بعد — كن الأول} =1{عرض واحد من محل آخر} =2{عرضان من محلات أخرى} few{{count} عروض من محلات أخرى} other{{count} عرضًا من محلات أخرى}}'**
  String otherOffers(int count);

  /// Button
  ///
  /// In ar, this message translates to:
  /// **'أرسل عرضًا'**
  String get makeOffer;

  /// Snackbar
  ///
  /// In ar, this message translates to:
  /// **'تم إرسال عرضك'**
  String get offerSent;

  /// Sent offer
  ///
  /// In ar, this message translates to:
  /// **'عرضك: {amount}'**
  String yourOffer(String amount);

  /// Sheet title
  ///
  /// In ar, this message translates to:
  /// **'عرض سعر'**
  String get offerTitle;

  /// Field
  ///
  /// In ar, this message translates to:
  /// **'وصف القطعة'**
  String get offerPart;

  /// Field
  ///
  /// In ar, this message translates to:
  /// **'ملاحظة للمشتري (اختياري)'**
  String get offerNote;

  /// Menu row
  ///
  /// In ar, this message translates to:
  /// **'المال والدفعات'**
  String get moreMoney;

  /// Menu row
  ///
  /// In ar, this message translates to:
  /// **'الموظفون'**
  String get moreStaff;

  /// Menu row
  ///
  /// In ar, this message translates to:
  /// **'الأداء'**
  String get moreInsights;

  /// Menu row
  ///
  /// In ar, this message translates to:
  /// **'ملف المحل'**
  String get moreProfile;

  /// Menu row
  ///
  /// In ar, this message translates to:
  /// **'اللغة'**
  String get moreLanguage;

  /// Menu row
  ///
  /// In ar, this message translates to:
  /// **'المظهر'**
  String get moreAppearance;

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
  /// **'المساعدة'**
  String get moreHelp;

  /// Button
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الخروج'**
  String get signOut;

  /// Dialog
  ///
  /// In ar, this message translates to:
  /// **'هل تريد تسجيل الخروج؟'**
  String get signOutConfirm;

  /// Positive balance label
  ///
  /// In ar, this message translates to:
  /// **'المنصة مدينة لك بـ'**
  String get moneyOwedToYou;

  /// Negative balance label
  ///
  /// In ar, this message translates to:
  /// **'أنت مدين للمنصة بـ'**
  String get moneyYouOwe;

  /// Payout schedule
  ///
  /// In ar, this message translates to:
  /// **'الدفعة القادمة: {date} عبر بنكك'**
  String nextPayout(String date);

  /// Commission rule
  ///
  /// In ar, this message translates to:
  /// **'العمولة {percent}% على القطع فقط، وتُخصم من الدفعة.'**
  String commissionNote(int percent);

  /// Section
  ///
  /// In ar, this message translates to:
  /// **'كشف الحساب'**
  String get statement;

  /// Section
  ///
  /// In ar, this message translates to:
  /// **'الدفعات'**
  String get payouts;

  /// Ledger line
  ///
  /// In ar, this message translates to:
  /// **'بيع'**
  String get ledgerSale;

  /// Ledger line
  ///
  /// In ar, this message translates to:
  /// **'عمولة'**
  String get ledgerCommission;

  /// Ledger line
  ///
  /// In ar, this message translates to:
  /// **'أجرة تركيب'**
  String get ledgerLabour;

  /// Ledger line
  ///
  /// In ar, this message translates to:
  /// **'رسوم مشوار'**
  String get ledgerTravel;

  /// Ledger line
  ///
  /// In ar, this message translates to:
  /// **'رسوم حجز'**
  String get ledgerBookingFee;

  /// Ledger line
  ///
  /// In ar, this message translates to:
  /// **'نقد محصّل'**
  String get ledgerCash;

  /// Ledger line
  ///
  /// In ar, this message translates to:
  /// **'تسليم نقد'**
  String get ledgerHandover;

  /// Ledger line
  ///
  /// In ar, this message translates to:
  /// **'دفعة'**
  String get ledgerPayout;

  /// Ledger line
  ///
  /// In ar, this message translates to:
  /// **'استرداد'**
  String get ledgerRefund;

  /// Payout status
  ///
  /// In ar, this message translates to:
  /// **'مدفوعة'**
  String get payoutPaid;

  /// Payout status
  ///
  /// In ar, this message translates to:
  /// **'معتمدة'**
  String get payoutApproved;

  /// Payout status
  ///
  /// In ar, this message translates to:
  /// **'قيد الإعداد'**
  String get payoutDraft;

  /// Role
  ///
  /// In ar, this message translates to:
  /// **'المالك'**
  String get staffOwner;

  /// Role
  ///
  /// In ar, this message translates to:
  /// **'موظف'**
  String get staffMember;

  /// Button
  ///
  /// In ar, this message translates to:
  /// **'دعوة موظف'**
  String get staffInvite;

  /// Explanation
  ///
  /// In ar, this message translates to:
  /// **'يستطيع الموظفون إدارة الطلبات والمخزون فقط، دون الوصول إلى المال.'**
  String get staffInviteBody;

  /// Snackbar
  ///
  /// In ar, this message translates to:
  /// **'أُرسلت الدعوة'**
  String get staffInviteSent;

  /// Activity
  ///
  /// In ar, this message translates to:
  /// **'آخر نشاط {ago}'**
  String lastActive(String ago);

  /// Chart title
  ///
  /// In ar, this message translates to:
  /// **'المبيعات آخر 7 أيام'**
  String get insightsSales7;

  /// Stat tile
  ///
  /// In ar, this message translates to:
  /// **'الطلبات'**
  String get insightsOrders;

  /// Stat tile
  ///
  /// In ar, this message translates to:
  /// **'متوسط الطلب'**
  String get insightsAvgOrder;

  /// Stat tile
  ///
  /// In ar, this message translates to:
  /// **'التقييم'**
  String get insightsRating;

  /// Section
  ///
  /// In ar, this message translates to:
  /// **'الأكثر مبيعًا'**
  String get insightsTop;

  /// Chart toggle
  ///
  /// In ar, this message translates to:
  /// **'عرض كجدول'**
  String get showTable;

  /// Chart toggle
  ///
  /// In ar, this message translates to:
  /// **'عرض كرسم'**
  String get showChart;

  /// Table column
  ///
  /// In ar, this message translates to:
  /// **'اليوم'**
  String get colDay;

  /// Table column
  ///
  /// In ar, this message translates to:
  /// **'المبيعات'**
  String get colSales;

  /// Table column
  ///
  /// In ar, this message translates to:
  /// **'الطلبات'**
  String get colOrders;

  /// Units sold
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{بيعت مرة} =2{بيعت مرتين} few{بيعت {count} مرات} other{بيعت {count} مرة}}'**
  String soldCount(int count);

  /// Tab
  ///
  /// In ar, this message translates to:
  /// **'الأعمال'**
  String get techNavJobs;

  /// Tab
  ///
  /// In ar, this message translates to:
  /// **'الجدول'**
  String get techNavSchedule;

  /// Tab
  ///
  /// In ar, this message translates to:
  /// **'الأرباح'**
  String get techNavEarnings;

  /// Tab
  ///
  /// In ar, this message translates to:
  /// **'حسابي'**
  String get techNavProfile;

  /// Availability switch on
  ///
  /// In ar, this message translates to:
  /// **'متاح لاستقبال الأعمال'**
  String get techOnline;

  /// Availability switch off
  ///
  /// In ar, this message translates to:
  /// **'غير متاح — لن تصلك عروض جديدة'**
  String get techOffline;

  /// Section
  ///
  /// In ar, this message translates to:
  /// **'عروض جديدة'**
  String get newOffers;

  /// Section
  ///
  /// In ar, this message translates to:
  /// **'أعمال اليوم'**
  String get todayJobs;

  /// Section
  ///
  /// In ar, this message translates to:
  /// **'القادمة'**
  String get upcomingJobs;

  /// Empty state
  ///
  /// In ar, this message translates to:
  /// **'لا أعمال اليوم بعد'**
  String get noJobsToday;

  /// Empty state
  ///
  /// In ar, this message translates to:
  /// **'تأكد أنك متاح وأن جدولك محدّث لتصلك العروض.'**
  String get noJobsTodayBody;

  /// Offer countdown
  ///
  /// In ar, this message translates to:
  /// **'رد خلال {time}'**
  String respondIn(String time);

  /// Button
  ///
  /// In ar, this message translates to:
  /// **'قبول'**
  String get accept;

  /// Button
  ///
  /// In ar, this message translates to:
  /// **'اعتذار'**
  String get decline;

  /// Decline explanation
  ///
  /// In ar, this message translates to:
  /// **'سيُعرض العمل على فني آخر في نفس الموعد.'**
  String get declineBody;

  /// Snackbar
  ///
  /// In ar, this message translates to:
  /// **'قبلت العمل'**
  String get jobAccepted;

  /// State
  ///
  /// In ar, this message translates to:
  /// **'انتهت مهلة العرض'**
  String get offerExpired;

  /// Earnings line
  ///
  /// In ar, this message translates to:
  /// **'تكسب {amount}'**
  String youEarn(String amount);

  /// Job place
  ///
  /// In ar, this message translates to:
  /// **'في ورشتك'**
  String get atYourBay;

  /// Job place
  ///
  /// In ar, this message translates to:
  /// **'عند العميل · {distance}'**
  String atCustomer(String distance);

  /// Part status
  ///
  /// In ar, this message translates to:
  /// **'القطعة جاهزة في {shop}'**
  String partReadyAt(String shop);

  /// Part status
  ///
  /// In ar, this message translates to:
  /// **'القطعة قيد التجهيز في {shop}'**
  String partPendingAt(String shop);

  /// Part status
  ///
  /// In ar, this message translates to:
  /// **'القطعة مع العميل'**
  String get partWithCustomer;

  /// Screen title
  ///
  /// In ar, this message translates to:
  /// **'تفاصيل العمل'**
  String get jobTitle;

  /// Section
  ///
  /// In ar, this message translates to:
  /// **'العميل'**
  String get jobCustomer;

  /// Section
  ///
  /// In ar, this message translates to:
  /// **'السيارة'**
  String get jobCar;

  /// Section
  ///
  /// In ar, this message translates to:
  /// **'العمل'**
  String get jobWork;

  /// Section
  ///
  /// In ar, this message translates to:
  /// **'المكان'**
  String get jobWhere;

  /// Section
  ///
  /// In ar, this message translates to:
  /// **'الأجر'**
  String get jobPay;

  /// Button
  ///
  /// In ar, this message translates to:
  /// **'أنا في الطريق'**
  String get onMyWay;

  /// Button
  ///
  /// In ar, this message translates to:
  /// **'وصلت — ابدأ العمل'**
  String get checkIn;

  /// Section
  ///
  /// In ar, this message translates to:
  /// **'صور قبل العمل'**
  String get photosBefore;

  /// Section
  ///
  /// In ar, this message translates to:
  /// **'صور بعد العمل'**
  String get photosAfter;

  /// Button
  ///
  /// In ar, this message translates to:
  /// **'إضافة صورة'**
  String get addPhoto;

  /// Section
  ///
  /// In ar, this message translates to:
  /// **'أدخل رمز العميل لإنهاء العمل'**
  String get enterCode;

  /// Field help
  ///
  /// In ar, this message translates to:
  /// **'اطلب من العميل الرمز المكوّن من 4 أرقام بعد رضاه عن العمل.'**
  String get codeHint;

  /// Wrong job code (D-028)
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{الرمز غير صحيح. أُوقف الإنهاء وتم تنبيه الإدارة.} =1{الرمز غير صحيح. محاولة واحدة متبقية.} =2{الرمز غير صحيح. محاولتان متبقيتان.} few{الرمز غير صحيح. {count} محاولات متبقية.} other{الرمز غير صحيح. {count} محاولة متبقية.}}'**
  String codeWrong(int count);

  /// Button
  ///
  /// In ar, this message translates to:
  /// **'إنهاء العمل'**
  String get finishJob;

  /// Snackbar / banner
  ///
  /// In ar, this message translates to:
  /// **'اكتمل العمل — أُضيف الأجر إلى أرباحك'**
  String get jobDone;

  /// Button
  ///
  /// In ar, this message translates to:
  /// **'القطعة لا تناسب'**
  String get partNotFit;

  /// Explanation
  ///
  /// In ar, this message translates to:
  /// **'يدفع العميل رسوم المشوار فقط، ويُفتح طلب إرجاع للقطعة.'**
  String get partNotFitBody;

  /// Cash instruction
  ///
  /// In ar, this message translates to:
  /// **'حصّل {amount} نقدًا من العميل'**
  String collectFromCustomer(String amount);

  /// Cash instruction (D-011)
  ///
  /// In ar, this message translates to:
  /// **'سلّم {amount} للمحل ثمن القطعة'**
  String handCashToShop(String amount);

  /// Instruction
  ///
  /// In ar, this message translates to:
  /// **'استلم القطعة من {shop} قبل الموعد'**
  String pickUpPart(String shop);

  /// Validation
  ///
  /// In ar, this message translates to:
  /// **'أضف صورة واحدة على الأقل بعد العمل.'**
  String get needAfterPhoto;

  /// Section
  ///
  /// In ar, this message translates to:
  /// **'ساعات العمل الأسبوعية'**
  String get weeklyHours;

  /// Day state
  ///
  /// In ar, this message translates to:
  /// **'إجازة'**
  String get dayOff;

  /// Section
  ///
  /// In ar, this message translates to:
  /// **'إيقاف سريع'**
  String get quickBlock;

  /// Explanation
  ///
  /// In ar, this message translates to:
  /// **'طارئ؟ أوقف استقبال الأعمال مؤقتًا دون تعديل جدولك.'**
  String get quickBlockBody;

  /// Option
  ///
  /// In ar, this message translates to:
  /// **'ساعة'**
  String get block1h;

  /// Option
  ///
  /// In ar, this message translates to:
  /// **'ساعتان'**
  String get block2h;

  /// Option
  ///
  /// In ar, this message translates to:
  /// **'بقية اليوم'**
  String get blockDay;

  /// State
  ///
  /// In ar, this message translates to:
  /// **'لن تصلك أعمال حتى {time}'**
  String blockedUntil(String time);

  /// Button
  ///
  /// In ar, this message translates to:
  /// **'إلغاء الإيقاف'**
  String get unblock;

  /// Section
  ///
  /// In ar, this message translates to:
  /// **'الإجازات'**
  String get timeOff;

  /// Button
  ///
  /// In ar, this message translates to:
  /// **'إضافة إجازة'**
  String get addTimeOff;

  /// Empty state
  ///
  /// In ar, this message translates to:
  /// **'لا توجد إجازات قادمة'**
  String get noTimeOff;

  /// Snackbar (demo adds a full day tomorrow)
  ///
  /// In ar, this message translates to:
  /// **'أُضيفت إجازة غدًا طوال اليوم'**
  String get timeOffAdded;

  /// Hero label
  ///
  /// In ar, this message translates to:
  /// **'أرباح هذا الأسبوع'**
  String get earningsWeek;

  /// Job count
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{لا أعمال} =1{عمل واحد} =2{عملان} few{{count} أعمال} other{{count} عملًا}}'**
  String jobsCount(int count);

  /// Stat tile
  ///
  /// In ar, this message translates to:
  /// **'نقد معك'**
  String get cashWithYou;

  /// Explanation
  ///
  /// In ar, this message translates to:
  /// **'حصّلته من العملاء ويُخصم من دفعتك.'**
  String get cashWithYouBody;

  /// Section
  ///
  /// In ar, this message translates to:
  /// **'آخر العمليات'**
  String get recentActivity;

  /// Section
  ///
  /// In ar, this message translates to:
  /// **'الأعمال وأسعارك'**
  String get skillsAndPrices;

  /// Section
  ///
  /// In ar, this message translates to:
  /// **'طريقة العمل'**
  String get howYouWork;

  /// Slider label
  ///
  /// In ar, this message translates to:
  /// **'أقصى مسافة للزيارات: {km} كم'**
  String maxDistance(int km);

  /// Bay line
  ///
  /// In ar, this message translates to:
  /// **'ورشتك: {shop}'**
  String yourBay(String shop);

  /// Price field
  ///
  /// In ar, this message translates to:
  /// **'أجرة {job}'**
  String labourFor(String job);

  /// Card title (demo only)
  ///
  /// In ar, this message translates to:
  /// **'أدوات العرض التجريبي'**
  String get demoControls;

  /// Demo button
  ///
  /// In ar, this message translates to:
  /// **'محاكاة طلب جديد'**
  String get demoNewOrder;

  /// Demo button
  ///
  /// In ar, this message translates to:
  /// **'محاكاة عرض عمل جديد'**
  String get demoNewOffer;

  /// Demo button
  ///
  /// In ar, this message translates to:
  /// **'محاكاة طلب تسعير جديد'**
  String get demoNewQuote;
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
