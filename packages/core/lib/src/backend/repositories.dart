import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_repository.dart';
import 'catalogue_repository.dart';
import 'garage_repository.dart';
import 'shop_repository.dart';

/// The Supabase client set up by [initBackend]. Tests override this with a client
/// that talks to a fake HTTP server.
final supabaseClientProvider = Provider<SupabaseClient>((ref) => Supabase.instance.client);

final authRepositoryProvider = Provider((ref) => AuthRepository(ref.watch(supabaseClientProvider)));
final catalogueRepositoryProvider = Provider(
  (ref) => CatalogueRepository(ref.watch(supabaseClientProvider)),
);
final garageRepositoryProvider = Provider(
  (ref) => GarageRepository(ref.watch(supabaseClientProvider)),
);
final shopRepositoryProvider = Provider((ref) => ShopRepository(ref.watch(supabaseClientProvider)));
