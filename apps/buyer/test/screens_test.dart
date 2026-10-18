import 'package:alghali_buyer/router.dart';
import 'package:alghali_buyer/state/cart.dart';
import 'package:alghali_core/alghali_core.dart';
import 'package:alghali_core/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'support/backend.dart';

/// Every screen, in Arabic (right-to-left) and English (left-to-right), on a 360 dp phone
/// with the data the dev server really returns: nothing overflows or throws, and each
/// screen shows its own title.
void main() {
  setUpAll(loadAppFonts);

  final orders = (fixture('orders') as List).cast<Json>();
  final bookings = (fixture('my_bookings') as List).cast<Json>();
  final order = orders.firstWhere((o) => (o['sub_orders'] as List).isNotEmpty);
  final booking = bookings.firstWhere((b) => b['status'] == 'ACCEPTED');
  final part = ((fixture('part_detail') as Json)['part'] as Json)['id'] as String;
  final shop =
      (((fixture('search_shop') as List).first as Json)['listings'] as List)
              .cast<Json>()
              .first['shop_id']
          as String;
  final car = '8f1c3c1e-0000-4000-8000-000000000001';
  final snapshot = fixture('catalogue_snapshot') as Json;
  final hilux = (snapshot['variants'] as List).cast<Json>().firstWhere((v) {
    final model = (snapshot['models'] as List).cast<Json>().firstWhere(
      (m) => m['id'] == v['model_id'],
    );
    return model['name_en'] == 'Hilux';
  })['id'];

  final screens = <String, ({String route, String ar, String en})>{
    'home': (route: Routes.home, ar: 'تسوّق حسب القسم', en: 'Shop by category'),
    'street': (route: Routes.street, ar: 'الكل', en: 'All'),
    'cart': (route: Routes.cart, ar: 'السلة', en: 'Cart'),
    'orders': (route: Routes.orders, ar: 'طلباتي', en: 'My orders'),
    'bookings tab': (route: '${Routes.orders}?tab=bookings', ar: 'طلباتي', en: 'My orders'),
    'requests tab': (route: '${Routes.orders}?tab=requests', ar: 'طلباتي', en: 'My orders'),
    'account': (route: Routes.account, ar: 'حسابي', en: 'Account'),
    'search': (route: Routes.searchFor(q: 'لمبات'), ar: 'لمبة هالوجين H4', en: 'H4 halogen bulb'),
    'part': (route: Routes.part(part), ar: 'قارن بين', en: 'Compare'),
    'shop': (route: Routes.shop(shop), ar: 'القطع', en: 'Parts'),
    'garage': (route: Routes.garage, ar: 'سياراتي', en: 'My garage'),
    'add car': (route: Routes.addCar, ar: 'اختر الشركة المصنّعة', en: 'Choose the make'),
    'checkout': (route: Routes.checkout, ar: 'إتمام الطلب', en: 'Checkout'),
    'order': (route: Routes.order(order['id'] as String), ar: 'رقم الطلب', en: 'Order number'),
    'booking': (
      route: Routes.booking(booking['id'] as String),
      ar: 'رمز إنهاء العمل',
      en: 'Job code',
    ),
    'book a fitting': (route: Routes.bookExternal, ar: 'حجز التركيب', en: 'Book fitting'),
    'new request': (route: Routes.newRequest, ar: 'اطلب بالصورة', en: 'Request by photo'),
    'window tint': (route: Routes.tint, ar: 'ما حجم سيارتك؟', en: 'What size is your car?'),
    'notifications': (route: Routes.notifications, ar: 'الإشعارات', en: 'Notifications'),
    'chat': (route: Routes.chat(shop), ar: 'اكتب رسالة', en: 'Write a message'),
    'chats': (route: Routes.chats, ar: 'المحادثات', en: 'Messages'),
    'complaints': (route: Routes.complaints, ar: 'شكاواي', en: 'My complaints'),
    'addresses': (route: Routes.addresses, ar: 'عناويني', en: 'My addresses'),
    'sign in': (route: Routes.signIn, ar: 'تسجيل الدخول', en: 'Sign in'),
    'sign up': (route: Routes.signUp, ar: 'إنشاء حساب', en: 'Create account'),
  };

  for (final locale in ['ar', 'en']) {
    for (final MapEntry(key: name, value: s) in screens.entries) {
      testWidgets('$name ($locale)', (tester) async {
        final backend = FakeBackend();
        final c = await pumpApp(
          tester,
          backend,
          locale: locale,
          prefs: {
            'garage': ['$car|$hilux'],
            'garage_selected': car,
            'chat:$buyerId:$shop': 'conv-1',
          },
        );
        if (name == 'cart' || name == 'checkout') {
          final detail = PartDetail.fromJson(fixture('part_detail') as Json);
          c.read(cartProvider.notifier).addListing(detail.offers.first.listing, detail.part);
        }
        c.read(routerProvider).go(s.route);
        await settle(tester);
        expect(tester.takeException(), isNull);
        expect(
          Directionality.of(tester.element(find.byType(Scaffold).last)),
          locale == 'ar' ? TextDirection.rtl : TextDirection.ltr,
        );
        expect(find.textContaining(locale == 'ar' ? s.ar : s.en), findsWidgets);
      });
    }
  }
}
