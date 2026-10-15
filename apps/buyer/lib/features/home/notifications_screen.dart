import 'package:alghali_core/alghali_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../state/inbox.dart';

/// The in-app inbox: every alert, worded in the reader's language from the templates
/// admins edit (the same wording push uses, D-101).
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final theme = Theme.of(context);
    final inbox = ref.watch(inboxProvider);
    final templates = ref.watch(alertTemplatesProvider).value ?? AlertTemplates.empty;
    final locale = Localizations.localeOf(context).languageCode;
    final now = ref.watch(clockProvider)();

    return Scaffold(
      appBar: AppBar(
        title: Text(t.notificationsTitle),
        actions: [
          if (inbox.value?.any((n) => !n.read) ?? false)
            TextButton(
              onPressed: () => ref.read(inboxProvider.notifier).markAllRead(),
              child: Text(t.notificationsMarkRead),
            ),
        ],
      ),
      body: AsyncBody(
        value: inbox,
        onRefresh: () async {
          ref.invalidate(alertTemplatesProvider);
          await ref.read(inboxProvider.notifier).refresh();
        },
        data: (items) => items.isEmpty
            ? ListView(
                children: [
                  EmptyState(
                    icon: Icons.notifications_none_outlined,
                    title: t.notificationsEmpty,
                    message: t.notificationsEmptyBody,
                  ),
                ],
              )
            : ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: Space.sm),
                itemCount: items.length,
                separatorBuilder: (_, _) => const Divider(indent: 72),
                itemBuilder: (context, i) {
                  final n = items[i];
                  final text = templates.render(n, locale);
                  final route = alertRoute(n.code, n.payload);
                  final (icon, tone) = switch (alertKind(n.code)) {
                    NotificationKind.payment => (Icons.account_balance_outlined, Tone.success),
                    NotificationKind.order => (Icons.inventory_2_outlined, Tone.info),
                    NotificationKind.booking => (Icons.handyman_outlined, Tone.brand),
                    NotificationKind.offer => (Icons.local_offer_outlined, Tone.warning),
                    NotificationKind.system => (Icons.info_outline, Tone.neutral),
                  };
                  return ListTile(
                    key: ValueKey(n.id),
                    tileColor: n.read ? null : theme.colorScheme.surface,
                    leading: IconTile(icon: icon, tone: tone),
                    title: Text(
                      text?.title ?? t.notificationsGeneric,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: n.read ? FontWeight.w500 : FontWeight.w700,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (text != null) Text(text.body),
                        const SizedBox(height: Space.xxs),
                        Text(context.core.ago(n.at, now), style: theme.textTheme.bodySmall),
                      ],
                    ),
                    trailing: n.read
                        ? null
                        : Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                    onTap: () {
                      ref.read(inboxProvider.notifier).markRead(n.id);
                      if (route != null) context.push(route);
                    },
                  );
                },
              ),
      ),
    );
  }
}
