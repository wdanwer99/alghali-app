import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart' show SystemUiOverlayStyle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../i18n/locale_controller.dart';
import '../l10n/generated/core_localizations.dart';
import '../theme/app_tokens.dart';
import 'brand.dart';
import 'splash.dart';

/// One page of the first-launch tour.
@immutable
class TourSlide {
  const TourSlide({required this.title, required this.body, this.icon, this.chips = const []});

  final String title;
  final String body;

  /// The big picture; null shows the car wheel, which rolls in as the page turns.
  final IconData? icon;

  /// Up to three small icons around the picture; the first is filled in the accent colour.
  final List<IconData> chips;
}

/// First launch: a short tour on the splash's night street, with the language switch
/// at the top (Arabic preselected; tapping English flips the screen at once). Skip or
/// the last page's button saves the language and runs [onDone].
class WelcomeTour extends ConsumerStatefulWidget {
  const WelcomeTour({
    required this.slides,
    required this.onDone,
    this.variant = MarkVariant.buyer,
    super.key,
  });

  final List<TourSlide> slides;
  final VoidCallback onDone;
  final MarkVariant variant;

  @override
  ConsumerState<WelcomeTour> createState() => _WelcomeTourState();
}

class _WelcomeTourState extends ConsumerState<WelcomeTour> with SingleTickerProviderStateMixin {
  final _pages = PageController();
  late final _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );
  var _started = false;
  var _leaving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _intro.value = 1;
    } else {
      unawaited(_intro.forward());
    }
  }

  @override
  void dispose() {
    _pages.dispose();
    _intro.dispose();
    super.dispose();
  }

  int get _index => _pages.hasClients ? (_pages.page ?? 0).round() : 0;
  bool get _last => _index >= widget.slides.length - 1;

  Future<void> _finish() async {
    if (_leaving) return;
    _leaving = true;
    final locale = ref.read(localeControllerProvider).locale;
    await ref.read(localeControllerProvider.notifier).select(locale);
    if (mounted) widget.onDone();
  }

  void _next() {
    if (_last) {
      unawaited(_finish());
    } else if (MediaQuery.disableAnimationsOf(context)) {
      _pages.jumpToPage(_index + 1);
    } else {
      unawaited(
        _pages.animateToPage(
          _index + 1,
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOutCubic,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = CoreLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = StreetColors.of(widget.variant);
    final padding = MediaQuery.paddingOf(context);
    const bar = 64.0;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: theme.colorScheme.surface,
        body: LayoutBuilder(
          builder: (context, box) {
            final hero = (box.maxHeight * 0.54).clamp(260.0, 480.0);
            // The picture sits in the middle of the street, below the top bar.
            final centre = padding.top + bar + (hero - padding.top - bar) / 2;
            final controls = padding.bottom + Space.lg + 8 + Space.xl + Hit.button;
            return Stack(
              children: [
                // The street stays put while the pages slide over it.
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: hero,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
                    child: ColoredBox(
                      color: colors.ground,
                      child: RepaintBoundary(
                        child: CustomPaint(
                          painter: StreetPainter(
                            colors: colors,
                            reveal: _intro,
                            vanish: Alignment(0, centre / hero * 2 - 1),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: PageView.builder(
                    controller: _pages,
                    itemCount: widget.slides.length,
                    itemBuilder: (context, i) => _TourPage(
                      slide: widget.slides[i],
                      index: i,
                      pages: _pages,
                      intro: _intro,
                      variant: widget.variant,
                      hero: hero,
                      centre: centre,
                      bottom: controls,
                    ),
                  ),
                ),
                Positioned(
                  top: padding.top,
                  left: 0,
                  right: 0,
                  height: bar,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Space.lg),
                    child: Row(
                      children: [
                        _LanguageSwitch(colors: colors),
                        const Spacer(),
                        TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                            minimumSize: const Size(Hit.min, Hit.min),
                          ),
                          onPressed: _finish,
                          child: Text(t.tourSkip),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: Space.xxl,
                  right: Space.xxl,
                  bottom: padding.bottom + Space.lg,
                  child: ListenableBuilder(
                    listenable: _pages,
                    builder: (context, _) => Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _Dots(pages: _pages, count: widget.slides.length),
                        const SizedBox(height: Space.xl),
                        SizedBox(
                          width: double.infinity,
                          height: Hit.button,
                          child: FilledButton(
                            onPressed: _next,
                            child: AnimatedSwitcher(
                              duration: Motion.medium,
                              child: Text(_last ? t.tourStart : t.tourNext, key: ValueKey(_last)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// A page: the picture on the street, then the words. Everything moves with the
/// swipe (no timers), so dragging half-way and back plays it backwards too.
class _TourPage extends StatelessWidget {
  const _TourPage({
    required this.slide,
    required this.index,
    required this.pages,
    required this.intro,
    required this.variant,
    required this.hero,
    required this.centre,
    required this.bottom,
  });

  final TourSlide slide;
  final int index;
  final PageController pages;
  final Animation<double> intro;
  final MarkVariant variant;
  final double hero;
  final double centre;
  final double bottom;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final ltr = Directionality.of(context) == TextDirection.ltr ? 1.0 : -1.0;
    final tile = (hero * 0.34).clamp(96.0, 140.0);
    final colors = StreetColors.of(variant);

    return AnimatedBuilder(
      animation: Listenable.merge([pages, intro]),
      builder: (context, _) {
        final page = pages.hasClients && pages.position.haveDimensions ? pages.page ?? 0.0 : 0.0;
        // Positive once this page is on its way out; the sign follows the reading direction.
        final delta = page - index;
        final seen = (1 - delta.abs()).clamp(0.0, 1.0) * intro.value;
        double rise(double from, double to) =>
            Curves.easeOutBack.transform(((seen - from) / (to - from)).clamp(0.0, 1.0));
        // Nearer things move faster than the page: a little depth while swiping.
        double drift(double depth) => -delta * width * depth * ltr;

        final picture = slide.icon == null
            ? _RollingWheel(shift: drift(0.6), size: tile, variant: variant)
            : Transform.translate(
                offset: Offset(drift(0.15), 0),
                child: Transform.scale(
                  scale: 0.6 + 0.4 * rise(0, 0.7),
                  child: Opacity(
                    opacity: (seen * 1.6).clamp(0.0, 1.0),
                    child: _Tile(
                      icon: slide.icon!,
                      size: tile,
                      accent: colors.accent,
                      deep: colors.deep,
                    ),
                  ),
                ),
              );

        const angles = [-150.0, -30.0, 100.0];
        final chips = [
          for (var k = 0; k < math.min(slide.chips.length, angles.length); k++)
            () {
              final s = rise(0.2 + 0.15 * k, 0.75 + 0.08 * k);
              final a = angles[k] * math.pi / 180;
              final reach = tile * (0.55 + 0.4 * s);
              return Transform.translate(
                offset: Offset(
                  math.cos(a) * reach * ltr + drift(0.35 + 0.12 * k),
                  math.sin(a) * reach,
                ),
                child: Transform.scale(
                  scale: s,
                  child: _Chip(icon: slide.chips[k], filled: k == 0, colors: colors),
                ),
              );
            }(),
        ];

        final words =
            (1 - delta.abs() * 1.4).clamp(0.0, 1.0) *
            Curves.easeOut.transform(_after(intro.value, 0.3));
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: hero,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    top: centre - tile,
                    height: tile * 2,
                    child: Stack(alignment: Alignment.center, children: [picture, ...chips]),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(Space.xxl, Space.xxxl, Space.xxl, bottom),
                child: Opacity(
                  opacity: words,
                  child: Transform.translate(
                    offset: Offset(drift(0.25), (1 - words) * 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          slide.title,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: Space.md),
                        Text(
                          slide.body,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  static double _after(double t, double start) => ((t - start) / (1 - start)).clamp(0.0, 1.0);
}

/// The big rounded tile, frosted on the street, with the mark's dot in its corner.
class _Tile extends StatelessWidget {
  const _Tile({required this.icon, required this.size, required this.accent, required this.deep});

  final IconData icon;
  final double size;
  final Color accent;
  final Color deep;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: Stack(
        children: [
          // Solid underneath, so the street doesn't show through.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: deep,
                borderRadius: BorderRadius.circular(size * 0.28),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(size * 0.28),
                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                gradient: LinearGradient(
                  begin: AlignmentDirectional.topStart,
                  end: AlignmentDirectional.bottomEnd,
                  colors: [
                    Colors.white.withValues(alpha: 0.18),
                    Colors.white.withValues(alpha: 0.05),
                  ],
                ),
              ),
              child: Icon(icon, size: size * 0.46, color: Colors.white),
            ),
          ),
          PositionedDirectional(
            top: size * 0.12,
            end: size * 0.12,
            child: Container(
              width: size * 0.09,
              height: size * 0.09,
              decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.filled, required this.colors});

  final IconData icon;
  final bool filled;
  final StreetColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? colors.accent : colors.deep.withValues(alpha: 0.55),
        border: Border.all(color: Colors.white.withValues(alpha: filled ? 0 : 0.2)),
      ),
      child: Icon(
        icon,
        size: 24,
        color: filled && colors.accent == Colors.white ? colors.ground : Colors.white,
      ),
    );
  }
}

/// The brand wheel, rolling without slipping: it turns one radian for every radius it
/// travels, so it rolls in and out with the swipe.
class _RollingWheel extends StatelessWidget {
  const _RollingWheel({required this.shift, required this.size, required this.variant});

  final double shift;
  final double size;
  final MarkVariant variant;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: Offset(shift, 0),
      child: Transform.rotate(
        angle: shift / (size / 2),
        child: AlghaliWheel(size: size, variant: variant),
      ),
    );
  }
}

/// Arabic | English, on the street; choosing previews the language at once.
class _LanguageSwitch extends ConsumerWidget {
  const _LanguageSwitch({required this.colors});

  final StreetColors colors;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = CoreLocalizations.of(context);
    final current = ref.watch(localeControllerProvider).locale.languageCode;
    final controller = ref.read(localeControllerProvider.notifier);

    Widget option(Locale locale, String label) {
      final selected = current == locale.languageCode;
      return Semantics(
        button: true,
        selected: selected,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => controller.preview(locale),
          child: AnimatedContainer(
            duration: Motion.medium,
            curve: Motion.curve,
            constraints: const BoxConstraints(minHeight: 40, minWidth: 64),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: Space.md),
            decoration: BoxDecoration(
              color: selected ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(Radii.pill),
            ),
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: selected ? colors.ground : Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      );
    }

    return Semantics(
      label: t.chooseLanguage,
      container: true,
      child: Container(
        padding: const EdgeInsets.all(Space.xs),
        decoration: BoxDecoration(
          color: colors.deep.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(Radii.pill),
          border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            option(const Locale('ar'), t.languageArabic),
            option(const Locale('en'), t.languageEnglish),
          ],
        ),
      ),
    );
  }
}

/// Page dots; the current one stretches into a pill, following the finger.
class _Dots extends StatelessWidget {
  const _Dots({required this.pages, required this.count});

  final PageController pages;
  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final page = pages.hasClients && pages.position.haveDimensions ? pages.page ?? 0.0 : 0.0;
    return Semantics(
      label: CoreLocalizations.of(context).tourStep(page.round() + 1, count),
      child: ExcludeSemantics(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < count; i++)
              () {
                final near = (1 - (page - i).abs()).clamp(0.0, 1.0);
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: 8 + 18 * near,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Color.lerp(scheme.outlineVariant, scheme.onSurface, near),
                    borderRadius: BorderRadius.circular(Radii.pill),
                  ),
                );
              }(),
          ],
        ),
      ),
    );
  }
}
