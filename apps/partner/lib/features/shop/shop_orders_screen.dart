import 'package:alghali_core/alghali_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../router.dart';
import '../../state/shop.dart';
import '../../widgets/partner_widgets.dart';

class ShopOrdersScreen extends ConsumerWidget {
  const ShopOrdersScreen({super.key, this.tab});

  final String? tab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final value = ref.watch(shopOrdersProvider);
    final orders = value.value ?? const <ShopSubOrder>[];
    Future<void> refresh() => ref.read(shopOrdersProvider.notifier).refresh();
    final groups = [
      (t.tabNew, orders.where((o) => o.isNew).toList()),
      (t.tabPreparing, orders.where((o) => o.isPreparing).toList()),
      (t.tabReady, orders.where((o) => o.isReady).toList()),
      (t.tabDone, orders.where((o) => o.isDone).toList()),
    ];

    Widget list(List<ShopSubOrder> items) => RefreshIndicator(
      onRefresh: refresh,
      child: items.isEmpty
          ? ListView(
              children: [EmptyState(icon: Icons.inbox_outlined, title: t.ordersEmpty)],
            )
          : ListView.separated(
              padding: Space.pageInsets,
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: Space.sm),
              itemBuilder: (_, i) => ShopOrderCard(key: ValueKey(items[i].id), order: items[i]),
            ),
    );

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
        body: Column(
          children: [
            const OfflineBanner(),
            Expanded(
              child: switch (value) {
                AsyncValue(hasValue: true) => TabBarView(
                  children: [for (final (_, items) in groups) list(items)],
                ),
                AsyncError(:final error) => EmptyState(
                  icon: Icons.cloud_off_outlined,
                  title: context.core.error(error),
                  action: OutlinedButton.icon(
                    onPressed: refresh,
                    icon: const Icon(Icons.refresh),
                    label: Text(context.core.actionRetry),
                  ),
                ),
                _ => const SkeletonList(),
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// When the order became the shop's to accept: when it was paid (or placed, for cash).
DateTime confirmedAt(ShopSubOrder o) =>
    o.subOrder.events.where((e) => e.status == SubOrderStatus.confirmed).firstOrNull?.at ??
    o.placedAt;

/// Order summary card used on the dashboard and the orders tabs.
class ShopOrderCard extends ConsumerWidget {
  const ShopOrderCard({super.key, required this.order});

  final ShopSubOrder order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final core = context.core;
    final theme = Theme.of(context);
    final now = ref.watch(clockProvider)();
    final sub = order.subOrder;
    final booking = order.booking;
    final ackBy = confirmedAt(order).add(const Duration(minutes: 30));

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
                context.sdg(sub.itemsSdg),
                style: theme.textTheme.titleSmall?.copyWith(fontFeatures: AppTypography.tabular),
              ),
            ],
          ),
          Text(
            '${t.orderFrom(isolate(order.buyerName))} · ${t.receivedAgo(core.ago(order.placedAt, now))}',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: Space.sm),
          for (final i in sub.items)
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
                StatusPill(label: core.subOrderStatus(sub.status), tone: shopOrderTone(sub.status)),
              StatusPill(
                label: sub.fulfilment == FulfilmentType.toTechnician && booking != null
                    ? t.toTechWith(
                        isolate(booking.technicianName),
                        context.dayTime(booking.startAt),
                      )
                    : core.fulfilment(sub.fulfilment),
                icon: switch (sub.fulfilment) {
                  FulfilmentType.pickup => Icons.storefront_outlined,
                  FulfilmentType.delivery => Icons.local_shipping_outlined,
                  FulfilmentType.toTechnician => Icons.handyman_outlined,
                },
              ),
              if (order.cashDue)
                StatusPill(label: core.payCash, tone: Tone.warning, icon: Icons.payments_outlined),
            ],
          ),
        ],
      ),
    );
  }
}
