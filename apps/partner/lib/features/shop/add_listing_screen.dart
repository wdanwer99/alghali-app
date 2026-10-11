import 'package:alghali_core/alghali_core.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../state/shop_state.dart';

/// Quick listing: photo → part → cars → price. Drafts work offline (brief §8).
class AddListingScreen extends ConsumerStatefulWidget {
  const AddListingScreen({super.key});

  @override
  ConsumerState<AddListingScreen> createState() => _AddListingScreenState();
}

class _AddListingScreenState extends ConsumerState<AddListingScreen> {
  var _step = 0;
  var _photo = false;
  String? _categoryId;
  final _name = TextEditingController();
  final _models = <String>{};
  var _unsure = false;
  var _condition = ListingCondition.newAftermarket;
  final _price = TextEditingController();
  var _qty = 1;
  var _warranty = 30;

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    super.dispose();
  }

  bool get _valid => switch (_step) {
    0 => _photo,
    1 => _categoryId != null && _name.text.trim().isNotEmpty,
    2 => _unsure || _models.isNotEmpty,
    _ => (int.tryParse(_price.text) ?? 0) > 0,
  };

  void _save({required bool draft}) {
    ref
        .read(stockProvider.notifier)
        .add(
          StockItem(
            id: 'ls-new-${DateTime.now().microsecondsSinceEpoch}',
            title: LocalizedText(_name.text.trim(), _name.text.trim()),
            categoryId: _categoryId!,
            condition: _condition,
            priceSdg: int.parse(_price.text),
            qty: _qty,
            warrantyDays: _warranty,
            visible: !draft,
            draft: draft,
          ),
        );
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(draft ? context.t.draftSaved : context.t.published)));
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final core = context.core;
    final theme = Theme.of(context);
    final catalogue = ref.watch(catalogueProvider);

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
            color: _photo ? AppColors.of(context).successContainer : theme.colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: Radii.lgAll,
              side: BorderSide(
                color: _photo ? AppColors.of(context).success : theme.colorScheme.outline,
              ),
            ),
            child: InkWell(
              borderRadius: Radii.lgAll,
              onTap: () => setState(() => _photo = !_photo),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(_photo ? Icons.check_circle_rounded : Icons.photo_camera_outlined, size: 48),
                  const SizedBox(height: Space.sm),
                  Text(_photo ? t.photoAdded : t.takePhoto, style: theme.textTheme.titleSmall),
                ],
              ),
            ),
          ),
        ),
      ],
      1 => [
        Text(t.categoryTitle, style: theme.textTheme.titleLarge),
        const SizedBox(height: Space.lg),
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
      ],
      2 => [
        Text(t.carsTitle, style: theme.textTheme.titleLarge),
        const SizedBox(height: Space.lg),
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
                        onPressed: _valid ? () => _save(draft: true) : null,
                        child: Text(t.saveDraft),
                      ),
                    ),
                    const SizedBox(width: Space.md),
                    Expanded(
                      child: FilledButton(
                        onPressed: _valid ? () => _save(draft: false) : null,
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
