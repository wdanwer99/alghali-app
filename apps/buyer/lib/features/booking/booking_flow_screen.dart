import 'dart:async';

import 'package:alghali_core/alghali_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../router.dart';
import '../../state/account.dart';
import '../../state/bookings.dart';
import '../../state/cart.dart';
import '../../state/garage.dart';
import '../../state/orders.dart';
import '../../state/session.dart';
import '../../widgets/buyer_widgets.dart';
import '../account/address_sheet.dart';
import '../account/profile_sheet.dart';

/// Book a fitting: for cart parts ([lineId], joining the cart's fitting if there is
/// one), a part from an earlier order ([orderItemId]), or a part bought elsewhere
/// (neither): what → place → technician → time → review. The technicians and times come
/// from the slot engine (`booking-slots`); holding a time is checked again by the server.
class BookingFlowScreen extends ConsumerStatefulWidget {
  const BookingFlowScreen({super.key, this.lineId, this.orderItemId, this.orderItemTitle});

  final String? lineId;
  final String? orderItemId;
  final String? orderItemTitle;

  @override
  ConsumerState<BookingFlowScreen> createState() => _BookingFlowScreenState();
}

enum _Step { what, place, tech, time, review }

class _BookingFlowScreenState extends ConsumerState<BookingFlowScreen> {
  late final bool _standalone = widget.lineId == null && widget.orderItemId == null;
  late final List<_Step> _steps = [
    if (_standalone) _Step.what,
    _Step.place,
    _Step.tech,
    _Step.time,
    _Step.review,
  ];
  var _index = 0;

  JobType? _job;
  final _description = TextEditingController();
  BookingPlace? _place;
  Address? _address;
  var _any = false;
  String? _techId;
  DateTime? _day;
  DateTime? _start;
  var _method = PaymentMethod.bankak;
  var _busy = false;
  Booking? _held;
  final _idem = newIdempotencyKey();

  _Step get _step => _steps[_index];

  /// The cart lines this fitting covers: the cart's fitting plus this line.
  late final Set<String> _lineIds = {...?ref.read(cartProvider).fitting?.lineIds, ?widget.lineId};

  @override
  void initState() {
    super.initState();
    final f = ref.read(cartProvider).fitting;
    if (widget.lineId != null && f != null) {
      _place = f.place;
      _address = f.booking.address;
      _any = f.anyTechnician;
      _techId = f.anyTechnician ? null : f.booking.technicianId;
      _day = khartoumDay(f.start);
    }
  }

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  List<CartLine> get _lines =>
      ref.read(cartProvider).lines.where((l) => _lineIds.contains(l.id)).toList();

  List<FittingItem> get _items {
    if (widget.orderItemId != null) return [FittingItem.orderItem(widget.orderItemId!)];
    if (!_standalone) return [for (final l in _lines) l.fittingItem];
    final job = _job;
    if (job == null) return const [];
    final category = ref
        .read(catalogueProvider)
        .categories
        .where((c) => c.jobType == job)
        .firstOrNull;
    if (category == null) return const [];
    final text = _description.text.trim();
    return [FittingItem.category(category.id, text.isEmpty ? context.core.jobType(job) : text)];
  }

  FittingQuery? get _query {
    final items = _items;
    final place = _place;
    if (items.isEmpty || place == null) return null;
    if (place == BookingPlace.customer && _address == null) return null;
    return FittingQuery(
      items: items,
      place: place,
      addressId: place == BookingPlace.customer ? _address!.id : null,
      variantId: ref.read(selectedVariantProvider),
    );
  }

  /// The free starts on [_day]: for "any", each with the best technician who has it.
  List<({DateTime start, String technicianId})> _slots(
    BookingOptions options,
    BookingOptions? tech,
  ) {
    final day = _day;
    bool onDay(DateTime t) => day != null && khartoumDay(t) == day;
    if (_any) {
      return [
        for (final a in options.any)
          if (onDay(a.start)) a,
      ];
    }
    final id = _techId;
    if (id == null || tech == null) return const [];
    final t = tech.technicians.where((x) => x.id == id).firstOrNull;
    return [
      for (final s in t?.slots ?? const <DateTime>[])
        if (onDay(s)) (start: s, technicianId: id),
    ];
  }

  TechnicianOption? _assignee(BookingOptions options) {
    final id = _any
        ? options.any.where((a) => a.start == _start).firstOrNull?.technicianId
        : _techId;
    return options.technicians.where((t) => t.id == id).firstOrNull;
  }

  void _resetFrom(_Step step) {
    _held = null;
    if (step.index <= _Step.tech.index) {
      _techId = null;
      _any = false;
    }
    if (step.index <= _Step.time.index) _start = null;
  }

  bool _valid(BookingOptions? options) => switch (_step) {
    _Step.what => _job != null && _items.isNotEmpty,
    _Step.place => _query != null,
    _Step.tech => options != null && options.technicians.isNotEmpty && (_any || _techId != null),
    _Step.time => _start != null,
    _Step.review => !_busy,
  };

  void _next() => setState(() {
    if (_index < _steps.length - 1) _index++;
  });

  void _back() {
    if (_index == 0) {
      context.pop();
    } else {
      setState(() => _index--);
    }
  }

  Future<bool> _ensureSignedIn() async {
    if (ref.read(sessionProvider).signedIn) return true;
    await context.push<void>(Routes.signIn);
    return mounted && ref.read(sessionProvider).signedIn;
  }

  Future<void> _finish(BookingOptions options) async {
    if (!await _ensureSignedIn()) return;
    final tech = _assignee(options);
    final start = _start;
    final query = _query;
    if (tech == null || start == null || query == null) return;
    setState(() => _busy = true);
    try {
      final held =
          _held ??
          await ref
              .read(bookingsRepositoryProvider)
              .hold(
                technicianId: tech.id,
                start: start,
                items: query.items,
                place: query.place,
                addressId: query.addressId,
                variantId: query.variantId,
                any: _any,
              );
      _held = held;
      if (!mounted) return;
      if (!_standalone && widget.orderItemId == null) {
        ref
            .read(cartProvider.notifier)
            .attachFitting(FittingDraft(booking: held, lineIds: _lineIds, anyTechnician: _any));
        context.pop();
        return;
      }
      final order = await ref
          .read(ordersProvider.notifier)
          .checkoutFitting(held, _method, idem: _idem);
      if (!mounted) return;
      context.go(Uri(path: Routes.orders, queryParameters: {'tab': 'bookings'}).toString());
      unawaited(
        context.push(order.needsTransfer ? Routes.payOrder(order.id) : Routes.booking(held.id)),
      );
    } on BackendException catch (e) {
      if (!mounted) return;
      if (e.code == 'PHONE_REQUIRED') {
        await showProfileSheet(context, askPhone: true);
        return;
      }
      if (e.code == 'SLOT_TAKEN' || e.code == 'TECHNICIAN_UNSUITABLE' || e.code == 'HOLD_EXPIRED') {
        _held = null;
        ref.invalidate(bookingOptionsProvider);
        setState(() {
          _start = null;
          _index = _steps.indexOf(_Step.time);
        });
      }
      showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final query = _query;
    final options = query == null ? null : ref.watch(bookingOptionsProvider(query));
    final techOptions = query == null || _any || _techId == null
        ? null
        : ref.watch(bookingOptionsProvider(query.forTechnician(_techId)));
    final labels = [
      if (_standalone) t.bookStepWhat,
      t.bookStepPlace,
      t.bookStepTech,
      t.bookStepTime,
    ];

    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(t.bookTitle),
          leading: IconButton(
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            onPressed: _back,
            icon: const BackButtonIcon(),
          ),
        ),
        body: Column(
          children: [
            Container(
              color: Theme.of(context).colorScheme.surface,
              padding: const EdgeInsets.fromLTRB(Space.sm, Space.md, Space.sm, Space.md),
              child: StepProgress(steps: labels, current: _index.clamp(0, labels.length - 1)),
            ),
            const Divider(),
            Expanded(
              child: AnimatedSwitcher(
                duration: Motion.medium,
                child: KeyedSubtree(
                  key: ValueKey(_step),
                  child: switch (_step) {
                    _Step.what => _whatStep(context),
                    _Step.place => _placeStep(context),
                    _Step.tech => _options(options, (o) => _techStep(context, o)),
                    _Step.time => _options(
                      options,
                      (o) => _any
                          ? _timeStep(context, o, null)
                          : _options(techOptions, (to) => _timeStep(context, o, to)),
                    ),
                    _Step.review => _options(options, (o) => _reviewStep(context, o)),
                  },
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: BottomActionBar(
          child: FilledButton(
            onPressed: !_valid(options?.value)
                ? null
                : _step == _Step.review
                ? () => _finish(options!.value!)
                : _next,
            child: _busy
                ? const SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  )
                : Text(switch (_step) {
                    _Step.review =>
                      _standalone || widget.orderItemId != null ? t.bookConfirm : t.bookHold,
                    _Step.time when _start == null => t.bookPickTime,
                    _ => context.core.actionNext,
                  }),
          ),
        ),
      ),
    );
  }

  /// Loading and failures of the slot engine, shared by the steps that need it.
  Widget _options(AsyncValue<BookingOptions>? value, Widget Function(BookingOptions) data) {
    return switch (value) {
      AsyncData(:final value) => data(value),
      AsyncError(:final error) => ListView(
        children: [
          EmptyState(
            icon: Icons.cloud_off_outlined,
            title: context.core.error(error),
            action: OutlinedButton.icon(
              onPressed: () => ref.invalidate(bookingOptionsProvider),
              icon: const Icon(Icons.refresh),
              label: Text(context.core.actionRetry),
            ),
          ),
        ],
      ),
      _ => const SkeletonList(),
    };
  }

  Widget _whatStep(BuildContext context) {
    final t = context.t;
    final core = context.core;
    final jobs = {for (final c in ref.watch(catalogueProvider).categories) ?c.jobType};
    return ListView(
      padding: Space.pageInsets,
      children: [
        Text(t.bookWhatTitle, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: Space.sm),
        InfoBanner(tone: Tone.neutral, message: t.bookWhatNote),
        const SizedBox(height: Space.lg),
        Text(t.bookWhatJob, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: Space.sm),
        Wrap(
          spacing: Space.sm,
          runSpacing: Space.sm,
          children: [
            for (final j in JobType.values.where(jobs.contains))
              ChoiceChip(
                label: Text(core.jobType(j)),
                selected: _job == j,
                onSelected: (_) => setState(() {
                  _job = j;
                  _resetFrom(_Step.tech);
                }),
              ),
          ],
        ),
        const SizedBox(height: Space.lg),
        TextField(
          controller: _description,
          maxLines: 2,
          onChanged: (_) => setState(() => _resetFrom(_Step.tech)),
          decoration: InputDecoration(labelText: t.bookWhatHint),
        ),
      ],
    );
  }

  Widget _placeStep(BuildContext context) {
    final t = context.t;
    final settings = ref.watch(platformSettingsProvider);
    final catalogue = ref.watch(catalogueProvider);
    final signedIn = ref.watch(sessionProvider.select((s) => s.signedIn));
    final addresses = signedIn
        ? ref.watch(addressesProvider).value ?? const <Address>[]
        : const <Address>[];
    final homeAvailable = catalogue.streetOrigin != null;

    Future<void> addHere() async {
      if (!await _ensureSignedIn() || !context.mounted) return;
      final a = await showAddressSheet(context);
      if (a != null && mounted) {
        setState(() {
          _address = a;
          _resetFrom(_Step.tech);
        });
      }
    }

    return ListView(
      padding: Space.pageInsets,
      children: [
        Text(t.bookPlaceTitle, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: Space.lg),
        ChoiceCard(
          selected: _place == BookingPlace.bay,
          onTap: () => setState(() {
            _place = BookingPlace.bay;
            _resetFrom(_Step.tech);
          }),
          icon: Icons.store_mall_directory_outlined,
          title: t.bookPlaceBay,
          subtitle: t.bookPlaceBayBody,
        ),
        const SizedBox(height: Space.md),
        ChoiceCard(
          selected: _place == BookingPlace.customer,
          onTap: homeAvailable
              ? () => setState(() {
                  _place = BookingPlace.customer;
                  _address ??= addresses.firstOrNull;
                  _resetFrom(_Step.tech);
                })
              : null,
          icon: Icons.home_work_outlined,
          title: t.bookPlaceHome,
          subtitle: homeAvailable
              ? t.bookPlaceHomeBody(context.sdg(settings.minTravelFee))
              : context.core.errTravelUnavailable,
        ),
        if (_place == BookingPlace.customer) ...[
          const SizedBox(height: Space.xl),
          Text(t.bookAddress, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: Space.sm),
          for (final a in addresses) ...[
            ChoiceCard(
              selected: _address?.id == a.id,
              onTap: () => setState(() {
                _address = a;
                _resetFrom(_Step.tech);
              }),
              icon: Icons.location_on_outlined,
              title: a.label.tr(context),
              subtitle: [
                if (a.description.tr(context).isNotEmpty) a.description.tr(context),
                context.core.distance(a.distanceKm),
              ].join(' · '),
              trailing: switch (settings.travelFee(a.distanceKm)) {
                final fee? => Text(
                  context.sdg(fee),
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                null => Text(t.bookTooFar, style: Theme.of(context).textTheme.labelMedium),
              },
            ),
            const SizedBox(height: Space.sm),
          ],
          TextButton.icon(
            onPressed: addHere,
            icon: const Icon(Icons.my_location),
            label: Text(t.bookUseLocation),
          ),
        ],
      ],
    );
  }

  Widget _techStep(BuildContext context, BookingOptions options) {
    final t = context.t;
    final techs = options.technicians;
    if (techs.isEmpty) {
      return ListView(
        children: [
          EmptyState(
            icon: Icons.engineering_outlined,
            title: t.bookNoTechs,
            message: t.bookNoTechsBody,
          ),
        ],
      );
    }
    final range = options.labourRange;
    final price = range == null
        ? ''
        : range.min == range.max
        ? context.sdg(range.min)
        : context.core.money(ltr('${groupDigits(range.min)}–${groupDigits(range.max)}'));

    return ListView(
      padding: Space.pageInsets,
      children: [
        Text(t.bookTechTitle, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: Space.lg),
        ChoiceCard(
          selected: _any,
          onTap: options.any.isEmpty
              ? null
              : () => setState(() {
                  _any = true;
                  _techId = null;
                  _start = null;
                  _held = null;
                }),
          icon: Icons.bolt_outlined,
          title: t.bookAnyTech,
          subtitle: [t.bookAnyTechBody, if (price.isNotEmpty) '${t.costLabour}: $price'].join('\n'),
        ),
        const SizedBox(height: Space.md),
        for (final tech in techs) ...[
          _TechOption(
            tech: tech,
            selected: !_any && _techId == tech.id,
            where: _place == BookingPlace.bay
                ? t.bookAtBay(tech.bay?.name.tr(context) ?? '')
                : tech.distanceKm == null
                ? ''
                : t.bookAway(context.core.distance(tech.distanceKm!)),
            onTap: () => setState(() {
              _any = false;
              _techId = tech.id;
              _start = null;
              _held = null;
            }),
          ),
          const SizedBox(height: Space.sm),
        ],
      ],
    );
  }

  Widget _timeStep(BuildContext context, BookingOptions options, BookingOptions? techOptions) {
    final t = context.t;
    final core = context.core;
    final theme = Theme.of(context);
    final settings = ref.read(platformSettingsProvider);
    final now = ref.read(clockProvider)();
    final days = upcomingDays(now, count: settings.bookingLookaheadDays.clamp(1, 14));
    // Open on the first day with a free time, not on a full or finished today.
    final firstFree = _any
        ? options.any.firstOrNull?.start
        : techOptions?.technicians.firstOrNull?.slots.firstOrNull;
    final day = _day ?? (firstFree == null ? days.first : khartoumDay(firstFree));
    _day ??= day;
    final slots = _slots(options, techOptions);

    // [d] is Khartoum midnight; +10 h UTC is midday there, safely inside the day.
    String dayLabel(int i, DateTime d) => i == 0
        ? core.today
        : i == 1
        ? core.tomorrow
        : context.weekday(d.add(const Duration(hours: 10)));

    return ListView(
      padding: Space.pageInsets,
      children: [
        Text(t.bookTimeTitle, style: theme.textTheme.titleLarge),
        const SizedBox(height: Space.xs),
        Text(t.bookEarliest, style: theme.textTheme.bodySmall),
        const SizedBox(height: Space.lg),
        SizedBox(
          height: 76,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: days.length,
            separatorBuilder: (_, _) => const SizedBox(width: Space.sm),
            itemBuilder: (context, i) {
              final d = days[i];
              final selected = d == day;
              final scheme = theme.colorScheme;
              return Material(
                color: selected ? scheme.secondary : scheme.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: Radii.mdAll,
                  side: BorderSide(color: selected ? scheme.secondary : scheme.outlineVariant),
                ),
                child: InkWell(
                  borderRadius: Radii.mdAll,
                  onTap: () => setState(() {
                    _day = d;
                    _start = null;
                    _held = null;
                  }),
                  child: SizedBox(
                    width: 76,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          dayLabel(i, d),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: selected ? scheme.onSecondary : scheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          '${d.day}',
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: selected ? scheme.onSecondary : scheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: Space.xl),
        if (slots.isEmpty)
          InfoBanner(tone: Tone.neutral, message: t.bookNoSlots)
        else
          Wrap(
            spacing: Space.sm,
            runSpacing: Space.sm,
            children: [
              for (final s in slots)
                ChoiceChip(
                  label: Text(context.time(s.start)),
                  selected: _start == s.start,
                  onSelected: (_) => setState(() {
                    _start = s.start;
                    _held = null;
                  }),
                ),
            ],
          ),
      ],
    );
  }

  Widget _reviewStep(BuildContext context, BookingOptions options) {
    final t = context.t;
    final core = context.core;
    final theme = Theme.of(context);
    final settings = ref.read(platformSettingsProvider);
    final tech = _assignee(options);
    if (tech == null || _start == null) return const SizedBox.shrink();
    final labour = tech.labourSdg;
    final travel = options.travelFeeSdg;
    final total = labour + travel + options.bookingFeeSdg;
    final what = switch (widget.orderItemTitle) {
      final title? => title,
      _ when !_standalone => _lines.map((l) => l.title.tr(context)).join('، '),
      _ => _description.text.trim().isEmpty ? core.jobType(_job!) : _description.text.trim(),
    };
    final paysHere = _standalone || widget.orderItemId != null;

    return ListView(
      padding: Space.pageInsets,
      children: [
        Text(t.bookReviewTitle, style: theme.textTheme.titleLarge),
        const SizedBox(height: Space.lg),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              KeyValueRow(label: t.bookingJob, value: what),
              KeyValueRow(
                label: t.bookingWhere,
                value: _place == BookingPlace.bay
                    ? t.bookAtBay(tech.bay?.name.tr(context) ?? '')
                    : _address!.label.tr(context),
              ),
              KeyValueRow(
                label: t.bookingTech,
                value: _any ? '${t.cartAnyTech} · ${tech.name}' : tech.name,
              ),
              KeyValueRow(label: t.bookWhen, value: context.dayTime(_start!)),
              KeyValueRow(label: t.bookDuration, value: core.minutes(options.durationMin)),
            ],
          ),
        ),
        const SizedBox(height: Space.md),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              KeyValueRow(label: t.costLabour, value: context.sdg(labour)),
              if (travel > 0) KeyValueRow(label: t.costTravel, value: context.sdg(travel)),
              KeyValueRow(label: t.costBookingFee, value: context.sdg(options.bookingFeeSdg)),
              const Divider(height: Space.xl),
              KeyValueRow(label: t.costTotal, value: context.sdg(total), emphasis: true),
            ],
          ),
        ),
        const SizedBox(height: Space.md),
        if (paysHere) ...[
          Text(t.checkoutPayment, style: theme.textTheme.titleSmall),
          const SizedBox(height: Space.sm),
          ChoiceCard(
            selected: _method == PaymentMethod.bankak,
            onTap: () => setState(() => _method = PaymentMethod.bankak),
            icon: Icons.account_balance_outlined,
            title: t.checkoutBankak,
            subtitle: t.checkoutBankakBody,
          ),
          const SizedBox(height: Space.sm),
          ChoiceCard(
            selected: _method == PaymentMethod.cash,
            onTap: () => setState(() => _method = PaymentMethod.cash),
            icon: Icons.payments_outlined,
            title: t.checkoutCash,
            subtitle: t.checkoutCashBody,
          ),
          if (_method == PaymentMethod.cash &&
              _place == BookingPlace.customer &&
              options.mobileDepositSdg > 0) ...[
            const SizedBox(height: Space.sm),
            InfoBanner(
              tone: Tone.info,
              message: t.bookDepositNote(context.sdg(options.mobileDepositSdg)),
            ),
          ],
          const SizedBox(height: Space.md),
        ],
        InfoBanner(
          tone: Tone.neutral,
          icon: Icons.event_available_outlined,
          message: paysHere
              ? t.bookCancelNote(settings.cancelCutoffHours)
              : '${t.bookHoldNote(settings.slotHoldMinutes)} ${t.bookCancelNote(settings.cancelCutoffHours)}',
        ),
      ],
    );
  }
}

class _TechOption extends StatelessWidget {
  const _TechOption({
    required this.tech,
    required this.selected,
    required this.where,
    required this.onTap,
  });

  final TechnicianOption tech;
  final bool selected;
  final String where;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final t = context.t;
    final next = tech.nextSlot;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: Radii.mdAll,
          side: BorderSide(
            color: selected ? scheme.secondary : scheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: tech.slotCount == 0 ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.all(Space.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TechnicianSummary(
                  name: tech.name,
                  rating: tech.rating,
                  ratingCount: tech.ratingCount,
                  completedJobs: tech.completedJobs,
                  verified: tech.verified,
                  subtitle: [
                    if (where.isNotEmpty) where,
                    t.bookYears(tech.yearsExperience),
                  ].join(' · '),
                  trailing: Icon(
                    selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                    color: selected ? scheme.secondary : scheme.outline,
                  ),
                ),
                const SizedBox(height: Space.sm),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        next == null ? t.bookNoFreeTime : t.bookNextFree(context.dayTime(next)),
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    const SizedBox(width: Space.sm),
                    Text(
                      context.sdg(tech.labourSdg),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontFeatures: AppTypography.tabular,
                      ),
                    ),
                  ],
                ),
                if (tech.bio != null) ...[
                  const SizedBox(height: Space.xs),
                  Text(
                    tech.bio!.tr(context),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
