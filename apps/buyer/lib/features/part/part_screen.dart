import 'package:alghali_core/alghali_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../router.dart';
import '../../state/cart.dart';
import '../../state/catalogue.dart';
import '../../state/garage.dart';
import '../../widgets/buyer_widgets.dart';

/// One part, every shop that sells it (in stock first, then cheapest), and the fit
/// verdict for the buyer's car.
class PartScreen extends ConsumerWidget {
  const PartScreen({super.key, required this.partId});

  final String partId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final variantId = ref.watch(selectedVariantProvider);
    final key = (partId: partId, variantId: variantId);
    final detail = ref.watch(partDetailProvider(key));
    final catalogue = ref.watch(catalogueProvider);
    final title = detail.value == null
        ? ''
        : catalogue.category(detail.value!.part.categoryId).name.tr(context);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: AsyncBody(
        value: detail,
        onRefresh: () => ref.refresh(partDetailProvider(key).future),
        data: (d) => _PartBody(detail: d, variantId: variantId),
      ),
    );
  }
}

class _PartBody extends ConsumerWidget {
  const _PartBody({required this.detail, required this.variantId});

  final PartDetail detail;
  final String? variantId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final core = context.core;
    final theme = Theme.of(context);
    final catalogue = ref.watch(catalogueProvider);
    final dataSaver = ref.watch(dataSaverProvider);
    final part = detail.part;
    final category = catalogue.category(part.categoryId);
    final offers = detail.offers;
    final inStock = offers.where((o) => o.listing.inStock && !o.listing.priceOnRequest).toList();
    final car = variantId == null ? null : carLabel(context, catalogue, variantId!, engine: false);
    final image = offers.expand((o) => o.images).firstOrNull;
    final installable = part.installable && (detail.jobType ?? category.jobType) != null;

    return ListView(
      padding: const EdgeInsets.only(bottom: Space.xxl),
      children: [
        Container(
          color: theme.colorScheme.surface,
          padding: const EdgeInsets.all(Space.page),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: GestureDetector(
                  onTap: image == null ? null : () => _showPhoto(context, ref, image),
                  child: PartThumb(
                    icon: category.icon,
                    size: 168,
                    imageUrl: thumbUrl(ref, image, size: dataSaver ? 'thumb' : 'medium'),
                  ),
                ),
              ),
              const SizedBox(height: Space.lg),
              Text(part.name.tr(context), style: theme.textTheme.headlineSmall),
              if (!part.verified) ...[
                const SizedBox(height: Space.xs),
                Text(t.partUnverified, style: theme.textTheme.bodySmall),
              ],
              const SizedBox(height: Space.sm),
              if (inStock.isNotEmpty)
                Text(
                  core.moneyFrom(
                    context.sdg(
                      inStock.map((o) => o.listing.priceSdg).reduce((a, b) => a < b ? a : b),
                    ),
                  ),
                  style: theme.textTheme.titleLarge?.copyWith(fontFeatures: AppTypography.tabular),
                ),
              const SizedBox(height: Space.md),
              switch (detail.fit) {
                Fit.fits => InfoBanner(tone: Tone.success, message: t.partFits(car ?? '')),
                Fit.check => InfoBanner(tone: Tone.warning, message: t.partCheck),
                Fit.noFit => InfoBanner(tone: Tone.danger, message: t.partNoFit(car ?? '')),
                null when variantId != null => InfoBanner(tone: Tone.warning, message: t.partCheck),
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
              if (detail.fitmentNote != null) ...[
                const SizedBox(height: Space.sm),
                Text(detail.fitmentNote!.tr(context), style: theme.textTheme.bodySmall),
              ],
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
        SectionHeader(title: t.partCompare(offers.length)),
        if (offers.isEmpty)
          EmptyState(
            icon: Icons.storefront_outlined,
            title: t.partNoOffers,
            compact: true,
            action: OutlinedButton.icon(
              onPressed: () => context.push(Routes.newRequest),
              icon: const Icon(Icons.add_a_photo_outlined),
              label: Text(t.searchSendPhoto),
            ),
          ),
        for (final (i, o) in offers.indexed)
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.page, 0, Space.page, Space.sm),
            child: _OfferCard(offer: o, part: part, best: i == 0 && inStock.contains(o)),
          ),
        if (installable)
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.page, Space.md, Space.page, 0),
            child: InfoBanner(
              tone: Tone.neutral,
              icon: Icons.handyman_outlined,
              title: t.partFittingTitle,
              message: t.partFittingBodyLive,
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
    );
  }

  /// The full photo, loaded only when tapped (data saver, brief §1).
  static void _showPhoto(BuildContext context, WidgetRef ref, String key) {
    final url = thumbUrl(ref, key, size: 'large');
    if (url == null) return;
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        clipBehavior: Clip.antiAlias,
        child: InteractiveViewer(
          child: Image.network(
            url,
            fit: BoxFit.contain,
            loadingBuilder: (_, child, progress) => progress == null
                ? child
                : const SizedBox(height: 240, child: Center(child: CircularProgressIndicator())),
            errorBuilder: (_, _, _) =>
                const SizedBox(height: 240, child: Icon(Icons.broken_image_outlined)),
          ),
        ),
      ),
    );
  }
}

class _OfferCard extends ConsumerWidget {
  const _OfferCard({required this.offer, required this.part, required this.best});

  final ShopOffer offer;
  final Part part;
  final bool best;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final core = context.core;
    final theme = Theme.of(context);
    final catalogue = ref.watch(catalogueProvider);
    final listing = offer.listing;
    final shop = catalogue.hasShop(offer.shop.id) ? catalogue.shop(offer.shop.id) : offer.shop;
    final canBuy = listing.inStock && !listing.priceOnRequest;

    void add() {
      ref.read(cartProvider.notifier).addListing(listing, part, imageKey: offer.images.firstOrNull);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(t.partAdded),
            action: SnackBarAction(label: t.partViewCart, onPressed: () => context.go(Routes.cart)),
          ),
        );
    }

    final button = !canBuy
        ? OutlinedButton.icon(
            onPressed: () => context.push(Routes.chat(shop.id)),
            icon: const Icon(Icons.chat_bubble_outline, size: 20),
            label: Text(listing.priceOnRequest ? t.partAskPrice : t.partAskStock),
          )
        : best
        ? FilledButton.icon(
            onPressed: add,
            icon: const Icon(Icons.add_shopping_cart, size: 20),
            label: Text(t.partAddToCart),
          )
        : OutlinedButton.icon(
            onPressed: add,
            icon: const Icon(Icons.add_shopping_cart, size: 20),
            label: Text(t.partAddToCart),
          );

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
                  if (shop.lat != null && shop.lng != null)
                    IconButton(
                      onPressed: () => Launch.directions(shop.lat!, shop.lng!),
                      tooltip: t.shopDirections,
                      icon: const Icon(Icons.directions_outlined),
                    ),
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
            if (offer.note != null && offer.note!.isNotEmpty) ...[
              const SizedBox(height: Space.sm),
              Text(offer.note!, style: theme.textTheme.bodySmall),
            ],
            const SizedBox(height: Space.md),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (listing.priceOnRequest)
                        Text(t.priceOnRequest, style: theme.textTheme.titleMedium)
                      else
                        PriceText(
                          text: context.sdg(listing.priceSdg),
                          was: listing.wasSdg == null ? null : context.sdg(listing.wasSdg!),
                          large: true,
                        ),
                      Text(
                        listing.inStock ? core.inStock(listing.stockQty) : t.partOutOfStock,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: listing.stockQty <= 3 ? AppColors.of(context).warning : null,
                        ),
                      ),
                    ],
                  ),
                ),
                button,
              ],
            ),
          ],
        ),
      ),
    );
  }
}
