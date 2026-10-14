// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Alghali Street';

  @override
  String get navHome => 'Home';

  @override
  String get navStreet => 'Street';

  @override
  String get navCart => 'Cart';

  @override
  String get navOrders => 'My orders';

  @override
  String get navAccount => 'Account';

  @override
  String get welcomeTitle => 'Car parts and fitting in one place';

  @override
  String get welcomePointFit => 'Parts that fit your car, from Alghali Street shops';

  @override
  String get welcomePointCompare => 'Compare prices across shops before you buy';

  @override
  String get welcomePointInstall => 'Book a technician at a workshop or at your place';

  @override
  String get homeSearchHint => 'Search for a part, e.g. bulbs, brake pads';

  @override
  String get homeAddCar => 'Add your car to see parts that fit';

  @override
  String get homeChangeCar => 'Change';

  @override
  String get homeQuickPhotoTitle => 'Send a photo';

  @override
  String get homeQuickPhotoBody => 'Can\'t find it? Shops send you offers';

  @override
  String get homeQuickBookTitle => 'Book a technician';

  @override
  String get homeQuickBookBody => 'At a workshop or at your place';

  @override
  String get homeCategories => 'Shop by category';

  @override
  String homeDealsFor(String model) {
    return 'Deals for your $model';
  }

  @override
  String get homeDeals => 'Today\'s deals';

  @override
  String get homeStreetTitle => 'Shops on the street';

  @override
  String homeStreetBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count shops along Alghali Street',
      one: '1 shop along Alghali Street',
    );
    return '$_temp0';
  }

  @override
  String get homeStreetOpen => 'Open the street map';

  @override
  String get homeTrustPay => 'Pay by Bankak or cash';

  @override
  String get homeTrustTech => 'Vetted, rated technicians';

  @override
  String homeTrustReturns(int days) {
    return '$days-day returns';
  }

  @override
  String get homeNextFitting => 'Your next fitting';

  @override
  String get homeCurrentOrder => 'Your current order';

  @override
  String get notificationsTitle => 'Notifications';

  @override
  String get notificationsMarkRead => 'Mark all as read';

  @override
  String get notificationsEmpty => 'No notifications';

  @override
  String get notificationsEmptyBody =>
      'Payment checks, shop offers and your appointments show up here.';

  @override
  String get searchHint => 'Search a part or part number';

  @override
  String get searchFilters => 'Filters';

  @override
  String get searchFitsOnly => 'Fits my car only';

  @override
  String get sortRelevance => 'Best match';

  @override
  String get sortPriceLow => 'Lowest price';

  @override
  String get sortPriceHigh => 'Highest price';

  @override
  String get sortRating => 'Top rated';

  @override
  String searchShowingFor(String car) {
    return 'Showing parts for $car';
  }

  @override
  String get searchNoCar => 'Add your car to see only parts that fit';

  @override
  String get searchRecent => 'Recent searches';

  @override
  String get searchPopular => 'Popular';

  @override
  String searchResults(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count results',
      one: '1 result',
      zero: 'No results',
    );
    return '$_temp0';
  }

  @override
  String shopsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count shops',
      one: '1 shop',
    );
    return '$_temp0';
  }

  @override
  String get searchNoResults => 'No matching parts';

  @override
  String get searchNoResultsBody =>
      'Try another word, or send a photo of the part and shops will send you offers.';

  @override
  String get searchSendPhoto => 'Send a photo of the part';

  @override
  String get filtersTitle => 'Filters';

  @override
  String get filtersCondition => 'Condition';

  @override
  String get filtersMaxPrice => 'Maximum price';

  @override
  String get filtersAnyPrice => 'Any price';

  @override
  String filtersUpTo(String amount) {
    return 'Up to $amount';
  }

  @override
  String get filtersSort => 'Sort by';

  @override
  String get filtersReset => 'Clear all';

  @override
  String get filtersApply => 'Show results';

  @override
  String partFits(String car) {
    return 'Fits your $car';
  }

  @override
  String get partCheck => 'We don\'t have fitment data for this part. Ask the shop before you buy.';

  @override
  String partNoFit(String car) {
    return 'This part doesn\'t fit your $car.';
  }

  @override
  String get partNoCar => 'Add your car so we can check this part fits.';

  @override
  String get partOem => 'OEM number';

  @override
  String partCompare(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Compare $count shops',
      one: 'Sold by 1 shop',
    );
    return '$_temp0';
  }

  @override
  String get partBestPrice => 'Best price';

  @override
  String get partAddToCart => 'Add to cart';

  @override
  String get partAdded => 'Added to your cart';

  @override
  String get partViewCart => 'View cart';

  @override
  String get partFittingTitle => 'Need it fitted?';

  @override
  String partFittingBody(String amount) {
    return 'Add fitting in your cart: at a workshop on the street or at your place. Labour from $amount.';
  }

  @override
  String get partAbout => 'About this part';

  @override
  String get shopOpen => 'Open now';

  @override
  String get shopClosed => 'Closed now';

  @override
  String get shopOnStreet => 'Show on the street';

  @override
  String get shopParts => 'Parts';

  @override
  String get shopReviews => 'Reviews';

  @override
  String get shopAbout => 'About the shop';

  @override
  String shopSince(String year) {
    return 'On the platform since $year';
  }

  @override
  String get shopNoReviews => 'No reviews yet';

  @override
  String get viewShop => 'View shop';

  @override
  String get streetHint => 'Tap a shop to see its details';

  @override
  String get streetAll => 'All';

  @override
  String get streetNorth => 'North';

  @override
  String get streetSouth => 'South';

  @override
  String get cartEmpty => 'Your cart is empty';

  @override
  String get cartEmptyBody => 'Find the part you need and add it here.';

  @override
  String get cartBrowse => 'Browse parts';

  @override
  String get cartAddFitting => 'Add fitting';

  @override
  String cartFittingFrom(String amount) {
    return 'Fitting from $amount';
  }

  @override
  String get cartFitting => 'Fitting';

  @override
  String get cartAnyTech => 'First available technician';

  @override
  String get placeBay => 'At the workshop';

  @override
  String get placeHome => 'At your place';

  @override
  String cartHeldFor(String time) {
    return 'Held for you $time';
  }

  @override
  String get cartHoldExpired => 'Your hold ran out. Pick a new time.';

  @override
  String get cartChange => 'Change';

  @override
  String get cartRemoveFitting => 'Remove fitting';

  @override
  String get cartRemoveItem => 'Remove from cart';

  @override
  String get cartSummary => 'Order summary';

  @override
  String get costParts => 'Parts';

  @override
  String get costLabour => 'Labour';

  @override
  String get costTravel => 'Travel fee';

  @override
  String get costBookingFee => 'Booking fee';

  @override
  String get costDelivery => 'Delivery';

  @override
  String get costTotal => 'Total';

  @override
  String get costFree => 'Free';

  @override
  String get cartDeliveryLater => 'You choose pickup or delivery at the next step.';

  @override
  String get cartCheckout => 'Checkout';

  @override
  String itemsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
    );
    return '$_temp0';
  }

  @override
  String get bookTitle => 'Book fitting';

  @override
  String get bookStepWhat => 'Part';

  @override
  String get bookStepPlace => 'Place';

  @override
  String get bookStepTech => 'Technician';

  @override
  String get bookStepTime => 'Time';

  @override
  String get bookWhatTitle => 'What needs fitting?';

  @override
  String get bookWhatHint => 'Describe the part, e.g. front right bulb';

  @override
  String get bookWhatJob => 'Type of job';

  @override
  String get bookWhatNote =>
      'Bought the part elsewhere? No problem: bring it along or have it ready for the technician.';

  @override
  String get bookPlaceTitle => 'Where should we fit it?';

  @override
  String get bookPlaceBay => 'At a workshop on Alghali Street';

  @override
  String get bookPlaceBayBody => 'No travel fee. You bring the car to the bay.';

  @override
  String get bookPlaceHome => 'At your place';

  @override
  String bookPlaceHomeBody(String amount) {
    return 'The technician comes to your home or work. Travel fee from $amount.';
  }

  @override
  String get bookAddress => 'Address';

  @override
  String get bookUseLocation => 'Use my current location';

  @override
  String get bookTechTitle => 'Choose a technician';

  @override
  String get bookAnyTech => 'First available technician';

  @override
  String get bookAnyTechBody => 'We pick the best technician who is free at the time you choose.';

  @override
  String bookAtBay(String shop) {
    return '$shop bay';
  }

  @override
  String bookAway(String distance) {
    return '$distance away';
  }

  @override
  String bookYears(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count years\' experience',
      one: '1 year\'s experience',
    );
    return '$_temp0';
  }

  @override
  String get bookNoTechs =>
      'No technician does this job at this place right now. Try the other place.';

  @override
  String get bookTimeTitle => 'Pick a time';

  @override
  String get bookEarliest =>
      'The earliest time is 2 hours from now, so the shop can prepare the part.';

  @override
  String get bookNoSlots => 'No times left on this day. Pick another day.';

  @override
  String get bookDayOff => 'Closed on this day.';

  @override
  String get bookReviewTitle => 'Review your booking';

  @override
  String get bookDuration => 'Expected duration';

  @override
  String bookCancelNote(int hours) {
    return 'Free cancellation up to $hours hours before.';
  }

  @override
  String get bookHold => 'Hold this time';

  @override
  String bookHoldNote(int minutes) {
    return 'We hold this time for $minutes minutes while you check out.';
  }

  @override
  String get bookConfirm => 'Confirm booking';

  @override
  String bookDepositNote(String amount) {
    return 'A $amount deposit is paid by Bankak to confirm the visit; the rest in cash.';
  }

  @override
  String get bookPickTime => 'Pick a time to continue';

  @override
  String get bookWhen => 'When';

  @override
  String get checkoutTitle => 'Checkout';

  @override
  String get checkoutReceive => 'How you get it';

  @override
  String checkoutPickupBody(String place) {
    return '$place — free';
  }

  @override
  String checkoutDeliveryTo(String address) {
    return 'To $address';
  }

  @override
  String get checkoutToTechBody => 'The shop hands the part to your technician before your time.';

  @override
  String get checkoutPayment => 'Payment method';

  @override
  String get checkoutBankak => 'Bankak transfer';

  @override
  String get checkoutBankakBody =>
      'Transfer, then upload the receipt. We confirm during working hours.';

  @override
  String get checkoutCash => 'Cash';

  @override
  String get checkoutCashBody => 'Pay at pickup, on delivery or to the technician.';

  @override
  String get checkoutPayWithin =>
      'Pay within 2 hours, or the order is cancelled automatically and the parts go back to the shop.';

  @override
  String get checkoutDueNow => 'Due now by Bankak';

  @override
  String get checkoutRestCash => 'Rest in cash';

  @override
  String get checkoutPlace => 'Place order';

  @override
  String get checkoutTerms =>
      'By placing the order you agree to the terms of use and the returns policy.';

  @override
  String get checkoutSignIn => 'Sign in to check out';

  @override
  String get bankakTitle => 'Pay with Bankak';

  @override
  String get bankakAmount => 'Transfer exactly';

  @override
  String get bankakStep1 => 'Open Bankak and transfer to this account';

  @override
  String get bankakAccountName => 'Account name';

  @override
  String get bankakAccountNumber => 'Account number';

  @override
  String get bankakSample => 'Sample account — don\'t transfer';

  @override
  String get bankakStep2 => 'Write the order number in the comment box';

  @override
  String get bankakRef => 'Order number';

  @override
  String get bankakStep3 => 'Upload the receipt or type the transaction number';

  @override
  String get bankakUpload => 'Upload receipt screenshot';

  @override
  String get bankakUploaded => 'Receipt screenshot attached';

  @override
  String get bankakTxn => 'Transaction number';

  @override
  String get bankakTxnHint => 'Shown on your Bankak receipt';

  @override
  String get bankakSubmit => 'Send for checking';

  @override
  String get bankakNeedProof => 'Upload the receipt or enter the transaction number.';

  @override
  String bankakTimeLeft(String time) {
    return 'Time left to pay: $time';
  }

  @override
  String get bankakChecking => 'We\'re checking your payment';

  @override
  String get bankakCheckingBody =>
      'We match your transfer with the bank statement, usually within 30 minutes between 8 AM and 10 PM. We\'ll notify you.';

  @override
  String get bankakNever =>
      'We never mark an order paid from a screenshot alone, only after matching it with the bank.';

  @override
  String get ordersTabOrders => 'Orders';

  @override
  String get ordersTabBookings => 'Bookings';

  @override
  String get ordersTabRequests => 'Photo requests';

  @override
  String get ordersEmpty => 'No orders yet';

  @override
  String get ordersEmptyBody => 'Your orders show up here after you buy.';

  @override
  String get bookingsEmpty => 'No bookings yet';

  @override
  String get bookingsEmptyBody =>
      'Book a technician to fit your part at a workshop or at your place.';

  @override
  String get requestsEmpty => 'No photo requests';

  @override
  String get requestsEmptyBody => 'Send a photo of the part and shops will send you offers.';

  @override
  String get ordersSignIn => 'Sign in to see your orders';

  @override
  String get ordersSignInBody => 'Track orders, bookings and shop offers in one place.';

  @override
  String orderRef(String ref) {
    return 'Order $ref';
  }

  @override
  String bookingRefTitle(String ref) {
    return 'Booking $ref';
  }

  @override
  String get orderTitle => 'Order details';

  @override
  String orderPlacedOn(String date) {
    return 'Placed $date';
  }

  @override
  String get orderPayNow => 'Pay now';

  @override
  String get orderAwaiting => 'Waiting for your transfer';

  @override
  String orderAwaitingBody(String amount, String time) {
    return 'Transfer $amount by Bankak before $time, or the order is cancelled.';
  }

  @override
  String orderPickupWhere(String place) {
    return 'Pickup: $place';
  }

  @override
  String get orderCancel => 'Cancel order';

  @override
  String get orderCancelConfirm => 'Cancel this order?';

  @override
  String get orderCancelBody =>
      'The parts go back to the shop and any fitting linked to this order is cancelled.';

  @override
  String get orderKeep => 'Keep order';

  @override
  String get orderReturn => 'Request a return';

  @override
  String orderReturnBody(int days) {
    return 'You can return it within $days days of receiving it.';
  }

  @override
  String get orderReturnSent => 'Return requested. The shop will contact you.';

  @override
  String get orderRateShop => 'Rate the shop';

  @override
  String get orderFitting => 'Fitting appointment';

  @override
  String get tlPlaced => 'Order placed';

  @override
  String get tlPaymentChecked => 'Payment confirmed';

  @override
  String get tlShopConfirmed => 'Shop confirmed';

  @override
  String get tlReady => 'Part ready';

  @override
  String get tlPickedUp => 'Picked up';

  @override
  String get tlOnTheWay => 'On the way to you';

  @override
  String get tlDelivered => 'Delivered';

  @override
  String get tlHanded => 'Handed to the technician';

  @override
  String get tlCompleted => 'Completed';

  @override
  String get tlBooked => 'Booked';

  @override
  String get tlTechAccepted => 'Technician accepted';

  @override
  String get tlEnRoute => 'Technician on the way';

  @override
  String get tlWorking => 'Working on it';

  @override
  String get tlJobDone => 'Job done';

  @override
  String get orderCancelled => 'This order was cancelled.';

  @override
  String get demoControls => 'Demo controls';

  @override
  String get demoNextStep => 'Simulate the next step';

  @override
  String get demoNextStepBody =>
      'Moves things along as if the admin, shop and technician did their part.';

  @override
  String get bookingTitle => 'Fitting appointment';

  @override
  String get bookingCode => 'Job code';

  @override
  String get bookingCodeBody =>
      'Give this code to the technician only when the job is done and you\'re happy with it.';

  @override
  String get bookingTech => 'Technician';

  @override
  String get bookingWhere => 'Place';

  @override
  String get bookingJob => 'Job';

  @override
  String bookingEnRoute(String name) {
    return '$name is on the way, about 15 minutes out.';
  }

  @override
  String bookingWaitingTech(int minutes) {
    return 'Waiting for the technician to accept, usually within $minutes minutes.';
  }

  @override
  String get bookingReschedule => 'Reschedule';

  @override
  String get bookingCancel => 'Cancel booking';

  @override
  String bookingCancelFree(String time) {
    return 'Free to cancel until $time.';
  }

  @override
  String get bookingCancelConfirm => 'Cancel this booking?';

  @override
  String get bookingKeep => 'Keep booking';

  @override
  String get bookingRate => 'Rate the technician';

  @override
  String get bookingRescheduleSoon => 'Pick a new time at the time step.';

  @override
  String get requestNewTitle => 'Request by photo';

  @override
  String get requestNewIntro =>
      'Take a photo of the old part or where it goes. Shops send you offers, usually within an hour.';

  @override
  String get requestAddPhoto => 'Add photo';

  @override
  String requestPhotos(int count) {
    return 'Photos ($count of 3)';
  }

  @override
  String get requestCar => 'Car';

  @override
  String get requestCategory => 'Category';

  @override
  String get requestNote => 'Describe the part';

  @override
  String get requestNoteHint => 'e.g. right rear door handle, chrome';

  @override
  String get requestSend => 'Send to shops';

  @override
  String get requestNeedPhoto => 'Add at least one photo.';

  @override
  String get requestTitle => 'Photo request';

  @override
  String requestOffers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count offers',
      one: '1 offer',
      zero: 'No offers yet',
    );
    return '$_temp0';
  }

  @override
  String get requestNoOffersBody =>
      'We\'ve told the shops that sell this. We\'ll notify you when an offer arrives.';

  @override
  String requestExpiresIn(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Expires in $count hours',
      one: 'Expires in 1 hour',
    );
    return '$_temp0';
  }

  @override
  String requestValidUntil(String time) {
    return 'Valid until $time';
  }

  @override
  String get requestClose => 'Close request';

  @override
  String get requestStatusOpen => 'Open';

  @override
  String get requestStatusClosed => 'Closed';

  @override
  String get requestStatusExpired => 'Expired';

  @override
  String get requestSent => 'Your request was sent to the shops.';

  @override
  String photoPlaceholder(int index) {
    return 'Photo $index';
  }

  @override
  String get chatHint => 'Write a message';

  @override
  String get chatVoice => 'Voice message';

  @override
  String get chatSend => 'Send';

  @override
  String get chatRecord => 'Record a voice message';

  @override
  String get chatVoiceSoon => 'Press and hold the mic to record, up to 60 seconds.';

  @override
  String get chatEmpty => 'Ask the shop about the part, the price or when it\'ll be ready.';

  @override
  String reviewTitle(String name) {
    return 'Rate $name';
  }

  @override
  String get reviewTags => 'What went well?';

  @override
  String get reviewTagGenuine => 'Genuine part';

  @override
  String get reviewTagFast => 'Quick';

  @override
  String get reviewTagPrice => 'Fair price';

  @override
  String get reviewTagPolite => 'Polite';

  @override
  String get reviewTagOnTime => 'On time';

  @override
  String get reviewComment => 'Add a comment (optional)';

  @override
  String get reviewSubmit => 'Submit review';

  @override
  String get reviewThanks => 'Thanks for your review';

  @override
  String get accountGuestTitle => 'Sign in to track your orders';

  @override
  String get accountGuestBody => 'Save your cars and track your orders and bookings.';

  @override
  String get accountSignIn => 'Sign in';

  @override
  String get accountSignUp => 'Create account';

  @override
  String get accountShopping => 'Shopping';

  @override
  String get accountSettings => 'App settings';

  @override
  String get accountSupport => 'Support';

  @override
  String get accountGarage => 'My garage';

  @override
  String get accountAddresses => 'My addresses';

  @override
  String get accountNotifications => 'Notifications';

  @override
  String get accountLanguage => 'Language';

  @override
  String get accountAppearance => 'Appearance';

  @override
  String get appearanceSystem => 'Same as phone';

  @override
  String get appearanceLight => 'Light';

  @override
  String get appearanceDark => 'Dark';

  @override
  String get accountDataSaver => 'Data saver';

  @override
  String get accountDataSaverBody => 'Small photos until you tap one';

  @override
  String get accountHelp => 'Help & support';

  @override
  String get accountTerms => 'Terms & privacy';

  @override
  String get accountTermsBody =>
      'The terms of use, privacy policy and returns policy will be published here before launch.';

  @override
  String get accountAbout => 'About';

  @override
  String accountVersion(String version) {
    return 'Version $version';
  }

  @override
  String get accountLicenses => 'Open-source licences';

  @override
  String get accountSignOut => 'Sign out';

  @override
  String get accountSignOutConfirm => 'Sign out?';

  @override
  String accountCars(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cars',
      one: '1 car',
      zero: 'No cars',
    );
    return '$_temp0';
  }

  @override
  String get garageTitle => 'My garage';

  @override
  String get garageEmpty => 'No cars yet';

  @override
  String get garageEmptyBody => 'Add your car and we\'ll show only parts that fit.';

  @override
  String get garageAdd => 'Add a car';

  @override
  String get garageSelected => 'Selected';

  @override
  String get garageUse => 'Select';

  @override
  String get garageRemove => 'Remove car';

  @override
  String garageRemoveConfirm(String car) {
    return 'Remove $car from your garage?';
  }

  @override
  String get addCarTitle => 'Add a car';

  @override
  String get addCarMake => 'Choose the make';

  @override
  String get addCarModel => 'Choose the model';

  @override
  String get addCarYear => 'Choose the year and engine';

  @override
  String addCarSaved(String car) {
    return '$car added';
  }

  @override
  String get signInTitle => 'Sign in';

  @override
  String get signInSubtitle => 'Welcome back';

  @override
  String get fieldEmail => 'Email';

  @override
  String get fieldPassword => 'Password';

  @override
  String get showPassword => 'Show password';

  @override
  String get hidePassword => 'Hide password';

  @override
  String get signInForgot => 'Forgot password?';

  @override
  String get signInForgotSent => 'We\'ll email you a reset link once email sending is switched on.';

  @override
  String get signInSubmit => 'Sign in';

  @override
  String get signInNoAccount => 'New here?';

  @override
  String get signInCreate => 'Create an account';

  @override
  String get signInDemoHint =>
      'In the demo, any valid email works with an 8+ character password that includes a number.';

  @override
  String get signUpTitle => 'Create account';

  @override
  String get fieldName => 'Name';

  @override
  String get fieldPhone => 'Phone number';

  @override
  String get fieldPhoneHelp => 'Shops and technicians call you on this number.';

  @override
  String get signUpSubmit => 'Create account';

  @override
  String get signUpHaveAccount => 'Have an account?';

  @override
  String get signUpTerms => 'By creating an account you agree to the terms and privacy policy.';

  @override
  String signInWelcome(String name) {
    return 'Welcome, $name';
  }

  @override
  String get continueAsGuest => 'Browse without an account';

  @override
  String get shopClosedDay => 'Closed';

  @override
  String get priceOnRequest => 'Price on request';

  @override
  String get homeCatalogueLoading =>
      'Loading categories and shops… the first time needs a connection.';

  @override
  String get updateAvailable => 'A new version of the app is available.';

  @override
  String get updateRequired => 'This version is too old. Download the new one to keep buying.';

  @override
  String get updateDownload => 'Download';

  @override
  String get partUnverified => 'Added by the shop; our team hasn\'t checked it yet.';

  @override
  String get partNoOffers => 'No shop sells this part right now.';

  @override
  String get partFittingBodyLive =>
      'Book a vetted technician to fit it at a workshop on the street or at your place. Add it to the cart, then choose \"Add fitting\".';

  @override
  String get partAskPrice => 'Ask the price';

  @override
  String get partAskStock => 'Ask the shop';

  @override
  String get partOutOfStock => 'Out of stock';

  @override
  String get shopDirections => 'Directions';

  @override
  String get shopNoParts => 'No parts listed yet.';

  @override
  String get cartFittingDropped =>
      'The fitting was dropped because that part was removed. Add it again if you need it.';

  @override
  String get cartInFitting => 'Included in the booked fitting';

  @override
  String get cartAddToFitting => 'Add to the fitting';

  @override
  String get bookTooFar => 'Too far';

  @override
  String get bookNoTechsBody =>
      'No technician is free for this job there in the coming days. Try a workshop on the street or another address.';

  @override
  String get bookNoFreeTime => 'No free times in the coming days';

  @override
  String bookNextFree(String when) {
    return 'Next free: $when';
  }

  @override
  String get addressNew => 'New address';

  @override
  String get addressNewBody =>
      'Stand at the place, use your current location, then add directions for the technician or courier.';

  @override
  String get addressLocated => 'Location found';

  @override
  String addressFromStreet(String distance) {
    return '$distance from the street';
  }

  @override
  String get addressLocateAgain => 'Locate again';

  @override
  String get addressHome => 'Home';

  @override
  String get addressWork => 'Work';

  @override
  String get addressLabel => 'Name of the place';

  @override
  String get addressDirections => 'Directions';

  @override
  String get addressDirectionsHint => 'e.g. district, street, house number, a nearby landmark';

  @override
  String get addressSave => 'Save address';

  @override
  String get profileTitle => 'My details';

  @override
  String get profileSave => 'Save';

  @override
  String get checkoutAddAddress => 'Add an address for delivery';

  @override
  String checkoutPayWithinMinutes(int minutes) {
    return 'Transfer within $minutes minutes, or the order is cancelled automatically.';
  }

  @override
  String get bankakRejected => 'We could not accept the receipt';

  @override
  String bankakRejectedBody(String reason) {
    return '$reason Send it again before the time runs out.';
  }

  @override
  String get bankakDepositAmount => 'Transfer exactly this deposit';

  @override
  String get rejectAmount => 'The amount transferred doesn\'t match.';

  @override
  String get rejectNotFound => 'We couldn\'t find the transfer on the statement.';

  @override
  String get rejectDuplicate => 'This receipt was used for another order.';

  @override
  String get rejectUnreadable => 'The receipt is not readable.';

  @override
  String get rejectOther => 'Check the transfer details.';

  @override
  String get orderRefunds => 'Refunds';

  @override
  String get refundSent => 'Sent to you';

  @override
  String get refundPending => 'Being sent';

  @override
  String get refundBody => 'Refunds go by Bankak to the account saved in \"Account\".';

  @override
  String get orderReturnReason => 'Why are you returning it?';

  @override
  String get orderReturnSend => 'Send return request';

  @override
  String get returnRequested => 'Return asked — waiting for our team';

  @override
  String get returnApproved => 'Return approved';

  @override
  String get returnDeclined => 'Return declined';

  @override
  String get orderGotIt => 'I got it';

  @override
  String orderBookFitting(String part) {
    return 'Book fitting: $part';
  }

  @override
  String get complaintReport => 'Report a problem';

  @override
  String get complaintIntro =>
      'Pick what went wrong and tell us what happened. Our team usually replies within a working day.';

  @override
  String get complaintDescribe => 'What happened?';

  @override
  String get complaintSend => 'Send';

  @override
  String get complaintNotReceived => 'I didn\'t get the part';

  @override
  String get complaintWrongPart => 'Wrong part';

  @override
  String get complaintDamaged => 'Damaged or doesn\'t work';

  @override
  String get complaintNotFitted => 'The fitting wasn\'t done right';

  @override
  String get complaintPayment => 'Payment problem';

  @override
  String get complaintBehaviour => 'Bad behaviour';

  @override
  String get complaintOther => 'Something else';

  @override
  String get complaintOpen => 'Open';

  @override
  String get complaintInReview => 'Being reviewed';

  @override
  String get complaintResolved => 'Resolved';

  @override
  String get complaintRejected => 'Closed';

  @override
  String get complaintsTitle => 'My complaints';

  @override
  String get complaintsEmpty => 'No complaints';

  @override
  String get complaintsEmptyBody =>
      'If something goes wrong with an order or a fitting, open it and choose \"Report a problem\".';

  @override
  String get complaintTitle => 'Complaint';

  @override
  String get complaintOutcome => 'Outcome';

  @override
  String get complaintYou => 'You';

  @override
  String get complaintTeam => 'Alghali Street team';

  @override
  String get complaintReply => 'Write a reply';

  @override
  String get bookingPayFirst => 'Pay for the order so the booking goes to the technician.';

  @override
  String get bookingNeedsTime =>
      'No technician could take this time. Pick a new time, or cancel for a full refund.';

  @override
  String get bookingPickNewTime => 'Pick a new time';

  @override
  String get bookingNotFit =>
      'The part turned out not to fit. You pay the travel fee only, and we opened a return for the part.';

  @override
  String get bookingCancelledBody => 'This booking was cancelled.';

  @override
  String get bookingCodeLocked =>
      'The code was entered wrong too many times. Our team will close the job after checking.';

  @override
  String get bookingLiveTitle => 'Your technician is on the way';

  @override
  String bookingLiveAway(String distance) {
    return 'About $distance away';
  }

  @override
  String bookingLiveUpdated(String ago) {
    return 'Updated $ago';
  }

  @override
  String get bookingLiveWaiting => 'Waiting for the technician\'s first location…';

  @override
  String get bookingLiveMap => 'See on the map';

  @override
  String get bookingPhotos => 'Job photos';

  @override
  String get bookingPhotoBefore => 'Before';

  @override
  String get bookingPhotoAfter => 'After';

  @override
  String bookingCancelLate(String when) {
    return 'After $when, the booking fee and travel fee are kept and the labour is refunded.';
  }

  @override
  String get bookingCancelLateNow =>
      'Free cancellation has passed: the booking fee and travel fee are kept, and the labour is refunded.';

  @override
  String get bookingRescheduled => 'Time changed';

  @override
  String bookingWaitingTechUntil(String time) {
    return 'We sent it to the technician and are waiting for them to accept by $time. If they don\'t, it goes to another free technician.';
  }

  @override
  String get requestOfferClosed => 'Offer closed';

  @override
  String get chatSignIn => 'Sign in to message the shop';

  @override
  String get chatsTitle => 'Messages';

  @override
  String get chatsEmpty => 'No messages yet';

  @override
  String get chatsEmptyBody => 'Open any shop and tap \"Chat\" to ask about a part.';

  @override
  String get chatVoiceNote => 'Voice note';

  @override
  String get notificationsGeneric => 'New update';

  @override
  String get accountRefundAccount => 'Refund account';

  @override
  String get accountRefundAccountLabel => 'Your Bankak account number';

  @override
  String get accountRefundAccountHint => 'We send any refund here';

  @override
  String get accountSaved => 'Saved';

  @override
  String get accountHelpBody =>
      'Contact the Alghali Street team about any order, payment or fitting.';

  @override
  String get accountHelpSoon =>
      'Support numbers are coming soon. Use \"Report a problem\" on the order or booking.';

  @override
  String get accountNoPhone => 'Add your phone number';

  @override
  String accountPending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count changes waiting for a connection',
      one: '1 change waiting for a connection',
    );
    return '$_temp0';
  }

  @override
  String accountSignOutPending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count changes haven\'t been sent yet and will be lost.',
      one: '1 change hasn\'t been sent yet and will be lost.',
    );
    return '$_temp0';
  }

  @override
  String get addressesEmpty => 'No saved addresses';
}
