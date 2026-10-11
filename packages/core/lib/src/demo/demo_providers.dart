import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/catalogue_data.dart';
import '../settings/app_settings.dart';
import 'demo_catalogue.dart';

/// The catalogue the apps read. Sample data for now; in M4 this becomes the
/// cached `catalogue_snapshot` from Supabase behind the same type.
final catalogueProvider = Provider<CatalogueData>(
  (ref) => buildDemoCatalogue(ref.watch(clockProvider)()),
);

/// Search results; async so screens already handle loading and errors the
/// way they will against the `search_listings` RPC.
final searchProvider = FutureProvider.family<List<PartResult>, SearchQuery>(
  (ref, query) async => ref.watch(catalogueProvider).search(query),
);
