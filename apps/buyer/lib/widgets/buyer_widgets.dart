import 'package:alghali_core/alghali_core.dart';
import 'package:material_ui/material_ui.dart';

/// "Toyota Hilux" for a variant.
String carName(BuildContext context, CatalogueData c, String variantId) =>
    '${c.makeOfVariant(variantId).name.tr(context)} ${c.modelOfVariant(variantId).name.tr(context)}';

/// "Toyota Hilux 2016–2025 · 2.7 petrol".
String carLabel(BuildContext context, CatalogueData c, String variantId, {bool engine = true}) {
  final v = c.variant(variantId);
  final base = '${carName(context, c, variantId)} ${v.years}';
  return engine ? '$base · ${v.engine.tr(context)}' : base;
}

/// "Zone 1 North entrance · Plot 12".
String shopPlace(BuildContext context, CatalogueData c, Shop shop) =>
    '${c.zone(shop.zoneId).name.tr(context)} · ${context.core.plot(shop.plotNo)}';

class FitBadge extends StatelessWidget {
  const FitBadge(this.fit, {super.key});

  final Fit fit;

  @override
  Widget build(BuildContext context) => StatusPill(
    label: context.core.fit(fit),
    tone: switch (fit) {
      Fit.fits => Tone.success,
      Fit.check => Tone.warning,
      Fit.noFit => Tone.danger,
    },
    icon: switch (fit) {
      Fit.fits => Icons.check_circle_rounded,
      Fit.check => Icons.help_outline,
      Fit.noFit => Icons.block,
    },
  );
}

// Status pills never use the red action colour: red means "tap here".
Tone subOrderTone(SubOrderStatus s) => switch (s) {
  SubOrderStatus.pendingPayment || SubOrderStatus.paymentReview => Tone.warning,
  SubOrderStatus.confirmed ||
  SubOrderStatus.outForDelivery ||
  SubOrderStatus.handedToTechnician => Tone.info,
  SubOrderStatus.ready ||
  SubOrderStatus.pickedUp ||
  SubOrderStatus.delivered ||
  SubOrderStatus.completed => Tone.success,
  SubOrderStatus.cancelled || SubOrderStatus.rejectedByShop => Tone.danger,
  SubOrderStatus.returnRequested || SubOrderStatus.returned => Tone.neutral,
};

Tone paymentTone(PaymentStatus s) => switch (s) {
  PaymentStatus.awaitingTransfer ||
  PaymentStatus.receiptSubmitted ||
  PaymentStatus.due => Tone.warning,
  PaymentStatus.confirmed || PaymentStatus.collected => Tone.success,
  PaymentStatus.rejected || PaymentStatus.expired => Tone.danger,
  PaymentStatus.cancelled => Tone.neutral,
};

Tone bookingTone(BookingStatus s) => switch (s) {
  BookingStatus.held ||
  BookingStatus.awaitingPayment ||
  BookingStatus.pendingTechAccept => Tone.warning,
  BookingStatus.accepted || BookingStatus.enRoute || BookingStatus.inProgress => Tone.info,
  BookingStatus.completed => Tone.success,
  BookingStatus.needsReschedule => Tone.warning,
  _ => Tone.danger,
};

/// A part in search results: thumbnail, name, fit, "from" price and shop count.
class PartResultTile extends StatelessWidget {
  const PartResultTile({
    super.key,
    required this.result,
    required this.onTap,
    required this.shopsLabel,
  });

  final PartResult result;
  final VoidCallback onTap;
  final String shopsLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = context.core;
    final category = _category(context);
    final best = result.listings.first;
    return TapCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PartThumb(
            icon: category.icon,
            size: 84,
            badge: best.discountPercent == null ? null : '-${best.discountPercent}%',
          ),
          const SizedBox(width: Space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.part.name.tr(context),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: Space.xs),
                if (result.fit != null) ...[
                  FitBadge(result.fit!),
                  const SizedBox(height: Space.xs),
                ],
                Text(
                  c.moneyFrom(context.sdg(result.fromSdg)),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontFeatures: AppTypography.tabular,
                  ),
                ),
                Text(
                  '$shopsLabel · ${result.conditions.map(c.condition).join('، ')}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  PartCategory _category(BuildContext context) =>
      CatalogueScope.of(context).category(result.part.categoryId);
}

/// Gives widgets synchronous access to the catalogue without Riverpod.
class CatalogueScope extends InheritedWidget {
  const CatalogueScope({super.key, required this.catalogue, required super.child});

  final CatalogueData catalogue;

  static CatalogueData of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CatalogueScope>()!.catalogue;

  @override
  bool updateShouldNotify(CatalogueScope old) => old.catalogue != catalogue;
}

/// Compact card for horizontal deal lists.
class DealCard extends StatelessWidget {
  const DealCard({super.key, required this.listing, required this.onTap, this.fit});

  final Listing listing;
  final VoidCallback onTap;
  final Fit? fit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final catalogue = CatalogueScope.of(context);
    final part = catalogue.part(listing.partId);
    final shop = catalogue.shop(listing.shopId);
    return SizedBox(
      width: 172,
      child: TapCard(
        onTap: onTap,
        padding: const EdgeInsets.all(Space.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: PartThumb(
                icon: catalogue.category(part.categoryId).icon,
                size: 104,
                badge: listing.discountPercent == null ? null : '-${listing.discountPercent}%',
              ),
            ),
            const SizedBox(height: Space.sm),
            SizedBox(
              height: 44,
              child: Text(
                part.name.tr(context),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            PriceText(
              text: context.sdg(listing.priceSdg),
              was: listing.wasSdg == null ? null : context.sdg(listing.wasSdg!),
            ),
            Text(
              shop.name.tr(context),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
            if (fit == Fit.fits) ...[const SizedBox(height: Space.xs), FitBadge(fit!)],
          ],
        ),
      ),
    );
  }
}

/// A technician with rating, jobs, price and where they work.
class TechnicianSummary extends StatelessWidget {
  const TechnicianSummary({super.key, required this.tech, this.trailing, this.subtitle});

  final Technician tech;
  final Widget? trailing;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = context.core;
    return Row(
      children: [
        InitialsAvatar(name: tech.name.tr(context), size: 48, tone: Tone.info),
        const SizedBox(width: Space.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      tech.name.tr(context),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  if (tech.verified) ...[
                    const SizedBox(width: Space.xs),
                    Tooltip(
                      message: c.verifiedTechnician,
                      child: Icon(Icons.verified, size: 18, color: AppColors.of(context).info),
                    ),
                  ],
                ],
              ),
              Wrap(
                spacing: Space.sm,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  RatingLine(rating: tech.rating, count: tech.ratingCount, dense: true),
                  Text(c.jobsDone(tech.completedJobs), style: theme.textTheme.bodySmall),
                ],
              ),
              if (subtitle != null) Text(subtitle!, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// White rounded section card with an optional title.
class SectionCard extends StatelessWidget {
  const SectionCard({super.key, this.title, required this.child, this.trailing, this.padding});

  final String? title;
  final Widget child;
  final Widget? trailing;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: padding ?? const EdgeInsets.all(Space.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null) ...[
              Row(
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(title!, style: Theme.of(context).textTheme.titleMedium),
                    ),
                  ),
                  ?trailing,
                ],
              ),
              const SizedBox(height: Space.md),
            ],
            child,
          ],
        ),
      ),
    );
  }
}

/// Large digits with gaps, for job codes and references.
class BigDigits extends StatelessWidget {
  const BigDigits(this.digits, {super.key, this.size = 34});

  final String digits;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final d in digits.characters)
            Container(
              width: size * 1.4,
              height: size * 1.7,
              margin: const EdgeInsets.symmetric(horizontal: Space.xs),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: scheme.surfaceContainer,
                borderRadius: Radii.mdAll,
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: Text(
                d,
                style: Theme.of(context).textTheme.headlineMedium
                    ?.copyWith(fontSize: size, height: 1, fontFeatures: AppTypography.tabular),
              ),
            ),
        ],
      ),
    );
  }
}
