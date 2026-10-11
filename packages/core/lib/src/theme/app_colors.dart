import 'package:material_ui/material_ui.dart';

import 'app_palette.dart';

/// The tone of a status pill, banner or icon. Each tone has a strong colour
/// (text/icons) and a soft container colour.
enum Tone { neutral, brand, success, warning, danger, info }

/// Colours the Material [ColorScheme] has no slot for: status tones and the
/// dark brand band used behind the logo on home screens.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.brandSurface,
    required this.onBrandSurface,
    required this.onBrandSurfaceMuted,
    required this.success,
    required this.successContainer,
    required this.onSuccessContainer,
    required this.warning,
    required this.warningContainer,
    required this.onWarningContainer,
    required this.info,
    required this.infoContainer,
    required this.onInfoContainer,
    required this.neutralContainer,
    required this.onNeutralContainer,
    required this.star,
    required this.chart1,
    required this.chart2,
  });

  static const light = AppColors(
    brandSurface: AppPalette.charcoal,
    onBrandSurface: Colors.white,
    onBrandSurfaceMuted: AppPalette.gray300,
    success: AppPalette.green700,
    successContainer: AppPalette.green100,
    onSuccessContainer: AppPalette.green900,
    warning: AppPalette.amber700,
    warningContainer: AppPalette.amber100,
    onWarningContainer: AppPalette.amber900,
    info: AppPalette.blue700,
    infoContainer: AppPalette.blue100,
    onInfoContainer: AppPalette.blue900,
    neutralContainer: AppPalette.gray150,
    onNeutralContainer: AppPalette.gray700,
    star: AppPalette.amber500,
    chart1: Color(0xFF2A78D6),
    chart2: Color(0xFFEB6834),
  );

  static const dark = AppColors(
    brandSurface: AppPalette.nightBrand,
    onBrandSurface: Colors.white,
    onBrandSurfaceMuted: AppPalette.gray300,
    success: AppPalette.green400,
    successContainer: AppPalette.green900,
    onSuccessContainer: AppPalette.green100,
    warning: AppPalette.amber400,
    warningContainer: AppPalette.amber900,
    onWarningContainer: AppPalette.amber100,
    info: AppPalette.blue400,
    infoContainer: AppPalette.blue900,
    onInfoContainer: AppPalette.blue100,
    neutralContainer: AppPalette.night4,
    onNeutralContainer: AppPalette.gray200,
    star: AppPalette.amber400,
    chart1: Color(0xFF3987E5),
    chart2: Color(0xFFD95926),
  );

  final Color brandSurface;
  final Color onBrandSurface;
  final Color onBrandSurfaceMuted;
  final Color success;
  final Color successContainer;
  final Color onSuccessContainer;
  final Color warning;
  final Color warningContainer;
  final Color onWarningContainer;
  final Color info;
  final Color infoContainer;
  final Color onInfoContainer;
  final Color neutralContainer;
  final Color onNeutralContainer;
  final Color star;

  /// Chart series colours, validated with the dataviz palette checks against
  /// this theme's surface (contrast, CVD separation). Text never uses them.
  final Color chart1;
  final Color chart2;

  static AppColors of(BuildContext context) => Theme.of(context).extension<AppColors>()!;

  /// Strong colour for text and icons in [tone].
  Color strong(Tone tone, ColorScheme scheme) => switch (tone) {
    Tone.neutral => onNeutralContainer,
    Tone.brand => scheme.primary,
    Tone.success => success,
    Tone.warning => warning,
    Tone.danger => scheme.error,
    Tone.info => info,
  };

  /// Soft background for pills and banners in [tone].
  Color container(Tone tone, ColorScheme scheme) => switch (tone) {
    Tone.neutral => neutralContainer,
    Tone.brand => scheme.primaryContainer,
    Tone.success => successContainer,
    Tone.warning => warningContainer,
    Tone.danger => scheme.errorContainer,
    Tone.info => infoContainer,
  };

  /// Readable text colour on [container].
  Color onContainer(Tone tone, ColorScheme scheme) => switch (tone) {
    Tone.neutral => onNeutralContainer,
    Tone.brand => scheme.onPrimaryContainer,
    Tone.success => onSuccessContainer,
    Tone.warning => onWarningContainer,
    Tone.danger => scheme.onErrorContainer,
    Tone.info => onInfoContainer,
  };

  @override
  AppColors copyWith({Color? brandSurface}) => AppColors(
    brandSurface: brandSurface ?? this.brandSurface,
    onBrandSurface: onBrandSurface,
    onBrandSurfaceMuted: onBrandSurfaceMuted,
    success: success,
    successContainer: successContainer,
    onSuccessContainer: onSuccessContainer,
    warning: warning,
    warningContainer: warningContainer,
    onWarningContainer: onWarningContainer,
    info: info,
    infoContainer: infoContainer,
    onInfoContainer: onInfoContainer,
    neutralContainer: neutralContainer,
    onNeutralContainer: onNeutralContainer,
    star: star,
    chart1: chart1,
    chart2: chart2,
  );

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other == null) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppColors(
      brandSurface: mix(brandSurface, other.brandSurface),
      onBrandSurface: mix(onBrandSurface, other.onBrandSurface),
      onBrandSurfaceMuted: mix(onBrandSurfaceMuted, other.onBrandSurfaceMuted),
      success: mix(success, other.success),
      successContainer: mix(successContainer, other.successContainer),
      onSuccessContainer: mix(onSuccessContainer, other.onSuccessContainer),
      warning: mix(warning, other.warning),
      warningContainer: mix(warningContainer, other.warningContainer),
      onWarningContainer: mix(onWarningContainer, other.onWarningContainer),
      info: mix(info, other.info),
      infoContainer: mix(infoContainer, other.infoContainer),
      onInfoContainer: mix(onInfoContainer, other.onInfoContainer),
      neutralContainer: mix(neutralContainer, other.neutralContainer),
      onNeutralContainer: mix(onNeutralContainer, other.onNeutralContainer),
      star: mix(star, other.star),
      chart1: mix(chart1, other.chart1),
      chart2: mix(chart2, other.chart2),
    );
  }
}
