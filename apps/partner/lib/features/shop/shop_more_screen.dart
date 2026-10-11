import 'package:alghali_core/alghali_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../router.dart';
import '../../state/session.dart';
import '../../widgets/partner_widgets.dart';

class ShopMoreScreen extends ConsumerWidget {
  const ShopMoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final core = context.core;
    final theme = Theme.of(context);
    final session = ref.watch(partnerSessionProvider);
    final catalogue = ref.watch(catalogueProvider);
    final shop = catalogue.shop(session.shopId);
    final chevron = Directionality.of(context) == TextDirection.rtl
        ? Icons.chevron_left
        : Icons.chevron_right;

    ListTile row(IconData icon, String title, VoidCallback onTap) =>
        ListTile(leading: Icon(icon), title: Text(title), trailing: Icon(chevron), onTap: onTap);

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
                  InitialsAvatar(name: shop.name.tr(context), size: 56, tone: Tone.brand),
                  const SizedBox(width: Space.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(shop.name.tr(context), style: theme.textTheme.titleMedium),
                        Text(
                          '${catalogue.zone(shop.zoneId).name.tr(context)} · ${core.plot(shop.plotNo)}',
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(height: Space.xs),
                        Wrap(
                          spacing: Space.sm,
                          children: [
                            if (shop.verified)
                              StatusPill(
                                label: core.verifiedShop,
                                tone: Tone.info,
                                icon: Icons.verified,
                              ),
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
                Icons.account_balance_wallet_outlined,
                t.moreMoney,
                () => context.push(Routes.shopMoney),
              ),
              row(Icons.insights_outlined, t.moreInsights, () => context.push(Routes.shopInsights)),
              row(Icons.groups_outlined, t.moreStaff, () => context.push(Routes.shopStaff)),
              row(Icons.storefront_outlined, t.moreProfile, () => showDemoDisabled(context)),
            ],
          ),
          MenuCard(children: settingsRows(context, ref)),
          MenuCard(
            children: [
              row(Icons.swap_horiz, t.roleSwitch, () => context.push(Routes.role)),
              row(Icons.help_outline, t.moreHelp, () => showDemoDisabled(context)),
            ],
          ),
          const SizedBox(height: Space.xl),
          SignOutButton(label: t.signOut, confirm: t.signOutConfirm),
        ],
      ),
    );
  }
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
