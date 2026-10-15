import 'package:alghali_core/alghali_core.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../router.dart';
import '../../state/session.dart';
import '../../state/tech.dart';
import '../../widgets/partner_widgets.dart';
import '../shop/shop_more_screen.dart';

/// Skills with the technician's own labour prices (D-010), work mode, home point and
/// travel radius, and app settings. Changes are saved at once (a connection is needed).
class TechProfileScreen extends ConsumerStatefulWidget {
  const TechProfileScreen({super.key});

  @override
  ConsumerState<TechProfileScreen> createState() => _TechProfileScreenState();
}

class _TechProfileScreenState extends ConsumerState<TechProfileScreen> {
  var _busy = false;
  int? _radius;

  MyTechnicianController get _me => ref.read(myTechnicianProvider.notifier);

  Future<void> _run(Future<void> Function() change, {String? done}) async {
    setState(() => _busy = true);
    try {
      await change();
      if (mounted && done != null) showSnack(context, done);
    } on BackendException catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editPrice(String jobTypeId, String name, int? current) async {
    final t = context.t;
    final v = await askText(
      context,
      title: t.labourFor(name),
      label: t.priceField,
      initial: current?.toString(),
      submit: context.core.actionSave,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
    );
    final sdg = int.tryParse(v ?? '');
    if (sdg == null || sdg <= 0 || !mounted) return;
    await _run(() => _me.setLabour(jobTypeId, sdg), done: t.saved);
  }

  Future<void> _addJob(MyTechnician me) async {
    final core = context.core;
    final ids = ref.read(catalogueProvider).jobTypeIds;
    final have = {for (final j in me.jobs) j.jobTypeId};
    final choice = await pickChoice<JobType>(
      context,
      title: context.t.addJobType,
      options: [
        for (final MapEntry(:key, :value) in ids.entries)
          if (!have.contains(value)) (key, core.jobType(key)),
      ],
    );
    if (choice == null || !mounted) return;
    await _editPrice(ids[choice]!, core.jobType(choice), null);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Scaffold(
      appBar: AppBar(title: Text(t.techNavProfile)),
      body: AsyncBody(
        value: ref.watch(myTechnicianProvider),
        onRefresh: () => _me.refresh(),
        data: (me) => _body(context, me),
      ),
    );
  }

  Widget _body(BuildContext context, MyTechnician? me) {
    final t = context.t;
    final core = context.core;
    final theme = Theme.of(context);
    final session = ref.watch(partnerSessionProvider);
    final chevron = Directionality.of(context) == TextDirection.rtl
        ? Icons.chevron_left
        : Icons.chevron_right;
    final radius = _radius ?? me?.radiusKm ?? 10;

    return ListView(
      padding: const EdgeInsets.fromLTRB(Space.page, Space.lg, Space.page, Space.xxl),
      children: [
        if (_busy) ...[const LinearProgressIndicator(), const SizedBox(height: Space.sm)],
        Card(
          child: Padding(
            padding: const EdgeInsets.all(Space.lg),
            child: Row(
              children: [
                InitialsAvatar(name: session.name ?? '', size: 60, tone: Tone.info),
                const SizedBox(width: Space.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(session.name ?? '', style: theme.textTheme.titleLarge),
                      if (me != null && me.ratingCount > 0)
                        RatingLine(rating: me.rating, count: me.ratingCount, dense: true),
                      const SizedBox(height: Space.xs),
                      Wrap(
                        spacing: Space.xs,
                        runSpacing: Space.xs,
                        children: [
                          if (session.technician case final tech?
                              when tech.status != PartnerStatus.approved)
                            PartnerStatusPill(status: tech.status),
                          if (me?.verified ?? false)
                            StatusPill(
                              label: core.verifiedTechnician,
                              tone: Tone.info,
                              icon: Icons.verified,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (me != null) ...[
          MenuCard(
            title: t.skillsAndPrices,
            children: [
              for (final j in me.jobs)
                ListTile(
                  title: Text(j.jobType == null ? j.name.tr(context) : core.jobType(j.jobType!)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(context.sdg(j.labourSdg), style: theme.textTheme.titleSmall),
                      const SizedBox(width: Space.sm),
                      const Icon(Icons.edit_outlined, size: 18),
                    ],
                  ),
                  onTap: _busy
                      ? null
                      : () => _editPrice(
                          j.jobTypeId,
                          j.jobType == null ? j.name.tr(context) : core.jobType(j.jobType!),
                          j.labourSdg,
                        ),
                ),
              ListTile(
                leading: const Icon(Icons.add),
                title: Text(t.addJobType),
                onTap: _busy ? null : () => _addJob(me),
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
                      selected: {me.mode},
                      onSelectionChanged: _busy
                          ? null
                          : (s) => _run(() => _me.setMode(s.first), done: t.saved),
                    ),
                    if (me.bay != null) ...[
                      const SizedBox(height: Space.md),
                      Text(t.yourBay(me.bay!.name.tr(context)), style: theme.textTheme.bodyMedium),
                    ],
                    if (me.mode != WorkMode.bay) ...[
                      const SizedBox(height: Space.md),
                      OutlinedButton.icon(
                        onPressed: _busy
                            ? null
                            : () => _run(_me.setHomeHere, done: t.techApplyHomeSet),
                        icon: const Icon(Icons.my_location),
                        label: Text(me.homeLat == null ? t.techApplyHome : t.homeUpdate),
                      ),
                      const SizedBox(height: Space.md),
                      Text(t.maxDistance(radius), style: theme.textTheme.titleSmall),
                      Slider(
                        value: radius.toDouble(),
                        min: 2,
                        max: 25,
                        divisions: 23,
                        label: core.km('$radius'),
                        onChanged: _busy ? null : (v) => setState(() => _radius = v.round()),
                        onChangeEnd: (v) => _run(() async {
                          await _me.setRadius(v.round());
                          if (mounted) setState(() => _radius = null);
                        }),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
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
              onTap: () => showHelp(context, ref),
            ),
          ],
        ),
        const SizedBox(height: Space.xl),
        SignOutButton(label: t.signOut, confirm: t.signOutConfirm),
      ],
    );
  }
}

/// One choice from a list in a bottom sheet; null when dismissed.
Future<T?> pickChoice<T>(
  BuildContext context, {
  required String title,
  required List<(T, String)> options,
}) => showModalBottomSheet<T>(
  context: context,
  builder: (context) => SafeArea(
    child: ListView(
      shrinkWrap: true,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.page, 0, Space.page, Space.sm),
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        for (final (v, label) in options)
          ListTile(title: Text(label), onTap: () => Navigator.pop(context, v)),
      ],
    ),
  ),
);
