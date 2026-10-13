import 'package:flutter/foundation.dart' show immutable;

import '../models/catalogue.dart';

/// What the apps cache for offline use, from `catalogue_snapshot(since)`:
/// vehicles, job types, categories, the street's zones and its approved shops.
///
/// A delta ([full] false) holds only rows changed since the last sync. Deactivated
/// rows come back with `is_active: false`, and shops that are no longer approved as
/// [removedShopIds], so the cache can drop them.
@immutable
class CatalogueSnapshot {
  const CatalogueSnapshot({
    required this.serverTime,
    required this.full,
    required this.makes,
    required this.models,
    required this.variants,
    required this.jobTypes,
    required this.categories,
    required this.zones,
    required this.shops,
    this.removedShopIds = const <String>{},
    this.inactiveIds = const <String>{},
  });

  factory CatalogueSnapshot.fromJson(Json j) {
    List<Json> rows(String key) => (j[key] as List).cast<Json>();
    bool active(Json r) => r['is_active'] as bool? ?? true;

    final jobTypes = <String, JobType>{
      for (final r in rows('job_types')) r['id'] as String: ?JobType.fromCode(r['code'] as String?),
    };
    final inactive = <String>{
      for (final key in ['makes', 'models', 'variants', 'categories', 'zones'])
        for (final r in rows(key))
          if (!active(r)) r['id'] as String,
    };
    final shops = rows('shops');
    return CatalogueSnapshot(
      serverTime: DateTime.parse(j['server_time'] as String),
      full: j['full'] as bool,
      makes: [for (final r in rows('makes').where(active)) VehicleMake.fromJson(r)],
      models: [for (final r in rows('models').where(active)) VehicleModel.fromJson(r)],
      variants: [for (final r in rows('variants').where(active)) VehicleVariant.fromJson(r)],
      jobTypes: jobTypes,
      categories: [
        for (final r in rows('categories').where(active)) PartCategory.fromJson(r, jobTypes),
      ],
      zones: [for (final r in rows('zones').where(active)) Zone.fromJson(r)],
      shops: [
        for (final s in shops)
          if (s['status'] == 'APPROVED') Shop.fromJson(s),
      ],
      removedShopIds: {
        for (final s in shops)
          if (s['status'] != 'APPROVED') s['id'] as String,
      },
      inactiveIds: inactive,
    );
  }

  /// Send this back as `since` on the next sync.
  final DateTime serverTime;
  final bool full;
  final List<VehicleMake> makes;
  final List<VehicleModel> models;
  final List<VehicleVariant> variants;

  /// `job_types.id` → [JobType], for reading categories and technician skills.
  final Map<String, JobType> jobTypes;
  final List<PartCategory> categories;
  final List<Zone> zones;
  final List<Shop> shops;
  final Set<String> removedShopIds;
  final Set<String> inactiveIds;
}
