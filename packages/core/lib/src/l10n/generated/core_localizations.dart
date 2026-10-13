import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'core_localizations_ar.dart';
import 'core_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of CoreLocalizations
/// returned by `CoreLocalizations.of(context)`.
///
/// Applications need to include `CoreLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/core_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: CoreLocalizations.localizationsDelegates,
///   supportedLocales: CoreLocalizations.supportedLocales,
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
/// be consistent with the languages listed in the CoreLocalizations.supportedLocales
/// property.
abstract class CoreLocalizations {
  CoreLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static CoreLocalizations of(BuildContext context) {
    return Localizations.of<CoreLocalizations>(context, CoreLocalizations)!;
  }

  static const LocalizationsDelegate<CoreLocalizations> delegate = _CoreLocalizationsDelegate();

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

  /// Label for the backend connection indicator
  ///
  /// In ar, this message translates to:
  /// **'حالة الخادم'**
  String get backendStatus;

  /// Backend reachable
  ///
  /// In ar, this message translates to:
  /// **'متصل'**
  String get backendOk;

  /// Backend not reachable
  ///
  /// In ar, this message translates to:
  /// **'تعذّر الاتصال'**
  String get backendError;

  /// App was built without Supabase URL/key
  ///
  /// In ar, this message translates to:
  /// **'لم يتم الإعداد بعد'**
  String get backendNotConfigured;

  /// Backend check in progress
  ///
  /// In ar, this message translates to:
  /// **'جارٍ الفحص…'**
  String get backendChecking;

  /// Name of the Arabic language, always written in Arabic
  ///
  /// In ar, this message translates to:
  /// **'العربية'**
  String get languageArabic;

  /// Name of the English language, always written in English
  ///
  /// In ar, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// Title of the language picker
  ///
  /// In ar, this message translates to:
  /// **'اختر اللغة'**
  String get chooseLanguage;

  /// Hint under the language picker
  ///
  /// In ar, this message translates to:
  /// **'يمكنك تغيير اللغة لاحقًا من الإعدادات.'**
  String get chooseLanguageHint;

  /// Primary button to move to the next step
  ///
  /// In ar, this message translates to:
  /// **'متابعة'**
  String get continueAction;

  /// Tooltip for the language toggle button
  ///
  /// In ar, this message translates to:
  /// **'تغيير اللغة'**
  String get switchLanguage;

  /// An amount in Sudanese pounds. amount is already grouped, e.g. 12,000
  ///
  /// In ar, this message translates to:
  /// **'{amount} ج.س'**
  String money(String amount);

  /// Lowest price among several shops, e.g. 'from 12,000 SDG'
  ///
  /// In ar, this message translates to:
  /// **'من {amount}'**
  String moneyFrom(String amount);

  /// Distance in kilometres
  ///
  /// In ar, this message translates to:
  /// **'{value} كم'**
  String km(String value);

  /// A duration in minutes
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{دقيقة} =2{دقيقتان} few{{count} دقائق} other{{count} دقيقة}}'**
  String minutes(int count);

  /// Warranty length on a part
  ///
  /// In ar, this message translates to:
  /// **'{days, plural, =0{بدون ضمان} =1{ضمان يوم} =2{ضمان يومين} few{ضمان {days} أيام} other{ضمان {days} يومًا}}'**
  String warrantyDays(int days);

  /// Warranty length in months (used for 30+ days)
  ///
  /// In ar, this message translates to:
  /// **'{months, plural, =1{ضمان شهر} =2{ضمان شهرين} few{ضمان {months} أشهر} other{ضمان {months} شهرًا}}'**
  String warrantyMonths(int months);

  /// Warranty of one year
  ///
  /// In ar, this message translates to:
  /// **'ضمان سنة'**
  String get warrantyYear;

  /// How many units a shop has
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{قطعة واحدة متبقية} =2{قطعتان متبقيتان} few{{count} قطع متوفرة} other{{count} قطعة متوفرة}}'**
  String inStock(int count);

  /// Listing has no stock
  ///
  /// In ar, this message translates to:
  /// **'نفدت الكمية'**
  String get outOfStock;

  /// Number of reviews
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{لا تقييمات} =1{تقييم واحد} =2{تقييمان} few{{count} تقييمات} other{{count} تقييمًا}}'**
  String ratingCount(int count);

  /// Completed installation jobs
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{لا أعمال بعد} =1{عمل واحد} =2{عملان} few{{count} أعمال} other{{count} عملًا}}'**
  String jobsDone(int count);

  /// Relative time
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{الآن} =1{قبل دقيقة} =2{قبل دقيقتين} few{قبل {count} دقائق} other{قبل {count} دقيقة}}'**
  String agoMinutes(int count);

  /// Relative time
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{قبل ساعة} =2{قبل ساعتين} few{قبل {count} ساعات} other{قبل {count} ساعة}}'**
  String agoHours(int count);

  /// Relative time
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{أمس} =2{قبل يومين} few{قبل {count} أيام} other{قبل {count} يومًا}}'**
  String agoDays(int count);

  /// Today, in date pickers
  ///
  /// In ar, this message translates to:
  /// **'اليوم'**
  String get today;

  /// Tomorrow, in date pickers
  ///
  /// In ar, this message translates to:
  /// **'غدًا'**
  String get tomorrow;

  /// Listing condition: new genuine (OEM) part
  ///
  /// In ar, this message translates to:
  /// **'جديد أصلي'**
  String get conditionNewOem;

  /// Listing condition: new aftermarket part
  ///
  /// In ar, this message translates to:
  /// **'جديد تجاري'**
  String get conditionNewAftermarket;

  /// Listing condition: used part
  ///
  /// In ar, this message translates to:
  /// **'مستعمل'**
  String get conditionUsed;

  /// Badge: the part is known to fit the selected car
  ///
  /// In ar, this message translates to:
  /// **'يناسب سيارتك'**
  String get fitFits;

  /// Badge: no fitment data, ask the shop
  ///
  /// In ar, this message translates to:
  /// **'تأكّد من المناسبة'**
  String get fitCheck;

  /// The part does not fit the selected car
  ///
  /// In ar, this message translates to:
  /// **'لا يناسب سيارتك'**
  String get fitNoFit;

  /// Badge for a shop the platform has verified
  ///
  /// In ar, this message translates to:
  /// **'محل موثّق'**
  String get verifiedShop;

  /// Badge for a vetted technician
  ///
  /// In ar, this message translates to:
  /// **'فني موثّق'**
  String get verifiedTechnician;

  /// Payment method: Bankak transfer (mBOK)
  ///
  /// In ar, this message translates to:
  /// **'بنكك'**
  String get payBankak;

  /// Payment method: cash
  ///
  /// In ar, this message translates to:
  /// **'نقدًا'**
  String get payCash;

  /// Fulfilment: buyer picks up at the shop
  ///
  /// In ar, this message translates to:
  /// **'استلام من المحل'**
  String get fulfilPickup;

  /// Fulfilment: shop delivers
  ///
  /// In ar, this message translates to:
  /// **'توصيل'**
  String get fulfilDelivery;

  /// Fulfilment: the shop hands the part to the technician
  ///
  /// In ar, this message translates to:
  /// **'يسلّمها المحل للفني'**
  String get fulfilToTechnician;

  /// Sub-order status
  ///
  /// In ar, this message translates to:
  /// **'بانتظار الدفع'**
  String get subPendingPayment;

  /// Sub-order status: admin is checking the Bankak receipt
  ///
  /// In ar, this message translates to:
  /// **'جارٍ التحقق من الدفع'**
  String get subPaymentReview;

  /// Sub-order status
  ///
  /// In ar, this message translates to:
  /// **'مؤكَّد'**
  String get subConfirmed;

  /// Sub-order status: ready at the shop
  ///
  /// In ar, this message translates to:
  /// **'جاهز'**
  String get subReady;

  /// Sub-order status
  ///
  /// In ar, this message translates to:
  /// **'تم الاستلام'**
  String get subPickedUp;

  /// Sub-order status
  ///
  /// In ar, this message translates to:
  /// **'في الطريق إليك'**
  String get subOutForDelivery;

  /// Sub-order status
  ///
  /// In ar, this message translates to:
  /// **'تم التوصيل'**
  String get subDelivered;

  /// Sub-order status
  ///
  /// In ar, this message translates to:
  /// **'سُلّم للفني'**
  String get subHandedToTechnician;

  /// Sub-order status
  ///
  /// In ar, this message translates to:
  /// **'مكتمل'**
  String get subCompleted;

  /// Sub-order status
  ///
  /// In ar, this message translates to:
  /// **'ملغى'**
  String get subCancelled;

  /// Sub-order status
  ///
  /// In ar, this message translates to:
  /// **'رفضه المحل'**
  String get subRejectedByShop;

  /// Sub-order status
  ///
  /// In ar, this message translates to:
  /// **'طلب إرجاع'**
  String get subReturnRequested;

  /// Sub-order status
  ///
  /// In ar, this message translates to:
  /// **'مُرجَع'**
  String get subReturned;

  /// Payment status
  ///
  /// In ar, this message translates to:
  /// **'بانتظار التحويل'**
  String get payAwaitingTransfer;

  /// Payment status: receipt uploaded, admin checking
  ///
  /// In ar, this message translates to:
  /// **'جارٍ التحقق من الدفع'**
  String get payReceiptSubmitted;

  /// Payment status
  ///
  /// In ar, this message translates to:
  /// **'تم الدفع'**
  String get payConfirmed;

  /// Payment status
  ///
  /// In ar, this message translates to:
  /// **'رُفض الإيصال'**
  String get payRejected;

  /// Payment status: cash to be paid on pickup/at the job
  ///
  /// In ar, this message translates to:
  /// **'يُدفع نقدًا'**
  String get payDue;

  /// Payment status: cash collected
  ///
  /// In ar, this message translates to:
  /// **'تم التحصيل'**
  String get payCollected;

  /// Payment status
  ///
  /// In ar, this message translates to:
  /// **'انتهت مهلة الدفع'**
  String get payExpired;

  /// Payment state: the order was cancelled before it was paid
  ///
  /// In ar, this message translates to:
  /// **'أُلغي الدفع'**
  String get payCancelled;

  /// Booking status: slot held during checkout
  ///
  /// In ar, this message translates to:
  /// **'الموعد محجوز مؤقتًا'**
  String get bkHeld;

  /// Booking status
  ///
  /// In ar, this message translates to:
  /// **'بانتظار تأكيد الدفع'**
  String get bkAwaitingPayment;

  /// Booking status
  ///
  /// In ar, this message translates to:
  /// **'بانتظار موافقة الفني'**
  String get bkPendingTechAccept;

  /// Booking status: technician accepted
  ///
  /// In ar, this message translates to:
  /// **'مؤكَّد'**
  String get bkAccepted;

  /// Booking status
  ///
  /// In ar, this message translates to:
  /// **'الفني في الطريق'**
  String get bkEnRoute;

  /// Booking status
  ///
  /// In ar, this message translates to:
  /// **'جارٍ العمل'**
  String get bkInProgress;

  /// Booking status
  ///
  /// In ar, this message translates to:
  /// **'مكتمل'**
  String get bkCompleted;

  /// Booking status: nobody free, buyer must reschedule
  ///
  /// In ar, this message translates to:
  /// **'يحتاج موعدًا جديدًا'**
  String get bkNeedsReschedule;

  /// Booking status
  ///
  /// In ar, this message translates to:
  /// **'انتهى الحجز المؤقت'**
  String get bkExpired;

  /// Booking status
  ///
  /// In ar, this message translates to:
  /// **'ألغيته'**
  String get bkCancelledByBuyer;

  /// Booking status
  ///
  /// In ar, this message translates to:
  /// **'ألغاه الفني'**
  String get bkCancelledByTech;

  /// Booking status
  ///
  /// In ar, this message translates to:
  /// **'ألغته الإدارة'**
  String get bkCancelledByAdmin;

  /// Booking status
  ///
  /// In ar, this message translates to:
  /// **'القطعة لم تناسب'**
  String get bkPartDoesNotFit;

  /// Job type
  ///
  /// In ar, this message translates to:
  /// **'إضاءة'**
  String get jobLighting;

  /// Job type
  ///
  /// In ar, this message translates to:
  /// **'فرامل'**
  String get jobBrakes;

  /// Job type: oil change, filters, plugs
  ///
  /// In ar, this message translates to:
  /// **'صيانة دورية'**
  String get jobService;

  /// Job type
  ///
  /// In ar, this message translates to:
  /// **'بطاريات'**
  String get jobBattery;

  /// Job type
  ///
  /// In ar, this message translates to:
  /// **'كهرباء'**
  String get jobElectrical;

  /// Job type
  ///
  /// In ar, this message translates to:
  /// **'تكييف'**
  String get jobAc;

  /// Job type: suspension
  ///
  /// In ar, this message translates to:
  /// **'عفشة'**
  String get jobSuspension;

  /// Job type
  ///
  /// In ar, this message translates to:
  /// **'إطارات'**
  String get jobTyres;

  /// Job type: engine, cooling, gearbox and clutch work
  ///
  /// In ar, this message translates to:
  /// **'ميكانيكا'**
  String get jobMechanical;

  /// Technician works at a bay on the street
  ///
  /// In ar, this message translates to:
  /// **'في الورشة'**
  String get modeBay;

  /// Technician comes to the buyer
  ///
  /// In ar, this message translates to:
  /// **'يأتي إليك'**
  String get modeMobile;

  /// Technician does both
  ///
  /// In ar, this message translates to:
  /// **'في الورشة أو يأتي إليك'**
  String get modeBoth;

  /// Side A of the street
  ///
  /// In ar, this message translates to:
  /// **'الجهة أ'**
  String get sideA;

  /// Side B of the street
  ///
  /// In ar, this message translates to:
  /// **'الجهة ب'**
  String get sideB;

  /// Shop plot number
  ///
  /// In ar, this message translates to:
  /// **'قطعة {number}'**
  String plot(String number);

  /// Generic cancel
  ///
  /// In ar, this message translates to:
  /// **'إلغاء'**
  String get actionCancel;

  /// Generic save
  ///
  /// In ar, this message translates to:
  /// **'حفظ'**
  String get actionSave;

  /// Generic done
  ///
  /// In ar, this message translates to:
  /// **'تم'**
  String get actionDone;

  /// Generic next step
  ///
  /// In ar, this message translates to:
  /// **'التالي'**
  String get actionNext;

  /// Generic back
  ///
  /// In ar, this message translates to:
  /// **'رجوع'**
  String get actionBack;

  /// Generic close
  ///
  /// In ar, this message translates to:
  /// **'إغلاق'**
  String get actionClose;

  /// Retry after an error
  ///
  /// In ar, this message translates to:
  /// **'إعادة المحاولة'**
  String get actionRetry;

  /// Link to a full list
  ///
  /// In ar, this message translates to:
  /// **'عرض الكل'**
  String get actionSeeAll;

  /// Call a shop/technician/buyer
  ///
  /// In ar, this message translates to:
  /// **'اتصال'**
  String get actionCall;

  /// Open WhatsApp chat
  ///
  /// In ar, this message translates to:
  /// **'واتساب'**
  String get actionWhatsApp;

  /// Open in-app chat
  ///
  /// In ar, this message translates to:
  /// **'محادثة'**
  String get actionChat;

  /// Copy to clipboard
  ///
  /// In ar, this message translates to:
  /// **'نسخ'**
  String get actionCopy;

  /// Shown after copying
  ///
  /// In ar, this message translates to:
  /// **'تم النسخ'**
  String get copied;

  /// Open directions in maps
  ///
  /// In ar, this message translates to:
  /// **'الاتجاهات'**
  String get actionDirections;

  /// Generic edit
  ///
  /// In ar, this message translates to:
  /// **'تعديل'**
  String get actionEdit;

  /// Generic remove
  ///
  /// In ar, this message translates to:
  /// **'حذف'**
  String get actionRemove;

  /// Generic confirm
  ///
  /// In ar, this message translates to:
  /// **'تأكيد'**
  String get actionConfirm;

  /// Marks an optional form field
  ///
  /// In ar, this message translates to:
  /// **'اختياري'**
  String get optional;

  /// Generic error title
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ ما'**
  String get errorGeneric;

  /// Generic error message
  ///
  /// In ar, this message translates to:
  /// **'لم نتمكن من إكمال الطلب. تحقّق من الاتصال وحاول مرة أخرى.'**
  String get errorGenericBody;

  /// Shown while offline
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد اتصال — نعرض آخر بيانات محفوظة'**
  String get offlineBanner;

  /// Marks the app as using sample data
  ///
  /// In ar, this message translates to:
  /// **'نسخة تجريبية'**
  String get demoBadge;

  /// Explains that the demo uses sample data
  ///
  /// In ar, this message translates to:
  /// **'هذه نسخة تجريبية ببيانات نموذجية. لا تتم أي عمليات دفع أو اتصال حقيقية.'**
  String get demoNote;

  /// Shown when a real-world action (call, WhatsApp) is tapped in the demo
  ///
  /// In ar, this message translates to:
  /// **'هذا الإجراء معطّل في النسخة التجريبية.'**
  String get demoActionDisabled;

  /// Platform name, used in the logo
  ///
  /// In ar, this message translates to:
  /// **'شارع الغالي'**
  String get brandName;

  /// Short tagline under the logo
  ///
  /// In ar, this message translates to:
  /// **'قطع الغيار والتركيب'**
  String get brandTagline;

  /// Form validation: empty required field
  ///
  /// In ar, this message translates to:
  /// **'هذا الحقل مطلوب'**
  String get fieldRequired;

  /// Form validation: bad email
  ///
  /// In ar, this message translates to:
  /// **'اكتب بريدًا إلكترونيًا صحيحًا، مثل name@example.com'**
  String get fieldEmailInvalid;

  /// Form validation: password rule (D-046)
  ///
  /// In ar, this message translates to:
  /// **'8 أحرف على الأقل، وفيها حروف وأرقام'**
  String get fieldPasswordWeak;

  /// Form validation: phone number
  ///
  /// In ar, this message translates to:
  /// **'اكتب رقمًا سودانيًا من 10 أرقام يبدأ بـ 0'**
  String get fieldPhoneInvalid;

  /// Form validation: not a number
  ///
  /// In ar, this message translates to:
  /// **'اكتب رقمًا صحيحًا'**
  String get fieldNumberInvalid;

  /// Compact thousands on chart axes, e.g. '50 ألف'
  ///
  /// In ar, this message translates to:
  /// **'{value} ألف'**
  String thousands(String value);
}

class _CoreLocalizationsDelegate extends LocalizationsDelegate<CoreLocalizations> {
  const _CoreLocalizationsDelegate();

  @override
  Future<CoreLocalizations> load(Locale locale) {
    return SynchronousFuture<CoreLocalizations>(lookupCoreLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_CoreLocalizationsDelegate old) => false;
}

CoreLocalizations lookupCoreLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return CoreLocalizationsAr();
    case 'en':
      return CoreLocalizationsEn();
  }

  throw FlutterError(
    'CoreLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
