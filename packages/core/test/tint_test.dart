import 'package:alghali_core/alghali_core.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_server.dart';
import 'support/fixtures.dart';

// Window tint (D-149), on answers captured from alghali-test.
void main() {
  const fullBlack = TintChoice(
    carSize: TintCarSize.saloon,
    selection: TintSelection.package(TintItem.full),
    darkness: 50,
    colour: TintColour.black,
  );

  group('the choice', () {
    test('windows that make up a package become it, as on the server', () {
      final sides = TintSelection.windows({
        TintWindow.frontLeft,
        TintWindow.frontRight,
        TintWindow.backLeft,
        TintWindow.backRight,
      });
      expect(sides, const TintSelection.package(TintItem.sides));
      final two = TintSelection.windows({TintWindow.windscreen, TintWindow.sunroof});
      expect(two.package, isNull);
      expect(two.windowCodes, ['SUNROOF', 'WINDSCREEN']);
    });

    test('goes to the server in its canonical form and comes back equal', () {
      expect(fullBlack.toJson(), {
        'car_size': 'SALOON',
        'package': 'FULL',
        'darkness': 50,
        'colour': 'BLACK',
      });
      final windows = TintChoice(
        carSize: TintCarSize.suv,
        selection: TintSelection.windows({TintWindow.windscreen, TintWindow.backGlass}),
        darkness: 30,
        colour: TintColour.smoke,
      );
      expect(windows.toJson()['windows'], ['BACK_GLASS', 'WINDSCREEN']);
      expect(TintChoice.fromJson(windows.toJson()), windows);
    });
  });

  group('parsing', () {
    test('tint_offers: shops cheapest first, with what each offers', () {
      final offers = TintOffers.fromJson(fixture('tint_offers')! as Json);
      expect(offers.selection, const TintSelection.package(TintItem.full));
      expect(offers.shops.map((s) => s.priceSdg), [65000, 70000]);
      expect(offers.darkness, [20, 30, 50, 70, 100]);
      expect(offers.colours, [
        TintColour.black,
        TintColour.smoke,
        TintColour.blue,
        TintColour.bronze,
      ]);
      final atShop = offers.shops.firstWhere((s) => s.atShop);
      expect(atShop.offers(100, TintColour.bronze), isTrue);
      expect(atShop.offers(70, TintColour.black), isFalse);
    });

    test("shop_tint_settings: the shop's levels, colours and price grid", () {
      final s = ShopTintSettings.fromJson(fixture('shop_tint_settings')! as Json);
      expect(s.isActive, isTrue);
      expect(s.darkness, {30, 50, 100});
      expect(s.colours, {TintColour.black, TintColour.smoke, TintColour.bronze});
      expect(s.prices[(TintCarSize.saloon, TintItem.full)], 70000);
      expect(s.prices[(TintCarSize.pickup, TintItem.window)], 12000);
      expect(s.prices.containsKey((TintCarSize.minibus, TintItem.full)), isFalse);
      expect(s.bayTechnicians, 1);
      expect(ShopTintSettings.pricesJson(s.prices), hasLength(s.prices.length));
    });

    test('a checked tint line, its booking item and its order item', () {
      final check = CartCheck.fromJson(
        (fixture('cart_validate_tint')! as List).cast<Json>().single,
      );
      expect(check.ok, isTrue);
      expect(check.tintShopId, isNotNull);
      expect(check.listingId, isNull);

      final booking = Booking.fromJson(fixture('booking_hold_tint')! as Json);
      final item = booking.items.single;
      expect(item.jobType, JobType.tint);
      expect(item.minutes, 120);
      expect(item.tint, fullBlack);
      expect(FittingItem.fromBooking(item)?.toJson(), {
        'tint_shop_id': item.tintShopId,
        'tint': fullBlack.toJson(),
      });

      final order = Order.fromJson(fixture('order_tint')! as Json);
      final bought = order.subOrders.single.items.single;
      expect(bought.tint, fullBlack);
      expect(bought.listingId, isEmpty);
      expect(bought.title.en, 'Window tint: full car, 50%, black (saloon)');
      expect(order.subOrders.single.fulfilment, FulfilmentType.toTechnician);
    });
  });

  group('repositories', () {
    late FakeServer server;
    setUp(() => server = FakeServer());

    test('tint_offers gets the size and either the package or the windows', () async {
      server.on('/rest/v1/rpc/tint_offers', (_) => json(fixture('tint_offers')!));
      final repo = CatalogueRepository(server.client());
      await repo.tintOffers(TintCarSize.saloon, const TintSelection.package(TintItem.full));
      expect(server.body(0), {'p_car_size': 'SALOON', 'p_package': 'FULL', 'p_windows': null});
      await repo.tintOffers(TintCarSize.suv, TintSelection.windows({TintWindow.sunroof}));
      expect(server.body(1), {
        'p_car_size': 'SUV',
        'p_package': null,
        'p_windows': ['SUNROOF'],
      });
    });

    test('shop_set_tint sends the whole offer', () async {
      server.on('/rest/v1/rpc/shop_set_tint', (_) => json(fixture('shop_tint_settings')!));
      await ShopRepository(server.client()).setTint(
        'shop1',
        active: true,
        darkness: {50, 30},
        colours: {TintColour.black},
        prices: {(TintCarSize.saloon, TintItem.full): 60000},
      );
      expect(server.body(0), {
        'p_shop_id': 'shop1',
        'p_is_active': true,
        'p_darkness': [30, 50],
        'p_colours': ['BLACK'],
        'p_prices': [
          {'car_size': 'SALOON', 'item': 'FULL', 'price_sdg': 60000},
        ],
      });
    });

    test('a tint line goes to checkout with its shop and choice', () {
      const line = CheckoutLine.tint('shop1', fullBlack, seenPriceSdg: 70000);
      expect(line.toJson(), {
        'tint_shop_id': 'shop1',
        'tint': fullBlack.toJson(),
        'qty': 1,
        'seen_price_sdg': 70000,
      });
    });
  });
}
