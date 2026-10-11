import 'package:material_ui/material_ui.dart';

/// 4-point spacing scale. Screens use [page] as the side gutter.
abstract final class Space {
  static const xxs = 2.0;
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0;
  static const xxxl = 32.0;
  static const huge = 48.0;

  static const page = lg;
  static const pageInsets = EdgeInsets.all(page);
  static const pageHorizontal = EdgeInsets.symmetric(horizontal: page);
}

abstract final class Radii {
  static const xs = 6.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const pill = 999.0;

  static const smAll = BorderRadius.all(Radius.circular(sm));
  static const mdAll = BorderRadius.all(Radius.circular(md));
  static const lgAll = BorderRadius.all(Radius.circular(lg));
}

/// Short, calm motion: 150–250 ms for state changes, 300 ms for screens.
abstract final class Motion {
  static const fast = Duration(milliseconds: 150);
  static const medium = Duration(milliseconds: 220);
  static const slow = Duration(milliseconds: 300);
  static const curve = Curves.easeOutCubic;
}

/// Minimum sizes for anything tappable (WCAG / Android: 48 dp).
abstract final class Hit {
  static const min = 48.0;
  static const button = 52.0;
}
