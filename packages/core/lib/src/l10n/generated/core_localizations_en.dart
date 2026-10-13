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
}
