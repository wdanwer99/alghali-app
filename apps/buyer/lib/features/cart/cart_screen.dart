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
    final cart = ref.watch(cartProvider);
    final lines = cart.lines;
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
                if (cart.fitting != null) ...[
                  _FittingBlock(fitting: cart.fitting!),
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
    final cart = ref.watch(cartProvider);
    final notifier = ref.read(cartProvider.notifier);
    final category = catalogue.category(line.categoryId);
    final fittable = line.installable && category.jobType != null;
    final fitted = cart.fitted(line.id);

    void remove() {
      if (notifier.remove(line.id)) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(t.cartFittingDropped)));
      }
    }

    return Padding(
      padding: const EdgeInsets.all(Space.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PartThumb(icon: category.icon, size: 60, imageUrl: thumbUrl(ref, line.imageKey)),
              const SizedBox(width: Space.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(line.title.tr(context), style: theme.textTheme.titleSmall),
                    Text(switch (line.tint) {
                      final tint? => core.tintSummary(tint),
                      null =>
                        '${core.condition(line.condition)} · ${core.warranty(line.warrantyDays)}',
                    }, style: theme.textTheme.bodySmall),
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
              if (line.offerId == null && line.tint == null)
                QuantityStepper(value: line.qty, onChanged: (q) => notifier.setQty(line.id, q)),
              const Spacer(),
              IconButton(
                tooltip: t.cartRemoveItem,
                onPressed: remove,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          if (fitted)
            Row(
              children: [
                Icon(Icons.handyman_outlined, size: 18, color: AppColors.of(context).success),
                const SizedBox(width: Space.sm),
                Expanded(child: Text(t.cartInFitting, style: theme.textTheme.bodySmall)),
              ],
            )
          else if (fittable) ...[
            if (line.tint != null) ...[
              InfoBanner(tone: Tone.warning, message: t.cartTintNeedsFitting),
              const SizedBox(height: Space.sm),
            ],
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, Hit.min)),
                onPressed: () => context.push(Routes.bookLine(line.id)),
                icon: const Icon(Icons.handyman_outlined, size: 20),
                label: Text(cart.fitting == null ? t.cartAddFitting : t.cartAddToFitting),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FittingBlock extends ConsumerWidget {
  const _FittingBlock({required this.fitting});

  final FittingDraft fitting;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final now = ref.watch(clockProvider)();
    final b = fitting.booking;
    final where = b.place == BookingPlace.bay
        ? t.bookAtBay(b.bayName?.tr(context) ?? '')
        : b.address?.label.tr(context) ?? t.placeHome;

    return SectionCard(
      title: t.cartFitting,
      trailing: const Icon(Icons.handyman_outlined),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            fitting.anyTechnician ? '${t.cartAnyTech} · ${b.technicianName}' : b.technicianName,
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: Space.xs),
          Text('${context.dayTime(b.startAt)} · $where', style: theme.textTheme.bodyMedium),
          Text(
            '${t.costLabour}: ${context.sdg(b.labourSdg)}'
            '${b.travelFeeSdg > 0 ? ' · ${t.costTravel}: ${context.sdg(b.travelFeeSdg)}' : ''}',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: Space.xs),
          Countdown(
            until: fitting.heldUntil(now),
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
                onPressed: () => context.push(Routes.bookLine(fitting.lineIds.first)),
                child: Text(t.cartChange),
              ),
              TextButton(
                onPressed: () => ref.read(cartProvider.notifier).releaseFitting(),
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
    final cart = ref.watch(cartProvider);
    final totals = ref.watch(cartTotalsProvider);
    final signedIn = ref.watch(sessionProvider.select((s) => s.signedIn));
    final now = ref.watch(clockProvider)();
    // Window tint is always fitted (D-149): no checkout until its fitting is booked.
    final tintUnfitted = cart.lines.any((l) => l.tint != null && !cart.fitted(l.id));

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
        onPressed: expired || tintUnfitted
            ? null
            : () => context.push(signedIn ? Routes.checkout : Routes.signInThen(Routes.checkout)),
        child: Text(signedIn ? t.cartCheckout : t.checkoutSignIn),
      ),
    );

    final f = cart.fitting;
    if (f == null) return bar(false);
    return Countdown(
      until: f.heldUntil(now),
      builder: (context, left) => bar(left == Duration.zero),
    );
  }
}
