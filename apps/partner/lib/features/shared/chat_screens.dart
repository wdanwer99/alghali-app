import 'dart:typed_data';

import 'package:alghali_core/alghali_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../router.dart';
import '../../state/inbox.dart';

/// The shop's chats with buyers, latest first.
class ShopChatsScreen extends ConsumerWidget {
  const ShopChatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final theme = Theme.of(context);
    final now = ref.watch(clockProvider)();
    return Scaffold(
      appBar: AppBar(title: Text(t.chatsTitle)),
      body: AsyncBody(
        value: ref.watch(shopChatsProvider),
        onRefresh: () => ref.read(shopChatsProvider.notifier).refresh(),
        data: (list) => list.isEmpty
            ? ListView(
                children: [
                  EmptyState(
                    icon: Icons.forum_outlined,
                    title: t.chatsEmpty,
                    message: t.chatsEmptyBody,
                  ),
                ],
              )
            : ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: Space.sm),
                itemCount: list.length,
                separatorBuilder: (_, _) => const Divider(indent: 72),
                itemBuilder: (context, i) {
                  final c = list[i];
                  final last = c.last;
                  final preview = last == null
                      ? ''
                      : last.voiceSecs != null
                      ? t.chatVoiceNote
                      : last.text ?? '';
                  return ListTile(
                    leading: InitialsAvatar(name: c.title.tr(context), size: 44),
                    title: Text(
                      c.title.tr(context),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: c.unread ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      c.orderRef == null
                          ? preview
                          : '${t.orderRef(formatRef(c.orderRef!))} · $preview',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (last != null)
                          Text(context.core.ago(last.at, now), style: theme.textTheme.bodySmall),
                        if (c.unread)
                          Container(
                            width: 10,
                            height: 10,
                            margin: const EdgeInsets.only(top: Space.xs),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    onTap: () => context.push(Routes.shopChat(c.id)),
                  );
                },
              ),
      ),
    );
  }
}

/// Chat with a buyer: text and voice notes (D-033), newest at the bottom, live. Text can
/// be written offline (it waits in the outbox, with a clock on the bubble).
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.conversationId});

  final String conversationId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _text.text.trim();
    if (text.isEmpty) return;
    _text.clear();
    setState(() {});
    await ref.read(chatProvider(widget.conversationId).notifier).send(text);
  }

  Future<void> _sendVoice(Uint8List audio, int seconds) async {
    try {
      await ref.read(chatProvider(widget.conversationId).notifier).sendVoice(audio, seconds);
    } on BackendException catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = Theme.of(context);
    final chat = (ref.watch(shopChatsProvider).value ?? const <Conversation>[])
        .where((c) => c.id == widget.conversationId)
        .firstOrNull;
    final thread = ref.watch(chatProvider(widget.conversationId));
    final notifier = ref.read(chatProvider(widget.conversationId).notifier);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            InitialsAvatar(name: chat?.title.tr(context) ?? '?', size: 36),
            const SizedBox(width: Space.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    chat?.title.tr(context) ?? t.chatsTitle,
                    style: theme.textTheme.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (chat?.orderRef != null)
                    Text(t.orderRef(formatRef(chat!.orderRef!)), style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (chat?.subOrderId != null)
            IconButton(
              tooltip: t.openOrder,
              onPressed: () => context.push(Routes.shopOrder(chat!.subOrderId!)),
              icon: const Icon(Icons.receipt_long_outlined),
            ),
        ],
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: switch (thread) {
              AsyncData(value: ChatThread(messages: [])) => EmptyState(
                icon: Icons.chat_bubble_outline,
                title: t.chatEmpty,
                compact: true,
              ),
              AsyncData(:final value) => ListView.builder(
                reverse: true,
                padding: Space.pageInsets,
                itemCount: value.messages.length,
                itemBuilder: (context, i) {
                  final m = value.messages[value.messages.length - 1 - i];
                  return _Bubble(
                    key: ValueKey(m.id),
                    message: m,
                    pending: value.pending.contains(m.id),
                    voiceUrl: m.voiceKey == null ? null : () => notifier.voiceUrl(m.voiceKey!),
                  );
                },
              ),
              AsyncError(:final error) => EmptyState(
                icon: Icons.cloud_off_outlined,
                title: context.core.error(error),
                action: OutlinedButton(
                  onPressed: () => ref.invalidate(chatProvider(widget.conversationId)),
                  child: Text(context.core.actionRetry),
                ),
              ),
              _ => const SkeletonList(),
            },
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(Space.sm),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _text,
                        minLines: 1,
                        maxLines: 4,
                        maxLength: 2000,
                        enabled: thread.hasValue,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: t.chatHint,
                          counterText: '',
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: Space.lg,
                            vertical: Space.md,
                          ),
                          border: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(24)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: const BorderRadius.all(Radius.circular(24)),
                            borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: const BorderRadius.all(Radius.circular(24)),
                            borderSide: BorderSide(color: theme.colorScheme.secondary, width: 2),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: Space.sm),
                    if (_text.text.trim().isEmpty)
                      VoiceRecordButton(onRecorded: _sendVoice)
                    else
                      IconButton.filled(
                        tooltip: t.chatSend,
                        onPressed: _send,
                        icon: const Icon(Icons.send_rounded),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({super.key, required this.message, this.pending = false, this.voiceUrl});

  final ChatMessage message;
  final bool pending;
  final Future<String> Function()? voiceUrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final mine = message.mine;
    final fg = mine ? scheme.onSecondary : scheme.onSurface;
    const r = Radius.circular(16);
    return Align(
      alignment: mine ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
        margin: const EdgeInsets.symmetric(vertical: Space.xs),
        padding: const EdgeInsets.fromLTRB(Space.md, Space.sm, Space.md, Space.xs),
        decoration: BoxDecoration(
          color: mine ? scheme.secondary : scheme.surface,
          border: mine ? null : Border.all(color: scheme.outlineVariant),
          borderRadius: BorderRadiusDirectional.only(
            topStart: r,
            topEnd: r,
            bottomStart: mine ? r : const Radius.circular(4),
            bottomEnd: mine ? const Radius.circular(4) : r,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.voiceSecs != null)
              VoiceNotePlayer(seconds: message.voiceSecs!, color: fg, url: voiceUrl)
            else
              Text(message.text ?? '', style: theme.textTheme.bodyMedium?.copyWith(color: fg)),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (pending) ...[
                    Tooltip(
                      message: context.core.queuedOffline,
                      child: Icon(Icons.schedule, size: 12, color: fg.withValues(alpha: 0.7)),
                    ),
                    const SizedBox(width: Space.xxs),
                  ],
                  Text(
                    context.time(message.at),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: fg.withValues(alpha: 0.7),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
