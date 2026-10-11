import 'package:alghali_core/alghali_core.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../router.dart';
import '../../state/tech_state.dart';
import '../../widgets/partner_widgets.dart';
import '../shop/shop_more_screen.dart';

/// Skills with the technician's own labour prices (D-010), work mode,
/// travel radius and app settings.
class TechProfileScreen extends ConsumerWidget {
  const TechProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final core = context.core;
    final theme = Theme.of(context);
    final catalogue = ref.watch(catalogueProvider);
    final tech = catalogue.technician('tc-osman');
    final profile = ref.watch(techProfileProvider);
    final controller = ref.read(techProfileProvider.notifier);
    final chevron = Directionality.of(context) == TextDirection.rtl
        ? Icons.chevron_left
        : Icons.chevron_right;

    Future<void> editPrice(JobType job, int current) async {
      final c = TextEditingController(text: '$current');
      final v = await showDialog<int>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(t.labourFor(core.jobType(job))),
          content: TextField(
            controller: c,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textDirection: TextDirection.ltr,
            decoration: InputDecoration(labelText: t.priceField),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(core.actionCancel)),
            FilledButton(
              onPressed: () => Navigator.pop(context, int.tryParse(c.text)),
              child: Text(core.actionSave),
            ),
          ],
        ),
      );
      c.dispose();
      if (v != null && v > 0) controller.setLabour(job, v);
    }

    return Scaffold(
      appBar: AppBar(title: Text(t.techNavProfile)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Space.page, Space.lg, Space.page, Space.xxl),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(Space.lg),
              child: Row(
                children: [
                  InitialsAvatar(name: tech.name.tr(context), size: 60, tone: Tone.info),
                  const SizedBox(width: Space.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tech.name.tr(context), style: theme.textTheme.titleLarge),
                        RatingLine(rating: tech.rating, count: tech.ratingCount, dense: true),
                        const SizedBox(height: Space.xs),
                        StatusPill(
                          label: core.verifiedTechnician,
                          tone: Tone.info,
                          icon: Icons.verified,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          MenuCard(
            title: t.skillsAndPrices,
            children: [
              for (final e in profile.labour.entries)
                ListTile(
                  title: Text(core.jobType(e.key)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(context.sdg(e.value), style: theme.textTheme.titleSmall),
                      const SizedBox(width: Space.sm),
                      const Icon(Icons.edit_outlined, size: 18),
                    ],
                  ),
                  onTap: () => editPrice(e.key, e.value),
                ),
            ],
          ),
          MenuCard(
            title: t.howYouWork,
            children: [
              Padding(
                padding: const EdgeInsets.all(Space.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SegmentedButton<WorkMode>(
                      showSelectedIcon: false,
                      segments: [
                        for (final m in WorkMode.values)
                          ButtonSegment(
                            value: m,
                            label: Text(
                              switch (m) {
                                WorkMode.bay => core.modeBay,
                                WorkMode.mobile => core.modeMobile,
                                WorkMode.both => core.modeBoth,
                              },
                              maxLines: 2,
                              textAlign: TextAlign.center,
                            ),
                          ),
                      ],
                      selected: {profile.mode},
                      onSelectionChanged: (s) => controller.setMode(s.first),
                    ),
                    if (tech.bayShopId != null) ...[
                      const SizedBox(height: Space.md),
                      Text(
                        t.yourBay(catalogue.shop(tech.bayShopId!).name.tr(context)),
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                    if (profile.mode != WorkMode.bay) ...[
                      const SizedBox(height: Space.md),
                      Text(t.maxDistance(profile.radiusKm), style: theme.textTheme.titleSmall),
                      Slider(
                        value: profile.radiusKm.toDouble(),
                        min: 2,
                        max: 25,
                        divisions: 23,
                        label: core.km('${profile.radiusKm}'),
                        onChanged: (v) => controller.setRadius(v.round()),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          MenuCard(children: settingsRows(context, ref)),
          MenuCard(
            children: [
              ListTile(
                leading: const Icon(Icons.swap_horiz),
                title: Text(t.roleSwitch),
                trailing: Icon(chevron),
                onTap: () => context.push(Routes.role),
              ),
              ListTile(
                leading: const Icon(Icons.help_outline),
                title: Text(t.moreHelp),
                trailing: Icon(chevron),
                onTap: () => showDemoDisabled(context),
              ),
            ],
          ),
          const SizedBox(height: Space.xl),
          SignOutButton(label: t.signOut, confirm: t.signOutConfirm),
        ],
      ),
    );
  }
}
