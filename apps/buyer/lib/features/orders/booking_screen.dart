import 'package:alghali_core/alghali_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../router.dart';
import '../../state/account.dart';
import '../../state/bookings.dart';
import '../../state/orders.dart';
import '../../widgets/buyer_widgets.dart';
import '../account/complaints_screens.dart';
import 'review_sheet.dart';

class BookingScreen extends ConsumerWidget {
  const BookingScreen({super.key, required this.bookingId});

  final String bookingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booking = ref.watch(bookingProvider(bookingId));
    return Scaffold(
      appBar: AppBar(title: Text(context.t.bookingTitle)),
      body: AsyncBody(
        value: booking,
        onRefresh: () => ref.read(bookingProvider(bookingId).notifier).refresh(),
        data: (b) => _BookingBody(booking: b),
      ),
    );
  }
}

class _BookingBody extends ConsumerWidget {
  const _BookingBody({required this.booking});

  final Booking booking;

  static const _showCode = {
    BookingStatus.accepted,
    BookingStatus.enRoute,
    BookingStatus.inProgress,
  };

  static const _cancelled = {
    BookingStatus.cancelledByBuyer,
    BookingStatus.cancelledByTech,
    BookingStatus.cancelledByAdmin,
    BookingStatus.expired,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final core = context.core;
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final b = booking;
    final catalogue = ref.watch(catalogueProvider);
    final settings = ref.watch(platformSettingsProvider);
    final reviewed = ref.watch(reviewedProvider);
    final now = ref.watch(clockProvider)();
    final order = b.orderId == null ? null : ref.watch(orderProvider(b.orderId!)).value;
    final freeUntil = b.startAt.subtract(Duration(hours: settings.cancelCutoffHours));
    final late = now.isAfter(freeUntil);

    final steps = <(BookingStatus, String)>[
      (BookingStatus.held, t.tlBooked),
      if (b.method == PaymentMethod.bankak || b.depositSdg > 0)
        (BookingStatus.pendingTechAccept, t.tlPaymentChecked),
      (BookingStatus.accepted, t.tlTechAccepted),
      if (b.place == BookingPlace.customer) (BookingStatus.enRoute, t.tlEnRoute),
      (BookingStatus.inProgress, t.tlWorking),
      (BookingStatus.completed, t.tlJobDone),
    ];
    final order_ = BookingStatus.values;
    final reached = steps.lastIndexWhere((s) => order_.indexOf(s.$1) <= order_.indexOf(b.status));

    Future<void> cancel() async {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(t.bookingCancelConfirm),
          content: Text(
            late ? t.bookingCancelLateNow : t.bookingCancelFree(context.dayTime(freeUntil)),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(t.bookingKeep)),
            TextButton(onPressed: () => Navigator.pop(context, true), child: Text(t.bookingCancel)),
          ],
        ),
      );
      if (!(ok ?? false)) return;
      try {
        await ref.read(bookingProvider(b.id).notifier).cancel();
        if (b.orderId != null) ref.invalidate(orderProvider(b.orderId!));
      } on BackendException catch (e) {
        if (context.mounted) showError(context, e);
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(Space.page, Space.lg, Space.page, Space.xxl),
      children: [
        Card(
          color: colors.brandSurface,
          child: Padding(
            padding: const EdgeInsets.all(Space.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.day(b.startAt),
                  style: theme.textTheme.titleMedium?.copyWith(color: colors.onBrandSurfaceMuted),
                ),
                Text(
                  context.time(b.startAt),
                  style: theme.textTheme.displaySmall?.copyWith(color: colors.onBrandSurface),
                ),
                const SizedBox(height: Space.sm),
                Wrap(
                  spacing: Space.sm,
                  runSpacing: Space.xs,
                  children: [
                    StatusPill(label: core.bookingStatus(b.status), tone: bookingTone(b.status)),
                    StatusPill(
                      label: b.place == BookingPlace.bay ? t.placeBay : t.placeHome,
                      icon: Icons.place_outlined,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Space.md),
        if (b.status == BookingStatus.awaitingPayment && (order?.needsTransfer ?? false))
          InfoBanner(
            tone: Tone.warning,
            title: t.orderAwaiting,
            message: t.bookingPayFirst,
            action: FilledButton(
              onPressed: () => context.push(Routes.payOrder(b.orderId!)),
              child: Text(t.orderPayNow),
            ),
          )
        else if (b.status == BookingStatus.awaitingPayment)
          InfoBanner(
            tone: Tone.info,
            icon: Icons.hourglass_top,
            title: t.bankakChecking,
            message: t.bankakCheckingBody,
          )
        else if (b.status == BookingStatus.pendingTechAccept)
          InfoBanner(
            tone: Tone.info,
            icon: Icons.hourglass_top,
            message: b.offer == null
                ? t.bookingWaitingTech(settings.techAcceptTimeoutMinutes)
                : t.bookingWaitingTechUntil(context.time(b.offer!.expiresAt)),
          )
        else if (b.status == BookingStatus.needsReschedule)
          InfoBanner(
            tone: Tone.warning,
            message: t.bookingNeedsTime,
            action: FilledButton(
              onPressed: () => _showReschedule(context, b),
              child: Text(t.bookingPickNewTime),
            ),
          )
        else if (b.status == BookingStatus.enRoute)
          _LiveLocation(booking: b)
        else if (b.status == BookingStatus.partDoesNotFit)
          InfoBanner(tone: Tone.warning, message: t.bookingNotFit)
        else if (_cancelled.contains(b.status))
          InfoBanner(tone: Tone.danger, message: b.cancelReason ?? t.bookingCancelledBody),
        if (_showCode.contains(b.status)) ...[
          const SizedBox(height: Space.md),
          SectionCard(
            child: Column(
              children: [
                Text(t.bookingCode, style: theme.textTheme.titleMedium),
                const SizedBox(height: Space.md),
                if (b.jobCode.isNotEmpty) BigDigits(b.jobCode),
                const SizedBox(height: Space.md),
                Text(
                  b.jobCodeLocked ? t.bookingCodeLocked : t.bookingCodeBody,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: Space.md),
        SectionCard(
          child: StatusTimeline(
            steps: [
              for (final (i, (_, title)) in steps.indexed)
                TimelineStep(
                  title,
                  b.status == BookingStatus.completed || i < reached
                      ? TimelineState.done
                      : i == reached
                      ? TimelineState.current
                      : TimelineState.upcoming,
                ),
            ],
          ),
        ),
        const SizedBox(height: Space.md),
        SectionCard(
          title: t.bookingTech,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TechnicianSummary(
                name: b.technicianName,
                rating: b.technicianRating,
                ratingCount: b.technicianRatingCount,
                verified: b.technicianVerified,
              ),
              if (b.technicianPhone != null) ...[
                const SizedBox(height: Space.md),
                ContactActions(live: true, phone: b.technicianPhone),
              ],
            ],
          ),
        ),
        const SizedBox(height: Space.md),
        SectionCard(
          title: t.bookingWhere,
          child: b.place == BookingPlace.bay && b.bayShopId != null
              ? _BayPlace(shop: catalogue.shop(b.bayShopId!), name: b.bayName)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(b.address?.label.tr(context) ?? '', style: theme.textTheme.titleSmall),
                    Text(
                      b.address?.description.tr(context) ?? '',
                      style: theme.textTheme.bodyMedium,
                    ),
                    if (b.locationNote != null)
                      Text(b.locationNote!, style: theme.textTheme.bodySmall),
                  ],
                ),
        ),
        const SizedBox(height: Space.md),
        SectionCard(
          title: t.bookingJob,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final item in b.items)
                KeyValueRow(
                  label: [
                    item.title.tr(context),
                    ?item.description,
                  ].where((s) => s.isNotEmpty).join(' — '),
                  value: core.minutes(item.minutes),
                ),
              if (b.variantId != null)
                Text(carLabel(context, catalogue, b.variantId!), style: theme.textTheme.bodySmall),
              const Divider(height: Space.xl),
              KeyValueRow(label: t.costLabour, value: context.sdg(b.labourSdg)),
              if (b.travelFeeSdg > 0)
                KeyValueRow(label: t.costTravel, value: context.sdg(b.travelFeeSdg)),
              KeyValueRow(label: t.costBookingFee, value: context.sdg(b.bookingFeeSdg)),
              KeyValueRow(label: t.costTotal, value: context.sdg(b.totalSdg), emphasis: true),
            ],
          ),
        ),
        if (b.photos.isNotEmpty) ...[const SizedBox(height: Space.md), _Photos(booking: b)],
        if (b.orderId != null) ...[
          const SizedBox(height: Space.md),
          OutlinedButton.icon(
            onPressed: () => context.push(Routes.order(b.orderId!)),
            icon: const Icon(Icons.receipt_long_outlined),
            label: Text(t.orderTitle),
          ),
        ],
        if (b.status == BookingStatus.completed && !reviewed.contains('tech:${b.id}')) ...[
          const SizedBox(height: Space.md),
          FilledButton.icon(
            onPressed: () => showReviewSheet(context, name: b.technicianName, bookingId: b.id),
            icon: const Icon(Icons.star_outline_rounded),
            label: Text(t.bookingRate),
          ),
        ],
        if (b.status != BookingStatus.held && b.status != BookingStatus.awaitingPayment) ...[
          const SizedBox(height: Space.sm),
          TextButton(
            onPressed: () => showComplaintSheet(context, bookingId: b.id),
            child: Text(t.complaintReport),
          ),
        ],
        if (b.isActive && b.status != BookingStatus.inProgress) ...[
          const SizedBox(height: Space.md),
          Text(
            late ? t.bookingCancelLateNow : t.bookingCancelLate(context.dayTime(freeUntil)),
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: Space.sm),
          OutlinedButton(
            style: OutlinedButton.styleFrom(foregroundColor: theme.colorScheme.error),
            onPressed: cancel,
            child: Text(t.bookingCancel),
          ),
        ],
      ],
    );
  }

  static Future<void> _showReschedule(BuildContext context, Booking b) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => _RescheduleSheet(booking: b),
      );
}

/// Where the technician is, live, while on the way (D-029).
class _LiveLocation extends ConsumerWidget {
  const _LiveLocation({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final theme = Theme.of(context);
    final now = ref.watch(clockProvider)();
    final location = ref.watch(technicianLocationProvider(booking.id)).value;
    final b = booking;
    final km = location == null || b.lat == null || b.lng == null
        ? null
        : distanceKm(location.lat, location.lng, b.lat!, b.lng!);
    return SectionCard(
      title: t.bookingLiveTitle,
      trailing: Icon(Icons.near_me_outlined, color: AppColors.of(context).info),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (location == null)
            Text(t.bookingLiveWaiting, style: theme.textTheme.bodyMedium)
          else ...[
            if (km != null)
              Text(
                t.bookingLiveAway(context.core.distance(km)),
                style: theme.textTheme.titleMedium,
              ),
            Text(
              t.bookingLiveUpdated(context.core.ago(location.at, now)),
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: Space.sm),
            OutlinedButton.icon(
              onPressed: () => Launch.mapAt(location.lat, location.lng),
              icon: const Icon(Icons.map_outlined),
              label: Text(t.bookingLiveMap),
            ),
          ],
        ],
      ),
    );
  }
}

class _Photos extends ConsumerWidget {
  const _Photos({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final keys = [for (final p in booking.photos) p.imageKey];
    final urls = ref.watch(bookingPhotoUrlsProvider(keys.join('\n'))).value ?? const {};
    return SectionCard(
      title: t.bookingPhotos,
      child: Wrap(
        spacing: Space.sm,
        runSpacing: Space.sm,
        children: [
          for (final p in booking.photos)
            Column(
              children: [
                ClipRRect(
                  borderRadius: Radii.smAll,
                  child: SizedBox.square(
                    dimension: 96,
                    child: urls[p.imageKey] == null
                        ? ColoredBox(
                            color: Theme.of(context).colorScheme.surfaceContainerHigh,
                            child: const Icon(Icons.image_outlined),
                          )
                        : Image.network(
                            urls[p.imageKey]!,
                            fit: BoxFit.cover,
                            cacheWidth: 288,
                            errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined),
                          ),
                  ),
                ),
                Text(p.before ? t.bookingPhotoBefore : t.bookingPhotoAfter),
              ],
            ),
        ],
      ),
    );
  }
}

class _BayPlace extends StatelessWidget {
  const _BayPlace({required this.shop, this.name});

  final Shop shop;
  final LocalizedText? name;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final catalogue = CatalogueScope.of(context);
    final shopName = shop.name.tr(context).isEmpty
        ? name?.tr(context) ?? ''
        : shop.name.tr(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.t.bookAtBay(shopName), style: theme.textTheme.titleSmall),
        Text(
          [
            shopPlace(context, catalogue, shop),
            shop.landmark.tr(context),
          ].where((s) => s.isNotEmpty).join(' · '),
          style: theme.textTheme.bodyMedium,
        ),
        Wrap(
          children: [
            TextButton.icon(
              onPressed: () => context.go(
                Uri(path: Routes.street, queryParameters: {'shop': shop.id}).toString(),
              ),
              icon: const Icon(Icons.map_outlined),
              label: Text(context.t.shopOnStreet),
            ),
            if (shop.lat != null && shop.lng != null)
              TextButton.icon(
                onPressed: () => Launch.directions(shop.lat!, shop.lng!),
                icon: const Icon(Icons.directions_outlined),
                label: Text(context.t.shopDirections),
              ),
          ],
        ),
      ],
    );
  }
}

/// A new time for a booking nobody could take (NEEDS_RESCHEDULE): the free starts of
/// every suitable technician, as "any available".
class _RescheduleSheet extends ConsumerStatefulWidget {
  const _RescheduleSheet({required this.booking});

  final Booking booking;

  @override
  ConsumerState<_RescheduleSheet> createState() => _RescheduleSheetState();
}

class _RescheduleSheetState extends ConsumerState<_RescheduleSheet> {
  DateTime? _day;
  ({DateTime start, String technicianId})? _slot;
  var _saving = false;

  FittingQuery get _query => FittingQuery(
    items: [for (final i in widget.booking.items) ?FittingItem.fromBooking(i)],
    place: widget.booking.place,
    addressId: widget.booking.address?.id.isEmpty ?? true ? null : widget.booking.address!.id,
    variantId: widget.booking.variantId,
  );

  Future<void> _save() async {
    final s = _slot;
    if (s == null) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(bookingProvider(widget.booking.id).notifier)
          .reschedule(s.start, technicianId: s.technicianId);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.t.bookingRescheduled)));
      Navigator.pop(context);
    } on BackendException catch (e) {
      if (mounted) showError(context, e);
      ref.invalidate(bookingOptionsProvider(_query));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = Theme.of(context);
    final options = ref.watch(bookingOptionsProvider(_query));
    final starts = options.value?.any ?? const [];
    final days = {for (final s in starts) khartoumDay(s.start)}.toList()..sort();
    final day = _day ?? days.firstOrNull;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.page, 0, Space.page, Space.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(t.bookingPickNewTime, style: theme.textTheme.titleLarge),
            const SizedBox(height: Space.md),
            switch (options) {
              AsyncError(:final error) => Text(context.core.error(error)),
              AsyncData() when starts.isEmpty => Text(t.bookNoSlots),
              AsyncData() => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    spacing: Space.sm,
                    runSpacing: Space.sm,
                    children: [
                      for (final d in days)
                        ChoiceChip(
                          label: Text(context.dayOfMonth(d.add(const Duration(hours: 10)))),
                          selected: d == day,
                          onSelected: (_) => setState(() {
                            _day = d;
                            _slot = null;
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: Space.md),
                  Wrap(
                    spacing: Space.sm,
                    runSpacing: Space.sm,
                    children: [
                      for (final s in starts.where((s) => khartoumDay(s.start) == day))
                        ChoiceChip(
                          label: Text(context.time(s.start)),
                          selected: _slot?.start == s.start,
                          onSelected: (_) => setState(() => _slot = s),
                        ),
                    ],
                  ),
                ],
              ),
              _ => const LinearProgressIndicator(),
            },
            const SizedBox(height: Space.lg),
            FilledButton(
              onPressed: _saving || _slot == null ? null : _save,
              child: Text(context.core.actionSave),
            ),
          ],
        ),
      ),
    );
  }
}
