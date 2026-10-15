import 'package:alghali_core/alghali_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../state/session.dart';
import '../../state/shop.dart';
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
    final settings = ref.watch(platformSettingsProvider);
    final now = ref.watch(clockProvider)();
    final orders = ref.watch(shopOrdersProvider).value ?? const <ShopSubOrder>[];
    final cash = orders.where((o) => o.cashDue && !o.isDone).toList();

    return Scaffold(
      appBar: AppBar(title: Text(t.moreMoney)),
      body: AsyncBody(
        value: ref.watch(shopStatementProvider),
        onRefresh: () => ref.read(shopStatementProvider.notifier).refresh(),
        data: (statement) {
          final balance = statement?.closingSdg ?? 0;
          final lines = [...?statement?.lines]..sort((a, b) => b.at.compareTo(a.at));
          final payouts = [...?statement?.payouts]..sort((a, b) => b.from.compareTo(a.from));
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
                        balance >= 0 ? t.moneyOwedToYou : t.moneyYouOwe,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.onBrandSurfaceMuted,
                        ),
                      ),
                      Text(
                        context.sdg(balance.abs()),
                        style: theme.textTheme.displaySmall?.copyWith(color: colors.onBrandSurface),
                      ),
                      const SizedBox(height: Space.sm),
                      Text(
                        t.nextPayout(context.day(nextSunday(now))),
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
                      trailing: Text(
                        context.sdg(o.subOrder.itemsSdg + o.subOrder.deliveryFeeSdg),
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                  ),
              ],
              SectionHeader(
                title: t.statement,
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

class PayoutTile extends StatelessWidget {
  const PayoutTile({super.key, required this.payout});

  final Payout payout;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final p = payout;
    return Card(
      child: ListTile(
        leading: const IconTile(icon: Icons.account_balance_outlined, tone: Tone.success),
        title: Text(context.sdg(p.amountSdg)),
        subtitle: Text(context.date(p.paidAt ?? p.from)),
        trailing: StatusPill(
          label: switch (p.status) {
            PayoutStatus.paid => t.payoutPaid,
            PayoutStatus.approved => t.payoutApproved,
            PayoutStatus.draft => t.payoutDraft,
          },
          tone: p.status == PayoutStatus.paid ? Tone.success : Tone.info,
        ),
      ),
    );
  }
}

class StaffScreen extends ConsumerWidget {
  const StaffScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final me = ref.watch(partnerSessionProvider.select((s) => s.userId));

    Future<void> invite() async {
      final email = await askText(
        context,
        title: t.staffInvite,
        label: t.fieldEmail,
        submit: t.staffInvite,
        keyboardType: TextInputType.emailAddress,
      );
      if (email == null || !context.mounted) return;
      try {
        await ref.read(staffProvider.notifier).add(email);
        if (context.mounted) showSnack(context, t.staffInviteSent);
      } on BackendException catch (e) {
        if (context.mounted) showError(context, e);
      }
    }

    Future<void> remove(StaffMember s) async {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(t.staffRemoveTitle(s.name)),
          content: Text(t.staffRemoveBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.core.actionCancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(context.core.actionRemove),
            ),
          ],
        ),
      );
      if (ok != true || !context.mounted) return;
      try {
        await ref.read(staffProvider.notifier).remove(s.id);
      } on BackendException catch (e) {
        if (context.mounted) showError(context, e);
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text(t.moreStaff)),
      body: AsyncBody(
        value: ref.watch(staffProvider),
        onRefresh: () => ref.read(staffProvider.notifier).refresh(),
        data: (staff) => ListView(
          padding: Space.pageInsets,
          children: [
            InfoBanner(tone: Tone.neutral, icon: Icons.lock_outline, message: t.staffInviteBody),
            const SizedBox(height: Space.md),
            for (final s in staff)
              Card(
                child: ListTile(
                  leading: InitialsAvatar(name: s.name.isEmpty ? s.email : s.name, size: 44),
                  title: Text(s.name.isEmpty ? s.email : s.name),
                  subtitle: Text('${s.email}\n${t.staffAdded(context.date(s.lastActive))}'),
                  isThreeLine: true,
                  trailing: s.role == StaffRole.owner || s.id == me
                      ? StatusPill(
                          label: s.role == StaffRole.owner ? t.staffOwner : t.staffMember,
                          tone: s.role == StaffRole.owner ? Tone.brand : Tone.neutral,
                        )
                      : IconButton(
                          tooltip: context.core.actionRemove,
                          onPressed: () => remove(s),
                          icon: const Icon(Icons.person_remove_outlined),
                        ),
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: BottomActionBar(
        child: FilledButton.icon(
          onPressed: invite,
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
    return Scaffold(
      appBar: AppBar(title: Text(t.moreInsights)),
      body: AsyncBody(
        value: ref.watch(shopInsightsProvider),
        onRefresh: () => ref.read(shopInsightsProvider.notifier).refresh(),
        data: (insights) {
          final days = insights?.days ?? const <SalesDay>[];
          final top = insights?.top ?? const <TopSeller>[];
          final total = days.fold(0, (s, d) => s + d.sdg);
          final orders = days.fold(0, (s, d) => s + d.orders);
          return ListView(
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
                      value: (insights?.ratingCount ?? 0) == 0
                          ? '—'
                          : insights!.rating.toStringAsFixed(1),
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
                      if (days.isEmpty)
                        const SizedBox.shrink()
                      else if (_table)
                        _SalesTable(days: days)
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
              if (top.isEmpty)
                Text(t.insightsNoSales, style: theme.textTheme.bodyMedium)
              else
                Card(
                  child: Column(
                    children: [
                      for (final (i, s) in top.indexed) ...[
                        if (i > 0) const Divider(indent: 72),
                        ListTile(
                          leading: const IconTile(icon: Icons.inventory_2_outlined, size: 44),
                          title: Text(s.title.tr(context)),
                          subtitle: Text(t.soldCount(s.qty)),
                          trailing: Text(
                            context.sdg(s.salesSdg),
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontFeatures: AppTypography.tabular,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _SalesTable extends StatelessWidget {
  const _SalesTable({required this.days});

  final List<SalesDay> days;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = Theme.of(context);
    return Table(
      columnWidths: const {0: FlexColumnWidth(2), 1: FlexColumnWidth(), 2: FlexColumnWidth(2)},
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
              border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant)),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: Space.sm),
                child: Text(context.dayOfMonth(d.day.add(const Duration(hours: 10)))),
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
    );
  }
}
