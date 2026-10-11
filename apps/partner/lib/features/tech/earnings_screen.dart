import 'package:alghali_core/alghali_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../state/tech_state.dart';
import '../../widgets/partner_widgets.dart';
import '../shop/money_screens.dart';

class EarningsScreen extends ConsumerWidget {
  const EarningsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final e = ref.watch(techEarningsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(t.techNavEarnings)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Space.page, Space.lg, Space.page, Space.xxl),
        children: [
          Card(
            color: colors.brandSurface,
            child: Padding(
              padding: const EdgeInsets.all(Space.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.earningsWeek,
                    style: theme.textTheme.bodyMedium?.copyWith(color: colors.onBrandSurfaceMuted),
                  ),
                  // The one hero figure on this screen: large, proportional digits.
                  Text(
                    context.sdg(e.weekSdg),
                    style: theme.textTheme.displaySmall?.copyWith(color: colors.onBrandSurface),
                  ),
                  Text(
                    t.jobsCount(e.weekJobs),
                    style: theme.textTheme.bodyMedium?.copyWith(color: colors.onBrandSurface),
                  ),
                  const SizedBox(height: Space.sm),
                  Text(
                    t.nextPayout(context.day(e.nextPayout)),
                    style: theme.textTheme.bodySmall?.copyWith(color: colors.onBrandSurfaceMuted),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Space.md),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  label: t.moneyOwedToYou,
                  value: context.sdg(e.balanceSdg),
                  icon: Icons.account_balance_wallet_outlined,
                  tone: Tone.success,
                ),
              ),
              const SizedBox(width: Space.md),
              Expanded(
                child: StatTile(
                  label: t.cashWithYou,
                  value: context.sdg(e.cashHeldSdg),
                  icon: Icons.payments_outlined,
                  tone: Tone.warning,
                  note: t.cashWithYouBody,
                ),
              ),
            ],
          ),
          SectionHeader(
            title: t.recentActivity,
            padding: const EdgeInsets.fromLTRB(Space.xs, Space.xl, 0, Space.sm),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.lg),
              child: Column(children: [for (final l in e.lines) LedgerTile(line: l)]),
            ),
          ),
        ],
      ),
    );
  }
}
