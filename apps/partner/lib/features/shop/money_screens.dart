import 'package:alghali_core/alghali_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../state/shop_state.dart';
import '../../widgets/partner_widgets.dart';

String ledgerLabel(AppLocalizations t, LedgerKind k) => switch (k) {
  LedgerKind.sale => t.ledgerSale,
  LedgerKind.commission => t.ledgerCommission,
  LedgerKind.labour => t.ledgerLabour,
  LedgerKind.travelFee => t.ledgerTravel,
  LedgerKind.bookingFee => t.ledgerBookingFee,
  LedgerKind.cashCollected => t.ledgerCash,
  LedgerKind.cashHandover => t.ledgerHandover,
  LedgerKind.payout => t.ledgerPayout,
  LedgerKind.refund => t.ledgerRefund,
};

/// "+12,000" / "−600" with sign colour; signs stay left-to-right in Arabic.
class SignedAmount extends StatelessWidget {
  const SignedAmount(this.sdg, {super.key});

  final int sdg;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Text(
      ltr('${sdg >= 0 ? '+' : '−'}${groupDigits(sdg.abs())}'),
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        color: sdg >= 0 ? colors.success : scheme.onSurface,
        fontFeatures: AppTypography.tabular,
      ),
    );
  }
}

class LedgerTile extends StatelessWidget {
  const LedgerTile({super.key, required this.line});

  final LedgerLine line;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: IconTile(
        icon: switch (line.kind) {
          LedgerKind.sale || LedgerKind.labour || LedgerKind.travelFee => Icons.south_west,
          LedgerKind.payout => Icons.account_balance_outlined,
          LedgerKind.cashCollected || LedgerKind.cashHandover => Icons.payments_outlined,
          _ => Icons.percent,
        },
        size: 40,
        tone: line.amountSdg >= 0 ? Tone.success : Tone.neutral,
      ),
      title: Text(ledgerLabel(t, line.kind)),
      subtitle: Text(
        line.ref == null
            ? context.dayTime(line.at)
            : '${formatRef(line.ref!)} · ${context.date(line.at)}',
      ),
      trailing: SignedAmount(line.amountSdg),
    );
  }
}

class MoneyScreen extends ConsumerWidget {
  const MoneyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final money = ref.watch(shopMoneyProvider);
    final settings = ref.watch(platformSettingsProvider);
    final orders = ref.watch(shopOrdersProvider);
    final cash = orders.where((o) => o.paymentStatus == PaymentStatus.due && !o.isDone).toList();

    return Scaffold(
      appBar: AppBar(title: Text(t.moreMoney)),
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
                    money.balanceSdg >= 0 ? t.moneyOwedToYou : t.moneyYouOwe,
                    style: theme.textTheme.bodyMedium?.copyWith(color: colors.onBrandSurfaceMuted),
                  ),
                  Text(
                    context.sdg(money.balanceSdg.abs()),
                    style: theme.textTheme.displaySmall?.copyWith(color: colors.onBrandSurface),
                  ),
                  const SizedBox(height: Space.sm),
                  Text(
                    t.nextPayout(context.day(money.nextPayout)),
                    style: theme.textTheme.bodyMedium?.copyWith(color: colors.onBrandSurface),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Space.md),
          InfoBanner(
            tone: Tone.neutral,
            icon: Icons.percent,
            message: t.commissionNote(settings.commissionPercent),
          ),
          if (cash.isNotEmpty) ...[
            SectionHeader(
              title: t.kpiCashToCollect,
              padding: const EdgeInsets.fromLTRB(Space.xs, Space.xl, 0, Space.sm),
            ),
            for (final o in cash)
              Card(
                child: ListTile(
                  leading: const IconTile(icon: Icons.payments_outlined, tone: Tone.warning),
                  title: Text(t.orderRef(formatRef(o.ref))),
                  subtitle: Text(o.buyerName),
                  trailing: Text(context.sdg(o.sub.itemsSdg), style: theme.textTheme.titleSmall),
                ),
              ),
          ],
          SectionHeader(
            title: t.statement,
            padding: const EdgeInsets.fromLTRB(Space.xs, Space.xl, 0, Space.sm),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.lg),
              child: Column(children: [for (final l in money.lines) LedgerTile(line: l)]),
            ),
          ),
          SectionHeader(
            title: t.payouts,
            padding: const EdgeInsets.fromLTRB(Space.xs, Space.xl, 0, Space.sm),
          ),
          for (final p in money.payouts)
            Card(
              child: ListTile(
                leading: const IconTile(icon: Icons.account_balance_outlined, tone: Tone.success),
                title: Text(context.sdg(p.amountSdg)),
                subtitle: Text('${context.date(p.from)} – ${context.date(p.to)}'),
                trailing: StatusPill(
                  label: switch (p.status) {
                    PayoutStatus.paid => t.payoutPaid,
                    PayoutStatus.approved => t.payoutApproved,
                    PayoutStatus.draft => t.payoutDraft,
                  },
                  tone: p.status == PayoutStatus.paid ? Tone.success : Tone.info,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class StaffScreen extends ConsumerWidget {
  const StaffScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final staff = ref.watch(staffProvider);
    final now = ref.watch(clockProvider)();
    return Scaffold(
      appBar: AppBar(title: Text(t.moreStaff)),
      body: ListView(
        padding: Space.pageInsets,
        children: [
          InfoBanner(tone: Tone.neutral, icon: Icons.lock_outline, message: t.staffInviteBody),
          const SizedBox(height: Space.md),
          for (final s in staff)
            Card(
              child: ListTile(
                leading: InitialsAvatar(name: s.name, size: 44),
                title: Text(s.name),
                subtitle: Text('${s.email}\n${t.lastActive(context.core.ago(s.lastActive, now))}'),
                isThreeLine: true,
                trailing: StatusPill(
                  label: s.role == StaffRole.owner ? t.staffOwner : t.staffMember,
                  tone: s.role == StaffRole.owner ? Tone.brand : Tone.neutral,
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: BottomActionBar(
        child: FilledButton.icon(
          onPressed: () async {
            final controller = TextEditingController();
            final email = await showDialog<String>(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(t.staffInvite),
                content: TextField(
                  controller: controller,
                  keyboardType: TextInputType.emailAddress,
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(labelText: t.fieldEmail),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(context.core.actionCancel),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, controller.text.trim()),
                    child: Text(t.staffInvite),
                  ),
                ],
              ),
            );
            controller.dispose();
            if (email == null || email.isEmpty) return;
            ref.read(staffProvider.notifier).invite(email);
            if (context.mounted) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text(t.staffInviteSent)));
            }
          },
          icon: const Icon(Icons.person_add_alt_outlined),
          label: Text(t.staffInvite),
        ),
      ),
    );
  }
}

class InsightsScreen extends ConsumerStatefulWidget {
  const InsightsScreen({super.key});

  @override
  ConsumerState<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends ConsumerState<InsightsScreen> {
  var _table = false;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = Theme.of(context);
    final days = ref.watch(weekSalesProvider);
    final catalogue = ref.watch(catalogueProvider);
    final shop = catalogue.shop('sh-nour');
    final total = days.fold(0, (s, d) => s + d.sdg);
    final orders = days.fold(0, (s, d) => s + d.orders);
    const top = [('pt-h4-halogen', 14), ('pt-h4-led', 9), ('pt-battery-70', 4)];

    return Scaffold(
      appBar: AppBar(title: Text(t.moreInsights)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Space.page, Space.lg, Space.page, Space.xxl),
        children: [
          Row(
            children: [
              Expanded(
                child: StatTile(label: t.insightsOrders, value: '$orders'),
              ),
              const SizedBox(width: Space.sm),
              Expanded(
                child: StatTile(
                  label: t.insightsAvgOrder,
                  value: context.core.thousands(
                    '${orders == 0 ? 0 : (total / orders / 1000).round()}',
                  ),
                ),
              ),
              const SizedBox(width: Space.sm),
              Expanded(
                child: StatTile(
                  label: t.insightsRating,
                  value: shop.rating.toStringAsFixed(1),
                  icon: Icons.star_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.md),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(Space.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t.insightsSales7, style: theme.textTheme.titleMedium),
                            Text(context.sdg(total), style: theme.textTheme.headlineSmall),
                          ],
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => setState(() => _table = !_table),
                        icon: Icon(_table ? Icons.bar_chart : Icons.table_rows_outlined),
                        label: Text(_table ? t.showChart : t.showTable),
                      ),
                    ],
                  ),
                  const SizedBox(height: Space.lg),
                  if (_table)
                    Table(
                      columnWidths: const {
                        0: FlexColumnWidth(2),
                        1: FlexColumnWidth(),
                        2: FlexColumnWidth(2),
                      },
                      children: [
                        TableRow(
                          children: [
                            for (final h in [t.colDay, t.colOrders, t.colSales])
                              Padding(
                                padding: const EdgeInsets.only(bottom: Space.sm),
                                child: Text(h, style: theme.textTheme.labelMedium),
                              ),
                          ],
                        ),
                        for (final d in days)
                          TableRow(
                            decoration: BoxDecoration(
                              border: Border(
                                top: BorderSide(color: theme.colorScheme.outlineVariant),
                              ),
                            ),
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: Space.sm),
                                child: Text(
                                  context.dayOfMonth(d.day.add(const Duration(hours: 10))),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: Space.sm),
                                child: Text(
                                  '${d.orders}',
                                  style: const TextStyle(fontFeatures: AppTypography.tabular),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: Space.sm),
                                child: Text(
                                  context.sdg(d.sdg),
                                  style: const TextStyle(fontFeatures: AppTypography.tabular),
                                ),
                              ),
                            ],
                          ),
                      ],
                    )
                  else
                    SalesChart(days: days),
                ],
              ),
            ),
          ),
          SectionHeader(
            title: t.insightsTop,
            padding: const EdgeInsets.fromLTRB(Space.xs, Space.xl, 0, Space.sm),
          ),
          Card(
            child: Column(
              children: [
                for (final (i, (partId, sold)) in top.indexed) ...[
                  if (i > 0) const Divider(indent: 72),
                  ListTile(
                    leading: PartThumb(
                      icon: catalogue.category(catalogue.part(partId).categoryId).icon,
                      size: 44,
                    ),
                    title: Text(catalogue.part(partId).name.tr(context)),
                    subtitle: Text(t.soldCount(sold)),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
