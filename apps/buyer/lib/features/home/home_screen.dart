import 'package:alghali_core/alghali_core.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../router.dart';
import '../../state/garage.dart';
import '../../state/orders.dart';
import '../../widgets/buyer_widgets.dart';
import '../shops/street_strip.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final catalogue = ref.watch(catalogueProvider);
    final variantId = ref.watch(selectedVariantProvider);
    final settings = ref.watch(platformSettingsProvider);
    final deals = catalogue.deals(variantId);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _Header(variantId: variantId)),
            const SliverToBoxAdapter(child: _ActiveCard()),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Space.page, Space.lg, Space.page, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _QuickAction(
                        icon: Icons.add_a_photo_outlined,
                        title: t.homeQuickPhotoTitle,
                        body: t.homeQuickPhotoBody,
                        onTap: () => context.push(Routes.newRequest),
                      ),
                    ),
                    const SizedBox(width: Space.md),
                    Expanded(
                      child: _QuickAction(
                        icon: Icons.handyman_outlined,
                        title: t.homeQuickBookTitle,
                        body: t.homeQuickBookBody,
                        onTap: () => context.push(Routes.bookExternal),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(child: SectionHeader(title: t.homeCategories)),
            SliverToBoxAdapter(child: _CategoryGrid(categories: catalogue.categories)),
            if (deals.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: SectionHeader(
                  title: variantId == null
                      ? t.homeDeals
                      : t.homeDealsFor(catalogue.modelOfVariant(variantId).name.tr(context)),
                ),
              ),
              SliverToBoxAdapter(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: Space.page),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final (i, l) in deals.indexed) ...[
                        if (i > 0) const SizedBox(width: Space.md),
                        DealCard(
                          listing: l,
                          fit: catalogue.fitOf(catalogue.part(l.partId), variantId),
                          onTap: () => context.push(Routes.part(l.partId)),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
            SliverToBoxAdapter(child: SectionHeader(title: t.homeStreetTitle)),
            SliverToBoxAdapter(
              child: Padding(
                padding: Space.pageHorizontal,
                child: TapCard(
                  onTap: () => context.go(Routes.street),
                  padding: const EdgeInsets.all(Space.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(height: 72, child: StreetStrip(catalogue: catalogue, compact: true)),
                      const SizedBox(height: Space.md),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              t.homeStreetBody(catalogue.shops.length),
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                          Text(
                            t.homeStreetOpen,
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(color: Theme.of(context).colorScheme.primary),
                          ),
                          Icon(
                            Directionality.of(context) == TextDirection.rtl
                                ? Icons.chevron_left
                                : Icons.chevron_right,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Space.page, Space.xl, Space.page, Space.xxl),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: Space.sm),
                    child: Column(
                      children: [
                        _TrustRow(Icons.payments_outlined, t.homeTrustPay),
                        _TrustRow(Icons.verified_outlined, t.homeTrustTech),
                        _TrustRow(
                          Icons.assignment_return_outlined,
                          t.homeTrustReturns(settings.returnWindowDays),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.variantId});

  final String? variantId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final catalogue = ref.watch(catalogueProvider);
    final unread = ref.watch(unreadCountProvider);
    final fg = colors.onBrandSurface;

    return Container(
      color: colors.brandSurface,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Space.page, Space.md, Space.sm, Space.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: AlghaliLogo(markSize: 36, color: fg)),
                  const DemoBadge(onDark: true),
                  IconButton(
                    tooltip: t.notificationsTitle,
                    onPressed: () => context.push(Routes.notifications),
                    icon: Badge(
                      isLabelVisible: unread > 0,
                      label: Text('$unread'),
                      child: Icon(Icons.notifications_outlined, color: fg),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Space.lg),
              Padding(
                padding: const EdgeInsetsDirectional.only(end: Space.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Material(
                      color: fg.withValues(alpha: 0.1),
                      borderRadius: Radii.mdAll,
                      child: InkWell(
                        borderRadius: Radii.mdAll,
                        onTap: () =>
                            context.push(variantId == null ? Routes.addCar : Routes.garage),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: Space.md,
                            vertical: Space.md,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                variantId == null
                                    ? Icons.add_circle_outline
                                    : Icons.directions_car_filled,
                                color: fg,
                              ),
                              const SizedBox(width: Space.md),
                              Expanded(
                                child: Text(
                                  variantId == null
                                      ? t.homeAddCar
                                      : carLabel(context, catalogue, variantId!),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleSmall?.copyWith(color: fg),
                                ),
                              ),
                              if (variantId != null)
                                Text(
                                  t.homeChangeCar,
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: colors.onBrandSurfaceMuted,
                                  ),
                                ),
                              Icon(Icons.expand_more, color: colors.onBrandSurfaceMuted),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: Space.md),
                    Material(
                      color: theme.colorScheme.surface,
                      borderRadius: Radii.mdAll,
                      child: InkWell(
                        borderRadius: Radii.mdAll,
                        onTap: () => context.push(Routes.search),
                        child: SizedBox(
                          height: 52,
                          child: Row(
                            children: [
                              const SizedBox(width: Space.md),
                              Icon(Icons.search, color: theme.colorScheme.onSurfaceVariant),
                              const SizedBox(width: Space.md),
                              Expanded(
                                child: Text(
                                  t.homeSearchHint,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: t.homeQuickPhotoTitle,
                                onPressed: () => context.push(Routes.newRequest),
                                icon: Icon(
                                  Icons.photo_camera_outlined,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The next fitting or an order in progress, so buyers never hunt for it.
class _ActiveCard extends ConsumerWidget {
  const _ActiveCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final core = context.core;
    final catalogue = ref.watch(catalogueProvider);
    final bookings = ref.watch(bookingsProvider).where((b) => b.isActive).toList()
      ..sort((a, b) => a.startAt.compareTo(b.startAt));
    final orders = ref.watch(ordersProvider).where((o) => o.isActive).toList();

    Widget card({
      required IconData icon,
      required String title,
      required String body,
      required String pill,
      required Tone tone,
      required VoidCallback onTap,
    }) => Padding(
      padding: const EdgeInsets.fromLTRB(Space.page, Space.lg, Space.page, 0),
      child: TapCard(
        onTap: onTap,
        child: Row(
          children: [
            IconTile(icon: icon, tone: Tone.brand),
            const SizedBox(width: Space.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.bodySmall),
                  Text(body, style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: Space.xs),
                  StatusPill(label: pill, tone: tone),
                ],
              ),
            ),
            Icon(
              Directionality.of(context) == TextDirection.rtl
                  ? Icons.chevron_left
                  : Icons.chevron_right,
            ),
          ],
        ),
      ),
    );

    if (bookings.isNotEmpty) {
      final b = bookings.first;
      return card(
        icon: Icons.handyman_outlined,
        title: t.homeNextFitting,
        body:
            '${context.dayTime(b.startAt)}\n${catalogue.technician(b.technicianId).name.tr(context)}',
        pill: core.bookingStatus(b.status),
        tone: bookingTone(b.status),
        onTap: () => context.push(Routes.booking(b.id)),
      );
    }
    if (orders.isNotEmpty) {
      final o = orders.first;
      final status = o.subOrders.first.status;
      return card(
        icon: Icons.receipt_long_outlined,
        title: t.homeCurrentOrder,
        body: t.orderRef(formatRef(o.ref)),
        pill: core.subOrderStatus(status),
        tone: subOrderTone(status),
        onTap: () => context.push(Routes.order(o.id)),
      );
    }
    return const SizedBox.shrink();
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.title,
    required this.body,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String body;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TapCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconTile(icon: icon, size: 40, tone: Tone.brand),
          const SizedBox(height: Space.sm),
          Text(title, style: theme.textTheme.titleSmall),
          Text(body, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid({required this.categories});

  final List<PartCategory> categories;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final half = (categories.length / 2).ceil();
    Widget cell(PartCategory c) => SizedBox(
      width: 84,
      child: InkWell(
        borderRadius: Radii.mdAll,
        onTap: () => context.push(Routes.searchFor(categoryId: c.id)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Space.sm),
          child: Column(
            children: [
              IconTile(icon: categoryIcon(c.icon), size: 56, background: theme.colorScheme.surface),
              const SizedBox(height: Space.xs),
              Text(
                c.name.tr(context),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium,
              ),
            ],
          ),
        ),
      ),
    );

    // Two rows that scroll sideways: every category stays one tap away and
    // long names get room on narrow phones.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: Space.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [for (final c in categories.take(half)) cell(c)],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [for (final c in categories.skip(half)) cell(c)],
          ),
        ],
      ),
    );
  }
}

class _TrustRow extends StatelessWidget {
  const _TrustRow(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => ListTile(
    dense: true,
    leading: Icon(icon, color: AppColors.of(context).success),
    title: Text(text, style: Theme.of(context).textTheme.bodyMedium),
    minVerticalPadding: Space.sm,
  );
}
