import 'package:alghali_core/alghali_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../state/orders.dart';

/// Chat with a shop: text and voice notes (D-033), newest at the bottom.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.shopId});

  final String shopId;

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

  void _send() {
    final text = _text.text.trim();
    if (text.isEmpty) return;
    ref.read(chatProvider.notifier).send(widget.shopId, text: text);
    _text.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = Theme.of(context);
    final shop = ref.watch(catalogueProvider).shop(widget.shopId);
    final messages = ref.watch(chatProvider)[widget.shopId] ?? const <ChatMessage>[];

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            InitialsAvatar(name: shop.name.tr(context), size: 36),
            const SizedBox(width: Space.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    shop.name.tr(context),
                    style: theme.textTheme.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(shop.openNow ? t.shopOpen : t.shopClosed, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: context.core.actionCall,
            onPressed: () => showDemoDisabled(context),
            icon: const Icon(Icons.call_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: messages.isEmpty
                ? EmptyState(icon: Icons.chat_bubble_outline, title: t.chatEmpty, compact: true)
                : ListView.builder(
                    reverse: true,
                    padding: Space.pageInsets,
                    itemCount: messages.length,
                    itemBuilder: (context, i) {
                      final m = messages[messages.length - 1 - i];
                      return _Bubble(key: ValueKey(m.id), message: m);
                    },
                  ),
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
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: t.chatHint,
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
                    _text.text.trim().isEmpty
                        ? IconButton.filledTonal(
                            tooltip: t.chatRecord,
                            onPressed: () {
                              ref.read(chatProvider.notifier).send(widget.shopId, voiceSecs: 8);
                              ScaffoldMessenger.of(context)
                                ..hideCurrentSnackBar()
                                ..showSnackBar(SnackBar(content: Text(t.chatVoiceSoon)));
                            },
                            icon: const Icon(Icons.mic_none_rounded),
                          )
                        : IconButton.filled(
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
  const _Bubble({super.key, required this.message});

  final ChatMessage message;

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
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.play_arrow_rounded, color: fg),
                  const SizedBox(width: Space.xs),
                  for (var i = 0; i < 14; i++)
                    Container(
                      width: 3,
                      height: 6.0 + (i * 7 % 13),
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: BoxDecoration(
                        color: fg.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  const SizedBox(width: Space.sm),
                  Text(
                    '0:${message.voiceSecs!.toString().padLeft(2, '0')}',
                    style: theme.textTheme.labelSmall?.copyWith(color: fg),
                  ),
                ],
              )
            else
              Text(message.text ?? '', style: theme.textTheme.bodyMedium?.copyWith(color: fg)),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Text(
                context.time(message.at),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: fg.withValues(alpha: 0.7),
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
