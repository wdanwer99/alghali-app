import 'package:alghali_core/alghali_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'app.dart';
import 'features/auth/apply_screens.dart';
import 'features/auth/auth_screens.dart';
import 'features/shared/chat_screens.dart';
import 'features/shared/complaints_screens.dart';
import 'features/shared/notifications_screen.dart';
import 'features/shell/partner_shells.dart';
import 'features/shop/add_listing_screen.dart';
import 'features/shop/money_screens.dart';
import 'features/shop/quotes_screen.dart';
import 'features/shop/shop_home_screen.dart';
import 'features/shop/shop_location.dart';
import 'features/shop/shop_more_screen.dart';
import 'features/shop/shop_order_screen.dart';
import 'features/shop/shop_orders_screen.dart';
import 'features/shop/shop_profile_screen.dart';
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
  static const signUp = '/sign-up';
  static const role = '/role';
  static const apply = '/apply';
  static const applyShop = '/apply/shop';
  static const applyTech = '/apply/tech';
  static const pickLocation = '/location';
  static const notifications = '/notifications';
  static const complaints = '/complaints';
  static String complaint(String id) => '/complaints/$id';

  static const shopHome = '/shop/home';
  static const shopOrders = '/shop/orders';
  static const shopStock = '/shop/stock';
  static const shopQuotes = '/shop/quotes';
  static const shopMore = '/shop/more';
  static const shopAdd = '/shop/add';
  static const shopMoney = '/shop/money';
  static const shopStaff = '/shop/staff';
  static const shopInsights = '/shop/insights';
  static const shopProfile = '/shop/profile';
  static const shopChats = '/shop/chats';
  static String shopOrder(String id) => '/shop/order/$id';
  static String shopChat(String conversationId) => '/shop/chat/$conversationId';

  static const techJobs = '/tech/jobs';
  static const techSchedule = '/tech/schedule';
  static const techEarnings = '/tech/earnings';
  static const techProfile = '/tech/profile';
  static String techJob(String id) => '/tech/job/$id';

  static String homeOf(PartnerRole role) => role == PartnerRole.shop ? shopHome : techJobs;
}

final routerProvider = Provider<GoRouter>((ref) {
  // Sign-in, applying and an admin's decision change where the partner belongs.
  final refresh = ValueNotifier(0);
  ref.listen(partnerSessionProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final loc = state.matchedLocation;
      if (!ref.read(localeControllerProvider).chosen) {
        return loc == Routes.welcome ? null : Routes.welcome;
      }
      final session = ref.read(partnerSessionProvider);
      if (!session.signedIn) {
        return loc == Routes.signIn || loc == Routes.signUp ? null : Routes.signIn;
      }
      // Signed in, the account still on its way: wait on the blank start page.
      if (!session.loaded) return loc == '/' ? null : '/';
      // The map picker opens from applying as well as from the shop's profile.
      final applying = loc.startsWith(Routes.apply) || loc == Routes.pickLocation;
      if (!session.isPartner) return applying ? null : Routes.apply;
      final role = session.role;
      if (role == null) return loc == Routes.role || applying ? null : Routes.role;
      if (loc == '/' || loc == Routes.welcome || loc == Routes.signIn || loc == Routes.signUp) {
        return Routes.homeOf(role);
      }
      // Stay inside the open home's screens.
      if (role == PartnerRole.shop && loc.startsWith('/tech')) return Routes.shopHome;
      if (role == PartnerRole.technician && loc.startsWith('/shop')) return Routes.techJobs;
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      GoRoute(
        path: Routes.welcome,
        builder: (context, state) => WelcomeTour(
          variant: MarkVariant.partner,
          slides: [
            TourSlide(
              icon: Icons.receipt_long_outlined,
              chips: const [
                Icons.notifications_active_outlined,
                Icons.chat_bubble_outline,
                Icons.handyman_outlined,
              ],
              title: context.t.tourOrdersTitle,
              body: context.t.tourOrdersBody,
            ),
            TourSlide(
              icon: Icons.inventory_2_outlined,
              chips: const [Icons.cloud_off_outlined, Icons.sync, Icons.sell_outlined],
              title: context.t.tourStockTitle,
              body: context.t.tourStockBody,
            ),
            TourSlide(
              icon: Icons.account_balance_wallet_outlined,
              chips: const [Icons.trending_up, Icons.receipt_long_outlined, Icons.star_outline],
              title: context.t.tourEarnTitle,
              body: context.t.tourEarnBody,
            ),
          ],
          onDone: () => context.go(Routes.signIn),
        ),
      ),
      GoRoute(path: Routes.signIn, builder: (_, _) => const SignInScreen()),
      GoRoute(path: Routes.signUp, builder: (_, _) => const SignUpScreen()),
      GoRoute(path: Routes.role, builder: (_, _) => const RoleScreen()),
      GoRoute(path: Routes.apply, builder: (_, _) => const ApplyScreen()),
      GoRoute(path: Routes.applyShop, builder: (_, _) => const ShopApplyScreen()),
      GoRoute(path: Routes.applyTech, builder: (_, _) => const TechApplyScreen()),
      GoRoute(
        path: Routes.pickLocation,
        builder: (_, s) => LocationPickerScreen(initial: s.extra as MapPoint?),
      ),
      GoRoute(path: Routes.notifications, builder: (_, _) => const NotificationsScreen()),
      GoRoute(path: Routes.complaints, builder: (_, _) => const ComplaintsScreen()),
      GoRoute(
        path: '/complaints/:id',
        builder: (_, s) => ComplaintScreen(disputeId: s.pathParameters['id']!),
      ),
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
      GoRoute(path: Routes.shopProfile, builder: (_, _) => const ShopProfileScreen()),
      GoRoute(path: Routes.shopChats, builder: (_, _) => const ShopChatsScreen()),
      GoRoute(
        path: '/shop/chat/:id',
        builder: (_, s) => ChatScreen(conversationId: s.pathParameters['id']!),
      ),
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
