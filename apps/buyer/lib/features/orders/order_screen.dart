import 'package:alghali_core/alghali_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../router.dart';
import '../../state/orders.dart';
import '../../widgets/buyer_widgets.dart';
import 'review_sheet.dart';

class OrderScreen extends ConsumerWidget {
  const OrderScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final core = context.core;
    final theme = Theme.of(context);
    final order = ref.watch(ordersProvider).where((o) => o.id == orderId).firstOrNull;
    if (order == null) {
      return Scaffold(
        appBar: AppBar(),
        body: EmptyState(icon: Icons.receipt_long_outlined, title: t.ordersEmpty),
      );
    }
    final orders = ref.read(ordersProvider.notifier);

    Future<void> cancel() async {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(t.orderCancelConfirm),
          content: Text(t.orderCancelBody),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(t.orderKeep)),
            TextButton(onPressed: () => Navigator.pop(context, true), child: Text(t.orderCancel)),
          ],
        ),
      );
      if (ok ?? false) orders.cancel(order.id);
    }

    return Scaffold(
      appBar: AppBar(title: Text(t.orderRef(formatRef(order.ref)))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Space.page, Space.lg, Space.page, Space.xxl),
        children: [
          if (order.isCancelled)
            InfoBanner(tone: Tone.danger, message: t.orderCancelled)
          else if (order.needsTransfer)
            InfoBanner(
              tone: Tone.warning,
              title: t.orderAwaiting,
              message: t.orderAwaitingBody(
                context.sdg(order.bankakDueSdg),
                context.time(order.payBy),
              ),
              action: FilledButton(
                onPressed: () => context.push(Routes.payOrder(order.id)),
                child: Text(t.orderPayNow),
              ),
            )
          else if (order.paymentStatus == PaymentStatus.receiptSubmitted)
            InfoBanner(
              tone: Tone.info,
              icon: Icons.hourglass_top,
              title: t.bankakChecking,
              message: t.bankakCheckingBody,
            ),
          const SizedBox(height: Space.md),
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CopyValue(label: t.bankakRef, value: order.ref, display: formatRef(order.ref)),
                const SizedBox(height: Space.sm),
                KeyValueRow(label: t.orderPlacedOn(''), value: context.dayTime(order.createdAt)),
                KeyValueRow(label: t.checkoutPayment, value: core.paymentMethod(order.method)),
                const SizedBox(height: Space.xs),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: StatusPill(
                    label: core.paymentStatus(order.paymentStatus),
                    tone: paymentTone(order.paymentStatus),
                    icon: Icons.account_balance_wallet_outlined,
                  ),
                ),
              ],
            ),
          ),
          for (final sub in order.subOrders) ...[
            const SizedBox(height: Space.md),
            _SubOrderCard(order: order, sub: sub),
          ],
          if (order.bookingId != null) ...[
            const SizedBox(height: Space.md),
            _LinkedBooking(bookingId: order.bookingId!),
          ],
          const SizedBox(height: Space.md),
          SectionCard(
            title: t.cartSummary,
            child: Column(
              children: [
                KeyValueRow(label: t.costParts, value: context.sdg(order.itemsSdg)),
                if (order.deliverySdg > 0)
                  KeyValueRow(label: t.costDelivery, value: context.sdg(order.deliverySdg)),
                if (order.labourSdg > 0)
                  KeyValueRow(label: t.costLabour, value: context.sdg(order.labourSdg)),
                if (order.travelFeeSdg > 0)
                  KeyValueRow(label: t.costTravel, value: context.sdg(order.travelFeeSdg)),
                if (order.bookingFeeSdg > 0)
                  KeyValueRow(label: t.costBookingFee, value: context.sdg(order.bookingFeeSdg)),
                const Divider(height: Space.xl),
                KeyValueRow(label: t.costTotal, value: context.sdg(order.totalSdg), emphasis: true),
              ],
            ),
          ),
          if (order.canCancel && !order.isCancelled) ...[
            const SizedBox(height: Space.md),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: theme.colorScheme.error),
              onPressed: cancel,
              icon: const Icon(Icons.cancel_outlined),
              label: Text(t.orderCancel),
            ),
          ],
          if (!order.isCancelled &&
              order.subOrders.any((s) => s.status != SubOrderStatus.completed)) ...[
            const SizedBox(height: Space.lg),
            DemoControls(onNext: () => orders.demoAdvance(order.id)),
          ],
        ],
      ),
    );
  }
}

class _SubOrderCard extends ConsumerWidget {
  const _SubOrderCard({required this.order, required this.sub});

  final Order order;
  final SubOrder sub;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final core = context.core;
    final theme = Theme.of(context);
    final catalogue = ref.watch(catalogueProvider);
    final settings = ref.watch(platformSettingsProvider);
    final reviewed = ref.watch(reviewedProvider);
    final shop = catalogue.shop(sub.shopId);
    final reviewKey = 'shop:${sub.id}';

    final steps = <(SubOrderStatus, String)>[
      if (order.method == PaymentMethod.bankak) ...[
        (SubOrderStatus.pendingPayment, t.tlPlaced),
        (SubOrderStatus.paymentReview, t.tlPaymentChecked),
      ],
      (SubOrderStatus.confirmed, t.tlShopConfirmed),
      (SubOrderStatus.ready, t.tlReady),
      ...switch (sub.fulfilment) {
        FulfilmentType.pickup => [(SubOrderStatus.pickedUp, t.tlPickedUp)],
        FulfilmentType.delivery => [
          (SubOrderStatus.outForDelivery, t.tlOnTheWay),
          (SubOrderStatus.delivered, t.tlDelivered),
        ],
        FulfilmentType.toTechnician => [(SubOrderStatus.handedToTechnician, t.tlHanded)],
      },
      (SubOrderStatus.completed, t.tlCompleted),
    ];
    final current = steps.indexWhere((s) => s.$1 == sub.status);
    DateTime? reachedAt(SubOrderStatus s) => sub.events.where((e) => e.status == s).firstOrNull?.at;

    final received = const {
      SubOrderStatus.pickedUp,
      SubOrderStatus.delivered,
      SubOrderStatus.completed,
    }.contains(sub.status);

    return SectionCard(
      title: shop.name.tr(context),
      trailing: StatusPill(label: core.subOrderStatus(sub.status), tone: subOrderTone(sub.status)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final item in sub.items)
            KeyValueRow(
              label: '${item.title.tr(context)} × ${item.qty}',
              value: context.sdg(item.lineSdg),
            ),
          Text(core.fulfilment(sub.fulfilment), style: theme.textTheme.bodySmall),
          if (sub.fulfilment == FulfilmentType.pickup)
            Text(
              t.orderPickupWhere(
                '${shopPlace(context, catalogue, shop)} · ${shop.landmark.tr(context)}',
              ),
              style: theme.textTheme.bodySmall,
            ),
          const SizedBox(height: Space.lg),
          if (current >= 0)
            StatusTimeline(
              steps: [
                for (final (i, (status, title)) in steps.indexed)
                  TimelineStep(
                    title,
                    sub.status == SubOrderStatus.completed || i < current
                        ? TimelineState.done
                        : i == current
                        ? TimelineState.current
                        : TimelineState.upcoming,
                    subtitle: i <= current && reachedAt(status) != null
                        ? context.dayTime(reachedAt(status)!)
                        : null,
                  ),
              ],
            ),
          const SizedBox(height: Space.lg),
          ContactActions(onChat: () => context.push(Routes.chat(shop.id))),
          if (received) ...[
            const SizedBox(height: Space.sm),
            Row(
              children: [
                if (!reviewed.contains(reviewKey))
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          showReviewSheet(context, name: shop.name.tr(context), key: reviewKey),
                      icon: const Icon(Icons.star_outline_rounded),
                      label: Text(t.orderRateShop),
                    ),
                  ),
                if (!reviewed.contains(reviewKey)) const SizedBox(width: Space.sm),
                Expanded(
                  child: TextButton(
                    onPressed: () {
                      ref.read(ordersProvider.notifier).requestReturn(order.id, sub.id);
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text(t.orderReturnSent)));
                    },
                    child: Text(t.orderReturn),
                  ),
                ),
              ],
            ),
            Text(t.orderReturnBody(settings.returnWindowDays), style: theme.textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}

class _LinkedBooking extends ConsumerWidget {
  const _LinkedBooking({required this.bookingId});

  final String bookingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final booking = ref.watch(bookingsProvider).where((b) => b.id == bookingId).firstOrNull;
    if (booking == null) return const SizedBox.shrink();
    final tech = ref.watch(catalogueProvider).technician(booking.technicianId);
    return TapCard(
      onTap: () => context.push(Routes.booking(booking.id)),
      child: Row(
        children: [
          const IconTile(icon: Icons.handyman_outlined, tone: Tone.brand),
          const SizedBox(width: Space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.orderFitting, style: Theme.of(context).textTheme.bodySmall),
                Text(
                  context.dayTime(booking.startAt),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text(tech.name.tr(context), style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          StatusPill(
            label: context.core.bookingStatus(booking.status),
            tone: bookingTone(booking.status),
          ),
        ],
      ),
    );
  }
}
