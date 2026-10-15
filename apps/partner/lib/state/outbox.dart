import 'dart:async';
import 'dart:typed_data';

import 'package:alghali_core/alghali_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What a partner can do without a connection (D-122): these changes wait in the outbox
/// and go out in order when the phone is back online. Order and job steps (accept, ready,
/// hand over, on my way, the buyer's code) must be checked at once and need a connection.
abstract final class PartnerOps {
  /// `{shop_id, items: [{listing_id, version, price_sdg?, stock_qty?, is_active?}]}`: one
  /// listing's quick edit or a bulk price change, through `shop_bulk_update`.
  static const stockEdit = 'stock.edit';

  /// `{shop_id, local_id, params, photo_path?}`: a quick listing. [params] is the
  /// `ListingDraft.toParams`; the photo waits on the phone and goes up first, under
  /// `local_id`, so a replay overwrites the same files.
  static const listingCreate = 'listing.create';

  /// `{id, conversation_id, body}`.
  static const chatSend = 'chat.send';

  /// `{ids}`.
  static const inboxRead = 'inbox.read';

  /// `{display_name?, phone?, locale?}`.
  static const profile = 'profile';
}

/// Where a queued listing's photo waits until it is uploaded, and how it is sized (D-008).
/// Tests swap it for one in memory: both need the phone's plugins.
class PhotoStore {
  const PhotoStore();

  Future<String> keep(Uint8List jpeg, String name) => Media.keep(jpeg, name);
  Future<Uint8List?> read(String path) => Media.read(path);
  Future<void> forget(String path) => Media.forget(path);
  Future<MediaVariants> variants(Uint8List jpeg) => Media.variants(jpeg);
}

final photoStoreProvider = Provider<PhotoStore>((ref) => const PhotoStore());

Map<String, OutboxHandler> partnerOutboxHandlers(Ref ref) => {
  PartnerOps.stockEdit: (p, idem) async {
    final results = await ref.read(shopRepositoryProvider).bulkUpdate(p['shop_id'] as String, [
      for (final i in (p['items'] as List).cast<Json>())
        BulkEdit(
          listingId: i['listing_id'] as String,
          version: i['version'] as int,
          priceSdg: i['price_sdg'] as int?,
          stockQty: i['stock_qty'] as int?,
          active: i['is_active'] as bool?,
        ),
    ], idem: idem);
    // Each line succeeds or fails alone; tell the shop about the first refusal.
    final failed = results.where((r) => !r.ok).firstOrNull;
    if (failed != null) throw BackendException(failed.error ?? 'UNKNOWN', status: 409);
  },
  PartnerOps.listingCreate: (p, idem) async {
    final repo = ref.read(shopRepositoryProvider);
    final photos = ref.read(photoStoreProvider);
    final shopId = p['shop_id'] as String;
    final path = p['photo_path'] as String?;
    String? photo;
    final bytes = path == null ? null : await photos.read(path);
    if (bytes != null) {
      photo = await repo.uploadListingPhoto(
        shopId,
        await photos.variants(bytes),
        id: p['local_id'] as String,
      );
    }
    final listing = await repo.saveListing(
      shopId,
      ListingDraft.fromParams(p['params'] as Json),
      idem: idem,
    );
    if (photo != null) await repo.setListingImages(shopId, listing.id, [photo]);
    if (path != null) await photos.forget(path);
  },
  PartnerOps.chatSend: (p, _) async {
    try {
      await ref
          .read(chatRepositoryProvider)
          .send(p['conversation_id'] as String, p['body'] as String, id: p['id'] as String);
    } on BackendException catch (e) {
      if (!e.duplicate) rethrow;
    }
  },
  PartnerOps.inboxRead: (p, _) =>
      ref.read(notificationsRepositoryProvider).markRead((p['ids'] as List).cast<String>()),
  PartnerOps.profile: (p, _) => ref
      .read(authRepositoryProvider)
      .updateProfile(
        displayName: p['display_name'] as String?,
        phone: p['phone'] as String?,
        locale: p['locale'] as String?,
      ),
};

/// The partner's outbox, or null without a database (widget tests that don't need it).
final outboxProvider = Provider<Outbox?>((ref) {
  final db = ref.watch(appDatabaseOrNullProvider);
  if (db == null) return null;
  final outbox = Outbox(db, handlers: partnerOutboxHandlers(ref), clock: ref.watch(clockProvider));
  ref.onDispose(outbox.dispose);
  Future.microtask(outbox.flush);
  return outbox;
});

/// [queue] for widgets: `ref.read(queueProvider)(op, payload)`.
final queueProvider = Provider<Future<void> Function(String op, Json payload)>(
  (ref) =>
      (op, payload) => queue(ref, op, payload),
);

/// Queues [op], or runs it straight away when there is no outbox (tests).
Future<void> queue(Ref ref, String op, Json payload) async {
  final outbox = ref.read(outboxProvider);
  if (outbox != null) return outbox.add(op, payload);
  final handler = partnerOutboxHandlers(ref)[op]!;
  await handler(payload, newIdempotencyKey());
}

/// Outbox results as they happen (empty without an outbox).
final outboxResultsProvider = Provider<Stream<OutboxResult>>(
  (ref) => ref.watch(outboxProvider)?.results ?? const Stream.empty(),
);
