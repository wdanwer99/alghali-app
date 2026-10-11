import 'package:material_ui/material_ui.dart';

/// IBM Plex Sans Arabic type scale.
///
/// Sizes are one step above Material's defaults because Arabic glyphs read
/// smaller at the same size, and line heights are generous so marks above and
/// below the letters are never clipped. Letter spacing is always zero: any
/// tracking breaks the joins between Arabic letters.
abstract final class AppTypography {
  static const fontFamily = 'IBMPlexSansArabic';
  static const fontPackage = 'alghali_core';

  /// Figures that keep their width, for prices, timers and references.
  static const tabular = [FontFeature.tabularFigures()];

  static TextTheme textTheme(ColorScheme scheme) {
    TextStyle style(double size, double lineHeight, FontWeight weight, [Color? color]) => TextStyle(
      fontSize: size,
      height: lineHeight / size,
      fontWeight: weight,
      letterSpacing: 0,
      leadingDistribution: TextLeadingDistribution.even,
      color: color ?? scheme.onSurface,
    );

    return TextTheme(
      displayLarge: style(44, 56, FontWeight.w700),
      displayMedium: style(38, 48, FontWeight.w700),
      displaySmall: style(32, 42, FontWeight.w700),
      headlineLarge: style(28, 38, FontWeight.w700),
      headlineMedium: style(25, 34, FontWeight.w700),
      headlineSmall: style(22, 31, FontWeight.w700),
      titleLarge: style(19, 28, FontWeight.w700),
      titleMedium: style(17, 26, FontWeight.w600),
      titleSmall: style(15, 23, FontWeight.w600),
      bodyLarge: style(16, 26, FontWeight.w400),
      bodyMedium: style(15, 24, FontWeight.w400),
      bodySmall: style(13, 20, FontWeight.w400, scheme.onSurfaceVariant),
      labelLarge: style(16, 22, FontWeight.w600),
      labelMedium: style(14, 20, FontWeight.w500),
      labelSmall: style(12, 17, FontWeight.w500),
    );
  }
}
