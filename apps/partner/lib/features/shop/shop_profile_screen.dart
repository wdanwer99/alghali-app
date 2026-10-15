import 'package:alghali_core/alghali_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../state/session.dart';
import '../../state/shop.dart';
import '../../widgets/partner_widgets.dart';

/// The shop's profile as buyers see it (`shop_update_profile`, owners only): contacts,
/// landmark, about, opening hours and what it sells. The name and place on the street are
/// changed by the platform team.
class ShopProfileScreen extends ConsumerWidget {
  const ShopProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    return Scaffold(
      appBar: AppBar(title: Text(t.moreProfile)),
      body: AsyncBody(
        value: ref.watch(myShopProvider),
        onRefresh: () => ref.read(myShopProvider.notifier).refresh(),
        data: (shop) => shop == null ? const SizedBox.shrink() : _Form(shop: shop),
      ),
    );
  }
}

class _Form extends ConsumerStatefulWidget {
  const _Form({required this.shop});

  final Shop shop;

  @override
  ConsumerState<_Form> createState() => _FormState();
}

class _FormState extends ConsumerState<_Form> {
  final _form = GlobalKey<FormState>();
  late final _phone = TextEditingController(text: localPhone(widget.shop.phone));
  late final _whatsapp = TextEditingController(text: localPhone(widget.shop.whatsapp));
  late final _landmark = TextEditingController(text: widget.shop.landmark.ar);
  late final _about = TextEditingController(text: widget.shop.about.ar);
  late var _hours = <int, List<(int, int)>>{...widget.shop.openingHours};
  late final _categories = {...widget.shop.specialityIds};
  late final _makes = {...widget.shop.makeIds};
  var _busy = false;

  @override
  void dispose() {
    for (final c in [_phone, _whatsapp, _landmark, _about]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final t = context.t;
    setState(() => _busy = true);
    try {
      await ref.read(myShopProvider.notifier).updateProfile({
        'phone': _phone.text.replaceAll(' ', ''),
        'whatsapp': _whatsapp.text.trim().isEmpty ? null : _whatsapp.text.replaceAll(' ', ''),
        'landmark_ar': _landmark.text.trim(),
        'about_ar': _about.text.trim(),
        'opening_hours': openingHoursToJson({
          for (final MapEntry(:key, :value) in _hours.entries)
            if (value.isNotEmpty) key: value,
        }),
        'category_ids': _categories.toList(),
        'make_ids': _makes.toList(),
      });
      if (mounted) showSnack(context, t.saved);
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
    final shop = widget.shop;

    Widget section(String title) => Padding(
      padding: const EdgeInsets.only(top: Space.xl, bottom: Space.sm),
      child: Text(title, style: theme.textTheme.titleMedium),
    );

    return Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(Space.page, Space.lg, Space.page, Space.xxl),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.storefront_outlined),
              title: Text(shop.name.tr(context)),
              subtitle: Text(
                [
                  catalogue.zone(shop.zoneId).name.tr(context),
                  if (shop.plotNo.isNotEmpty) core.plot(shop.plotNo),
                ].where((s) => s.isNotEmpty).join(' · '),
              ),
            ),
          ),
          const SizedBox(height: Space.sm),
          Text(t.profileNameNote, style: theme.textTheme.bodySmall),
          section(t.applySectionContact),
          TextFormField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            textDirection: TextDirection.ltr,
            decoration: InputDecoration(labelText: t.fieldPhone),
            validator: (v) => isSudanPhone(v ?? '') ? null : core.fieldPhoneInvalid,
          ),
          const SizedBox(height: Space.md),
          TextFormField(
            controller: _whatsapp,
            keyboardType: TextInputType.phone,
            textDirection: TextDirection.ltr,
            decoration: InputDecoration(labelText: t.fieldWhatsapp),
            validator: (v) =>
                (v ?? '').trim().isEmpty || isSudanPhone(v!) ? null : core.fieldPhoneInvalid,
          ),
          const SizedBox(height: Space.md),
          TextFormField(
            controller: _landmark,
            decoration: InputDecoration(labelText: t.shopLandmark, hintText: t.shopLandmarkHint),
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
              child: WeeklyHoursEditor(hours: _hours, onChanged: (h) => setState(() => _hours = h)),
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
          const SizedBox(height: Space.xl),
          FilledButton(onPressed: _busy ? null : _save, child: Text(core.actionSave)),
        ],
      ),
    );
  }
}
