import 'dart:math';

import 'package:alghali_core/alghali_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 10, 14, 7, 30); // Wednesday 09:30 Khartoum
  final catalogue = buildDemoCatalogue(now);

  group('Arabic search normaliser (D-006)', () {
    test('unifies alef, taa marbuta and yaa, strips tashkeel and tatweel', () {
      expect(arNormalize('أَإآٱ'), 'اااا');
      expect(arNormalize('لمبة'), 'لمبه');
      expect(arNormalize('على'), 'علي');
      expect(arNormalize('بطـــارية'), 'بطاريه');
      expect(arNormalize('  LED   H4 '), 'led h4');
    });

    test('plural, singular and definite forms reach the same stem', () {
      final stems = {
        for (final w in ['لمبة', 'لمبه', 'لمبات', 'اللمبات']) arStem(arNormalize(w)),
      };
      expect(stems, hasLength(1));
    });

    test('Arabic-Indic digits and Persian letters, as in ar_normalize()', () {
      expect(arNormalize('٤٥٠٠٠ ۱۲'), '45000 12');
      expect(arNormalize('کیا'), 'كيا');
    });

    // The same cases as tests/db/catalogue.test.ts runs against search_terms().
    for (final (input, expected) in [
      ('لمبات', ['لمب']),
      ('اللمبات', ['لمب']),
      ('فلتر زيت', ['فلتر', 'زيت']),
      ('زيت 5W-30، فلتر', ['زيت', '5w-30', 'فلتر']),
      ('إطار 265/65R17.', ['اطار', '265/65r17']),
      ('OEM: 04465-0K290', ['oem', '04465-0k290']),
      ('!!!', <String>[]),
    ]) {
      test('searchTerms("$input") matches the database', () {
        expect(searchTerms(input)..sort(), [...expected]..sort());
      });
    }
  });

  group('catalogue search', () {
    List<String> names(String q, {String? variant, bool onlyFits = false}) => [
      for (final r in catalogue.search(
        SearchQuery(text: q, variantId: variant, onlyFits: onlyFits),
      ))
        r.part.name.en,
    ];

    test('"لمبات" finds bulbs and nothing else', () {
      final found = names('لمبات');
      expect(found, containsAll(['H4 halogen bulb', 'H4 LED headlight bulbs (pair)']));
      expect(found.any((n) => n.contains('brake')), isFalse);
    });

    test('colloquial synonyms work: لستك finds tyres, بوري finds horns', () {
      expect(names('لستك'), everyElement(startsWith('Tyre')));
      expect(names('بوري'), ['12 V dual horn']);
    });

    test('OEM numbers match with or without the dash', () {
      expect(names('04465-0K290'), ['Front brake pads']);
      expect(names('044650k290'), ['Front brake pads']);
    });

    test('with a car selected, parts known not to fit are left out', () {
      final hilux = names('فحمات', variant: 'v-hilux-16p');
      expect(hilux, ['Front brake pads']);
      final accent = catalogue.search(const SearchQuery(text: 'فحمات', variantId: 'v-accent-11'));
      expect(accent.single.part.id, 'pt-pads-accent');
    });

    test('"only fits" hides parts without fitment data', () {
      final all = names('لمبات', variant: 'v-hilux-16p');
      final fitsOnly = names('لمبات', variant: 'v-hilux-16p', onlyFits: true);
      expect(all, contains('Rear indicator bulbs (set of 4)'));
      expect(fitsOnly, isNot(contains('Rear indicator bulbs (set of 4)')));
    });

    test('listings come cheapest first', () {
      final r = catalogue.search(const SearchQuery(text: 'H4 halogen')).first;
      final prices = [for (final l in r.listings) l.priceSdg];
      expect(prices, [...prices]..sort());
      expect(r.fromSdg, prices.first);
    });
  });

  group('order references (D-016)', () {
    test('new references are 8 digits with a valid Luhn check digit', () {
      final random = Random(1);
      for (var i = 0; i < 200; i++) {
        final ref = newOrderRef(random);
        expect(ref, matches(RegExp(r'^[1-9]\d{7}$')));
        expect(isValidRef(ref), isTrue);
      }
    });

    test('a single mistyped digit is caught', () {
      const ref = '48151625';
      expect(isValidRef(ref), isTrue);
      expect(isValidRef('48151626'), isFalse);
      expect(isValidRef('48751625'), isFalse);
    });

    test('formatRef groups the digits and keeps them left-to-right', () {
      final f = formatRef('48151625');
      expect(f.codeUnits.first, 0x2066);
      expect(f.codeUnits.last, 0x2069);
      expect(f.substring(1, f.length - 1), '4815 1625');
    });
  });

  group('demo slot engine (PLAN §5)', () {
    final thursday = DateTime.utc(2026, 10, 15);
    final friday = DateTime.utc(2026, 10, 16);

    test('no slots on Friday', () {
      expect(slotsFor(technicianId: 'tc-osman', day: friday, durationMin: 30, now: now), isEmpty);
    });

    test('slots sit on a 30-minute grid inside working hours (Khartoum time)', () {
      final slots = slotsFor(technicianId: 'tc-osman', day: thursday, durationMin: 60, now: now);
      expect(slots, isNotEmpty);
      for (final s in slots) {
        final local = toKhartoum(s.slot.start);
        expect(local.minute % 30, 0);
        final startMin = local.hour * 60 + local.minute;
        final inMorning = startMin >= 9 * 60 && startMin + 60 <= 13 * 60;
        final inEvening = startMin >= 16 * 60 && startMin + 60 <= 21 * 60;
        expect(inMorning || inEvening, isTrue, reason: '$local');
      }
    });

    test('today starts after the part-ready buffer', () {
      final today = DateTime.utc(2026, 10, 14);
      final slots = slotsFor(technicianId: 'tc-osman', day: today, durationMin: 30, now: now);
      expect(slots.first.slot.start.isBefore(now.add(const Duration(minutes: 120))), isFalse);
    });

    test('ranking prefers better-rated, more experienced, closer technicians', () {
      final osman = catalogue.technician('tc-osman');
      final khalid = catalogue.technician('tc-khalid');
      expect(technicianScore(osman), greaterThan(technicianScore(khalid)));
    });
  });

  test('fee bands: 3 km → 3,000; 8 km → 6,000; beyond 15 km is not served', () {
    const s = PlatformSettings.demo;
    expect(s.travelFee(2.6), 3000);
    expect(s.travelFee(6.2), 6000);
    expect(s.travelFee(16), isNull);
  });

  test('initials skip the Arabic article and use two Latin letters', () {
    expect(InitialsAvatar.initialsOf('النيل لكهرباء السيارات'), 'ن');
    expect(InitialsAvatar.initialsOf('محمد عثمان'), 'م');
    expect(InitialsAvatar.initialsOf('Mohamed Osman'), 'MO');
    expect(InitialsAvatar.initialsOf(''), '?');
  });

  test('every listing points at a real part and shop', () {
    for (final l in catalogue.listings) {
      expect(() => catalogue.part(l.partId), returnsNormally, reason: l.id);
      expect(() => catalogue.shop(l.shopId), returnsNormally, reason: l.id);
    }
    for (final t in catalogue.technicians.where((t) => t.bayShopId != null)) {
      expect(() => catalogue.shop(t.bayShopId!), returnsNormally, reason: t.id);
    }
  });
}
