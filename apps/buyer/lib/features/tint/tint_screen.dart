import 'dart:async';

import 'package:alghali_core/alghali_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../router.dart';
import '../../state/cart.dart';
import '../../state/tint.dart';
import '../../widgets/buyer_widgets.dart';

/// Window tint (D-149): car size → windows (a package or one by one) → darkness and
/// colour → shop. The tint goes in the cart and the fitting is booked straight after:
/// tint is never bought without one.
class TintScreen extends ConsumerStatefulWidget {
  const TintScreen({super.key});

  @override
  ConsumerState<TintScreen> createState() => _TintScreenState();
}

enum _Step { size, windows, look, shop }

/// What each colour looks like on the glass.
const _swatch = {
  TintColour.black: Color(0xFF1C1C1E),
  TintColour.smoke: Color(0xFF5B6168),
  TintColour.blue: Color(0xFF2E4C6D),
  TintColour.green: Color(0xFF2F5A47),
  TintColour.bronze: Color(0xFF7A5634),
  TintColour.silver: Color(0xFFAEB5BC),
};

class _TintScreenState extends ConsumerState<TintScreen> {
  var _step = _Step.size;
  TintCarSize? _size;
  TintItem? _package;
  var _custom = false;
  var _windows = <TintWindow>{};
  int? _darkness;
  TintColour? _colour;
  String? _shopId;

  TintSelection? get _selection => _custom
      ? (_windows.isEmpty ? null : TintSelection.windows(_windows))
      : switch (_package) {
          final p? => TintSelection.package(p),
          null => null,
        };

  /// The shops' answer for the size and windows chosen so far.
  AsyncValue<TintOffers>? _offers() {
    final size = _size;
    final selection = _selection;
    if (size == null || selection == null) return null;
    return ref.watch(tintOffersProvider((size, selection)));
  }

  List<TintShopOffer> _matching(TintOffers offers) => [
    for (final s in offers.shops)
      if (_darkness != null && _colour != null && s.offers(_darkness!, _colour!)) s,
  ];

  /// A new size or windows: the shades and shops offered may differ.
  void _resetLook() {
    _darkness = null;
    _colour = null;
    _shopId = null;
  }

  bool _valid(TintOffers? offers) => switch (_step) {
    _Step.size => _size != null,
    _Step.windows => _selection != null && offers != null && offers.shops.isNotEmpty,
    _Step.look => offers != null && _matching(offers).isNotEmpty,
    _Step.shop => offers != null && _matching(offers).any((s) => s.shopId == _shopId),
  };

  void _back() {
    if (_step == _Step.size) {
      context.pop();
    } else {
      setState(() => _step = _Step.values[_step.index - 1]);
    }
  }

  Future<void> _finish(TintOffers offers) async {
    final t = context.t;
    final category = ref.read(catalogueProvider).tintCategory;
    final offer = offers.shops.where((s) => s.shopId == _shopId).firstOrNull;
    if (category == null || offer == null) return;
    if (ref.read(cartProvider).lines.any((l) => l.tint != null)) {
      final replace = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          content: Text(t.tintReplace),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.core.actionCancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(t.tintReplaceYes),
            ),
          ],
        ),
      );
      if (!(replace ?? false) || !mounted) return;
    }
    final line = ref
        .read(cartProvider.notifier)
        .addTint(
          shopId: offer.shopId,
          category: category,
          choice: TintChoice(
            carSize: _size!,
            selection: offers.selection,
            darkness: _darkness!,
            colour: _colour!,
          ),
          priceSdg: offer.priceSdg,
        );
    // Book the fitting now, with the cart underneath to come back to.
    context.go(Routes.cart);
    unawaited(context.push(Routes.bookLine(line.id)));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final value = _offers();
    final offers = value?.value;

    return PopScope(
      canPop: _step == _Step.size,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(t.tintTitle),
          leading: IconButton(
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            onPressed: _back,
            icon: const BackButtonIcon(),
          ),
        ),
        body: Column(
          children: [
            Container(
              color: Theme.of(context).colorScheme.surface,
              padding: const EdgeInsets.fromLTRB(Space.sm, Space.md, Space.sm, Space.md),
              child: StepProgress(
                steps: [t.tintStepSize, t.tintStepWindows, t.tintStepLook, t.tintStepShop],
                current: _step.index,
              ),
            ),
            const Divider(),
            Expanded(
              child: AnimatedSwitcher(
                duration: Motion.medium,
                child: KeyedSubtree(
                  key: ValueKey(_step),
                  child: switch (_step) {
                    _Step.size => _sizeStep(context),
                    _Step.windows => _windowsStep(context, value),
                    _Step.look => _loaded(value, (o) => _lookStep(context, o)),
                    _Step.shop => _loaded(value, (o) => _shopStep(context, o)),
                  },
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: BottomActionBar(
          child: FilledButton(
            onPressed: !_valid(offers)
                ? null
                : _step == _Step.shop
                ? () => _finish(offers!)
                : () => setState(() => _step = _Step.values[_step.index + 1]),
            child: Text(_step == _Step.shop ? t.tintBook : context.core.actionNext),
          ),
        ),
      ),
    );
  }

  Widget _loaded(AsyncValue<TintOffers>? value, Widget Function(TintOffers) data) =>
      switch (value) {
        AsyncData(:final value) => data(value),
        AsyncError(:final error) => ListView(
          children: [
            EmptyState(
              icon: Icons.cloud_off_outlined,
              title: context.core.error(error),
              action: OutlinedButton.icon(
                onPressed: () => ref.invalidate(tintOffersProvider),
                icon: const Icon(Icons.refresh),
                label: Text(context.core.actionRetry),
              ),
            ),
          ],
        ),
        _ => const SkeletonList(),
      };

  Widget _title(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.only(bottom: Space.lg),
    child: Text(text, style: Theme.of(context).textTheme.titleLarge),
  );

  Widget _sizeStep(BuildContext context) {
    final core = context.core;
    return ListView(
      padding: Space.pageInsets,
      children: [
        _title(context, context.t.tintSizeTitle),
        for (final s in TintCarSize.values) ...[
          ChoiceCard(
            selected: _size == s,
            onTap: () => setState(() {
              _size = s;
              _resetLook();
            }),
            icon: switch (s) {
              TintCarSize.small => Icons.directions_car_outlined,
              TintCarSize.saloon => Icons.directions_car_filled_outlined,
              TintCarSize.suv => Icons.airport_shuttle_outlined,
              TintCarSize.pickup => Icons.local_shipping_outlined,
              TintCarSize.minibus => Icons.directions_bus_outlined,
            },
            title: core.tintSize(s),
          ),
          const SizedBox(height: Space.sm),
        ],
      ],
    );
  }

  Widget _windowsStep(BuildContext context, AsyncValue<TintOffers>? value) {
    final t = context.t;
    final core = context.core;
    return ListView(
      padding: Space.pageInsets,
      children: [
        _title(context, t.tintWindowsTitle),
        for (final p in TintItem.packages) ...[
          ChoiceCard(
            selected: !_custom && _package == p,
            onTap: () => setState(() {
              _custom = false;
              _package = p;
              _resetLook();
            }),
            icon: Icons.tonality,
            title: core.tintItem(p),
            subtitle: switch (tintWindowsOf(p)) {
              final w when w.isEmpty => null,
              final w => [
                for (final x in TintWindow.values)
                  if (w.contains(x)) core.tintWindow(x),
              ].join('، '),
            },
          ),
          const SizedBox(height: Space.sm),
        ],
        ChoiceCard(
          selected: _custom,
          onTap: () => setState(() {
            _custom = true;
            _resetLook();
          }),
          icon: Icons.checklist,
          title: t.tintPickWindows,
          subtitle: t.tintPickWindowsBody,
        ),
        if (_custom) ...[
          const SizedBox(height: Space.md),
          Wrap(
            spacing: Space.sm,
            runSpacing: Space.sm,
            children: [
              for (final w in TintWindow.values)
                FilterChip(
                  label: Text(core.tintWindow(w)),
                  selected: _windows.contains(w),
                  onSelected: (on) => setState(() {
                    _windows = on ? {..._windows, w} : ({..._windows}..remove(w));
                    _resetLook();
                  }),
                ),
            ],
          ),
        ],
        const SizedBox(height: Space.lg),
        switch (value) {
          AsyncData(value: TintOffers(shops: [])) => InfoBanner(
            tone: Tone.neutral,
            title: t.tintNoShops,
            message: t.tintNoShopsBody,
          ),
          AsyncError(:final error) => InfoBanner(tone: Tone.danger, message: core.error(error)),
          AsyncLoading() => const LinearProgressIndicator(),
          _ => const SizedBox.shrink(),
        },
      ],
    );
  }

  Widget _lookStep(BuildContext context, TintOffers offers) {
    final t = context.t;
    final core = context.core;
    final theme = Theme.of(context);
    final noMatch = _darkness != null && _colour != null && _matching(offers).isEmpty;

    return ListView(
      padding: Space.pageInsets,
      children: [
        _GlassPreview(darkness: _darkness, colour: _colour),
        const SizedBox(height: Space.xl),
        Text(t.tintDarknessTitle, style: theme.textTheme.titleMedium),
        const SizedBox(height: Space.xs),
        Text(t.tintDarknessNote, style: theme.textTheme.bodySmall),
        const SizedBox(height: Space.sm),
        Wrap(
          spacing: Space.sm,
          runSpacing: Space.sm,
          children: [
            for (final d in offers.darkness)
              ChoiceChip(
                label: Text(ltr(core.tintPercent(d))),
                selected: _darkness == d,
                onSelected: (_) => setState(() {
                  _darkness = d;
                  _shopId = null;
                }),
              ),
          ],
        ),
        const SizedBox(height: Space.xl),
        Text(t.tintColourTitle, style: theme.textTheme.titleMedium),
        const SizedBox(height: Space.sm),
        Wrap(
          spacing: Space.sm,
          runSpacing: Space.sm,
          children: [
            for (final c in offers.colours)
              ChoiceChip(
                avatar: SizedBox.square(
                  dimension: 18,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: _swatch[c],
                      shape: BoxShape.circle,
                      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                    ),
                  ),
                ),
                label: Text(core.tintColour(c)),
                selected: _colour == c,
                onSelected: (_) => setState(() {
                  _colour = c;
                  _shopId = null;
                }),
              ),
          ],
        ),
        if (noMatch) ...[
          const SizedBox(height: Space.lg),
          InfoBanner(tone: Tone.warning, message: t.tintNoMatch),
        ],
      ],
    );
  }

  Widget _shopStep(BuildContext context, TintOffers offers) {
    final t = context.t;
    final catalogue = ref.watch(catalogueProvider);
    final shops = _matching(offers);
    final summary = context.core.tintSummary(
      TintChoice(
        carSize: _size!,
        selection: offers.selection,
        darkness: _darkness!,
        colour: _colour!,
      ),
    );

    return ListView(
      padding: Space.pageInsets,
      children: [
        _title(context, t.tintShopTitle),
        Text(summary, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: Space.lg),
        for (final s in shops) ...[
          ChoiceCard(
            selected: _shopId == s.shopId,
            onTap: () => setState(() => _shopId = s.shopId),
            icon: Icons.storefront_outlined,
            title: catalogue.shop(s.shopId).name.tr(context),
            subtitle: [
              shopPlace(context, catalogue, catalogue.shop(s.shopId)),
              if (s.atShop) t.tintFitsAtShop,
            ].where((x) => x.isNotEmpty).join(' · '),
            trailing: Text(
              context.sdg(s.priceSdg),
              style: Theme.of(context).textTheme.titleSmall
                  ?.copyWith(fontFeatures: AppTypography.tabular),
            ),
          ),
          const SizedBox(height: Space.sm),
        ],
        const SizedBox(height: Space.sm),
        InfoBanner(tone: Tone.neutral, message: t.tintPriceNote),
      ],
    );
  }
}

/// A side window with the chosen shade over a bright sky, to see how dark it gets.
class _GlassPreview extends StatelessWidget {
  const _GlassPreview({required this.darkness, required this.colour});

  final int? darkness;
  final TintColour? colour;

  @override
  Widget build(BuildContext context) {
    final shade = _swatch[colour ?? TintColour.black]!;
    final alpha = ((darkness ?? 0) / 100 * 0.9).clamp(0.0, 0.9);
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(48),
          topRight: Radius.circular(12),
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
        child: SizedBox(
          height: 120,
          child: Stack(
            fit: StackFit.expand,
            children: [
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF8EC5EC), Color(0xFFF3E3B5)],
                  ),
                ),
              ),
              const Align(
                alignment: AlignmentDirectional(0.6, 0.2),
                child: Icon(Icons.wb_sunny, size: 44, color: Color(0xFFF7B733)),
              ),
              ColoredBox(color: shade.withValues(alpha: alpha)),
            ],
          ),
        ),
      ),
    );
  }
}
