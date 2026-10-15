import 'package:alghali_core/alghali_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../router.dart';
import '../../state/inbox.dart';

/// The buyer's chats with shops, latest first.
class ChatsScreen extends ConsumerWidget {
  const ChatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final theme = Theme.of(context);
    final now = ref.watch(clockProvider)();
    return Scaffold(
      appBar: AppBar(title: Text(t.chatsTitle)),
      body: AsyncBody(
        value: ref.watch(chatsProvider),
        onRefresh: () => ref.read(chatsProvider.notifier).refresh(),
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
                  return ListTile(
                    leading: InitialsAvatar(name: c.title.tr(context), size: 44),
                    title: Text(
                      c.title.tr(context),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: c.unread ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      last == null
                          ? ''
                          : last.voiceSecs != null
                          ? t.chatVoiceNote
                          : last.text ?? '',
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
                    onTap: () => context.push(Routes.chat(c.shopId)),
                  );
                },
              ),
      ),
    );
  }
}
