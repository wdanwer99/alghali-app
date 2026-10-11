import 'package:alghali_core/alghali_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'app.dart';
import 'features/auth/auth_screens.dart';
import 'features/shell/partner_shells.dart';
import 'features/shop/add_listing_screen.dart';
import 'features/shop/money_screens.dart';
import 'features/shop/quotes_screen.dart';
import 'features/shop/shop_home_screen.dart';
import 'features/shop/shop_more_screen.dart';
import 'features/shop/shop_order_screen.dart';
import 'features/shop/shop_orders_screen.dart';
import 'features/shop/stock_screen.dart';
import 'features/tech/earnings_screen.dart';
import 'features/tech/job_screen.dart';
import 'features/tech/schedule_screen.dart';
import 'features/tech/tech_jobs_screen.dart';
import 'features/tech/tech_profile_screen.dart';
import 'state/session.dart';

abstract final class Routes {
  static const welcome = '/welcome';
  static const signIn = '/sign-in';
  static const role = '/role';

  static const shopHome = '/shop/home';
  static const shopOrders = '/shop/orders';
  static const shopStock = '/shop/stock';
  static const shopQuotes = '/shop/quotes';
  static const shopMore = '/shop/more';
  static const shopAdd = '/shop/add';
  static const shopMoney = '/shop/money';
  static const shopStaff = '/shop/staff';
  static const shopInsights = '/shop/insights';
  static String shopOrder(String id) => '/shop/order/$id';

  static const techJobs = '/tech/jobs';
  static const techSchedule = '/tech/schedule';
  static const techEarnings = '/tech/earnings';
  static const techProfile = '/tech/profile';
  static String techJob(String id) => '/tech/job/$id';

  static String homeOf(PartnerRole role) => role == PartnerRole.shop ? shopHome : techJobs;
}

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final loc = state.matchedLocation;
      if (!ref.read(localeControllerProvider).chosen) {
        return loc == Routes.welcome ? null : Routes.welcome;
      }
      final session = ref.read(partnerSessionProvider);
      if (!session.signedIn) return loc == Routes.signIn ? null : Routes.signIn;
      final role = session.role;
      if (role == null) return loc == Routes.role ? null : Routes.role;
      if (loc == '/' || loc == Routes.welcome || loc == Routes.signIn) return Routes.homeOf(role);
      // Stay inside the active role's screens.
      if (role == PartnerRole.shop && loc.startsWith('/tech')) return Routes.shopHome;
      if (role == PartnerRole.technician && loc.startsWith('/shop')) return Routes.techJobs;
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (_, _) => const SizedBox.shrink()),
      GoRoute(
        path: Routes.welcome,
        builder: (context, state) => LanguagePickerScreen(
          variant: MarkVariant.partner,
          title: context.t.welcomeTitle,
          points: [
            WelcomePoint(Icons.receipt_long_outlined, context.t.welcomePointOrders),
            WelcomePoint(Icons.inventory_2_outlined, context.t.welcomePointStock),
            WelcomePoint(Icons.handyman_outlined, context.t.welcomePointJobs),
          ],
          onContinue: () => context.go(Routes.signIn),
        ),
      ),
      GoRoute(path: Routes.signIn, builder: (_, _) => const SignInScreen()),
      GoRoute(path: Routes.role, builder: (_, _) => const RoleScreen()),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => ShopShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.shopHome, builder: (_, _) => const ShopHomeScreen())],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.shopOrders,
                builder: (_, state) => ShopOrdersScreen(tab: state.uri.queryParameters['tab']),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.shopStock,
                builder: (_, state) => StockScreen(filter: state.uri.queryParameters['filter']),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.shopQuotes, builder: (_, _) => const QuotesScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.shopMore, builder: (_, _) => const ShopMoreScreen())],
          ),
        ],
      ),
      GoRoute(
        path: '/shop/order/:id',
        builder: (_, s) => ShopOrderScreen(orderId: s.pathParameters['id']!),
      ),
      GoRoute(path: Routes.shopAdd, builder: (_, _) => const AddListingScreen()),
      GoRoute(path: Routes.shopMoney, builder: (_, _) => const MoneyScreen()),
      GoRoute(path: Routes.shopStaff, builder: (_, _) => const StaffScreen()),
      GoRoute(path: Routes.shopInsights, builder: (_, _) => const InsightsScreen()),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => TechShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.techJobs, builder: (_, _) => const TechJobsScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.techSchedule, builder: (_, _) => const ScheduleScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.techEarnings, builder: (_, _) => const EarningsScreen())],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: Routes.techProfile, builder: (_, _) => const TechProfileScreen()),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/tech/job/:id',
        builder: (_, s) => JobScreen(jobId: s.pathParameters['id']!),
      ),
    ],
  );
});
