import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'addresses_repository.dart';
import 'auth_repository.dart';
import 'bookings_repository.dart';
import 'catalogue_repository.dart';
import 'chat_repository.dart';
import 'garage_repository.dart';
import 'orders_repository.dart';
import 'read_cache.dart';
import 'requests_repository.dart';
import 'shop_repository.dart';
import 'technician_repository.dart';

/// The Supabase client set up by [initBackend]. Tests override this with a client
/// that talks to a fake HTTP server.
final supabaseClientProvider = Provider<SupabaseClient>((ref) => Supabase.instance.client);

final authRepositoryProvider = Provider((ref) => AuthRepository(ref.watch(supabaseClientProvider)));
final catalogueRepositoryProvider = Provider(
  (ref) =>
      CatalogueRepository(ref.watch(supabaseClientProvider), cache: ref.watch(readCacheProvider)),
);
final garageRepositoryProvider = Provider(
  (ref) => GarageRepository(ref.watch(supabaseClientProvider), cache: ref.watch(readCacheProvider)),
);
final addressesRepositoryProvider = Provider(
  (ref) =>
      AddressesRepository(ref.watch(supabaseClientProvider), cache: ref.watch(readCacheProvider)),
);
final shopRepositoryProvider = Provider((ref) => ShopRepository(ref.watch(supabaseClientProvider)));
final ordersRepositoryProvider = Provider(
  (ref) => OrdersRepository(ref.watch(supabaseClientProvider), cache: ref.watch(readCacheProvider)),
);
final requestsRepositoryProvider = Provider(
  (ref) =>
      RequestsRepository(ref.watch(supabaseClientProvider), cache: ref.watch(readCacheProvider)),
);
final chatRepositoryProvider = Provider(
  (ref) => ChatRepository(ref.watch(supabaseClientProvider), cache: ref.watch(readCacheProvider)),
);
final notificationsRepositoryProvider = Provider(
  (ref) => NotificationsRepository(
    ref.watch(supabaseClientProvider),
    cache: ref.watch(readCacheProvider),
  ),
);
final bookingsRepositoryProvider = Provider(
  (ref) =>
      BookingsRepository(ref.watch(supabaseClientProvider), cache: ref.watch(readCacheProvider)),
);
final technicianRepositoryProvider = Provider(
  (ref) => TechnicianRepository(ref.watch(supabaseClientProvider)),
);
