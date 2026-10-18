import 'package:alghali_core/alghali_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../app.dart';
import '../state/cart.dart';

/// A cart line's name; window tint adds what was chosen ("Window tint · Full car · 50% …").
String lineTitle(BuildContext context, CartLine l) => switch (l.tint) {
  final t? => '${l.title.tr(context)} · ${context.core.tintSummary(t)}',
  null => l.title.tr(context),
};

/// "Toyota Hilux" for a variant.
String carName(BuildContext context, CatalogueData c, String variantId) =>
    '${c.makeOfVariant(variantId).name.tr(context)} ${c.modelOfVariant(variantId).name.tr(context)}';

/// "Toyota Hilux 2016–2025 · 2.7 petrol".
String carLabel(BuildContext context, CatalogueData c, String variantId, {bool engine = true}) {
  final v = c.variant(variantId);
  final base = '${carName(context, c, variantId)} ${v.years}';
  return engine && v.engine.tr(context).isNotEmpty ? '$base · ${v.engine.tr(context)}' : base;
}

/// "Zone 1 North entrance · Plot 12".
String shopPlace(BuildContext context, CatalogueData c, Shop shop) {
  final zone = c.zone(shop.zoneId).name.tr(context);
  final plot = shop.plotNo.isEmpty ? '' : context.core.plot(shop.plotNo);
  return [zone, plot].where((s) => s.isNotEmpty).join(' · ');
}

/// A shop's name: from the cached street, else as the order recorded it.
String shopName(BuildContext context, CatalogueData c, String shopId, {LocalizedText? fallback}) {
  final name = c.shop(shopId).name.tr(context);
  return name.isNotEmpty ? name : fallback?.tr(context) ?? '';
}

/// The shop's weekly hours in Khartoum time, Saturday first, with days that share the
/// same hours grouped: "السبت – الخميس: 8:00 ص – 8:00 م".
List<String> openingHoursLines(BuildContext context, OpeningHours hours) {
  if (hours.isEmpty) return const [];
  String day(int wd) => context.weekday(DateTime.utc(2026, 10, 11 + wd, 10));
  String clock(int minutes) => context.time(
    DateTime.utc(2026, 1, 1).add(Duration(minutes: minutes)).subtract(khartoumOffset),
  );
  String windows(int wd) {
    final w = hours[wd];
    if (w == null || w.isEmpty) return context.t.shopClosedDay;
    return w.map((x) => ltr('${clock(x.$1)} – ${clock(x.$2)}')).join('، ');
  }

  const order = [6, 0, 1, 2, 3, 4, 5];
  final lines = <String>[];
  var start = 0;
  for (var i = 1; i <= order.length; i++) {
    if (i < order.length && windows(order[i]) == windows(order[start])) continue;
    final from = day(order[start]);
    final to = day(order[i - 1]);
    lines.add('${i - 1 == start ? from : '$from – $to'}: ${windows(order[start])}');
    start = i;
  }
  return lines;
}

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
class PartResultTile extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final c = context.core;
    final category = CatalogueScope.of(context).category(result.part.categoryId);
    final best = result.listings.first;
    final discount = result.listings
        .map((l) => l.discountPercent ?? 0)
        .fold(0, (a, b) => a > b ? a : b);
    return TapCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PartThumb(
            icon: category.icon,
            size: 84,
            badge: discount == 0 ? null : '-$discount%',
            imageUrl: thumbUrl(ref, result.imageKey ?? best.imageKey),
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
                  best.priceOnRequest
                      ? context.t.priceOnRequest
                      : c.moneyFrom(context.sdg(result.fromSdg)),
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

/// Compact card for horizontal deal lists: the part's cheapest discounted offer.
class DealCard extends ConsumerWidget {
  const DealCard({super.key, required this.result, required this.onTap});

  final PartResult result;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final catalogue = CatalogueScope.of(context);
    final deal =
        result.listings.where((l) => l.discountPercent != null).firstOrNull ??
        result.listings.first;
    final shop = catalogue.shop(deal.shopId);
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
                icon: catalogue.category(result.part.categoryId).icon,
                size: 104,
                badge: deal.discountPercent == null ? null : '-${deal.discountPercent}%',
                imageUrl: thumbUrl(ref, deal.imageKey ?? result.imageKey),
              ),
            ),
            const SizedBox(height: Space.sm),
            SizedBox(
              height: 44,
              child: Text(
                result.part.name.tr(context),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            PriceText(
              text: context.sdg(deal.priceSdg),
              was: deal.wasSdg == null ? null : context.sdg(deal.wasSdg!),
            ),
            Text(
              shop.name.tr(context),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
            if (result.fit == Fit.fits) ...[
              const SizedBox(height: Space.xs),
              FitBadge(result.fit!),
            ],
          ],
        ),
      ),
    );
  }
}

/// A technician with rating, jobs and a line about where they work.
class TechnicianSummary extends StatelessWidget {
  const TechnicianSummary({
    super.key,
    required this.name,
    required this.rating,
    required this.ratingCount,
    this.completedJobs,
    this.verified = false,
    this.trailing,
    this.subtitle,
  });

  final String name;
  final double rating;
  final int ratingCount;
  final int? completedJobs;
  final bool verified;
  final Widget? trailing;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = context.core;
    return Row(
      children: [
        InitialsAvatar(name: name, size: 48, tone: Tone.info),
        const SizedBox(width: Space.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  if (verified) ...[
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
                  RatingLine(rating: rating, count: ratingCount, dense: true),
                  if (completedJobs != null)
                    Text(c.jobsDone(completedJobs!), style: theme.textTheme.bodySmall),
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

/// Asks for a short text (a reason, a reply) in a bottom sheet; null when dismissed.
Future<String?> askText(
  BuildContext context, {
  required String title,
  required String label,
  String? hint,
  String? submit,
  int maxLines = 3,
}) => showModalBottomSheet<String>(
  context: context,
  isScrollControlled: true,
  builder: (context) =>
      _TextSheet(title: title, label: label, hint: hint, submit: submit, maxLines: maxLines),
);

class _TextSheet extends StatefulWidget {
  const _TextSheet({
    required this.title,
    required this.label,
    this.hint,
    this.submit,
    this.maxLines = 3,
  });

  final String title;
  final String label;
  final String? hint;
  final String? submit;
  final int maxLines;

  @override
  State<_TextSheet> createState() => _TextSheetState();
}

class _TextSheetState extends State<_TextSheet> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.page, 0, Space.page, Space.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: Space.lg),
            TextField(
              controller: _text,
              autofocus: true,
              minLines: 1,
              maxLines: widget.maxLines,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(labelText: widget.label, hintText: widget.hint),
            ),
            const SizedBox(height: Space.lg),
            FilledButton(
              onPressed: _text.text.trim().isEmpty
                  ? null
                  : () => Navigator.pop(context, _text.text.trim()),
              child: Text(widget.submit ?? context.core.actionNext),
            ),
          ],
        ),
      ),
    ),
  );
}
