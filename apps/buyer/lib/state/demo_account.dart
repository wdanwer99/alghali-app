import 'package:alghali_core/alghali_core.dart';

/// Sample history for the demo account (Ahmed and his Hilux): one finished
/// order, one order with a fitting booked for the next working day, a photo
/// request with two offers, notifications and a chat with a shop.
String _ref(String seven) => '$seven${luhnCheckDigit(seven)}';

/// [hour] o'clock Khartoum time on the next working day after [now].
DateTime nextWorkingDayAt(DateTime now, int hour) {
  var day = khartoumDay(now).add(const Duration(days: 1));
  if (day.weekday == DateTime.friday) day = day.add(const Duration(days: 1));
  return day.add(Duration(hours: hour)).subtract(khartoumOffset);
}

const demoAddresses = [
  Address(
    id: 'ad-home',
    label: LocalizedText('المنزل', 'Home'),
    description: LocalizedText(
      'الرياض، الخرطوم — شارع 15، منزل 7',
      'Riyadh, Khartoum — Street 15, house 7',
    ),
    distanceKm: 2.6,
  ),
  Address(
    id: 'ad-work',
    label: LocalizedText('العمل', 'Work'),
    description: LocalizedText('العمارات، شارع 41', 'Amarat, Street 41'),
    distanceKm: 6.2,
  ),
];

List<Order> demoOrders(DateTime now) {
  final weekAgo = now.subtract(const Duration(days: 9));
  final yesterday = now.subtract(const Duration(hours: 26));
  return [
    Order(
      id: 'ord-1002',
      ref: _ref('4815162'),
      createdAt: yesterday,
      payBy: yesterday.add(const Duration(hours: 2)),
      method: PaymentMethod.bankak,
      paymentStatus: PaymentStatus.confirmed,
      bookingId: 'bk-2001',
      bookingFeeSdg: 2000,
      labourSdg: 15000,
      txnNo: '200987361',
      subOrders: [
        SubOrder(
          id: 'so-1002-1',
          shopId: 'sh-tawfiq',
          status: SubOrderStatus.ready,
          fulfilment: FulfilmentType.toTechnician,
          acknowledgedAt: yesterday.add(const Duration(minutes: 70)),
          items: const [
            OrderItem(
              listingId: 'ls-13',
              partId: 'pt-pads-hilux',
              title: LocalizedText('فحمات فرامل أمامية', 'Front brake pads'),
              condition: ListingCondition.newAftermarket,
              unitPriceSdg: 38000,
              qty: 1,
              warrantyDays: 90,
            ),
          ],
          events: [
            StatusEvent(SubOrderStatus.pendingPayment, yesterday),
            StatusEvent(SubOrderStatus.paymentReview, yesterday.add(const Duration(minutes: 12))),
            StatusEvent(SubOrderStatus.confirmed, yesterday.add(const Duration(minutes: 41))),
            StatusEvent(SubOrderStatus.ready, now.subtract(const Duration(hours: 3))),
          ],
        ),
      ],
    ),
    Order(
      id: 'ord-1001',
      ref: _ref('7351920'),
      createdAt: weekAgo,
      payBy: weekAgo.add(const Duration(hours: 2)),
      method: PaymentMethod.bankak,
      paymentStatus: PaymentStatus.confirmed,
      txnNo: '200871544',
      subOrders: [
        SubOrder(
          id: 'so-1001-1',
          shopId: 'sh-farouq',
          status: SubOrderStatus.completed,
          fulfilment: FulfilmentType.pickup,
          acknowledgedAt: weekAgo.add(const Duration(minutes: 50)),
          items: const [
            OrderItem(
              listingId: 'ls-25',
              partId: 'pt-oil-filter-toyota',
              title: LocalizedText('فلتر زيت تويوتا', 'Toyota oil filter'),
              condition: ListingCondition.newOem,
              unitPriceSdg: 9500,
              qty: 1,
              warrantyDays: 30,
            ),
            OrderItem(
              listingId: 'ls-28',
              partId: 'pt-air-filter-hilux',
              title: LocalizedText('فلتر هواء المحرك', 'Engine air filter'),
              condition: ListingCondition.newOem,
              unitPriceSdg: 18000,
              qty: 1,
              warrantyDays: 30,
            ),
          ],
          events: [
            StatusEvent(SubOrderStatus.pendingPayment, weekAgo),
            StatusEvent(SubOrderStatus.paymentReview, weekAgo.add(const Duration(minutes: 8))),
            StatusEvent(SubOrderStatus.confirmed, weekAgo.add(const Duration(minutes: 35))),
            StatusEvent(SubOrderStatus.ready, weekAgo.add(const Duration(hours: 1))),
            StatusEvent(SubOrderStatus.pickedUp, weekAgo.add(const Duration(hours: 3))),
            StatusEvent(SubOrderStatus.completed, weekAgo.add(const Duration(days: 3))),
          ],
        ),
      ],
    ),
  ];
}

List<Booking> demoBookings(DateTime now) {
  final yesterday = now.subtract(const Duration(hours: 26));
  return [
    Booking(
      id: 'bk-2001',
      ref: _ref('5208113'),
      status: BookingStatus.accepted,
      technicianId: 'tc-babiker',
      place: BookingPlace.bay,
      bayShopId: 'sh-tawfiq',
      startAt: nextWorkingDayAt(now, 10),
      durationMin: 60,
      labourSdg: 15000,
      bookingFeeSdg: 2000,
      jobCode: '4815',
      orderId: 'ord-1002',
      partShopId: 'sh-tawfiq',
      variantId: 'v-hilux-16p',
      items: const [
        BookingItem(
          title: LocalizedText('فحمات فرامل أمامية', 'Front brake pads'),
          jobType: JobType.brakes,
          minutes: 60,
        ),
      ],
      events: [
        StatusEvent(BookingStatus.held, yesterday),
        StatusEvent(BookingStatus.awaitingPayment, yesterday.add(const Duration(minutes: 12))),
        StatusEvent(BookingStatus.pendingTechAccept, yesterday.add(const Duration(minutes: 41))),
        StatusEvent(BookingStatus.accepted, yesterday.add(const Duration(minutes: 52))),
      ],
    ),
  ];
}

List<PartRequest> demoRequests(DateTime now) {
  final created = now.subtract(const Duration(hours: 3));
  return [
    PartRequest(
      id: 'rq-3001',
      note: 'مقبض الباب الخلفي اليمين، لون كروم',
      status: RequestStatus.open,
      createdAt: created,
      expiresAt: created.add(const Duration(hours: 24)),
      variantId: 'v-hilux-16p',
      categoryId: 'cat-accessories',
      photoCount: 2,
      offers: [
        PartOffer(
          id: 'of-1',
          shopId: 'sh-amin',
          title: const LocalizedText(
            'مقبض باب خلفي يمين — كروم',
            'Rear right door handle — chrome',
          ),
          condition: ListingCondition.newAftermarket,
          priceSdg: 25000,
          warrantyDays: 30,
          validUntil: now.add(const Duration(hours: 20)),
          note: const LocalizedText('متوفر الآن، نفس اللون.', 'In stock now, same colour.'),
        ),
        PartOffer(
          id: 'of-2',
          shopId: 'sh-safi',
          title: const LocalizedText('مقبض باب خلفي يمين', 'Rear right door handle'),
          condition: ListingCondition.used,
          priceSdg: 12000,
          validUntil: now.add(const Duration(hours: 12)),
          note: const LocalizedText('مستعمل بحالة ممتازة.', 'Used, excellent condition.'),
        ),
      ],
    ),
  ];
}

List<AppNotification> demoNotifications(DateTime now) => [
  AppNotification(
    id: 'nt-4',
    kind: NotificationKind.booking,
    title: const LocalizedText('تذكير بموعد التركيب', 'Fitting reminder'),
    body: const LocalizedText(
      'موعدك غدًا مع عمر بابكر في ورشة التوفيق.',
      'Your fitting with Omer Babiker at the Al-Tawfiq bay is tomorrow.',
    ),
    at: now.subtract(const Duration(minutes: 40)),
    route: '/booking/bk-2001',
  ),
  AppNotification(
    id: 'nt-3',
    kind: NotificationKind.offer,
    title: const LocalizedText('وصلك عرض جديد', 'New offer'),
    body: const LocalizedText(
      'الأمين للإسبيرات أرسل عرضًا لمقبض الباب: 25,000 ج.س',
      'Al-Amin Spares sent an offer for your door handle: SDG 25,000',
    ),
    at: now.subtract(const Duration(hours: 2)),
    route: '/request/rq-3001',
  ),
  AppNotification(
    id: 'nt-2',
    kind: NotificationKind.order,
    title: const LocalizedText('قطعتك جاهزة', 'Your part is ready'),
    body: const LocalizedText(
      'جهّز التوفيق للفرامل فحمات الفرامل وسيسلّمها للفني.',
      'Al-Tawfiq prepared your brake pads and will hand them to the technician.',
    ),
    at: now.subtract(const Duration(hours: 3)),
    read: true,
    route: '/order/ord-1002',
  ),
  AppNotification(
    id: 'nt-1',
    kind: NotificationKind.payment,
    title: const LocalizedText('تم تأكيد دفعك', 'Payment confirmed'),
    body: const LocalizedText(
      'تأكدنا من تحويلك لطلب 4815 1625.',
      'We confirmed your transfer for order 4815 1625.',
    ),
    at: now.subtract(const Duration(hours: 25)),
    read: true,
    route: '/order/ord-1002',
  ),
];

Map<String, List<ChatMessage>> demoChats(DateTime now) => {
  'sh-farouq': [
    ChatMessage(
      id: 'm1',
      mine: true,
      text: 'السلام عليكم، عندكم فلتر هواء لهايلكس 2018؟',
      at: now.subtract(const Duration(days: 9, minutes: 30)),
    ),
    ChatMessage(
      id: 'm2',
      mine: false,
      text: 'وعليكم السلام، متوفر أصلي بـ 18,000 ونجهّزه لك خلال ساعة.',
      at: now.subtract(const Duration(days: 9, minutes: 26)),
    ),
    ChatMessage(
      id: 'm3',
      mine: true,
      voiceSecs: 12,
      at: now.subtract(const Duration(days: 9, minutes: 24)),
    ),
    ChatMessage(
      id: 'm4',
      mine: false,
      text: 'تمام، الطلب جاهز للاستلام. مرحبًا بك.',
      at: now.subtract(const Duration(days: 9, minutes: 2)),
    ),
  ],
};
