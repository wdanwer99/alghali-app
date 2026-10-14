import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/catalogue.dart';
import 'backend_error.dart';
import 'read_cache.dart';

/// The buyer's saved cars, written directly under row level security. The server keeps
/// one default car, cleans up the VIN and allows at most 10 cars (GARAGE_FULL).
class GarageRepository with CachedReads {
  GarageRepository(this._client, {this.cache});

  final SupabaseClient _client;
  @override
  final ReadCache? cache;

  SupabaseQueryBuilder get _table => _client.from('garage_vehicles');

  Future<List<GarageVehicle>> list() => cachedRead(
    '@garage',
    () => _table.select().order('is_default', ascending: false).order('created_at'),
    (raw) => [for (final r in (raw! as List).cast<Json>()) GarageVehicle.fromJson(r)],
  );

  /// [id] may be chosen by the app, so a replay from the outbox can't add the car twice.
  Future<GarageVehicle> add({
    String? id,
    required String variantId,
    String? nickname,
    String? vin,
    String? plate,
    bool makeDefault = false,
  }) => guard(() async {
    final row = await _table
        .insert({
          'id': ?id,
          'variant_id': variantId,
          'nickname': nickname,
          'vin': vin,
          'plate': plate,
          if (makeDefault) 'is_default': true,
        })
        .select()
        .single();
    return GarageVehicle.fromJson(row);
  });

  Future<void> makeDefault(String id) =>
      guard(() => _table.update({'is_default': true}).eq('id', id));

  Future<void> rename(String id, String? nickname) =>
      guard(() => _table.update({'nickname': nickname}).eq('id', id));

  Future<void> remove(String id) => guard(() => _table.delete().eq('id', id));
}
