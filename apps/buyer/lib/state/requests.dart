import 'dart:async';

import 'package:alghali_core/alghali_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'connection.dart';
import 'session.dart';

/// Photo requests (PLAN §3.5): the buyer's requests with every shop's offer.
class RequestsController extends AsyncNotifier<List<PartRequest>>
    with CachedList<List<PartRequest>> {
  @override
  Future<List<PartRequest>> build() async {
    final uid = ref.watch(sessionProvider.select((s) => s.userId));
    if (uid == null) return const [];
    return load();
  }

  RequestsRepository get _repo => ref.read(requestsRepositoryProvider);

  @override
  Future<List<PartRequest>> fetch() => _repo.mine();

  PartRequest? byId(String id) => state.value?.where((r) => r.id == id).firstOrNull;

  /// Uploads the photos and opens the request; needs a connection.
  Future<PartRequest> create({
    required String note,
    required List<PickedPhoto> photos,
    String? variantId,
    String? categoryId,
    required String idem,
  }) async {
    final r = await _repo.create(
      note: note,
      variantId: variantId,
      categoryId: categoryId,
      photos: [for (final p in photos) (bytes: p.bytes, fileName: p.fileName)],
      idem: idem,
    );
    state = AsyncData([r, ...?state.value]);
    return r;
  }

  Future<void> close(String id) async {
    await _repo.close(id);
    await refresh();
  }
}

final requestsProvider = AsyncNotifierProvider<RequestsController, List<PartRequest>>(
  RequestsController.new,
);

/// Hour-long links to a request's photos (keys joined by new lines).
final requestPhotoUrlsProvider = FutureProvider.autoDispose.family<Map<String, String>, String>((
  ref,
  keys,
) {
  final list = keys.isEmpty ? const <String>[] : keys.split('\n');
  return ref.watch(requestsRepositoryProvider).photoUrls(list);
});
