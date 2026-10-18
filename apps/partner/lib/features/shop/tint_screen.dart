import 'package:alghali_core/alghali_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../state/shop.dart';
import '../../widgets/partner_widgets.dart';

/// The shop's window-tint offer (`shop_set_tint`, D-149): whether it tints, the darkness
/// levels and colours it does, and a price per package and per window for each car size.
/// Buyers pick a level and a colour, then a shop by price.
class TintSettingsScreen extends ConsumerWidget {
  const TintSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text(context.t.moreTint)),
      body: AsyncBody(
        value: ref.watch(shopTintProvider),
        onRefresh: () => ref.read(shopTintProvider.notifier).refresh(),
        data: (s) => s == null ? const SizedBox.shrink() : _Form(settings: s),
      ),
    );
  }
}

class _Form extends ConsumerStatefulWidget {
  const _Form({required this.settings});

  final ShopTintSettings settings;

  @override
  ConsumerState<_Form> createState() => _FormState();
}

class _FormState extends ConsumerState<_Form> {
  late var _active = widget.settings.isActive;
  late var _darkness = {...widget.settings.darkness};
  late var _colours = {...widget.settings.colours};
  late final _prices = {
    for (final size in TintCarSize.values)
      for (final item in TintItem.values)
        (size, item): TextEditingController(
          text: widget.settings.prices[(size, item)]?.toString() ?? '',
        ),
  };
  var _busy = false;

  @override
  void dispose() {
    for (final c in _prices.values) {
      c.dispose();
    }
    super.dispose();
  }

  Map<(TintCarSize, TintItem), int> get _entered => {
    for (final MapEntry(:key, :value) in _prices.entries)
      if (int.tryParse(value.text) case final p? when p > 0) key: p,
  };

  Future<void> _save() async {
    final t = context.t;
    if (_active && (_darkness.isEmpty || _colours.isEmpty)) {
      showSnack(context, t.tintNeedsChoice);
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(shopTintProvider.notifier)
          .save(active: _active, darkness: _darkness, colours: _colours, prices: _entered);
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
    final bay = widget.settings.bayTechnicians;

    Widget section(String title, [String? note]) => Padding(
      padding: const EdgeInsets.only(top: Space.xl, bottom: Space.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleMedium),
          if (note != null) Text(note, style: theme.textTheme.bodySmall),
        ],
      ),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(Space.page, Space.lg, Space.page, Space.xxl),
      children: [
        Card(
          child: SwitchListTile(
            value: _active,
            onChanged: (v) => setState(() => _active = v),
            title: Text(t.tintOffer),
            subtitle: Text(t.tintOfferBody),
          ),
        ),
        const SizedBox(height: Space.md),
        InfoBanner(
          tone: bay == 0 ? Tone.warning : Tone.success,
          message: bay == 0 ? t.tintBayNone : t.tintBayCount(bay),
        ),
        section(t.tintDarkness, t.tintDarknessNote),
        Wrap(
          spacing: Space.sm,
          runSpacing: Space.sm,
          children: [
            for (final d in tintDarknessLevels)
              FilterChip(
                label: Text(ltr(core.tintPercent(d))),
                selected: _darkness.contains(d),
                onSelected: (on) => setState(
                  () => _darkness = on ? {..._darkness, d} : ({..._darkness}..remove(d)),
                ),
              ),
          ],
        ),
        section(t.tintColours),
        Wrap(
          spacing: Space.sm,
          runSpacing: Space.sm,
          children: [
            for (final c in TintColour.values)
              FilterChip(
                label: Text(core.tintColour(c)),
                selected: _colours.contains(c),
                onSelected: (on) =>
                    setState(() => _colours = on ? {..._colours, c} : ({..._colours}..remove(c))),
              ),
          ],
        ),
        section(t.tintPrices, t.tintPricesNote),
        for (final size in TintCarSize.values)
          Card(
            clipBehavior: Clip.antiAlias,
            child: ExpansionTile(
              initiallyExpanded: size == TintCarSize.saloon,
              title: Text(core.tintSize(size)),
              subtitle: Text(
                t.tintPricesSet(
                  TintItem.values.where((i) => _prices[(size, i)]!.text.isNotEmpty).length,
                ),
              ),
              childrenPadding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.md),
              children: [
                for (final item in TintItem.values)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Space.sm),
                    child: TextField(
                      key: ValueKey('tint-${size.code}-${item.code}'),
                      controller: _prices[(size, item)],
                      keyboardType: TextInputType.number,
                      textDirection: TextDirection.ltr,
                      inputFormatters: [_digits],
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: '${core.tintItem(item)} · ${t.priceField}',
                      ),
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: Space.xl),
        FilledButton(onPressed: _busy ? null : _save, child: Text(core.actionSave)),
      ],
    );
  }
}

/// Digits only, from either keyboard: Arabic-Indic digits become 0–9.
final _digits = TextInputFormatter.withFunction((old, value) {
  const eastern = '٠١٢٣٤٥٦٧٨٩';
  const persian = '۰۱۲۳۴۵۶۷۸۹';
  final buf = StringBuffer();
  for (final ch in value.text.split('')) {
    final e = eastern.indexOf(ch);
    final p = persian.indexOf(ch);
    if (e >= 0) {
      buf.write(e);
    } else if (p >= 0) {
      buf.write(p);
    } else if (RegExp('[0-9]').hasMatch(ch)) {
      buf.write(ch);
    }
  }
  final text = buf.toString();
  if (text.length > 9) return old;
  return TextEditingValue(
    text: text,
    selection: TextSelection.collapsed(offset: text.length),
  );
});
