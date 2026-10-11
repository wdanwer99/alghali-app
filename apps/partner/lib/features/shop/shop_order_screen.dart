import 'package:alghali_core/alghali_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../state/shop_state.dart';
import '../../widgets/partner_widgets.dart';

class ShopOrderScreen extends ConsumerWidget {
  const ShopOrderScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final core = context.core;
    final theme = Theme.of(context);
    final order = ref.watch(shopOrdersProvider).where((o) => o.id == orderId).firstOrNull;
    if (order == null) {
      return Scaffold(
        appBar: AppBar(),
        body: EmptyState(icon: Icons.inbox_outlined, title: t.ordersEmpty),
      );
    }
    final catalogue = ref.watch(catalogueProvider);
    final settings = ref.watch(platformSettingsProvider);
    final orders = ref.read(shopOrdersProvider.notifier);
    final sub = order.sub;
    final commission = (sub.itemsSdg * settings.commissionPercent / 100).round();
    final tech = order.technicianId == null ? null : catalogue.technician(order.technicianId!);

    Future<void> reject() async {
      final ok = await showModalBottomSheet<bool>(
        context: context,
        builder: (context) => _RejectSheet(),
      );
      if (ok ?? false) orders.reject(order.id);
    }

    final actions = <Widget>[
      if (order.isNew) ...[
        Expanded(
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(foregroundColor: theme.colorScheme.error),
            onPressed: reject,
            child: Text(t.orderReject),
          ),
        ),
        const SizedBox(width: Space.md),
        Expanded(
          flex: 2,
          child: FilledButton(onPressed: () => orders.accept(order.id), child: Text(t.orderAccept)),
        ),
      ] else if (order.isPreparing)
        Expanded(
          child: FilledButton(
            onPressed: () => orders.markReady(order.id),
            child: Text(t.markReady),
          ),
        )
      else if (order.isReady)
        Expanded(
          child: FilledButton(
            onPressed: () => orders.handOver(order.id),
            child: Text(switch (sub.fulfilment) {
              FulfilmentType.pickup => t.handToBuyer,
              FulfilmentType.delivery => t.outForDelivery,
              FulfilmentType.toTechnician => t.handToTech,
            }),
          ),
        )
      else if (sub.status == SubOrderStatus.outForDelivery)
        Expanded(
          child: FilledButton(
            onPressed: () => orders.markDelivered(order.id),
            child: Text(t.markDelivered),
          ),
        ),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(t.orderRef(formatRef(order.ref)))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Space.page, Space.lg, Space.page, Space.xxl),
        children: [
          if (sub.status == SubOrderStatus.pendingPayment) ...[
            InfoBanner(
              tone: Tone.warning,
              icon: Icons.hourglass_top,
              message: t.orderAwaitingPayment,
            ),
            const SizedBox(height: Space.md),
          ],
          Card(
            child: Padding(
              padding: const EdgeInsets.all(Space.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(t.sectionBuyer, style: theme.textTheme.titleMedium)),
                      StatusPill(
                        label: core.subOrderStatus(sub.status),
                        tone: shopOrderTone(sub.status),
                      ),
                    ],
                  ),
                  const SizedBox(height: Space.md),
                  Row(
                    children: [
                      InitialsAvatar(name: order.buyerName, size: 44),
                      const SizedBox(width: Space.md),
                      Expanded(child: Text(order.buyerName, style: theme.textTheme.titleSmall)),
                    ],
                  ),
                  const SizedBox(height: Space.md),
                  const ContactActions(),
                ],
              ),
            ),
          ),
          const SizedBox(height: Space.md),
          _Section(
            title: t.sectionItems,
            child: Column(
              children: [
                for (final i in sub.items)
                  KeyValueRow(
                    label: '${i.title.tr(context)} × ${i.qty}\n${core.condition(i.condition)}',
                    value: context.sdg(i.lineSdg),
                  ),
              ],
            ),
          ),
          const SizedBox(height: Space.md),
          _Section(
            title: t.sectionHandover,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(switch (sub.fulfilment) {
                      FulfilmentType.pickup => Icons.storefront_outlined,
                      FulfilmentType.delivery => Icons.local_shipping_outlined,
                      FulfilmentType.toTechnician => Icons.handyman_outlined,
                    }),
                    const SizedBox(width: Space.sm),
                    Expanded(
                      child: Text(
                        core.fulfilment(sub.fulfilment),
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                  ],
                ),
                if (tech != null) ...[
                  const SizedBox(height: Space.sm),
                  Text(
                    t.toTechWith(
                      tech.name.tr(context),
                      order.fittingAt == null ? '' : context.dayTime(order.fittingAt!),
                    ),
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
                if (order.deliveryTo != null) ...[
                  const SizedBox(height: Space.sm),
                  Text(
                    '${order.deliveryTo!.label.tr(context)} — ${order.deliveryTo!.description.tr(context)}',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: Space.md),
          _Section(
            title: t.sectionMoney,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                KeyValueRow(label: t.sectionItems, value: context.sdg(sub.itemsSdg)),
                KeyValueRow(
                  label: t.commission(settings.commissionPercent),
                  value: '−${context.sdg(commission)}',
                ),
                if (sub.deliveryFeeSdg > 0)
                  KeyValueRow(label: core.fulfilDelivery, value: context.sdg(sub.deliveryFeeSdg)),
                const Divider(height: Space.xl),
                KeyValueRow(
                  label: t.youReceive,
                  value: context.sdg(sub.itemsSdg - commission + sub.deliveryFeeSdg),
                  emphasis: true,
                ),
                const SizedBox(height: Space.sm),
                InfoBanner(
                  tone: order.paymentStatus == PaymentStatus.due ? Tone.warning : Tone.success,
                  icon: order.paymentStatus == PaymentStatus.due
                      ? Icons.payments_outlined
                      : Icons.account_balance_outlined,
                  message: order.paymentStatus == PaymentStatus.due
                      ? (sub.fulfilment == FulfilmentType.toTechnician
                            ? t.cashFromTech(context.sdg(sub.itemsSdg))
                            : t.collectCash(context.sdg(sub.itemsSdg + sub.deliveryFeeSdg)))
                      : t.paidBankak,
                ),
              ],
            ),
          ),
          const SizedBox(height: Space.md),
          _Section(
            title: t.receivedAgo(context.dayTime(order.placedAt)),
            child: StatusTimeline(
              steps: [
                for (final e in sub.events)
                  TimelineStep(
                    core.subOrderStatus(e.status),
                    TimelineState.done,
                    subtitle: context.dayTime(e.at),
                  ),
                if (sub.acknowledgedAt != null)
                  TimelineStep(
                    t.orderAccept,
                    TimelineState.done,
                    subtitle: context.dayTime(sub.acknowledgedAt!),
                  ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: actions.isEmpty ? null : BottomActionBar(child: Row(children: actions)),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(Space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: Space.md),
          child,
        ],
      ),
    ),
  );
}

class _RejectSheet extends StatefulWidget {
  @override
  State<_RejectSheet> createState() => _RejectSheetState();
}

class _RejectSheetState extends State<_RejectSheet> {
  var _reason = 0;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.page, 0, Space.page, Space.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(t.rejectTitle, style: Theme.of(context).textTheme.titleLarge),
            RadioGroup<int>(
              groupValue: _reason,
              onChanged: (v) => setState(() => _reason = v ?? 0),
              child: Column(
                children: [
                  for (final (i, label) in [
                    t.rejectOutOfStock,
                    t.rejectPrice,
                    t.rejectOther,
                  ].indexed)
                    RadioListTile<int>(
                      value: i,
                      title: Text(label),
                      contentPadding: EdgeInsets.zero,
                    ),
                ],
              ),
            ),
            InfoBanner(tone: Tone.warning, message: t.rejectNote),
            const SizedBox(height: Space.lg),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
              onPressed: () => Navigator.pop(context, true),
              child: Text(t.orderReject),
            ),
          ],
        ),
      ),
    );
  }
}
