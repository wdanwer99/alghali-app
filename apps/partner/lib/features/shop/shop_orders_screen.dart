import 'package:alghali_core/alghali_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../router.dart';
import '../../state/shop_state.dart';
import '../../widgets/partner_widgets.dart';

class ShopOrdersScreen extends ConsumerWidget {
  const ShopOrdersScreen({super.key, this.tab});

  final String? tab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final orders = ref.watch(shopOrdersProvider);
    final groups = [
      (
        t.tabNew,
        orders.where((o) => o.isNew || o.sub.status == SubOrderStatus.pendingPayment).toList(),
      ),
      (t.tabPreparing, orders.where((o) => o.isPreparing).toList()),
      (t.tabReady, orders.where((o) => o.isReady).toList()),
      (t.tabDone, orders.where((o) => o.isDone).toList()),
    ];
    return DefaultTabController(
      length: groups.length,
      initialIndex: switch (tab) {
        'preparing' => 1,
        'ready' => 2,
        'done' => 3,
        _ => 0,
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(t.shopNavOrders),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [for (final (label, list) in groups) Tab(text: '$label (${list.length})')],
          ),
        ),
        body: TabBarView(
          children: [
            for (final (_, list) in groups)
              list.isEmpty
                  ? EmptyState(icon: Icons.inbox_outlined, title: t.ordersEmpty)
                  : ListView.separated(
                      padding: Space.pageInsets,
                      itemCount: list.length,
                      separatorBuilder: (_, _) => const SizedBox(height: Space.sm),
                      itemBuilder: (_, i) =>
                          ShopOrderCard(key: ValueKey(list[i].id), order: list[i]),
                    ),
          ],
        ),
      ),
    );
  }
}

/// Order summary card used on the dashboard and the orders tabs.
class ShopOrderCard extends ConsumerWidget {
  const ShopOrderCard({super.key, required this.order});

  final ShopOrder order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final core = context.core;
    final theme = Theme.of(context);
    final catalogue = ref.watch(catalogueProvider);
    final now = ref.watch(clockProvider)();
    final items = order.sub.items;
    final ackBy = order.sub.events.first.at.add(const Duration(minutes: 30));

    return TapCard(
      onTap: () => context.push(Routes.shopOrder(order.id)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(t.orderRef(formatRef(order.ref)), style: theme.textTheme.titleSmall),
              ),
              Text(
                context.sdg(order.sub.itemsSdg),
                style: theme.textTheme.titleSmall?.copyWith(fontFeatures: AppTypography.tabular),
              ),
            ],
          ),
          Text(
            '${t.orderFrom(isolate(order.buyerName))} · ${t.receivedAgo(core.ago(order.placedAt, now))}',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: Space.sm),
          for (final i in items)
            Text(
              '${i.title.tr(context)} × ${i.qty}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium,
            ),
          const SizedBox(height: Space.sm),
          Wrap(
            spacing: Space.xs,
            runSpacing: Space.xs,
            children: [
              if (order.isNew)
                Countdown(
                  until: ackBy,
                  builder: (context, left) => StatusPill(
                    label: left == Duration.zero ? t.ackLate : t.ackWithin(left.inMinutes + 1),
                    tone: left == Duration.zero ? Tone.danger : Tone.warning,
                    icon: Icons.timer_outlined,
                  ),
                )
              else
                StatusPill(
                  label: core.subOrderStatus(order.sub.status),
                  tone: shopOrderTone(order.sub.status),
                ),
              StatusPill(
                label:
                    order.sub.fulfilment == FulfilmentType.toTechnician &&
                        order.technicianId != null
                    ? t.toTechWith(
                        catalogue.technician(order.technicianId!).name.tr(context),
                        order.fittingAt == null ? '' : context.dayTime(order.fittingAt!),
                      )
                    : core.fulfilment(order.sub.fulfilment),
                icon: switch (order.sub.fulfilment) {
                  FulfilmentType.pickup => Icons.storefront_outlined,
                  FulfilmentType.delivery => Icons.local_shipping_outlined,
                  FulfilmentType.toTechnician => Icons.handyman_outlined,
                },
              ),
              if (order.paymentStatus == PaymentStatus.due)
                StatusPill(label: core.payCash, tone: Tone.warning, icon: Icons.payments_outlined),
            ],
          ),
        ],
      ),
    );
  }
}
