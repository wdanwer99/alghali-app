import 'package:alghali_core/alghali_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'session.dart';

/// Complaints the partner is part of (D-105, D-131): ones a buyer opened about the shop's
/// order or the technician's job, and ones the partner opened. Newest first.
class ComplaintsController extends AsyncNotifier<List<Dispute>> with CachedList<List<Dispute>> {
  @override
  Future<List<Dispute>> build() async {
    final uid = ref.watch(partnerSessionProvider.select((s) => s.userId));
    if (uid == null) return const [];
    return load();
  }

  BookingsRepository get _repo => ref.read(bookingsRepositoryProvider);

  @override
  Future<List<Dispute>> fetch() => _repo.disputes();

  /// About one of the shop's sub-orders or one of the technician's jobs. Needs a connection.
  Future<Dispute> open({
    required DisputeCategory category,
    required String description,
    String? subOrderId,
    String? bookingId,
  }) async {
    final d = await _repo.openDispute(
      category: category,
      description: description,
      subOrderId: subOrderId,
      bookingId: bookingId,
    );
    state = AsyncData([d, ...?state.value]);
    return d;
  }

  Future<Dispute> reply(String id, String body) async {
    final d = await _repo.replyDispute(id, body);
    state = AsyncData([for (final x in state.value ?? const <Dispute>[]) x.id == id ? d : x]);
    return d;
  }
}

final complaintsProvider = AsyncNotifierProvider<ComplaintsController, List<Dispute>>(
  ComplaintsController.new,
);

/// Complaints still waiting for a decision.
final openComplaintsProvider = Provider<int>(
  (ref) =>
      (ref.watch(complaintsProvider).value ?? const <Dispute>[]).where((d) => !d.closed).length,
);
