import 'package:material_ui/material_ui.dart';

import '../l10n/generated/core_localizations.dart';
import '../theme/app_palette.dart';
import '../theme/app_typography.dart';

/// Which app the mark belongs to: the buyer app is charcoal with a red dot,
/// the partner app is red, so the two icons are easy to tell apart.
enum MarkVariant { buyer, partner }

/// The placeholder brand mark: the letter "ع" with a dot above it, which reads
/// "غ" as in الغالي. The dot doubles as a "you are here" pin on the street.
class AlghaliMark extends StatelessWidget {
  const AlghaliMark({
    super.key,
    this.size = 40,
    this.variant = MarkVariant.buyer,
    this.background = true,
  });

  final double size;
  final MarkVariant variant;

  /// False draws only the letter and dot (for app-icon foreground layers).
  final bool background;

  @override
  Widget build(BuildContext context) {
    final bg = variant == MarkVariant.buyer ? AppPalette.charcoal : AppPalette.red700;
    final dot = variant == MarkVariant.buyer ? const Color(0xFFEF4444) : Colors.white;
    return Semantics(
      label: CoreLocalizations.of(context).brandName,
      image: true,
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: MarkPainter(background: background ? bg : null, glyph: Colors.white, dot: dot),
        ),
      ),
    );
  }
}

/// Paints the mark into any square; also used to export the launcher icons.
class MarkPainter extends CustomPainter {
  const MarkPainter({required this.glyph, required this.dot, this.background, this.scale = 1});

  final Color? background;
  final Color glyph;
  final Color dot;

  /// Shrinks the letter and dot (adaptive icons keep content in the middle 61%).
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    if (background != null) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(s * 0.24)),
        Paint()..color = background!,
      );
    }
    final k = s * scale;
    final center = size.center(Offset.zero);
    final painter = TextPainter(
      text: TextSpan(
        text: 'ع',
        style: TextStyle(
          fontFamily: AppTypography.fontFamily,
          package: AppTypography.fontPackage,
          fontWeight: FontWeight.w700,
          fontSize: k * 0.66,
          height: 1,
          color: glyph,
        ),
      ),
      textDirection: TextDirection.rtl,
    )..layout();
    // Offsets measured from rendered output: the letter's ink starts ~9% down
    // its line box and sits right of its advance centre. Letter + gap + dot
    // together span the middle 74% of the square.
    painter.paint(canvas, Offset(center.dx - painter.width / 2 - k * 0.019, center.dy - k * 0.24));
    canvas.drawCircle(center + Offset(0, -k * 0.2975), k * 0.07, Paint()..color = dot);
  }

  @override
  bool shouldRepaint(MarkPainter old) =>
      old.background != background || old.glyph != glyph || old.dot != dot || old.scale != scale;
}

/// Mark + "شارع الغالي" wordmark, for headers and the welcome screen.
class AlghaliLogo extends StatelessWidget {
  const AlghaliLogo({
    super.key,
    this.markSize = 40,
    this.variant = MarkVariant.buyer,
    this.color,
    this.subtitle,
  });

  final double markSize;
  final MarkVariant variant;

  /// Text colour; defaults to the theme's on-surface colour.
  final Color? color;

  /// Shown under the name; defaults to the tagline.
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final t = CoreLocalizations.of(context);
    final theme = Theme.of(context);
    final fg = color ?? theme.colorScheme.onSurface;
    return ExcludeSemantics(
      excluding: false,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AlghaliMark(size: markSize, variant: variant),
          SizedBox(width: markSize * 0.28),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.brandName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: fg,
                    fontSize: markSize * 0.5,
                    height: 1.25,
                  ),
                ),
                Text(
                  subtitle ?? t.brandTagline,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: fg.withValues(alpha: 0.72),
                    fontSize: (markSize * 0.3).clamp(11, 16),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
