import 'package:alghali_core/alghali_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../router.dart';
import '../../state/bookings.dart';
import '../../state/orders.dart';
import '../../state/requests.dart';
import '../../state/session.dart';
import '../../widgets/buyer_widgets.dart';

/// Orders · Bookings · Photo requests.
class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key, this.tab});

  final String? tab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final signedIn = ref.watch(sessionProvider.select((s) => s.signedIn));
    if (!signedIn) {
      return Scaffold(
        appBar: AppBar(title: Text(t.navOrders)),
        body: EmptyState(
          icon: Icons.receipt_long_outlined,
          title: t.ordersSignIn,
          message: t.ordersSignInBody,
          action: FilledButton(
            onPressed: () => context.push(Routes.signIn),
            child: Text(t.accountSignIn),
          ),
        ),
      );
    }
    return DefaultTabController(
      length: 3,
      initialIndex: switch (tab) {
        'bookings' => 1,
        'requests' => 2,
        _ => 0,
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(t.navOrders),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: t.ordersTabOrders),
              Tab(text: t.ordersTabBookings),
              Tab(text: t.ordersTabRequests),
            ],
          ),
        ),
        body: const TabBarView(children: [_OrdersTab(), _BookingsTab(), _RequestsTab()]),
      ),
    );
  }
}

class _OrdersTab extends ConsumerWidget {
  const _OrdersTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    return AsyncBody(
      value: ref.watch(ordersProvider),
      onRefresh: () => ref.read(ordersProvider.notifier).refresh(),
      data: (orders) => orders.isEmpty
          ? ListView(
              children: [
                EmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: t.ordersEmpty,
                  message: t.ordersEmptyBody,
                ),
              ],
            )
          : _list(context, orders),
    );
  }

  Widget _list(BuildContext context, List<Order> orders) {
    final t = context.t;
    final core = context.core;
    final theme = Theme.of(context);
    return ListView.separated(
      padding: Space.pageInsets,
      itemCount: orders.length,
      separatorBuilder: (_, _) => const SizedBox(height: Space.sm),
      itemBuilder: (context, i) {
        final o = orders[i];
        // An order for a fitting alone has no shop parts (D-097).
        final status = o.subOrders.firstOrNull?.status;
        return TapCard(
          key: ValueKey(o.id),
          onTap: () => context.push(Routes.order(o.id)),
          child: Row(
            children: [
              const IconTile(icon: Icons.receipt_long_outlined),
              const SizedBox(width: Space.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.orderRef(formatRef(o.ref)), style: theme.textTheme.titleSmall),
                    Text(
                      status == null
                          ? '${context.date(o.createdAt)} · ${t.orderFitting}'
                          : '${context.date(o.createdAt)} · ${t.itemsCount(o.itemCount)} · ${t.shopsCount(o.subOrders.length)}',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: Space.xs),
                    Wrap(
                      spacing: Space.xs,
                      runSpacing: Space.xs,
                      children: [
                        if (status != null)
                          StatusPill(
                            label: core.subOrderStatus(status),
                            tone: subOrderTone(status),
                          ),
                        if (o.needsTransfer || o.receiptBeingChecked)
                          StatusPill(
                            label: core.paymentStatus(o.bankakStatus),
                            tone: paymentTone(o.bankakStatus),
                            icon: Icons.account_balance_outlined,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Space.sm),
              Text(
                context.sdg(o.totalSdg),
                style: theme.textTheme.titleSmall?.copyWith(fontFeatures: AppTypography.tabular),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BookingsTab extends ConsumerWidget {
  const _BookingsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    return AsyncBody(
      value: ref.watch(bookingsProvider),
      onRefresh: () => ref.read(bookingsProvider.notifier).refresh(),
      data: (list) {
        if (list.isEmpty) {
          return ListView(
            children: [
              EmptyState(
                icon: Icons.handyman_outlined,
                title: t.bookingsEmpty,
                message: t.bookingsEmptyBody,
                action: OutlinedButton(
                  onPressed: () => context.push(Routes.bookExternal),
                  child: Text(t.homeQuickBookTitle),
                ),
              ),
            ],
          );
        }
        final bookings = [...list]
          ..sort(
            (a, b) =>
                a.isActive == b.isActive ? b.startAt.compareTo(a.startAt) : (a.isActive ? -1 : 1),
          );
        return _list(context, bookings);
      },
    );
  }

  Widget _list(BuildContext context, List<Booking> bookings) {
    final t = context.t;
    final core = context.core;
    final theme = Theme.of(context);
    return ListView.separated(
      padding: Space.pageInsets,
      itemCount: bookings.length,
      separatorBuilder: (_, _) => const SizedBox(height: Space.sm),
      itemBuilder: (context, i) {
        final b = bookings[i];
        final local = toKhartoum(b.startAt);
        return TapCard(
          key: ValueKey(b.id),
          onTap: () => context.push(Routes.booking(b.id)),
          child: Row(
            children: [
              Container(
                width: 56,
                padding: const EdgeInsets.symmetric(vertical: Space.sm),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainer,
                  borderRadius: Radii.mdAll,
                ),
                child: Column(
                  children: [
                    Text('${local.day}', style: theme.textTheme.titleLarge?.copyWith(height: 1.1)),
                    Text(context.time(b.startAt), style: theme.textTheme.labelSmall),
                  ],
                ),
              ),
              const SizedBox(width: Space.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(b.items.first.title.tr(context), style: theme.textTheme.titleSmall),
                    Text(
                      '${b.technicianName} · ${b.place == BookingPlace.bay ? t.placeBay : t.placeHome}',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: Space.xs),
                    StatusPill(label: core.bookingStatus(b.status), tone: bookingTone(b.status)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RequestsTab extends ConsumerWidget {
  const _RequestsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final theme = Theme.of(context);
    final now = ref.watch(clockProvider)();
    return AsyncBody(
      value: ref.watch(requestsProvider),
      onRefresh: () => ref.read(requestsProvider.notifier).refresh(),
      data: (requests) => ListView(
        padding: Space.pageInsets,
        children: [
          OutlinedButton.icon(
            onPressed: () => context.push(Routes.newRequest),
            icon: const Icon(Icons.add_a_photo_outlined),
            label: Text(t.requestNewTitle),
          ),
          const SizedBox(height: Space.md),
          if (requests.isEmpty)
            EmptyState(
              icon: Icons.photo_camera_outlined,
              title: t.requestsEmpty,
              message: t.requestsEmptyBody,
            )
          else
            for (final r in requests) ...[
              TapCard(
                key: ValueKey(r.id),
                onTap: () => context.push(Routes.request(r.id)),
                child: Row(
                  children: [
                    const IconTile(icon: Icons.photo_camera_outlined),
                    const SizedBox(width: Space.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r.note,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall,
                          ),
                          Text(
                            context.core.ago(r.createdAt, now),
                            style: theme.textTheme.bodySmall,
                          ),
                          const SizedBox(height: Space.xs),
                          StatusPill(
                            label: t.requestOffers(r.offers.where((o) => o.live).length),
                            tone: r.offers.any((o) => o.live) ? Tone.brand : Tone.neutral,
                            icon: Icons.local_offer_outlined,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Space.sm),
            ],
        ],
      ),
    );
  }
}
