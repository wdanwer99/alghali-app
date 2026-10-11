import 'package:flutter/services.dart' show SystemUiOverlayStyle;
import 'package:material_ui/material_ui.dart';

import 'app_colors.dart';
import 'app_palette.dart';
import 'app_tokens.dart';
import 'app_typography.dart';

/// Shared look for both apps: charcoal brand, red for the main action,
/// IBM Plex Sans Arabic, flat cards with hairline borders (cheap to draw on
/// low-end phones) and 48 dp+ tap targets.
abstract final class AppTheme {
  static ThemeData light() => _build(_lightScheme, AppColors.light, canvas: AppPalette.canvas);

  static ThemeData dark() => _build(_darkScheme, AppColors.dark, canvas: AppPalette.night0);

  static const _lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppPalette.red700,
    onPrimary: Colors.white,
    primaryContainer: AppPalette.red100,
    onPrimaryContainer: AppPalette.red900,
    secondary: AppPalette.charcoal,
    onSecondary: Colors.white,
    secondaryContainer: AppPalette.gray200,
    onSecondaryContainer: AppPalette.gray900,
    tertiary: AppPalette.blue700,
    onTertiary: Colors.white,
    tertiaryContainer: AppPalette.blue100,
    onTertiaryContainer: AppPalette.blue900,
    error: Color(0xFFB3261E),
    onError: Colors.white,
    errorContainer: Color(0xFFFDECEA),
    onErrorContainer: Color(0xFF8C1D18),
    surface: Colors.white,
    onSurface: AppPalette.gray900,
    onSurfaceVariant: AppPalette.gray600,
    surfaceDim: AppPalette.gray200,
    surfaceBright: Colors.white,
    surfaceContainerLowest: Colors.white,
    surfaceContainerLow: AppPalette.gray50,
    surfaceContainer: AppPalette.gray100,
    surfaceContainerHigh: AppPalette.gray150,
    surfaceContainerHighest: AppPalette.gray200,
    outline: AppPalette.gray450,
    outlineVariant: AppPalette.gray200,
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: AppPalette.charcoal,
    onInverseSurface: AppPalette.gray50,
    inversePrimary: AppPalette.red300,
    surfaceTint: Colors.transparent,
  );

  static const _darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: AppPalette.red400,
    onPrimary: AppPalette.red950,
    primaryContainer: AppPalette.red900,
    onPrimaryContainer: AppPalette.red100,
    secondary: AppPalette.gray200,
    onSecondary: AppPalette.gray900,
    secondaryContainer: AppPalette.night4,
    onSecondaryContainer: AppPalette.gray50,
    tertiary: AppPalette.blue400,
    onTertiary: Color(0xFF0A1A3F),
    tertiaryContainer: AppPalette.blue900,
    onTertiaryContainer: AppPalette.blue100,
    error: Color(0xFFF2B8B5),
    onError: Color(0xFF601410),
    errorContainer: Color(0xFF8C1D18),
    onErrorContainer: Color(0xFFF9DEDC),
    surface: AppPalette.night1,
    onSurface: AppPalette.gray100,
    onSurfaceVariant: AppPalette.gray400,
    surfaceDim: AppPalette.night0,
    surfaceBright: AppPalette.night4,
    surfaceContainerLowest: AppPalette.night0,
    surfaceContainerLow: AppPalette.night1,
    surfaceContainer: AppPalette.night2,
    surfaceContainerHigh: AppPalette.night3,
    surfaceContainerHighest: AppPalette.night4,
    outline: AppPalette.gray500,
    outlineVariant: AppPalette.night4,
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: AppPalette.gray100,
    onInverseSurface: AppPalette.gray900,
    inversePrimary: AppPalette.red700,
    surfaceTint: Colors.transparent,
  );

  static ThemeData _build(ColorScheme scheme, AppColors colors, {required Color canvas}) {
    final isDark = scheme.brightness == Brightness.dark;
    // Apply the family here, not only via ThemeData.fontFamily: component
    // styles below (badges, chips, buttons) are built from these and some
    // widgets use them without merging with the ambient text style.
    final text = AppTypography.textTheme(scheme)
        .apply(fontFamily: AppTypography.fontFamily, package: AppTypography.fontPackage);
    final chipBorder = isDark ? AppPalette.night4 : AppPalette.gray300;
    final inputFill = isDark ? scheme.surfaceContainer : scheme.surface;
    const shape12 = RoundedRectangleBorder(borderRadius: Radii.mdAll);

    OutlineInputBorder inputBorder(Color color, [double width = 1]) => OutlineInputBorder(
      borderRadius: Radii.mdAll,
      borderSide: BorderSide(color: color, width: width),
    );

    bool selected(Set<WidgetState> s) => s.contains(WidgetState.selected);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: AppTypography.fontFamily,
      package: AppTypography.fontPackage,
      textTheme: text,
      scaffoldBackgroundColor: canvas,
      canvasColor: scheme.surface,
      dividerColor: scheme.outlineVariant,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      // Ripples are much cheaper than the sparkle shader on old phones.
      splashFactory: InkRipple.splashFactory,
      extensions: [colors],
      iconTheme: IconThemeData(color: scheme.onSurface, size: 24),
      appBarTheme: AppBarThemeData(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
        shape: Border(bottom: BorderSide(color: scheme.outlineVariant)),
        systemOverlayStyle: (isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
            .copyWith(statusBarColor: Colors.transparent),
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: Radii.mdAll,
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          // In dark mode the light "primary" red suits text and icons, but the
          // main action button needs a solid red with white text.
          backgroundColor: isDark ? AppPalette.red600 : null,
          foregroundColor: isDark ? Colors.white : null,
          minimumSize: const Size(64, Hit.button),
          padding: const EdgeInsets.symmetric(horizontal: Space.xl),
          shape: shape12,
          textStyle: text.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, Hit.button),
          padding: const EdgeInsets.symmetric(horizontal: Space.xl),
          foregroundColor: scheme.onSurface,
          side: BorderSide(color: scheme.outline),
          shape: shape12,
          textStyle: text.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(Hit.min, Hit.min),
          padding: const EdgeInsets.symmetric(horizontal: Space.md),
          shape: shape12,
          textStyle: text.labelLarge,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size(Hit.min, Hit.min)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 2,
        highlightElevation: 4,
        shape: const RoundedRectangleBorder(borderRadius: Radii.lgAll),
        extendedTextStyle: text.labelLarge,
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: inputFill,
        contentPadding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.lg),
        border: inputBorder(scheme.outline),
        enabledBorder: inputBorder(scheme.outline),
        // Focus is charcoal, not red, so a focused field never looks like an error.
        focusedBorder: inputBorder(scheme.secondary, 2),
        errorBorder: inputBorder(scheme.error),
        focusedErrorBorder: inputBorder(scheme.error, 2),
        disabledBorder: inputBorder(scheme.outlineVariant),
        labelStyle: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
        floatingLabelStyle: text.bodyLarge?.copyWith(color: scheme.onSurface),
        hintStyle: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
        helperStyle: text.bodySmall,
        errorStyle: text.bodySmall?.copyWith(color: scheme.error),
        errorMaxLines: 3,
        prefixIconColor: scheme.onSurfaceVariant,
        suffixIconColor: scheme.onSurfaceVariant,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: scheme.secondary,
        selectionColor: scheme.secondary.withValues(alpha: 0.25),
        selectionHandleColor: scheme.secondary,
      ),
      chipTheme: ChipThemeData(
        color: WidgetStateProperty.resolveWith(
          (s) => selected(s) ? scheme.secondary : scheme.surface,
        ),
        side: WidgetStateBorderSide.resolveWith(
          (s) => BorderSide(color: selected(s) ? scheme.secondary : chipBorder),
        ),
        labelStyle: text.labelMedium?.copyWith(
          color: WidgetStateColor.resolveWith(
            (s) => selected(s) ? scheme.onSecondary : scheme.onSurface,
          ),
        ),
        checkmarkColor: scheme.onSecondary,
        iconTheme: IconThemeData(color: scheme.onSurfaceVariant, size: 18),
        shape: const RoundedRectangleBorder(borderRadius: Radii.smAll),
        padding: const EdgeInsets.symmetric(horizontal: Space.xs, vertical: Space.sm),
        elevation: 0,
        pressElevation: 0,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(0, Hit.min)),
          textStyle: WidgetStatePropertyAll(text.labelMedium),
          backgroundColor: WidgetStateProperty.resolveWith(
            (s) => selected(s) ? scheme.secondary : scheme.surface,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (s) => selected(s) ? scheme.onSecondary : scheme.onSurface,
          ),
          side: WidgetStatePropertyAll(BorderSide(color: chipBorder)),
          shape: const WidgetStatePropertyAll(shape12),
        ),
      ),
      // Toggles use charcoal: a red "on" switch reads as a warning.
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => selected(s) ? scheme.onSecondary : scheme.outline,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => selected(s) ? scheme.secondary : scheme.surfaceContainerHighest,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (s) => selected(s) ? scheme.secondary : scheme.outline,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => selected(s) ? scheme.secondary : Colors.transparent,
        ),
        checkColor: WidgetStatePropertyAll(scheme.onSecondary),
        side: BorderSide(color: scheme.outline, width: 2),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(4))),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => selected(s) ? scheme.secondary : scheme.outline,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        indicatorColor: scheme.primaryContainer,
        indicatorShape: const RoundedRectangleBorder(borderRadius: Radii.mdAll),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(
            size: 24,
            color: selected(s) ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => text.labelSmall?.copyWith(
            fontSize: 12.5,
            fontWeight: selected(s) ? FontWeight.w700 : FontWeight.w500,
            color: selected(s) ? scheme.onSurface : scheme.onSurfaceVariant,
          ),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: scheme.onSurface,
        unselectedLabelColor: scheme.onSurfaceVariant,
        labelStyle: text.titleSmall,
        unselectedLabelStyle: text.titleSmall?.copyWith(fontWeight: FontWeight.w500),
        indicatorColor: scheme.primary,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: scheme.outlineVariant,
      ),
      listTileTheme: ListTileThemeData(
        minVerticalPadding: Space.md,
        contentPadding: const EdgeInsetsDirectional.symmetric(horizontal: Space.lg),
        horizontalTitleGap: Space.md,
        iconColor: scheme.onSurfaceVariant,
        titleTextStyle: text.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
        subtitleTextStyle: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, thickness: 1, space: 1),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        modalBackgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: scheme.outline,
        clipBehavior: Clip.antiAlias,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.xl)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: Radii.lgAll),
        titleTextStyle: text.titleLarge,
        contentTextStyle: text.bodyLarge,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: text.bodyMedium?.copyWith(color: scheme.onInverseSurface),
        actionTextColor: scheme.inversePrimary,
        shape: const RoundedRectangleBorder(borderRadius: Radii.smAll),
      ),
      badgeTheme: BadgeThemeData(
        backgroundColor: scheme.primary,
        textColor: scheme.onPrimary,
        textStyle: text.labelSmall?.copyWith(fontWeight: FontWeight.w700),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.surfaceContainerHighest,
        circularTrackColor: Colors.transparent,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(color: scheme.inverseSurface, borderRadius: Radii.smAll),
        textStyle: text.bodySmall?.copyWith(color: scheme.onInverseSurface),
      ),
    );
  }
}
