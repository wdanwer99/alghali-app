import 'package:alghali_core/alghali_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The shops that tint this car size and these windows, cheapest first (D-149).
final tintOffersProvider = FutureProvider.autoDispose
    .family<TintOffers, (TintCarSize, TintSelection)>(
      (ref, q) => ref.watch(catalogueRepositoryProvider).tintOffers(q.$1, q.$2),
    );
