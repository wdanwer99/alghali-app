// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'core_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class CoreLocalizationsEn extends CoreLocalizations {
  CoreLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get backendStatus => 'Backend status';

  @override
  String get backendOk => 'Connected';

  @override
  String get backendError => 'Can\'t connect';

  @override
  String get backendNotConfigured => 'Not set up yet';

  @override
  String get backendChecking => 'Checking…';

  @override
  String get languageArabic => 'العربية';

  @override
  String get languageEnglish => 'English';

  @override
  String get chooseLanguage => 'Choose your language';

  @override
  String get chooseLanguageHint => 'You can change it later in settings.';

  @override
  String get continueAction => 'Continue';

  @override
  String get switchLanguage => 'Change language';

  @override
  String money(String amount) {
    return 'SDG $amount';
  }

  @override
  String moneyFrom(String amount) {
    return 'from $amount';
  }

  @override
  String km(String value) {
    return '$value km';
  }

  @override
  String minutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutes',
      one: '1 minute',
    );
    return '$_temp0';
  }

  @override
  String warrantyDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days-day warranty',
      one: '1-day warranty',
      zero: 'No warranty',
    );
    return '$_temp0';
  }

  @override
  String warrantyMonths(int months) {
    String _temp0 = intl.Intl.pluralLogic(
      months,
      locale: localeName,
      other: '$months-month warranty',
      one: '1-month warranty',
    );
    return '$_temp0';
  }

  @override
  String get warrantyYear => '1-year warranty';

  @override
  String inStock(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count in stock',
      two: 'Only 2 left',
      one: 'Only 1 left',
    );
    return '$_temp0';
  }

  @override
  String get outOfStock => 'Out of stock';

  @override
  String ratingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count reviews',
      one: '1 review',
      zero: 'No reviews',
    );
    return '$_temp0';
  }

  @override
  String jobsDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count jobs',
      one: '1 job',
      zero: 'No jobs yet',
    );
    return '$_temp0';
  }

  @override
  String agoMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count min ago',
      one: '1 min ago',
      zero: 'just now',
    );
    return '$_temp0';
  }

  @override
  String agoHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours ago',
      one: '1 hour ago',
    );
    return '$_temp0';
  }

  @override
  String agoDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days ago',
      one: 'yesterday',
    );
    return '$_temp0';
  }

  @override
  String get today => 'Today';

  @override
  String get tomorrow => 'Tomorrow';

  @override
  String get conditionNewOem => 'New, genuine';

  @override
  String get conditionNewAftermarket => 'New, aftermarket';

  @override
  String get conditionUsed => 'Used';

  @override
  String get fitFits => 'Fits your car';

  @override
  String get fitCheck => 'Check fitment';

  @override
  String get fitNoFit => 'Doesn\'t fit your car';

  @override
  String get verifiedShop => 'Verified shop';

  @override
  String get verifiedTechnician => 'Verified technician';

  @override
  String get payBankak => 'Bankak';

  @override
  String get payCash => 'Cash';

  @override
  String get fulfilPickup => 'Pick up at the shop';

  @override
  String get fulfilDelivery => 'Delivery';

  @override
  String get fulfilToTechnician => 'Shop hands it to the technician';

  @override
  String get subPendingPayment => 'Waiting for payment';

  @override
  String get subPaymentReview => 'Payment being checked';

  @override
  String get subConfirmed => 'Confirmed';

  @override
  String get subReady => 'Ready';

  @override
  String get subPickedUp => 'Picked up';

  @override
  String get subOutForDelivery => 'On the way to you';

  @override
  String get subDelivered => 'Delivered';

  @override
  String get subHandedToTechnician => 'With the technician';

  @override
  String get subCompleted => 'Completed';

  @override
  String get subCancelled => 'Cancelled';

  @override
  String get subRejectedByShop => 'Declined by shop';

  @override
  String get subReturnRequested => 'Return requested';

  @override
  String get subReturned => 'Returned';

  @override
  String get payAwaitingTransfer => 'Waiting for transfer';

  @override
  String get payReceiptSubmitted => 'Payment being checked';

  @override
  String get payConfirmed => 'Paid';

  @override
  String get payRejected => 'Receipt rejected';

  @override
  String get payDue => 'Pay in cash';

  @override
  String get payCollected => 'Cash collected';

  @override
  String get payExpired => 'Payment time ran out';

  @override
  String get payCancelled => 'Payment cancelled';

  @override
  String get bkHeld => 'Time held for you';

  @override
  String get bkAwaitingPayment => 'Waiting for payment check';

  @override
  String get bkPendingTechAccept => 'Waiting for the technician';

  @override
  String get bkAccepted => 'Confirmed';

  @override
  String get bkEnRoute => 'Technician on the way';

  @override
  String get bkInProgress => 'Work in progress';

  @override
  String get bkCompleted => 'Completed';

  @override
  String get bkNeedsReschedule => 'Needs a new time';

  @override
  String get bkExpired => 'Hold expired';

  @override
  String get bkCancelledByBuyer => 'You cancelled';

  @override
  String get bkCancelledByTech => 'Technician cancelled';

  @override
  String get bkCancelledByAdmin => 'Cancelled by support';

  @override
  String get bkPartDoesNotFit => 'Part didn\'t fit';

  @override
  String get jobLighting => 'Lighting';

  @override
  String get jobBrakes => 'Brakes';

  @override
  String get jobService => 'Servicing';

  @override
  String get jobBattery => 'Batteries';

  @override
  String get jobElectrical => 'Electrical';

  @override
  String get jobAc => 'Air conditioning';

  @override
  String get jobSuspension => 'Suspension';

  @override
  String get jobTyres => 'Tyres';

  @override
  String get jobMechanical => 'Mechanical';

  @override
  String get modeBay => 'At the workshop';

  @override
  String get modeMobile => 'Comes to you';

  @override
  String get modeBoth => 'Workshop or comes to you';

  @override
  String get sideA => 'Side A';

  @override
  String get sideB => 'Side B';

  @override
  String plot(String number) {
    return 'Plot $number';
  }

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionSave => 'Save';

  @override
  String get actionDone => 'Done';

  @override
  String get actionNext => 'Next';

  @override
  String get actionBack => 'Back';

  @override
  String get actionClose => 'Close';

  @override
  String get actionRetry => 'Try again';

  @override
  String get actionSeeAll => 'See all';

  @override
  String get actionCall => 'Call';

  @override
  String get actionWhatsApp => 'WhatsApp';

  @override
  String get actionChat => 'Chat';

  @override
  String get actionCopy => 'Copy';

  @override
  String get copied => 'Copied';

  @override
  String get actionDirections => 'Directions';

  @override
  String get actionEdit => 'Edit';

  @override
  String get actionRemove => 'Remove';

  @override
  String get actionConfirm => 'Confirm';

  @override
  String get optional => 'Optional';

  @override
  String get errorGeneric => 'Something went wrong';

  @override
  String get errorGenericBody => 'We couldn\'t finish that. Check your connection and try again.';

  @override
  String get offlineBanner => 'You\'re offline — showing saved data';

  @override
  String get demoBadge => 'Demo';

  @override
  String get demoNote => 'This is a demo with sample data. No real payments or calls happen.';

  @override
  String get demoActionDisabled => 'This action is switched off in the demo.';

  @override
  String get brandName => 'Alghali Street';

  @override
  String get brandTagline => 'Car parts & fitting';

  @override
  String get fieldRequired => 'This field is required';

  @override
  String get fieldEmailInvalid => 'Enter a valid email, like name@example.com';

  @override
  String get fieldPasswordWeak => 'At least 8 characters, with letters and numbers';

  @override
  String get fieldPhoneInvalid => 'Enter a 10-digit Sudanese number starting with 0';

  @override
  String get fieldNumberInvalid => 'Enter a valid number';

  @override
  String thousands(String value) {
    return '${value}K';
  }

  @override
  String get errOffline => 'No connection. Try again in a moment.';

  @override
  String get errGeneric => 'Something went wrong. Please try again.';

  @override
  String get errSessionExpired => 'Your session ended. Please sign in again.';

  @override
  String get errInvalidCredentials => 'Wrong email or password.';

  @override
  String get errEmailTaken => 'This email already has an account. Sign in instead.';

  @override
  String get errTooManyAttempts => 'Too many attempts. Wait a little, then try again.';

  @override
  String get errPhoneRequired =>
      'Add your phone number in your account first, so the shop or technician can call you.';

  @override
  String get errSlotTaken => 'Someone just took this time. Pick another.';

  @override
  String get errHoldExpired => 'The time you held has lapsed. Pick it again.';

  @override
  String get errTechnicianUnavailable =>
      'This technician is no longer free then. Pick another time or technician.';

  @override
  String get errTooEarly => 'That time is too soon. Pick a later one.';

  @override
  String get errOutOfRange => 'That place is outside the service area.';

  @override
  String get errTravelUnavailable =>
      'Fitting at your place isn\'t available yet. Choose a workshop on the street.';

  @override
  String get errDeliveryUnavailable =>
      'Delivery isn\'t available to this address yet. Choose pickup.';

  @override
  String get errDuplicateTxn => 'This transaction number was already used. Check it.';

  @override
  String get errPaymentExpired => 'The time to pay for this order has passed.';

  @override
  String get errCannotCancel => 'This can no longer be cancelled.';

  @override
  String get errTooManyRequests => 'You have too many open photo requests. Close some first.';

  @override
  String get errGarageFull => 'You can save up to 10 cars.';

  @override
  String get errFileTooLarge => 'The file is too big (5 MB at most).';

  @override
  String get errFileType => 'That file type isn\'t supported.';

  @override
  String get errNotFound => 'We couldn\'t find that. It may have been removed.';

  @override
  String get errForbidden => 'You can\'t do that.';

  @override
  String get errCartChanged => 'Some prices or stock changed. Check your cart, then confirm.';

  @override
  String get errAddressRequired => 'Choose an address or add a new one.';

  @override
  String get errLocationOff => 'Turn on location (GPS) on your phone, then try again.';

  @override
  String get errLocationDenied => 'Allow location access in your phone settings.';

  @override
  String get errMicDenied => 'Allow microphone access in your phone settings.';

  @override
  String get errCannotOpen => 'Couldn\'t open that on your phone.';

  @override
  String get errUnavailable => 'This is no longer available.';

  @override
  String get queuedOffline => 'Will be sent when you\'re back online';

  @override
  String notSent(String reason) {
    return 'Not sent: $reason';
  }

  @override
  String get voiceHold => 'Hold to record';

  @override
  String get voiceRecording => 'Recording… lift your finger to send';

  @override
  String get voiceTooShort => 'Press and hold the microphone to record.';

  @override
  String get voicePlay => 'Play';

  @override
  String get voicePause => 'Pause';

  @override
  String get photoCamera => 'Camera';

  @override
  String get photoGallery => 'Gallery';

  @override
  String get pullToRefresh => 'Pull to refresh';

  @override
  String get actionOpen => 'Open';

  @override
  String get errChangedMeanwhile => 'This changed meanwhile. Pull down to see where it is now.';

  @override
  String get errVersionConflict => 'Someone else just changed this part. Check it and try again.';

  @override
  String get errStockBelowReserved => 'Stock can\'t go below what open orders have reserved.';

  @override
  String get errPriceRequired => 'Enter a price.';

  @override
  String get errCheckValue => 'Check what you entered and try again.';

  @override
  String get errShopNotActive =>
      'The shop is suspended or not approved. Contact the platform team.';

  @override
  String get errTechNotActive => 'The technician account isn\'t active yet.';

  @override
  String get errPartsNotCollected => 'Collect the parts from the shop first.';

  @override
  String get errPartsWithTechnician =>
      'You have the parts now. Contact the platform team to drop this job.';

  @override
  String get errJobCodeLocked =>
      'Finishing is locked after wrong codes. The platform team will help.';

  @override
  String get errLabourBounds => 'That price is outside the platform\'s limits.';

  @override
  String get errTooManyRules => 'Too many working periods.';

  @override
  String get errTimeOffTooLong => 'Time off can be up to 60 days.';

  @override
  String get errAlreadyMember => 'They\'re already in your shop.';

  @override
  String get errUserNotFound =>
      'No account with that email. Ask them to sign up in the partner app first.';

  @override
  String get errTooManyStaff => 'You\'ve reached the staff limit.';

  @override
  String get errCannotRemoveOwner => 'The owner can\'t be removed.';

  @override
  String get errAlreadyApplied => 'You already have an application under review.';

  @override
  String get errTooManyShops => 'You can run up to 3 shops.';

  @override
  String get errBayRequired => 'Choose the bay where you work.';

  @override
  String get errHomeRequired => 'Set your starting point for visits.';

  @override
  String get errJobTypesRequired => 'Choose at least one kind of job.';

  @override
  String get errReasonRequired => 'Write a reason.';

  @override
  String get errBadSheet =>
      'The file doesn\'t match the template. Download the template, fill it in and try again.';

  @override
  String get errTooManyRows => 'The file has more than 2,000 rows. Split it into smaller files.';

  @override
  String get updateTitle => 'Update the app';

  @override
  String get updateRequiredBody =>
      'This version is too old to use. Download the new one and install it over this one; your account and data stay as they are.';

  @override
  String get updateAvailableBody => 'A new version of the app is available.';

  @override
  String get updateDownload => 'Download';

  @override
  String get tourSkip => 'Skip';

  @override
  String get tourNext => 'Next';

  @override
  String get tourStart => 'Get started';

  @override
  String tourStep(int current, int total) {
    return 'Page $current of $total';
  }
}
