import 'dart:math' as math;

import 'package:alghali_core/alghali_core.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../app.dart';

/// What each colour looks like on the glass.
const tintSwatch = {
  TintColour.black: Color(0xFF1C1C1E),
  TintColour.smoke: Color(0xFF5B6168),
  TintColour.blue: Color(0xFF2E4C6D),
  TintColour.green: Color(0xFF2F5A47),
  TintColour.bronze: Color(0xFF7A5634),
  TintColour.silver: Color(0xFFAEB5BC),
};

enum _View { outside, inside }

/// A car door with the chosen shade on its window (D-149). The buyer drags the handle to
/// compare clear and tinted glass, and switches between how people outside see in and how
/// the driver sees out. A new shade fades in with one light sweep across the glass; with
/// animations off on the phone it just changes.
class TintGlassPreview extends StatefulWidget {
  const TintGlassPreview({super.key, required this.darkness, required this.colour});

  /// Null until the buyer picks one: the glass shows clear.
  final int? darkness;
  final TintColour? colour;

  @override
  State<TintGlassPreview> createState() => _TintGlassPreviewState();
}

class _TintGlassPreviewState extends State<TintGlassPreview> with SingleTickerProviderStateMixin {
  var _view = _View.outside;

  /// Where the handle is, from the start side: clear glass before it, tinted after.
  var _split = 0.4;
  late final _glare = AnimationController(vsync: this, duration: const Duration(milliseconds: 750));

  bool get _picked => widget.darkness != null;

  @override
  void didUpdateWidget(TintGlassPreview old) {
    super.didUpdateWidget(old);
    final changed = old.darkness != widget.darkness || old.colour != widget.colour;
    if (changed && _picked && !MediaQuery.of(context).disableAnimations) {
      _glare.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _glare.dispose();
    super.dispose();
  }

  void _moveTo(double x, double width, bool rtl) {
    final fromStart = rtl ? width - x : x;
    setState(() => _split = (fromStart / width).clamp(0.0, 1.0));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final core = context.core;
    final theme = Theme.of(context);
    final still = MediaQuery.of(context).disableAnimations;
    final fade = still ? Duration.zero : const Duration(milliseconds: 320);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final darkness = widget.darkness ?? 0;
    final colour = widget.colour ?? TintColour.black;
    final shade = _picked
        ? '${ltr(core.tintPercent(darkness))} · ${core.tintColour(colour)}'
        : t.tintPickToSee;

    final glass = LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth;
        const h = 150.0;
        final handleX = rtl ? w * (1 - _split) : w * _split;
        return Semantics(
          slider: _picked,
          label: '${t.tintPreviewLabel(shade)}. ${_picked ? t.tintCompareHint : ''}',
          value: _picked ? '${(_split * 100).round()}%' : null,
          increasedValue: _picked ? '${((_split + 0.1).clamp(0, 1) * 100).round()}%' : null,
          decreasedValue: _picked ? '${((_split - 0.1).clamp(0, 1) * 100).round()}%' : null,
          onIncrease: _picked ? () => setState(() => _split = (_split + 0.1).clamp(0, 1)) : null,
          onDecrease: _picked ? () => setState(() => _split = (_split - 0.1).clamp(0, 1)) : null,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragStart: _picked ? (_) => HapticFeedback.selectionClick() : null,
            onHorizontalDragUpdate: _picked ? (d) => _moveTo(d.localPosition.dx, w, rtl) : null,
            onTapUp: _picked ? (d) => _moveTo(d.localPosition.dx, w, rtl) : null,
            child: ExcludeSemantics(
              child: SizedBox(
                height: h,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: ClipPath(
                        clipper: const _WindowShape(),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            AnimatedSwitcher(
                              duration: fade,
                              child: CustomPaint(
                                key: ValueKey(_view),
                                size: Size.infinite,
                                painter: _view == _View.outside
                                    ? const _CabinPainter()
                                    : const _StreetPainter(),
                              ),
                            ),
                            ClipRect(
                              clipper: _TintedPart(_picked ? _split : 0, rtl),
                              child: TweenAnimationBuilder<Color?>(
                                tween: ColorTween(end: tintSwatch[colour]),
                                duration: fade,
                                curve: Curves.easeOut,
                                builder: (context, c, _) => TweenAnimationBuilder<double>(
                                  tween: Tween(end: darkness / 100),
                                  duration: fade,
                                  curve: Curves.easeOut,
                                  builder: (context, d, _) => CustomPaint(
                                    painter: _TintPainter(
                                      colour: c ?? tintSwatch[colour]!,
                                      darkness: d,
                                      mirror: colour == TintColour.silver,
                                      outside: _view == _View.outside,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            AnimatedBuilder(
                              animation: _glare,
                              builder: (context, _) => _glare.isAnimating
                                  ? CustomPaint(painter: _GlarePainter(_glare.value))
                                  : const SizedBox.shrink(),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // The shade, on the glass.
                    PositionedDirectional(
                      top: Space.sm,
                      end: Space.sm,
                      child: AnimatedSwitcher(
                        duration: fade,
                        transitionBuilder: (child, a) => FadeTransition(
                          opacity: a,
                          child: ScaleTransition(
                            scale: Tween(begin: 0.9, end: 1.0).animate(a),
                            child: child,
                          ),
                        ),
                        child: _Tag(key: ValueKey(shade), text: shade, strong: true),
                      ),
                    ),
                    if (_picked) ...[
                      PositionedDirectional(
                        bottom: Space.sm,
                        start: Space.sm,
                        child: AnimatedOpacity(
                          opacity: _split > 0.18 ? 1 : 0,
                          duration: fade,
                          child: _Tag(text: t.tintBefore),
                        ),
                      ),
                      PositionedDirectional(
                        bottom: Space.sm,
                        end: Space.sm,
                        child: AnimatedOpacity(
                          opacity: _split < 0.82 ? 1 : 0,
                          duration: fade,
                          child: _Tag(text: t.tintAfter),
                        ),
                      ),
                      // The divider and its handle.
                      Positioned(
                        left: handleX - 1,
                        top: 0,
                        bottom: 0,
                        child: Container(width: 2, color: Colors.white.withValues(alpha: 0.9)),
                      ),
                      Positioned(
                        left: handleX - Hit.min / 2,
                        top: h / 2 - Hit.min / 2,
                        child: Container(
                          width: Hit.min,
                          height: Hit.min,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.25),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.compare_arrows,
                            size: 22,
                            color: Color(0xFF1C1C1E),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The door around the window: silver paint, a handle below.
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: Radii.lgAll,
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFE4E7EA), Color(0xFFC3C8CE)],
            ),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Space.md, Space.md, Space.md, Space.sm),
            child: Column(
              children: [
                glass,
                const SizedBox(height: Space.sm),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: Container(
                    width: 64,
                    height: 8,
                    margin: const EdgeInsetsDirectional.only(end: Space.lg),
                    decoration: const BoxDecoration(
                      color: Color(0xFF9AA1A9),
                      borderRadius: BorderRadius.all(Radius.circular(Radii.pill)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Space.md),
        SegmentedButton<_View>(
          segments: [
            ButtonSegment(
              value: _View.outside,
              icon: const Icon(Icons.visibility_outlined),
              label: Text(t.tintViewOutside),
            ),
            ButtonSegment(
              value: _View.inside,
              icon: const Icon(Icons.airline_seat_recline_normal_outlined),
              label: Text(t.tintViewInside),
            ),
          ],
          selected: {_view},
          showSelectedIcon: false,
          onSelectionChanged: (s) {
            HapticFeedback.selectionClick();
            setState(() => _view = s.first);
          },
        ),
        if (_picked) ...[
          const SizedBox(height: Space.md),
          Row(
            children: [
              Expanded(
                child: _Meter(
                  label: t.tintLightIn,
                  value: (100 - darkness) / 100,
                  text: ltr(core.tintPercent(100 - darkness)),
                  duration: fade,
                ),
              ),
              const SizedBox(width: Space.lg),
              Expanded(
                child: _Meter(
                  label: t.tintPrivacy,
                  value: darkness / 100,
                  text: darkness < 35
                      ? t.tintPrivacyLow
                      : darkness < 70
                      ? t.tintPrivacyMedium
                      : t.tintPrivacyHigh,
                  duration: fade,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// A small label on the glass, readable on any shade.
class _Tag extends StatelessWidget {
  const _Tag({super.key, required this.text, this.strong = false});

  final String text;
  final bool strong;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: Space.sm, vertical: 2),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: strong ? 0.6 : 0.45),
      borderRadius: const BorderRadius.all(Radius.circular(Radii.pill)),
    ),
    child: Text(
      text,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Colors.white),
    ),
  );
}

class _Meter extends StatelessWidget {
  const _Meter({
    required this.label,
    required this.value,
    required this.text,
    required this.duration,
  });

  final String label;
  final double value;
  final String text;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: theme.textTheme.labelMedium)),
            Text(
              text,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                fontFeatures: AppTypography.tabular,
              ),
            ),
          ],
        ),
        const SizedBox(height: Space.xs),
        TweenAnimationBuilder<double>(
          tween: Tween(end: value.clamp(0, 1)),
          duration: duration,
          curve: Curves.easeOut,
          builder: (context, v, _) => ClipRRect(
            borderRadius: const BorderRadius.all(Radius.circular(Radii.pill)),
            child: LinearProgressIndicator(
              value: v,
              minHeight: 6,
              color: theme.colorScheme.secondary,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
          ),
        ),
      ],
    );
  }
}

/// A side window: a sloping front pillar, a rounded rear corner.
class _WindowShape extends CustomClipper<Path> {
  const _WindowShape();

  @override
  Path getClip(Size s) => Path()
    ..moveTo(0, s.height)
    ..quadraticBezierTo(s.width * 0.08, s.height * 0.3, s.width * 0.3, s.height * 0.04)
    ..quadraticBezierTo(s.width * 0.34, 0, s.width * 0.4, 0)
    ..lineTo(s.width - 18, 0)
    ..quadraticBezierTo(s.width, 0, s.width, 18)
    ..lineTo(s.width, s.height - 6)
    ..quadraticBezierTo(s.width, s.height, s.width - 6, s.height)
    ..close();

  @override
  bool shouldReclip(covariant CustomClipper<Path> old) => false;
}

/// The tinted part of the glass: after the handle, from the start side.
class _TintedPart extends CustomClipper<Rect> {
  const _TintedPart(this.split, this.rtl);

  final double split;
  final bool rtl;

  @override
  Rect getClip(Size s) => rtl
      ? Rect.fromLTRB(0, 0, s.width * (1 - split), s.height)
      : Rect.fromLTRB(s.width * split, 0, s.width, s.height);

  @override
  bool shouldReclip(_TintedPart old) => old.split != split || old.rtl != rtl;
}

/// From the street: the cabin, with a passenger and a headrest.
class _CabinPainter extends CustomPainter {
  const _CabinPainter();

  @override
  void paint(Canvas canvas, Size s) {
    final r = Offset.zero & s;
    canvas.drawRect(
      r,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFA9AFB6), Color(0xFF6B7178)],
        ).createShader(r),
    );
    final seat = Paint()..color = const Color(0xFF3A3F45);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(s.width * 0.6, s.height * 0.22, s.width * 0.14, s.height * 0.26),
        const Radius.circular(12),
      ),
      seat,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(s.width * 0.56, s.height * 0.52, s.width * 0.22, s.height * 0.6),
        const Radius.circular(14),
      ),
      seat,
    );
    final person = Paint()..color = const Color(0xFF8A6A52);
    canvas.drawCircle(Offset(s.width * 0.38, s.height * 0.42), s.height * 0.15, person);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(s.width * 0.24, s.height * 0.6, s.width * 0.28, s.height * 0.5),
        const Radius.circular(24),
      ),
      Paint()..color = const Color(0xFFE9ECEF),
    );
  }

  @override
  bool shouldRepaint(_CabinPainter old) => false;
}

/// From the driver's seat: the street in the sun.
class _StreetPainter extends CustomPainter {
  const _StreetPainter();

  @override
  void paint(Canvas canvas, Size s) {
    final r = Offset.zero & s;
    canvas.drawRect(
      r,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF8EC5EC), Color(0xFFF3E3B5)],
        ).createShader(r),
    );
    final sun = Offset(s.width * 0.78, s.height * 0.28);
    canvas.drawCircle(
      sun,
      s.height * 0.3,
      Paint()
        ..shader = RadialGradient(
          colors: [const Color(0xFFFFE08A).withValues(alpha: 0.9), const Color(0x00FFE08A)],
        ).createShader(Rect.fromCircle(center: sun, radius: s.height * 0.3)),
    );
    canvas.drawCircle(sun, s.height * 0.11, Paint()..color = const Color(0xFFF7B733));
    final building = Paint()..color = const Color(0xFFC9B48F);
    final far = Paint()..color = const Color(0xFFDCCBA9);
    for (final (x, w, top, p) in [
      (0.05, 0.16, 0.52, far),
      (0.2, 0.12, 0.4, building),
      (0.34, 0.2, 0.58, far),
      (0.5, 0.1, 0.46, building),
      (0.62, 0.18, 0.62, far),
    ]) {
      canvas.drawRect(Rect.fromLTWH(s.width * x, s.height * top, s.width * w, s.height), p);
    }
    canvas.drawRect(
      Rect.fromLTWH(0, s.height * 0.86, s.width, s.height * 0.14),
      Paint()..color = const Color(0xFF8C8C8C),
    );
  }

  @override
  bool shouldRepaint(_StreetPainter old) => false;
}

/// The film: its colour at the chosen darkness, and from outside the glare it reflects
/// (a silver mirror film most of all).
class _TintPainter extends CustomPainter {
  const _TintPainter({
    required this.colour,
    required this.darkness,
    required this.mirror,
    required this.outside,
  });

  final Color colour;
  final double darkness;
  final bool mirror;
  final bool outside;

  @override
  void paint(Canvas canvas, Size s) {
    final r = Offset.zero & s;
    // Darker film hides more than in proportion: 30% lets most through, 70% very little.
    final cover = (1 - math.pow(1 - darkness, 1.6)).clamp(0.0, 0.96).toDouble();
    canvas.drawRect(r, Paint()..color = colour.withValues(alpha: cover));
    if (!outside || darkness == 0) return;
    final sheen = (mirror ? 0.55 : 0.12) * darkness;
    canvas.drawRect(
      r,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0),
            Colors.white.withValues(alpha: sheen),
            Colors.white.withValues(alpha: 0),
          ],
          stops: const [0.25, 0.45, 0.7],
        ).createShader(r),
    );
  }

  @override
  bool shouldRepaint(_TintPainter old) =>
      old.colour != colour ||
      old.darkness != darkness ||
      old.mirror != mirror ||
      old.outside != outside;
}

/// One sweep of light across the glass when the shade changes.
class _GlarePainter extends CustomPainter {
  const _GlarePainter(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size s) {
    final x = -s.width * 0.4 + Curves.easeOutCubic.transform(t) * s.width * 1.8;
    final band = Rect.fromLTWH(x, 0, s.width * 0.25, s.height);
    canvas.save();
    canvas.skew(-0.35, 0);
    canvas.drawRect(
      band.translate(s.height * 0.35, 0),
      Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0),
            Colors.white.withValues(alpha: 0.45 * (1 - t)),
            Colors.white.withValues(alpha: 0),
          ],
        ).createShader(band.translate(s.height * 0.35, 0)),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GlarePainter old) => old.t != t;
}
