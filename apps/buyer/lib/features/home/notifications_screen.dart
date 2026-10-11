import 'package:alghali_core/alghali_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../state/orders.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final theme = Theme.of(context);
    final items = ref.watch(notificationsProvider);
    final now = ref.watch(clockProvider)();

    return Scaffold(
      appBar: AppBar(
        title: Text(t.notificationsTitle),
        actions: [
          if (items.any((n) => !n.read))
            TextButton(
              onPressed: () => ref.read(notificationsProvider.notifier).markAllRead(),
              child: Text(t.notificationsMarkRead),
            ),
        ],
      ),
      body: items.isEmpty
          ? EmptyState(
              icon: Icons.notifications_none_outlined,
              title: t.notificationsEmpty,
              message: t.notificationsEmptyBody,
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: Space.sm),
              itemCount: items.length,
              separatorBuilder: (_, _) => const Divider(indent: 72),
              itemBuilder: (context, i) {
                final n = items[i];
                final (icon, tone) = switch (n.kind) {
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
                    n.title.tr(context),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: n.read ? FontWeight.w500 : FontWeight.w700,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(n.body.tr(context)),
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
                  onTap: n.route == null ? null : () => context.push(n.route!),
                );
              },
            ),
    );
  }
}
