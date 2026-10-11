// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Alghali Partners';

  @override
  String get welcomeTitle => 'Run your shop and jobs from your phone';

  @override
  String get welcomePointOrders => 'Receive and prepare orders fast';

  @override
  String get welcomePointStock => 'Update prices and stock in seconds';

  @override
  String get welcomePointJobs => 'Get fitting jobs and track your earnings';

  @override
  String get signInTitle => 'Partner sign in';

  @override
  String get signInSubtitle => 'For shops and technicians on Alghali Street';

  @override
  String get fieldEmail => 'Email';

  @override
  String get fieldPassword => 'Password';

  @override
  String get showPassword => 'Show password';

  @override
  String get hidePassword => 'Hide password';

  @override
  String get signInSubmit => 'Sign in';

  @override
  String get signInForgot => 'Forgot password?';

  @override
  String get signInForgotSent => 'We\'ll email you a reset link once email sending is switched on.';

  @override
  String get signInDemoHint =>
      'In the demo, any valid email works with an 8+ character password that includes a number.';

  @override
  String get signInApply => 'New shop or technician? Apply to join';

  @override
  String get applySoon => 'Applying in the app opens soon. Contact the platform team for now.';

  @override
  String get roleTitle => 'How do you want to continue?';

  @override
  String get roleBody => 'Your account has a shop and an installation technician profile.';

  @override
  String get roleShop => 'Shop owner';

  @override
  String get roleTechnician => 'Installation technician';

  @override
  String get roleSwitch => 'Switch role';

  @override
  String get shopNavHome => 'Home';

  @override
  String get shopNavOrders => 'Orders';

  @override
  String get shopNavStock => 'Stock';

  @override
  String get shopNavQuotes => 'Quotes';

  @override
  String get shopNavMore => 'More';

  @override
  String hello(String name) {
    return 'Hello, $name';
  }

  @override
  String get shopIsOpen => 'Shop is open for orders';

  @override
  String get shopIsClosed => 'Shop is closed — buyers won\'t see your parts';

  @override
  String get kpiNewOrders => 'New orders';

  @override
  String get kpiToPrepare => 'To prepare';

  @override
  String get kpiCashToCollect => 'Cash to collect';

  @override
  String get kpiTodaySales => 'Today\'s sales';

  @override
  String get needsAction => 'Needs action';

  @override
  String ackWithin(int minutes) {
    return 'Accept within $minutes min';
  }

  @override
  String get ackLate => 'Late to accept — the admin was alerted';

  @override
  String get quickAddPart => 'Add a part';

  @override
  String get quickUpdatePrices => 'Update prices';

  @override
  String get quickQuotes => 'Price requests';

  @override
  String get lowStock => 'Low stock';

  @override
  String lowStockBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items are running low',
      one: '1 item is running low',
    );
    return '$_temp0';
  }

  @override
  String get allCaughtUp => 'Nothing waiting for you right now';

  @override
  String get tabNew => 'New';

  @override
  String get tabPreparing => 'Preparing';

  @override
  String get tabReady => 'Ready';

  @override
  String get tabDone => 'Done';

  @override
  String get ordersEmpty => 'No orders here';

  @override
  String orderRef(String ref) {
    return 'Order $ref';
  }

  @override
  String orderFrom(String buyer) {
    return 'From $buyer';
  }

  @override
  String get orderAwaitingPayment => 'Waiting for the buyer\'s payment — don\'t prepare yet';

  @override
  String toTechWith(String name, String time) {
    return 'To technician $name · $time';
  }

  @override
  String get orderAccept => 'Accept order';

  @override
  String get orderReject => 'Decline';

  @override
  String get rejectTitle => 'Why are you declining?';

  @override
  String get rejectOutOfStock => 'Out of stock';

  @override
  String get rejectPrice => 'Price changed';

  @override
  String get rejectOther => 'Other reason';

  @override
  String get rejectNote => 'The buyer is refunded, and declines affect your shop rating.';

  @override
  String get markReady => 'Part is ready';

  @override
  String get handToBuyer => 'Handed to buyer';

  @override
  String get handToTech => 'Handed to technician';

  @override
  String get outForDelivery => 'Out for delivery';

  @override
  String get markDelivered => 'Delivered';

  @override
  String collectCash(String amount) {
    return 'Collect $amount in cash at handover';
  }

  @override
  String cashFromTech(String amount) {
    return 'The technician pays you $amount in cash for the part';
  }

  @override
  String get paidBankak => 'Paid by Bankak — you\'ll get it in the next payout';

  @override
  String get sectionBuyer => 'Buyer';

  @override
  String get sectionItems => 'Items';

  @override
  String get sectionHandover => 'Handover';

  @override
  String get sectionMoney => 'Money';

  @override
  String commission(int percent) {
    return 'Platform commission ($percent%)';
  }

  @override
  String get youReceive => 'You receive';

  @override
  String receivedAgo(String ago) {
    return 'Received $ago';
  }

  @override
  String get stockSearch => 'Search your parts';

  @override
  String get filterAll => 'All';

  @override
  String get filterLow => 'Low';

  @override
  String get filterOut => 'Out';

  @override
  String get filterHidden => 'Hidden';

  @override
  String qty(int count) {
    return 'Qty: $count';
  }

  @override
  String get hiddenFromBuyers => 'Hidden from buyers';

  @override
  String get editListing => 'Edit price and stock';

  @override
  String get priceField => 'Price (SDG)';

  @override
  String get qtyField => 'Quantity';

  @override
  String get visibleToBuyers => 'Visible to buyers';

  @override
  String get saved => 'Saved';

  @override
  String get bulkEdit => 'Bulk edit';

  @override
  String selectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count selected',
      one: '1 selected',
    );
    return '$_temp0';
  }

  @override
  String get bulkPriceBy => 'Change prices by';

  @override
  String get bulkApply => 'Apply';

  @override
  String bulkDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Updated $count prices',
      one: 'Updated 1 price',
    );
    return '$_temp0';
  }

  @override
  String get importExcel => 'Import from Excel';

  @override
  String get importBody =>
      'Download the template, fill it in, then upload it to update hundreds of parts at once.';

  @override
  String get downloadTemplate => 'Download template';

  @override
  String get uploadFile => 'Upload file';

  @override
  String get priceLockNote => 'Confirmed orders keep their old price.';

  @override
  String get addTitle => 'Add a part';

  @override
  String get stepPhoto => 'Photo';

  @override
  String get stepPart => 'Part';

  @override
  String get stepCars => 'Cars';

  @override
  String get stepPrice => 'Price';

  @override
  String get photoTitle => 'Photograph the part';

  @override
  String get photoBody =>
      'A clear photo on a light background sells more. We shrink it automatically to save data.';

  @override
  String get takePhoto => 'Take photo';

  @override
  String get photoAdded => 'Photo added';

  @override
  String get categoryTitle => 'What is the part?';

  @override
  String get partName => 'Part name';

  @override
  String get partNameHint => 'e.g. H4 halogen bulb';

  @override
  String get carsTitle => 'Which cars does it fit?';

  @override
  String get carsUnknown => 'Not sure — buyers will be asked to check';

  @override
  String get conditionLabel => 'Condition';

  @override
  String get warrantyLabel => 'Warranty';

  @override
  String get publish => 'Publish';

  @override
  String get saveDraft => 'Save draft';

  @override
  String get draftOffline => 'Drafts are kept on your phone and sent when you\'re back online.';

  @override
  String get published => 'Part published';

  @override
  String get draftSaved => 'Draft saved';

  @override
  String get draft => 'Draft';

  @override
  String get quotesBody =>
      'Buyers sent photos of parts they need. Send your offer before the request expires.';

  @override
  String get quotesEmpty => 'No price requests right now';

  @override
  String expiresIn(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Expires in $count hours',
      one: 'Expires in 1 hour',
    );
    return '$_temp0';
  }

  @override
  String otherOffers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count offers from other shops',
      one: '1 offer from another shop',
      zero: 'No offers yet — be the first',
    );
    return '$_temp0';
  }

  @override
  String get makeOffer => 'Send an offer';

  @override
  String get offerSent => 'Offer sent';

  @override
  String yourOffer(String amount) {
    return 'Your offer: $amount';
  }

  @override
  String get offerTitle => 'Price offer';

  @override
  String get offerPart => 'Part description';

  @override
  String get offerNote => 'Note to the buyer (optional)';

  @override
  String get moreMoney => 'Money & payouts';

  @override
  String get moreStaff => 'Staff';

  @override
  String get moreInsights => 'Insights';

  @override
  String get moreProfile => 'Shop profile';

  @override
  String get moreLanguage => 'Language';

  @override
  String get moreAppearance => 'Appearance';

  @override
  String get appearanceSystem => 'Same as phone';

  @override
  String get appearanceLight => 'Light';

  @override
  String get appearanceDark => 'Dark';

  @override
  String get moreHelp => 'Help';

  @override
  String get signOut => 'Sign out';

  @override
  String get signOutConfirm => 'Sign out?';

  @override
  String get moneyOwedToYou => 'The platform owes you';

  @override
  String get moneyYouOwe => 'You owe the platform';

  @override
  String nextPayout(String date) {
    return 'Next payout: $date by Bankak';
  }

  @override
  String commissionNote(int percent) {
    return 'Commission is $percent% on parts only, netted from your payout.';
  }

  @override
  String get statement => 'Statement';

  @override
  String get payouts => 'Payouts';

  @override
  String get ledgerSale => 'Sale';

  @override
  String get ledgerCommission => 'Commission';

  @override
  String get ledgerLabour => 'Labour';

  @override
  String get ledgerTravel => 'Travel fee';

  @override
  String get ledgerBookingFee => 'Booking fee';

  @override
  String get ledgerCash => 'Cash collected';

  @override
  String get ledgerHandover => 'Cash handover';

  @override
  String get ledgerPayout => 'Payout';

  @override
  String get ledgerRefund => 'Refund';

  @override
  String get payoutPaid => 'Paid';

  @override
  String get payoutApproved => 'Approved';

  @override
  String get payoutDraft => 'Being prepared';

  @override
  String get staffOwner => 'Owner';

  @override
  String get staffMember => 'Staff';

  @override
  String get staffInvite => 'Invite staff';

  @override
  String get staffInviteBody => 'Staff can manage orders and stock only, without access to money.';

  @override
  String get staffInviteSent => 'Invite sent';

  @override
  String lastActive(String ago) {
    return 'Last active $ago';
  }

  @override
  String get insightsSales7 => 'Sales, last 7 days';

  @override
  String get insightsOrders => 'Orders';

  @override
  String get insightsAvgOrder => 'Average order';

  @override
  String get insightsRating => 'Rating';

  @override
  String get insightsTop => 'Best sellers';

  @override
  String get showTable => 'Show as table';

  @override
  String get showChart => 'Show as chart';

  @override
  String get colDay => 'Day';

  @override
  String get colSales => 'Sales';

  @override
  String get colOrders => 'Orders';

  @override
  String soldCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Sold $count times',
      one: 'Sold once',
    );
    return '$_temp0';
  }

  @override
  String get techNavJobs => 'Jobs';

  @override
  String get techNavSchedule => 'Schedule';

  @override
  String get techNavEarnings => 'Earnings';

  @override
  String get techNavProfile => 'Profile';

  @override
  String get techOnline => 'Accepting jobs';

  @override
  String get techOffline => 'Not available — no new offers';

  @override
  String get newOffers => 'New offers';

  @override
  String get todayJobs => 'Today\'s jobs';

  @override
  String get upcomingJobs => 'Upcoming';

  @override
  String get noJobsToday => 'No jobs today yet';

  @override
  String get noJobsTodayBody => 'Stay available and keep your schedule up to date to get offers.';

  @override
  String respondIn(String time) {
    return 'Respond within $time';
  }

  @override
  String get accept => 'Accept';

  @override
  String get decline => 'Decline';

  @override
  String get declineBody => 'The job goes to another technician at the same time.';

  @override
  String get jobAccepted => 'Job accepted';

  @override
  String get offerExpired => 'Offer expired';

  @override
  String youEarn(String amount) {
    return 'You earn $amount';
  }

  @override
  String get atYourBay => 'At your bay';

  @override
  String atCustomer(String distance) {
    return 'At the customer · $distance';
  }

  @override
  String partReadyAt(String shop) {
    return 'Part ready at $shop';
  }

  @override
  String partPendingAt(String shop) {
    return 'Part being prepared at $shop';
  }

  @override
  String get partWithCustomer => 'Customer has the part';

  @override
  String get jobTitle => 'Job details';

  @override
  String get jobCustomer => 'Customer';

  @override
  String get jobCar => 'Car';

  @override
  String get jobWork => 'Work';

  @override
  String get jobWhere => 'Location';

  @override
  String get jobPay => 'Pay';

  @override
  String get onMyWay => 'I\'m on my way';

  @override
  String get checkIn => 'I\'ve arrived — start';

  @override
  String get photosBefore => 'Before photos';

  @override
  String get photosAfter => 'After photos';

  @override
  String get addPhoto => 'Add photo';

  @override
  String get enterCode => 'Enter the customer\'s code to finish';

  @override
  String get codeHint =>
      'Ask the customer for their 4-digit code once they\'re happy with the work.';

  @override
  String codeWrong(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Wrong code. $count attempts left.',
      one: 'Wrong code. 1 attempt left.',
      zero: 'Wrong code. Finishing is locked and the admin was alerted.',
    );
    return '$_temp0';
  }

  @override
  String get finishJob => 'Finish job';

  @override
  String get jobDone => 'Job done — your pay was added to earnings';

  @override
  String get partNotFit => 'Part doesn\'t fit';

  @override
  String get partNotFitBody =>
      'The customer pays the travel fee only, and a return opens for the part.';

  @override
  String collectFromCustomer(String amount) {
    return 'Collect $amount in cash from the customer';
  }

  @override
  String handCashToShop(String amount) {
    return 'Hand $amount to the shop for the part';
  }

  @override
  String pickUpPart(String shop) {
    return 'Pick up the part from $shop before the job';
  }

  @override
  String get needAfterPhoto => 'Add at least one after photo.';

  @override
  String get weeklyHours => 'Weekly hours';

  @override
  String get dayOff => 'Day off';

  @override
  String get quickBlock => 'Quick block';

  @override
  String get quickBlockBody => 'Something came up? Pause new jobs without changing your schedule.';

  @override
  String get block1h => '1 hour';

  @override
  String get block2h => '2 hours';

  @override
  String get blockDay => 'Rest of today';

  @override
  String blockedUntil(String time) {
    return 'No jobs until $time';
  }

  @override
  String get unblock => 'Resume';

  @override
  String get timeOff => 'Time off';

  @override
  String get addTimeOff => 'Add time off';

  @override
  String get noTimeOff => 'No upcoming time off';

  @override
  String get timeOffAdded => 'Added a full day off tomorrow';

  @override
  String get earningsWeek => 'This week\'s earnings';

  @override
  String jobsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count jobs',
      one: '1 job',
      zero: 'No jobs',
    );
    return '$_temp0';
  }

  @override
  String get cashWithYou => 'Cash with you';

  @override
  String get cashWithYouBody => 'Collected from customers; netted from your payout.';

  @override
  String get recentActivity => 'Recent activity';

  @override
  String get skillsAndPrices => 'Jobs and your prices';

  @override
  String get howYouWork => 'How you work';

  @override
  String maxDistance(int km) {
    return 'Max distance for visits: $km km';
  }

  @override
  String yourBay(String shop) {
    return 'Your bay: $shop';
  }

  @override
  String labourFor(String job) {
    return '$job labour';
  }

  @override
  String get demoControls => 'Demo controls';

  @override
  String get demoNewOrder => 'Simulate a new order';

  @override
  String get demoNewOffer => 'Simulate a new job offer';

  @override
  String get demoNewQuote => 'Simulate a new price request';
}
