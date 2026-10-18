import 'dart:async';

import 'package:alghali_core/alghali_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What the buyer can do without a connection (D-112): these changes wait in the outbox
/// and go out in order when the phone is back online. Everything that must be checked
/// at once — checkout, holding a fitting time, receipts with a photo, photo requests,
/// voice notes — needs a connection and says so.
abstract final class BuyerOps {
  /// `{listing_id | offer_id | tint_shop_id + tint, qty, seen_price_sdg}`: the server copy
  /// of a cart line.
  static const cartPut = 'cart.put';

  /// `{listing_id | offer_id | tint_shop_id}`.
  static const cartRemove = 'cart.remove';

  /// `{id, variant_id, is_default}`: the app picks the id, so a replay can't add twice.
  static const garageAdd = 'garage.add';
  static const garageRemove = 'garage.remove';
  static const garageDefault = 'garage.default';

  /// `{id, conversation_id, body}`.
  static const chatSend = 'chat.send';

  /// `{ids}`; null ids marks everything read.
  static const inboxRead = 'inbox.read';

  /// `{rating, sub_order_id | booking_id, comment}`; rating again changes the review.
  static const review = 'review';

  /// `{display_name?, phone?, locale?, data_saver?}`.
  static const profile = 'profile';
}

Map<String, OutboxHandler> buyerOutboxHandlers(Ref ref) {
  final client = ref.read(supabaseClientProvider);
  Future<void> run(Future<Object?> Function() call) => guard(call);

  Future<void> dropCartLine(Json p) => run(() {
    final q = client.from('cart_items').delete();
    if (p['tint_shop_id'] != null) {
      // One tint line per cart (D-149): a new one replaces whichever shop it was from.
      return q.not('tint_shop_id', 'is', null);
    }
    return p['listing_id'] != null
        ? q.eq('listing_id', p['listing_id'] as String)
        : q.eq('offer_id', p['offer_id'] as String);
  });

  return {
    BuyerOps.cartPut: (p, _) async {
      // A partial unique index can't take an upsert, so replace the line.
      await dropCartLine(p);
      await run(
        () => client.from('cart_items').insert({
          'listing_id': p['listing_id'],
          'offer_id': p['offer_id'],
          if (p['tint_shop_id'] != null) ...{'tint_shop_id': p['tint_shop_id'], 'tint': p['tint']},
          'qty': p['qty'],
          'seen_price_sdg': p['seen_price_sdg'],
        }),
      );
    },
    BuyerOps.cartRemove: (p, _) => dropCartLine(p),
    BuyerOps.garageAdd: (p, _) async {
      try {
        await ref
            .read(garageRepositoryProvider)
            .add(
              id: p['id'] as String,
              variantId: p['variant_id'] as String,
              makeDefault: p['is_default'] as bool? ?? false,
            );
      } on BackendException catch (e) {
        if (!e.duplicate) rethrow;
      }
    },
    BuyerOps.garageRemove: (p, _) => ref.read(garageRepositoryProvider).remove(p['id'] as String),
    BuyerOps.garageDefault: (p, _) =>
        ref.read(garageRepositoryProvider).makeDefault(p['id'] as String),
    BuyerOps.chatSend: (p, _) async {
      try {
        await ref
            .read(chatRepositoryProvider)
            .send(p['conversation_id'] as String, p['body'] as String, id: p['id'] as String);
      } on BackendException catch (e) {
        if (!e.duplicate) rethrow;
      }
    },
    BuyerOps.inboxRead: (p, _) =>
        ref.read(notificationsRepositoryProvider).markRead((p['ids'] as List?)?.cast<String>()),
    BuyerOps.review: (p, _) => ref
        .read(bookingsRepositoryProvider)
        .review(
          rating: p['rating'] as int,
          subOrderId: p['sub_order_id'] as String?,
          bookingId: p['booking_id'] as String?,
          comment: p['comment'] as String?,
        ),
    BuyerOps.profile: (p, _) => ref
        .read(authRepositoryProvider)
        .updateProfile(
          displayName: p['display_name'] as String?,
          phone: p['phone'] as String?,
          locale: p['locale'] as String?,
          dataSaver: p['data_saver'] as bool?,
        ),
  };
}

/// The buyer's outbox, or null without a database (widget tests that don't need it).
final outboxProvider = Provider<Outbox?>((ref) {
  final db = ref.watch(appDatabaseOrNullProvider);
  if (db == null) return null;
  final outbox = Outbox(db, handlers: buyerOutboxHandlers(ref), clock: ref.watch(clockProvider));
  ref.onDispose(outbox.dispose);
  Future.microtask(outbox.flush);
  return outbox;
});

/// How many changes are waiting for a connection.
final outboxPendingProvider = StreamProvider<int>((ref) {
  final outbox = ref.watch(outboxProvider);
  if (outbox == null) return Stream.value(0);
  final controller = StreamController<int>();
  void push() => controller.add(outbox.pending.value);
  outbox.pending.addListener(push);
  push();
  ref.onDispose(() {
    outbox.pending.removeListener(push);
    unawaited(controller.close());
  });
  return controller.stream;
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
  final handler = buyerOutboxHandlers(ref)[op]!;
  await handler(payload, newIdempotencyKey());
}
