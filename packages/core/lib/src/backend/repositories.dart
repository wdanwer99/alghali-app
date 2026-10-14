import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_repository.dart';
import 'bookings_repository.dart';
import 'catalogue_repository.dart';
import 'chat_repository.dart';
import 'garage_repository.dart';
import 'orders_repository.dart';
import 'requests_repository.dart';
import 'shop_repository.dart';
import 'technician_repository.dart';

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
final ordersRepositoryProvider = Provider(
  (ref) => OrdersRepository(ref.watch(supabaseClientProvider)),
);
final requestsRepositoryProvider = Provider(
  (ref) => RequestsRepository(ref.watch(supabaseClientProvider)),
);
final chatRepositoryProvider = Provider((ref) => ChatRepository(ref.watch(supabaseClientProvider)));
final notificationsRepositoryProvider = Provider(
  (ref) => NotificationsRepository(ref.watch(supabaseClientProvider)),
);
final bookingsRepositoryProvider = Provider(
  (ref) => BookingsRepository(ref.watch(supabaseClientProvider)),
);
final technicianRepositoryProvider = Provider(
  (ref) => TechnicianRepository(ref.watch(supabaseClientProvider)),
);
