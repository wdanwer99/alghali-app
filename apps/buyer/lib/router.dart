import 'package:alghali_core/alghali_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'app.dart';
import 'features/account/account_screen.dart';
import 'features/auth/auth_screens.dart';
import 'features/booking/booking_flow_screen.dart';
import 'features/cart/cart_screen.dart';
import 'features/chat/chat_screen.dart';
import 'features/checkout/bankak_screen.dart';
import 'features/checkout/checkout_screen.dart';
import 'features/garage/garage_screens.dart';
import 'features/home/home_screen.dart';
import 'features/home/notifications_screen.dart';
import 'features/orders/booking_screen.dart';
import 'features/orders/order_screen.dart';
import 'features/orders/orders_screen.dart';
import 'features/part/part_screen.dart';
import 'features/requests/request_screens.dart';
import 'features/search/search_screen.dart';
import 'features/shell/app_shell.dart';
import 'features/shops/shop_screen.dart';
import 'features/shops/street_screen.dart';

abstract final class Routes {
  static const welcome = '/welcome';
  static const signIn = '/sign-in';
  static const signUp = '/sign-up';
  static const home = '/home';
  static const street = '/street';
  static const cart = '/cart';
  static const orders = '/orders';
  static const account = '/account';
  static const search = '/search';
  static const garage = '/garage';
  static const addCar = '/garage/add';
  static const bookExternal = '/book/new';
  static const checkout = '/checkout';
  static const newRequest = '/request/new';
  static const notifications = '/notifications';

  static String part(String id) => '/part/$id';
  static String shop(String id) => '/shop/$id';
  static String bookLine(String lineId) => '/book/line/$lineId';
  static String payOrder(String id) => '/pay/order/$id';
  static String payBooking(String id) => '/pay/booking/$id';
  static String order(String id) => '/order/$id';
  static String booking(String id) => '/booking/$id';
  static String request(String id) => '/request/$id';
  static String chat(String shopId) => '/chat/$shopId';

  static String searchFor({String? q, String? categoryId}) =>
      Uri(path: search, queryParameters: {'q': ?q, 'cat': ?categoryId}).toString();

  /// Sign in, then come back to [next].
  static String signInThen(String next) =>
      Uri(path: signIn, queryParameters: {'next': next}).toString();
}

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: Routes.home,
    redirect: (context, state) {
      final chosen = ref.read(localeControllerProvider).chosen;
      if (!chosen && state.matchedLocation != Routes.welcome) return Routes.welcome;
      return null;
    },
    routes: [
      GoRoute(
        path: Routes.welcome,
        builder: (context, state) => LanguagePickerScreen(
          title: context.t.welcomeTitle,
          points: [
            WelcomePoint(Icons.directions_car_outlined, context.t.welcomePointFit),
            WelcomePoint(Icons.storefront_outlined, context.t.welcomePointCompare),
            WelcomePoint(Icons.handyman_outlined, context.t.welcomePointInstall),
          ],
          onContinue: () => context.go(Routes.home),
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.home, builder: (_, _) => const HomeScreen())],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.street,
                builder: (_, state) => StreetScreen(focusShopId: state.uri.queryParameters['shop']),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.cart, builder: (_, _) => const CartScreen())],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.orders,
                builder: (_, state) => OrdersScreen(tab: state.uri.queryParameters['tab']),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.account, builder: (_, _) => const AccountScreen())],
          ),
        ],
      ),
      GoRoute(
        path: Routes.signIn,
        builder: (_, state) => SignInScreen(next: state.uri.queryParameters['next']),
      ),
      GoRoute(
        path: Routes.signUp,
        builder: (_, state) => SignUpScreen(next: state.uri.queryParameters['next']),
      ),
      GoRoute(
        path: Routes.search,
        builder: (_, state) => SearchScreen(
          initialQuery: state.uri.queryParameters['q'] ?? '',
          categoryId: state.uri.queryParameters['cat'],
        ),
      ),
      GoRoute(
        path: '/part/:id',
        builder: (_, state) => PartScreen(partId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/shop/:id',
        builder: (_, state) => ShopScreen(shopId: state.pathParameters['id']!),
      ),
      GoRoute(path: Routes.garage, builder: (_, _) => const GarageScreen()),
      GoRoute(path: Routes.addCar, builder: (_, _) => const AddCarScreen()),
      GoRoute(path: Routes.bookExternal, builder: (_, _) => const BookingFlowScreen()),
      GoRoute(
        path: '/book/line/:id',
        builder: (_, state) => BookingFlowScreen(lineId: state.pathParameters['id']),
      ),
      GoRoute(path: Routes.checkout, builder: (_, _) => const CheckoutScreen()),
      GoRoute(
        path: '/pay/:kind/:id',
        builder: (_, state) => BankakScreen(
          id: state.pathParameters['id']!,
          isBooking: state.pathParameters['kind'] == 'booking',
        ),
      ),
      GoRoute(
        path: '/order/:id',
        builder: (_, state) => OrderScreen(orderId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/booking/:id',
        builder: (_, state) => BookingScreen(bookingId: state.pathParameters['id']!),
      ),
      GoRoute(path: Routes.newRequest, builder: (_, _) => const NewRequestScreen()),
      GoRoute(
        path: '/request/:id',
        builder: (_, state) => RequestScreen(requestId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/chat/:shopId',
        builder: (_, state) => ChatScreen(shopId: state.pathParameters['shopId']!),
      ),
      GoRoute(path: Routes.notifications, builder: (_, _) => const NotificationsScreen()),
    ],
  );
});
