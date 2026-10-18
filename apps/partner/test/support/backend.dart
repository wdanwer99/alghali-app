import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:alghali_core/alghali_core.dart';
import 'package:alghali_core/testing.dart';
import 'package:alghali_partner/app.dart';
import 'package:alghali_partner/features/shop/shop_location.dart';
import 'package:alghali_partner/features/shop/stock_screen.dart';
import 'package:alghali_partner/state/inbox.dart';
import 'package:alghali_partner/state/outbox.dart';
import 'package:alghali_partner/state/session.dart';
import 'package:alghali_partner/state/tech.dart';
import 'package:alghali_partner/widgets/partner_widgets.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A fixture captured from alghali-dev (`pnpm fixtures:partner`).
dynamic fixture(String name) => jsonDecode(File('test/fixtures/$name.json').readAsStringSync());

List<Json> fixtureList(String name) => (fixture(name) as List).cast<Json>();

/// The app's own wording from its ARB files (messages without placeholders).
String text(String key, [String locale = 'ar']) =>
    (jsonDecode(File('lib/l10n/app_$locale.arb').readAsStringSync()) as Json)[key] as String;

/// Thursday 15 Oct 2026, 09:00 in Khartoum: the demo technician's job is at 16:00 today.
final now = DateTime.utc(2026, 10, 15, 7);

/// Who is signed in.
enum Who { shop, tech, both, fresh }

final _shopMe = fixture('shop_me') as Json;
final _techMe = fixture('tech_me_account') as Json;
final shopId = (_shopMe['shops'] as List).cast<Json>().first['shop_id'] as String;
final techId = (_techMe['technician'] as Json)['technician_id'] as String;

String _jwt(String sub) {
  String part(Object o) => base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
  return '${part({'alg': 'HS256', 'typ': 'JWT'})}.'
      '${part({'sub': sub, 'role': 'authenticated', 'exp': 4102444800})}.sig';
}

/// The partner app's server in tests: every call the screens make, answered from the
/// fixtures (plus a new order, a photo request and a job offer, which dev rarely has at
/// capture time); changes are kept in memory.
class FakeBackend {
  FakeBackend({this.who = Who.shop}) {
    _seed();
    _routes();
  }

  final Who who;
  final server = FakeServer();
  late final client = server.client();

  late List<Json> orders;
  late List<Json> listings;
  late List<Json> requests;
  late List<Json> offers;
  late List<Json> upcoming;
  late List<Json> past;
  late Json technician;
  late Json shop;
  Json tint = fixture('shop_tint_settings') as Json;
  final staff = fixtureList('shop_staff');
  final messages = <Json>[];
  final rules = <Json>[];
  final timeOff = <Json>[];
  final locations = <({String booking, double lat, double lng})>[];
  final photos = <String>[];

  /// Complaints the partner is part of: one a buyer opened about a delivered order.
  late List<Json> disputes;

  /// The job code the fake buyer gives the technician.
  static const jobCode = '2741';
  var codeTries = 0;

  /// What `me()` answers: who is signed in, and whether they applied for anything yet.
  late Json me;

  String get userId => ((me['profile'] as Json)['id']) as String;

  void _seed() {
    final shopOrders = fixtureList('shop_orders');
    final done = shopOrders.firstWhere((o) => o['status'] == 'COMPLETED');
    DateTime ago(int minutes) => now.subtract(Duration(minutes: minutes));
    Json order(String id, String ref, {DateTime? ack, required int minutesAgo}) => {
      ...done,
      'id': id,
      'ref': ref,
      'status': 'CONFIRMED',
      'fulfilment': 'PICKUP',
      'payment_method': 'CASH',
      'payment_status': 'DUE',
      'placed_at': ago(minutesAgo).toIso8601String(),
      'shop_ack_at': ack?.toIso8601String(),
      'ready_at': null,
      'handed_over_at': null,
      'completed_at': null,
      'events': [
        {
          'from': null,
          'to': 'CONFIRMED',
          'actor': 'BUYER',
          'at': ago(minutesAgo).toIso8601String(),
        },
      ],
    };
    orders = [
      order('so-new', '61042177', minutesAgo: 12),
      order('so-prep', '61039854', ack: ago(30), minutesAgo: 45),
      ...shopOrders,
    ];
    listings = fixtureList('shop_listings');
    final snapshot = fixture('catalogue_snapshot') as Json;
    final category = (snapshot['categories'] as List).cast<Json>().first['id'];
    requests = [
      {
        'id': 'rq-1',
        'note': 'مرآة جانبية يسار مع إشارة',
        'status': 'OPEN',
        'created_at': ago(60).toIso8601String(),
        'expires_at': now.add(const Duration(hours: 20)).toIso8601String(),
        'variant_id': (snapshot['variants'] as List).cast<Json>().first['id'],
        'category_id': category,
        'image_keys': <String>[],
        'buyer_name': 'عمر',
        'offer_count': 1,
        'my_offer': null,
      },
      ...fixtureList('shop_open_requests'),
    ];
    upcoming = fixtureList('tech_upcoming');
    past = fixtureList('tech_past');
    final job = upcoming.first;
    offers = [
      {
        ...job,
        'id': 'bk-offer',
        'ref': '30217749',
        'status': 'PENDING_TECH_ACCEPT',
        'place': 'CUSTOMER_LOCATION',
        'bay': null,
        'bay_shop_id': null,
        'lat': 15.59,
        'lng': 32.53,
        'address_snapshot': {'label': 'البيت', 'description_ar': 'الرياض، شارع 15'},
        'travel_fee_sdg': 3000,
        'payment_method': 'CASH',
        'payments': <Json>[],
        'start_at': DateTime.utc(2026, 10, 16, 14).toIso8601String(),
        'offer': {
          'id': 'of-1',
          'status': 'OFFERED',
          'expires_at': now.add(const Duration(minutes: 14)).toIso8601String(),
        },
      },
    ];
    disputes = [
      {
        'id': 'dp-1',
        'category': 'WRONG_PART',
        'description': 'وصلتني مرآة يمين بدل اليسار',
        'status': 'IN_REVIEW',
        'created_at': ago(90).toIso8601String(),
        'ref': done['ref'],
        'sub_order_id': done['id'],
        'booking_id': null,
        'resolution': null,
        'opener_name': 'عمر',
        'messages': <Json>[
          {
            'id': 'dm-1',
            'body': 'نراجع الطلب مع المحل.',
            'from_admin': true,
            'mine': false,
            'at': ago(60).toIso8601String(),
            'sender': null,
          },
        ],
      },
    ];
    technician = {...fixture('technician') as Json, 'home_lat': 15.6, 'home_lng': 32.5};
    rules.addAll((technician['availability_rules'] as List).cast<Json>());
    shop = fixture('shop_detail') as Json;
    me = switch (who) {
      Who.shop => _shopMe,
      Who.tech => _techMe,
      Who.both => {..._shopMe, 'technician': _techMe['technician']},
      Who.fresh => {..._shopMe, 'shops': <Json>[], 'technician': null},
    };
  }

  Json _session() => {
    'access_token': _jwt(userId),
    'token_type': 'bearer',
    'expires_in': 3600,
    'expires_at': 4102444800,
    'refresh_token': 'refresh',
    'user': {
      'id': userId,
      'aud': 'authenticated',
      'role': 'authenticated',
      'email': (me['profile'] as Json)['email'],
      'app_metadata': {'provider': 'email'},
      'user_metadata': <String, Object?>{},
      'created_at': '2026-10-13T00:00:00Z',
    },
  };

  Future<void> signIn() =>
      client.auth.signInWithPassword(email: 'owner.nour@demo.alghali.invalid', password: 'x');

  Json _body(http.Request r) => r.body.isEmpty ? const {} : jsonDecode(r.body) as Json;

  String? _eq(http.Request r, String column) {
    final v = r.url.queryParameters[column];
    return v != null && v.startsWith('eq.') ? v.substring(3) : null;
  }

  http.Response _table(http.Request r, List<Json> rows) {
    switch (r.method) {
      case 'POST':
        final body = jsonDecode(r.body);
        final row = <String, dynamic>{
          'id': newId(),
          'created_at': now.toIso8601String(),
          ...(body is List ? body.first as Json : body as Json),
        };
        if (rows.any((x) => x['id'] == row['id'])) {
          return jsonResponse({'code': '23505', 'message': 'duplicate', 'details': null}, 409);
        }
        rows.add(row);
        return jsonResponse(r.headers['Accept']?.contains('object') ?? false ? row : [row], 201);
      case 'DELETE':
        final id = _eq(r, 'id');
        rows.removeWhere((x) => x['id'] == id);
        return http.Response('', 204);
      default:
        return jsonResponse(rows);
    }
  }

  http.Response _move(http.Request r, Json Function(Json o) change) {
    final id = _body(r)['p_sub_order_id'] as String;
    final i = orders.indexWhere((o) => o['id'] == id);
    if (i < 0) return rpcError('SUBORDER_NOT_FOUND');
    orders[i] = change(orders[i]);
    return jsonResponse(orders[i]);
  }

  Json _status(Json o, String to) => {
    ...o,
    'status': to,
    'events': [
      ...(o['events'] as List).cast<Json>(),
      {'from': o['status'], 'to': to, 'actor': 'SHOP', 'at': now.toIso8601String()},
    ],
  };

  Json? _job(String id) =>
      [...offers, ...upcoming, ...past].where((b) => b['id'] == id).firstOrNull;

  http.Response _step(http.Request r, String to, {Json extra = const {}}) {
    final id = _body(r)['p_booking_id'] as String;
    final b = _job(id);
    if (b == null) return rpcError('BOOKING_NOT_FOUND');
    final next = {...b, 'status': to, ...extra};
    upcoming = [for (final x in upcoming) x['id'] == id ? next : x];
    return jsonResponse(next);
  }

  Json _technicianRow() => {...technician, 'availability_rules': rules, 'time_off': timeOff};

  void _routes() {
    final s = server;
    s.on('/auth/v1/token', (_) => jsonResponse(_session()));
    s.on('/auth/v1/signup', (_) => jsonResponse(_session()));
    s.on('/auth/v1/logout', (_) => http.Response('', 204));
    s.on('/auth/v1/recover', (_) => jsonResponse({}));

    s.on('/rest/v1/rpc/catalogue_snapshot', (_) => jsonResponse(fixture('catalogue_snapshot')));
    s.on('/rest/v1/rpc/public_settings', (_) => jsonResponse(fixture('public_settings')));
    s.on('/rest/v1/rpc/me', (_) => jsonResponse(me));
    s.on('/rest/v1/rpc/update_profile', (_) => jsonResponse(me['profile']));
    s.on('/rest/v1/rpc/register_device', (_) => jsonResponse({}));
    s.on('/rest/v1/rpc/unregister_device', (_) => jsonResponse(null));
    s.on('/rest/v1/rpc/mark_notifications_read', (_) => jsonResponse(1));
    s.on('/rest/v1/rpc/mark_conversation_read', (_) => jsonResponse(null));

    // The shop.
    s.on('/rest/v1/rpc/shop_detail', (_) => jsonResponse(shop));
    // Window tint (D-149): captured on alghali-test; saving echoes what was sent.
    s.on('/rest/v1/rpc/shop_tint_settings', (_) => jsonResponse(tint));
    s.on('/rest/v1/rpc/shop_set_tint', (r) {
      final b = _body(r);
      tint = {
        ...tint,
        'is_active': b['p_is_active'],
        'darkness': b['p_darkness'],
        'colours': b['p_colours'],
        'prices': b['p_prices'],
      };
      return jsonResponse(tint);
    });
    s.on('/rest/v1/rpc/shop_set_closed', (r) {
      shop = {
        ...shop,
        'closed_until': _body(r)['p_until'],
        'open_now': _body(r)['p_until'] == null,
      };
      return jsonResponse(shop);
    });
    s.on('/rest/v1/rpc/shop_update_profile', (r) {
      shop = {...shop, ...(_body(r)['p_patch'] as Json)};
      return jsonResponse(shop);
    });
    s.on('/rest/v1/rpc/shop_orders', (_) => jsonResponse(orders));
    s.on('/rest/v1/rpc/shop_ack_suborder', (r) {
      return _move(r, (o) => {...o, 'shop_ack_at': now.toIso8601String()});
    });
    s.on('/rest/v1/rpc/shop_reject_suborder', (r) {
      final reason = _body(r)['p_reason'];
      return _move(r, (o) => {..._status(o, 'REJECTED_BY_SHOP'), 'cancel_reason': reason});
    });
    s.on('/rest/v1/rpc/shop_mark_ready', (r) => _move(r, (o) => _status(o, 'READY')));
    s.on('/rest/v1/rpc/shop_hand_over', (r) {
      return _move(r, (o) {
        final to = switch (o['fulfilment']) {
          'DELIVERY' => 'OUT_FOR_DELIVERY',
          'TO_TECHNICIAN' => 'HANDED_TO_TECHNICIAN',
          _ => 'PICKED_UP',
        };
        return {
          ..._status(o, to),
          if (o['payment_status'] == 'DUE' && to == 'PICKED_UP') 'payment_status': 'COLLECTED',
        };
      });
    });
    s.on('/rest/v1/rpc/shop_mark_delivered', (r) => _move(r, (o) => _status(o, 'DELIVERED')));
    s.on('/rest/v1/rpc/shop_listings', (_) => jsonResponse(listings));
    s.on('/rest/v1/rpc/shop_bulk_update', (r) {
      final results = <Json>[];
      for (final i in (_body(r)['p_items'] as List).cast<Json>()) {
        final at = listings.indexWhere((l) => l['id'] == i['listing_id']);
        final l = listings[at];
        if (l['version'] != i['version']) {
          results.add({
            'listing_id': l['id'],
            'ok': false,
            'error': 'VERSION_CONFLICT',
            'version': l['version'],
          });
          continue;
        }
        final reserved = (l['stock_qty'] as int) - (l['available_qty'] as int);
        final qty = i['stock_qty'] as int? ?? l['stock_qty'] as int;
        listings[at] = {
          ...l,
          'version': (l['version'] as int) + 1,
          if (i['price_sdg'] != null) 'price_sdg': i['price_sdg'],
          'stock_qty': qty,
          'available_qty': qty - reserved,
          if (i['is_active'] != null) 'is_active': i['is_active'],
        };
        results.add({'listing_id': l['id'], 'ok': true, 'version': listings[at]['version']});
      }
      return jsonResponse({'results': results});
    });
    s.on('/rest/v1/rpc/shop_upsert_listing', (r) {
      final b = _body(r);
      final part = b['p_new_part'] as Json?;
      final base = listings.first;
      final row = {
        ...base,
        'id': 'ls-${listings.length + 1}',
        'version': 1,
        'condition': b['p_condition'],
        'price_sdg': b['p_price_sdg'],
        'stock_qty': b['p_stock_qty'],
        'available_qty': b['p_stock_qty'],
        'is_active': b['p_is_active'],
        'images': <String>[],
        'part': {
          ...(base['part'] as Json),
          if (part != null) ...{
            'id': 'pt-new',
            'name_ar': part['name_ar'],
            'name_en': part['name_ar'],
            'category_id': part['category_id'],
            'own': true,
          },
        },
      };
      listings.insert(0, row);
      return jsonResponse(row);
    });
    s.on('/rest/v1/rpc/shop_set_listing_images', (r) {
      final b = _body(r);
      final at = listings.indexWhere((l) => l['id'] == b['p_listing_id']);
      listings[at] = {...listings[at], 'images': b['p_base_keys']};
      return jsonResponse(listings[at]);
    });
    s.on('/rest/v1/rpc/shop_archive_listing', (r) {
      listings.removeWhere((l) => l['id'] == _body(r)['p_listing_id']);
      return jsonResponse(null);
    });
    s.on('/rest/v1/rpc/suggest_parts', (_) => jsonResponse(fixture('suggest_parts')));
    s.on('/rest/v1/rpc/shop_open_requests', (_) => jsonResponse(requests));
    s.on('/rest/v1/rpc/shop_make_offer', (r) {
      final b = _body(r);
      final offer = {
        'id': 'of-shop-1',
        'shop_id': shopId,
        'title_ar': b['p_title_ar'],
        'title_en': b['p_title_ar'],
        'condition': b['p_condition'],
        'price_sdg': b['p_price_sdg'],
        'warranty_days': b['p_warranty_days'],
        'valid_until': now.add(const Duration(hours: 48)).toIso8601String(),
        'status': 'OFFERED',
      };
      requests = [
        for (final q in requests)
          q['id'] == b['p_request_id'] ? {...q, 'my_offer': offer, 'offer_count': 2} : q,
      ];
      return jsonResponse(offer);
    });
    s.on('/rest/v1/rpc/shop_conversations', (_) => jsonResponse(fixture('shop_conversations')));
    s.on('/rest/v1/rpc/shop_start_conversation', (_) {
      return jsonResponse({'id': fixtureList('shop_conversations').first['id']});
    });
    s.on('/rest/v1/rpc/shop_staff', (_) => jsonResponse(staff));
    s.on('/rest/v1/rpc/shop_add_staff', (r) {
      final email = _body(r)['p_email'] as String;
      if (!email.contains('demo')) return rpcError('USER_NOT_FOUND', sqlState: 'P0002');
      staff.add({
        'user_id': newId(),
        'role': 'STAFF',
        'email': email,
        'display_name': 'مجدي',
        'added_at': now.toIso8601String(),
      });
      return jsonResponse({});
    });
    s.on('/rest/v1/rpc/shop_remove_staff', (r) {
      staff.removeWhere((m) => m['user_id'] == _body(r)['p_user_id']);
      return jsonResponse(null);
    });
    s.on('/rest/v1/rpc/shop_statement', (_) => jsonResponse(fixture('shop_statement')));
    s.on('/rest/v1/rpc/shop_insights', (_) => jsonResponse(fixture('shop_insights')));
    s.on('/rest/v1/rpc/apply_as_shop', (r) {
      final id = newId();
      me = {
        ...me,
        'shops': [
          {
            'shop_id': id,
            'role': 'OWNER',
            'status': 'PENDING',
            'status_reason': null,
            'name_ar': _body(r)['p_name_ar'],
            'name_en': '',
          },
        ],
      };
      return jsonResponse({'id': id});
    });
    s.on('/rest/v1/rpc/apply_as_technician', (_) {
      me = {
        ...me,
        'technician': {
          'technician_id': techId,
          'status': 'PENDING',
          'work_mode': 'BOTH',
          'status_reason': null,
        },
      };
      return jsonResponse(_technicianRow());
    });

    // The technician.
    s.on('/rest/v1/technicians', (_) => jsonResponse(_technicianRow()));
    s.on('/rest/v1/availability_rules', (r) => _table(r, rules));
    s.on('/rest/v1/time_off', (r) => _table(r, timeOff));
    s.on('/rest/v1/rpc/tech_quick_block', (r) {
      timeOff.add({
        'id': newId(),
        'period':
            '["${now.toIso8601String()}","${now.add(Duration(minutes: _body(r)['p_minutes'] as int)).toIso8601String()}")',
        'reason': quickBlockReason,
      });
      return jsonResponse(_technicianRow());
    });
    s.on('/rest/v1/rpc/tech_update_profile', (r) {
      technician = {...technician, ...(_body(r)['p_patch'] as Json)};
      return jsonResponse(_technicianRow());
    });
    s.on('/rest/v1/rpc/tech_set_job_types', (r) {
      final ids = {
        for (final j in (technician['technician_job_types'] as List).cast<Json>())
          (j['job_types'] as Json)['id']: j['job_types'],
      };
      technician = {
        ...technician,
        'technician_job_types': [
          for (final i in (_body(r)['p_items'] as List).cast<Json>())
            {
              'labour_sdg': i['labour_sdg'],
              'job_types':
                  ids[i['job_type_id']] ??
                  {'id': i['job_type_id'], 'code': 'AC', 'name_ar': 'تكييف', 'name_en': 'AC'},
            },
        ],
      };
      return jsonResponse(_technicianRow());
    });
    s.on('/rest/v1/rpc/tech_bookings', (r) {
      return jsonResponse(switch (_body(r)['p_scope']) {
        'OFFERS' => offers,
        'UPCOMING' => upcoming,
        _ => past,
      });
    });
    s.on(
      '/rest/v1/rpc/booking_detail',
      (r) => jsonResponse(_job(_body(r)['p_booking_id'] as String)),
    );
    s.on('/rest/v1/rpc/tech_respond_offer', (r) {
      final b = _body(r);
      final job = offers.firstWhere((o) => (o['offer'] as Json)['id'] == b['p_offer_id']);
      offers = [];
      if (b['p_accept'] == true) {
        final accepted = {
          ...job,
          'status': 'ACCEPTED',
          'offer': {...(job['offer'] as Json), 'status': 'ACCEPTED'},
        };
        upcoming = [...upcoming, accepted];
        return jsonResponse(accepted);
      }
      return jsonResponse({...job, 'status': 'PENDING_TECH_ACCEPT'});
    });
    s.on('/rest/v1/rpc/tech_en_route', (r) => _step(r, 'EN_ROUTE'));
    s.on('/rest/v1/rpc/tech_check_in', (r) => _step(r, 'IN_PROGRESS'));
    s.on('/rest/v1/rpc/tech_update_location', (r) {
      final b = _body(r);
      locations.add((
        booking: b['p_booking_id'] as String,
        lat: (b['p_lat'] as num).toDouble(),
        lng: (b['p_lng'] as num).toDouble(),
      ));
      return jsonResponse(null);
    });
    s.on('/rest/v1/rpc/tech_add_photo', (r) {
      final b = _body(r);
      photos.add(b['p_image_key'] as String);
      final job = _job(b['p_booking_id'] as String)!;
      return _step(
        r,
        job['status'] as String,
        extra: {
          'photos': [
            ...(job['photos'] as List),
            {
              'id': newId(),
              'kind': b['p_kind'],
              'image_key': b['p_image_key'],
              'taken_at': now.toIso8601String(),
            },
          ],
        },
      );
    });
    s.on('/rest/v1/rpc/tech_complete', (r) {
      final b = _body(r);
      if (b['p_code'] != jobCode) {
        codeTries++;
        return jsonResponse({
          'ok': false,
          'error': 'WRONG_JOB_CODE',
          'attempts_left': 5 - codeTries,
        });
      }
      final job = _job(b['p_booking_id'] as String)!;
      final done = {...job, 'status': 'COMPLETED'};
      upcoming = upcoming.where((x) => x['id'] != job['id']).toList();
      past = [done, ...past];
      return jsonResponse({'ok': true, 'booking': done});
    });
    s.on('/rest/v1/rpc/tech_part_not_fit', (r) => _step(r, 'PART_DOES_NOT_FIT'));
    s.on('/rest/v1/rpc/tech_cancel', (r) {
      upcoming = upcoming.where((x) => x['id'] != _body(r)['p_booking_id']).toList();
      return jsonResponse({});
    });
    s.on('/rest/v1/rpc/tech_statement', (_) => jsonResponse(fixture('tech_statement')));

    // Shared.
    s.on('/rest/v1/rpc/my_disputes', (_) => jsonResponse(disputes));
    s.on('/rest/v1/rpc/open_dispute', (r) {
      final b = _body(r);
      final d = <String, Object?>{
        'id': 'dp-${disputes.length + 1}',
        'category': b['p_category'],
        'description': b['p_description'],
        'status': 'OPEN',
        'created_at': now.toIso8601String(),
        'ref': null,
        'sub_order_id': b['p_sub_order_id'],
        'booking_id': b['p_booking_id'],
        'resolution': null,
        'opener_name': (me['profile'] as Json)['display_name'],
        'messages': <Json>[],
      };
      disputes.insert(0, d);
      return jsonResponse(d);
    });
    s.on('/rest/v1/rpc/dispute_reply', (r) {
      final b = _body(r);
      final d = disputes.firstWhere((x) => x['id'] == b['p_dispute_id']);
      (d['messages'] as List).add({
        'id': 'dm-${(d['messages'] as List).length + 1}',
        'body': b['p_body'],
        'from_admin': false,
        'mine': true,
        'at': now.toIso8601String(),
        'sender': null,
      });
      return jsonResponse(d);
    });
    s.on('/rest/v1/notifications', (_) {
      return jsonResponse(fixture(who == Who.tech ? 'tech_notifications' : 'shop_notifications'));
    });
    s.on('/rest/v1/notification_templates', (_) => jsonResponse(fixture('templates')));
    s.on('/rest/v1/messages', (r) {
      if (r.method == 'GET' && messages.isEmpty) messages.addAll(fixtureList('messages'));
      return _table(r, messages);
    });
    s.on('/storage/v1/object/sign', (r) {
      final paths = (_body(r)['paths'] as List?)?.cast<String>() ?? const <String>[];
      return jsonResponse([
        for (final p in paths) {'path': p, 'signedURL': '/object/sign/x/$p?token=t'},
      ]);
    });
    s.on('/storage/v1/object', (r) => jsonResponse({'Key': r.url.path}));
    s.on('/functions/v1/inventory-import', (r) {
      final dry = _body(r)['dry_run'] == true;
      return jsonResponse({
        'total': 3,
        'created': 2,
        'updated': 1,
        'failed': 1,
        'dry_run': dry,
        'errors': [
          {'row': 4, 'code': 'INVALID_PRICE', 'column': 'price'},
        ],
        'warnings': <Json>[],
      });
    });
  }

  /// The requests to a function, in order.
  List<Json> calls(String rpc) => [for (final r in server.to('/rest/v1/rpc/$rpc')) jsonBody(r)];
}

/// Photos kept in memory instead of the phone's storage (no plugins in tests).
class MemoryPhotoStore implements PhotoStore {
  final files = <String, Uint8List>{};

  @override
  Future<String> keep(Uint8List jpeg, String name) async {
    files[name] = jpeg;
    return name;
  }

  @override
  Future<Uint8List?> read(String path) async => files[path];

  @override
  Future<void> forget(String path) async => files.remove(path);

  @override
  Future<MediaVariants> variants(Uint8List jpeg) async =>
      (thumb: jpeg, medium: jpeg, large: jpeg, orig: jpeg);
}

/// A 1×1 PNG for the photo picker.
final testPhoto = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

/// A small Android phone (360 × 780 dp), the narrowest layout we support.
Future<ProviderContainer> pumpApp(
  WidgetTester tester,
  FakeBackend backend, {
  String locale = 'ar',
  bool signedIn = true,
  PartnerRole? role = PartnerRole.shop,
  Map<String, Object> prefs = const {},
  AppDatabase? db,
  PushClient? push,
  MemoryPhotoStore? photos,
  DateTime Function()? clock,
}) async {
  ReadPolicy.retries = 0;
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final me = backend.me;
  final account = PartnerSession.fromJson({
    'user_id': (me['profile'] as Json)['id'],
    'name': (me['profile'] as Json)['display_name'],
    'email': (me['profile'] as Json)['email'],
    'phone': (me['profile'] as Json)['phone'],
    'shops': me['shops'],
    'technician': me['technician'],
    'role': role?.name,
    'shop_id': role == PartnerRole.shop ? shopId : null,
  });
  SharedPreferences.setMockInitialValues({
    'locale': locale,
    if (signedIn) 'partner_account': jsonEncode(account.toJson()),
    ...prefs,
  });
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
        splashEnabledProvider.overrideWithValue(false),
        locationSharingEnabledProvider.overrideWithValue(false),
        mapTilesEnabledProvider.overrideWithValue(false),
        photoStoreProvider.overrideWithValue(photos ?? MemoryPhotoStore()),
        photoPickerProvider.overrideWithValue(
          ({required bool camera}) async => (bytes: testPhoto, fileName: 'part.jpg'),
        ),
        sheetPickerProvider.overrideWithValue(
          () async => (bytes: Uint8List.fromList([1, 2, 3]), name: 'stock.xlsx'),
        ),
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
      child: const PartnerApp(),
    ),
  );
  container = ProviderScope.containerOf(tester.element(find.byType(PartnerApp)));
  await settle(tester);
  return container;
}

/// Countdowns tick every second, so pump a fixed time rather than settle.
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
