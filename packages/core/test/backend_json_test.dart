import 'dart:ffi' show Abi;

import 'package:alghali_core/alghali_core.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fixtures.dart';

void main() {
  test('search_parts rows become part cards with fit, offers and the server’s shop count', () {
    final rows = (fixture('search_parts')! as List).cast<Json>();
    final results = [for (final r in rows) PartResult.fromJson(r)];
    final first = results.first;
    expect(first.part.name.ar, 'لمبات أمامية LED مقاس H4 (زوج)');
    expect(first.part.name.en, 'H4 LED headlight bulbs (pair)');
    expect(first.fit, Fit.fits);
    expect(first.shopCount, rows.first['shop_count']);
    expect(first.fromSdg, rows.first['from_sdg']);
    expect(first.listings.first.condition, ListingCondition.newAftermarket);
    expect(first.listings.every((l) => l.partId == first.part.id), isTrue);
    final deal = first.listings.firstWhere((l) => l.wasSdg != null);
    expect(deal.discountPercent, greaterThan(0));
  });

  test('part_detail lists offers with the shop’s details', () {
    final detail = PartDetail.fromJson(fixture('part_detail')! as Json);
    expect(detail.fit, Fit.fits);
    expect(detail.jobType, JobType.lighting);
    expect(detail.part.standardMinutes, 30);
    expect(detail.part.fitmentModelIds, isNotEmpty);
    expect(detail.offers, isNotEmpty);
    final offer = detail.offers.first;
    expect(offer.listing.shopId, offer.shop.id);
    expect(offer.shop.name.ar, isNotEmpty);
    expect(offer.shop.phone, startsWith('+249'));
  });

  test('catalogue_snapshot builds the offline cache, resolving job types by id', () {
    final snap = CatalogueSnapshot.fromJson(fixture('catalogue_snapshot')! as Json);
    expect(snap.full, isTrue);
    expect(snap.makes.first.name.en, 'Toyota');
    expect(snap.models.every((m) => snap.makes.any((k) => k.id == m.makeId)), isTrue);
    expect(snap.variants.first.yearTo, greaterThanOrEqualTo(snap.variants.first.yearFrom));
    expect(snap.jobTypes.values, contains(JobType.mechanical));
    final lighting = snap.categories.firstWhere((c) => c.name.en == 'Lighting');
    expect(lighting.jobType, JobType.lighting);
    expect(lighting.icon, CategoryIcon.lighting);
    expect(snap.zones.map((z) => z.seq), [1, 2, 3, 4]);
    final shop = snap.shops.first;
    expect(shop.openingHours[6], [(480, 1200)]); // Saturday, 08:00–20:00
    expect(shop.openingHours.containsKey(5), isFalse); // closed on Friday
  });

  test('a snapshot delta reports deactivated rows and shops that left', () {
    final snap = CatalogueSnapshot.fromJson({
      'server_time': '2026-10-13T12:00:00Z',
      'full': false,
      'makes': [
        {'id': 'm1', 'name_ar': 'فورد', 'name_en': 'Ford', 'is_active': false},
      ],
      'models': <Object>[],
      'variants': <Object>[],
      'job_types': <Object>[],
      'categories': <Object>[],
      'markets': <Object>[],
      'streets': <Object>[],
      'zones': <Object>[],
      'shops': [
        {'id': 's1', 'status': 'SUSPENDED'},
      ],
    });
    expect(snap.makes, isEmpty);
    expect(snap.inactiveIds, {'m1'});
    expect(snap.removedShopIds, {'s1'});
  });

  test('public_settings becomes PlatformSettings, with the app release info', () {
    final s = PlatformSettings.fromJson(fixture('public_settings')! as Json);
    expect(s.bookingFeeSdg, 2000);
    expect(s.travelFee(2.5), 3000);
    expect(s.travelFee(20), isNull);
    expect(s.buyerRelease.minBuild, 1);
    expect(s.buyerRelease.updateRequired(1), isFalse);
  });

  test('app release: offer an update when newer, require it below the minimum', () {
    const r = AppRelease(latestBuild: 5, minBuild: 3, apkUrl: 'https://x/buyer.apk');
    expect(r.updateAvailable(4), isTrue);
    expect(r.updateRequired(4), isFalse);
    expect(r.updateRequired(2), isTrue);
    expect(const AppRelease(latestBuild: 5, minBuild: 3).updateRequired(1), isFalse); // no APK yet
    const split = AppRelease(latestBuild: 7, minBuild: 3, apkUrl: 'https://x/buyer-7-{abi}.apk');
    expect(split.apkFor(Abi.androidArm), 'https://x/buyer-7-armeabi-v7a.apk');
    expect(split.apkFor(Abi.androidArm64), 'https://x/buyer-7-arm64-v8a.apk');
    expect(r.apkFor(Abi.androidArm), 'https://x/buyer.apk'); // one file for every phone
  });

  test('me() becomes the account with roles and shop memberships', () {
    final a = Account.fromJson(fixture('me')! as Json);
    expect(a.roles, containsAll([AppRole.buyer, AppRole.shopOwner]));
    expect(a.shops.single.role, StaffRole.owner);
    expect(a.shops.single.status, PartnerStatus.approved);
    expect(a.profile.email, endsWith('@demo.alghali.invalid'));
  });

  test('listing drafts and bulk edits send only what was set', () {
    const draft = ListingDraft(
      condition: ListingCondition.used,
      stockQty: 2,
      priceSdg: 18000,
      newPart: NewPart(nameAr: 'فحمات', categoryId: 'cat', modelIds: ['m1']),
    );
    expect(draft.toParams('shop'), containsPair('p_condition', 'USED'));
    expect(draft.toParams('shop')['p_new_part'], {
      'name_ar': 'فحمات',
      'category_id': 'cat',
      'model_ids': ['m1'],
    });
    expect(const BulkEdit(listingId: 'l', version: 3, stockQty: 0).toJson(), {
      'listing_id': 'l',
      'version': 3,
      'stock_qty': 0,
    });
  });

  test('opening hours survive a round trip', () {
    const hours = {
      0: [(480, 780), (960, 1260)],
      6: [(540, 1080)],
    };
    expect(openingHoursFromJson(openingHoursToJson(hours)), hours);
  });
}
