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
  String get signInForgotSent =>
      'If this email has an account, a link to reset the password is on its way.';

  @override
  String get signInApply => 'New shop or technician? Create an account';

  @override
  String get roleTitle => 'How do you want to continue?';

  @override
  String get roleBody =>
      'Choose which of your work to open. You can switch any time from the menu.';

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
  String get timeOffAdded => 'Time off added';

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
  String get forgotSend => 'Send link';

  @override
  String get signUpTitle => 'New partner account';

  @override
  String get signUpBody =>
      'For shop owners, their staff and installation technicians. Next you choose how you work with us.';

  @override
  String get fieldName => 'Full name';

  @override
  String get fieldPhone => 'Mobile number';

  @override
  String get fieldWhatsapp => 'WhatsApp number (optional)';

  @override
  String get signUpSubmit => 'Create account';

  @override
  String get signUpHaveAccount => 'Already have an account? Sign in';

  @override
  String get roleShopStaff => 'Shop staff';

  @override
  String get applyAddShop => 'Add a shop';

  @override
  String get applyAsTechnician => 'Apply as an installation technician';

  @override
  String get statusPending => 'Under review';

  @override
  String get statusApproved => 'Approved';

  @override
  String get statusRejected => 'Not approved';

  @override
  String get statusSuspended => 'Suspended';

  @override
  String get statusRejectedBody =>
      'Your application wasn\'t approved. Contact the platform team to find out what\'s needed.';

  @override
  String get statusSuspendedBody =>
      'The account is suspended and hidden from buyers. Contact the platform team.';

  @override
  String statusReason(String reason) {
    return 'Reason: $reason';
  }

  @override
  String get shopPendingBody =>
      'Your shop is being reviewed. Add your parts and prices now; buyers see them once it is approved.';

  @override
  String get techPendingBody =>
      'Your application is being reviewed. Job offers come once you\'re approved; set your hours and prices now.';

  @override
  String get applyTitle => 'Join Alghali Street';

  @override
  String applyHello(String name) {
    return 'Welcome, $name';
  }

  @override
  String get applyBody =>
      'How will you work with us? The platform team usually reviews applications within a working day.';

  @override
  String get applyShopTitle => 'I have a shop on the street';

  @override
  String get applyShopBody => 'List your parts, get orders and price requests.';

  @override
  String get applyTechTitle => 'I\'m an installation technician';

  @override
  String get applyTechBody =>
      'Get fitting jobs at a bay on the street or at the customer\'s place.';

  @override
  String get applyStaffNote =>
      'Working at a shop that is already here? Don\'t apply: ask the owner to add you with this email.';

  @override
  String get applyShopNote =>
      'The shop\'s name and place on the street show to buyers once approved.';

  @override
  String get applySectionShop => 'The shop';

  @override
  String get applySectionPlace => 'Place on the street';

  @override
  String get applySectionContact => 'Contact';

  @override
  String get applySubmit => 'Send application';

  @override
  String get applySent => 'Application sent for review';

  @override
  String get shopNameAr => 'Shop name in Arabic';

  @override
  String get shopNameEn => 'Shop name in English (optional)';

  @override
  String get shopZone => 'Zone';

  @override
  String get shopPlot => 'Plot number';

  @override
  String get shopSideA => 'Side A';

  @override
  String get shopSideB => 'Side B';

  @override
  String get shopLandmark => 'Landmark';

  @override
  String get shopLandmarkHint => 'e.g. opposite the petrol station';

  @override
  String get shopAbout => 'About the shop (optional)';

  @override
  String get shopHours => 'Opening hours';

  @override
  String get shopSells => 'What do you sell?';

  @override
  String get shopMakes => 'Car makes you serve';

  @override
  String get shopMakesBody => 'Leave empty if you serve every make.';

  @override
  String get applyTechNote => 'The team checks your experience before your first job offer.';

  @override
  String get techApplyBay => 'The bay you work at';

  @override
  String get techApplyBayHelp =>
      'A shop or workshop on the street where customers come for fittings';

  @override
  String get techApplyHome => 'Use my current location as my starting point';

  @override
  String get techApplyHomeSet => 'Location set';

  @override
  String get techApplyHomeBody => 'Visit distances are measured from here; customers never see it.';

  @override
  String get techApplyJobsBody =>
      'Enter your labour price for each kind of job you do; leave the others empty.';

  @override
  String get techApplyMakes => 'Car makes you work on';

  @override
  String get techApplyMakesBody => 'Leave empty if you work on every make.';

  @override
  String get techApplyYears => 'Years of experience';

  @override
  String get techApplyBio => 'About you (optional)';

  @override
  String get techApplyNeedJob => 'Choose at least one kind of job with its price.';

  @override
  String get techApplyNeedBay => 'Choose the bay where you work.';

  @override
  String get techApplyNeedHome => 'Set your starting point for visits.';

  @override
  String get homeUpdate => 'Update my starting point';

  @override
  String get addJobType => 'Add a kind of job';

  @override
  String get chatsTitle => 'Messages';

  @override
  String get notificationsTitle => 'Alerts';

  @override
  String get shopClosedToday => 'Closed today — buyers see the shop as closed';

  @override
  String get shopOutsideHours => 'Outside opening hours now';

  @override
  String get orderAccepted => 'Order accepted';

  @override
  String get orderRejected => 'Order declined; the buyer gets the money back';

  @override
  String get orderMarkedReady => 'Marked ready';

  @override
  String get orderHandedOver => 'Handed over';

  @override
  String get orderDelivered => 'Delivered';

  @override
  String get orderNotHere => 'This order isn\'t in your shop';

  @override
  String returnRequested(String reason) {
    return 'The buyer asked to return it: $reason';
  }

  @override
  String get waitTechAccept => 'Hand the part over once the technician accepts the job.';

  @override
  String get callTechnician => 'Call the technician';

  @override
  String get cashCollected => 'You collected the cash';

  @override
  String get rejectOtherLabel => 'Write the reason for the buyer';

  @override
  String get openOrder => 'Open the order';

  @override
  String get chatsEmpty => 'No messages yet';

  @override
  String get chatsEmptyBody => 'When a buyer messages you, the chat shows here.';

  @override
  String get chatEmpty => 'Start the conversation';

  @override
  String get chatHint => 'Write a message';

  @override
  String get chatSend => 'Send';

  @override
  String get chatVoiceNote => 'Voice note';

  @override
  String get notificationsEmpty => 'No alerts';

  @override
  String get notificationsEmptyBody => 'New orders, job offers and messages show here.';

  @override
  String get notificationsGeneric => 'Alert';

  @override
  String get notificationsMarkRead => 'Mark all read';

  @override
  String get helpBody => 'The platform team helps with orders, payments and your account.';

  @override
  String get stockEmpty => 'No parts yet';

  @override
  String get stockEmptyBody => 'Add a part with a photo, or import an Excel file.';

  @override
  String get stockNoMatch => 'No parts match';

  @override
  String reservedQty(int count) {
    return '$count reserved';
  }

  @override
  String reservedNote(int count) {
    return '$count held for open orders';
  }

  @override
  String get priceOnRequest => 'Price on request';

  @override
  String get archive => 'Remove from the shop';

  @override
  String get archiveTitle => 'Remove this part?';

  @override
  String get archiveBody => 'Buyers won\'t see it any more. Confirmed orders aren\'t affected.';

  @override
  String get listingQueued =>
      'This part is waiting for a connection to be sent. Edit it once it\'s in the list.';

  @override
  String get listingSavedOffline => 'Saved; it\'ll be sent when you\'re back online';

  @override
  String get retakePhoto => 'Take another';

  @override
  String get noPhoto => 'No photo for now';

  @override
  String get fromCatalogue => 'From the parts catalogue';

  @override
  String get suggestionsTitle => 'Did you mean?';

  @override
  String get carsFromCatalogue => 'The cars this part fits are set in the catalogue.';

  @override
  String get importCheckTitle => 'File check';

  @override
  String importCheckBody(int created, int updated, int failed) {
    return '$created to add, $updated to update, $failed rows with problems.';
  }

  @override
  String importRow(int row) {
    return 'Row $row';
  }

  @override
  String importGo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Import $count rows',
      one: 'Import 1 row',
    );
    return '$_temp0';
  }

  @override
  String importDone(int created, int updated, int failed) {
    return 'Added $created, updated $updated, skipped $failed';
  }

  @override
  String get importErrName => 'Part name missing';

  @override
  String get importErrCategory => 'Category missing or unknown';

  @override
  String get importErrCondition => 'Condition missing or wrong';

  @override
  String get importErrPrice => 'Price missing or wrong';

  @override
  String get importErrQty => 'Quantity is wrong';

  @override
  String get importErrWarranty => 'Warranty is wrong';

  @override
  String get importErrSku => 'Code used twice';

  @override
  String get importErrReserved => 'Less than open orders have reserved';

  @override
  String get importErrValue => 'A value is wrong';

  @override
  String get importWarnModel => 'Unknown car (left out):';

  @override
  String get changeOffer => 'Change';

  @override
  String get statementEmpty => 'Nothing in the last 30 days';

  @override
  String staffAdded(String date) {
    return 'Added $date';
  }

  @override
  String staffRemoveTitle(String name) {
    return 'Remove $name?';
  }

  @override
  String get staffRemoveBody =>
      'They won\'t be able to manage the shop\'s orders and stock any more.';

  @override
  String get insightsNoSales => 'No sales in these days yet';

  @override
  String get profileNameNote =>
      'To change the name or place on the street, contact the platform team.';

  @override
  String get atCustomerPlace => 'At the customer\'s place';

  @override
  String jobAndMore(String first, int count) {
    return '$first + $count more';
  }

  @override
  String jobRef(String ref) {
    return 'Job $ref';
  }

  @override
  String get onMyWayDone => 'The customer can see your position until you arrive';

  @override
  String get checkedIn => 'Job started';

  @override
  String get sharingLocation => 'Your position is shared with the customer while on the way.';

  @override
  String partCollected(String shop) {
    return 'Collected from $shop';
  }

  @override
  String get partNotFitReason => 'What\'s wrong?';

  @override
  String get partNotFitDone => 'Recorded; a return was opened for the part';

  @override
  String get dropJob => 'I can\'t make it';

  @override
  String get dropJobReason => 'Reason';

  @override
  String get dropJobBody =>
      'The job goes to another technician at the same time. Dropping jobs often affects your rating.';

  @override
  String get dropJobDone => 'The job was passed on';

  @override
  String get youEarnLabel => 'You earn';

  @override
  String get editHours => 'Edit hours';

  @override
  String get addPeriod => 'Add a period';

  @override
  String get periodsOverlap =>
      'Make sure each period ends after it starts and they don\'t overlap.';

  @override
  String get timeOffDefault => 'Time off';

  @override
  String get earningsNotYet => 'Your earnings show here once you are approved';

  @override
  String get ledgerAdjustment => 'Adjustment';

  @override
  String get complaintsTitle => 'Complaints';

  @override
  String get complaintsMenuBody =>
      'What buyers reported about your orders or jobs, and what you reported';

  @override
  String get complaintsEmpty => 'No complaints';

  @override
  String get complaintsEmptyBody =>
      'If a buyer reports a problem with one of your orders or jobs, it shows here. You can also report one from the order or job.';

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
  String get complaintNotReceived => 'Part not received';

  @override
  String get complaintWrongPart => 'Wrong part';

  @override
  String get complaintDamaged => 'Damage or fault';

  @override
  String get complaintNotFitted => 'Fitting not done right';

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
  String get complaintTitle => 'Complaint';

  @override
  String complaintFrom(String name) {
    return 'Opened by $name';
  }

  @override
  String get complaintOutcome => 'Outcome';

  @override
  String get complaintYou => 'You';

  @override
  String get complaintTeam => 'Alghali Street team';

  @override
  String get complaintReply => 'Write a reply';

  @override
  String get tourOrdersTitle => 'Orders and fitting jobs come to you';

  @override
  String get tourOrdersBody =>
      'Get an alert for every new order or job, and answer buyers in chat.';

  @override
  String get tourStockTitle => 'Your stock, even offline';

  @override
  String get tourStockBody =>
      'Change prices and quantities any time; they are sent by themselves when you are back online.';

  @override
  String get tourEarnTitle => 'Track your earnings';

  @override
  String get tourEarnBody =>
      'See what each order and fitting earned you, and what the platform owes you.';

  @override
  String get shopLocation => 'Shop location on the map';

  @override
  String get shopLocationBody =>
      'Optional. Buyers get a button that opens Google Maps with directions to your shop; without it, the button is hidden.';

  @override
  String get shopLocationPick => 'Set the shop\'s location';

  @override
  String get shopLocationIsSet => 'Location set';

  @override
  String get shopLocationChange => 'Change';

  @override
  String get shopLocationView => 'View on the map';

  @override
  String get shopLocationRemove => 'Remove';

  @override
  String get pickLocationTitle => 'Shop location';

  @override
  String get pickLocationHint => 'Move the map until the pin sits on your shop\'s door.';

  @override
  String get pickLocationHere => 'My location';

  @override
  String get pickLocationConfirm => 'Use this location';

  @override
  String get moreTint => 'Window tint';

  @override
  String get tintOffer => 'We offer window tint';

  @override
  String get tintOfferBody =>
      'Buyers see your shop when they choose window tint, at the prices you enter here.';

  @override
  String get tintDarkness => 'Darkness levels you offer';

  @override
  String get tintDarknessNote => '100% is the darkest.';

  @override
  String get tintColours => 'Colours you offer';

  @override
  String get tintPrices => 'Prices by car size';

  @override
  String get tintPricesNote =>
      'Leave a box empty if you don\'t offer it. The one-window price is used when the buyer ticks windows one by one.';

  @override
  String tintPricesSet(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count prices',
      one: '1 price',
      zero: 'No prices yet',
    );
    return '$_temp0';
  }

  @override
  String get tintBayNone =>
      'No technician who does tint works at your shop\'s bay yet, so buyers won\'t see fitting at the shop. Ask one of your staff to sign up as a technician at your bay.';

  @override
  String tintBayCount(int count) {
    return 'Technicians who tint at your bay: $count';
  }

  @override
  String get tintNeedsChoice => 'Choose at least one darkness level and one colour.';
}
