import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:alghali_buyer/app.dart';
import 'package:alghali_buyer/state/inbox.dart';
import 'package:alghali_buyer/state/session.dart';
import 'package:alghali_core/alghali_core.dart';
import 'package:alghali_core/testing.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A fixture captured from alghali-dev (`node infra/scripts/capture-fixtures.mjs`).
dynamic fixture(String name) => jsonDecode(File('test/fixtures/$name.json').readAsStringSync());

/// When the fixtures were captured: tests run at this time so slots and countdowns match.
/// Wednesday 14 Oct 2026, 18:00 in Khartoum.
final now = DateTime.utc(2026, 10, 14, 16);

/// The demo buyer the fixtures belong to.
final buyerId = ((fixture('me') as Json)['profile'] as Json)['id'] as String;

String _jwt(String sub) {
  String part(Object o) => base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
  return '${part({'alg': 'HS256', 'typ': 'JWT'})}.'
      '${part({'sub': sub, 'role': 'authenticated', 'exp': 4102444800})}.sig';
}

Json _session() => {
  'access_token': _jwt(buyerId),
  'token_type': 'bearer',
  'expires_in': 3600,
  'expires_at': 4102444800,
  'refresh_token': 'refresh',
  'user': {
    'id': buyerId,
    'aud': 'authenticated',
    'role': 'authenticated',
    'email': 'buyer@demo.alghali.invalid',
    'app_metadata': {'provider': 'email'},
    'user_metadata': {'display_name': 'أحمد محمد'},
    'created_at': '2026-10-13T00:00:00Z',
  },
};

/// The server side of the buyer app in tests: every call the screens make, answered from
/// the fixtures; the cart, garage, addresses, chat and new orders kept in memory.
class FakeBackend {
  FakeBackend() {
    _routes();
  }

  final server = FakeServer();
  late final client = server.client();

  final garage = <Json>[];
  final addresses = <Json>[];
  final cartItems = <Json>[];
  final messages = <Json>[];
  final placed = <Json>[];
  final requests = <Json>[];

  /// What checkout answers next (e.g. an error), once.
  http.Response? Function(Json body)? onCheckout;

  Future<void> signIn() =>
      client.auth.signInWithPassword(email: 'buyer@demo.alghali.invalid', password: 'secret12');

  List<Json> get _orders => [...placed, ...(fixture('orders') as List).cast<Json>()];
  List<Json> get _bookings => (fixture('my_bookings') as List).cast<Json>();

  Json _body(http.Request r) => r.body.isEmpty ? const {} : jsonDecode(r.body) as Json;

  /// `id=eq.X` filters on a PostgREST GET.
  String? _eq(http.Request r, String column) {
    final v = r.url.queryParameters[column];
    return v != null && v.startsWith('eq.') ? v.substring(3) : null;
  }

  http.Response _table(http.Request r, List<Json> rows) {
    switch (r.method) {
      case 'GET':
        final id = _eq(r, 'id');
        final list = id == null ? rows : rows.where((x) => x['id'] == id).toList();
        return jsonResponse(list);
      case 'POST':
        final body = jsonDecode(r.body);
        final row = <String, dynamic>{
          'id': newId(),
          'created_at': now.toIso8601String(),
          ...(body is List ? body.first as Json : body as Json),
        };
        if (rows.any((x) => x['id'] == row['id'])) {
          return jsonResponse({
            'code': '23505',
            'message': 'duplicate key value',
            'details': null,
          }, 409);
        }
        rows.add(row);
        return jsonResponse(r.headers['Accept']?.contains('object') ?? false ? row : [row], 201);
      case 'DELETE':
        rows.removeWhere(
          (x) => r.url.queryParameters.entries.every(
            (q) => !q.value.startsWith('eq.') || '${x[q.key]}' == q.value.substring(3),
          ),
        );
        return http.Response('', 204);
      default:
        return jsonResponse([]);
    }
  }

  Json _order(Json source, {required String paymentStatus, String? id}) {
    final orderId = id ?? newId();
    return {
      ...source,
      'id': orderId,
      'ref': '48151623',
      'created_at': now.toIso8601String(),
      'pay_by': now.add(const Duration(hours: 2)).toIso8601String(),
      'payment_method': 'BANKAK',
      'payments': [
        {
          'id': 'pay-$orderId',
          'method': 'BANKAK',
          'status': paymentStatus,
          'purpose': 'ORDER',
          'amount_sdg': source['total_sdg'],
          'reject_reason': null,
          'bankak_txn_no': null,
        },
      ],
      'sub_orders': [
        for (final s in (source['sub_orders'] as List).cast<Json>())
          {
            ...s,
            'status': paymentStatus == 'AWAITING_TRANSFER' ? 'PENDING_PAYMENT' : 'PAYMENT_REVIEW',
            'events': <Json>[],
          },
      ],
    };
  }

  void _routes() {
    final s = server;
    s.on('/auth/v1/token', (_) => jsonResponse(_session()));
    s.on('/auth/v1/signup', (_) => jsonResponse(_session()));
    s.on('/auth/v1/logout', (_) => http.Response('', 204));
    s.on('/auth/v1/recover', (_) => jsonResponse({}));

    s.on('/rest/v1/rpc/catalogue_snapshot', (_) => jsonResponse(fixture('catalogue_snapshot')));
    s.on('/rest/v1/rpc/public_settings', (_) => jsonResponse(fixture('public_settings')));
    s.on('/rest/v1/rpc/search_parts', (r) {
      final b = _body(r);
      if (b['p_deals_only'] == true) return jsonResponse(fixture('search_deals'));
      if (b['p_shop_id'] != null) return jsonResponse(fixture('search_shop'));
      return jsonResponse(fixture('search_bulbs'));
    });
    s.on('/rest/v1/rpc/part_detail', (_) => jsonResponse(fixture('part_detail')));
    s.on('/rest/v1/rpc/reviews_for', (_) => jsonResponse(fixture('reviews_shop')));
    s.on('/rest/v1/rpc/me', (_) => jsonResponse(fixture('me')));
    s.on('/rest/v1/rpc/update_profile', (r) {
      final b = _body(r);
      final p = {...((fixture('me') as Json)['profile'] as Json)};
      if (b['p_display_name'] != null) p['display_name'] = b['p_display_name'];
      if (b['p_phone'] != null) p['phone'] = '+249${(b['p_phone'] as String).substring(1)}';
      return jsonResponse(p);
    });
    s.on('/rest/v1/rpc/register_device', (_) => jsonResponse({}));
    s.on('/rest/v1/rpc/unregister_device', (_) => jsonResponse(null));
    s.on('/rest/v1/rpc/mark_notifications_read', (_) => jsonResponse(1));
    s.on('/rest/v1/rpc/my_bookings', (_) => jsonResponse(_bookings));
    s.on('/rest/v1/rpc/booking_detail', (r) {
      final id = _body(r)['p_booking_id'];
      return jsonResponse(_bookings.firstWhere((b) => b['id'] == id));
    });
    s.on('/rest/v1/rpc/my_disputes', (_) => jsonResponse(fixture('disputes')));
    s.on('/rest/v1/rpc/cart_validate', (r) {
      final items = (_body(r)['p_items'] as List).cast<Json>();
      return jsonResponse([
        for (final i in items)
          {...i, 'ok': true, 'price_sdg': i['seen_price_sdg'], 'available_qty': 10},
      ]);
    });
    s.on('/rest/v1/rpc/checkout', (r) {
      final b = _body(r);
      final custom = onCheckout?.call(b);
      onCheckout = null;
      if (custom != null) return custom;
      final source = _orders.firstWhere((o) => (o['sub_orders'] as List).isNotEmpty);
      final order = _order(source, paymentStatus: 'AWAITING_TRANSFER');
      placed.insert(0, order);
      return jsonResponse(order);
    });
    s.on('/rest/v1/rpc/submit_bankak_receipt', (r) {
      final id = _body(r)['p_order_id'];
      final i = placed.indexWhere((o) => o['id'] == id);
      final order = _order(
        _orders.firstWhere((o) => o['id'] == id),
        paymentStatus: 'RECEIPT_SUBMITTED',
        id: id as String,
      );
      if (i >= 0) placed[i] = order;
      return jsonResponse(order);
    });
    s.on('/rest/v1/rpc/create_booking_hold', (r) {
      final b = _body(r);
      final base = _bookings.first;
      final start = DateTime.parse(b['p_start_at'] as String);
      return jsonResponse({
        ...base,
        'id': newId(),
        'status': 'HELD',
        'order_id': null,
        'start_at': start.toIso8601String(),
        'end_at': start.add(Duration(minutes: base['duration_min'] as int)).toIso8601String(),
        'technician_id': b['p_technician_id'],
        'hold_expires_at': now.add(const Duration(minutes: 10)).toIso8601String(),
        'events': [
          {'to': 'HELD', 'at': now.toIso8601String()},
        ],
      });
    });
    s.on('/rest/v1/rpc/release_booking_hold', (_) => jsonResponse(null));
    s.on('/rest/v1/rpc/start_conversation', (_) => jsonResponse({'id': 'conv-1'}));
    s.on('/rest/v1/rpc/mark_conversation_read', (_) => jsonResponse(null));
    s.on('/rest/v1/rpc/create_review', (_) => jsonResponse({}));
    s.on('/rest/v1/rpc/create_part_request', (r) {
      final b = _body(r);
      final row = {
        'id': newId(),
        'note': b['p_note'],
        'status': 'OPEN',
        'created_at': now.toIso8601String(),
        'expires_at': now.add(const Duration(days: 3)).toIso8601String(),
        'variant_id': b['p_variant_id'],
        'category_id': b['p_category_id'],
        'image_keys': b['p_image_keys'],
        'part_offers': <Json>[],
      };
      requests.insert(0, row);
      return jsonResponse(row);
    });

    s.on('/rest/v1/orders', (r) {
      final id = _eq(r, 'id');
      return jsonResponse(id == null ? _orders : _orders.where((o) => o['id'] == id).toList());
    });
    s.on('/rest/v1/notifications', (_) => jsonResponse(fixture('notifications')));
    s.on('/rest/v1/notification_templates', (_) => jsonResponse(fixture('templates')));
    s.on('/rest/v1/garage_vehicles', (r) => _table(r, garage));
    s.on('/rest/v1/addresses', (r) => _table(r, addresses));
    s.on('/rest/v1/cart_items', (r) => _table(r, cartItems));
    s.on('/rest/v1/messages', (r) => _table(r, messages));
    s.on('/rest/v1/part_requests', (_) => jsonResponse(requests));
    s.on('/rest/v1/conversations', (_) => jsonResponse(<Json>[]));
    s.on('/functions/v1/booking-slots', (r) {
      final b = _body(r);
      final slots = fixture('booking_slots_bay') as Json;
      final techId = b['technician_id'] as String?;
      if (techId == null) return jsonResponse(slots);
      return jsonResponse({
        ...slots,
        'any': <Json>[],
        'technicians': [
          for (final t in (slots['technicians'] as List).cast<Json>())
            if (t['id'] == techId)
              {
                ...t,
                'slots': [
                  for (final a in (slots['any'] as List).cast<Json>())
                    if (a['technician_id'] == techId) a['start'],
                ],
              },
        ],
      });
    });
    s.on('/storage/v1/object', (r) => jsonResponse({'Key': r.url.path}));
  }
}

/// A small Android phone (360 × 780 dp), the narrowest layout we support.
Future<ProviderContainer> pumpApp(
  WidgetTester tester,
  FakeBackend backend, {
  String locale = 'ar',
  bool signedIn = true,
  Map<String, Object> prefs = const {},
  AppDatabase? db,
  DateTime Function()? clock,
  PushClient? push,
}) async {
  // No retries: a test that goes offline sees it at once.
  ReadPolicy.retries = 0;
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({'locale': locale, ...prefs});
  final instance = await SharedPreferences.getInstance();
  if (signedIn) await backend.signIn();
  ProviderContainer? container;
  final cache = db == null
      ? null
      : DriftReadCache(
          db,
          userId: () => backend.client.auth.currentUser?.id,
          onReachable: (online) {
            final c = container?.read(onlineProvider.notifier);
            online ? c?.online() : c?.offline();
          },
        );
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        sharedPreferencesProvider.overrideWithValue(instance),
        clockProvider.overrideWithValue(clock ?? () => now),
        supabaseClientProvider.overrideWithValue(backend.client),
        backendReadyProvider.overrideWithValue(true),
        realtimeProvider.overrideWithValue(false),
        offlineSeedProvider.overrideWithValue(
          OfflineSeed(
            snapshot: fixture('catalogue_snapshot') as Json,
            settings: fixture('public_settings') as Json,
          ),
        ),
        if (db != null) appDatabaseProvider.overrideWithValue(db),
        if (cache != null) readCacheProvider.overrideWithValue(cache),
        if (push != null) pushClientProvider.overrideWithValue(push),
        ...liveDataOverrides,
      ],
      child: const BuyerApp(),
    ),
  );
  container = ProviderScope.containerOf(tester.element(find.byType(BuyerApp)));
  await settle(tester);
  return container;
}

/// Hold countdowns tick every second, so pump a fixed time rather than settle.
Future<void> settle(WidgetTester tester, {int frames = 12}) async {
  for (var i = 0; i < frames; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Push as Firebase would deliver it, driven by the test.
class FakePush implements PushClient {
  final _foreground = StreamController<PushData>.broadcast();
  final _taps = StreamController<PushData>.broadcast();

  void arrive(PushData data) => _foreground.add(data);
  void tap(PushData data) => _taps.add(data);

  @override
  Future<String?> token() async => 'fcm-token-1';
  @override
  Stream<String> get tokenRefresh => const Stream.empty();
  @override
  Stream<PushData> get foreground => _foreground.stream;
  @override
  Stream<PushData> get taps => _taps.stream;
  @override
  Future<PushData?> initialTap() async => null;
  @override
  Future<bool> requestPermission() async => true;
}

/// An in-memory phone database, for tests of the offline cache and outbox.
AppDatabase memoryDatabase() => AppDatabase(NativeDatabase.memory());
