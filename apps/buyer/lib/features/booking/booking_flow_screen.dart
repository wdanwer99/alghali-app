import 'package:alghali_core/alghali_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../router.dart';
import '../../state/cart.dart';
import '../../state/garage.dart';
import '../../state/orders.dart';
import '../../state/session.dart';
import '../../widgets/buyer_widgets.dart';

/// Add fitting to a cart line ([lineId]) or book fitting for a part bought
/// elsewhere (no [lineId]): place → technician → time → review.
class BookingFlowScreen extends ConsumerStatefulWidget {
  const BookingFlowScreen({super.key, this.lineId});

  final String? lineId;

  @override
  ConsumerState<BookingFlowScreen> createState() => _BookingFlowScreenState();
}

enum _Step { what, place, tech, time, review }

class _BookingFlowScreenState extends ConsumerState<BookingFlowScreen> {
  late final List<_Step> _steps = [
    if (widget.lineId == null) _Step.what,
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
  Slot? _slot;
  var _method = PaymentMethod.bankak;

  static const _defaultMinutes = {
    JobType.lighting: 30,
    JobType.brakes: 60,
    JobType.service: 30,
    JobType.battery: 20,
    JobType.electrical: 60,
    JobType.ac: 90,
    JobType.suspension: 120,
    JobType.tyres: 30,
  };

  _Step get _step => _steps[_index];

  CartLine? get _line => ref.read(cartProvider).where((l) => l.id == widget.lineId).firstOrNull;

  @override
  void initState() {
    super.initState();
    final f = _line?.fitting;
    if (f != null) {
      _place = f.place;
      _address = f.address;
      _any = f.anyTechnician;
      _techId = f.anyTechnician ? null : f.technicianId;
      _day = khartoumDay(f.slot.start);
    }
  }

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  JobType? get _jobType {
    final line = _line;
    if (line == null) return _job;
    return ref.read(catalogueProvider).category(line.categoryId).jobType;
  }

  int get _minutes {
    final line = _line;
    final catalogue = ref.read(catalogueProvider);
    if (line != null) {
      final part = line.partId == null || line.partId!.isEmpty
          ? null
          : catalogue.part(line.partId!);
      return part?.standardMinutes ?? catalogue.category(line.categoryId).standardMinutes ?? 60;
    }
    return _defaultMinutes[_job] ?? 60;
  }

  List<Technician> _eligible(CatalogueData c, String? variantId) {
    final job = _jobType;
    if (job == null || _place == null) return const [];
    final make = variantId == null ? null : c.makeOfVariant(variantId).id;
    final list = c.technicians.where((t) {
      if (!t.labourSdg.containsKey(job)) return false;
      if (make != null && t.makeIds.isNotEmpty && !t.makeIds.contains(make)) return false;
      return _place == BookingPlace.bay
          ? t.worksAtBay
          : t.comesToYou && (_address?.distanceKm ?? 0) <= t.radiusKm;
    }).toList()..sort((a, b) => technicianScore(b).compareTo(technicianScore(a)));
    return list;
  }

  int? _travelFee(PlatformSettings s) =>
      _place == BookingPlace.customer ? s.travelFee(_address?.distanceKm ?? 0) : 0;

  bool _valid(List<Technician> eligible) => switch (_step) {
    _Step.what => _job != null,
    _Step.place =>
      _place == BookingPlace.bay || (_place == BookingPlace.customer && _address != null),
    _Step.tech => eligible.isNotEmpty && (_any || _techId != null),
    _Step.time => _slot != null,
    _Step.review => true,
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

  /// The technician who takes the slot: the chosen one, or for "any" the
  /// best-ranked one free at that time.
  Technician _assignee(List<Technician> eligible) {
    if (!_any) return eligible.firstWhere((t) => t.id == _techId);
    return eligible.firstWhere((t) => isFree(t.id, _slot!.start), orElse: () => eligible.first);
  }

  Future<void> _finish(List<Technician> eligible) async {
    // Guests sign in on top of the flow and come back to the same step.
    if (widget.lineId == null && !ref.read(sessionProvider).signedIn) {
      await context.push<void>(Routes.signIn);
      if (!mounted || !ref.read(sessionProvider).signedIn) return;
    }
    final settings = ref.read(platformSettingsProvider);
    final now = ref.read(clockProvider)();
    final tech = _assignee(eligible);
    final draft = FittingDraft(
      place: _place!,
      technicianId: tech.id,
      anyTechnician: _any,
      slot: _slot!,
      labourSdg: tech.labourSdg[_jobType]!,
      travelFeeSdg: _travelFee(settings) ?? 0,
      heldUntil: now.add(Duration(minutes: settings.slotHoldMinutes)),
      address: _place == BookingPlace.customer ? _address : null,
    );
    final line = _line;
    if (line != null) {
      ref.read(cartProvider.notifier).attachFitting(line.id, draft);
      context.pop();
      return;
    }
    final booking = ref
        .read(bookingsProvider.notifier)
        .createStandalone(
          draft: draft,
          jobType: _job!,
          description: _description.text.trim().isEmpty
              ? context.core.jobType(_job!)
              : _description.text.trim(),
          method: _method,
          variantId: ref.read(selectedVariantProvider),
        );
    context.pushReplacement(
      booking.bankakDueSdg > 0 ? Routes.payBooking(booking.id) : Routes.booking(booking.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final catalogue = ref.watch(catalogueProvider);
    final settings = ref.watch(platformSettingsProvider);
    final variantId = ref.watch(selectedVariantProvider);
    final eligible = _eligible(catalogue, variantId);
    final labels = [
      if (widget.lineId == null) t.bookStepWhat,
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
              child: StepProgress(steps: labels, current: _index),
            ),
            const Divider(),
            Expanded(
              child: AnimatedSwitcher(
                duration: Motion.medium,
                child: KeyedSubtree(
                  key: ValueKey(_step),
                  child: switch (_step) {
                    _Step.what => _whatStep(context),
                    _Step.place => _placeStep(context, settings),
                    _Step.tech => _techStep(context, eligible, settings),
                    _Step.time => _timeStep(context, eligible),
                    _Step.review => _reviewStep(context, eligible, settings),
                  },
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: BottomActionBar(
          child: FilledButton(
            onPressed: !_valid(eligible)
                ? null
                : _step == _Step.review
                ? () => _finish(eligible)
                : _next,
            child: Text(switch (_step) {
              _Step.review => widget.lineId == null ? t.bookConfirm : t.bookHold,
              _Step.time when _slot == null => t.bookPickTime,
              _ => context.core.actionNext,
            }),
          ),
        ),
      ),
    );
  }

  Widget _whatStep(BuildContext context) {
    final t = context.t;
    final core = context.core;
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
            for (final j in JobType.values)
              ChoiceChip(
                label: Text(core.jobType(j)),
                selected: _job == j,
                onSelected: (_) => setState(() {
                  _job = j;
                  _techId = null;
                  _slot = null;
                }),
              ),
          ],
        ),
        const SizedBox(height: Space.lg),
        TextField(
          controller: _description,
          maxLines: 2,
          decoration: InputDecoration(labelText: t.bookWhatHint),
        ),
      ],
    );
  }

  Widget _placeStep(BuildContext context, PlatformSettings settings) {
    final t = context.t;
    final addresses = ref.watch(addressesProvider);
    return ListView(
      padding: Space.pageInsets,
      children: [
        Text(t.bookPlaceTitle, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: Space.lg),
        ChoiceCard(
          selected: _place == BookingPlace.bay,
          onTap: () => setState(() {
            _place = BookingPlace.bay;
            _techId = null;
            _slot = null;
          }),
          icon: Icons.store_mall_directory_outlined,
          title: t.bookPlaceBay,
          subtitle: t.bookPlaceBayBody,
        ),
        const SizedBox(height: Space.md),
        ChoiceCard(
          selected: _place == BookingPlace.customer,
          onTap: () => setState(() {
            _place = BookingPlace.customer;
            _address ??= addresses.first;
            _techId = null;
            _slot = null;
          }),
          icon: Icons.home_work_outlined,
          title: t.bookPlaceHome,
          subtitle: t.bookPlaceHomeBody(context.sdg(settings.minTravelFee)),
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
                _slot = null;
              }),
              icon: a.id == 'ad-here' ? Icons.my_location : Icons.location_on_outlined,
              title: a.label.tr(context),
              subtitle: '${a.description.tr(context)} · ${context.core.distance(a.distanceKm)}',
              trailing: Text(
                context.sdg(settings.travelFee(a.distanceKm) ?? 0),
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
            const SizedBox(height: Space.sm),
          ],
          if (!addresses.any((a) => a.id == 'ad-here'))
            TextButton.icon(
              onPressed: () => setState(() {
                _address = ref.read(addressesProvider.notifier).addCurrentLocation();
                _slot = null;
              }),
              icon: const Icon(Icons.my_location),
              label: Text(t.bookUseLocation),
            ),
        ],
      ],
    );
  }

  Widget _techStep(BuildContext context, List<Technician> eligible, PlatformSettings settings) {
    final t = context.t;
    final catalogue = ref.read(catalogueProvider);
    final job = _jobType!;
    if (eligible.isEmpty) {
      return EmptyState(icon: Icons.engineering_outlined, title: t.bookNoTechs);
    }
    final prices = eligible.map((e) => e.labourSdg[job]!).toList()..sort();
    final range = prices.first == prices.last
        ? context.sdg(prices.first)
        : context.core.money(ltr('${groupDigits(prices.first)}–${groupDigits(prices.last)}'));

    return ListView(
      padding: Space.pageInsets,
      children: [
        Text(t.bookTechTitle, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: Space.lg),
        ChoiceCard(
          selected: _any,
          onTap: () => setState(() {
            _any = true;
            _techId = null;
            _slot = null;
          }),
          icon: Icons.bolt_outlined,
          title: t.bookAnyTech,
          subtitle: '${t.bookAnyTechBody}\n${t.costLabour}: $range',
        ),
        const SizedBox(height: Space.md),
        for (final tech in eligible) ...[
          _TechOption(
            tech: tech,
            selected: !_any && _techId == tech.id,
            labour: tech.labourSdg[job]!,
            where: _place == BookingPlace.bay
                ? t.bookAtBay(catalogue.shop(tech.bayShopId!).name.tr(context))
                : t.bookAway(context.core.distance(tech.distanceKm)),
            onTap: () => setState(() {
              _any = false;
              _techId = tech.id;
              _slot = null;
            }),
          ),
          const SizedBox(height: Space.sm),
        ],
      ],
    );
  }

  Widget _timeStep(BuildContext context, List<Technician> eligible) {
    final t = context.t;
    final core = context.core;
    final theme = Theme.of(context);
    final now = ref.read(clockProvider)();
    final settings = ref.read(platformSettingsProvider);
    final days = upcomingDays(now);
    final day = _day ?? days.first;
    final slots = _any
        ? slotsForAny(
            technicianIds: [for (final e in eligible) e.id],
            day: day,
            durationMin: _minutes,
            now: now,
            readyBufferMin: settings.partReadyBufferMinutes,
          )
        : slotsFor(
            technicianId: _techId!,
            day: day,
            durationMin: _minutes,
            now: now,
            readyBufferMin: settings.partReadyBufferMinutes,
          );

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
                    _slot = null;
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
          InfoBanner(
            tone: Tone.neutral,
            message: day.weekday == DateTime.friday ? t.bookDayOff : t.bookNoSlots,
          )
        else if (!slots.any((s) => s.available))
          InfoBanner(tone: Tone.neutral, message: t.bookNoSlots)
        else
          Wrap(
            spacing: Space.sm,
            runSpacing: Space.sm,
            children: [
              for (final s in slots)
                ChoiceChip(
                  label: Text(
                    context.time(s.slot.start),
                    style: s.available
                        ? null
                        : const TextStyle(decoration: TextDecoration.lineThrough),
                  ),
                  selected: _slot?.start == s.slot.start,
                  onSelected: s.available ? (_) => setState(() => _slot = s.slot) : null,
                ),
            ],
          ),
      ],
    );
  }

  Widget _reviewStep(BuildContext context, List<Technician> eligible, PlatformSettings settings) {
    final t = context.t;
    final core = context.core;
    final theme = Theme.of(context);
    final catalogue = ref.read(catalogueProvider);
    final tech = _assignee(eligible);
    final labour = tech.labourSdg[_jobType]!;
    final travel = _travelFee(settings) ?? 0;
    final total = labour + travel + settings.bookingFeeSdg;
    final line = _line;
    final what =
        line?.title.tr(context) ??
        (_description.text.trim().isEmpty ? core.jobType(_job!) : _description.text.trim());

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
                    ? t.bookAtBay(catalogue.shop(tech.bayShopId!).name.tr(context))
                    : _address!.label.tr(context),
              ),
              KeyValueRow(
                label: t.bookingTech,
                value: _any ? t.cartAnyTech : tech.name.tr(context),
              ),
              KeyValueRow(label: t.bookWhen, value: context.dayTime(_slot!.start)),
              KeyValueRow(label: t.bookDuration, value: core.minutes(_minutes)),
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
              KeyValueRow(label: t.costBookingFee, value: context.sdg(settings.bookingFeeSdg)),
              const Divider(height: Space.xl),
              KeyValueRow(label: t.costTotal, value: context.sdg(total), emphasis: true),
            ],
          ),
        ),
        const SizedBox(height: Space.md),
        if (line == null) ...[
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
          if (_method == PaymentMethod.cash && _place == BookingPlace.customer) ...[
            const SizedBox(height: Space.sm),
            InfoBanner(
              tone: Tone.info,
              message: t.bookDepositNote(context.sdg(settings.mobileDepositSdg)),
            ),
          ],
          const SizedBox(height: Space.md),
        ],
        InfoBanner(
          tone: Tone.neutral,
          icon: Icons.event_available_outlined,
          message: line != null
              ? '${t.bookHoldNote(settings.slotHoldMinutes)} ${t.bookCancelNote(settings.cancelCutoffHours)}'
              : t.bookCancelNote(settings.cancelCutoffHours),
        ),
      ],
    );
  }
}

class _TechOption extends StatelessWidget {
  const _TechOption({
    required this.tech,
    required this.selected,
    required this.labour,
    required this.where,
    required this.onTap,
  });

  final Technician tech;
  final bool selected;
  final int labour;
  final String where;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
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
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(Space.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TechnicianSummary(
                  tech: tech,
                  subtitle: '$where · ${context.t.bookYears(tech.yearsExperience)}',
                  trailing: Icon(
                    selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                    color: selected ? scheme.secondary : scheme.outline,
                  ),
                ),
                const SizedBox(height: Space.sm),
                Row(
                  children: [
                    Expanded(child: Text(tech.bio.tr(context), style: theme.textTheme.bodySmall)),
                    const SizedBox(width: Space.sm),
                    Text(
                      context.sdg(labour),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontFeatures: AppTypography.tabular,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
