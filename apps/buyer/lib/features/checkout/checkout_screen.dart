import 'dart:async';

import 'package:alghali_core/alghali_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../router.dart';
import '../../state/account.dart';
import '../../state/cart.dart';
import '../../state/orders.dart';
import '../../widgets/buyer_widgets.dart';
import '../account/address_sheet.dart';
import '../account/profile_sheet.dart';

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
  var _changed = false;

  /// One key per attempt at this cart: retrying after a lost answer can't order twice.
  var _idem = newIdempotencyKey();

  @override
  void initState() {
    super.initState();
    unawaited(_recheck());
  }

  /// Prices and stock change often (brief §1): check before the buyer confirms.
  Future<void> _recheck() async {
    final lines = ref.read(cartProvider).lines;
    if (lines.isEmpty) return;
    try {
      final checks = await ref.read(ordersRepositoryProvider).validate([
        for (final l in lines) l.checkoutLine,
      ]);
      if (!mounted) return;
      if (checks.any((c) => !c.ok)) {
        ref.read(cartProvider.notifier).applyChecks(checks);
        setState(() {
          _changed = true;
          _idem = newIdempotencyKey();
        });
      }
    } on BackendException {
      // Offline: checkout itself checks again.
    }
  }

  /// The delivery fee for [shop] to [a] (D-087): from the shop's pin, else the street's
  /// starting point; null when delivery isn't possible.
  int? _deliveryFee(PlatformSettings settings, CatalogueData catalogue, Shop shop, Address? a) {
    if (a == null || a.lat == null || a.lng == null) return null;
    final from = shop.lat != null && shop.lng != null
        ? (lat: shop.lat!, lng: shop.lng!)
        : catalogue.streetOrigin;
    if (from == null) return null;
    return settings.deliveryFee(distanceKm(from.lat, from.lng, a.lat!, a.lng!));
  }

  Future<void> _place(Map<String, FulfilmentType> fulfilment, bool anyDelivery) async {
    setState(() => _placing = true);
    try {
      final order = await ref
          .read(ordersProvider.notifier)
          .checkout(
            CheckoutChoice(
              method: _method,
              fulfilment: fulfilment,
              addressId: anyDelivery ? _address?.id : null,
            ),
            idem: _idem,
          );
      if (!mounted) return;
      // Land on My orders, with payment (or the order) on top, so Back makes sense.
      context.go(Routes.orders);
      unawaited(
        context.push(order.needsTransfer ? Routes.payOrder(order.id) : Routes.order(order.id)),
      );
    } on CartChangedException {
      if (!mounted) return;
      setState(() {
        _changed = true;
        _idem = newIdempotencyKey();
      });
    } on BackendException catch (e) {
      if (!mounted) return;
      if (e.code == 'PHONE_REQUIRED') {
        await showProfileSheet(context, askPhone: true);
      } else {
        showError(context, e);
      }
    } finally {
      if (mounted) setState(() => _placing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final core = context.core;
    final theme = Theme.of(context);
    final catalogue = ref.watch(catalogueProvider);
    final settings = ref.watch(platformSettingsProvider);
    final cart = ref.watch(cartProvider);
    final lines = cart.lines;
    final totals = ref.watch(cartTotalsProvider);
    final addresses = ref.watch(addressesProvider).value ?? const <Address>[];
    final shops = <String>{for (final l in lines) l.shopId}.toList();

    if (lines.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(t.checkoutTitle)),
        body: EmptyState(icon: Icons.shopping_cart_outlined, title: t.cartEmpty),
      );
    }

    bool hasFitting(String shopId) => lines.any((l) => l.shopId == shopId && cart.fitted(l.id));
    final address =
        _address ?? addresses.where((a) => a.isDefault).firstOrNull ?? addresses.firstOrNull;
    int? feeFor(String shopId) =>
        _deliveryFee(settings, catalogue, catalogue.shop(shopId), address);
    FulfilmentType mode(String shopId) {
      if (hasFitting(shopId)) return FulfilmentType.toTechnician;
      final chosen = _fulfil[shopId] ?? FulfilmentType.pickup;
      return chosen == FulfilmentType.delivery && feeFor(shopId) == null
          ? FulfilmentType.pickup
          : chosen;
    }

    final anyDelivery = shops.any((s) => mode(s) == FulfilmentType.delivery);
    final deliverySdg = [
      for (final s in shops)
        if (mode(s) == FulfilmentType.delivery) feeFor(s) ?? 0,
    ].fold(0, (a, b) => a + b);
    final total = totals.totalSdg + deliverySdg;
    final homeFitting = cart.fitting?.place == BookingPlace.customer;
    final deposit = _method == PaymentMethod.cash && homeFitting ? settings.mobileDepositSdg : 0;
    final dueNow = _method == PaymentMethod.bankak ? total : deposit;

    return Scaffold(
      appBar: AppBar(title: Text(t.checkoutTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Space.page, Space.lg, Space.page, Space.xxl),
        children: [
          if (_changed) ...[
            InfoBanner(
              tone: Tone.warning,
              icon: Icons.price_change_outlined,
              message: core.errCartChanged,
            ),
            const SizedBox(height: Space.md),
          ],
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
                      onTap: address == null
                          ? () async {
                              final a = await showAddressSheet(context);
                              if (a != null && mounted) {
                                setState(() {
                                  _address = a;
                                  _fulfil[shopId] = FulfilmentType.delivery;
                                });
                              }
                            }
                          : feeFor(shopId) == null
                          ? null
                          : () => setState(() => _fulfil[shopId] = FulfilmentType.delivery),
                      icon: Icons.local_shipping_outlined,
                      title: core.fulfilDelivery,
                      subtitle: address == null
                          ? t.checkoutAddAddress
                          : feeFor(shopId) == null
                          ? core.errDeliveryUnavailable
                          : t.checkoutDeliveryTo(address.label.tr(context)),
                      trailing: feeFor(shopId) == null
                          ? null
                          : Text(context.sdg(feeFor(shopId)!), style: theme.textTheme.labelMedium),
                    ),
                  ],
                ],
                if (anyDelivery) ...[
                  const SizedBox(height: Space.lg),
                  Text(t.bookAddress, style: theme.textTheme.titleSmall),
                  const SizedBox(height: Space.sm),
                  for (final a in addresses) ...[
                    ChoiceCard(
                      selected: address?.id == a.id,
                      onTap: () => setState(() => _address = a),
                      icon: Icons.location_on_outlined,
                      title: a.label.tr(context),
                      subtitle: a.description.tr(context),
                    ),
                    const SizedBox(height: Space.sm),
                  ],
                  TextButton.icon(
                    onPressed: () async {
                      final a = await showAddressSheet(context);
                      if (a != null && mounted) setState(() => _address = a);
                    },
                    icon: const Icon(Icons.add_location_alt_outlined),
                    label: Text(t.addressNew),
                  ),
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
                    label: l.tint != null
                        ? lineTitle(context, l)
                        : '${l.title.tr(context)} × ${l.qty}',
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
              message: t.checkoutPayWithinMinutes(settings.paymentWindowMinutes),
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
          onPressed: _placing
              ? null
              : () => _place({for (final s in shops) s: mode(s)}, anyDelivery),
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
