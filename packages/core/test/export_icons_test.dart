// Renders the placeholder logo into the PNGs that flutter_launcher_icons and
// flutter_native_splash read. Run when the mark changes:
//   cd packages/core && flutter test test/export_icons_test.dart --dart-define=EXPORT_ICONS=true --update-goldens
// then `dart run flutter_launcher_icons` and `dart run flutter_native_splash:create`
// in apps/buyer and apps/partner (see README).
import 'package:alghali_core/alghali_core.dart';
import 'package:alghali_core/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

const _enabled = bool.fromEnvironment('EXPORT_ICONS');

Future<void> _export(
  WidgetTester tester,
  String path,
  MarkPainter painter, {
  double size = 1024,
  Color? fill,
}) async {
  tester.view.physicalSize = Size.square(size);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.rtl,
      child: RepaintBoundary(
        child: ColoredBox(
          color: fill ?? const Color(0x00000000),
          child: SizedBox.square(
            dimension: size,
            child: CustomPaint(painter: painter),
          ),
        ),
      ),
    ),
  );
  await expectLater(find.byType(RepaintBoundary).first, matchesGoldenFile(path));
}

void main() {
  setUpAll(loadAppFonts);

  const red = Color(0xFFEF4444);
  for (final (app, bg, dot) in [
    ('buyer', AppPalette.charcoal, red),
    ('partner', AppPalette.red700, Colors.white),
  ]) {
    final dir = '../../../apps/$app/assets/icon';
    testWidgets('$app launcher icons', skip: !_enabled, (tester) async {
      // Full-bleed square: iOS and older Android launchers apply their own mask.
      await _export(
        tester,
        '$dir/icon.png',
        MarkPainter(glyph: Colors.white, dot: dot, scale: 0.8),
        fill: bg,
      );
      // Adaptive icon layers keep content inside the middle 61% safe zone.
      await _export(
        tester,
        '$dir/foreground.png',
        MarkPainter(glyph: Colors.white, dot: dot, scale: 0.56),
      );
      await _export(
        tester,
        '$dir/monochrome.png',
        const MarkPainter(glyph: Colors.white, dot: Colors.white, scale: 0.56),
      );
      // Splash: the bare mark, the same on every Android (12+ draws it inside a circle
      // covering two thirds of the image), at the size SplashGate starts from.
      await _export(
        tester,
        '$dir/splash.png',
        MarkPainter(glyph: Colors.white, dot: dot, scale: SplashGate.markScale),
        size: SplashGate.markBox * 4,
      );
      await _export(
        tester,
        '$dir/splash_android12.png',
        MarkPainter(glyph: Colors.white, dot: dot, scale: SplashGate.markScale),
        size: SplashGate.markBox * 4,
      );
    });
  }

  testWidgets('mark preview', skip: !_enabled, (tester) async {
    await _export(
      tester,
      '../build/icons/preview.png',
      const MarkPainter(background: AppPalette.charcoal, glyph: Colors.white, dot: red),
      size: 512,
      fill: Colors.white,
    );
  });
}
