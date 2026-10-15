import 'dart:typed_data';

import 'package:alghali_core/alghali_core.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../router.dart';
import '../../state/shop.dart';
import '../../widgets/partner_widgets.dart';

/// Quick listing: photo → part → cars → price (brief §8). It is kept on the phone with
/// its photo and sent when online (D-122); a draft stays hidden from buyers.
class AddListingScreen extends ConsumerStatefulWidget {
  const AddListingScreen({super.key});

  @override
  ConsumerState<AddListingScreen> createState() => _AddListingScreenState();
}

class _AddListingScreenState extends ConsumerState<AddListingScreen> {
  var _step = 0;
  Uint8List? _photo;
  var _noPhoto = false;
  String? _categoryId;
  final _name = TextEditingController();

  /// A catalogue part picked from the suggestions (its cars come from the catalogue).
  PartSuggestion? _part;
  final _models = <String>{};
  var _unsure = false;
  var _condition = ListingCondition.newAftermarket;
  final _price = TextEditingController();
  var _qty = 1;
  var _warranty = 30;
  var _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    super.dispose();
  }

  bool get _valid => switch (_step) {
    0 => _photo != null || _noPhoto,
    1 => _part != null || (_categoryId != null && _name.text.trim().length >= 2),
    2 => _part != null || _unsure || _models.isNotEmpty,
    _ => (int.tryParse(_price.text) ?? 0) > 0,
  };

  Future<void> _takePhoto() async {
    final photo = await pickPhoto(context, ref);
    if (photo != null && mounted) setState(() => _photo = photo.bytes);
  }

  Future<void> _save({required bool draft}) async {
    final t = context.t;
    setState(() => _saving = true);
    final part = _part;
    await ref
        .read(stockProvider.notifier)
        .create(
          ListingDraft(
            condition: _condition,
            stockQty: _qty,
            priceSdg: int.parse(_price.text),
            warrantyDays: _warranty,
            active: !draft,
            partId: part?.id,
            newPart: part != null
                ? null
                : NewPart(
                    nameAr: _name.text.trim(),
                    categoryId: _categoryId!,
                    modelIds: _unsure ? const [] : _models.toList(),
                  ),
          ),
          photo: _photo,
        );
    if (!mounted) return;
    final online = ref.read(onlineProvider);
    showSnack(context, !online ? t.listingSavedOffline : (draft ? t.draftSaved : t.published));
    context.canPop() ? context.pop() : context.go(Routes.shopStock);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final core = context.core;
    final theme = Theme.of(context);
    final catalogue = ref.watch(catalogueProvider);
    final suggestions = _step == 1 && _part == null
        ? ref.watch(partSuggestionsProvider((query: _name.text, categoryId: _categoryId))).value ??
              const <PartSuggestion>[]
        : const <PartSuggestion>[];

    final body = switch (_step) {
      0 => [
        Text(t.photoTitle, style: theme.textTheme.titleLarge),
        const SizedBox(height: Space.xs),
        Text(
          t.photoBody,
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: Space.xl),
        AspectRatio(
          aspectRatio: 4 / 3,
          child: Material(
            color: _photo != null
                ? AppColors.of(context).successContainer
                : theme.colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: Radii.lgAll,
              side: BorderSide(
                color: _photo != null ? AppColors.of(context).success : theme.colorScheme.outline,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: _takePhoto,
              child: _photo != null
                  ? Image.memory(_photo!, fit: BoxFit.cover)
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.photo_camera_outlined, size: 48),
                        const SizedBox(height: Space.sm),
                        Text(t.takePhoto, style: theme.textTheme.titleSmall),
                      ],
                    ),
            ),
          ),
        ),
        if (_photo != null) ...[
          const SizedBox(height: Space.sm),
          TextButton.icon(
            onPressed: _takePhoto,
            icon: const Icon(Icons.refresh),
            label: Text(t.retakePhoto),
          ),
        ] else
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _noPhoto,
            onChanged: (v) => setState(() => _noPhoto = v ?? false),
            title: Text(t.noPhoto),
          ),
      ],
      1 => [
        Text(t.categoryTitle, style: theme.textTheme.titleLarge),
        const SizedBox(height: Space.lg),
        if (_part case final p?)
          Card(
            child: ListTile(
              leading: const Icon(Icons.verified_outlined),
              title: Text(p.name.tr(context)),
              subtitle: Text(t.fromCatalogue),
              trailing: IconButton(
                tooltip: core.actionRemove,
                onPressed: () => setState(() => _part = null),
                icon: const Icon(Icons.close),
              ),
            ),
          )
        else ...[
          Wrap(
            spacing: Space.sm,
            runSpacing: Space.sm,
            children: [
              for (final c in catalogue.categories)
                ChoiceChip(
                  avatar: Icon(categoryIcon(c.icon), size: 18),
                  label: Text(c.name.tr(context)),
                  selected: _categoryId == c.id,
                  onSelected: (_) => setState(() => _categoryId = c.id),
                ),
            ],
          ),
          const SizedBox(height: Space.xl),
          TextField(
            controller: _name,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(labelText: t.partName, hintText: t.partNameHint),
          ),
          if (suggestions.isNotEmpty) ...[
            const SizedBox(height: Space.sm),
            Text(t.suggestionsTitle, style: theme.textTheme.labelLarge),
            for (final s in suggestions.take(6))
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(s.verified ? Icons.verified_outlined : Icons.storefront_outlined),
                title: Text(s.name.tr(context)),
                subtitle: Text(catalogue.category(s.categoryId).name.tr(context)),
                onTap: () => setState(() {
                  _part = s;
                  _categoryId = s.categoryId;
                }),
              ),
          ],
        ],
      ],
      2 => [
        Text(t.carsTitle, style: theme.textTheme.titleLarge),
        const SizedBox(height: Space.lg),
        if (_part != null)
          InfoBanner(tone: Tone.info, icon: Icons.verified_outlined, message: t.carsFromCatalogue)
        else ...[
          for (final make in catalogue.makes) ...[
            Text(make.name.tr(context), style: theme.textTheme.titleSmall),
            const SizedBox(height: Space.xs),
            Wrap(
              spacing: Space.sm,
              runSpacing: Space.sm,
              children: [
                for (final m in catalogue.modelsOf(make.id))
                  FilterChip(
                    label: Text(m.name.tr(context)),
                    selected: _models.contains(m.id),
                    onSelected: _unsure
                        ? null
                        : (v) => setState(() => v ? _models.add(m.id) : _models.remove(m.id)),
                  ),
              ],
            ),
            const SizedBox(height: Space.md),
          ],
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _unsure,
            onChanged: (v) => setState(() {
              _unsure = v ?? false;
              if (_unsure) _models.clear();
            }),
            title: Text(t.carsUnknown),
          ),
        ],
      ],
      _ => [
        Text(t.stepPrice, style: theme.textTheme.titleLarge),
        const SizedBox(height: Space.lg),
        Text(t.conditionLabel, style: theme.textTheme.titleSmall),
        const SizedBox(height: Space.sm),
        Wrap(
          spacing: Space.sm,
          children: [
            for (final c in ListingCondition.values)
              ChoiceChip(
                label: Text(core.condition(c)),
                selected: _condition == c,
                onSelected: (_) => setState(() => _condition = c),
              ),
          ],
        ),
        const SizedBox(height: Space.lg),
        TextField(
          controller: _price,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          textDirection: TextDirection.ltr,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(labelText: t.priceField),
        ),
        const SizedBox(height: Space.lg),
        Row(
          children: [
            Expanded(child: Text(t.qtyField, style: theme.textTheme.titleSmall)),
            QuantityStepper(value: _qty, max: 999, onChanged: (v) => setState(() => _qty = v)),
          ],
        ),
        const SizedBox(height: Space.lg),
        Text(t.warrantyLabel, style: theme.textTheme.titleSmall),
        const SizedBox(height: Space.sm),
        Wrap(
          spacing: Space.sm,
          runSpacing: Space.sm,
          children: [
            for (final d in [0, 14, 30, 90, 180, 365])
              ChoiceChip(
                label: Text(core.warranty(d)),
                selected: _warranty == d,
                onSelected: (_) => setState(() => _warranty = d),
              ),
          ],
        ),
        const SizedBox(height: Space.lg),
        InfoBanner(tone: Tone.neutral, icon: Icons.cloud_off_outlined, message: t.draftOffline),
      ],
    };

    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _step--);
      },
      child: Scaffold(
        appBar: AppBar(title: Text(t.addTitle)),
        body: Column(
          children: [
            Container(
              color: theme.colorScheme.surface,
              padding: const EdgeInsets.fromLTRB(Space.sm, Space.md, Space.sm, Space.md),
              child: StepProgress(
                steps: [t.stepPhoto, t.stepPart, t.stepCars, t.stepPrice],
                current: _step,
              ),
            ),
            const Divider(),
            Expanded(
              child: ListView(padding: Space.pageInsets, children: body),
            ),
          ],
        ),
        bottomNavigationBar: BottomActionBar(
          child: _step < 3
              ? FilledButton(
                  onPressed: _valid ? () => setState(() => _step++) : null,
                  child: Text(core.actionNext),
                )
              : Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _valid && !_saving ? () => _save(draft: true) : null,
                        child: Text(t.saveDraft),
                      ),
                    ),
                    const SizedBox(width: Space.md),
                    Expanded(
                      child: FilledButton(
                        onPressed: _valid && !_saving ? () => _save(draft: false) : null,
                        child: Text(t.publish),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
