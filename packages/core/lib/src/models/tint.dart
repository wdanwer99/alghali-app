import 'package:flutter/foundation.dart' show immutable, listEquals;

import 'catalogue.dart';

/// Window tint (D-149): the buyer picks a car size, a package or single windows, a
/// darkness and a colour; each shop prices a package or one window per car size.
/// The codes match the database (`tint_choice()`).
enum TintCarSize {
  small('SMALL'),
  saloon('SALOON'),
  suv('SUV'),
  pickup('PICKUP'),
  minibus('MINIBUS');

  const TintCarSize(this.code);

  final String code;

  static TintCarSize? fromCode(String? code) => values.where((v) => v.code == code).firstOrNull;
}

/// What a shop prices: the four packages, and [window] for one window ticked on its own.
enum TintItem {
  full('FULL'),
  sides('SIDES'),
  sidesBack('SIDES_BACK'),
  windscreenStrip('WINDSCREEN_STRIP'),
  window('WINDOW');

  const TintItem(this.code);

  final String code;

  static TintItem? fromCode(String? code) => values.where((v) => v.code == code).firstOrNull;

  /// The packages the buyer can choose (everything but [window]).
  static const packages = [full, sides, sidesBack, windscreenStrip];
}

enum TintWindow {
  windscreen('WINDSCREEN'),
  backGlass('BACK_GLASS'),
  frontLeft('FRONT_LEFT'),
  frontRight('FRONT_RIGHT'),
  backLeft('BACK_LEFT'),
  backRight('BACK_RIGHT'),
  sunroof('SUNROOF');

  const TintWindow(this.code);

  final String code;

  static TintWindow? fromCode(String? code) => values.where((v) => v.code == code).firstOrNull;
}

enum TintColour {
  black('BLACK'),
  smoke('SMOKE'),
  blue('BLUE'),
  green('GREEN'),
  bronze('BRONZE'),
  silver('SILVER');

  const TintColour(this.code);

  final String code;

  static TintColour? fromCode(String? code) => values.where((v) => v.code == code).firstOrNull;
}

/// The darkness levels a shop can offer, in percent (100 = the darkest).
const tintDarknessLevels = [10, 20, 30, 40, 50, 60, 70, 80, 90, 100];

const _sides = {
  TintWindow.frontLeft,
  TintWindow.frontRight,
  TintWindow.backLeft,
  TintWindow.backRight,
};

/// The windows of a package; the windscreen strip is a package only.
Set<TintWindow> tintWindowsOf(TintItem package) => switch (package) {
  TintItem.full => {..._sides, TintWindow.windscreen, TintWindow.backGlass},
  TintItem.sidesBack => {..._sides, TintWindow.backGlass},
  TintItem.sides => _sides,
  TintItem.windscreenStrip || TintItem.window => const {},
};

/// The windows to tint: a package, or windows ticked one by one.
@immutable
class TintSelection {
  /// Windows that make up a package become that package, as on the server.
  factory TintSelection.windows(Set<TintWindow> windows) {
    for (final p in [TintItem.full, TintItem.sidesBack, TintItem.sides]) {
      final w = tintWindowsOf(p);
      if (w.length == windows.length && w.containsAll(windows)) return TintSelection.package(p);
    }
    return TintSelection._(null, {...windows});
  }

  const TintSelection.package(TintItem this.package) : windows = const {};
  const TintSelection._(this.package, this.windows);

  final TintItem? package;
  final Set<TintWindow> windows;

  bool get isEmpty => package == null && windows.isEmpty;

  /// The windows sorted by code, as the database keeps them.
  List<String> get windowCodes => [for (final w in windows) w.code]..sort();

  @override
  bool operator ==(Object other) =>
      other is TintSelection &&
      other.package == package &&
      listEquals(other.windowCodes, windowCodes);

  @override
  int get hashCode => Object.hash(package, Object.hashAll(windowCodes));
}

/// What the buyer chose: `{car_size, package | windows, darkness, colour}`.
@immutable
class TintChoice {
  const TintChoice({
    required this.carSize,
    required this.selection,
    required this.darkness,
    required this.colour,
  });

  factory TintChoice.fromJson(Json j) => TintChoice(
    carSize: TintCarSize.fromCode(j['car_size'] as String?) ?? TintCarSize.saloon,
    selection: switch (TintItem.fromCode(j['package'] as String?)) {
      final p? => TintSelection.package(p),
      null => TintSelection.windows({
        for (final c in [...?(j['windows'] as List?)?.cast<String>()]) ?TintWindow.fromCode(c),
      }),
    },
    darkness: (j['darkness'] as num?)?.toInt() ?? 0,
    colour: TintColour.fromCode(j['colour'] as String?) ?? TintColour.black,
  );

  final TintCarSize carSize;
  final TintSelection selection;
  final int darkness;
  final TintColour colour;

  Json toJson() => {
    'car_size': carSize.code,
    if (selection.package != null) 'package': selection.package!.code,
    if (selection.package == null) 'windows': selection.windowCodes,
    'darkness': darkness,
    'colour': colour.code,
  };

  @override
  bool operator ==(Object other) =>
      other is TintChoice &&
      other.carSize == carSize &&
      other.selection == selection &&
      other.darkness == darkness &&
      other.colour == colour;

  @override
  int get hashCode => Object.hash(carSize, selection, darkness, colour);
}

/// One shop in `tint_offers`: its price for the size and windows asked about, and the
/// darkness levels and colours it does.
@immutable
class TintShopOffer {
  const TintShopOffer({
    required this.shopId,
    required this.priceSdg,
    required this.darkness,
    required this.colours,
    required this.atShop,
  });

  factory TintShopOffer.fromJson(Json j) => TintShopOffer(
    shopId: j['shop_id'] as String,
    priceSdg: (j['price_sdg'] as num).toInt(),
    darkness: [
      for (final d in [...?(j['darkness'] as List?)]) (d as num).toInt(),
    ],
    colours: [
      for (final c in [...?(j['colours'] as List?)?.cast<String>()]) ?TintColour.fromCode(c),
    ],
    atShop: j['at_shop'] as bool? ?? false,
  );

  final String shopId;
  final int priceSdg;
  final List<int> darkness;
  final List<TintColour> colours;

  /// A technician works at the shop's own bay and can fit it there.
  final bool atShop;

  bool offers(int darkness, TintColour colour) =>
      this.darkness.contains(darkness) && colours.contains(colour);
}

/// The answer of `tint_offers`: the windows as the server reads them, and the shops,
/// cheapest first.
@immutable
class TintOffers {
  const TintOffers({required this.selection, required this.shops});

  factory TintOffers.fromJson(Json j) {
    final choice = {...(j['choice'] as Json? ?? const {}), 'darkness': 0, 'colour': 'BLACK'};
    return TintOffers(
      selection: TintChoice.fromJson(choice).selection,
      shops: [for (final s in (j['shops'] as List).cast<Json>()) TintShopOffer.fromJson(s)],
    );
  }

  final TintSelection selection;
  final List<TintShopOffer> shops;

  /// Every darkness level some shop offers, lightest first.
  List<int> get darkness => {for (final s in shops) ...s.darkness}.toList()..sort();

  /// Every colour some shop offers, in the usual order.
  List<TintColour> get colours => [
    for (final c in TintColour.values)
      if (shops.any((s) => s.colours.contains(c))) c,
  ];
}

/// A shop's own tint offer (`shop_tint_settings`), for the partner app.
@immutable
class ShopTintSettings {
  const ShopTintSettings({
    required this.isActive,
    required this.darkness,
    required this.colours,
    required this.prices,
    required this.bayTechnicians,
  });

  factory ShopTintSettings.fromJson(Json j) => ShopTintSettings(
    isActive: j['is_active'] as bool? ?? false,
    darkness: {
      for (final d in [...?(j['darkness'] as List?)]) (d as num).toInt(),
    },
    colours: {
      for (final c in [...?(j['colours'] as List?)?.cast<String>()]) ?TintColour.fromCode(c),
    },
    prices: {
      for (final p in [...?(j['prices'] as List?)?.cast<Json>()])
        if ((
              TintCarSize.fromCode(p['car_size'] as String?),
              TintItem.fromCode(p['item'] as String?),
            )
            case (final size?, final item?))
          (size, item): (p['price_sdg'] as num).toInt(),
    },
    bayTechnicians: j['bay_technicians'] as int? ?? 0,
  );

  final bool isActive;
  final Set<int> darkness;
  final Set<TintColour> colours;
  final Map<(TintCarSize, TintItem), int> prices;

  /// Technicians who tint at the shop's bay ("at the shop" needs one).
  final int bayTechnicians;

  /// The `p_prices` of `shop_set_tint`.
  static List<Json> pricesJson(Map<(TintCarSize, TintItem), int> prices) => [
    for (final MapEntry(key: (size, item), :value) in prices.entries)
      {'car_size': size.code, 'item': item.code, 'price_sdg': value},
  ];
}
