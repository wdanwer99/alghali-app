import 'dart:ui' show Locale;

import 'package:alghali_core/alghali_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> containerWith(Map<String, Object> prefs) async {
  SharedPreferences.setMockInitialValues(prefs);
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(await SharedPreferences.getInstance())],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('defaults to Arabic and asks the user to choose', () async {
    final c = await containerWith({});
    final state = c.read(localeControllerProvider);
    expect(state.locale, const Locale('ar'));
    expect(state.chosen, isFalse);
  });

  test('remembers the chosen language', () async {
    final c = await containerWith({});
    await c.read(localeControllerProvider.notifier).select(const Locale('en'));

    final prefs = c.read(sharedPreferencesProvider);
    expect(prefs.getString('locale'), 'en');
    expect(c.read(localeControllerProvider).chosen, isTrue);
  });

  test('previewing does not count as choosing', () async {
    final c = await containerWith({});
    c.read(localeControllerProvider.notifier).preview(const Locale('en'));
    final state = c.read(localeControllerProvider);
    expect(state.locale, const Locale('en'));
    expect(state.chosen, isFalse);
  });

  test('ignores an unsupported saved language', () async {
    final c = await containerWith({'locale': 'fr'});
    expect(c.read(localeControllerProvider).locale, const Locale('ar'));
  });

  test('toggle flips between Arabic and English', () async {
    final c = await containerWith({'locale': 'ar'});
    await c.read(localeControllerProvider.notifier).toggle();
    expect(c.read(localeControllerProvider).locale, const Locale('en'));
  });
}
