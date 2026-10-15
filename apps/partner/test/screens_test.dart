import 'package:alghali_core/testing.dart';
import 'package:alghali_partner/router.dart';
import 'package:alghali_partner/state/session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'support/backend.dart';

/// Every partner screen, in Arabic (right-to-left) and English (left-to-right), on a
/// 360 dp phone with the data the dev server really returns: nothing overflows or throws,
/// and each screen shows its own text.
void main() {
  setUpAll(loadAppFonts);

  final readyForTech = fixtureList('shop_orders').firstWhere((o) => o['status'] == 'READY');
  final job = fixtureList('tech_upcoming').first;
  final chat = fixtureList('shop_conversations').first;

  final screens = <String, ({String route, String key, Who who, PartnerRole? role})>{
    'shop home': (
      route: Routes.shopHome,
      key: 'needsAction',
      who: Who.shop,
      role: PartnerRole.shop,
    ),
    'orders': (
      route: Routes.shopOrders,
      key: 'tabPreparing',
      who: Who.shop,
      role: PartnerRole.shop,
    ),
    'new order': (
      route: Routes.shopOrder('so-new'),
      key: 'orderAccept',
      who: Who.shop,
      role: PartnerRole.shop,
    ),
    'order for a fitting': (
      route: Routes.shopOrder(readyForTech['id'] as String),
      key: 'handToTech',
      who: Who.shop,
      role: PartnerRole.shop,
    ),
    'stock': (route: Routes.shopStock, key: 'importExcel', who: Who.shop, role: PartnerRole.shop),
    'add a part': (route: Routes.shopAdd, key: 'photoTitle', who: Who.shop, role: PartnerRole.shop),
    'price requests': (
      route: Routes.shopQuotes,
      key: 'quotesBody',
      who: Who.shop,
      role: PartnerRole.shop,
    ),
    'more': (route: Routes.shopMore, key: 'moreMoney', who: Who.shop, role: PartnerRole.shop),
    'money': (route: Routes.shopMoney, key: 'statement', who: Who.shop, role: PartnerRole.shop),
    'insights': (
      route: Routes.shopInsights,
      key: 'insightsSales7',
      who: Who.shop,
      role: PartnerRole.shop,
    ),
    'staff': (route: Routes.shopStaff, key: 'staffInvite', who: Who.shop, role: PartnerRole.shop),
    'shop profile': (
      route: Routes.shopProfile,
      key: 'shopHours',
      who: Who.shop,
      role: PartnerRole.shop,
    ),
    'chats': (route: Routes.shopChats, key: 'chatsTitle', who: Who.shop, role: PartnerRole.shop),
    'chat': (
      route: Routes.shopChat(chat['id'] as String),
      key: 'chatHint',
      who: Who.shop,
      role: PartnerRole.shop,
    ),
    'alerts': (
      route: Routes.notifications,
      key: 'notificationsTitle',
      who: Who.shop,
      role: PartnerRole.shop,
    ),
    'complaints': (
      route: Routes.complaints,
      key: 'complaintWrongPart',
      who: Who.shop,
      role: PartnerRole.shop,
    ),
    'a complaint': (
      route: Routes.complaint('dp-1'),
      key: 'complaintTeam',
      who: Who.tech,
      role: PartnerRole.technician,
    ),
    'jobs': (route: Routes.techJobs, key: 'newOffers', who: Who.tech, role: PartnerRole.technician),
    'job': (
      route: Routes.techJob(job['id'] as String),
      key: 'jobCustomer',
      who: Who.tech,
      role: PartnerRole.technician,
    ),
    'job offer': (
      route: Routes.techJob('bk-offer'),
      key: 'accept',
      who: Who.tech,
      role: PartnerRole.technician,
    ),
    'schedule': (
      route: Routes.techSchedule,
      key: 'weeklyHours',
      who: Who.tech,
      role: PartnerRole.technician,
    ),
    'earnings': (
      route: Routes.techEarnings,
      key: 'earningsWeek',
      who: Who.tech,
      role: PartnerRole.technician,
    ),
    'technician profile': (
      route: Routes.techProfile,
      key: 'skillsAndPrices',
      who: Who.tech,
      role: PartnerRole.technician,
    ),
    'choose a role': (route: Routes.role, key: 'roleTitle', who: Who.both, role: null),
    'apply': (route: Routes.apply, key: 'applyShopTitle', who: Who.fresh, role: null),
    'apply as a shop': (route: Routes.applyShop, key: 'shopNameAr', who: Who.fresh, role: null),
    'apply as a technician': (
      route: Routes.applyTech,
      key: 'skillsAndPrices',
      who: Who.fresh,
      role: null,
    ),
  };

  for (final locale in ['ar', 'en']) {
    for (final MapEntry(key: name, value: s) in screens.entries) {
      testWidgets('$name ($locale)', (tester) async {
        final backend = FakeBackend(who: s.who);
        final c = await pumpApp(tester, backend, locale: locale, role: s.role);
        c.read(routerProvider).go(s.route);
        await settle(tester);
        expect(tester.takeException(), isNull);
        expect(
          Directionality.of(tester.element(find.byType(Scaffold).last)),
          locale == 'ar' ? TextDirection.rtl : TextDirection.ltr,
        );
        expect(find.textContaining(text(s.key, locale)), findsWidgets);
      });
    }

    testWidgets('sign in ($locale)', (tester) async {
      await pumpApp(tester, FakeBackend(), locale: locale, signedIn: false);
      expect(tester.takeException(), isNull);
      expect(find.text(text('signInTitle', locale)), findsOneWidget);
    });

    testWidgets('sign up ($locale)', (tester) async {
      final c = await pumpApp(tester, FakeBackend(), locale: locale, signedIn: false);
      c.read(routerProvider).go(Routes.signUp);
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.text(text('signUpTitle', locale)), findsOneWidget);
    });
  }
}
