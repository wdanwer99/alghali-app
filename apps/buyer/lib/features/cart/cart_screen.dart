import 'package:alghali_core/alghali_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../router.dart';
import '../../state/cart.dart';
import '../../state/session.dart';
import '../../widgets/buyer_widgets.dart';

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final lines = ref.watch(cartProvider);
    final catalogue = ref.watch(catalogueProvider);
    final shops = <String>{for (final l in lines) l.shopId};

    return Scaffold(
      appBar: AppBar(title: Text(t.navCart)),
      body: lines.isEmpty
          ? EmptyState(
              icon: Icons.shopping_cart_outlined,
              title: t.cartEmpty,
              message: t.cartEmptyBody,
              action: FilledButton.icon(
                onPressed: () => context.push(Routes.search),
                icon: const Icon(Icons.search),
                label: Text(t.cartBrowse),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(Space.page, Space.lg, Space.page, Space.xxl),
              children: [
                for (final shopId in shops) ...[
                  _ShopGroup(
                    shop: catalogue.shop(shopId),
                    lines: lines.where((l) => l.shopId == shopId).toList(),
                  ),
                  const SizedBox(height: Space.md),
                ],
                const _Summary(),
              ],
            ),
      bottomNavigationBar: lines.isEmpty ? null : const _CheckoutBar(),
    );
  }
}

class _ShopGroup extends StatelessWidget {
  const _ShopGroup({required this.shop, required this.lines});

  final Shop shop;
  final List<CartLine> lines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final catalogue = CatalogueScope.of(context);
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => context.push(Routes.shop(shop.id)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Space.md, Space.md, Space.md, Space.sm),
              child: Row(
                children: [
                  Icon(Icons.storefront_outlined, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: Space.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(shop.name.tr(context), style: theme.textTheme.titleSmall),
                        Text(shopPlace(context, catalogue, shop), style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(),
          for (final (i, line) in lines.indexed) ...[
            if (i > 0) const Divider(indent: Space.md, endIndent: Space.md),
            _LineTile(line: line),
          ],
        ],
      ),
    );
  }
}

class _LineTile extends ConsumerWidget {
  const _LineTile({required this.line});

  final CartLine line;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final core = context.core;
    final theme = Theme.of(context);
    final catalogue = ref.watch(catalogueProvider);
    final cart = ref.read(cartProvider.notifier);
    final category = catalogue.category(line.categoryId);
    final job = category.jobType;
    final minLabour = job == null
        ? null
        : [for (final tech in catalogue.technicians) ?tech.labourSdg[job]]
              .fold<int?>(null, (m, p) => m == null || p < m ? p : m);

    return Padding(
      padding: const EdgeInsets.all(Space.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PartThumb(icon: category.icon, size: 60),
              const SizedBox(width: Space.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(line.title.tr(context), style: theme.textTheme.titleSmall),
                    Text(
                      '${core.condition(line.condition)} · ${core.warranty(line.warrantyDays)}',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: Space.xs),
                    Text(
                      context.sdg(line.lineSdg),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontFeatures: AppTypography.tabular,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.sm),
          Row(
            children: [
              QuantityStepper(value: line.qty, onChanged: (q) => cart.setQty(line.id, q)),
              const Spacer(),
              IconButton(
                tooltip: t.cartRemoveItem,
                onPressed: () => cart.remove(line.id),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          if (line.installable && job != null) ...[
            const SizedBox(height: Space.sm),
            line.fitting == null
                ? Row(
                    children: [
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(minimumSize: const Size(0, Hit.min)),
                        onPressed: () => context.push(Routes.bookLine(line.id)),
                        icon: const Icon(Icons.handyman_outlined, size: 20),
                        label: Text(t.cartAddFitting),
                      ),
                      const SizedBox(width: Space.md),
                      if (minLabour != null)
                        Expanded(
                          child: Text(
                            t.cartFittingFrom(context.sdg(minLabour)),
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                    ],
                  )
                : _FittingBlock(line: line),
          ],
        ],
      ),
    );
  }
}

class _FittingBlock extends ConsumerWidget {
  const _FittingBlock({required this.line});

  final CartLine line;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final theme = Theme.of(context);
    final f = line.fitting!;
    final catalogue = ref.watch(catalogueProvider);
    final tech = catalogue.technician(f.technicianId);
    final colors = AppColors.of(context);

    return Container(
      padding: const EdgeInsets.all(Space.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: Radii.mdAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.handyman_outlined, size: 20),
              const SizedBox(width: Space.sm),
              Expanded(
                child: Text(
                  '${t.cartFitting}: ${f.anyTechnician ? t.cartAnyTech : tech.name.tr(context)}',
                  style: theme.textTheme.titleSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.xs),
          Text(
            '${context.dayTime(f.slot.start)} · ${f.place == BookingPlace.bay ? t.placeBay : t.placeHome}',
            style: theme.textTheme.bodyMedium,
          ),
          Text(
            '${t.costLabour}: ${context.sdg(f.labourSdg)}'
            '${f.travelFeeSdg > 0 ? ' · ${t.costTravel}: ${context.sdg(f.travelFeeSdg)}' : ''}',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: Space.xs),
          Countdown(
            until: f.heldUntil,
            builder: (context, left) => left == Duration.zero
                ? Text(
                    t.cartHoldExpired,
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                  )
                : Row(
                    children: [
                      Icon(Icons.timer_outlined, size: 16, color: colors.warning),
                      const SizedBox(width: Space.xs),
                      Text(
                        t.cartHeldFor(clockText(left)),
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: colors.warning,
                          fontFeatures: AppTypography.tabular,
                        ),
                      ),
                    ],
                  ),
          ),
          Row(
            children: [
              TextButton(
                onPressed: () => context.push(Routes.bookLine(line.id)),
                child: Text(t.cartChange),
              ),
              TextButton(
                onPressed: () => ref.read(cartProvider.notifier).removeFitting(line.id),
                child: Text(t.cartRemoveFitting),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Summary extends ConsumerWidget {
  const _Summary();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final totals = ref.watch(cartTotalsProvider);
    return SectionCard(
      title: t.cartSummary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          KeyValueRow(label: t.costParts, value: context.sdg(totals.partsSdg)),
          if (totals.labourSdg > 0)
            KeyValueRow(label: t.costLabour, value: context.sdg(totals.labourSdg)),
          if (totals.travelSdg > 0)
            KeyValueRow(label: t.costTravel, value: context.sdg(totals.travelSdg)),
          if (totals.bookingFeeSdg > 0)
            KeyValueRow(label: t.costBookingFee, value: context.sdg(totals.bookingFeeSdg)),
          const Divider(height: Space.xl),
          KeyValueRow(label: t.costTotal, value: context.sdg(totals.totalSdg), emphasis: true),
          const SizedBox(height: Space.sm),
          Text(t.cartDeliveryLater, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _CheckoutBar extends ConsumerWidget {
  const _CheckoutBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final lines = ref.watch(cartProvider);
    final totals = ref.watch(cartTotalsProvider);
    final signedIn = ref.watch(sessionProvider.select((s) => s.signedIn));
    final holds = [for (final l in lines) ?l.fitting?.heldUntil]..sort();

    Widget bar(bool expired) => BottomActionBar(
      top: Row(
        children: [
          Expanded(child: Text(t.costTotal, style: Theme.of(context).textTheme.titleMedium)),
          Text(
            context.sdg(totals.totalSdg),
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontFeatures: AppTypography.tabular),
          ),
        ],
      ),
      child: FilledButton(
        onPressed: expired
            ? null
            : () => context.push(signedIn ? Routes.checkout : Routes.signInThen(Routes.checkout)),
        child: Text(signedIn ? t.cartCheckout : t.checkoutSignIn),
      ),
    );

    if (holds.isEmpty) return bar(false);
    return Countdown(until: holds.first, builder: (context, left) => bar(left == Duration.zero));
  }
}
