import 'package:material_ui/material_ui.dart';

/// Raw brand colours. Widgets should not use these directly: read the
/// [ColorScheme] or [AppColors] from the theme so dark mode keeps working.
///
/// Charcoal is the brand colour (headers, selected chips); red is reserved for
/// the main action on a screen (buy, book, pay) so it always stands out.
/// Contrast ratios in comments are against white unless stated.
abstract final class AppPalette {
  // Charcoal / neutral scale.
  static const gray50 = Color(0xFFF9FAFB);
  static const gray100 = Color(0xFFF3F4F6);
  static const gray150 = Color(0xFFECEEF1);
  static const gray200 = Color(0xFFE5E7EB);
  static const gray300 = Color(0xFFD1D5DB);
  static const gray400 = Color(0xFF9CA3AF);
  static const gray450 = Color(0xFF868D98); // 3.3:1, input borders
  static const gray500 = Color(0xFF6B7280);
  static const gray600 = Color(0xFF4B5563); // 7.6:1, secondary text
  static const gray700 = Color(0xFF374151);
  static const charcoal = Color(0xFF1F2937); // brand, 14.7:1
  static const gray900 = Color(0xFF111827);
  static const ink = Color(0xFF0B0F19);

  // Action red.
  static const red50 = Color(0xFFFEF2F2);
  static const red100 = Color(0xFFFEE2E2);
  static const red300 = Color(0xFFFCA5A5);
  static const red400 = Color(0xFFF87171);
  static const red600 = Color(0xFFDC2626); // dark-mode buttons, 4.8:1 with white
  static const red700 = Color(0xFFB91C1C); // primary, 6.5:1
  static const red800 = Color(0xFF991B1B);
  static const red900 = Color(0xFF7F1D1D);
  static const red950 = Color(0xFF450A0A);

  // Status colours (always paired with an icon or text, never colour alone).
  static const green50 = Color(0xFFF0FDF4);
  static const green100 = Color(0xFFDCFCE7);
  static const green400 = Color(0xFF4ADE80);
  static const green700 = Color(0xFF15803D); // 5.0:1
  static const green900 = Color(0xFF14532D);
  static const amber100 = Color(0xFFFEF3C7);
  static const amber400 = Color(0xFFFBBF24);
  static const amber500 = Color(0xFFF59E0B);
  static const amber700 = Color(0xFFB45309); // 5.0:1
  static const amber900 = Color(0xFF78350F);
  static const blue100 = Color(0xFFDBEAFE);
  static const blue400 = Color(0xFF60A5FA);
  static const blue700 = Color(0xFF1D4ED8); // 6.7:1
  static const blue900 = Color(0xFF1E3A8A);

  // Dark-mode surfaces.
  static const night0 = Color(0xFF0B0F19); // page
  static const night1 = Color(0xFF111827); // cards, bars
  static const night2 = Color(0xFF182030);
  static const night3 = Color(0xFF1F2937);
  static const night4 = Color(0xFF273244);
  static const nightBrand = Color(0xFF151C2A);

  /// Page background behind white cards in light mode.
  static const canvas = Color(0xFFF4F5F7);
}
