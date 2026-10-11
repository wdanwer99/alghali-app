import 'package:alghali_core/alghali_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../router.dart';
import '../../state/garage.dart';
import '../../widgets/buyer_widgets.dart';

class GarageScreen extends ConsumerWidget {
  const GarageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final theme = Theme.of(context);
    final garage = ref.watch(garageProvider);
    final catalogue = ref.watch(catalogueProvider);
    final controller = ref.read(garageProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: Text(t.garageTitle)),
      body: garage.vehicles.isEmpty
          ? EmptyState(
              icon: Icons.directions_car_outlined,
              title: t.garageEmpty,
              message: t.garageEmptyBody,
            )
          : ListView.separated(
              padding: Space.pageInsets,
              itemCount: garage.vehicles.length,
              separatorBuilder: (_, _) => const SizedBox(height: Space.sm),
              itemBuilder: (context, i) {
                final v = garage.vehicles[i];
                final selected = garage.selected?.id == v.id;
                final variant = catalogue.variant(v.variantId);
                final name = carName(context, catalogue, v.variantId);
                return Card(
                  key: ValueKey(v.id),
                  shape: RoundedRectangleBorder(
                    borderRadius: Radii.mdAll,
                    side: BorderSide(
                      color: selected
                          ? theme.colorScheme.secondary
                          : theme.colorScheme.outlineVariant,
                      width: selected ? 2 : 1,
                    ),
                  ),
                  child: InkWell(
                    onTap: () => controller.select(v.id),
                    child: Padding(
                      padding: const EdgeInsets.all(Space.lg),
                      child: Row(
                        children: [
                          IconTile(
                            icon: Icons.directions_car_filled,
                            size: 52,
                            tone: selected ? Tone.brand : Tone.neutral,
                          ),
                          const SizedBox(width: Space.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name, style: theme.textTheme.titleMedium),
                                Text(
                                  '${variant.years} · ${variant.engine.tr(context)}',
                                  style: theme.textTheme.bodyMedium,
                                ),
                                const SizedBox(height: Space.xs),
                                if (selected)
                                  StatusPill(
                                    label: t.garageSelected,
                                    tone: Tone.success,
                                    icon: Icons.check_circle_rounded,
                                  )
                                else
                                  Text(
                                    t.garageUse,
                                    style: theme.textTheme.labelLarge?.copyWith(
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: t.garageRemove,
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () async {
                              final ok = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: Text(t.garageRemoveConfirm(name)),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, false),
                                      child: Text(context.core.actionCancel),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, true),
                                      child: Text(t.garageRemove),
                                    ),
                                  ],
                                ),
                              );
                              if (ok ?? false) await controller.remove(v.id);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
      bottomNavigationBar: BottomActionBar(
        child: FilledButton.icon(
          onPressed: () => context.push(Routes.addCar),
          icon: const Icon(Icons.add),
          label: Text(t.garageAdd),
        ),
      ),
    );
  }
}

/// Make → model → years/engine, with big tap targets.
class AddCarScreen extends ConsumerStatefulWidget {
  const AddCarScreen({super.key});

  @override
  ConsumerState<AddCarScreen> createState() => _AddCarScreenState();
}

class _AddCarScreenState extends ConsumerState<AddCarScreen> {
  VehicleMake? _make;
  VehicleModel? _model;

  int get _step => _make == null ? 0 : (_model == null ? 1 : 2);

  void _back() => setState(() {
    if (_model != null) {
      _model = null;
    } else {
      _make = null;
    }
  });

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = Theme.of(context);
    final catalogue = ref.watch(catalogueProvider);

    Widget option(String title, {String? subtitle, Widget? leading, required VoidCallback onTap}) =>
        Padding(
          padding: const EdgeInsets.only(bottom: Space.sm),
          child: TapCard(
            onTap: onTap,
            padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.md),
            child: Row(
              children: [
                if (leading != null) ...[leading, const SizedBox(width: Space.md)],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.titleMedium),
                      if (subtitle != null) Text(subtitle, style: theme.textTheme.bodySmall),
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

    final (title, options) = switch (_step) {
      0 => (
        t.addCarMake,
        [
          for (final m in catalogue.makes)
            option(
              m.name.tr(context),
              leading: InitialsAvatar(name: m.name.en, size: 40),
              subtitle: catalogue.modelsOf(m.id).map((x) => x.name.tr(context)).join('، '),
              onTap: () => setState(() => _make = m),
            ),
        ],
      ),
      1 => (
        t.addCarModel,
        [
          for (final m in catalogue.modelsOf(_make!.id))
            option(m.name.tr(context), onTap: () => setState(() => _model = m)),
        ],
      ),
      _ => (
        t.addCarYear,
        [
          for (final v in catalogue.variantsOf(_model!.id))
            option(
              v.years,
              subtitle: v.engine.tr(context),
              onTap: () async {
                await ref.read(garageProvider.notifier).add(v.id);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(t.addCarSaved(carName(context, catalogue, v.id)))),
                );
                context.pop();
              },
            ),
        ],
      ),
    };

    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        appBar: AppBar(title: Text(t.addCarTitle)),
        body: ListView(
          padding: Space.pageInsets,
          children: [
            if (_make != null) ...[
              Wrap(
                spacing: Space.sm,
                children: [
                  InputChip(
                    avatar: const Icon(Icons.directions_car_outlined, size: 18),
                    label: Text(_make!.name.tr(context)),
                    deleteButtonTooltipMessage: context.core.actionEdit,
                    onDeleted: () => setState(() {
                      _make = null;
                      _model = null;
                    }),
                  ),
                  if (_model != null)
                    InputChip(
                      label: Text(_model!.name.tr(context)),
                      deleteButtonTooltipMessage: context.core.actionEdit,
                      onDeleted: () => setState(() => _model = null),
                    ),
                ],
              ),
              const SizedBox(height: Space.lg),
            ],
            Text(title, style: theme.textTheme.titleLarge),
            const SizedBox(height: Space.md),
            ...options,
          ],
        ),
      ),
    );
  }
}
