import 'dart:convert';
import 'dart:typed_data';

import 'package:alghali_core/alghali_core.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_server.dart';
import 'support/fixtures.dart';

List<Json> rows(String name) => (fixture(name)! as List).cast<Json>();

void main() {
  group('parsing M3 responses', () {
    test('the buyer’s bookings carry the job code, the order to pay and the job types', () {
      final bookings = [for (final r in rows('my_bookings')) Booking.fromJson(r)];
      final accepted = bookings.firstWhere((b) => b.status == BookingStatus.accepted);
      expect(accepted.jobCode, matches(RegExp(r'^\d{4}$')));
      expect(accepted.place, BookingPlace.bay);
      expect(accepted.bayName, isNotNull);
      expect(accepted.paymentStatus, PaymentStatus.confirmed);
      expect(accepted.orderRef, matches(RegExp(r'^\d{8}$')));
      expect(accepted.items.single.jobType, JobType.lighting);
      expect(accepted.technicianName, 'عمر عبد الله');
      expect(accepted.technicianPhone, isNotNull, reason: 'accepted: the buyer may call');

      final waiting = bookings.firstWhere((b) => b.status == BookingStatus.awaitingPayment);
      expect(waiting.paymentStatus, PaymentStatus.receiptSubmitted);
      expect(waiting.items.single.jobType, JobType.tyres);
      expect(waiting.externalPart, 'تركيب 4 إطارات');
      expect(waiting.technicianPhone, isNull, reason: 'not accepted yet');
      expect(waiting.totalSdg, waiting.labourSdg + waiting.bookingFeeSdg);
    });

    test('a finished fitting: events from hold to completion, cash collected', () {
      final b = Booking.fromJson(fixture('booking_completed')! as Json);
      expect(b.status, BookingStatus.completed);
      expect(b.events.first.status, BookingStatus.held);
      expect(b.events.last.status, BookingStatus.completed);
      expect(b.method, PaymentMethod.cash);
      expect(b.items.single.jobType, JobType.brakes);
      expect(b.isActive, isFalse);
    });

    test('a technician’s offer: the buyer to call and the deadline, no job code', () {
      final b = Booking.fromJson(rows('tech_bookings_offers').single);
      expect(b.status, BookingStatus.pendingTechAccept);
      expect(b.jobCode, isEmpty);
      expect(b.buyerName, 'منى حسن');
      expect(b.buyerPhone, startsWith('+249'));
      expect(b.offer?.open, isTrue);
      expect(b.offer?.expiresAt, isNotNull);
      expect(b.items.single.jobType, JobType.battery);
    });

    test('booking-slots: technicians ranked with price and next slot; "any available" times', () {
      final o = BookingOptions.fromJson(fixture('booking_slots')! as Json);
      expect(o.durationMin, 30);
      expect(o.bookingFeeSdg, 2000);
      expect(o.travelFeeSdg, 0);
      expect(o.labourRange, (min: 4500, max: 5000));
      final best = o.technicians.first;
      expect(best.name, 'عمر عبد الله');
      expect(best.mode, WorkMode.both);
      expect(best.bay?.name.en, 'Al-Nour Auto Parts');
      expect(best.nextSlot, isNotNull);
      expect(best.slots, isEmpty);
      expect(best.score, greaterThan(o.technicians.last.score));
      expect(o.any.first.technicianId, best.id);

      final one = BookingOptions.fromJson(fixture('booking_slots_one')! as Json);
      expect(one.technicians.single.slots, hasLength(6));
      expect(one.any, isEmpty);
    });

    test('a technician’s public profile and reviews', () {
      final p = TechnicianProfile.fromJson(fixture('technician_profile')! as Json);
      expect(p.name, 'عمر عبد الله');
      expect(p.jobs.map((j) => j.jobType), containsAll([JobType.lighting, JobType.battery]));
      expect(p.makeIds, isEmpty);
      expect(p.bay?.plotNo, '12');
      final reviews = [for (final r in rows('reviews_for')) reviewFromJson(r)];
      expect(reviews.single.rating, 5);
      expect(reviews.single.author, 'عمر');
    });

    test('the technician’s own record: prices, hours, bay', () {
      final me = MyTechnician.fromJson(fixture('technician_self')! as Json);
      expect(me.status, TechnicianStatus.approved);
      expect(me.mode, WorkMode.both);
      expect(me.radiusKm, 12);
      expect(me.rules, hasLength(12));
      expect(me.rules.first.weekday, 0);
      expect(me.rules.first.startMin, 540);
      expect(me.jobs.firstWhere((j) => j.jobType == JobType.lighting).labourSdg, 5000);
      expect(me.bay?.name.ar, 'النور لقطع الغيار');
    });

    test('time off arrives as a Postgres range', () {
      final me = MyTechnician.fromJson({
        ...fixture('technician_self')! as Json,
        'time_off': [
          {
            'id': 't1',
            'period': '["2026-10-15 08:00:00+00","2026-10-15 10:00:00+00")',
            'reason': 'QUICK_BLOCK',
          },
        ],
      });
      expect(me.timeOff.single.from, DateTime.utc(2026, 10, 15, 8));
      expect(me.timeOff.single.to, DateTime.utc(2026, 10, 15, 10));
    });

    test('the technician’s statement: cash handed to the shop, cash collected, labour', () {
      final st = ShopStatement.fromJson(fixture('tech_statement')! as Json);
      expect(st.lines.map((l) => l.kind), [
        LedgerKind.cashHandover,
        LedgerKind.cashCollected,
        LedgerKind.labour,
      ]);
      expect(st.openingSdg + st.lines.fold(0, (n, l) => n + l.amountSdg), st.closingSdg);
      expect(st.closingSdg, -2000, reason: 'owes the booking fee on a cash job (D-013)');
    });

    test('disputes', () {
      final d = Dispute.fromJson({
        'id': 'd1',
        'category': 'WRONG_PART',
        'description': 'القطعة غير المطلوبة',
        'status': 'IN_REVIEW',
        'created_at': '2026-10-14T08:00:00Z',
        'ref': '28743185',
        'sub_order_id': 's1',
        'booking_id': null,
        'resolution': null,
        'messages': [
          {
            'id': 'm1',
            'body': 'سنستبدلها',
            'from_admin': false,
            'mine': false,
            'at': '2026-10-14T09:00:00Z',
            'sender': 'محل',
          },
        ],
      });
      expect(d.category, DisputeCategory.wrongPart);
      expect(d.status, DisputeStatus.inReview);
      expect(d.closed, isFalse);
      expect(d.messages.single.sender, 'محل');
      expect(disputeCategoryCode(DisputeCategory.notReceived), 'NOT_RECEIVED');
    });
  });

  group('BookingsRepository', () {
    late FakeServer server;
    setUp(() => server = FakeServer());

    test('asks booking-slots with the items, the place and only the filters given', () async {
      server.on('/functions/v1/booking-slots', (_) => json(fixture('booking_slots')!));
      final o = await BookingsRepository(server.client()).options(
        items: const [FittingItem.category('c1', 'لمبات'), FittingItem.listing('l1')],
        place: BookingPlace.customer,
        lat: 15.6,
        lng: 32.5,
      );
      expect(o.technicians, isNotEmpty);
      expect(server.body(0), {
        'items': [
          {'category_id': 'c1', 'description': 'لمبات'},
          {'listing_id': 'l1'},
        ],
        'place': 'CUSTOMER_LOCATION',
        'lat': 15.6,
        'lng': 32.5,
      });
    });

    test('a hold sends the start in UTC and "any available" as the assignment mode', () async {
      server.on('/rest/v1/rpc/create_booking_hold', (_) => json(rows('my_bookings').first));
      await BookingsRepository(server.client()).hold(
        technicianId: 't1',
        start: DateTime.utc(2026, 10, 16, 14),
        items: const [FittingItem.orderItem('oi1')],
        place: BookingPlace.bay,
        any: true,
      );
      final body = server.body(0)..remove('p_idem');
      expect(body, {
        'p_technician_id': 't1',
        'p_start_at': '2026-10-16T14:00:00.000Z',
        'p_items': [
          {'order_item_id': 'oi1'},
        ],
        'p_place': 'BAY',
        'p_address_id': null,
        'p_location_note': null,
        'p_variant_id': null,
        'p_assignment_mode': 'ANY',
      });
    });

    test('checkout pays the held fitting in the same order', () async {
      server.on('/rest/v1/rpc/checkout', (_) => json(fixture('order_json')!));
      await OrdersRepository(server.client())
          .checkout(const [], PaymentMethod.bankak, bookingId: 'b1');
      expect(server.body(0), containsPair('p_booking_id', 'b1'));
      expect(server.body(0), containsPair('p_items', <Object>[]));
    });

    test('a dispute sends the category code', () async {
      server.on(
        '/rest/v1/rpc/open_dispute',
        (_) => json({
          'id': 'd1',
          'category': 'NOT_FITTED',
          'description': 'التركيب غير سليم',
          'status': 'OPEN',
          'created_at': '2026-10-14T08:00:00Z',
          'messages': <Object>[],
        }),
      );
      final d = await BookingsRepository(server.client()).openDispute(
        category: DisputeCategory.notFitted,
        description: 'التركيب غير سليم',
        bookingId: 'b1',
      );
      expect(d.status, DisputeStatus.open);
      expect(server.body(0), containsPair('p_category', 'NOT_FITTED'));
    });
  });

  group('TechnicianRepository', () {
    late FakeServer server;
    setUp(() => server = FakeServer());

    test('a wrong job code is an answer, not an error', () async {
      server.on(
        '/rest/v1/rpc/tech_complete',
        (_) => json({'ok': false, 'error': 'WRONG_JOB_CODE', 'attempts_left': 3}),
      );
      final r = await TechnicianRepository(server.client()).complete('b1', '1234');
      expect(r.ok, isFalse);
      expect(r.error, 'WRONG_JOB_CODE');
      expect(r.attemptsLeft, 3);
      expect(r.booking, isNull);
    });

    test('applying sends job types with their prices', () async {
      server.on('/rest/v1/rpc/apply_as_technician', (_) => json({'id': 't1'}));
      await TechnicianRepository(server.client()).apply(
        mode: WorkMode.mobile,
        labourByJobTypeId: {'jt1': 5000},
        phone: '0912000111',
        homeLat: 15.6,
        homeLng: 32.5,
      );
      final body = server.body(0);
      expect(body['p_work_mode'], 'MOBILE');
      expect(body['p_job_types'], [
        {'job_type_id': 'jt1', 'labour_sdg': 5000},
      ]);
      expect(body['p_home_lat'], 15.6);
    });

    test('time off is written as a half-open range in UTC', () async {
      server.on('/rest/v1/time_off', (_) => json(<Object>[], 201));
      await TechnicianRepository(server.client()).addTimeOff(
        technicianId: 't1',
        from: DateTime.utc(2026, 10, 15, 8),
        to: DateTime.utc(2026, 10, 15, 10),
      );
      expect(jsonDecode(server.requests.single.body), {
        'technician_id': 't1',
        'period': '[2026-10-15T08:00:00.000Z,2026-10-15T10:00:00.000Z)',
        'reason': null,
      });
    });

    test('a photo goes to the booking’s folder before it is attached', () async {
      server.on('/storage/v1/object/booking-photos', (_) => json({'Key': 'booking-photos/x'}));
      server.on('/rest/v1/rpc/tech_add_photo', (_) => json(rows('tech_bookings_offers').single));
      await TechnicianRepository(server.client()).addPhoto('b1', Uint8List(3), before: true);
      final upload = server.requests.first.url.path;
      expect(upload, startsWith('/storage/v1/object/booking-photos/b1/'));
      expect(upload, endsWith('.jpg'));
      expect(server.body(1), containsPair('p_kind', 'BEFORE'));
      expect(server.body(1)['p_image_key'], startsWith('b1/'));
    });
  });
}
