import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/services.dart' show SystemUiOverlayStyle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../l10n/generated/core_localizations.dart';
import '../theme/app_palette.dart';
import '../theme/app_tokens.dart';
import 'brand.dart';

/// Off in widget tests, which pump the app and tap straight away.
final splashEnabledProvider = Provider<bool>((ref) => true);

/// The night street's colours for each app. [ground] is Android's launch-screen colour
/// (`flutter_native_splash` in the app's pubspec), so the splash takes over unseen.
@immutable
class StreetColors {
  const StreetColors({
    required this.ground,
    required this.deep,
    required this.accent,
    required this.lamp,
  });

  final Color ground;

  /// The edges darken to this as the street lights up.
  final Color deep;

  /// The mark's dot, and the glow at the end of the street.
  final Color accent;
  final Color lamp;

  static StreetColors of(MarkVariant variant) => switch (variant) {
    MarkVariant.buyer => const StreetColors(
      ground: AppPalette.charcoal,
      deep: AppPalette.ink,
      accent: Color(0xFFEF4444),
      lamp: AppPalette.amber400,
    ),
    MarkVariant.partner => const StreetColors(
      ground: AppPalette.red700,
      deep: AppPalette.red950,
      accent: Colors.white,
      lamp: AppPalette.amber100,
    ),
  };
}

/// Where [t] is inside [begin]..[end], as 0..1.
double _span(double t, double begin, double end) => ((t - begin) / (end - begin)).clamp(0.0, 1.0);

/// A street at night in perspective, running from the bottom edge to [vanish], with the
/// accent glowing at [glow] (the vanishing point unless given). As
/// [reveal] goes 0 → 1 the kerbs draw away from the viewer and the lamps come on, near
/// to far; while [chase] runs, a light travels down the lane markings towards the
/// viewer. At [reveal] 0 it paints nothing, so it can start on a plain colour.
class StreetPainter extends CustomPainter {
  StreetPainter({
    required this.colors,
    required this.reveal,
    this.chase,
    this.vanish = Alignment.center,
    Alignment? glow,
  }) : glow = glow ?? vanish,
       super(repaint: Listenable.merge([reveal, chase]));

  final StreetColors colors;
  final Animation<double> reveal;
  final Animation<double>? chase;
  final Alignment vanish;
  final Alignment glow;

  static const _dashes = 10;
  static const _lamps = 6;

  @override
  void paint(Canvas canvas, Size size) {
    final r = reveal.value;
    if (r == 0) return;
    final vp = vanish.alongSize(size);
    final bottom = size.height + 24;
    final depth = bottom - vp.dy;
    final halfRoad = size.width * 0.5;

    // d is 0 on the horizon and 1 at the bottom edge; x is in road half-widths.
    Offset ground(double x, double d) => Offset(vp.dx + x * halfRoad * d, vp.dy + depth * d);
    // Haze near the horizon softens the far end.
    double haze(double d) => _span(d, 0.12, 0.4);

    final dark = Curves.easeOut.transform(_span(r, 0, 0.6));
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = RadialGradient(
          center: vanish,
          radius: 1.2,
          colors: [
            colors.ground.withValues(alpha: 0),
            colors.deep.withValues(alpha: 0.85 * dark),
          ],
          stops: const [0.2, 1],
        ).createShader(Offset.zero & size),
    );

    final lit = Curves.easeOut.transform(_span(r, 0.35, 0.9));
    final glowAt = glow.alongSize(size);
    canvas.drawCircle(
      glowAt,
      size.shortestSide * 0.5,
      Paint()
        ..shader = ui.Gradient.radial(glowAt, size.shortestSide * 0.5, [
          colors.accent.withValues(alpha: 0.22 * lit),
          colors.accent.withValues(alpha: 0),
        ]),
    );

    // Kerbs draw from the viewer towards the horizon.
    final drawn = Curves.easeOutCubic.transform(_span(r, 0, 0.45));
    final far = 1 - drawn;
    final kerb = Paint()
      ..strokeWidth = 2
      ..shader = ui.Gradient.linear(
        Offset(0, vp.dy),
        Offset(0, bottom),
        [Colors.white.withValues(alpha: 0), Colors.white.withValues(alpha: 0.5)],
        const [0, 0.5],
      );
    for (final side in const [-1.0, 1.0]) {
      canvas.drawLine(ground(side, 1), ground(side, math.max(far, 0.01)), kerb);
    }

    // Lane markings, evenly spaced on the road; z = 1 is the bottom edge.
    final lightAt = chase == null ? null : (_dashes + 3) * (1 - chase!.value) - 1.5;
    for (var i = 0; i < _dashes; i++) {
      final z = 1.0 + i * 0.8;
      final near = 1 / z;
      final away = 1 / (z + 0.4);
      if (near < far) break;
      final lit = lightAt == null ? 0.0 : math.exp(-math.pow(i - lightAt, 2) / 1.4);
      final alpha = haze(near) * (0.3 + 0.7 * lit);
      if (alpha <= 0.01) continue;
      const w = 0.03;
      canvas.drawPath(
        Path()
          ..moveTo(ground(-w, near).dx, ground(-w, near).dy)
          ..lineTo(ground(w, near).dx, ground(w, near).dy)
          ..lineTo(ground(w, away).dx, ground(w, away).dy)
          ..lineTo(ground(-w, away).dx, ground(-w, away).dy)
          ..close(),
        Paint()..color = Color.lerp(Colors.white, colors.lamp, lit * 0.5)!.withValues(alpha: alpha),
      );
    }

    // Street lamps on both kerbs, lighting up near to far with a short flicker.
    final post = Paint()
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.28);
    for (var k = 0; k < _lamps; k++) {
      final d = 1 / (1.25 + k * 0.85);
      final fade = _span(d, 0.1, 0.35);
      if (fade == 0 || d < far) continue;
      final start = 0.16 + k * 0.08;
      final t = _span(r, start, start + 0.16);
      final on = t < 0.35
          ? t / 0.35 * 0.8
          : t < 0.5
          ? 0.35
          : 0.35 + (t - 0.5) / 0.5 * 0.65;
      for (final side in const [-1.0, 1.0]) {
        final foot = ground(side * 1.1, d);
        final top = foot.translate(0, -depth * 0.75 * d);
        final head = Offset(ground(side * 0.92, d).dx, top.dy);
        post
          ..strokeWidth = 1 + 2 * d
          ..color = Colors.white.withValues(alpha: 0.28 * fade);
        canvas
          ..drawLine(foot, top, post)
          ..drawLine(top, head, post);
        if (on == 0) continue;
        // Light pooled on the road below, then the lamp's own glow.
        final pool = ground(side * 0.8, d);
        canvas
          ..save()
          ..translate(pool.dx, pool.dy)
          ..scale(1, 0.28)
          ..drawCircle(
            Offset.zero,
            halfRoad * 0.5 * d,
            Paint()
              ..shader = ui.Gradient.radial(Offset.zero, halfRoad * 0.5 * d, [
                colors.lamp.withValues(alpha: 0.22 * on * fade),
                colors.lamp.withValues(alpha: 0),
              ]),
          )
          ..restore();
        final radius = 10 + 60 * d;
        canvas
          ..drawCircle(
            head,
            radius,
            Paint()
              ..shader = ui.Gradient.radial(head, radius, [
                colors.lamp.withValues(alpha: 0.55 * on * fade),
                colors.lamp.withValues(alpha: 0),
              ]),
          )
          ..drawCircle(
            head,
            1.5 + 3 * d,
            Paint()
              ..color = Color.lerp(colors.lamp, Colors.white, 0.6)!.withValues(alpha: on * fade),
          );
      }
    }
  }

  @override
  bool shouldRepaint(StreetPainter old) =>
      old.colors != colors ||
      old.reveal != reveal ||
      old.chase != chase ||
      old.vanish != vanish ||
      old.glow != glow;
}

/// Plays the street lighting up over the app on every start, while [ready] is false
/// (the account and saved data on their way), then fades into whatever is underneath.
/// It always plays through once, and gives up waiting after a few seconds: screens have
/// their own loading states. With animations turned off it shows the finished street.
class SplashGate extends ConsumerStatefulWidget {
  const SplashGate({
    required this.ready,
    required this.child,
    this.variant = MarkVariant.buyer,
    super.key,
  });

  final bool ready;
  final Widget child;
  final MarkVariant variant;

  /// The mark's box on Android's launch screen: a 1152 px image at 4x, the mark at half
  /// scale (packages/core/test/export_icons_test.dart).
  static const markBox = 288.0;
  static const markScale = 0.5;

  @override
  ConsumerState<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends ConsumerState<SplashGate> with TickerProviderStateMixin {
  static const _longest = Duration(seconds: 6);
  static const _introSeconds = 1.8;
  static const _chaseSeconds = 1.1;

  // Driven by [_tick] rather than run, so the street can't skip ahead (see there).
  late final _intro = AnimationController(vsync: this);
  late final _chase = AnimationController(vsync: this);
  late final _ticker = createTicker(_tick);
  var _lastTick = Duration.zero;
  var _clock = 0.0;
  late final _exit = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));
  late var _shown = ref.read(splashEnabledProvider);
  Timer? _giveUp;
  var _started = false;
  var _played = false;
  var _timedOut = false;

  @override
  void initState() {
    super.initState();
    if (!_shown) return;
    _giveUp = Timer(_longest, () {
      _timedOut = true;
      _leave();
    });
    _intro.addStatusListener((s) {
      if (s != AnimationStatus.completed) return;
      _played = true;
      _leave();
    });
    _exit.addStatusListener((s) {
      if (s != AnimationStatus.completed || !mounted) return;
      _ticker.stop();
      setState(() => _shown = false);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_shown || _started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _intro.value = 1;
    } else {
      unawaited(_ticker.start());
    }
  }

  /// Moves the street on by the frame's time, but never more than one frame's worth:
  /// right after the first frame the app is busy starting up underneath (seconds on a
  /// cheap phone), and a running animation would come back already finished.
  void _tick(Duration elapsed) {
    final step = (elapsed - _lastTick).inMicroseconds / Duration.microsecondsPerSecond;
    _lastTick = elapsed;
    _clock += math.min(step, 1 / 30);
    _intro.value = math.min(_clock / _introSeconds, 1);
    _chase.value = _clock / _chaseSeconds % 1;
  }

  @override
  void didUpdateWidget(SplashGate old) {
    super.didUpdateWidget(old);
    if (widget.ready) _leave();
  }

  void _leave() {
    if (!_shown ||
        !_played ||
        !(widget.ready || _timedOut) ||
        _exit.status != AnimationStatus.dismissed) {
      return;
    }
    _giveUp?.cancel();
    if (MediaQuery.disableAnimationsOf(context)) {
      _exit.value = 1;
    } else {
      unawaited(_exit.forward());
    }
  }

  @override
  void dispose() {
    _giveUp?.cancel();
    _ticker.dispose();
    _intro.dispose();
    _chase.dispose();
    _exit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The same Stack either way, so the app underneath keeps its state when the splash goes.
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (_shown)
          // Blocks taps and hides the page from screen readers until the street fades.
          BlockSemantics(
            child: AbsorbPointer(
              child: FadeTransition(
                opacity: ReverseAnimation(CurvedAnimation(parent: _exit, curve: Curves.easeIn)),
                child: _SplashView(
                  variant: widget.variant,
                  intro: _intro,
                  chase: _chase,
                  exit: _exit,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SplashView extends StatelessWidget {
  const _SplashView({
    required this.variant,
    required this.intro,
    required this.chase,
    required this.exit,
  });

  final MarkVariant variant;
  final Animation<double> intro;
  final Animation<double> chase;
  final Animation<double> exit;

  /// From the screen's middle: the letter ends about 63 dp down, the name starts below
  /// it, and the street's far end sits under the tagline.
  static const _nameBelow = 80.0;
  static const _streetBelow = 165.0;

  @override
  Widget build(BuildContext context) {
    final colors = StreetColors.of(variant);
    final t = CoreLocalizations.of(context);
    final theme = Theme.of(context);
    final words = CurvedAnimation(
      parent: intro,
      curve: const Interval(0.55, 0.9, curve: Curves.easeOutCubic),
    );
    final pin = CurvedAnimation(parent: intro, curve: const Interval(0.5, 1));
    const k = SplashGate.markBox * SplashGate.markScale;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Semantics(
        label: t.brandName,
        child: ColoredBox(
          color: colors.ground,
          child: LayoutBuilder(
            builder: (context, box) => Stack(
              alignment: Alignment.center,
              children: [
                // The mark stays in the middle with the name under it; the street begins below both.
                Positioned.fill(
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: StreetPainter(
                        colors: colors,
                        reveal: intro,
                        chase: chase,
                        vanish: Alignment(0, _streetBelow / (box.maxHeight / 2)),
                        glow: Alignment.center,
                      ),
                    ),
                  ),
                ),
                // The mark exactly where Android's launch screen left it; the dot glows once
                // like a pin dropped at the end of the street, and the mark leans in on the way out.
                ScaleTransition(
                  scale: Tween(
                    begin: 1.0,
                    end: 1.12,
                  ).animate(CurvedAnimation(parent: exit, curve: Curves.easeIn)),
                  child: SizedBox.square(
                    dimension: SplashGate.markBox,
                    child: CustomPaint(
                      painter: _PinGlowPainter(
                        pulse: pin,
                        color: colors.accent,
                        at: const Offset(0, -k * 0.2975),
                      ),
                      foregroundPainter: MarkPainter(
                        glyph: Colors.white,
                        dot: colors.accent,
                        scale: SplashGate.markScale,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: box.maxHeight / 2 + _nameBelow,
                  left: Space.lg,
                  right: Space.lg,
                  child: FadeTransition(
                    opacity: words,
                    child: SlideTransition(
                      position: Tween(begin: const Offset(0, 0.4), end: Offset.zero).animate(words),
                      child: ExcludeSemantics(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              t.brandName,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              t.brandTagline,
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: Colors.white.withValues(alpha: 0.72),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A soft ring that swells once around the mark's dot, [at] from the box's centre.
class _PinGlowPainter extends CustomPainter {
  _PinGlowPainter({required this.pulse, required this.color, required this.at})
    : super(repaint: pulse);

  final Animation<double> pulse;
  final Color color;
  final Offset at;

  @override
  void paint(Canvas canvas, Size size) {
    final p = pulse.value;
    if (p == 0) return;
    final c = size.center(Offset.zero) + at;
    // Rises quickly, settles to a faint halo.
    final strength = p < 0.4 ? p / 0.4 : 1 - 0.6 * (p - 0.4) / 0.6;
    final radius = 14 + 34 * Curves.easeOut.transform(p);
    canvas.drawCircle(
      c,
      radius,
      Paint()
        ..shader = ui.Gradient.radial(c, radius, [
          color.withValues(alpha: 0.55 * strength),
          color.withValues(alpha: 0),
        ]),
    );
  }

  @override
  bool shouldRepaint(_PinGlowPainter old) =>
      old.color != color || old.at != at || old.pulse != pulse;
}
