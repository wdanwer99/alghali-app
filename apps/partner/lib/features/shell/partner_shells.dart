import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../state/shop_state.dart';
import '../../state/tech_state.dart';

class _Shell extends StatelessWidget {
  const _Shell({required this.shell, required this.destinations});

  final StatefulNavigationShell shell;
  final List<NavigationDestination> destinations;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: shell,
    bottomNavigationBar: DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
      ),
      child: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
        destinations: destinations,
      ),
    ),
  );
}

NavigationDestination _dest(IconData icon, IconData selected, String label, [int badge = 0]) =>
    NavigationDestination(
      icon: Badge(isLabelVisible: badge > 0, label: Text('$badge'), child: Icon(icon)),
      selectedIcon: Badge(isLabelVisible: badge > 0, label: Text('$badge'), child: Icon(selected)),
      label: label,
    );

/// Shop: Home · Orders · Stock · Quotes · More.
class ShopShell extends ConsumerWidget {
  const ShopShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final newOrders = ref.watch(shopOrdersProvider).where((o) => o.isNew).length;
    final openQuotes = ref.watch(quotesProvider).where((q) => q.myOfferSdg == null).length;
    return _Shell(
      shell: shell,
      destinations: [
        _dest(Icons.dashboard_outlined, Icons.dashboard, t.shopNavHome),
        _dest(Icons.receipt_long_outlined, Icons.receipt_long, t.shopNavOrders, newOrders),
        _dest(Icons.inventory_2_outlined, Icons.inventory_2, t.shopNavStock),
        _dest(Icons.request_quote_outlined, Icons.request_quote, t.shopNavQuotes, openQuotes),
        _dest(Icons.menu, Icons.menu, t.shopNavMore),
      ],
    );
  }
}

/// Technician: Jobs · Schedule · Earnings · Profile.
class TechShell extends ConsumerWidget {
  const TechShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final offers = ref.watch(techJobsProvider).offers.length;
    return _Shell(
      shell: shell,
      destinations: [
        _dest(Icons.handyman_outlined, Icons.handyman, t.techNavJobs, offers),
        _dest(Icons.calendar_month_outlined, Icons.calendar_month, t.techNavSchedule),
        _dest(Icons.savings_outlined, Icons.savings, t.techNavEarnings),
        _dest(Icons.person_outline, Icons.person, t.techNavProfile),
      ],
    );
  }
}
