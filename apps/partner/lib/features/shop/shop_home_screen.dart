import 'package:alghali_core/alghali_core.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../router.dart';
import '../../state/session.dart';
import '../../state/shop_state.dart';
import '../../widgets/partner_widgets.dart';
import 'shop_orders_screen.dart';

class ShopHomeScreen extends ConsumerWidget {
  const ShopHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final session = ref.watch(partnerSessionProvider);
    final shop = ref.watch(catalogueProvider).shop(session.shopId);
    final orders = ref.watch(shopOrdersProvider);
    final stock = ref.watch(stockProvider);
    final quotes = ref.watch(quotesProvider);
    final open = ref.watch(shopOpenProvider);
    final sales = ref.watch(weekSalesProvider);

    final newOrders = orders.where((o) => o.isNew).toList();
    final preparing = orders.where((o) => o.isPreparing).length;
    final cashDue = orders
        .where((o) => o.paymentStatus == PaymentStatus.due && !o.isDone)
        .fold(0, (s, o) => s + o.sub.itemsSdg);
    final low = stock.where((s) => s.isLow || s.qty == 0).length;
    final openQuotes = quotes.where((q) => q.myOfferSdg == null).length;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(
              color: colors.brandSurface,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(Space.page, Space.lg, Space.page, Space.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const AlghaliMark(size: 40, variant: MarkVariant.partner),
                          const SizedBox(width: Space.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  t.hello(session.name ?? ''),
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: colors.onBrandSurfaceMuted,
                                  ),
                                ),
                                Text(
                                  shop.name.tr(context),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    color: colors.onBrandSurface,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const DemoBadge(onDark: true),
                        ],
                      ),
                      const SizedBox(height: Space.lg),
                      HeaderSwitch(
                        value: open,
                        onChanged: ref.read(shopOpenProvider.notifier).set,
                        title: open ? t.shopIsOpen : t.shopIsClosed,
                        icon: open ? Icons.storefront : Icons.store_mall_directory_outlined,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.page, Space.lg, Space.page, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: StatTile(
                          label: t.kpiNewOrders,
                          value: '${newOrders.length}',
                          icon: Icons.move_to_inbox_outlined,
                          tone: newOrders.isEmpty ? Tone.neutral : Tone.warning,
                          onTap: () => context.go(Routes.shopOrders),
                        ),
                      ),
                      const SizedBox(width: Space.md),
                      Expanded(
                        child: StatTile(
                          label: t.kpiToPrepare,
                          value: '$preparing',
                          icon: Icons.inventory_outlined,
                          onTap: () => context.go(
                            Uri(
                              path: Routes.shopOrders,
                              queryParameters: {'tab': 'preparing'},
                            ).toString(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Space.md),
                  Row(
                    children: [
                      Expanded(
                        child: StatTile(
                          label: t.kpiCashToCollect,
                          value: context.sdg(cashDue),
                          icon: Icons.payments_outlined,
                          onTap: () => context.push(Routes.shopMoney),
                        ),
                      ),
                      const SizedBox(width: Space.md),
                      Expanded(
                        child: StatTile(
                          label: t.kpiTodaySales,
                          value: context.sdg(sales.last.sdg),
                          icon: Icons.trending_up,
                          tone: Tone.success,
                          onTap: () => context.push(Routes.shopInsights),
                        ),
                      ),
                    ],
                  ),
                  SectionHeader(
                    title: t.needsAction,
                    padding: const EdgeInsets.fromLTRB(Space.xs, Space.xl, 0, Space.sm),
                  ),
                  if (newOrders.isEmpty)
                    InfoBanner(tone: Tone.success, message: t.allCaughtUp)
                  else
                    for (final o in newOrders) ...[
                      ShopOrderCard(order: o),
                      const SizedBox(height: Space.sm),
                    ],
                  const SizedBox(height: Space.lg),
                  Row(
                    children: [
                      Expanded(
                        child: _Quick(
                          icon: Icons.add_a_photo_outlined,
                          label: t.quickAddPart,
                          onTap: () => context.push(Routes.shopAdd),
                        ),
                      ),
                      const SizedBox(width: Space.sm),
                      Expanded(
                        child: _Quick(
                          icon: Icons.price_change_outlined,
                          label: t.quickUpdatePrices,
                          onTap: () => context.go(Routes.shopStock),
                        ),
                      ),
                      const SizedBox(width: Space.sm),
                      Expanded(
                        child: _Quick(
                          icon: Icons.request_quote_outlined,
                          label: t.quickQuotes,
                          badge: openQuotes,
                          onTap: () => context.go(Routes.shopQuotes),
                        ),
                      ),
                    ],
                  ),
                  if (low > 0) ...[
                    const SizedBox(height: Space.lg),
                    TapCard(
                      onTap: () => context.go(
                        Uri(path: Routes.shopStock, queryParameters: {'filter': 'low'}).toString(),
                      ),
                      child: Row(
                        children: [
                          const IconTile(icon: Icons.warning_amber_rounded, tone: Tone.warning),
                          const SizedBox(width: Space.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(t.lowStock, style: theme.textTheme.titleSmall),
                                Text(t.lowStockBody(low), style: theme.textTheme.bodySmall),
                              ],
                            ),
                          ),
                          Icon(
                            Directionality.of(context) == TextDirection.rtl
                                ? Icons.chevron_left
                                : Icons.chevron_right,
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: Space.lg),
                  DemoControls(
                    label: t.demoNewOrder,
                    onTap: () => ref.read(shopOrdersProvider.notifier).demoNewOrder(),
                  ),
                  const SizedBox(height: Space.xxl),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Quick extends StatelessWidget {
  const _Quick({required this.icon, required this.label, required this.onTap, this.badge = 0});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) => TapCard(
    onTap: onTap,
    padding: const EdgeInsets.symmetric(horizontal: Space.xs, vertical: Space.md),
    child: Column(
      children: [
        Badge(
          isLabelVisible: badge > 0,
          label: Text('$badge'),
          child: IconTile(icon: icon, size: 44, tone: Tone.brand),
        ),
        const SizedBox(height: Space.sm),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 2,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );
}
