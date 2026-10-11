import 'package:alghali_core/alghali_core.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../router.dart';
import '../../state/shop_state.dart';

enum _Filter { all, low, out, hidden }

/// Stock and prices with one-tap editing and bulk price changes
/// (`shop_bulk_update`); confirmed orders keep their locked price.
class StockScreen extends ConsumerStatefulWidget {
  const StockScreen({super.key, this.filter});

  final String? filter;

  @override
  ConsumerState<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends ConsumerState<StockScreen> {
  late var _filter = widget.filter == 'low' ? _Filter.low : _Filter.all;
  var _query = '';
  var _bulk = false;
  final _selected = <String>{};

  @override
  void didUpdateWidget(StockScreen old) {
    super.didUpdateWidget(old);
    if (widget.filter != old.filter && widget.filter == 'low') _filter = _Filter.low;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = Theme.of(context);
    final all = ref.watch(stockProvider);
    final q = arNormalize(_query);
    final items = all.where((s) {
      if (q.isNotEmpty && !arNormalize('${s.title.ar} ${s.title.en}').contains(q)) return false;
      return switch (_filter) {
        _Filter.all => true,
        _Filter.low => s.isLow,
        _Filter.out => s.qty == 0,
        _Filter.hidden => !s.visible,
      };
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(_bulk ? t.selectedCount(_selected.length) : t.shopNavStock),
        actions: [
          TextButton.icon(
            onPressed: () => setState(() {
              _bulk = !_bulk;
              _selected.clear();
            }),
            icon: Icon(_bulk ? Icons.close : Icons.checklist),
            label: Text(_bulk ? context.core.actionCancel : t.bulkEdit),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Space.page, Space.md, Space.page, 120),
        children: [
          TextField(
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: t.stockSearch,
              prefixIcon: const Icon(Icons.search),
            ),
          ),
          const SizedBox(height: Space.md),
          Wrap(
            spacing: Space.sm,
            children: [
              for (final (f, label) in [
                (_Filter.all, t.filterAll),
                (_Filter.low, t.filterLow),
                (_Filter.out, t.filterOut),
                (_Filter.hidden, t.filterHidden),
              ])
                ChoiceChip(
                  label: Text(label),
                  selected: _filter == f,
                  onSelected: (_) => setState(() => _filter = f),
                ),
            ],
          ),
          const SizedBox(height: Space.md),
          if (!_bulk) ...[
            TapCard(
              onTap: () => _import(context),
              child: Row(
                children: [
                  const IconTile(icon: Icons.table_view_outlined, tone: Tone.success),
                  const SizedBox(width: Space.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t.importExcel, style: theme.textTheme.titleSmall),
                        Text(t.importBody, style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Space.md),
          ],
          for (final item in items) ...[
            _StockRow(
              key: ValueKey(item.id),
              item: item,
              bulk: _bulk,
              selected: _selected.contains(item.id),
              onTap: () => _bulk
                  ? setState(
                      () => _selected.contains(item.id)
                          ? _selected.remove(item.id)
                          : _selected.add(item.id),
                    )
                  : _edit(context, item),
            ),
            const SizedBox(height: Space.sm),
          ],
          if (items.isEmpty)
            EmptyState(icon: Icons.inventory_2_outlined, title: t.ordersEmpty, compact: true),
        ],
      ),
      floatingActionButton: _bulk
          ? null
          : FloatingActionButton.extended(
              onPressed: () => context.push(Routes.shopAdd),
              icon: const Icon(Icons.add),
              label: Text(t.quickAddPart),
            ),
      bottomNavigationBar: !_bulk
          ? null
          : BottomActionBar(
              top: Text(t.bulkPriceBy, style: theme.textTheme.titleSmall),
              child: Row(
                children: [
                  for (final (i, p) in [-10, -5, 5, 10].indexed) ...[
                    if (i > 0) const SizedBox(width: Space.sm),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _selected.isEmpty
                            ? null
                            : () {
                                final n = ref
                                    .read(stockProvider.notifier)
                                    .bulkPercent(_selected, p);
                                setState(() {
                                  _bulk = false;
                                  _selected.clear();
                                });
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(SnackBar(content: Text(t.bulkDone(n))));
                              },
                        child: Text(ltr(p > 0 ? '+$p%' : '$p%')),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Future<void> _edit(BuildContext context, StockItem item) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _EditSheet(item: item),
  );

  Future<void> _import(BuildContext context) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.table_view_outlined),
      title: Text(context.t.importExcel),
      content: Text(context.t.importBody),
      actions: [
        TextButton(
          onPressed: () => showDemoDisabled(context),
          child: Text(context.t.downloadTemplate),
        ),
        FilledButton(onPressed: () => showDemoDisabled(context), child: Text(context.t.uploadFile)),
      ],
    ),
  );
}

class _StockRow extends ConsumerWidget {
  const _StockRow({
    super.key,
    required this.item,
    required this.bulk,
    required this.selected,
    required this.onTap,
  });

  final StockItem item;
  final bool bulk;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final core = context.core;
    final theme = Theme.of(context);
    final category = ref.watch(catalogueProvider).category(item.categoryId);
    return TapCard(
      onTap: onTap,
      child: Row(
        children: [
          if (bulk) ...[
            Checkbox(value: selected, onChanged: (_) => onTap()),
            const SizedBox(width: Space.xs),
          ],
          PartThumb(icon: category.icon, size: 56),
          const SizedBox(width: Space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title.tr(context),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
                Text(core.condition(item.condition), style: theme.textTheme.bodySmall),
                const SizedBox(height: Space.xs),
                Wrap(
                  spacing: Space.xs,
                  runSpacing: Space.xs,
                  children: [
                    StatusPill(
                      label: item.qty == 0 ? core.outOfStock : t.qty(item.qty),
                      tone: item.qty == 0
                          ? Tone.danger
                          : (item.isLow ? Tone.warning : Tone.neutral),
                    ),
                    if (item.draft)
                      StatusPill(label: t.draft, tone: Tone.info, icon: Icons.edit_note)
                    else if (!item.visible)
                      StatusPill(label: t.hiddenFromBuyers, icon: Icons.visibility_off_outlined),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: Space.sm),
          Text(
            context.sdg(item.priceSdg),
            style: theme.textTheme.titleSmall?.copyWith(fontFeatures: AppTypography.tabular),
          ),
        ],
      ),
    );
  }
}

class _EditSheet extends ConsumerStatefulWidget {
  const _EditSheet({required this.item});

  final StockItem item;

  @override
  ConsumerState<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends ConsumerState<_EditSheet> {
  late final _price = TextEditingController(text: '${widget.item.priceSdg}');
  late var _qty = widget.item.qty;
  late var _visible = widget.item.visible;

  @override
  void dispose() {
    _price.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Space.page, 0, Space.page, Space.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(t.editListing, style: theme.textTheme.titleLarge),
              Text(widget.item.title.tr(context), style: theme.textTheme.bodyMedium),
              const SizedBox(height: Space.lg),
              TextField(
                controller: _price,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(labelText: t.priceField, helperText: t.priceLockNote),
              ),
              const SizedBox(height: Space.lg),
              Row(
                children: [
                  Expanded(child: Text(t.qtyField, style: theme.textTheme.titleSmall)),
                  QuantityStepper(
                    value: _qty,
                    min: 0,
                    max: 999,
                    onChanged: (v) => setState(() => _qty = v),
                  ),
                ],
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(t.visibleToBuyers),
                value: _visible,
                onChanged: (v) => setState(() => _visible = v),
              ),
              const SizedBox(height: Space.md),
              FilledButton(
                onPressed: () {
                  ref
                      .read(stockProvider.notifier)
                      .update(
                        widget.item.id,
                        priceSdg: int.tryParse(_price.text) ?? widget.item.priceSdg,
                        qty: _qty,
                        visible: _visible,
                      );
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.saved)));
                },
                child: Text(context.core.actionSave),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
