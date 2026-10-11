import 'package:alghali_core/alghali_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../router.dart';
import '../../state/garage.dart';
import '../../widgets/buyer_widgets.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key, this.initialQuery = '', this.categoryId});

  final String initialQuery;
  final String? categoryId;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  late final _text = TextEditingController(text: widget.initialQuery);
  late SearchQuery _query = SearchQuery(text: widget.initialQuery, categoryId: widget.categoryId);

  static const _recent = ['لمبات', 'فحمات', 'بطارية 70', 'زيت 5W-30'];

  bool get _browsing => _query.text.trim().isNotEmpty || _query.categoryId != null;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _search(String text) => setState(() => _query = _query.copyWith(text: text));

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = Theme.of(context);
    final catalogue = ref.watch(catalogueProvider);
    final variantId = ref.watch(selectedVariantProvider);
    final query = _query.copyWith(variantId: () => variantId);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _text,
          autofocus: !_browsing,
          textInputAction: TextInputAction.search,
          onSubmitted: _search,
          onChanged: (v) {
            if (v.isEmpty) _search('');
          },
          decoration: InputDecoration(
            hintText: t.searchHint,
            filled: true,
            fillColor: theme.colorScheme.surfaceContainer,
            contentPadding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.md),
            border: const OutlineInputBorder(
              borderRadius: Radii.mdAll,
              borderSide: BorderSide.none,
            ),
            enabledBorder: const OutlineInputBorder(
              borderRadius: Radii.mdAll,
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: Radii.mdAll,
              borderSide: BorderSide(color: theme.colorScheme.secondary, width: 2),
            ),
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _text.text.isEmpty
                ? null
                : IconButton(
                    tooltip: context.core.actionClose,
                    onPressed: () {
                      _text.clear();
                      _search('');
                    },
                    icon: const Icon(Icons.close),
                  ),
          ),
        ),
        actions: const [SizedBox(width: Space.md)],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _FilterBar(
            query: query,
            hasCar: variantId != null,
            onChanged: (q) => setState(() => _query = q.copyWith(variantId: () => null)),
          ),
          Expanded(
            child: _browsing
                ? _Results(query: query)
                : _Suggestions(
                    onPick: (q) {
                      _text.text = q;
                      _search(q);
                    },
                    categories: catalogue.categories,
                    onCategory: (id) =>
                        setState(() => _query = _query.copyWith(categoryId: () => id)),
                    recent: _recent,
                  ),
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.query, required this.hasCar, required this.onChanged});

  final SearchQuery query;
  final bool hasCar;
  final ValueChanged<SearchQuery> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final core = context.core;
    final catalogue = CatalogueScope.of(context);
    final active = query.conditions.length + (query.maxPriceSdg == null ? 0 : 1);
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(bottom: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Space.page, vertical: Space.sm),
        children: [
          ActionChip(
            avatar: const Icon(Icons.tune, size: 18),
            label: Text(active == 0 ? t.searchFilters : '${t.searchFilters} ($active)'),
            onPressed: () async {
              final q = await showModalBottomSheet<SearchQuery>(
                context: context,
                isScrollControlled: true,
                builder: (_) => _FiltersSheet(query: query),
              );
              if (q != null) onChanged(q);
            },
          ),
          if (query.categoryId != null) ...[
            const SizedBox(width: Space.sm),
            InputChip(
              avatar: Icon(categoryIcon(catalogue.category(query.categoryId!).icon), size: 18),
              label: Text(catalogue.category(query.categoryId!).name.tr(context)),
              onDeleted: () => onChanged(query.copyWith(categoryId: () => null)),
              deleteButtonTooltipMessage: core.actionRemove,
            ),
          ],
          if (hasCar) ...[
            const SizedBox(width: Space.sm),
            FilterChip(
              label: Text(t.searchFitsOnly),
              selected: query.onlyFits,
              onSelected: (v) => onChanged(query.copyWith(onlyFits: v)),
            ),
          ],
          for (final c in ListingCondition.values) ...[
            const SizedBox(width: Space.sm),
            FilterChip(
              label: Text(core.condition(c)),
              selected: query.conditions.contains(c),
              onSelected: (v) => onChanged(
                query.copyWith(
                  conditions: v ? {...query.conditions, c} : ({...query.conditions}..remove(c)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Results extends ConsumerWidget {
  const _Results({required this.query});

  final SearchQuery query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final theme = Theme.of(context);
    final catalogue = ref.watch(catalogueProvider);
    final results = ref.watch(searchProvider(query));
    return switch (results) {
      AsyncData(:final value) when value.isEmpty => SingleChildScrollView(
        child: EmptyState(
          icon: Icons.search_off,
          title: t.searchNoResults,
          message: t.searchNoResultsBody,
          action: FilledButton.icon(
            onPressed: () => context.push(Routes.newRequest),
            icon: const Icon(Icons.add_a_photo_outlined),
            label: Text(t.searchSendPhoto),
          ),
        ),
      ),
      AsyncData(:final value) => ListView.separated(
        padding: const EdgeInsets.fromLTRB(Space.page, Space.md, Space.page, Space.xxl),
        itemCount: value.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: Space.sm),
        itemBuilder: (context, i) {
          if (i == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: Space.xs),
              child: Text(
                '${t.searchResults(value.length)} · ${query.variantId == null ? t.searchNoCar : t.searchShowingFor(carLabel(context, catalogue, query.variantId!, engine: false))}',
                style: theme.textTheme.bodySmall,
              ),
            );
          }
          final r = value[i - 1];
          return PartResultTile(
            key: ValueKey(r.part.id),
            result: r,
            shopsLabel: t.shopsCount(r.shopCount),
            onTap: () => context.push(Routes.part(r.part.id)),
          );
        },
      ),
      AsyncError() => ErrorState(onRetry: () => ref.invalidate(searchProvider(query))),
      _ => const SkeletonList(),
    };
  }
}

class _Suggestions extends StatelessWidget {
  const _Suggestions({
    required this.onPick,
    required this.categories,
    required this.onCategory,
    required this.recent,
  });

  final ValueChanged<String> onPick;
  final List<PartCategory> categories;
  final ValueChanged<String> onCategory;
  final List<String> recent;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return ListView(
      padding: const EdgeInsets.only(bottom: Space.xxl),
      children: [
        SectionHeader(title: t.searchRecent),
        for (final q in recent)
          ListTile(
            leading: const Icon(Icons.history),
            title: Text(q),
            trailing: const Icon(Icons.north_west, size: 18),
            onTap: () => onPick(q),
          ),
        SectionHeader(title: t.searchPopular),
        Padding(
          padding: Space.pageHorizontal,
          child: Wrap(
            spacing: Space.sm,
            runSpacing: Space.sm,
            children: [
              for (final c in categories)
                ActionChip(
                  avatar: Icon(categoryIcon(c.icon), size: 18),
                  label: Text(c.name.tr(context)),
                  onPressed: () => onCategory(c.id),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FiltersSheet extends StatefulWidget {
  const _FiltersSheet({required this.query});

  final SearchQuery query;

  @override
  State<_FiltersSheet> createState() => _FiltersSheetState();
}

class _FiltersSheetState extends State<_FiltersSheet> {
  late var _q = widget.query;
  static const _prices = [null, 10000, 50000, 100000, 250000];

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final core = context.core;
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.page, 0, Space.page, Space.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(t.filtersTitle, style: theme.textTheme.titleLarge),
            const SizedBox(height: Space.lg),
            Text(t.filtersCondition, style: theme.textTheme.titleSmall),
            const SizedBox(height: Space.sm),
            Wrap(
              spacing: Space.sm,
              runSpacing: Space.sm,
              children: [
                for (final c in ListingCondition.values)
                  FilterChip(
                    label: Text(core.condition(c)),
                    selected: _q.conditions.contains(c),
                    onSelected: (v) => setState(
                      () => _q = _q.copyWith(
                        conditions: v ? {..._q.conditions, c} : ({..._q.conditions}..remove(c)),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: Space.lg),
            Text(t.filtersMaxPrice, style: theme.textTheme.titleSmall),
            const SizedBox(height: Space.sm),
            Wrap(
              spacing: Space.sm,
              runSpacing: Space.sm,
              children: [
                for (final p in _prices)
                  ChoiceChip(
                    label: Text(p == null ? t.filtersAnyPrice : t.filtersUpTo(context.sdg(p))),
                    selected: _q.maxPriceSdg == p,
                    onSelected: (_) => setState(() => _q = _q.copyWith(maxPriceSdg: () => p)),
                  ),
              ],
            ),
            const SizedBox(height: Space.lg),
            Text(t.filtersSort, style: theme.textTheme.titleSmall),
            RadioGroup<SearchSort>(
              groupValue: _q.sort,
              onChanged: (s) {
                if (s != null) setState(() => _q = _q.copyWith(sort: s));
              },
              child: Column(
                children: [
                  for (final (s, label) in [
                    (SearchSort.relevance, t.sortRelevance),
                    (SearchSort.priceLow, t.sortPriceLow),
                    (SearchSort.priceHigh, t.sortPriceHigh),
                    (SearchSort.rating, t.sortRating),
                  ])
                    RadioListTile<SearchSort>(
                      value: s,
                      title: Text(label),
                      contentPadding: EdgeInsets.zero,
                    ),
                ],
              ),
            ),
            const SizedBox(height: Space.md),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () =>
                        setState(() => _q = SearchQuery(text: _q.text, categoryId: _q.categoryId)),
                    child: Text(t.filtersReset),
                  ),
                ),
                const SizedBox(width: Space.md),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, _q),
                    child: Text(t.filtersApply),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
