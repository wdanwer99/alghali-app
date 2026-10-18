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
  /// **'إذا كان لهذا البريد حساب، سيصلك رابط لتغيير كلمة المرور.'**
  String get signInForgotSent;

  /// Link for new partners
  ///
  /// In ar, this message translates to:
  /// **'محل أو فني جديد؟ أنشئ حساباً'**
  String get signInApply;

  /// Role chooser title
  ///
  /// In ar, this message translates to:
  /// **'كيف تريد المتابعة؟'**
  String get roleTitle;

  /// Role chooser explanation
  ///
  /// In ar, this message translates to:
  /// **'اختر ما تريد فتحه من أعمالك. يمكنك التبديل في أي وقت من القائمة.'**
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
  /// **'أضيفت الإجازة'**
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

  /// Button in the forgot-password sheet
  ///
  /// In ar, this message translates to:
  /// **'أرسل الرابط'**
  String get forgotSend;

  /// Sign-up screen title
  ///
  /// In ar, this message translates to:
  /// **'حساب شريك جديد'**
  String get signUpTitle;

  /// Sign-up intro
  ///
  /// In ar, this message translates to:
  /// **'لأصحاب المحلات وموظفيهم وفنيي التركيب. بعدها تختار كيف تعمل معنا.'**
  String get signUpBody;

  /// Field label
  ///
  /// In ar, this message translates to:
  /// **'الاسم الكامل'**
  String get fieldName;

  /// Field label
  ///
  /// In ar, this message translates to:
  /// **'رقم الجوال'**
  String get fieldPhone;

  /// Field label
  ///
  /// In ar, this message translates to:
  /// **'رقم واتساب (اختياري)'**
  String get fieldWhatsapp;

  /// Button
  ///
  /// In ar, this message translates to:
  /// **'إنشاء الحساب'**
  String get signUpSubmit;

  /// Link
  ///
  /// In ar, this message translates to:
  /// **'لديك حساب؟ سجّل الدخول'**
  String get signUpHaveAccount;

  /// Role card subtitle for staff
  ///
  /// In ar, this message translates to:
  /// **'موظف في المحل'**
  String get roleShopStaff;

  /// Button on the role screen
  ///
  /// In ar, this message translates to:
  /// **'أضف محلاً'**
  String get applyAddShop;

  /// Button on the role screen
  ///
  /// In ar, this message translates to:
  /// **'قدّم كفني تركيب'**
  String get applyAsTechnician;

  /// Shop or technician review state
  ///
  /// In ar, this message translates to:
  /// **'قيد المراجعة'**
  String get statusPending;

  /// Review state
  ///
  /// In ar, this message translates to:
  /// **'معتمد'**
  String get statusApproved;

  /// Review state
  ///
  /// In ar, this message translates to:
  /// **'مرفوض'**
  String get statusRejected;

  /// Review state
  ///
  /// In ar, this message translates to:
  /// **'موقوف'**
  String get statusSuspended;

  /// Banner
  ///
  /// In ar, this message translates to:
  /// **'لم يُعتمد طلبك. تواصل مع فريق المنصة لمعرفة المطلوب.'**
  String get statusRejectedBody;

  /// Banner
  ///
  /// In ar, this message translates to:
  /// **'الحساب موقوف مؤقتاً، ولا يظهر للمشترين. تواصل مع فريق المنصة.'**
  String get statusSuspendedBody;

  /// The admin reason under a review banner
  ///
  /// In ar, this message translates to:
  /// **'السبب: {reason}'**
  String statusReason(String reason);

  /// Banner on the shop home while pending
  ///
  /// In ar, this message translates to:
  /// **'طلب المحل قيد المراجعة. جهّز قطعك وأسعارك الآن، وستظهر للمشترين بعد الاعتماد.'**
  String get shopPendingBody;

  /// Banner on the jobs screen while pending
  ///
  /// In ar, this message translates to:
  /// **'طلبك قيد المراجعة. ستصلك عروض العمل بعد الاعتماد؛ أكمل ساعات عملك وأسعارك الآن.'**
  String get techPendingBody;

  /// Apply screen title
  ///
  /// In ar, this message translates to:
  /// **'انضم إلى شارع الغالي'**
  String get applyTitle;

  /// Apply screen greeting
  ///
  /// In ar, this message translates to:
  /// **'أهلاً {name}'**
  String applyHello(String name);

  /// Apply intro
  ///
  /// In ar, this message translates to:
  /// **'كيف ستعمل معنا؟ يراجع فريق المنصة طلبك عادة خلال يوم عمل.'**
  String get applyBody;

  /// Choice title / screen title
  ///
  /// In ar, this message translates to:
  /// **'عندي محل في الشارع'**
  String get applyShopTitle;

  /// Choice body
  ///
  /// In ar, this message translates to:
  /// **'اعرض قطعك، واستقبل الطلبات وطلبات الأسعار.'**
  String get applyShopBody;

  /// Choice title / screen title
  ///
  /// In ar, this message translates to:
  /// **'أنا فني تركيب'**
  String get applyTechTitle;

  /// Choice body
  ///
  /// In ar, this message translates to:
  /// **'استقبل أعمال التركيب في ورشة على الشارع أو عند الزبون.'**
  String get applyTechBody;

  /// Note for staff
  ///
  /// In ar, this message translates to:
  /// **'تعمل في محل مسجّل؟ لا تقدّم طلباً — اطلب من صاحب المحل إضافتك ببريدك هذا.'**
  String get applyStaffNote;

  /// Banner at the top of the shop form
  ///
  /// In ar, this message translates to:
  /// **'اسم المحل ومكانه في الشارع يظهران للمشترين بعد الاعتماد.'**
  String get applyShopNote;

  /// Form section
  ///
  /// In ar, this message translates to:
  /// **'المحل'**
  String get applySectionShop;

  /// Form section
  ///
  /// In ar, this message translates to:
  /// **'المكان في الشارع'**
  String get applySectionPlace;

  /// Form section
  ///
  /// In ar, this message translates to:
  /// **'التواصل'**
  String get applySectionContact;

  /// Button
  ///
  /// In ar, this message translates to:
  /// **'أرسل الطلب'**
  String get applySubmit;

  /// Snack bar
  ///
  /// In ar, this message translates to:
  /// **'أرسلنا طلبك للمراجعة'**
  String get applySent;

  /// Field label
  ///
  /// In ar, this message translates to:
  /// **'اسم المحل بالعربية'**
  String get shopNameAr;

  /// Field label
  ///
  /// In ar, this message translates to:
  /// **'اسم المحل بالإنجليزية (اختياري)'**
  String get shopNameEn;

  /// Field label
  ///
  /// In ar, this message translates to:
  /// **'المنطقة'**
  String get shopZone;

  /// Field label
  ///
  /// In ar, this message translates to:
  /// **'رقم القطعة'**
  String get shopPlot;

  /// Street side
  ///
  /// In ar, this message translates to:
  /// **'الجهة أ'**
  String get shopSideA;

  /// Street side
  ///
  /// In ar, this message translates to:
  /// **'الجهة ب'**
  String get shopSideB;

  /// Field label
  ///
  /// In ar, this message translates to:
  /// **'علامة مميزة'**
  String get shopLandmark;

  /// Field hint
  ///
  /// In ar, this message translates to:
  /// **'مثلاً: مقابل محطة الوقود'**
  String get shopLandmarkHint;

  /// Field label
  ///
  /// In ar, this message translates to:
  /// **'عن المحل (اختياري)'**
  String get shopAbout;

  /// Form section
  ///
  /// In ar, this message translates to:
  /// **'ساعات العمل'**
  String get shopHours;

  /// Form section
  ///
  /// In ar, this message translates to:
  /// **'ماذا تبيع؟'**
  String get shopSells;

  /// Form section
  ///
  /// In ar, this message translates to:
  /// **'السيارات التي تخدمها'**
  String get shopMakes;

  /// Hint
  ///
  /// In ar, this message translates to:
  /// **'اتركها فارغة إذا كنت تخدم كل الأنواع.'**
  String get shopMakesBody;

  /// Banner at the top of the technician form
  ///
  /// In ar, this message translates to:
  /// **'يراجع الفريق خبرتك قبل وصول أول عرض عمل.'**
  String get applyTechNote;

  /// Field label
  ///
  /// In ar, this message translates to:
  /// **'الورشة التي تعمل فيها'**
  String get techApplyBay;

  /// Field helper
  ///
  /// In ar, this message translates to:
  /// **'محل أو ورشة على الشارع يركّب فيه الزبائن'**
  String get techApplyBayHelp;

  /// Button
  ///
  /// In ar, this message translates to:
  /// **'حدّد موقعي الحالي كنقطة الانطلاق'**
  String get techApplyHome;

  /// Button after setting / snack bar
  ///
  /// In ar, this message translates to:
  /// **'حُدّد موقعك'**
  String get techApplyHomeSet;

  /// Hint
  ///
  /// In ar, this message translates to:
  /// **'تُحسب مسافة الزيارات من هنا، ولا يراها الزبائن.'**
  String get techApplyHomeBody;

  /// Hint
  ///
  /// In ar, this message translates to:
  /// **'اكتب سعر المصنعية لكل نوع عمل تقوم به، واترك الباقي فارغاً.'**
  String get techApplyJobsBody;

  /// Form section
  ///
  /// In ar, this message translates to:
  /// **'السيارات التي تعمل عليها'**
  String get techApplyMakes;

  /// Hint
  ///
  /// In ar, this message translates to:
  /// **'اتركها فارغة إذا كنت تعمل على كل الأنواع.'**
  String get techApplyMakesBody;

  /// Field label
  ///
  /// In ar, this message translates to:
  /// **'سنوات الخبرة'**
  String get techApplyYears;

  /// Field label
  ///
  /// In ar, this message translates to:
  /// **'نبذة عنك (اختياري)'**
  String get techApplyBio;

  /// Validation
  ///
  /// In ar, this message translates to:
  /// **'اختر نوع عمل واحداً على الأقل مع سعره.'**
  String get techApplyNeedJob;

  /// Validation
  ///
  /// In ar, this message translates to:
  /// **'اختر الورشة التي تعمل فيها.'**
  String get techApplyNeedBay;

  /// Validation
  ///
  /// In ar, this message translates to:
  /// **'حدّد موقع انطلاقك للزيارات.'**
  String get techApplyNeedHome;

  /// Button
  ///
  /// In ar, this message translates to:
  /// **'حدّث موقع الانطلاق'**
  String get homeUpdate;

  /// Button / sheet title
  ///
  /// In ar, this message translates to:
  /// **'أضف نوع عمل'**
  String get addJobType;

  /// Chats screen title
  ///
  /// In ar, this message translates to:
  /// **'الرسائل'**
  String get chatsTitle;

  /// Inbox screen title
  ///
  /// In ar, this message translates to:
  /// **'التنبيهات'**
  String get notificationsTitle;

  /// Header switch when closed for the day
  ///
  /// In ar, this message translates to:
  /// **'المحل مغلق اليوم — يظهر مغلقاً للمشترين'**
  String get shopClosedToday;

  /// Header switch outside hours
  ///
  /// In ar, this message translates to:
  /// **'خارج ساعات العمل الآن'**
  String get shopOutsideHours;

  /// Snack bar
  ///
  /// In ar, this message translates to:
  /// **'قُبل الطلب'**
  String get orderAccepted;

  /// Snack bar
  ///
  /// In ar, this message translates to:
  /// **'اعتذرت عن الطلب، وسيُعاد المبلغ للمشتري'**
  String get orderRejected;

  /// Snack bar
  ///
  /// In ar, this message translates to:
  /// **'القطعة جاهزة'**
  String get orderMarkedReady;

  /// Snack bar
  ///
  /// In ar, this message translates to:
  /// **'تم التسليم'**
  String get orderHandedOver;

  /// Snack bar
  ///
  /// In ar, this message translates to:
  /// **'تم التوصيل'**
  String get orderDelivered;

  /// Empty state
  ///
  /// In ar, this message translates to:
  /// **'لم نجد هذا الطلب في محلك'**
  String get orderNotHere;

  /// Banner
  ///
  /// In ar, this message translates to:
  /// **'طلب المشتري الإرجاع: {reason}'**
  String returnRequested(String reason);

  /// Banner
  ///
  /// In ar, this message translates to:
  /// **'سلّم القطعة بعد أن يقبل الفني العمل.'**
  String get waitTechAccept;

  /// Button
  ///
  /// In ar, this message translates to:
  /// **'اتصل بالفني'**
  String get callTechnician;

  /// Banner
  ///
  /// In ar, this message translates to:
  /// **'استلمت المبلغ نقداً'**
  String get cashCollected;

  /// Field label
  ///
  /// In ar, this message translates to:
  /// **'اكتب السبب للمشتري'**
  String get rejectOtherLabel;

  /// Tooltip
  ///
  /// In ar, this message translates to:
  /// **'افتح الطلب'**
  String get openOrder;

  /// Empty state
  ///
  /// In ar, this message translates to:
  /// **'لا توجد رسائل بعد'**
  String get chatsEmpty;

  /// Empty state body
  ///
  /// In ar, this message translates to:
  /// **'عندما يراسلك مشترٍ ستظهر محادثته هنا.'**
  String get chatsEmptyBody;

  /// Empty chat
  ///
  /// In ar, this message translates to:
  /// **'ابدأ المحادثة'**
  String get chatEmpty;

  /// Chat field hint
  ///
  /// In ar, this message translates to:
  /// **'اكتب رسالة'**
  String get chatHint;

  /// Tooltip
  ///
  /// In ar, this message translates to:
  /// **'إرسال'**
  String get chatSend;

  /// Chat preview
  ///
  /// In ar, this message translates to:
  /// **'رسالة صوتية'**
  String get chatVoiceNote;

  /// Empty state
  ///
  /// In ar, this message translates to:
  /// **'لا توجد تنبيهات'**
  String get notificationsEmpty;

  /// Empty state body
  ///
  /// In ar, this message translates to:
  /// **'ستصلك هنا الطلبات الجديدة وعروض العمل والرسائل.'**
  String get notificationsEmptyBody;

  /// Title when no template exists
  ///
  /// In ar, this message translates to:
  /// **'تنبيه'**
  String get notificationsGeneric;

  /// Button
  ///
  /// In ar, this message translates to:
  /// **'تعليم الكل كمقروء'**
  String get notificationsMarkRead;

  /// Help sheet
  ///
  /// In ar, this message translates to:
  /// **'فريق المنصة يساعدك في الطلبات والمدفوعات والحساب.'**
  String get helpBody;

  /// Empty state
  ///
  /// In ar, this message translates to:
  /// **'لا توجد قطع بعد'**
  String get stockEmpty;

  /// Empty state body
  ///
  /// In ar, this message translates to:
  /// **'أضف قطعة بالصورة، أو استورد ملف Excel.'**
  String get stockEmptyBody;

  /// Empty state
  ///
  /// In ar, this message translates to:
  /// **'لا توجد قطع تطابق البحث'**
  String get stockNoMatch;

  /// Pill: units held by open orders
  ///
  /// In ar, this message translates to:
  /// **'محجوز {count}'**
  String reservedQty(int count);

  /// Hint in the edit sheet
  ///
  /// In ar, this message translates to:
  /// **'{count} محجوزة لطلبات مفتوحة'**
  String reservedNote(int count);

  /// Stock row
  ///
  /// In ar, this message translates to:
  /// **'السعر عند الطلب'**
  String get priceOnRequest;

  /// Button
  ///
  /// In ar, this message translates to:
  /// **'احذف من المحل'**
  String get archive;

  /// Dialog title
  ///
  /// In ar, this message translates to:
  /// **'حذف القطعة؟'**
  String get archiveTitle;

  /// Dialog body
  ///
  /// In ar, this message translates to:
  /// **'لن تظهر للمشترين بعد الآن. الطلبات المؤكدة لا تتأثر.'**
  String get archiveBody;

  /// Edit sheet banner
  ///
  /// In ar, this message translates to:
  /// **'هذه القطعة بانتظار الاتصال لإرسالها. عدّلها بعد ظهورها في القائمة.'**
  String get listingQueued;

  /// Snack bar
  ///
  /// In ar, this message translates to:
  /// **'حُفظت القطعة وستُرسل عند عودة الاتصال'**
  String get listingSavedOffline;

  /// Button
  ///
  /// In ar, this message translates to:
  /// **'صورة أخرى'**
  String get retakePhoto;

  /// Checkbox
  ///
  /// In ar, this message translates to:
  /// **'بدون صورة الآن'**
  String get noPhoto;

  /// Chosen suggestion subtitle
  ///
  /// In ar, this message translates to:
  /// **'من دليل القطع'**
  String get fromCatalogue;

  /// Suggestions heading
  ///
  /// In ar, this message translates to:
  /// **'هل تقصد؟'**
  String get suggestionsTitle;

  /// Banner
  ///
  /// In ar, this message translates to:
  /// **'السيارات المناسبة لهذه القطعة محددة في الدليل.'**
  String get carsFromCatalogue;

  /// Sheet title
  ///
  /// In ar, this message translates to:
  /// **'فحص الملف'**
  String get importCheckTitle;

  /// Dry-run summary
  ///
  /// In ar, this message translates to:
  /// **'سيُضاف {created} ويُحدَّث {updated}، وفيه {failed} صفوف بها مشاكل.'**
  String importCheckBody(int created, int updated, int failed);

  /// Problem row
  ///
  /// In ar, this message translates to:
  /// **'الصف {row}'**
  String importRow(int row);

  /// Button
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{استورد صفاً واحداً} =2{استورد صفين} few{استورد {count} صفوف} other{استورد {count} صفاً}}'**
  String importGo(int count);

  /// Snack bar
  ///
  /// In ar, this message translates to:
  /// **'أضيفت {created} وحُدّثت {updated}، وتُركت {failed}'**
  String importDone(int created, int updated, int failed);

  /// Row problem
  ///
  /// In ar, this message translates to:
  /// **'اسم القطعة ناقص'**
  String get importErrName;

  /// Row problem
  ///
  /// In ar, this message translates to:
  /// **'الفئة ناقصة أو غير معروفة'**
  String get importErrCategory;

  /// Row problem
  ///
  /// In ar, this message translates to:
  /// **'الحالة ناقصة أو غير صحيحة'**
  String get importErrCondition;

  /// Row problem
  ///
  /// In ar, this message translates to:
  /// **'السعر ناقص أو غير صحيح'**
  String get importErrPrice;

  /// Row problem
  ///
  /// In ar, this message translates to:
  /// **'الكمية غير صحيحة'**
  String get importErrQty;

  /// Row problem
  ///
  /// In ar, this message translates to:
  /// **'الضمان غير صحيح'**
  String get importErrWarranty;

  /// Row problem
  ///
  /// In ar, this message translates to:
  /// **'الرمز مكرر'**
  String get importErrSku;

  /// Row problem
  ///
  /// In ar, this message translates to:
  /// **'الكمية أقل من المحجوز لطلبات مفتوحة'**
  String get importErrReserved;

  /// Row problem
  ///
  /// In ar, this message translates to:
  /// **'قيمة غير صحيحة'**
  String get importErrValue;

  /// Row warning
  ///
  /// In ar, this message translates to:
  /// **'سيارة غير معروفة (تجاهلناها):'**
  String get importWarnModel;

  /// Button
  ///
  /// In ar, this message translates to:
  /// **'تعديل'**
  String get changeOffer;

  /// Empty statement
  ///
  /// In ar, this message translates to:
  /// **'لا حركات في آخر 30 يوماً'**
  String get statementEmpty;

  /// Staff subtitle
  ///
  /// In ar, this message translates to:
  /// **'أضيف {date}'**
  String staffAdded(String date);

  /// Dialog title
  ///
  /// In ar, this message translates to:
  /// **'إزالة {name}؟'**
  String staffRemoveTitle(String name);

  /// Dialog body
  ///
  /// In ar, this message translates to:
  /// **'لن يستطيع إدارة طلبات المحل ومخزونه بعد الآن.'**
  String get staffRemoveBody;

  /// Empty top sellers
  ///
  /// In ar, this message translates to:
  /// **'لا مبيعات في هذه الأيام بعد'**
  String get insightsNoSales;

  /// Profile note
  ///
  /// In ar, this message translates to:
  /// **'لتغيير الاسم أو المكان في الشارع، تواصل مع فريق المنصة.'**
  String get profileNameNote;

  /// Job place without a distance
  ///
  /// In ar, this message translates to:
  /// **'عند الزبون'**
  String get atCustomerPlace;

  /// Job title with more items
  ///
  /// In ar, this message translates to:
  /// **'{first} و{count} أخرى'**
  String jobAndMore(String first, int count);

  /// Booking reference
  ///
  /// In ar, this message translates to:
  /// **'رقم العمل {ref}'**
  String jobRef(String ref);

  /// Snack bar
  ///
  /// In ar, this message translates to:
  /// **'الزبون يرى موقعك الآن حتى تصل'**
  String get onMyWayDone;

  /// Snack bar
  ///
  /// In ar, this message translates to:
  /// **'بدأ العمل'**
  String get checkedIn;

  /// Banner
  ///
  /// In ar, this message translates to:
  /// **'يُشارك موقعك مع الزبون أثناء الطريق.'**
  String get sharingLocation;

  /// Part row
  ///
  /// In ar, this message translates to:
  /// **'استلمت القطعة من {shop}'**
  String partCollected(String shop);

  /// Field label
  ///
  /// In ar, this message translates to:
  /// **'ما المشكلة؟'**
  String get partNotFitReason;

  /// Snack bar
  ///
  /// In ar, this message translates to:
  /// **'سُجّل أن القطعة لا تناسب، وفُتح طلب إرجاع'**
  String get partNotFitDone;

  /// Button / sheet title
  ///
  /// In ar, this message translates to:
  /// **'لا أستطيع الحضور'**
  String get dropJob;

  /// Field label
  ///
  /// In ar, this message translates to:
  /// **'السبب'**
  String get dropJobReason;

  /// Sheet hint
  ///
  /// In ar, this message translates to:
  /// **'يذهب العمل لفني آخر في نفس الموعد. الاعتذار المتكرر يؤثر على تقييمك.'**
  String get dropJobBody;

  /// Snack bar
  ///
  /// In ar, this message translates to:
  /// **'أُرسل العمل لفني آخر'**
  String get dropJobDone;

  /// Pay total label
  ///
  /// In ar, this message translates to:
  /// **'لك'**
  String get youEarnLabel;

  /// Tooltip
  ///
  /// In ar, this message translates to:
  /// **'تعديل الساعات'**
  String get editHours;

  /// Button
  ///
  /// In ar, this message translates to:
  /// **'أضف فترة'**
  String get addPeriod;

  /// Validation
  ///
  /// In ar, this message translates to:
  /// **'تأكد أن كل فترة تنتهي بعد بدايتها ولا تتداخل مع غيرها.'**
  String get periodsOverlap;

  /// Time off without a reason
  ///
  /// In ar, this message translates to:
  /// **'إجازة'**
  String get timeOffDefault;

  /// Empty state
  ///
  /// In ar, this message translates to:
  /// **'ستظهر أرباحك هنا بعد الاعتماد'**
  String get earningsNotYet;

  /// Ledger line: a correction the platform team made by hand
  ///
  /// In ar, this message translates to:
  /// **'تعديل من الإدارة'**
  String get ledgerAdjustment;

  /// Screen title and menu entry
  ///
  /// In ar, this message translates to:
  /// **'الشكاوى'**
  String get complaintsTitle;

  /// Menu entry subtitle
  ///
  /// In ar, this message translates to:
  /// **'شكاوى المشترين عن طلباتك أو أعمالك، وما أبلغت عنه'**
  String get complaintsMenuBody;

  /// Empty state
  ///
  /// In ar, this message translates to:
  /// **'لا توجد شكاوى'**
  String get complaintsEmpty;

  /// Empty state
  ///
  /// In ar, this message translates to:
  /// **'إن أبلغ مشترٍ عن مشكلة في أحد طلباتك أو أعمالك تظهر هنا. ويمكنك الإبلاغ عن مشكلة من صفحة الطلب أو العمل.'**
  String get complaintsEmptyBody;

  /// Button and sheet title
  ///
  /// In ar, this message translates to:
  /// **'الإبلاغ عن مشكلة'**
  String get complaintReport;

  /// Sheet intro
  ///
  /// In ar, this message translates to:
  /// **'اختر نوع المشكلة واشرح ما حدث. يرد فريقنا عادةً خلال يوم عمل.'**
  String get complaintIntro;

  /// Field label
  ///
  /// In ar, this message translates to:
  /// **'ماذا حدث؟'**
  String get complaintDescribe;

  /// Button
  ///
  /// In ar, this message translates to:
  /// **'إرسال'**
  String get complaintSend;

  /// Complaint category
  ///
  /// In ar, this message translates to:
  /// **'لم يستلم القطعة'**
  String get complaintNotReceived;

  /// Complaint category
  ///
  /// In ar, this message translates to:
  /// **'قطعة خاطئة'**
  String get complaintWrongPart;

  /// Complaint category
  ///
  /// In ar, this message translates to:
  /// **'تلف أو عطل'**
  String get complaintDamaged;

  /// Complaint category
  ///
  /// In ar, this message translates to:
  /// **'التركيب لم يتم كما يجب'**
  String get complaintNotFitted;

  /// Complaint category
  ///
  /// In ar, this message translates to:
  /// **'مشكلة في الدفع'**
  String get complaintPayment;

  /// Complaint category
  ///
  /// In ar, this message translates to:
  /// **'سوء معاملة'**
  String get complaintBehaviour;

  /// Complaint category
  ///
  /// In ar, this message translates to:
  /// **'أخرى'**
  String get complaintOther;

  /// Complaint status
  ///
  /// In ar, this message translates to:
  /// **'مفتوحة'**
  String get complaintOpen;

  /// Complaint status
  ///
  /// In ar, this message translates to:
  /// **'قيد المراجعة'**
  String get complaintInReview;

  /// Complaint status
  ///
  /// In ar, this message translates to:
  /// **'تم الحل'**
  String get complaintResolved;

  /// Complaint status
  ///
  /// In ar, this message translates to:
  /// **'مغلقة'**
  String get complaintRejected;

  /// Screen title
  ///
  /// In ar, this message translates to:
  /// **'الشكوى'**
  String get complaintTitle;

  /// Who opened the complaint
  ///
  /// In ar, this message translates to:
  /// **'فتحها {name}'**
  String complaintFrom(String name);

  /// Banner title
  ///
  /// In ar, this message translates to:
  /// **'القرار'**
  String get complaintOutcome;

  /// Message sender
  ///
  /// In ar, this message translates to:
  /// **'أنت'**
  String get complaintYou;

  /// Message sender
  ///
  /// In ar, this message translates to:
  /// **'فريق شارع الغالي'**
  String get complaintTeam;

  /// Field label
  ///
  /// In ar, this message translates to:
  /// **'اكتب ردًا'**
  String get complaintReply;

  /// Welcome tour page 1 title
  ///
  /// In ar, this message translates to:
  /// **'الطلبات وأعمال التركيب تصلك'**
  String get tourOrdersTitle;

  /// Welcome tour page 1 text
  ///
  /// In ar, this message translates to:
  /// **'يصلك تنبيه بكل طلب أو عمل جديد، وتردّ على المشترين في المحادثة.'**
  String get tourOrdersBody;

  /// Welcome tour page 2 title
  ///
  /// In ar, this message translates to:
  /// **'مخزونك حتى بدون إنترنت'**
  String get tourStockTitle;

  /// Welcome tour page 2 text
  ///
  /// In ar, this message translates to:
  /// **'عدّل الأسعار والكميات متى شئت، وتُرسل وحدها عند عودة الاتصال.'**
  String get tourStockBody;

  /// Welcome tour page 3 title
  ///
  /// In ar, this message translates to:
  /// **'تابع أرباحك'**
  String get tourEarnTitle;

  /// Welcome tour page 3 text
  ///
  /// In ar, this message translates to:
  /// **'اعرف ما كسبته من كل طلب وكل تركيب، وما تبقّى لك عند المنصة.'**
  String get tourEarnBody;

  /// Form section
  ///
  /// In ar, this message translates to:
  /// **'موقع المحل على الخريطة'**
  String get shopLocation;

  /// Hint
  ///
  /// In ar, this message translates to:
  /// **'اختياري. يظهر للزبائن زر يفتح خرائط جوجل بالطريق إلى محلك، ولا يظهر إن لم تحدّده.'**
  String get shopLocationBody;

  /// Button
  ///
  /// In ar, this message translates to:
  /// **'حدّد موقع المحل'**
  String get shopLocationPick;

  /// Status
  ///
  /// In ar, this message translates to:
  /// **'حُدّد الموقع'**
  String get shopLocationIsSet;

  /// Button
  ///
  /// In ar, this message translates to:
  /// **'تغيير'**
  String get shopLocationChange;

  /// Button
  ///
  /// In ar, this message translates to:
  /// **'عرض في الخرائط'**
  String get shopLocationView;

  /// Button
  ///
  /// In ar, this message translates to:
  /// **'إزالة'**
  String get shopLocationRemove;

  /// Screen title
  ///
  /// In ar, this message translates to:
  /// **'موقع المحل'**
  String get pickLocationTitle;

  /// Hint over the map
  ///
  /// In ar, this message translates to:
  /// **'حرّك الخريطة حتى يقع الدبوس على باب محلك.'**
  String get pickLocationHint;

  /// Button
  ///
  /// In ar, this message translates to:
  /// **'موقعي الحالي'**
  String get pickLocationHere;

  /// Button
  ///
  /// In ar, this message translates to:
  /// **'اعتمد هذا الموقع'**
  String get pickLocationConfirm;

  /// More menu: the shop's window-tint offer
  ///
  /// In ar, this message translates to:
  /// **'تظليل الزجاج'**
  String get moreTint;

  /// Window tint: switch that shows the shop to buyers choosing tint
  ///
  /// In ar, this message translates to:
  /// **'نقدّم تظليل الزجاج'**
  String get tintOffer;

  /// Window tint: under the switch
  ///
  /// In ar, this message translates to:
  /// **'يظهر محلك للمشترين عندما يختارون التظليل، بالأسعار التي تكتبها هنا.'**
  String get tintOfferBody;

  /// Window tint: section title
  ///
  /// In ar, this message translates to:
  /// **'درجات التعتيم التي تقدّمها'**
  String get tintDarkness;

  /// Window tint: explains the percentages
  ///
  /// In ar, this message translates to:
  /// **'100% هي الأغمق.'**
  String get tintDarknessNote;

  /// Window tint: section title
  ///
  /// In ar, this message translates to:
  /// **'الألوان التي تقدّمها'**
  String get tintColours;

  /// Window tint: section title
  ///
  /// In ar, this message translates to:
  /// **'الأسعار حسب حجم السيارة'**
  String get tintPrices;

  /// Window tint: how the price grid works
  ///
  /// In ar, this message translates to:
  /// **'اترك الخانة فارغة إن كنت لا تقدّمها. سعر النافذة الواحدة يُستخدم حين يختار المشتري النوافذ بنفسه.'**
  String get tintPricesNote;

  /// Window tint: how many prices a car size has
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{لم تُحدَّد أسعار} =1{سعر واحد} =2{سعران} few{{count} أسعار} other{{count} سعرًا}}'**
  String tintPricesSet(int count);

  /// Window tint: the shop has no technician for fitting at the shop
  ///
  /// In ar, this message translates to:
  /// **'لا يعمل في ورشة محلك فني تظليل مسجّل، فلن يرى المشترون خيار التركيب في المحل. اطلب من أحد العاملين التسجيل كفني يعمل في ورشتك.'**
  String get tintBayNone;

  /// Window tint: technicians who can fit it at the shop
  ///
  /// In ar, this message translates to:
  /// **'فنيّو التظليل في ورشة محلك: {count}'**
  String tintBayCount(int count);

  /// Window tint: error before saving
  ///
  /// In ar, this message translates to:
  /// **'اختر درجة تعتيم ولونًا واحدًا على الأقل.'**
  String get tintNeedsChoice;
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
