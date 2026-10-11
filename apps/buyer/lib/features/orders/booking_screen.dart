import 'package:alghali_core/alghali_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../router.dart';
import '../../state/orders.dart';
import '../../widgets/buyer_widgets.dart';
import 'review_sheet.dart';

class BookingScreen extends ConsumerWidget {
  const BookingScreen({super.key, required this.bookingId});

  final String bookingId;

  static const _showCode = {
    BookingStatus.accepted,
    BookingStatus.enRoute,
    BookingStatus.inProgress,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final core = context.core;
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final b = ref.watch(bookingsProvider).where((b) => b.id == bookingId).firstOrNull;
    if (b == null) {
      return Scaffold(
        appBar: AppBar(),
        body: EmptyState(icon: Icons.handyman_outlined, title: t.bookingsEmpty),
      );
    }
    final catalogue = ref.watch(catalogueProvider);
    final settings = ref.watch(platformSettingsProvider);
    final reviewed = ref.watch(reviewedProvider);
    final bookings = ref.read(bookingsProvider.notifier);
    final tech = catalogue.technician(b.technicianId);
    final freeUntil = b.startAt.subtract(Duration(hours: settings.cancelCutoffHours));
    final reviewKey = 'tech:${b.id}';

    final steps = <(BookingStatus, String)>[
      (BookingStatus.held, t.tlBooked),
      if (b.method == PaymentMethod.bankak || b.depositSdg > 0)
        (BookingStatus.pendingTechAccept, t.tlPaymentChecked),
      (BookingStatus.accepted, t.tlTechAccepted),
      if (b.place == BookingPlace.customer) (BookingStatus.enRoute, t.tlEnRoute),
      (BookingStatus.inProgress, t.tlWorking),
      (BookingStatus.completed, t.tlJobDone),
    ];
    final order = BookingStatus.values;
    final reached = steps.lastIndexWhere((s) => order.indexOf(s.$1) <= order.indexOf(b.status));

    Future<void> cancel() async {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(t.bookingCancelConfirm),
          content: Text(t.bookingCancelFree(context.dayTime(freeUntil))),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(t.bookingKeep)),
            TextButton(onPressed: () => Navigator.pop(context, true), child: Text(t.bookingCancel)),
          ],
        ),
      );
      if (ok ?? false) bookings.cancel(b.id);
    }

    return Scaffold(
      appBar: AppBar(title: Text(t.bookingTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Space.page, Space.lg, Space.page, Space.xxl),
        children: [
          Card(
            color: colors.brandSurface,
            child: Padding(
              padding: const EdgeInsets.all(Space.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.day(b.startAt),
                    style: theme.textTheme.titleMedium?.copyWith(color: colors.onBrandSurfaceMuted),
                  ),
                  Text(
                    context.time(b.startAt),
                    style: theme.textTheme.displaySmall?.copyWith(color: colors.onBrandSurface),
                  ),
                  const SizedBox(height: Space.sm),
                  Wrap(
                    spacing: Space.sm,
                    runSpacing: Space.xs,
                    children: [
                      StatusPill(label: core.bookingStatus(b.status), tone: bookingTone(b.status)),
                      StatusPill(
                        label: b.place == BookingPlace.bay ? t.placeBay : t.placeHome,
                        icon: Icons.place_outlined,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Space.md),
          if (b.paymentStatus == PaymentStatus.awaitingTransfer)
            InfoBanner(
              tone: Tone.warning,
              title: t.orderAwaiting,
              message: t.orderAwaitingBody(
                context.sdg(b.bankakDueSdg),
                context.time(
                  b.events.first.at.add(Duration(minutes: settings.paymentWindowMinutes)),
                ),
              ),
              action: FilledButton(
                onPressed: () => context.push(Routes.payBooking(b.id)),
                child: Text(t.orderPayNow),
              ),
            )
          else if (b.paymentStatus == PaymentStatus.receiptSubmitted)
            InfoBanner(
              tone: Tone.info,
              icon: Icons.hourglass_top,
              title: t.bankakChecking,
              message: t.bankakCheckingBody,
            )
          else if (b.status == BookingStatus.pendingTechAccept)
            InfoBanner(
              tone: Tone.info,
              icon: Icons.hourglass_top,
              message: t.bookingWaitingTech(settings.techAcceptTimeoutMinutes),
            )
          else if (b.status == BookingStatus.enRoute)
            InfoBanner(
              tone: Tone.brand,
              icon: Icons.near_me_outlined,
              message: t.bookingEnRoute(tech.name.tr(context)),
            ),
          if (_showCode.contains(b.status)) ...[
            const SizedBox(height: Space.md),
            SectionCard(
              child: Column(
                children: [
                  Text(t.bookingCode, style: theme.textTheme.titleMedium),
                  const SizedBox(height: Space.md),
                  BigDigits(b.jobCode),
                  const SizedBox(height: Space.md),
                  Text(
                    t.bookingCodeBody,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: Space.md),
          SectionCard(
            child: StatusTimeline(
              steps: [
                for (final (i, (_, title)) in steps.indexed)
                  TimelineStep(
                    title,
                    b.status == BookingStatus.completed || i < reached
                        ? TimelineState.done
                        : i == reached
                        ? TimelineState.current
                        : TimelineState.upcoming,
                  ),
              ],
            ),
          ),
          const SizedBox(height: Space.md),
          SectionCard(
            title: t.bookingTech,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TechnicianSummary(tech: tech, subtitle: core.workMode(tech.mode)),
                const SizedBox(height: Space.md),
                const ContactActions(),
              ],
            ),
          ),
          const SizedBox(height: Space.md),
          SectionCard(
            title: t.bookingWhere,
            child: b.place == BookingPlace.bay && b.bayShopId != null
                ? _BayPlace(shop: catalogue.shop(b.bayShopId!))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(b.address?.label.tr(context) ?? '', style: theme.textTheme.titleSmall),
                      Text(
                        b.address?.description.tr(context) ?? '',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: Space.md),
          SectionCard(
            title: t.bookingJob,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final item in b.items)
                  KeyValueRow(label: item.title.tr(context), value: core.minutes(item.minutes)),
                if (b.variantId != null)
                  Text(
                    carLabel(context, catalogue, b.variantId!),
                    style: theme.textTheme.bodySmall,
                  ),
                const Divider(height: Space.xl),
                KeyValueRow(label: t.costLabour, value: context.sdg(b.labourSdg)),
                if (b.travelFeeSdg > 0)
                  KeyValueRow(label: t.costTravel, value: context.sdg(b.travelFeeSdg)),
                KeyValueRow(label: t.costBookingFee, value: context.sdg(b.bookingFeeSdg)),
                KeyValueRow(label: t.costTotal, value: context.sdg(b.totalSdg), emphasis: true),
              ],
            ),
          ),
          if (b.orderId != null) ...[
            const SizedBox(height: Space.md),
            OutlinedButton.icon(
              onPressed: () => context.push(Routes.order(b.orderId!)),
              icon: const Icon(Icons.receipt_long_outlined),
              label: Text(t.orderTitle),
            ),
          ],
          if (b.status == BookingStatus.completed && !reviewed.contains(reviewKey)) ...[
            const SizedBox(height: Space.md),
            FilledButton.icon(
              onPressed: () =>
                  showReviewSheet(context, name: tech.name.tr(context), key: reviewKey),
              icon: const Icon(Icons.star_outline_rounded),
              label: Text(t.bookingRate),
            ),
          ],
          if (b.isActive && b.status != BookingStatus.inProgress) ...[
            const SizedBox(height: Space.md),
            Text(t.bookingCancelFree(context.dayTime(freeUntil)), style: theme.textTheme.bodySmall),
            const SizedBox(height: Space.sm),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () =>
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(content: Text(t.bookingRescheduleSoon))),
                    child: Text(t.bookingReschedule),
                  ),
                ),
                const SizedBox(width: Space.sm),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(foregroundColor: theme.colorScheme.error),
                    onPressed: cancel,
                    child: Text(t.bookingCancel),
                  ),
                ),
              ],
            ),
          ],
          if (b.isActive) ...[
            const SizedBox(height: Space.lg),
            DemoControls(onNext: () => bookings.demoAdvance(b.id)),
          ],
        ],
      ),
    );
  }
}

class _BayPlace extends StatelessWidget {
  const _BayPlace({required this.shop});

  final Shop shop;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final catalogue = CatalogueScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.t.bookAtBay(shop.name.tr(context)), style: theme.textTheme.titleSmall),
        Text(
          '${shopPlace(context, catalogue, shop)} · ${shop.landmark.tr(context)}',
          style: theme.textTheme.bodyMedium,
        ),
        TextButton.icon(
          onPressed: () =>
              context.go(Uri(path: Routes.street, queryParameters: {'shop': shop.id}).toString()),
          icon: const Icon(Icons.map_outlined),
          label: Text(context.t.shopOnStreet),
        ),
      ],
    );
  }
}
