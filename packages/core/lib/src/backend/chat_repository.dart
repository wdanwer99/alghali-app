import 'dart:async';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/catalogue.dart';
import '../models/commerce.dart';
import 'backend_error.dart';
import 'uploads.dart';

/// Chat between a buyer and a shop: text and voice notes (up to 60 s), delivered live.
/// Messages are written directly; row level security keeps each conversation to its
/// buyer and the shop's staff.
class ChatRepository {
  ChatRepository(this._client);

  final SupabaseClient _client;

  static const _voiceBucket = 'voice-notes';

  String get _me => signedInUserId(_client);

  /// The buyer opens (or reopens) a chat with a shop, optionally about one sub-order.
  /// Returns the conversation id.
  Future<String> start(String shopId, {String? subOrderId}) => guard(() async {
    final row = await _client.rpc<Json>(
      'start_conversation',
      params: {'p_shop_id': shopId, 'p_sub_order_id': subOrderId},
    );
    return row['id'] as String;
  });

  /// The shop opens a chat with the buyer of one of its sub-orders.
  Future<String> startAsShop(String subOrderId) => guard(() async {
    final row = await _client.rpc<Json>(
      'shop_start_conversation',
      params: {'p_sub_order_id': subOrderId},
    );
    return row['id'] as String;
  });

  /// The buyer's chats, latest activity first.
  Future<List<Conversation>> buyerInbox({int limit = 50}) => guard(() async {
    final me = _me;
    final rows = await _client
        .from('conversations')
        .select(
          '*, shop:shops(name_ar, name_en), sub_order:sub_orders(order:orders(ref)), messages(*)',
        )
        .eq('buyer_id', me)
        .not('last_message_at', 'is', null)
        .order('last_message_at', ascending: false)
        .order('created_at', referencedTable: 'messages', ascending: false)
        .limit(1, referencedTable: 'messages')
        .limit(limit);
    return [for (final r in rows) Conversation.forBuyer(r, myId: me)];
  });

  /// A shop's chats, latest activity first.
  Future<List<Conversation>> shopInbox(String shopId, {int limit = 50}) => guard(() async {
    final rows = await _client.rpc<List<dynamic>>(
      'shop_conversations',
      params: {'p_shop_id': shopId, 'p_limit': limit},
    );
    return [for (final r in rows.cast<Json>()) Conversation.forShop(r)];
  });

  /// Up to [limit] messages before [before] (the newest when null), oldest first.
  Future<List<ChatMessage>> messages(String conversationId, {DateTime? before, int limit = 50}) =>
      guard(() async {
        final me = _me;
        var query = _client.from('messages').select().eq('conversation_id', conversationId);
        if (before != null) query = query.lt('created_at', before.toUtc().toIso8601String());
        final rows = await query.order('created_at', ascending: false).limit(limit);
        return [for (final r in rows.reversed) ChatMessage.fromJson(r, myId: me)];
      });

  Future<ChatMessage> send(String conversationId, String text) => guard(() async {
    final row = await _client
        .from('messages')
        .insert({'conversation_id': conversationId, 'body': text})
        .select()
        .single();
    return ChatMessage.fromJson(row, myId: _me);
  });

  /// Uploads the recording to the conversation's folder, then sends it.
  Future<ChatMessage> sendVoice(
    String conversationId,
    Uint8List audio, {
    required int seconds,
    String fileName = 'voice.m4a',
  }) => guard(() async {
    final key = '$conversationId/${newIdempotencyKey()}${extensionOf(fileName)}';
    await _client.storage
        .from(_voiceBucket)
        .uploadBinary(key, audio, fileOptions: FileOptions(contentType: mimeOf(fileName)));
    final row = await _client
        .from('messages')
        .insert({'conversation_id': conversationId, 'voice_key': key, 'voice_secs': seconds})
        .select()
        .single();
    return ChatMessage.fromJson(row, myId: _me);
  });

  /// An hour-long link to play a voice note.
  Future<String> voiceUrl(String voiceKey) =>
      guard(() => _client.storage.from(_voiceBucket).createSignedUrl(voiceKey, 3600));

  Future<void> markRead(String conversationId) => guard(
    () =>
        _client.rpc<void>('mark_conversation_read', params: {'p_conversation_id': conversationId}),
  );

  /// New messages in the conversation as they arrive (both sides, including this
  /// device's own sends). Cancel the subscription to leave the channel.
  Stream<ChatMessage> live(String conversationId) {
    late final RealtimeChannel channel;
    late final StreamController<ChatMessage> controller;
    controller = StreamController<ChatMessage>(
      onListen: () {
        final me = _me;
        channel = _client
            .channel('messages:$conversationId')
            .onPostgresChanges(
              event: PostgresChangeEvent.insert,
              schema: 'public',
              table: 'messages',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'conversation_id',
                value: conversationId,
              ),
              callback: (payload) =>
                  controller.add(ChatMessage.fromJson(payload.newRecord, myId: me)),
            )
            .subscribe();
      },
      onCancel: () => _client.removeChannel(channel),
    );
    return controller.stream;
  }
}

/// The in-app inbox (`notifications`), newest first. The app words each entry from its
/// code and payload in the reader's language.
class NotificationsRepository {
  NotificationsRepository(this._client);

  final SupabaseClient _client;

  Future<List<InboxItem>> list({int limit = 50}) => guard(() async {
    final rows = await _client
        .from('notifications')
        .select()
        .order('created_at', ascending: false)
        .limit(limit);
    return [for (final r in rows) InboxItem.fromJson(r)];
  });

  /// Marks [ids] read, or all of them when null. Returns how many changed.
  Future<int> markRead([List<String>? ids]) =>
      guard(() => _client.rpc<int>('mark_notifications_read', params: {'p_ids': ids}));
}
