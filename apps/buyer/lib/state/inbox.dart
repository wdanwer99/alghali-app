import 'dart:async';
import 'dart:typed_data';

import 'package:alghali_core/alghali_core.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'outbox.dart';
import 'session.dart';

/// The in-app inbox (`notifications`), newest first. Push brings the same alerts.
class InboxController extends AsyncNotifier<List<InboxItem>> with CachedList<List<InboxItem>> {
  @override
  Future<List<InboxItem>> build() async {
    final uid = ref.watch(sessionProvider.select((s) => s.userId));
    if (uid == null) return const [];
    return load();
  }

  @override
  Future<List<InboxItem>> fetch() => ref.read(notificationsRepositoryProvider).list(app: 'buyer');

  /// Marks everything read at once; the server hears about it through the outbox.
  Future<void> markAllRead() async {
    final items = state.value ?? const <InboxItem>[];
    if (items.every((n) => n.read)) return;
    state = AsyncData([
      for (final n in items)
        InboxItem(id: n.id, code: n.code, payload: n.payload, at: n.at, read: true),
    ]);
    await queue(ref, BuyerOps.inboxRead, {'ids': null});
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
    await queue(ref, BuyerOps.inboxRead, {
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

/// Where tapping an alert (in the inbox or the notification tray) takes the buyer.
String? alertRoute(String code, Map<String, Object?> payload) {
  String? id(String key) {
    final v = payload[key];
    return v is String && v.isNotEmpty ? v : null;
  }

  if (code == 'NEW_MESSAGE' && id('shop_id') != null) return '/chat/${id('shop_id')}';
  if (id('dispute_id') != null) return '/complaints/${id('dispute_id')}';
  if (id('booking_id') != null) return '/booking/${id('booking_id')}';
  if (id('request_id') != null) return '/request/${id('request_id')}';
  if (id('order_id') != null) return '/order/${id('order_id')}';
  return null;
}

// ---------------------------------------------------------------------------- chat

/// Live updates over Realtime (chat); widget tests switch them off.
final realtimeProvider = Provider<bool>((ref) => true);

/// The conversation with a shop: started once (needs a connection), then remembered on
/// the phone so its messages open offline.
final conversationIdProvider = FutureProvider.autoDispose.family<String, String>((
  ref,
  shopId,
) async {
  final uid = ref.watch(sessionProvider.select((s) => s.userId));
  if (uid == null) throw const BackendException('SESSION_EXPIRED');
  final prefs = ref.read(sharedPreferencesProvider);
  final key = 'chat:$uid:$shopId';
  final saved = prefs.getString(key);
  if (saved != null) return saved;
  final id = await ref.read(chatRepositoryProvider).start(shopId);
  await prefs.setString(key, id);
  return id;
});

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

  /// Ids of the buyer's messages still waiting in the outbox.
  final Set<String> pending;
}

/// One chat with a shop: the saved messages at once, then the server's, then new ones
/// live (Realtime). Text goes through the outbox, so it can be written offline.
class ChatController extends AsyncNotifier<ChatThread> {
  ChatController(this.shopId);

  final String shopId;
  StreamSubscription<ChatMessage>? _live;
  StreamSubscription<OutboxResult>? _sent;

  ChatRepository get _repo => ref.read(chatRepositoryProvider);

  @override
  Future<ChatThread> build() async {
    final convId = await ref.watch(conversationIdProvider(shopId).future);
    ref.onDispose(() {
      unawaited(_live?.cancel());
      unawaited(_sent?.cancel());
    });
    if (ref.watch(realtimeProvider)) {
      _live = _repo.live(convId).listen(_arrived, onError: (Object _) {});
    }
    // A message sent later from the outbox loses its clock even if Realtime is slow.
    _sent = ref.read(outboxProvider)?.results.listen((r) {
      if (r.ok && r.operation == BuyerOps.chatSend && r.payload['conversation_id'] == convId) {
        sent(r.payload['id'] as String);
      }
    });
    final saved = await _repo.peekMessages(convId).catchError((Object _) => null);
    unawaited(Future.microtask(() => _load(convId)));
    return ChatThread(conversationId: convId, messages: saved ?? const []);
  }

  Future<void> _load(String convId) async {
    try {
      final messages = await _repo.messages(convId);
      if (!ref.mounted) return;
      final current = state.value;
      final pending = current?.pending ?? const <String>{};
      // Keep this phone's unsent messages under the server's.
      final unsent = [
        for (final m in current?.messages ?? const <ChatMessage>[])
          if (pending.contains(m.id) && !messages.any((x) => x.id == m.id)) m,
      ];
      state = AsyncData(
        ChatThread(conversationId: convId, messages: [...messages, ...unsent], pending: pending),
      );
      unawaited(_repo.markRead(convId).catchError((Object _) {}));
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
    await queue(ref, BuyerOps.chatSend, {
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

/// The buyer's chats, latest first.
class ChatsController extends AsyncNotifier<List<Conversation>>
    with CachedList<List<Conversation>> {
  @override
  Future<List<Conversation>> build() async {
    final uid = ref.watch(sessionProvider.select((s) => s.userId));
    if (uid == null) return const [];
    return load();
  }

  @override
  Future<List<Conversation>> fetch() => ref.read(chatRepositoryProvider).buyerInbox();
}

final chatsProvider = AsyncNotifierProvider<ChatsController, List<Conversation>>(
  ChatsController.new,
);
