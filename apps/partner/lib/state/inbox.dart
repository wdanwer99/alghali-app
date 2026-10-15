import 'dart:async';
import 'dart:typed_data';

import 'package:alghali_core/alghali_core.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'outbox.dart';
import 'session.dart';

/// The partner's alerts (`notifications` for the partner app), newest first.
class InboxController extends AsyncNotifier<List<InboxItem>> with CachedList<List<InboxItem>> {
  @override
  Future<List<InboxItem>> build() async {
    final uid = ref.watch(partnerSessionProvider.select((s) => s.userId));
    if (uid == null) return const [];
    return load();
  }

  @override
  Future<List<InboxItem>> fetch() => ref.read(notificationsRepositoryProvider).list(app: 'partner');

  /// Marks the shown alerts read; the server hears about it through the outbox.
  Future<void> markAllRead() async {
    final items = state.value ?? const <InboxItem>[];
    final ids = [
      for (final n in items)
        if (!n.read) n.id,
    ];
    if (ids.isEmpty) return;
    state = AsyncData([
      for (final n in items)
        InboxItem(id: n.id, code: n.code, payload: n.payload, at: n.at, read: true),
    ]);
    await queue(ref, PartnerOps.inboxRead, {'ids': ids});
  }

  Future<void> markRead(String id) async {
    final items = state.value ?? const <InboxItem>[];
    if (items.where((n) => n.id == id).firstOrNull?.read ?? true) return;
    state = AsyncData([
      for (final n in items)
        n.id == id
            ? InboxItem(id: n.id, code: n.code, payload: n.payload, at: n.at, read: true)
            : n,
    ]);
    await queue(ref, PartnerOps.inboxRead, {
      'ids': [id],
    });
  }
}

final inboxProvider = AsyncNotifierProvider<InboxController, List<InboxItem>>(InboxController.new);

final unreadCountProvider = Provider<int>(
  (ref) => (ref.watch(inboxProvider).value ?? const <InboxItem>[]).where((n) => !n.read).length,
);

/// How each alert code reads in Arabic and English (the admins' templates).
final alertTemplatesProvider = FutureProvider<AlertTemplates>((ref) async {
  if (!ref.watch(backendReadyProvider)) return AlertTemplates.empty;
  try {
    return await ref.watch(notificationsRepositoryProvider).templates();
  } on BackendException {
    return AlertTemplates.empty;
  }
});

/// Where an alert takes the partner, and which side of the app that is: shop alerts open
/// the shop's screens, job alerts the technician's (switching if needed).
({String route, PartnerRole role})? alertRoute(
  String code,
  Map<String, Object?> payload, {
  PartnerRole? current,
}) {
  String? id(String key) {
    final v = payload[key];
    return v is String && v.isNotEmpty ? v : null;
  }

  ({String route, PartnerRole role}) shop(String route) => (route: route, role: PartnerRole.shop);
  ({String route, PartnerRole role}) tech(String route) =>
      (route: route, role: PartnerRole.technician);

  if (code == 'NEW_MESSAGE' && id('conversation_id') != null) {
    return shop('/shop/chat/${id('conversation_id')}');
  }
  if (code == 'NEW_PART_REQUEST') return shop('/shop/quotes');
  if (id('booking_id') != null) return tech('/tech/job/${id('booking_id')}');
  if (id('sub_order_id') != null) return shop('/shop/order/${id('sub_order_id')}');
  if (code == 'TECHNICIAN_STATUS') return tech('/tech/profile');
  if (code == 'PAYOUT_PAID' || code == 'NEW_REVIEW') {
    return current == PartnerRole.technician
        ? tech(code == 'PAYOUT_PAID' ? '/tech/earnings' : '/tech/profile')
        : shop(code == 'PAYOUT_PAID' ? '/shop/money' : '/shop/insights');
  }
  return null;
}

// ---------------------------------------------------------------------------- chat

/// Live updates over Realtime (chat); widget tests switch them off.
final realtimeProvider = Provider<bool>((ref) => true);

/// The shop's chats with buyers, latest first.
class ShopChatsController extends AsyncNotifier<List<Conversation>>
    with CachedList<List<Conversation>> {
  @override
  Future<List<Conversation>> build() async {
    if (ref.watch(currentShopIdProvider) == null) return const [];
    return load();
  }

  @override
  Future<List<Conversation>> fetch() async {
    final shopId = ref.read(currentShopIdProvider);
    if (shopId == null) return const [];
    return ref.read(chatRepositoryProvider).shopInbox(shopId);
  }

  /// Opens (or reopens) the chat with the buyer of [subOrderId]; needs a connection.
  Future<String> startFor(String subOrderId) =>
      ref.read(chatRepositoryProvider).startAsShop(subOrderId);
}

final shopChatsProvider = AsyncNotifierProvider<ShopChatsController, List<Conversation>>(
  ShopChatsController.new,
);

final unreadChatsProvider = Provider<int>(
  (ref) =>
      (ref.watch(shopChatsProvider).value ?? const <Conversation>[]).where((c) => c.unread).length,
);

@immutable
class ChatThread {
  const ChatThread({
    required this.conversationId,
    this.messages = const [],
    this.pending = const {},
  });

  final String conversationId;

  /// Oldest first.
  final List<ChatMessage> messages;

  /// Ids of this phone's messages still waiting in the outbox.
  final Set<String> pending;
}

/// One chat with a buyer: the saved messages at once, then the server's, then new ones
/// live (Realtime). Text goes through the outbox, so it can be written offline.
class ChatController extends AsyncNotifier<ChatThread> {
  ChatController(this.conversationId);

  final String conversationId;
  StreamSubscription<ChatMessage>? _live;
  StreamSubscription<OutboxResult>? _sent;

  ChatRepository get _repo => ref.read(chatRepositoryProvider);

  @override
  Future<ChatThread> build() async {
    ref.onDispose(() {
      unawaited(_live?.cancel());
      unawaited(_sent?.cancel());
    });
    if (ref.watch(realtimeProvider)) {
      _live = _repo.live(conversationId).listen(_arrived, onError: (Object _) {});
    }
    _sent = ref.read(outboxResultsProvider).listen((r) {
      if (r.ok &&
          r.operation == PartnerOps.chatSend &&
          r.payload['conversation_id'] == conversationId) {
        sent(r.payload['id'] as String);
      }
    });
    final saved = await _repo.peekMessages(conversationId).catchError((Object _) => null);
    unawaited(Future.microtask(_load));
    return ChatThread(conversationId: conversationId, messages: saved ?? const []);
  }

  Future<void> _load() async {
    try {
      final messages = await _repo.messages(conversationId);
      if (!ref.mounted) return;
      final current = state.value;
      final pending = current?.pending ?? const <String>{};
      // Keep this phone's unsent messages under the server's.
      final unsent = [
        for (final m in current?.messages ?? const <ChatMessage>[])
          if (pending.contains(m.id) && !messages.any((x) => x.id == m.id)) m,
      ];
      state = AsyncData(
        ChatThread(
          conversationId: conversationId,
          messages: [...messages, ...unsent],
          pending: pending,
        ),
      );
      unawaited(_repo.markRead(conversationId).catchError((Object _) {}));
      ref.invalidate(shopChatsProvider);
    } on Object {
      // Offline: the saved messages stay.
    }
  }

  void _arrived(ChatMessage m) {
    final t = state.value;
    if (t == null) return;
    final exists = t.messages.any((x) => x.id == m.id);
    state = AsyncData(
      ChatThread(
        conversationId: t.conversationId,
        messages: exists ? [for (final x in t.messages) x.id == m.id ? m : x] : [...t.messages, m],
        pending: {...t.pending}..remove(m.id),
      ),
    );
    if (!m.mine) unawaited(_repo.markRead(t.conversationId).catchError((Object _) {}));
  }

  Future<void> send(String text) async {
    final t = state.value;
    if (t == null || text.trim().isEmpty) return;
    final m = ChatMessage(
      id: newId(),
      mine: true,
      at: ref.read(clockProvider)(),
      text: text.trim(),
    );
    state = AsyncData(
      ChatThread(
        conversationId: t.conversationId,
        messages: [...t.messages, m],
        pending: {...t.pending, m.id},
      ),
    );
    await queue(ref, PartnerOps.chatSend, {
      'id': m.id,
      'conversation_id': t.conversationId,
      'body': m.text,
    });
  }

  /// Called when the outbox sent a message (in case Realtime is slow to echo it).
  void sent(String messageId) {
    final t = state.value;
    if (t == null || !t.pending.contains(messageId)) return;
    state = AsyncData(
      ChatThread(
        conversationId: t.conversationId,
        messages: t.messages,
        pending: {...t.pending}..remove(messageId),
      ),
    );
  }

  /// Uploads and sends a voice note; needs a connection.
  Future<void> sendVoice(Uint8List audio, int seconds) async {
    final t = state.value;
    if (t == null) return;
    final m = await _repo.sendVoice(t.conversationId, audio, seconds: seconds);
    _arrived(m);
  }

  Future<String> voiceUrl(String key) => _repo.voiceUrl(key);
}

final chatProvider = AsyncNotifierProvider.autoDispose.family<ChatController, ChatThread, String>(
  ChatController.new,
);
