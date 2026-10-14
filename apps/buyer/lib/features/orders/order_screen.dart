import 'package:alghali_core/alghali_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../router.dart';
import '../../state/account.dart';
import '../../state/bookings.dart';
import '../../state/orders.dart';
import '../../widgets/buyer_widgets.dart';
import '../account/complaints_screens.dart';
import '../checkout/bankak_screen.dart' show rejectReason;
import 'review_sheet.dart';

class OrderScreen extends ConsumerWidget {
  const OrderScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final order = ref.watch(orderProvider(orderId));
    return Scaffold(
      appBar: AppBar(
        title: Text(order.value == null ? t.orderTitle : t.orderRef(formatRef(order.value!.ref))),
      ),
      body: AsyncBody(
        value: order,
        onRefresh: () => ref.read(orderProvider(orderId).notifier).refresh(),
        data: (o) => o == null
            ? ListView(
                children: [EmptyState(icon: Icons.receipt_long_outlined, title: t.ordersEmpty)],
              )
            : _OrderBody(order: o),
      ),
    );
  }
}

class _OrderBody extends ConsumerWidget {
  const _OrderBody({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final core = context.core;
    final theme = Theme.of(context);
    final catalogue = ref.watch(catalogueProvider);
    final booking = ref
        .watch(bookingsProvider)
        .value
        ?.where((b) => b.orderId == order.id)
        .firstOrNull;

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
      if (!(ok ?? false)) return;
      try {
        await ref.read(orderProvider(order.id).notifier).cancel();
      } on BackendException catch (e) {
        if (context.mounted) showError(context, e);
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(Space.page, Space.lg, Space.page, Space.xxl),
      children: [
        if (order.isCancelled)
          InfoBanner(tone: Tone.danger, message: t.orderCancelled)
        else if (order.needsTransfer)
          InfoBanner(
            tone: order.bankakStatus == PaymentStatus.rejected ? Tone.danger : Tone.warning,
            title: order.bankakStatus == PaymentStatus.rejected
                ? t.bankakRejected
                : t.orderAwaiting,
            message: order.bankakStatus == PaymentStatus.rejected
                ? t.bankakRejectedBody(rejectReason(context, order.rejectReason))
                : t.orderAwaitingBody(context.sdg(order.bankakDueSdg), context.time(order.payBy)),
            action: FilledButton(
              onPressed: () => context.push(Routes.payOrder(order.id)),
              child: Text(t.orderPayNow),
            ),
          )
        else if (order.receiptBeingChecked)
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
                  label: core.paymentStatus(order.bankakStatus),
                  tone: paymentTone(order.bankakStatus),
                  icon: Icons.account_balance_wallet_outlined,
                ),
              ),
            ],
          ),
        ),
        for (final sub in order.streetOrder(catalogue)) ...[
          const SizedBox(height: Space.md),
          _SubOrderCard(order: order, sub: sub),
        ],
        if (booking != null) ...[
          const SizedBox(height: Space.md),
          _LinkedBooking(booking: booking),
        ],
        if (order.refunds.isNotEmpty) ...[
          const SizedBox(height: Space.md),
          SectionCard(
            title: t.orderRefunds,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final r in order.refunds)
                  KeyValueRow(
                    label: r.sent ? t.refundSent : t.refundPending,
                    value: context.sdg(r.amountSdg),
                  ),
                const SizedBox(height: Space.xs),
                Text(t.refundBody, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
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
        if (order.canCancel) ...[
          const SizedBox(height: Space.md),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: theme.colorScheme.error),
            onPressed: cancel,
            icon: const Icon(Icons.cancel_outlined),
            label: Text(t.orderCancel),
          ),
        ],
      ],
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
    final name = shopName(context, catalogue, sub.shopId, fallback: sub.shopName);
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
    DateTime? reachedAt(SubOrderStatus s) => sub.events.where((e) => e.status == s).lastOrNull?.at;

    final received = const {
      SubOrderStatus.pickedUp,
      SubOrderStatus.delivered,
      SubOrderStatus.completed,
    }.contains(sub.status);
    final canConfirm =
        sub.status == SubOrderStatus.pickedUp || sub.status == SubOrderStatus.delivered;
    final receivedAt =
        reachedAt(SubOrderStatus.pickedUp) ??
        reachedAt(SubOrderStatus.delivered) ??
        reachedAt(SubOrderStatus.completed);
    final returnOpen =
        receivedAt != null &&
        sub.returnRequest == null &&
        sub.fulfilment != FulfilmentType.toTechnician &&
        ref.watch(clockProvider)().difference(receivedAt).inDays < settings.returnWindowDays;

    Future<void> act(Future<Order> Function(OrderController c) action, {String? done}) async {
      try {
        await action(ref.read(orderProvider(order.id).notifier));
        if (done != null && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(done)));
        }
      } on BackendException catch (e) {
        if (context.mounted) showError(context, e);
      }
    }

    Future<void> askReturn() async {
      final reason = await askText(
        context,
        title: t.orderReturn,
        label: t.orderReturnReason,
        submit: t.orderReturnSend,
      );
      if (reason != null) {
        await act((c) => c.requestReturn(sub.id, reason), done: t.orderReturnSent);
      }
    }

    return SectionCard(
      title: name,
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
                [
                  shopPlace(context, catalogue, shop),
                  shop.landmark.tr(context),
                ].where((s) => s.isNotEmpty).join(' · '),
              ),
              style: theme.textTheme.bodySmall,
            ),
          if (sub.cancelReason != null &&
              (sub.status == SubOrderStatus.cancelled ||
                  sub.status == SubOrderStatus.rejectedByShop)) ...[
            const SizedBox(height: Space.sm),
            InfoBanner(tone: Tone.neutral, message: sub.cancelReason!),
          ],
          if (sub.returnRequest != null) ...[
            const SizedBox(height: Space.sm),
            InfoBanner(
              tone: Tone.neutral,
              icon: Icons.assignment_return_outlined,
              title: switch (sub.returnRequest!.state) {
                ReturnState.requested => t.returnRequested,
                ReturnState.approved => t.returnApproved,
                ReturnState.declined => t.returnDeclined,
              },
              message: sub.returnRequest!.note ?? sub.returnRequest!.reason,
            ),
          ],
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
          ContactActions(
            live: true,
            phone: sub.shopPhone ?? shop.phone,
            whatsapp: sub.shopWhatsapp ?? shop.whatsapp,
            onChat: () => context.push(Routes.chat(sub.shopId)),
          ),
          if (canConfirm) ...[
            const SizedBox(height: Space.sm),
            FilledButton.icon(
              onPressed: () => act((c) => c.confirmReceived(sub.id)),
              icon: const Icon(Icons.task_alt),
              label: Text(t.orderGotIt),
            ),
          ],
          if (received) ...[
            const SizedBox(height: Space.sm),
            Wrap(
              spacing: Space.sm,
              runSpacing: Space.xs,
              children: [
                if (!reviewed.contains(reviewKey))
                  OutlinedButton.icon(
                    onPressed: () => showReviewSheet(context, name: name, subOrderId: sub.id),
                    icon: const Icon(Icons.star_outline_rounded),
                    label: Text(t.orderRateShop),
                  ),
                if (returnOpen) TextButton(onPressed: askReturn, child: Text(t.orderReturn)),
                TextButton(
                  onPressed: () => showComplaintSheet(context, subOrderId: sub.id),
                  child: Text(t.complaintReport),
                ),
              ],
            ),
            if (returnOpen)
              Text(t.orderReturnBody(settings.returnWindowDays), style: theme.textTheme.bodySmall),
            if (sub.fulfilment != FulfilmentType.toTechnician)
              for (final item in sub.items)
                // The server says if the part can't be fitted (NOT_INSTALLABLE).
                if (item.id != null && item.partId.isNotEmpty)
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton.icon(
                      onPressed: () =>
                          context.push(Routes.bookOrderItem(item.id!, item.title.tr(context))),
                      icon: const Icon(Icons.handyman_outlined, size: 18),
                      label: Text(t.orderBookFitting(item.title.tr(context))),
                    ),
                  ),
          ],
        ],
      ),
    );
  }
}

class _LinkedBooking extends StatelessWidget {
  const _LinkedBooking({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
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
                Text(booking.technicianName, style: Theme.of(context).textTheme.bodySmall),
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
