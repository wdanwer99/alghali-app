import 'package:alghali_core/alghali_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'session.dart';

/// Search results (`search_parts`), at most 30 at a time; saved for browsing offline.
final partSearchProvider = FutureProvider.autoDispose.family<SearchPage, SearchQuery>((ref, q) {
  if (!ref.watch(backendReadyProvider)) return const SearchPage([], 0);
  return ref.watch(catalogueRepositoryProvider).search(q);
});

/// Price cuts on parts that fit the buyer's car (or any car), biggest first.
final dealsProvider = FutureProvider.autoDispose.family<List<PartResult>, String?>((
  ref,
  variantId,
) async {
  if (!ref.watch(backendReadyProvider)) return const [];
  final page = await ref
      .watch(catalogueRepositoryProvider)
      .search(SearchQuery(variantId: variantId), dealsOnly: true, limit: 12);
  return page.results;
});

/// One part, every shop that sells it, and the fit verdict for the buyer's car.
final partDetailProvider = FutureProvider.autoDispose
    .family<PartDetail, ({String partId, String? variantId})>(
      (ref, k) =>
          ref.watch(catalogueRepositoryProvider).partDetail(k.partId, variantId: k.variantId),
    );

/// A shop's parts (search limited to the shop).
final shopPartsProvider = FutureProvider.autoDispose
    .family<SearchPage, ({String shopId, String? variantId})>(
      (ref, k) => ref
          .watch(catalogueRepositoryProvider)
          .search(SearchQuery(variantId: k.variantId), shopId: k.shopId, limit: 50),
    );

/// A shop's visible reviews, newest first.
final shopReviewsProvider = FutureProvider.autoDispose.family<List<Review>, String>(
  (ref, shopId) => ref.watch(bookingsRepositoryProvider).reviews(shopId: shopId),
);
