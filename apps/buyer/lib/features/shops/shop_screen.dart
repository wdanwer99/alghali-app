import 'package:alghali_core/alghali_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../router.dart';
import '../../widgets/buyer_widgets.dart';

class ShopScreen extends ConsumerStatefulWidget {
  const ShopScreen({super.key, required this.shopId});

  final String shopId;

  @override
  ConsumerState<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends ConsumerState<ShopScreen> {
  var _tab = 0;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final core = context.core;
    final theme = Theme.of(context);
    final catalogue = ref.watch(catalogueProvider);
    final shop = catalogue.shop(widget.shopId);
    final listings = catalogue.shopListings(shop.id);
    final reviews = catalogue.reviewsOfShop(shop.id);

    return Scaffold(
      appBar: AppBar(title: Text(shop.name.tr(context))),
      body: ListView(
        padding: Space.pageInsets,
        children: [
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    InitialsAvatar(name: shop.name.tr(context), size: 60),
                    const SizedBox(width: Space.lg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(shop.name.tr(context), style: theme.textTheme.titleLarge),
                          const SizedBox(height: Space.xs),
                          Wrap(
                            spacing: Space.sm,
                            runSpacing: Space.xs,
                            children: [
                              if (shop.verified)
                                StatusPill(
                                  label: core.verifiedShop,
                                  tone: Tone.info,
                                  icon: Icons.verified,
                                ),
                              StatusPill(
                                label: shop.openNow ? t.shopOpen : t.shopClosed,
                                tone: shop.openNow ? Tone.success : Tone.neutral,
                                icon: Icons.schedule,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Space.md),
                RatingLine(rating: shop.rating, count: shop.ratingCount),
                const SizedBox(height: Space.sm),
                _InfoLine(Icons.location_on_outlined, shopPlace(context, catalogue, shop)),
                _InfoLine(
                  Icons.signpost_outlined,
                  '${core.side(shop.side)} · ${shop.landmark.tr(context)}',
                ),
                _InfoLine(Icons.schedule, shop.hours.tr(context)),
                const SizedBox(height: Space.md),
                ContactActions(onChat: () => context.push(Routes.chat(shop.id))),
                const SizedBox(height: Space.sm),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: () => context.go(
                      Uri(path: Routes.street, queryParameters: {'shop': shop.id}).toString(),
                    ),
                    icon: const Icon(Icons.map_outlined),
                    label: Text(t.shopOnStreet),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Space.lg),
          SegmentedButton<int>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: 0, label: Text('${t.shopParts} (${listings.length})')),
              ButtonSegment(value: 1, label: Text('${t.shopReviews} (${reviews.length})')),
            ],
            selected: {_tab},
            onSelectionChanged: (s) => setState(() => _tab = s.first),
          ),
          const SizedBox(height: Space.md),
          if (_tab == 0)
            for (final l in listings) ...[_ListingRow(listing: l), const SizedBox(height: Space.sm)]
          else if (reviews.isEmpty)
            EmptyState(icon: Icons.rate_review_outlined, title: t.shopNoReviews, compact: true)
          else
            for (final r in reviews) ...[_ReviewTile(review: r), const SizedBox(height: Space.sm)],
          const SizedBox(height: Space.lg),
          SectionCard(
            title: t.shopAbout,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(shop.about.tr(context), style: theme.textTheme.bodyLarge),
                const SizedBox(height: Space.sm),
                Text(t.shopSince('${shop.memberSince}'), style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: Space.xxs),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(width: Space.sm),
        Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyMedium)),
      ],
    ),
  );
}

class _ListingRow extends StatelessWidget {
  const _ListingRow({required this.listing});

  final Listing listing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final core = context.core;
    final catalogue = CatalogueScope.of(context);
    final part = catalogue.part(listing.partId);
    return TapCard(
      onTap: () => context.push(Routes.part(part.id)),
      child: Row(
        children: [
          PartThumb(icon: catalogue.category(part.categoryId).icon, size: 64),
          const SizedBox(width: Space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  part.name.tr(context),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
                Text(
                  '${core.condition(listing.condition)} · ${core.warranty(listing.warrantyDays)}',
                  style: theme.textTheme.bodySmall,
                ),
                PriceText(
                  text: context.sdg(listing.priceSdg),
                  was: listing.wasSdg == null ? null : context.sdg(listing.wasSdg!),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewTile extends ConsumerWidget {
  const _ReviewTile({required this.review});

  final Review review;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final now = ref.watch(clockProvider)();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Space.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                InitialsAvatar(name: review.author, size: 32),
                const SizedBox(width: Space.sm),
                Expanded(child: Text(review.author, style: theme.textTheme.titleSmall)),
                Text(context.core.ago(review.at, now), style: theme.textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: Space.sm),
            Row(
              children: [
                for (var i = 1; i <= 5; i++)
                  Icon(
                    i <= review.rating ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: 18,
                    color: AppColors.of(context).star,
                  ),
              ],
            ),
            const SizedBox(height: Space.xs),
            Text(review.comment.tr(context), style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
