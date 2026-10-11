import 'dart:async';

import 'package:alghali_core/alghali_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../router.dart';
import '../../state/cart.dart';
import '../../state/orders.dart';
import '../../widgets/buyer_widgets.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final _fulfil = <String, FulfilmentType>{};
  Address? _address;
  var _method = PaymentMethod.bankak;
  var _placing = false;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final core = context.core;
    final theme = Theme.of(context);
    final catalogue = ref.watch(catalogueProvider);
    final settings = ref.watch(platformSettingsProvider);
    final lines = ref.watch(cartProvider);
    final totals = ref.watch(cartTotalsProvider);
    final addresses = ref.watch(addressesProvider);
    final shops = <String>{for (final l in lines) l.shopId}.toList();

    if (lines.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(t.checkoutTitle)),
        body: EmptyState(icon: Icons.shopping_cart_outlined, title: t.cartEmpty),
      );
    }

    bool hasFitting(String shopId) => lines.any((l) => l.shopId == shopId && l.fitting != null);
    FulfilmentType mode(String shopId) =>
        hasFitting(shopId) ? FulfilmentType.toTechnician : _fulfil[shopId] ?? FulfilmentType.pickup;
    final anyDelivery = shops.any((s) => mode(s) == FulfilmentType.delivery);
    final address = _address ?? addresses.first;
    final deliveryFee = settings.deliveryFee(address.distanceKm) ?? 0;
    final deliverySdg = shops.where((s) => mode(s) == FulfilmentType.delivery).length * deliveryFee;
    final total = totals.totalSdg + deliverySdg;
    final homeFittings = lines.where((l) => l.fitting?.place == BookingPlace.customer).length;
    final deposit = _method == PaymentMethod.cash ? homeFittings * settings.mobileDepositSdg : 0;
    final dueNow = _method == PaymentMethod.bankak ? total : deposit;

    Future<void> place() async {
      setState(() => _placing = true);
      await Future<void>.delayed(const Duration(milliseconds: 300));
      if (!context.mounted) return;
      final order = ref
          .read(ordersProvider.notifier)
          .place(
            lines: lines,
            choice: CheckoutChoice(
              method: _method,
              fulfilment: {for (final s in shops) s: mode(s)},
              deliveryAddress: anyDelivery ? address : null,
            ),
          );
      // Land on My orders, with payment (or the order) on top, so Back makes sense.
      context.go(Routes.orders);
      unawaited(
        context.push(order.needsTransfer ? Routes.payOrder(order.id) : Routes.order(order.id)),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(t.checkoutTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Space.page, Space.lg, Space.page, Space.xxl),
        children: [
          SectionCard(
            title: t.checkoutReceive,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, shopId) in shops.indexed) ...[
                  if (i > 0) const Divider(height: Space.xxl),
                  Text(catalogue.shop(shopId).name.tr(context), style: theme.textTheme.titleSmall),
                  const SizedBox(height: Space.sm),
                  if (hasFitting(shopId))
                    InfoBanner(
                      tone: Tone.neutral,
                      icon: Icons.handyman_outlined,
                      message: t.checkoutToTechBody,
                    )
                  else ...[
                    ChoiceCard(
                      selected: mode(shopId) == FulfilmentType.pickup,
                      onTap: () => setState(() => _fulfil[shopId] = FulfilmentType.pickup),
                      icon: Icons.storefront_outlined,
                      title: core.fulfilPickup,
                      subtitle: t.checkoutPickupBody(
                        shopPlace(context, catalogue, catalogue.shop(shopId)),
                      ),
                    ),
                    const SizedBox(height: Space.sm),
                    ChoiceCard(
                      selected: mode(shopId) == FulfilmentType.delivery,
                      onTap: () => setState(() => _fulfil[shopId] = FulfilmentType.delivery),
                      icon: Icons.local_shipping_outlined,
                      title: core.fulfilDelivery,
                      subtitle: t.checkoutDeliveryTo(address.label.tr(context)),
                      trailing: Text(context.sdg(deliveryFee), style: theme.textTheme.labelMedium),
                    ),
                  ],
                ],
                if (anyDelivery) ...[
                  const SizedBox(height: Space.lg),
                  Text(t.bookAddress, style: theme.textTheme.titleSmall),
                  const SizedBox(height: Space.sm),
                  for (final a in addresses) ...[
                    ChoiceCard(
                      selected: address.id == a.id,
                      onTap: () => setState(() => _address = a),
                      icon: Icons.location_on_outlined,
                      title: a.label.tr(context),
                      subtitle: a.description.tr(context),
                    ),
                    const SizedBox(height: Space.sm),
                  ],
                ],
              ],
            ),
          ),
          const SizedBox(height: Space.md),
          SectionCard(
            title: t.checkoutPayment,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ChoiceCard(
                  selected: _method == PaymentMethod.bankak,
                  onTap: () => setState(() => _method = PaymentMethod.bankak),
                  icon: Icons.account_balance_outlined,
                  title: t.checkoutBankak,
                  subtitle: t.checkoutBankakBody,
                ),
                const SizedBox(height: Space.sm),
                ChoiceCard(
                  selected: _method == PaymentMethod.cash,
                  onTap: () => setState(() => _method = PaymentMethod.cash),
                  icon: Icons.payments_outlined,
                  title: t.checkoutCash,
                  subtitle: t.checkoutCashBody,
                ),
                if (deposit > 0) ...[
                  const SizedBox(height: Space.sm),
                  InfoBanner(
                    tone: Tone.info,
                    message: t.bookDepositNote(context.sdg(settings.mobileDepositSdg)),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: Space.md),
          SectionCard(
            title: t.cartSummary,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final l in lines)
                  KeyValueRow(
                    label: '${l.title.tr(context)} × ${l.qty}',
                    value: context.sdg(l.lineSdg),
                  ),
                const Divider(height: Space.xl),
                KeyValueRow(label: t.costParts, value: context.sdg(totals.partsSdg)),
                if (deliverySdg > 0)
                  KeyValueRow(label: t.costDelivery, value: context.sdg(deliverySdg)),
                if (totals.labourSdg > 0)
                  KeyValueRow(label: t.costLabour, value: context.sdg(totals.labourSdg)),
                if (totals.travelSdg > 0)
                  KeyValueRow(label: t.costTravel, value: context.sdg(totals.travelSdg)),
                if (totals.bookingFeeSdg > 0)
                  KeyValueRow(label: t.costBookingFee, value: context.sdg(totals.bookingFeeSdg)),
                const Divider(height: Space.xl),
                KeyValueRow(label: t.costTotal, value: context.sdg(total), emphasis: true),
                if (dueNow > 0 && dueNow != total) ...[
                  KeyValueRow(label: t.checkoutDueNow, value: context.sdg(dueNow)),
                  KeyValueRow(label: t.checkoutRestCash, value: context.sdg(total - dueNow)),
                ],
              ],
            ),
          ),
          if (dueNow > 0) ...[
            const SizedBox(height: Space.md),
            InfoBanner(
              tone: Tone.warning,
              icon: Icons.timer_outlined,
              message: t.checkoutPayWithin,
            ),
          ],
          const SizedBox(height: Space.md),
          Text(t.checkoutTerms, style: theme.textTheme.bodySmall, textAlign: TextAlign.center),
        ],
      ),
      bottomNavigationBar: BottomActionBar(
        top: Row(
          children: [
            Expanded(child: Text(t.costTotal, style: theme.textTheme.titleMedium)),
            Text(
              context.sdg(total),
              style: theme.textTheme.titleLarge?.copyWith(fontFeatures: AppTypography.tabular),
            ),
          ],
        ),
        child: FilledButton(
          onPressed: _placing ? null : place,
          child: _placing
              ? const SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                )
              : Text(t.checkoutPlace),
        ),
      ),
    );
  }
}
