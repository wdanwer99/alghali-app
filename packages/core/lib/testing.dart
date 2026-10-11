/// Helpers for widget tests and screenshot runs. Not used by app code.
library;

import 'dart:convert';

import 'package:flutter/services.dart';

/// Loads every font in the test bundle's FontManifest (the app font and
/// Material icons), so golden screenshots show real Arabic text instead of
/// the test font's boxes.
///
/// Inside this package's own tests the font is listed as `IBMPlexSansArabic`,
/// while the theme asks for `packages/alghali_core/IBMPlexSansArabic` (and
/// the apps list it that way), so each family is registered under both names.
Future<void> loadAppFonts() async {
  final manifest = json.decode(await rootBundle.loadString('FontManifest.json')) as List<dynamic>;
  for (final family in manifest.cast<Map<String, dynamic>>()) {
    final name = family['family'] as String;
    final assets = [
      for (final font in (family['fonts'] as List<dynamic>).cast<Map<String, dynamic>>())
        font['asset'] as String,
    ];
    final names = {
      name,
      if (name.startsWith('packages/')) name.split('/').last,
      if (!name.startsWith('packages/') && name != 'MaterialIcons') 'packages/alghali_core/$name',
    };
    for (final alias in names) {
      final loader = FontLoader(alias);
      for (final asset in assets) {
        loader.addFont(rootBundle.load(asset));
      }
      await loader.load();
    }
  }
}
