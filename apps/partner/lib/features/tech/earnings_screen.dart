import 'package:alghali_core/alghali_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../state/shop.dart' show nextSunday;
import '../../state/tech.dart';
import '../../widgets/partner_widgets.dart';
import '../shop/money_screens.dart';

/// The last 30 days from `tech_statement`: this week's pay, what the platform owes, the
/// cash taken from buyers, and every line.
class EarningsScreen extends ConsumerWidget {
  const EarningsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final now = ref.watch(clockProvider)();

    return Scaffold(
      appBar: AppBar(title: Text(t.techNavEarnings)),
      body: AsyncBody(
        value: ref.watch(techStatementProvider),
        onRefresh: () => ref.read(techStatementProvider.notifier).refresh(),
        data: (statement) {
          if (statement == null) {
            return ListView(
              children: [EmptyState(icon: Icons.savings_outlined, title: t.earningsNotYet)],
            );
          }
          final e = TechEarnings.of(statement, now);
          final lines = [...statement.lines]..sort((a, b) => b.at.compareTo(a.at));
          final payouts = [...statement.payouts]..sort((a, b) => b.from.compareTo(a.from));
          return ListView(
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
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.onBrandSurfaceMuted,
                        ),
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
                        t.nextPayout(context.day(nextSunday(now))),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onBrandSurfaceMuted,
                        ),
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
                      label: e.balanceSdg >= 0 ? t.moneyOwedToYou : t.moneyYouOwe,
                      value: context.sdg(e.balanceSdg.abs()),
                      icon: Icons.account_balance_wallet_outlined,
                      tone: e.balanceSdg >= 0 ? Tone.success : Tone.warning,
                    ),
                  ),
                  const SizedBox(width: Space.md),
                  Expanded(
                    child: StatTile(
                      label: t.cashWithYou,
                      value: context.sdg(e.cashSdg < 0 ? 0 : e.cashSdg),
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
              if (lines.isEmpty)
                Text(t.statementEmpty, style: theme.textTheme.bodyMedium)
              else
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Space.lg),
                    child: Column(children: [for (final l in lines) LedgerTile(line: l)]),
                  ),
                ),
              if (payouts.isNotEmpty) ...[
                SectionHeader(
                  title: t.payouts,
                  padding: const EdgeInsets.fromLTRB(Space.xs, Space.xl, 0, Space.sm),
                ),
                for (final p in payouts) PayoutTile(payout: p),
              ],
            ],
          );
        },
      ),
    );
  }
}
