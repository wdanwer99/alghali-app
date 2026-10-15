import 'package:alghali_core/alghali_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../router.dart';
import '../../state/inbox.dart';
import '../../state/shop.dart';
import '../../widgets/partner_widgets.dart';

class ShopOrderScreen extends ConsumerStatefulWidget {
  const ShopOrderScreen({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<ShopOrderScreen> createState() => _ShopOrderScreenState();
}

class _ShopOrderScreenState extends ConsumerState<ShopOrderScreen> {
  var _busy = false;

  /// Runs one step; the server checks it, and a refusal is explained.
  Future<void> _act(Future<void> Function(ShopOrdersController orders) step, String done) async {
    setState(() => _busy = true);
    try {
      await step(ref.read(shopOrdersProvider.notifier));
      if (mounted) showSnack(context, done);
    } on BackendException catch (e) {
      if (!mounted) return;
      showError(context, e);
      // The order may have moved on elsewhere (cancelled, paid back): show where it is.
      await ref.read(shopOrdersProvider.notifier).refresh();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reject(ShopSubOrder order) async {
    final t = context.t;
    final reason = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const _RejectSheet(),
    );
    if (reason == null || !mounted) return;
    await _act((o) => o.reject(order.id, reason), t.orderRejected);
  }

  Future<void> _chat(ShopSubOrder order) async {
    try {
      final id = await ref.read(shopChatsProvider.notifier).startFor(order.id);
      if (mounted) await context.push(Routes.shopChat(id));
    } on BackendException catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final core = context.core;
    final theme = Theme.of(context);
    final value = ref.watch(shopOrdersProvider);
    final order = ref.watch(shopOrderProvider(widget.orderId));
    if (order == null) {
      return Scaffold(
        appBar: AppBar(),
        body: value.isLoading
            ? const SkeletonList()
            : EmptyState(
                icon: Icons.inbox_outlined,
                title: t.orderNotHere,
                action: OutlinedButton.icon(
                  onPressed: () => ref.read(shopOrdersProvider.notifier).refresh(),
                  icon: const Icon(Icons.refresh),
                  label: Text(core.actionRetry),
                ),
              ),
      );
    }
    final settings = ref.watch(platformSettingsProvider);
    final sub = order.subOrder;
    final booking = order.booking;
    final address = order.address;
    final techAccepted =
        booking != null &&
        const {
          BookingStatus.accepted,
          BookingStatus.enRoute,
          BookingStatus.inProgress,
        }.contains(booking.status);

    final actions = <Widget>[
      if (order.isNew) ...[
        Expanded(
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(foregroundColor: theme.colorScheme.error),
            onPressed: _busy ? null : () => _reject(order),
            child: Text(t.orderReject),
          ),
        ),
        const SizedBox(width: Space.md),
        Expanded(
          flex: 2,
          child: FilledButton(
            onPressed: _busy ? null : () => _act((o) => o.accept(order.id), t.orderAccepted),
            child: Text(t.orderAccept),
          ),
        ),
      ] else if (order.isPreparing)
        Expanded(
          child: FilledButton(
            onPressed: _busy ? null : () => _act((o) => o.markReady(order.id), t.orderMarkedReady),
            child: Text(t.markReady),
          ),
        )
      else if (order.isReady)
        Expanded(
          child: FilledButton(
            onPressed: _busy || (sub.fulfilment == FulfilmentType.toTechnician && !techAccepted)
                ? null
                : () => _act((o) => o.handOver(order.id), t.orderHandedOver),
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
            onPressed: _busy
                ? null
                : () => _act((o) => o.markDelivered(order.id), t.orderDelivered),
            child: Text(t.markDelivered),
          ),
        ),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(t.orderRef(formatRef(order.ref)))),
      body: RefreshIndicator(
        onRefresh: () => ref.read(shopOrdersProvider.notifier).refresh(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Space.page, Space.lg, Space.page, Space.xxl),
          children: [
            if (sub.cancelReason != null &&
                (sub.status == SubOrderStatus.cancelled ||
                    sub.status == SubOrderStatus.rejectedByShop)) ...[
              InfoBanner(tone: Tone.neutral, icon: Icons.block, message: sub.cancelReason!),
              const SizedBox(height: Space.md),
            ],
            if (sub.returnRequest case final r?) ...[
              InfoBanner(
                tone: Tone.warning,
                icon: Icons.assignment_return_outlined,
                message: t.returnRequested(r.reason),
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
                    ContactActions(live: true, phone: order.buyerPhone, onChat: () => _chat(order)),
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
                  if (booking != null) ...[
                    const SizedBox(height: Space.sm),
                    Text(
                      t.toTechWith(
                        isolate(booking.technicianName),
                        context.dayTime(booking.startAt),
                      ),
                      style: theme.textTheme.bodyMedium,
                    ),
                    if (!techAccepted && order.isReady) ...[
                      const SizedBox(height: Space.sm),
                      InfoBanner(tone: Tone.warning, message: t.waitTechAccept),
                    ],
                    if (booking.technicianPhone != null) ...[
                      const SizedBox(height: Space.sm),
                      OutlinedButton.icon(
                        onPressed: () => Launch.call(booking.technicianPhone!),
                        icon: const Icon(Icons.call_outlined),
                        label: Text(t.callTechnician),
                      ),
                    ],
                  ],
                  if (address != null) ...[
                    const SizedBox(height: Space.sm),
                    Text(
                      [
                        address.label,
                        address.directions ?? '',
                      ].where((s) => s.isNotEmpty).join(' — '),
                      style: theme.textTheme.bodyMedium,
                    ),
                    if (address.lat != null && address.lng != null) ...[
                      const SizedBox(height: Space.sm),
                      OutlinedButton.icon(
                        onPressed: () => Launch.directions(address.lat!, address.lng!),
                        icon: const Icon(Icons.directions_outlined),
                        label: Text(core.actionDirections),
                      ),
                    ],
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
                    value: '−${context.sdg(order.commissionSdg)}',
                  ),
                  if (sub.deliveryFeeSdg > 0)
                    KeyValueRow(label: core.fulfilDelivery, value: context.sdg(sub.deliveryFeeSdg)),
                  const Divider(height: Space.xl),
                  KeyValueRow(
                    label: t.youReceive,
                    value: context.sdg(order.shopGetsSdg),
                    emphasis: true,
                  ),
                  const SizedBox(height: Space.sm),
                  InfoBanner(
                    tone: order.cashDue ? Tone.warning : Tone.success,
                    icon: order.cashDue ? Icons.payments_outlined : Icons.account_balance_outlined,
                    message: order.method == PaymentMethod.cash
                        ? (sub.fulfilment == FulfilmentType.toTechnician
                              ? t.cashFromTech(context.sdg(sub.itemsSdg))
                              : order.cashDue
                              ? t.collectCash(context.sdg(sub.itemsSdg + sub.deliveryFeeSdg))
                              : t.cashCollected)
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

/// Why the shop declines: the buyer reads it as written.
class _RejectSheet extends StatefulWidget {
  const _RejectSheet();

  @override
  State<_RejectSheet> createState() => _RejectSheetState();
}

class _RejectSheetState extends State<_RejectSheet> {
  var _reason = 0;
  final _other = TextEditingController();

  @override
  void dispose() {
    _other.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final reasons = [t.rejectOutOfStock, t.rejectPrice, t.rejectOther];
    final other = _reason == reasons.length - 1;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
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
                    for (final (i, label) in reasons.indexed)
                      RadioListTile<int>(
                        value: i,
                        title: Text(label),
                        contentPadding: EdgeInsets.zero,
                      ),
                  ],
                ),
              ),
              if (other) ...[
                TextField(
                  controller: _other,
                  maxLines: 2,
                  maxLength: 300,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(labelText: t.rejectOtherLabel),
                ),
                const SizedBox(height: Space.sm),
              ],
              InfoBanner(tone: Tone.warning, message: t.rejectNote),
              const SizedBox(height: Space.lg),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
                onPressed: other && _other.text.trim().isEmpty
                    ? null
                    : () => Navigator.pop(context, other ? _other.text.trim() : reasons[_reason]),
                child: Text(t.orderReject),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
