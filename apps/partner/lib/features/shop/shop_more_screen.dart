import 'package:alghali_core/alghali_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../router.dart';
import '../../state/complaints.dart';
import '../../state/inbox.dart';
import '../../state/session.dart';
import '../../state/shop.dart';
import '../../widgets/partner_widgets.dart';

class ShopMoreScreen extends ConsumerWidget {
  const ShopMoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final core = context.core;
    final theme = Theme.of(context);
    final session = ref.watch(partnerSessionProvider);
    final membership = session.shop;
    final shop = ref.watch(myShopProvider).value;
    final catalogue = ref.watch(catalogueProvider);
    final name = (shop?.name ?? membership?.name)?.tr(context) ?? '';
    final owner = session.isOwner;
    final chevron = Directionality.of(context) == TextDirection.rtl
        ? Icons.chevron_left
        : Icons.chevron_right;

    ListTile row(IconData icon, String title, VoidCallback onTap, {int badge = 0}) => ListTile(
      leading: Badge(isLabelVisible: badge > 0, label: Text('$badge'), child: Icon(icon)),
      title: Text(title),
      trailing: Icon(chevron),
      onTap: onTap,
    );

    return Scaffold(
      appBar: AppBar(title: Text(t.shopNavMore)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Space.page, Space.lg, Space.page, Space.xxl),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(Space.lg),
              child: Row(
                children: [
                  InitialsAvatar(name: name, size: 56, tone: Tone.brand),
                  const SizedBox(width: Space.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: theme.textTheme.titleMedium),
                        if (shop != null)
                          Text(
                            [
                              catalogue.zone(shop.zoneId).name.tr(context),
                              if (shop.plotNo.isNotEmpty) core.plot(shop.plotNo),
                            ].where((s) => s.isNotEmpty).join(' · '),
                            style: theme.textTheme.bodySmall,
                          ),
                        const SizedBox(height: Space.xs),
                        Wrap(
                          spacing: Space.sm,
                          runSpacing: Space.xs,
                          children: [
                            if (membership != null && membership.status != PartnerStatus.approved)
                              PartnerStatusPill(status: membership.status),
                            if (shop?.verified ?? false)
                              StatusPill(
                                label: core.verifiedShop,
                                tone: Tone.info,
                                icon: Icons.verified,
                              ),
                            if (shop != null && shop.ratingCount > 0)
                              RatingLine(rating: shop.rating, count: shop.ratingCount, dense: true),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          MenuCard(
            children: [
              row(
                Icons.forum_outlined,
                t.chatsTitle,
                () => context.push(Routes.shopChats),
                badge: ref.watch(unreadChatsProvider),
              ),
              row(
                Icons.notifications_outlined,
                t.notificationsTitle,
                () => context.push(Routes.notifications),
                badge: ref.watch(unreadCountProvider),
              ),
              row(
                Icons.support_agent_outlined,
                t.complaintsTitle,
                () => context.push(Routes.complaints),
                badge: ref.watch(openComplaintsProvider),
              ),
            ],
          ),
          MenuCard(
            children: [
              if (owner)
                row(
                  Icons.account_balance_wallet_outlined,
                  t.moreMoney,
                  () => context.push(Routes.shopMoney),
                ),
              row(Icons.insights_outlined, t.moreInsights, () => context.push(Routes.shopInsights)),
              if (owner) ...[
                row(Icons.groups_outlined, t.moreStaff, () => context.push(Routes.shopStaff)),
                row(
                  Icons.storefront_outlined,
                  t.moreProfile,
                  () => context.push(Routes.shopProfile),
                ),
              ],
            ],
          ),
          MenuCard(children: settingsRows(context, ref)),
          MenuCard(
            children: [
              row(Icons.swap_horiz, t.roleSwitch, () => context.push(Routes.role)),
              row(Icons.help_outline, t.moreHelp, () => showHelp(context, ref)),
            ],
          ),
          const SizedBox(height: Space.xl),
          SignOutButton(label: t.signOut, confirm: t.signOutConfirm),
        ],
      ),
    );
  }
}

/// The platform's support phone and WhatsApp.
Future<void> showHelp(BuildContext context, WidgetRef ref) {
  final settings = ref.read(platformSettingsProvider);
  return showModalBottomSheet<void>(
    context: context,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.page, 0, Space.page, Space.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(context.t.moreHelp, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: Space.sm),
            Text(context.t.helpBody),
            const SizedBox(height: Space.lg),
            ContactActions(
              live: true,
              phone: settings.supportPhone.isEmpty ? null : settings.supportPhone,
              whatsapp: settings.supportWhatsapp.isEmpty ? null : settings.supportWhatsapp,
            ),
          ],
        ),
      ),
    ),
  );
}

class SignOutButton extends ConsumerWidget {
  const SignOutButton({super.key, required this.label, required this.confirm});

  final String label;
  final String confirm;

  @override
  Widget build(BuildContext context, WidgetRef ref) => OutlinedButton.icon(
    style: OutlinedButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
    onPressed: () async {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(confirm),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.core.actionCancel),
            ),
            TextButton(onPressed: () => Navigator.pop(context, true), child: Text(label)),
          ],
        ),
      );
      if (!(ok ?? false)) return;
      await ref.read(partnerSessionProvider.notifier).signOut();
      if (context.mounted) context.go(Routes.signIn);
    },
    icon: const Icon(Icons.logout),
    label: Text(label),
  );
}
