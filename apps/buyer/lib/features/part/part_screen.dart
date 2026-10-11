import 'package:alghali_core/alghali_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../router.dart';
import '../../state/cart.dart';
import '../../state/garage.dart';
import '../../widgets/buyer_widgets.dart';

/// One part, every shop that sells it (cheapest first), and the fit verdict
/// for the buyer's car.
class PartScreen extends ConsumerWidget {
  const PartScreen({super.key, required this.partId});

  final String partId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final core = context.core;
    final theme = Theme.of(context);
    final catalogue = ref.watch(catalogueProvider);
    final variantId = ref.watch(selectedVariantProvider);
    final part = catalogue.part(partId);
    final category = catalogue.category(part.categoryId);
    final fit = catalogue.fitOf(part, variantId);
    final listings = catalogue.listingsOf(partId).where((l) => l.inStock).toList();
    final minLabour = _minLabour(catalogue, category.jobType);
    final car = variantId == null ? null : carLabel(context, catalogue, variantId, engine: false);

    return Scaffold(
      appBar: AppBar(title: Text(category.name.tr(context))),
      body: ListView(
        padding: const EdgeInsets.only(bottom: Space.xxl),
        children: [
          Container(
            color: theme.colorScheme.surface,
            padding: const EdgeInsets.all(Space.page),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(child: PartThumb(icon: category.icon, size: 168)),
                const SizedBox(height: Space.lg),
                Text(part.name.tr(context), style: theme.textTheme.headlineSmall),
                const SizedBox(height: Space.sm),
                if (listings.isNotEmpty)
                  Text(
                    core.moneyFrom(context.sdg(listings.first.priceSdg)),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontFeatures: AppTypography.tabular,
                    ),
                  ),
                const SizedBox(height: Space.md),
                switch (fit) {
                  Fit.fits => InfoBanner(tone: Tone.success, message: t.partFits(car!)),
                  Fit.check => InfoBanner(tone: Tone.warning, message: t.partCheck),
                  Fit.noFit => InfoBanner(tone: Tone.danger, message: t.partNoFit(car!)),
                  null => InfoBanner(
                    tone: Tone.info,
                    icon: Icons.directions_car_outlined,
                    message: t.partNoCar,
                    action: OutlinedButton(
                      onPressed: () => context.push(Routes.addCar),
                      child: Text(t.garageAdd),
                    ),
                  ),
                },
                if (part.oemNumbers.isNotEmpty) ...[
                  const SizedBox(height: Space.md),
                  Text(t.partOem, style: theme.textTheme.bodySmall),
                  Wrap(
                    spacing: Space.sm,
                    children: [
                      for (final n in part.oemNumbers)
                        Chip(
                          label: Text(n, textDirection: TextDirection.ltr),
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          SectionHeader(title: t.partCompare(listings.length)),
          for (final (i, l) in listings.indexed)
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.page, 0, Space.page, Space.sm),
              child: _OfferCard(listing: l, part: part, best: i == 0),
            ),
          if (part.installable && minLabour != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.page, Space.md, Space.page, 0),
              child: InfoBanner(
                tone: Tone.neutral,
                icon: Icons.handyman_outlined,
                title: t.partFittingTitle,
                message: t.partFittingBody(context.sdg(minLabour)),
              ),
            ),
          if (part.description != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.page, Space.lg, Space.page, 0),
              child: SectionCard(
                title: t.partAbout,
                child: Text(part.description!.tr(context), style: theme.textTheme.bodyLarge),
              ),
            ),
        ],
      ),
    );
  }

  static int? _minLabour(CatalogueData c, JobType? job) {
    if (job == null) return null;
    final prices = [for (final tech in c.technicians) ?tech.labourSdg[job]];
    return prices.isEmpty ? null : prices.reduce((a, b) => a < b ? a : b);
  }
}

class _OfferCard extends ConsumerWidget {
  const _OfferCard({required this.listing, required this.part, required this.best});

  final Listing listing;
  final Part part;
  final bool best;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final core = context.core;
    final theme = Theme.of(context);
    final catalogue = ref.watch(catalogueProvider);
    final shop = catalogue.shop(listing.shopId);

    void add() {
      ref.read(cartProvider.notifier).addListing(listing, part);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(t.partAdded),
            action: SnackBarAction(label: t.partViewCart, onPressed: () => context.go(Routes.cart)),
          ),
        );
    }

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: Radii.mdAll,
        side: BorderSide(
          color: best ? theme.colorScheme.secondary : theme.colorScheme.outlineVariant,
          width: best ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Space.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              borderRadius: Radii.smAll,
              onTap: () => context.push(Routes.shop(shop.id)),
              child: Row(
                children: [
                  InitialsAvatar(name: shop.name.tr(context), size: 40),
                  const SizedBox(width: Space.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                shop.name.tr(context),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleSmall,
                              ),
                            ),
                            if (shop.verified) ...[
                              const SizedBox(width: Space.xs),
                              Icon(Icons.verified, size: 16, color: AppColors.of(context).info),
                            ],
                          ],
                        ),
                        Text(shopPlace(context, catalogue, shop), style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                  RatingLine(rating: shop.rating, dense: true),
                ],
              ),
            ),
            const Divider(height: Space.xl),
            Wrap(
              spacing: Space.sm,
              runSpacing: Space.xs,
              children: [
                if (best)
                  StatusPill(
                    label: t.partBestPrice,
                    tone: Tone.brand,
                    icon: Icons.local_offer_outlined,
                  ),
                StatusPill(label: core.condition(listing.condition)),
                StatusPill(
                  label: core.warranty(listing.warrantyDays),
                  icon: Icons.verified_user_outlined,
                ),
                if (listing.brand != null) StatusPill(label: listing.brand!),
              ],
            ),
            const SizedBox(height: Space.md),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PriceText(
                        text: context.sdg(listing.priceSdg),
                        was: listing.wasSdg == null ? null : context.sdg(listing.wasSdg!),
                        large: true,
                      ),
                      Text(
                        core.inStock(listing.stockQty),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: listing.stockQty <= 3 ? AppColors.of(context).warning : null,
                        ),
                      ),
                    ],
                  ),
                ),
                best
                    ? FilledButton.icon(
                        onPressed: add,
                        icon: const Icon(Icons.add_shopping_cart, size: 20),
                        label: Text(t.partAddToCart),
                      )
                    : OutlinedButton.icon(
                        onPressed: add,
                        icon: const Icon(Icons.add_shopping_cart, size: 20),
                        label: Text(t.partAddToCart),
                      ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
