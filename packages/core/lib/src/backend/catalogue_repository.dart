import 'dart:convert';

import 'package:flutter/foundation.dart' show immutable;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/catalogue_data.dart';
import '../data/catalogue_snapshot.dart';
import '../data/platform_settings.dart';
import '../models/catalogue.dart';
import '../models/tint.dart';
import 'backend_error.dart';
import 'read_cache.dart';

@immutable
class SearchPage {
  const SearchPage(this.results, this.total);

  final List<PartResult> results;

  /// All matches, for "N results" and paging.
  final int total;
}

/// One shop's offer in [PartDetail], with the shop's details for the compare list.
@immutable
class ShopOffer {
  const ShopOffer({required this.listing, required this.shop, required this.images, this.note});

  final Listing listing;
  final Shop shop;
  final List<String> images;
  final String? note;
}

@immutable
class PartDetail {
  const PartDetail({
    required this.part,
    required this.offers,
    this.fit,
    this.jobType,
    this.fitmentNote,
  });

  factory PartDetail.fromJson(Json j) {
    final part = j['part'] as Json;
    final note = LocalizedText.fromJson(part, 'fitment_note');
    final p = Part.fromJson(part);
    return PartDetail(
      part: p,
      fit: Fit.fromCode(part['fit'] as String?),
      jobType: JobType.fromCode(part['job_type_code'] as String?),
      fitmentNote: note.ar.isEmpty ? null : note,
      offers: [
        for (final l in (j['listings'] as List).cast<Json>())
          ShopOffer(
            listing: Listing.fromJson({...l, 'shop_id': (l['shop'] as Json)['id']}, partId: p.id),
            shop: Shop.fromJson(l['shop'] as Json),
            images: [...(l['images'] as List).cast<String>()],
            note: l['note_ar'] as String?,
          ),
      ],
    );
  }

  final Part part;
  final Fit? fit;
  final JobType? jobType;
  final LocalizedText? fitmentNote;

  /// In stock first, then cheapest.
  final List<ShopOffer> offers;
}

/// Reads the public catalogue: offline snapshot, search, part pages, settings. Search
/// results and part pages are kept in [cache] for browsing without a connection.
class CatalogueRepository with CachedReads {
  CatalogueRepository(this._client, {this.cache});

  final SupabaseClient _client;
  @override
  final ReadCache? cache;

  Future<CatalogueSnapshot> snapshot({DateTime? since}) =>
      snapshotJson(since: since).then(CatalogueSnapshot.fromJson);

  /// The raw answer, for the offline cache to merge (`LiveCatalogue`).
  Future<Json> snapshotJson({DateTime? since}) => guard(
    () => _client.rpc<Json>(
      'catalogue_snapshot',
      params: {'p_since': since?.toUtc().toIso8601String()},
    ),
  );

  Future<SearchPage> search(
    SearchQuery q, {
    int limit = 30,
    int offset = 0,
    String? shopId,
    bool dealsOnly = false,
  }) {
    final params = {
      'p_q': q.text,
      'p_variant_id': q.variantId,
      'p_category_id': q.categoryId,
      'p_only_fits': q.onlyFits,
      'p_conditions': q.conditions.isEmpty ? null : [for (final c in q.conditions) c.code],
      'p_price_max': q.maxPriceSdg,
      'p_shop_id': shopId,
      'p_in_stock_only': q.inStockOnly,
      'p_deals_only': dealsOnly,
      'p_sort': dealsOnly && q.sort == SearchSort.relevance ? 'discount' : _sort(q.sort),
      'p_limit': limit,
      'p_offset': offset,
    };
    return cachedRead(
      'search:${jsonEncode(params)}',
      () => _client.rpc<List<dynamic>>('search_parts', params: params),
      (raw) {
        final rows = (raw! as List).cast<Json>();
        final results = [for (final r in rows) PartResult.fromJson(r)];
        final total = rows.isEmpty ? 0 : rows.first['total_count'] as int;
        return SearchPage(results, total);
      },
    );
  }

  Future<PartDetail> partDetail(String partId, {String? variantId}) => cachedRead(
    'part:$partId:${variantId ?? ''}',
    () =>
        _client.rpc<Json>('part_detail', params: {'p_part_id': partId, 'p_variant_id': variantId}),
    (raw) => PartDetail.fromJson(raw! as Json),
  );

  /// The shops that tint this car size and these windows, cheapest first (D-149).
  /// Works for guests too.
  Future<TintOffers> tintOffers(TintCarSize size, TintSelection selection) => cachedRead(
    'tint:${size.code}:${selection.package?.code ?? selection.windowCodes.join(',')}',
    () => _client.rpc<Json>(
      'tint_offers',
      params: {
        'p_car_size': size.code,
        'p_package': selection.package?.code,
        'p_windows': selection.package == null ? selection.windowCodes : null,
      },
    ),
    (raw) => TintOffers.fromJson(raw! as Json),
  );

  Future<PlatformSettings> settings() => settingsJson().then(PlatformSettings.fromJson);

  Future<Json> settingsJson() => guard(() => _client.rpc<Json>('public_settings'));

  static String _sort(SearchSort s) => switch (s) {
    SearchSort.relevance => 'relevance',
    SearchSort.priceLow => 'price_low',
    SearchSort.priceHigh => 'price_high',
    SearchSort.rating => 'rating',
  };
}
