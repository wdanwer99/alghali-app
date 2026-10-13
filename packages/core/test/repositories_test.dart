import 'dart:convert';
import 'dart:typed_data';

import 'package:alghali_core/alghali_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/fake_server.dart';

void main() {
  late FakeServer server;
  setUp(() => server = FakeServer());

  group('CatalogueRepository', () {
    test('search sends the query, filters and sort the way search_parts names them', () async {
      server.on('/rest/v1/rpc/search_parts', (_) => json(<Object>[]));
      final repo = CatalogueRepository(server.client());
      final page = await repo.search(
        const SearchQuery(
          text: 'لمبات',
          variantId: 'v1',
          onlyFits: true,
          conditions: {ListingCondition.newOem},
          maxPriceSdg: 50000,
          sort: SearchSort.priceLow,
        ),
        limit: 20,
      );
      expect(page.results, isEmpty);
      expect(page.total, 0);
      expect(server.body(0), {
        'p_q': 'لمبات',
        'p_variant_id': 'v1',
        'p_category_id': null,
        'p_only_fits': true,
        'p_conditions': ['NEW_OEM'],
        'p_price_max': 50000,
        'p_shop_id': null,
        'p_in_stock_only': true,
        'p_deals_only': false,
        'p_sort': 'price_low',
        'p_limit': 20,
        'p_offset': 0,
      });
    });

    test('deals default to the biggest discount first', () async {
      server.on('/rest/v1/rpc/search_parts', (_) => json(<Object>[]));
      await CatalogueRepository(server.client()).search(const SearchQuery(), dealsOnly: true);
      expect(server.body(0), containsPair('p_sort', 'discount'));
      expect(server.body(0), containsPair('p_deals_only', true));
    });

    test('snapshot sends since in UTC', () async {
      server.on('/rest/v1/rpc/catalogue_snapshot', (_) {
        return json({
          'server_time': '2026-10-13T12:00:00Z',
          'full': false,
          for (final k in [
            'makes',
            'models',
            'variants',
            'job_types',
            'categories',
            'zones',
            'shops',
          ])
            k: <Object>[],
        });
      });
      final snap = await CatalogueRepository(server.client())
          .snapshot(since: DateTime.utc(2026, 10, 1));
      expect(server.body(0), {'p_since': '2026-10-01T00:00:00.000Z'});
      expect(snap.serverTime, DateTime.utc(2026, 10, 13, 12));
    });
  });

  group('ShopRepository', () {
    test('saving a listing sends the draft with an idempotency key', () async {
      server.on('/rest/v1/rpc/shop_upsert_listing', (_) {
        return json({
          'id': 'l1',
          'version': 1,
          'condition': 'NEW_AFTERMARKET',
          'price_sdg': 38000,
          'price_on_request': false,
          'stock_qty': 4,
          'available_qty': 4,
          'warranty_days': 90,
          'is_active': true,
          'images': <Object>[],
          'part': {
            'id': 'p1',
            'name_ar': 'فحمات',
            'name_en': '',
            'category_id': 'c1',
            'own': true,
            'model_ids': ['m1'],
          },
        });
      });
      final listing = await ShopRepository(server.client()).saveListing(
        'shop1',
        const ListingDraft(
          condition: ListingCondition.newAftermarket,
          stockQty: 4,
          priceSdg: 38000,
          warrantyDays: 90,
          newPart: NewPart(nameAr: 'فحمات', categoryId: 'c1', modelIds: ['m1']),
        ),
        idem: '00000000-0000-4000-8000-000000000001',
      );
      expect(listing.ownPart, isTrue);
      expect(listing.partName.en, 'فحمات'); // English falls back to Arabic
      expect(server.body(0), containsPair('p_idem', '00000000-0000-4000-8000-000000000001'));
      expect(server.body(0), containsPair('p_shop_id', 'shop1'));
    });

    test('a stale edit surfaces as VERSION_CONFLICT (HTTP 409)', () async {
      server.on(
        '/rest/v1/rpc/shop_upsert_listing',
        (_) => json({
          'code': 'PT409',
          'message': 'VERSION_CONFLICT',
          'details': '3',
          'hint': null,
        }, 409),
      );
      final call = ShopRepository(server.client()).saveListing(
        'shop1',
        const ListingDraft(
          condition: ListingCondition.used,
          stockQty: 1,
          priceSdg: 1,
          listingId: 'l1',
          version: 2,
        ),
      );
      await expectLater(
        call,
        throwsA(
          isA<BackendException>()
              .having((e) => e.code, 'code', 'VERSION_CONFLICT')
              .having((e) => e.detail, 'detail', '3'),
        ),
      );
    });

    test('importing uploads the sheet to the shop’s folder, then calls the function', () async {
      server
        ..on('/storage/v1/object/imports/shop1/', (_) => json({'Key': 'imports/x'}))
        ..on('/functions/v1/inventory-import', (_) {
          return json({
            'total': 2,
            'created': 1,
            'updated': 0,
            'failed': 1,
            'dry_run': false,
            'errors': [
              {'row': 3, 'code': 'INVALID_PRICE', 'column': 'price'},
            ],
            'warnings': <Object>[],
          });
        });
      final report = await ShopRepository(server.client())
          .importStock('shop1', Uint8List.fromList([1, 2, 3]), 'مخزون.xlsx');
      expect(report.failed, 1);
      expect(report.errors.single.code, 'INVALID_PRICE');
      final upload = server.requests.first;
      expect(
        upload.url.path,
        matches(RegExp(r'^/storage/v1/object/imports/shop1/[0-9a-f-]{36}\.xlsx$')),
      );
      final call = server.requests.last;
      expect(call.headers['Idempotency-Key'], matches(RegExp(r'^[0-9a-f-]{36}$')));
      expect(
        jsonDecode(call.body),
        containsPair('file_key', upload.url.path.replaceFirst('/storage/v1/object/imports/', '')),
      );
    });
  });

  group('errors', () {
    test('RPC codes come through as they are; generic denials become FORBIDDEN', () {
      expect(
        BackendException.from(const PostgrestException(message: 'INVALID_PHONE', code: '22023'))
            .code,
        'INVALID_PHONE',
      );
      final denied = BackendException.from(
        const PostgrestException(message: 'permission denied for table profiles', code: '42501'),
      );
      expect(denied.code, 'FORBIDDEN');
      expect(denied.status, 403);
    });

    test('auth, storage and function errors are mapped to codes', () {
      expect(
        BackendException.from(const AuthException('x', code: 'invalid_credentials')).code,
        'INVALID_CREDENTIALS',
      );
      expect(BackendException.from(AuthRetryableFetchException()).offline, isTrue);
      expect(
        BackendException.from(
          const StorageException('mime type text/html is not supported', statusCode: '415'),
        ).code,
        'INVALID_FILE_TYPE',
      );
      expect(
        BackendException.from(
          const FunctionException(status: 422, details: {'error': 'HEADER_NOT_FOUND'}),
        ).code,
        'HEADER_NOT_FOUND',
      );
    });

    test('a dropped connection is OFFLINE', () async {
      final client = SupabaseClient(
        'https://fake.supabase.co',
        'sb_publishable_fake',
        httpClient: MockClient((_) => throw http.ClientException('Connection reset')),
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      await expectLater(
        CatalogueRepository(client).settings(),
        throwsA(isA<BackendException>().having((e) => e.offline, 'offline', isTrue)),
      );
    });
  });

  test('idempotency keys are fresh v4 UUIDs', () {
    final a = newIdempotencyKey();
    expect(
      a,
      matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')),
    );
    expect(newIdempotencyKey(), isNot(a));
  });
}
