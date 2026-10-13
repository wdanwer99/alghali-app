import '../models/catalogue.dart';
import '../models/commerce.dart';
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
  };

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
