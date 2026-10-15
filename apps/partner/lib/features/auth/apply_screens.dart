import 'package:alghali_core/alghali_core.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../router.dart';
import '../../state/session.dart';
import '../../widgets/partner_widgets.dart';
import '../shop/shop_more_screen.dart';

/// A new partner chooses how they work with the street; an admin reviews the application.
class ApplyScreen extends ConsumerWidget {
  const ApplyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final theme = Theme.of(context);
    final session = ref.watch(partnerSessionProvider);

    Widget choice(IconData icon, String title, String body, VoidCallback onTap) => Padding(
      padding: const EdgeInsets.only(bottom: Space.md),
      child: TapCard(
        onTap: onTap,
        child: Row(
          children: [
            IconTile(icon: icon, size: 56, tone: Tone.brand),
            const SizedBox(width: Space.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleMedium),
                  Text(body, style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: session.isPartner, title: Text(t.applyTitle)),
      body: ListView(
        padding: const EdgeInsets.all(Space.xxl),
        children: [
          Text(t.applyHello(session.name ?? ''), style: theme.textTheme.headlineSmall),
          const SizedBox(height: Space.xs),
          Text(
            t.applyBody,
            style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: Space.xxl),
          choice(
            Icons.storefront_outlined,
            t.applyShopTitle,
            t.applyShopBody,
            () => context.push(Routes.applyShop),
          ),
          if (session.technician == null)
            choice(
              Icons.handyman_outlined,
              t.applyTechTitle,
              t.applyTechBody,
              () => context.push(Routes.applyTech),
            ),
          const SizedBox(height: Space.lg),
          InfoBanner(tone: Tone.neutral, icon: Icons.groups_outlined, message: t.applyStaffNote),
          if (!session.isPartner) ...[
            const SizedBox(height: Space.xl),
            SignOutButton(label: t.signOut, confirm: t.signOutConfirm),
          ],
        ],
      ),
    );
  }
}

/// `apply_as_shop`: the shop's name, place on the street, contacts, hours and what it
/// sells. It can prepare its stock while an admin reviews it (D-125).
class ShopApplyScreen extends ConsumerStatefulWidget {
  const ShopApplyScreen({super.key});

  @override
  ConsumerState<ShopApplyScreen> createState() => _ShopApplyScreenState();
}

class _ShopApplyScreenState extends ConsumerState<ShopApplyScreen> {
  final _form = GlobalKey<FormState>();
  final _nameAr = TextEditingController();
  final _nameEn = TextEditingController();
  final _plot = TextEditingController();
  final _landmark = TextEditingController();
  late final _phone = TextEditingController(
    text: localPhone(ref.read(partnerSessionProvider).phone),
  );
  final _whatsapp = TextEditingController();
  final _about = TextEditingController();
  String? _zoneId;
  var _side = StreetSide.a;
  var _hours = <int, List<(int, int)>>{
    for (final d in [6, 0, 1, 2, 3, 4]) d: [(480, 1200)],
  };
  final _categories = <String>{};
  final _makes = <String>{};
  var _busy = false;

  @override
  void dispose() {
    for (final c in [_nameAr, _nameEn, _plot, _landmark, _phone, _whatsapp, _about]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final shopId = await ref
          .read(shopRepositoryProvider)
          .apply(
            ShopApplication(
              nameAr: _nameAr.text.trim(),
              nameEn: _nameEn.text.trim(),
              zoneId: _zoneId!,
              phone: _phone.text.replaceAll(' ', ''),
              plotNo: _plot.text.trim().isEmpty ? null : _plot.text.trim(),
              side: _side,
              landmarkAr: _landmark.text.trim().isEmpty ? null : _landmark.text.trim(),
              whatsapp: _whatsapp.text.trim().isEmpty ? null : _whatsapp.text.replaceAll(' ', ''),
              aboutAr: _about.text.trim().isEmpty ? null : _about.text.trim(),
              openingHours: {
                for (final MapEntry(:key, :value) in _hours.entries)
                  if (value.isNotEmpty) key: value,
              },
              categoryIds: _categories.toList(),
              makeIds: _makes.toList(),
            ),
          );
      final session = ref.read(partnerSessionProvider.notifier);
      await session.refreshAccount();
      await session.chooseRole(PartnerRole.shop, shopId: shopId);
      if (!mounted) return;
      showSnack(context, context.t.applySent);
      context.go(Routes.shopHome);
    } on BackendException catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final core = context.core;
    final theme = Theme.of(context);
    final catalogue = ref.watch(catalogueProvider);
    _zoneId ??= catalogue.zones.firstOrNull?.id;

    Widget section(String title) => Padding(
      padding: const EdgeInsets.only(top: Space.xl, bottom: Space.sm),
      child: Text(title, style: theme.textTheme.titleMedium),
    );

    return Scaffold(
      appBar: AppBar(title: Text(t.applyShopTitle)),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Space.page, Space.lg, Space.page, Space.xxl),
          children: [
            InfoBanner(tone: Tone.info, icon: Icons.info_outline, message: t.applyShopNote),
            section(t.applySectionShop),
            TextFormField(
              controller: _nameAr,
              decoration: InputDecoration(labelText: t.shopNameAr),
              validator: (v) => (v ?? '').trim().length < 2 ? core.fieldRequired : null,
            ),
            const SizedBox(height: Space.md),
            TextFormField(
              controller: _nameEn,
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(labelText: t.shopNameEn),
            ),
            section(t.applySectionPlace),
            DropdownButtonFormField<String>(
              initialValue: _zoneId,
              decoration: InputDecoration(labelText: t.shopZone),
              items: [
                for (final z in catalogue.zones)
                  DropdownMenuItem(value: z.id, child: Text(z.name.tr(context))),
              ],
              onChanged: (v) => setState(() => _zoneId = v),
              validator: (v) => v == null ? core.fieldRequired : null,
            ),
            const SizedBox(height: Space.md),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _plot,
                    decoration: InputDecoration(labelText: t.shopPlot),
                  ),
                ),
                const SizedBox(width: Space.md),
                SegmentedButton<StreetSide>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(value: StreetSide.a, label: Text(t.shopSideA)),
                    ButtonSegment(value: StreetSide.b, label: Text(t.shopSideB)),
                  ],
                  selected: {_side},
                  onSelectionChanged: (s) => setState(() => _side = s.first),
                ),
              ],
            ),
            const SizedBox(height: Space.md),
            TextFormField(
              controller: _landmark,
              decoration: InputDecoration(labelText: t.shopLandmark, hintText: t.shopLandmarkHint),
            ),
            section(t.applySectionContact),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(labelText: t.fieldPhone, hintText: '09xxxxxxxx'),
              validator: (v) => isSudanPhone(v ?? '') ? null : core.fieldPhoneInvalid,
            ),
            const SizedBox(height: Space.md),
            TextFormField(
              controller: _whatsapp,
              keyboardType: TextInputType.phone,
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(labelText: t.fieldWhatsapp, hintText: '09xxxxxxxx'),
              validator: (v) =>
                  (v ?? '').trim().isEmpty || isSudanPhone(v!) ? null : core.fieldPhoneInvalid,
            ),
            const SizedBox(height: Space.md),
            TextFormField(
              controller: _about,
              maxLines: 3,
              maxLength: 500,
              decoration: InputDecoration(labelText: t.shopAbout),
            ),
            section(t.shopHours),
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.sm),
                child: WeeklyHoursEditor(
                  hours: _hours,
                  onChanged: (h) => setState(() => _hours = h),
                ),
              ),
            ),
            section(t.shopSells),
            Wrap(
              spacing: Space.sm,
              runSpacing: Space.sm,
              children: [
                for (final c in catalogue.categories)
                  FilterChip(
                    avatar: Icon(categoryIcon(c.icon), size: 18),
                    label: Text(c.name.tr(context)),
                    selected: _categories.contains(c.id),
                    onSelected: (v) =>
                        setState(() => v ? _categories.add(c.id) : _categories.remove(c.id)),
                  ),
              ],
            ),
            section(t.shopMakes),
            Text(t.shopMakesBody, style: theme.textTheme.bodySmall),
            const SizedBox(height: Space.sm),
            Wrap(
              spacing: Space.sm,
              runSpacing: Space.sm,
              children: [
                for (final m in catalogue.makes)
                  FilterChip(
                    label: Text(m.name.tr(context)),
                    selected: _makes.contains(m.id),
                    onSelected: (v) => setState(() => v ? _makes.add(m.id) : _makes.remove(m.id)),
                  ),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomActionBar(
        child: FilledButton(onPressed: _busy ? null : _submit, child: Text(t.applySubmit)),
      ),
    );
  }
}

/// `apply_as_technician`: how they work (at a bay on the street, at the buyer's place,
/// or both), their prices per kind of job, makes and phone. An admin approves it.
class TechApplyScreen extends ConsumerStatefulWidget {
  const TechApplyScreen({super.key});

  @override
  ConsumerState<TechApplyScreen> createState() => _TechApplyScreenState();
}

class _TechApplyScreenState extends ConsumerState<TechApplyScreen> {
  final _form = GlobalKey<FormState>();
  late final _phone = TextEditingController(
    text: localPhone(ref.read(partnerSessionProvider).phone),
  );
  final _bio = TextEditingController();
  var _mode = WorkMode.both;
  String? _bayShopId;
  ({double lat, double lng})? _home;
  var _radius = 10;
  var _years = 1;
  final _prices = <JobType, TextEditingController>{};
  final _makes = <String>{};
  var _busy = false;
  var _locating = false;

  @override
  void dispose() {
    _phone.dispose();
    _bio.dispose();
    for (final c in _prices.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _locate() async {
    setState(() => _locating = true);
    try {
      final here = await Gps.here();
      if (mounted) setState(() => _home = here);
    } on BackendException catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _submit() async {
    final t = context.t;
    if (!_form.currentState!.validate()) return;
    final ids = ref.read(catalogueProvider).jobTypeIds;
    final labour = {
      for (final MapEntry(:key, :value) in _prices.entries)
        if (int.tryParse(value.text) case final sdg? when sdg > 0 && ids[key] != null)
          ids[key]!: sdg,
    };
    if (labour.isEmpty) return showSnack(context, t.techApplyNeedJob);
    if (_mode != WorkMode.mobile && _bayShopId == null) {
      return showSnack(context, t.techApplyNeedBay);
    }
    if (_mode != WorkMode.bay && _home == null) return showSnack(context, t.techApplyNeedHome);
    setState(() => _busy = true);
    try {
      await ref
          .read(technicianRepositoryProvider)
          .apply(
            mode: _mode,
            labourByJobTypeId: labour,
            phone: _phone.text.replaceAll(' ', ''),
            makeIds: _makes,
            bayShopId: _mode == WorkMode.mobile ? null : _bayShopId,
            homeLat: _mode == WorkMode.bay ? null : _home?.lat,
            homeLng: _mode == WorkMode.bay ? null : _home?.lng,
            radiusKm: _radius,
            yearsExperience: _years,
            bio: _bio.text.trim().isEmpty ? null : _bio.text.trim(),
          );
      final session = ref.read(partnerSessionProvider.notifier);
      await session.refreshAccount();
      await session.chooseRole(PartnerRole.technician);
      if (!mounted) return;
      showSnack(context, t.applySent);
      context.go(Routes.techJobs);
    } on BackendException catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final core = context.core;
    final theme = Theme.of(context);
    final catalogue = ref.watch(catalogueProvider);
    final jobs = [
      for (final j in JobType.values)
        if (catalogue.jobTypeIds.containsKey(j)) j,
    ];

    Widget section(String title) => Padding(
      padding: const EdgeInsets.only(top: Space.xl, bottom: Space.sm),
      child: Text(title, style: theme.textTheme.titleMedium),
    );

    return Scaffold(
      appBar: AppBar(title: Text(t.applyTechTitle)),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Space.page, Space.lg, Space.page, Space.xxl),
          children: [
            InfoBanner(tone: Tone.info, icon: Icons.info_outline, message: t.applyTechNote),
            section(t.howYouWork),
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
              selected: {_mode},
              onSelectionChanged: (s) => setState(() => _mode = s.first),
            ),
            if (_mode != WorkMode.mobile) ...[
              const SizedBox(height: Space.lg),
              DropdownButtonFormField<String>(
                initialValue: _bayShopId,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: t.techApplyBay,
                  helperText: t.techApplyBayHelp,
                ),
                items: [
                  for (final s in catalogue.shops)
                    DropdownMenuItem(
                      value: s.id,
                      child: Text(s.name.tr(context), overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (v) => setState(() => _bayShopId = v),
              ),
            ],
            if (_mode != WorkMode.bay) ...[
              const SizedBox(height: Space.lg),
              OutlinedButton.icon(
                onPressed: _locating ? null : _locate,
                icon: Icon(_home == null ? Icons.my_location : Icons.check_circle_outline),
                label: Text(_home == null ? t.techApplyHome : t.techApplyHomeSet),
              ),
              const SizedBox(height: Space.xs),
              Text(t.techApplyHomeBody, style: theme.textTheme.bodySmall),
              const SizedBox(height: Space.md),
              Text(t.maxDistance(_radius), style: theme.textTheme.titleSmall),
              Slider(
                value: _radius.toDouble(),
                min: 2,
                max: 25,
                divisions: 23,
                label: core.km('$_radius'),
                onChanged: (v) => setState(() => _radius = v.round()),
              ),
            ],
            section(t.skillsAndPrices),
            Text(t.techApplyJobsBody, style: theme.textTheme.bodySmall),
            const SizedBox(height: Space.sm),
            for (final j in jobs)
              Padding(
                padding: const EdgeInsets.only(bottom: Space.sm),
                child: Row(
                  children: [
                    Expanded(child: Text(core.jobType(j), style: theme.textTheme.bodyLarge)),
                    SizedBox(
                      width: 140,
                      child: TextFormField(
                        controller: _prices.putIfAbsent(j, TextEditingController.new),
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        textDirection: TextDirection.ltr,
                        decoration: InputDecoration(labelText: t.priceField, isDense: true),
                      ),
                    ),
                  ],
                ),
              ),
            section(t.techApplyMakes),
            Text(t.techApplyMakesBody, style: theme.textTheme.bodySmall),
            const SizedBox(height: Space.sm),
            Wrap(
              spacing: Space.sm,
              runSpacing: Space.sm,
              children: [
                for (final m in catalogue.makes)
                  FilterChip(
                    label: Text(m.name.tr(context)),
                    selected: _makes.contains(m.id),
                    onSelected: (v) => setState(() => v ? _makes.add(m.id) : _makes.remove(m.id)),
                  ),
              ],
            ),
            section(t.applySectionContact),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(labelText: t.fieldPhone, hintText: '09xxxxxxxx'),
              validator: (v) => isSudanPhone(v ?? '') ? null : core.fieldPhoneInvalid,
            ),
            const SizedBox(height: Space.md),
            Row(
              children: [
                Expanded(child: Text(t.techApplyYears, style: theme.textTheme.titleSmall)),
                QuantityStepper(
                  value: _years,
                  min: 0,
                  max: 50,
                  onChanged: (v) => setState(() => _years = v),
                ),
              ],
            ),
            const SizedBox(height: Space.md),
            TextFormField(
              controller: _bio,
              maxLines: 3,
              maxLength: 500,
              decoration: InputDecoration(labelText: t.techApplyBio),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomActionBar(
        child: FilledButton(onPressed: _busy ? null : _submit, child: Text(t.applySubmit)),
      ),
    );
  }
}
