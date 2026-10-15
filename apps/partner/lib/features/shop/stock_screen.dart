import 'dart:typed_data';

import 'package:alghali_core/alghali_core.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../router.dart';
import '../../state/session.dart';
import '../../state/shop.dart';
import '../../widgets/partner_widgets.dart';
import 'shop_home_screen.dart' show lowStockAt;

enum _Filter { all, low, out, hidden }

/// A stock sheet picked from the phone; tests swap the picker.
typedef PickedSheet = ({Uint8List bytes, String name});

final sheetPickerProvider = Provider<Future<PickedSheet?> Function()>(
  (ref) => () async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['xlsx', 'xls', 'csv'],
    );
    if (file == null) return null;
    return (bytes: await file.xFile.readAsBytes(), name: file.name);
  },
);

/// Stock and prices with one-tap editing and bulk price changes (`shop_bulk_update`),
/// kept on the phone and sent when online (D-122); confirmed orders keep their price.
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
    final value = ref.watch(stockProvider);
    final q = arNormalize(_query);

    Widget list(List<ShopListing> all) {
      final items = all.where((s) {
        if (q.isNotEmpty &&
            !arNormalize('${s.partName.ar} ${s.partName.en} ${s.sku ?? ''}').contains(q)) {
          return false;
        }
        return switch (_filter) {
          _Filter.all => true,
          _Filter.low => s.active && s.availableQty > 0 && s.availableQty <= lowStockAt,
          _Filter.out => s.availableQty == 0,
          _Filter.hidden => !s.active,
        };
      }).toList();
      return ListView(
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
            EmptyState(
              icon: Icons.inventory_2_outlined,
              title: all.isEmpty ? t.stockEmpty : t.stockNoMatch,
              message: all.isEmpty ? t.stockEmptyBody : null,
              compact: true,
            ),
        ],
      );
    }

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
      body: AsyncBody(
        value: value,
        onRefresh: () => ref.read(stockProvider.notifier).refresh(),
        data: list,
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
                            : () async {
                                final n = await ref
                                    .read(stockProvider.notifier)
                                    .bulkPercent(_selected, p);
                                if (!context.mounted) return;
                                setState(() {
                                  _bulk = false;
                                  _selected.clear();
                                });
                                showSnack(context, t.bulkDone(n));
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

  Future<void> _edit(BuildContext context, ShopListing item) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _EditSheet(item: item),
  );

  /// Template → filled sheet → a dry run that lists problems → the import itself.
  Future<void> _import(BuildContext context) async {
    final t = context.t;
    final env = ref.read(appEnvProvider);
    final action = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.table_view_outlined),
        title: Text(t.importExcel),
        content: Text(t.importBody),
        actions: [
          TextButton(
            onPressed: () => Launch.open(
              '${env.supabaseUrl}/storage/v1/object/public/templates/inventory-template.xlsx',
            ),
            child: Text(t.downloadTemplate),
          ),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(t.uploadFile)),
        ],
      ),
    );
    if (action != true || !context.mounted) return;
    final sheet = await ref.read(sheetPickerProvider)();
    if (sheet == null || !context.mounted) return;
    final shopId = ref.read(currentShopIdProvider)!;
    final repo = ref.read(shopRepositoryProvider);
    try {
      final check = await repo.importStock(shopId, sheet.bytes, sheet.name, dryRun: true);
      if (!context.mounted) return;
      final go = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        builder: (_) => _ImportReportSheet(report: check),
      );
      if (go != true || !context.mounted) return;
      final done = await repo.importStock(shopId, sheet.bytes, sheet.name);
      if (!context.mounted) return;
      showSnack(context, t.importDone(done.created, done.updated, done.failed));
      await ref.read(stockProvider.notifier).refresh();
    } on BackendException catch (e) {
      if (context.mounted) showError(context, e);
    }
  }
}

class _StockRow extends ConsumerWidget {
  const _StockRow({
    super.key,
    required this.item,
    required this.bulk,
    required this.selected,
    required this.onTap,
  });

  final ShopListing item;
  final bool bulk;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final core = context.core;
    final theme = Theme.of(context);
    final category = ref.watch(catalogueProvider).category(item.categoryId);
    final pending = ref.watch(stockPendingProvider).contains(item.id);
    final reserved = item.stockQty - item.availableQty;
    final low = item.availableQty > 0 && item.availableQty <= lowStockAt;
    return TapCard(
      onTap: onTap,
      child: Row(
        children: [
          if (bulk) ...[
            Checkbox(value: selected, onChanged: (_) => onTap()),
            const SizedBox(width: Space.xs),
          ],
          PartThumb(
            icon: category.icon,
            size: 56,
            imageUrl: thumbUrl(ref, item.images.firstOrNull),
          ),
          const SizedBox(width: Space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.partName.tr(context),
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
                      label: item.availableQty == 0 ? core.outOfStock : t.qty(item.availableQty),
                      tone: item.availableQty == 0
                          ? Tone.danger
                          : (low ? Tone.warning : Tone.neutral),
                    ),
                    if (reserved > 0) StatusPill(label: t.reservedQty(reserved)),
                    if (!item.active)
                      StatusPill(label: t.hiddenFromBuyers, icon: Icons.visibility_off_outlined),
                    if (pending)
                      StatusPill(label: core.queuedOffline, tone: Tone.info, icon: Icons.schedule),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: Space.sm),
          Text(
            item.priceSdg == null ? t.priceOnRequest : context.sdg(item.priceSdg!),
            style: theme.textTheme.titleSmall?.copyWith(fontFeatures: AppTypography.tabular),
          ),
        ],
      ),
    );
  }
}

class _EditSheet extends ConsumerStatefulWidget {
  const _EditSheet({required this.item});

  final ShopListing item;

  @override
  ConsumerState<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends ConsumerState<_EditSheet> {
  late final _price = TextEditingController(text: '${widget.item.priceSdg ?? ''}');
  late var _qty = widget.item.stockQty;
  late var _visible = widget.item.active;

  @override
  void dispose() {
    _price.dispose();
    super.dispose();
  }

  Future<void> _archive() async {
    final t = context.t;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.archiveTitle),
        content: Text(t.archiveBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.core.actionCancel),
          ),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(t.archive)),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await ref
          .read(shopRepositoryProvider)
          .archiveListing(ref.read(currentShopIdProvider)!, widget.item.id);
      await ref.read(stockProvider.notifier).refresh();
      if (mounted) Navigator.pop(context);
    } on BackendException catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = Theme.of(context);
    final item = widget.item;
    final reserved = item.stockQty - item.availableQty;
    final queued = item.version == 0;
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
              Text(item.partName.tr(context), style: theme.textTheme.bodyMedium),
              if (queued) ...[
                const SizedBox(height: Space.md),
                InfoBanner(tone: Tone.info, icon: Icons.schedule, message: t.listingQueued),
              ] else ...[
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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t.qtyField, style: theme.textTheme.titleSmall),
                          if (reserved > 0)
                            Text(t.reservedNote(reserved), style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ),
                    QuantityStepper(
                      value: _qty,
                      min: reserved,
                      max: 9999,
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
                  onPressed: () async {
                    await ref
                        .read(stockProvider.notifier)
                        .edit(
                          item,
                          priceSdg: int.tryParse(_price.text),
                          stockQty: _qty,
                          active: _visible,
                        );
                    if (!context.mounted) return;
                    Navigator.pop(context);
                    showSnack(context, t.saved);
                  },
                  child: Text(context.core.actionSave),
                ),
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
                  onPressed: _archive,
                  child: Text(t.archive),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// What a dry run found: how many rows would be added or changed, and each problem row.
class _ImportReportSheet extends StatelessWidget {
  const _ImportReportSheet({required this.report});

  final ImportReport report;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = Theme.of(context);
    final ok = report.created + report.updated;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(Space.page, 0, Space.page, Space.lg),
          children: [
            Text(t.importCheckTitle, style: theme.textTheme.titleLarge),
            const SizedBox(height: Space.sm),
            Text(
              t.importCheckBody(report.created, report.updated, report.failed),
              style: theme.textTheme.bodyLarge,
            ),
            for (final e in report.errors.take(20))
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.error_outline),
                title: Text(t.importRow(e.row)),
                subtitle: Text(importIssueLabel(t, e.code)),
              ),
            for (final w in report.warnings.take(10))
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.warning_amber_rounded),
                title: Text(t.importRow(w.row)),
                subtitle: Text('${importIssueLabel(t, w.code)} ${w.value ?? ''}'.trim()),
              ),
            const SizedBox(height: Space.lg),
            FilledButton(
              onPressed: ok == 0 ? null : () => Navigator.pop(context, true),
              child: Text(t.importGo(ok)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.core.actionCancel),
            ),
          ],
        ),
      ),
    );
  }
}

/// A sheet row's problem in words (codes from `inventory-import`, D-078).
String importIssueLabel(AppLocalizations t, String code) => switch (code) {
  'NAME_REQUIRED' => t.importErrName,
  'CATEGORY_REQUIRED' || 'CATEGORY_NOT_FOUND' => t.importErrCategory,
  'CONDITION_REQUIRED' || 'INVALID_CONDITION' => t.importErrCondition,
  'INVALID_PRICE' || 'PRICE_REQUIRED' => t.importErrPrice,
  'INVALID_QTY' => t.importErrQty,
  'INVALID_WARRANTY' => t.importErrWarranty,
  'DUPLICATE_SKU' => t.importErrSku,
  'STOCK_BELOW_RESERVED' => t.importErrReserved,
  'MODEL_NOT_FOUND' => t.importWarnModel,
  _ => t.importErrValue,
};
