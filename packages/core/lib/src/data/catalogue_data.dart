import 'package:flutter/foundation.dart' show immutable;

import '../models/catalogue.dart';
import 'arabic.dart';

enum SearchSort { relevance, priceLow, priceHigh, rating }

@immutable
class SearchQuery {
  const SearchQuery({
    this.text = '',
    this.categoryId,
    this.variantId,
    this.onlyFits = false,
    this.conditions = const {},
    this.maxPriceSdg,
    this.inStockOnly = true,
    this.sort = SearchSort.relevance,
  });

  final String text;
  final String? categoryId;

  /// The buyer's selected car; parts known not to fit it are left out.
  final String? variantId;

  /// Hide parts without fitment data too ("only parts that fit my car").
  final bool onlyFits;
  final Set<ListingCondition> conditions;
  final int? maxPriceSdg;
  final bool inStockOnly;
  final SearchSort sort;

  bool get hasFilters => conditions.isNotEmpty || maxPriceSdg != null || onlyFits;

  SearchQuery copyWith({
    String? text,
    String? Function()? categoryId,
    String? Function()? variantId,
    bool? onlyFits,
    Set<ListingCondition>? conditions,
    int? Function()? maxPriceSdg,
    SearchSort? sort,
  }) => SearchQuery(
    text: text ?? this.text,
    categoryId: categoryId == null ? this.categoryId : categoryId(),
    variantId: variantId == null ? this.variantId : variantId(),
    onlyFits: onlyFits ?? this.onlyFits,
    conditions: conditions ?? this.conditions,
    maxPriceSdg: maxPriceSdg == null ? this.maxPriceSdg : maxPriceSdg(),
    inStockOnly: inStockOnly,
    sort: sort ?? this.sort,
  );

  @override
  bool operator ==(Object other) =>
      other is SearchQuery &&
      other.text == text &&
      other.categoryId == categoryId &&
      other.variantId == variantId &&
      other.onlyFits == onlyFits &&
      other.conditions.length == conditions.length &&
      other.conditions.containsAll(conditions) &&
      other.maxPriceSdg == maxPriceSdg &&
      other.sort == sort;

  @override
  int get hashCode => Object.hash(
    text,
    categoryId,
    variantId,
    onlyFits,
    Object.hashAllUnordered(conditions),
    maxPriceSdg,
    sort,
  );
}

/// One part in search results, with the shops that sell it (cheapest first).
@immutable
class PartResult {
  const PartResult({
    required this.part,
    required this.fit,
    required this.listings,
    this._shopCount,
  });

  /// A `search_parts` row. The server sends at most 5 offers per part, so the
  /// shop count comes from the server rather than from [listings].
  factory PartResult.fromJson(Json j) {
    final part = Part.fromJson(j);
    return PartResult(
      part: part,
      fit: Fit.fromCode(j['fit'] as String?),
      listings: [
        for (final l in (j['listings'] as List).cast<Json>()) Listing.fromJson(l, partId: part.id),
      ],
      shopCount: j['shop_count'] as int?,
    );
  }

  final Part part;
  final Fit? fit;
  final List<Listing> listings;
  final int? _shopCount;

  int get fromSdg => listings.first.priceSdg;
  int get shopCount => _shopCount ?? listings.map((l) => l.shopId).toSet().length;
  Set<ListingCondition> get conditions => listings.map((l) => l.condition).toSet();
  int get bestWarrantyDays => listings.fold(0, (m, l) => l.warrantyDays > m ? l.warrantyDays : m);
}

/// Everything the apps show from the catalogue: cars, categories, parts,
/// the street and its shops, listings and technicians. In the real app this
/// is the cached `catalogue_snapshot` plus search RPCs; today it is sample data.
class CatalogueData {
  CatalogueData({
    required this.makes,
    required this.models,
    required this.variants,
    required this.categories,
    required this.parts,
    required this.zones,
    required this.shops,
    required this.listings,
    required this.technicians,
    required this.reviews,
    required List<List<String>> synonyms,
  }) : _synonyms = [
         for (final group in synonyms) {for (final w in group) ...searchTerms(w)},
       ];

  final List<VehicleMake> makes;
  final List<VehicleModel> models;
  final List<VehicleVariant> variants;
  final List<PartCategory> categories;
  final List<Part> parts;
  final List<Zone> zones;
  final List<Shop> shops;
  final List<Listing> listings;
  final List<Technician> technicians;
  final List<Review> reviews;
  final List<Set<String>> _synonyms;

  late final _makes = {for (final x in makes) x.id: x};
  late final _models = {for (final x in models) x.id: x};
  late final _variants = {for (final x in variants) x.id: x};
  late final _categories = {for (final x in categories) x.id: x};
  late final _parts = {for (final x in parts) x.id: x};
  late final _zones = {for (final x in zones) x.id: x};
  late final _shops = {for (final x in shops) x.id: x};
  late final _listings = {for (final x in listings) x.id: x};
  late final _technicians = {for (final x in technicians) x.id: x};

  VehicleMake make(String id) => _makes[id]!;
  VehicleModel model(String id) => _models[id]!;
  VehicleVariant variant(String id) => _variants[id]!;
  PartCategory category(String id) => _categories[id]!;
  Part part(String id) => _parts[id]!;
  Zone zone(String id) => _zones[id]!;
  Shop shop(String id) => _shops[id]!;
  Listing listing(String id) => _listings[id]!;
  Technician technician(String id) => _technicians[id]!;

  List<VehicleModel> modelsOf(String makeId) => models.where((m) => m.makeId == makeId).toList();
  List<VehicleVariant> variantsOf(String modelId) =>
      variants.where((v) => v.modelId == modelId).toList();

  VehicleModel modelOfVariant(String variantId) => model(variant(variantId).modelId);
  VehicleMake makeOfVariant(String variantId) => make(modelOfVariant(variantId).makeId);

  /// Null when no car is selected.
  Fit? fitOf(Part part, String? variantId) {
    if (variantId == null) return null;
    final fitment = part.fitment;
    if (fitment == null) return Fit.check;
    return fitment.contains(variantId) ? Fit.fits : Fit.noFit;
  }

  List<Listing> listingsOf(String partId) =>
      listings.where((l) => l.partId == partId).toList()
        ..sort((a, b) => a.priceSdg.compareTo(b.priceSdg));

  List<Listing> shopListings(String shopId) => listings.where((l) => l.shopId == shopId).toList();

  List<Shop> shopsIn(String zoneId) =>
      shops.where((s) => s.zoneId == zoneId).toList()..sort((a, b) => a.posM.compareTo(b.posM));

  List<Review> reviewsOfShop(String shopId) => reviews.where((r) => r.shopId == shopId).toList();
  List<Review> reviewsOfTechnician(String id) =>
      reviews.where((r) => r.technicianId == id).toList();

  /// Price-cut listings for parts that fit [variantId] (or any car when null).
  List<Listing> deals(String? variantId) {
    final out = listings.where((l) {
      if (l.discountPercent == null || !l.inStock) return false;
      final fit = fitOf(part(l.partId), variantId);
      return fit == null || fit == Fit.fits;
    }).toList();
    out.sort((a, b) => b.discountPercent!.compareTo(a.discountPercent!));
    return out;
  }

  List<PartResult> search(SearchQuery q) {
    final terms = searchTerms(q.text);
    final scored = <(PartResult, int)>[];
    for (final p in parts) {
      if (q.categoryId != null && p.categoryId != q.categoryId) continue;
      final fit = fitOf(p, q.variantId);
      if (fit == Fit.noFit) continue;
      if (q.onlyFits && fit != Fit.fits) continue;
      final score = terms.isEmpty ? 1 : _score(p, terms);
      if (score == 0) continue;

      final offers = listingsOf(p.id).where((l) {
        if (q.inStockOnly && !l.inStock) return false;
        if (q.conditions.isNotEmpty && !q.conditions.contains(l.condition)) return false;
        if (q.maxPriceSdg != null && l.priceSdg > q.maxPriceSdg!) return false;
        return true;
      }).toList();
      if (offers.isEmpty) continue;
      scored.add((PartResult(part: p, fit: fit, listings: offers), score));
    }

    double rating(PartResult r) => r.listings.fold(0, (m, l) {
      final s = shop(l.shopId).rating;
      return s > m ? s : m;
    });
    scored.sort(
      (a, b) => switch (q.sort) {
        SearchSort.relevance => _byFitThen(a, b, () => b.$2.compareTo(a.$2)),
        SearchSort.priceLow => a.$1.fromSdg.compareTo(b.$1.fromSdg),
        SearchSort.priceHigh => b.$1.fromSdg.compareTo(a.$1.fromSdg),
        SearchSort.rating => rating(b.$1).compareTo(rating(a.$1)),
      },
    );
    return [for (final s in scored) s.$1];
  }

  int _byFitThen((PartResult, int) a, (PartResult, int) b, int Function() then) {
    final fa = a.$1.fit == Fit.fits ? 0 : 1;
    final fb = b.$1.fit == Fit.fits ? 0 : 1;
    return fa != fb ? fa.compareTo(fb) : then();
  }

  late final Map<String, List<String>> _docs = {
    for (final p in parts)
      p.id: {
        ...searchTerms(p.name.ar),
        ...searchTerms(p.name.en),
        ...searchTerms(category(p.categoryId).name.ar),
        ...searchTerms(category(p.categoryId).name.en),
        for (final k in p.keywords) ...searchTerms(k),
        for (final n in p.oemNumbers) n.replaceAll('-', '').toLowerCase(),
      }.toList(),
  };

  /// 0 when some query term matches nothing; otherwise higher is better.
  /// A term matches a document word it prefixes, directly or via a synonym.
  int _score(Part p, List<String> terms) {
    final doc = _docs[p.id]!;
    var score = 0;
    for (final term in terms) {
      final alternatives = {term.replaceAll('-', '')};
      for (final group in _synonyms) {
        if (group.any((w) => w.startsWith(term) || (term.length >= 3 && term.startsWith(w)))) {
          alternatives.addAll(group);
        }
      }
      var best = 0;
      for (final word in doc) {
        for (final alt in alternatives) {
          if (word == alt) {
            best = 3;
          } else if (word.startsWith(alt) && best < 2) {
            best = 2;
          }
        }
      }
      if (best == 0) return 0;
      score += best;
    }
    return score;
  }
}
