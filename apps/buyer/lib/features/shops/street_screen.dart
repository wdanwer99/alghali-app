import 'package:alghali_core/alghali_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../router.dart';
import '../../widgets/buyer_widgets.dart';
import 'street_strip.dart';

class StreetScreen extends ConsumerStatefulWidget {
  const StreetScreen({super.key, this.focusShopId});

  final String? focusShopId;

  @override
  ConsumerState<StreetScreen> createState() => _StreetScreenState();
}

class _StreetScreenState extends ConsumerState<StreetScreen> {
  String? _selected;
  String? _categoryId;

  @override
  void initState() {
    super.initState();
    _selected = widget.focusShopId;
  }

  @override
  void didUpdateWidget(StreetScreen old) {
    super.didUpdateWidget(old);
    if (widget.focusShopId != null && widget.focusShopId != old.focusShopId) {
      _selected = widget.focusShopId;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final core = context.core;
    final theme = Theme.of(context);
    final catalogue = ref.watch(catalogueProvider);
    final specialities = {for (final s in catalogue.shops) ...s.specialityIds};
    final highlight = _categoryId == null
        ? null
        : {
            for (final s in catalogue.shops)
              if (s.specialityIds.contains(_categoryId)) s.id,
          };
    final selected = catalogue.shops.where((s) => s.id == _selected).firstOrNull;

    return Scaffold(
      appBar: AppBar(
        title: Text(core.brandName),
        actions: [
          IconButton(
            tooltip: t.searchHint,
            onPressed: () => context.push(Routes.search),
            icon: const Icon(Icons.search),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: Space.xxl),
        children: [
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: Space.page, vertical: Space.sm),
              children: [
                ChoiceChip(
                  label: Text(t.streetAll),
                  selected: _categoryId == null,
                  onSelected: (_) => setState(() => _categoryId = null),
                ),
                for (final c in catalogue.categories.where((c) => specialities.contains(c.id))) ...[
                  const SizedBox(width: Space.sm),
                  ChoiceChip(
                    avatar: Icon(categoryIcon(c.icon), size: 18),
                    label: Text(c.name.tr(context)),
                    selected: _categoryId == c.id,
                    onSelected: (_) =>
                        setState(() => _categoryId = _categoryId == c.id ? null : c.id),
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.page, Space.xs, Space.page, Space.sm),
            child: Text(t.streetHint, style: theme.textTheme.bodySmall),
          ),
          ColoredBox(
            color: theme.colorScheme.surface,
            child: StreetStrip(
              catalogue: catalogue,
              selectedShopId: _selected,
              highlight: highlight,
              onShopTap: (s) => setState(() => _selected = s.id),
            ),
          ),
          AnimatedSize(
            duration: Motion.medium,
            child: selected == null
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.fromLTRB(Space.page, Space.lg, Space.page, 0),
                    child: _ShopCard(shop: selected, highlighted: true),
                  ),
          ),
          for (final zone in catalogue.zones) ...[
            SectionHeader(title: '${zone.seq}. ${zone.name.tr(context)}'),
            for (final shop in catalogue.shopsIn(zone.id))
              if (highlight == null || highlight.contains(shop.id))
                Padding(
                  padding: const EdgeInsets.fromLTRB(Space.page, 0, Space.page, Space.sm),
                  child: _ShopCard(shop: shop),
                ),
          ],
        ],
      ),
    );
  }
}

class _ShopCard extends StatelessWidget {
  const _ShopCard({required this.shop, this.highlighted = false});

  final Shop shop;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final catalogue = CatalogueScope.of(context);
    final core = context.core;
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: Radii.mdAll,
        side: BorderSide(
          color: highlighted ? theme.colorScheme.secondary : theme.colorScheme.outlineVariant,
          width: highlighted ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: () => context.push(Routes.shop(shop.id)),
        child: Padding(
          padding: const EdgeInsets.all(Space.md),
          child: Row(
            children: [
              InitialsAvatar(name: shop.name.tr(context), size: 48),
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
                          Tooltip(
                            message: core.verifiedShop,
                            child: Icon(
                              Icons.verified,
                              size: 18,
                              color: AppColors.of(context).info,
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      '${core.plot(shop.plotNo)} · ${core.side(shop.side)} · ${shop.landmark.tr(context)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: Space.xs),
                    Wrap(
                      spacing: Space.sm,
                      runSpacing: Space.xs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        RatingLine(rating: shop.rating, count: shop.ratingCount, dense: true),
                        for (final id in shop.specialityIds.take(2))
                          Text(
                            '· ${catalogue.category(id).name.tr(context)}',
                            style: theme.textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                Directionality.of(context) == TextDirection.rtl
                    ? Icons.chevron_left
                    : Icons.chevron_right,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
