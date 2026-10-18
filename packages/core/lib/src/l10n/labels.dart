import '../backend/backend_error.dart';
import '../models/catalogue.dart';
import '../models/commerce.dart';
import '../models/tint.dart';
import 'generated/core_localizations.dart';

/// Localised names for domain enums, so every screen words statuses the same way.
extension CoreLabels on CoreLocalizations {
  String condition(ListingCondition c) => switch (c) {
    ListingCondition.newOem => conditionNewOem,
    ListingCondition.newAftermarket => conditionNewAftermarket,
    ListingCondition.used => conditionUsed,
  };

  String fit(Fit f) => switch (f) {
    Fit.fits => fitFits,
    Fit.check => fitCheck,
    Fit.noFit => fitNoFit,
  };

  /// "No warranty", "14-day warranty", "6-month warranty", "1-year warranty".
  String warranty(int days) {
    if (days == 365) return warrantyYear;
    if (days >= 30) return warrantyMonths((days / 30).round());
    return warrantyDays(days);
  }

  String paymentMethod(PaymentMethod m) => switch (m) {
    PaymentMethod.bankak => payBankak,
    PaymentMethod.cash => payCash,
  };

  String fulfilment(FulfilmentType f) => switch (f) {
    FulfilmentType.pickup => fulfilPickup,
    FulfilmentType.delivery => fulfilDelivery,
    FulfilmentType.toTechnician => fulfilToTechnician,
  };

  String subOrderStatus(SubOrderStatus s) => switch (s) {
    SubOrderStatus.pendingPayment => subPendingPayment,
    SubOrderStatus.paymentReview => subPaymentReview,
    SubOrderStatus.confirmed => subConfirmed,
    SubOrderStatus.ready => subReady,
    SubOrderStatus.pickedUp => subPickedUp,
    SubOrderStatus.outForDelivery => subOutForDelivery,
    SubOrderStatus.delivered => subDelivered,
    SubOrderStatus.handedToTechnician => subHandedToTechnician,
    SubOrderStatus.completed => subCompleted,
    SubOrderStatus.cancelled => subCancelled,
    SubOrderStatus.rejectedByShop => subRejectedByShop,
    SubOrderStatus.returnRequested => subReturnRequested,
    SubOrderStatus.returned => subReturned,
  };

  String paymentStatus(PaymentStatus s) => switch (s) {
    PaymentStatus.awaitingTransfer => payAwaitingTransfer,
    PaymentStatus.receiptSubmitted => payReceiptSubmitted,
    PaymentStatus.confirmed => payConfirmed,
    PaymentStatus.rejected => payRejected,
    PaymentStatus.due => payDue,
    PaymentStatus.collected => payCollected,
    PaymentStatus.expired => payExpired,
    PaymentStatus.cancelled => payCancelled,
  };

  String bookingStatus(BookingStatus s) => switch (s) {
    BookingStatus.held => bkHeld,
    BookingStatus.awaitingPayment => bkAwaitingPayment,
    BookingStatus.pendingTechAccept => bkPendingTechAccept,
    BookingStatus.accepted => bkAccepted,
    BookingStatus.enRoute => bkEnRoute,
    BookingStatus.inProgress => bkInProgress,
    BookingStatus.completed => bkCompleted,
    BookingStatus.needsReschedule => bkNeedsReschedule,
    BookingStatus.expired => bkExpired,
    BookingStatus.cancelledByBuyer => bkCancelledByBuyer,
    BookingStatus.cancelledByTech => bkCancelledByTech,
    BookingStatus.cancelledByAdmin => bkCancelledByAdmin,
    BookingStatus.partDoesNotFit => bkPartDoesNotFit,
  };

  String jobType(JobType j) => switch (j) {
    JobType.lighting => jobLighting,
    JobType.brakes => jobBrakes,
    JobType.service => jobService,
    JobType.battery => jobBattery,
    JobType.electrical => jobElectrical,
    JobType.ac => jobAc,
    JobType.suspension => jobSuspension,
    JobType.tyres => jobTyres,
    JobType.mechanical => jobMechanical,
    JobType.tint => jobTint,
  };

  String tintSize(TintCarSize s) => switch (s) {
    TintCarSize.small => tintSizeSmall,
    TintCarSize.saloon => tintSizeSaloon,
    TintCarSize.suv => tintSizeSuv,
    TintCarSize.pickup => tintSizePickup,
    TintCarSize.minibus => tintSizeMinibus,
  };

  String tintItem(TintItem i) => switch (i) {
    TintItem.full => tintFull,
    TintItem.sides => tintSides,
    TintItem.sidesBack => tintSidesBack,
    TintItem.windscreenStrip => tintStrip,
    TintItem.window => tintOneWindow,
  };

  String tintWindow(TintWindow w) => switch (w) {
    TintWindow.windscreen => tintWindscreen,
    TintWindow.backGlass => tintBackGlass,
    TintWindow.frontLeft => tintFrontLeft,
    TintWindow.frontRight => tintFrontRight,
    TintWindow.backLeft => tintBackLeft,
    TintWindow.backRight => tintBackRight,
    TintWindow.sunroof => tintSunroof,
  };

  String tintColour(TintColour c) => switch (c) {
    TintColour.black => tintBlack,
    TintColour.smoke => tintSmoke,
    TintColour.blue => tintBlue,
    TintColour.green => tintGreen,
    TintColour.bronze => tintBronze,
    TintColour.silver => tintSilver,
  };

  /// "السيارة كاملة" or "3 نوافذ".
  String tintSelection(TintSelection s) => switch (s.package) {
    final p? => tintItem(p),
    null => tintWindows(s.windows.length),
  };

  /// "Full car · 50% · Black · Saloon".
  String tintSummary(TintChoice c) => [
    tintSelection(c.selection),
    tintPercent(c.darkness),
    tintColour(c.colour),
    tintSize(c.carSize),
  ].join(' · ');

  String workMode(WorkMode m) => switch (m) {
    WorkMode.bay => modeBay,
    WorkMode.mobile => modeMobile,
    WorkMode.both => modeBoth,
  };

  String side(StreetSide s) => switch (s) {
    StreetSide.a => sideA,
    StreetSide.b => sideB,
  };

  /// "قبل 5 دقائق" / "5 min ago", from [then] to [now].
  String ago(DateTime then, DateTime now) {
    final d = now.difference(then);
    if (d.inMinutes < 60) return agoMinutes(d.inMinutes.clamp(0, 59));
    if (d.inHours < 24) return agoHours(d.inHours);
    return agoDays(d.inDays);
  }

  String distance(double km) => this.km(km < 10 ? km.toStringAsFixed(1) : km.round().toString());
}

/// The message for a failed backend call, from its error code (docs/API.md).
extension ErrorLabels on CoreLocalizations {
  String error(Object e) => errorCode(e is BackendException ? e.code : 'UNKNOWN');

  String errorCode(String code) => switch (code) {
    BackendException.offlineCode => errOffline,
    'SESSION_EXPIRED' || 'NOT_AUTHENTICATED' => errSessionExpired,
    'INVALID_CREDENTIALS' => errInvalidCredentials,
    'USER_ALREADY_EXISTS' || 'EMAIL_EXISTS' => errEmailTaken,
    'WEAK_PASSWORD' => fieldPasswordWeak,
    'EMAIL_ADDRESS_INVALID' || 'VALIDATION_FAILED' => fieldEmailInvalid,
    'OVER_REQUEST_RATE_LIMIT' ||
    'OVER_EMAIL_SEND_RATE_LIMIT' ||
    'RATE_LIMITED' => errTooManyAttempts,
    'INVALID_PHONE' || 'INVALID_WHATSAPP' => fieldPhoneInvalid,
    'PHONE_REQUIRED' => errPhoneRequired,
    'SLOT_TAKEN' => errSlotTaken,
    'HOLD_EXPIRED' || 'BOOKING_NOT_FOUND' => errHoldExpired,
    'TECHNICIAN_UNSUITABLE' || 'TECHNICIAN_NOT_ASSIGNED' => errTechnicianUnavailable,
    'TOO_EARLY' || 'INVALID_START' => errTooEarly,
    'TRAVEL_OUT_OF_RANGE' || 'DELIVERY_OUT_OF_RANGE' || 'INVALID_LOCATION' => errOutOfRange,
    'TRAVEL_UNAVAILABLE' => errTravelUnavailable,
    'DELIVERY_UNAVAILABLE' => errDeliveryUnavailable,
    'DUPLICATE_TXN' => errDuplicateTxn,
    'PAYMENT_EXPIRED' => errPaymentExpired,
    'CANNOT_CANCEL' => errCannotCancel,
    'INVALID_TRANSITION' || 'NOT_EN_ROUTE' => errChangedMeanwhile,
    'TOO_MANY_REQUESTS' => errTooManyRequests,
    'GARAGE_FULL' => errGarageFull,
    'FILE_TOO_LARGE' => errFileTooLarge,
    'INVALID_FILE_TYPE' => errFileType,
    'NOT_FOUND' ||
    'ORDER_NOT_FOUND' ||
    'ITEM_NOT_FOUND' ||
    'SUBORDER_NOT_FOUND' ||
    'LISTING_NOT_FOUND' ||
    'SHOP_NOT_FOUND' ||
    'REQUEST_NOT_FOUND' => errNotFound,
    'FORBIDDEN' => errForbidden,
    'CART_CHANGED' => errCartChanged,
    'ADDRESS_REQUIRED' || 'ADDRESS_NOT_FOUND' => errAddressRequired,
    'LOCATION_OFF' => errLocationOff,
    'LOCATION_DENIED' => errLocationDenied,
    'OFFER_CLOSED' || 'OFFER_NOT_FOUND' || 'UNAVAILABLE' || 'NOT_INSTALLABLE' => errUnavailable,
    // The partner app (M5).
    'VERSION_CONFLICT' => errVersionConflict,
    'STOCK_BELOW_RESERVED' => errStockBelowReserved,
    'PRICE_REQUIRED' => errPriceRequired,
    'INVALID_QTY' ||
    'INVALID_VALUE' ||
    'INVALID_OFFER' ||
    'NAME_TOO_LONG' ||
    'PART_NAME_REQUIRED' ||
    'PART_NAME_INVALID' ||
    'PART_REQUIRED' ||
    'INVALID_OPENING_HOURS' ||
    'CATEGORY_NOT_FOUND' ||
    'INVALID_JOB_TYPES' ||
    'INVALID_WORK_MODE' => errCheckValue,
    'SHOP_NOT_ACTIVE' => errShopNotActive,
    'TECHNICIAN_NOT_ACTIVE' || 'NOT_A_TECHNICIAN' => errTechNotActive,
    'PARTS_NOT_COLLECTED' => errPartsNotCollected,
    'PARTS_WITH_TECHNICIAN' => errPartsWithTechnician,
    'JOB_CODE_LOCKED' => errJobCodeLocked,
    'LABOUR_OUT_OF_BOUNDS' => errLabourBounds,
    'TOO_MANY_RULES' => errTooManyRules,
    'TIME_OFF_TOO_LONG' => errTimeOffTooLong,
    'ALREADY_MEMBER' => errAlreadyMember,
    'USER_NOT_FOUND' => errUserNotFound,
    'TOO_MANY_STAFF' => errTooManyStaff,
    'CANNOT_REMOVE_OWNER' => errCannotRemoveOwner,
    'APPLICATION_PENDING' || 'ALREADY_APPLIED' => errAlreadyApplied,
    'TOO_MANY_SHOPS' => errTooManyShops,
    'BAY_REQUIRED' => errBayRequired,
    'HOME_POINT_REQUIRED' => errHomeRequired,
    'JOB_TYPES_REQUIRED' => errJobTypesRequired,
    'REASON_REQUIRED' => errReasonRequired,
    'HEADER_NOT_FOUND' || 'UNREADABLE_FILE' || 'EMPTY_FILE' || 'FILE_NOT_FOUND' => errBadSheet,
    'TOO_MANY_ROWS' => errTooManyRows,
    // Window tint (D-149).
    'TINT_NEEDS_FITTING' => errTintNeedsFitting,
    'TINT_PRICE_REQUIRED' => errTintPriceRequired,
    'INVALID_TINT' => errCheckValue,
    _ => errGeneric,
  };
}
