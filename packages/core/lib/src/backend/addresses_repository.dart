import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/catalogue.dart';
import 'backend_error.dart';
import 'read_cache.dart';

/// The buyer's saved places (`addresses`), written directly under row level security: a
/// GPS point, a label and written directions; at most 10, one of them the default.
class AddressesRepository with CachedReads {
  AddressesRepository(this._client, {this.cache});

  final SupabaseClient _client;
  @override
  final ReadCache? cache;

  SupabaseQueryBuilder get _table => _client.from('addresses');

  /// Rows of `addresses`, the default first.
  Future<List<Json>> list() => cachedRead(
    '@addresses',
    () => _table.select().order('is_default', ascending: false).order('created_at'),
    (raw) => (raw! as List).cast<Json>(),
  );

  Future<Json> add({
    required String label,
    required String description,
    required double lat,
    required double lng,
    bool makeDefault = false,
  }) => guard(
    () => _table
        .insert({
          'label': label.trim(),
          'description_ar': description.trim().isEmpty ? null : description.trim(),
          'lat': lat,
          'lng': lng,
          if (makeDefault) 'is_default': true,
        })
        .select()
        .single(),
  );

  Future<void> remove(String id) => guard(() => _table.delete().eq('id', id));
}
