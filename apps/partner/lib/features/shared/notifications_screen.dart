import 'dart:async';

import 'package:alghali_core/alghali_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../state/inbox.dart';
import '../../state/session.dart';

/// The partner's alerts, worded in the reader's language from the templates admins edit
/// (the same wording push uses, D-101). Tapping one opens what it is about, switching
/// between the shop's and the technician's screens when needed.
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
    final session = ref.watch(partnerSessionProvider);

    Future<void> open(({String route, PartnerRole role}) target) async {
      if (session.role != target.role) {
        final ok = switch (target.role) {
          PartnerRole.shop => session.shops.isNotEmpty,
          PartnerRole.technician => session.technician != null,
        };
        if (!ok) return;
        await ref
            .read(partnerSessionProvider.notifier)
            .chooseRole(target.role, shopId: session.shopId ?? session.shops.firstOrNull?.shopId);
      }
      if (context.mounted) unawaited(context.push(target.route));
    }

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
                  final target = alertRoute(n.code, n.payload, current: session.role);
                  final (icon, tone) = switch (n.code) {
                    'NEW_ORDER' || 'TECH_WILL_COLLECT' => (Icons.receipt_long_outlined, Tone.brand),
                    'NEW_PART_REQUEST' => (Icons.request_quote_outlined, Tone.warning),
                    'NEW_JOB_OFFER' || 'PARTS_READY' => (Icons.handyman_outlined, Tone.brand),
                    'PAYOUT_PAID' => (Icons.account_balance_outlined, Tone.success),
                    'NEW_MESSAGE' => (Icons.forum_outlined, Tone.info),
                    'NEW_REVIEW' => (Icons.star_outline_rounded, Tone.success),
                    'RETURN_REQUESTED' || 'BOOKING_CANCELLED' => (Icons.undo, Tone.danger),
                    _ => (Icons.info_outline, Tone.neutral),
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
                      unawaited(ref.read(inboxProvider.notifier).markRead(n.id));
                      if (target != null) unawaited(open(target));
                    },
                  );
                },
              ),
      ),
    );
  }
}
