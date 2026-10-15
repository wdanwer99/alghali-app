import 'package:alghali_core/alghali_core.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../state/tech.dart';
import '../../widgets/partner_widgets.dart';
import 'tech_jobs_screen.dart';

/// One job from offer to done: on my way → check in → photos → buyer's code. Each step
/// is checked by the server at once.
class JobScreen extends ConsumerStatefulWidget {
  const JobScreen({super.key, required this.jobId});

  final String jobId;

  @override
  ConsumerState<JobScreen> createState() => _JobScreenState();
}

class _JobScreenState extends ConsumerState<JobScreen> {
  final _code = TextEditingController();
  String? _error;
  var _busy = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  TechJobsController get _jobs => ref.read(techJobsProvider.notifier);

  Future<void> _step(Future<Object?> Function() step, {String? done}) async {
    setState(() => _busy = true);
    try {
      await step();
      if (mounted && done != null) showSnack(context, done);
    } on BackendException catch (e) {
      if (!mounted) return;
      showError(context, e);
      ref.invalidate(jobDetailProvider(widget.jobId));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// On the way: the buyer sees the technician's position from now on (D-029).
  Future<void> _onMyWay(Booking b) => _step(() async {
    await _jobs.enRoute(b.id);
    try {
      await Gps.here();
    } on BackendException catch (e) {
      if (mounted) showError(context, e);
    }
    return null;
  }, done: context.t.onMyWayDone);

  Future<void> _photo(Booking b, {required bool before}) async {
    final photo = await pickPhoto(context, ref);
    if (photo == null || !mounted) return;
    await _step(() => _jobs.addPhoto(b.id, photo.bytes, before: before));
  }

  Future<void> _finish(Booking b) async {
    final t = context.t;
    if (!b.photos.any((p) => !p.before)) {
      setState(() => _error = t.needAfterPhoto);
      return;
    }
    if (_code.text.length != 4) {
      setState(() => _error = t.codeHint);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await _jobs.complete(b.id, _code.text);
      if (!mounted) return;
      if (result.ok) {
        showSnack(context, t.jobDone);
      } else {
        setState(
          () => _error = result.error == 'JOB_CODE_LOCKED'
              ? t.codeWrong(0)
              : t.codeWrong(result.attemptsLeft ?? 0),
        );
        ref.invalidate(jobDetailProvider(b.id));
      }
    } on BackendException catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _notFit(Booking b) async {
    final t = context.t;
    final reason = await askText(
      context,
      title: t.partNotFit,
      label: t.partNotFitReason,
      hint: t.partNotFitBody,
      submit: context.core.actionConfirm,
      maxLines: 3,
    );
    if (reason == null || !mounted) return;
    await _step(() => _jobs.partDoesNotFit(b.id, reason), done: t.partNotFitDone);
  }

  Future<void> _drop(Booking b) async {
    final t = context.t;
    final reason = await askText(
      context,
      title: t.dropJob,
      label: t.dropJobReason,
      hint: t.dropJobBody,
      submit: t.dropJob,
      maxLines: 3,
    );
    if (reason == null || !mounted) return;
    await _step(() => _jobs.cancel(b.id, reason), done: t.dropJobDone);
    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Scaffold(
      appBar: AppBar(title: Text(t.jobTitle)),
      body: AsyncBody(
        value: ref.watch(jobDetailProvider(widget.jobId)),
        onRefresh: () async {
          await _jobs.refresh();
          ref.invalidate(jobDetailProvider(widget.jobId));
        },
        data: (b) => _body(context, b),
      ),
      bottomNavigationBar: switch (ref.watch(jobDetailProvider(widget.jobId)).value) {
        final b? => _action(context, b),
        null => null,
      },
    );
  }

  Widget? _action(BuildContext context, Booking b) {
    final t = context.t;
    final collected = b.parts.every((p) => p.collected);
    final button = switch (b.status) {
      BookingStatus.pendingTechAccept when b.offer?.open ?? false => Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _busy ? null : () => _step(() => _jobs.respond(b, accept: false)),
              child: Text(t.decline),
            ),
          ),
          const SizedBox(width: Space.md),
          Expanded(
            flex: 2,
            child: FilledButton(
              onPressed: _busy
                  ? null
                  : () => _step(() => _jobs.respond(b, accept: true), done: t.jobAccepted),
              child: Text(t.accept),
            ),
          ),
        ],
      ),
      BookingStatus.accepted when b.place == BookingPlace.customer => FilledButton.icon(
        onPressed: _busy || !collected ? null : () => _onMyWay(b),
        icon: const Icon(Icons.near_me_outlined),
        label: Text(t.onMyWay),
      ),
      BookingStatus.accepted || BookingStatus.enRoute => FilledButton.icon(
        onPressed: _busy ? null : () => _step(() => _jobs.checkIn(b.id), done: t.checkedIn),
        icon: const Icon(Icons.play_arrow_rounded),
        label: Text(t.checkIn),
      ),
      BookingStatus.inProgress => FilledButton.icon(
        onPressed: _busy || b.jobCodeLocked ? null : () => _finish(b),
        icon: const Icon(Icons.check),
        label: Text(t.finishJob),
      ),
      _ => null,
    };
    return button == null ? null : BottomActionBar(child: button);
  }

  Widget _body(BuildContext context, Booking b) {
    final t = context.t;
    final core = context.core;
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final catalogue = ref.watch(catalogueProvider);
    final me = ref.watch(myTechnicianProvider).value;
    final cash = b.method == PaymentMethod.cash;
    // On a cash fitting the technician takes the labour, fees and parts from the buyer,
    // less any deposit paid by Bankak, and pays each shop for its parts at pickup.
    final bookingCash = cash ? b.labourSdg + b.travelFeeSdg + b.bookingFeeSdg - b.depositSdg : 0;
    final partsCash = cash ? b.parts.fold(0, (s, p) => s + p.itemsSdg) : 0;
    final photoKeys = [for (final p in b.photos) p.imageKey].join('\n');
    final urls = ref.watch(jobPhotoUrlsProvider(photoKeys)).value ?? const <String, String>{};
    final canDrop = b.status == BookingStatus.accepted && !b.parts.any((p) => p.collected);

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
                  style: theme.textTheme.titleSmall?.copyWith(color: colors.onBrandSurfaceMuted),
                ),
                Text(
                  context.time(b.startAt),
                  style: theme.textTheme.displaySmall?.copyWith(color: colors.onBrandSurface),
                ),
                Text(
                  '${core.minutes(b.durationMin)} · ${t.jobRef(formatRef(b.ref))}',
                  style: theme.textTheme.bodySmall?.copyWith(color: colors.onBrandSurfaceMuted),
                ),
                const SizedBox(height: Space.sm),
                StatusPill(label: core.bookingStatus(b.status), tone: jobTone(b.status)),
              ],
            ),
          ),
        ),
        if (b.status == BookingStatus.completed) ...[
          const SizedBox(height: Space.md),
          InfoBanner(tone: Tone.success, message: t.jobDone),
        ],
        if (b.jobCodeLocked) ...[
          const SizedBox(height: Space.md),
          InfoBanner(tone: Tone.danger, icon: Icons.lock_outline, message: t.codeWrong(0)),
        ],
        if (b.cancelReason != null && !b.isActive) ...[
          const SizedBox(height: Space.md),
          InfoBanner(tone: Tone.neutral, icon: Icons.block, message: b.cancelReason!),
        ],
        const SizedBox(height: Space.md),
        _Card(
          title: t.jobCustomer,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  InitialsAvatar(name: b.buyerName, size: 44),
                  const SizedBox(width: Space.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(b.buyerName, style: theme.textTheme.titleSmall),
                        if (b.variantId != null && catalogue.hasVariant(b.variantId!))
                          Text(
                            carLabel(context, catalogue, b.variantId!),
                            style: theme.textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              if (b.buyerPhone != null) ...[
                const SizedBox(height: Space.md),
                ContactActions(live: true, phone: b.buyerPhone),
              ],
            ],
          ),
        ),
        const SizedBox(height: Space.md),
        _Card(
          title: t.jobWork,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final i in b.items)
                KeyValueRow(label: i.title.tr(context), value: core.minutes(i.minutes)),
              if (b.externalPart != null) ...[
                const SizedBox(height: Space.sm),
                Text(b.externalPart!, style: theme.textTheme.bodyMedium),
              ],
              const SizedBox(height: Space.sm),
              if (b.parts.isEmpty)
                InfoBanner(
                  tone: Tone.neutral,
                  icon: Icons.inventory_2_outlined,
                  message: t.partWithCustomer,
                )
              else
                for (final p in b.parts) ...[
                  _PartRow(part: p, atBay: b.place == BookingPlace.bay, cash: cash),
                  const SizedBox(height: Space.sm),
                ],
            ],
          ),
        ),
        const SizedBox(height: Space.md),
        _Card(
          title: t.jobWhere,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (b.place == BookingPlace.bay)
                Text(b.bayName?.tr(context) ?? t.atYourBay, style: theme.textTheme.titleSmall)
              else ...[
                Text(b.address?.label.tr(context) ?? '', style: theme.textTheme.titleSmall),
                if ((b.address?.description.tr(context) ?? '').isNotEmpty)
                  Text(b.address!.description.tr(context), style: theme.textTheme.bodyMedium),
                if (b.locationNote != null)
                  Text(b.locationNote!, style: theme.textTheme.bodyMedium),
                Text(jobPlace(context, b, me), style: theme.textTheme.bodySmall),
                if (b.lat != null && b.lng != null) ...[
                  const SizedBox(height: Space.sm),
                  OutlinedButton.icon(
                    onPressed: () => Launch.directions(b.lat!, b.lng!),
                    icon: const Icon(Icons.directions_outlined),
                    label: Text(core.actionDirections),
                  ),
                ],
                if (b.status == BookingStatus.enRoute) ...[
                  const SizedBox(height: Space.sm),
                  InfoBanner(
                    tone: Tone.info,
                    icon: Icons.share_location_outlined,
                    message: t.sharingLocation,
                  ),
                ],
              ],
            ],
          ),
        ),
        const SizedBox(height: Space.md),
        _Card(
          title: t.jobPay,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              KeyValueRow(label: t.ledgerLabour, value: context.sdg(b.labourSdg)),
              if (b.travelFeeSdg > 0)
                KeyValueRow(label: t.ledgerTravel, value: context.sdg(b.travelFeeSdg)),
              KeyValueRow(
                label: t.youEarnLabel,
                value: context.sdg(b.labourSdg + b.travelFeeSdg),
                emphasis: true,
              ),
              if (cash) ...[
                const SizedBox(height: Space.sm),
                InfoBanner(
                  tone: Tone.warning,
                  icon: Icons.payments_outlined,
                  message: t.collectFromCustomer(context.sdg(bookingCash + partsCash)),
                ),
              ],
            ],
          ),
        ),
        if (b.status == BookingStatus.inProgress || b.photos.isNotEmpty) ...[
          const SizedBox(height: Space.md),
          _Card(
            title: t.photosBefore,
            child: _Photos(
              urls: [
                for (final p in b.photos)
                  if (p.before) urls[p.imageKey],
              ],
              onAdd: b.status == BookingStatus.inProgress && !_busy
                  ? () => _photo(b, before: true)
                  : null,
            ),
          ),
          const SizedBox(height: Space.md),
          _Card(
            title: t.photosAfter,
            child: _Photos(
              urls: [
                for (final p in b.photos)
                  if (!p.before) urls[p.imageKey],
              ],
              onAdd: b.status == BookingStatus.inProgress && !_busy
                  ? () => _photo(b, before: false)
                  : null,
            ),
          ),
        ],
        if (b.status == BookingStatus.inProgress && !b.jobCodeLocked) ...[
          const SizedBox(height: Space.md),
          _Card(
            title: t.enterCode,
            child: TextField(
              controller: _code,
              keyboardType: TextInputType.number,
              maxLength: 4,
              textAlign: TextAlign.center,
              textDirection: TextDirection.ltr,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: theme.textTheme.headlineMedium?.copyWith(fontFeatures: AppTypography.tabular),
              decoration: InputDecoration(
                counterText: '',
                hintText: '••••',
                helperText: t.codeHint,
                helperMaxLines: 2,
                errorText: _error,
                errorMaxLines: 3,
              ),
            ),
          ),
          const SizedBox(height: Space.md),
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
            onPressed: _busy ? null : () => _notFit(b),
            icon: const Icon(Icons.report_gmailerrorred_outlined),
            label: Text(t.partNotFit),
          ),
        ],
        if (canDrop) ...[
          const SizedBox(height: Space.md),
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
            onPressed: _busy ? null : () => _drop(b),
            icon: const Icon(Icons.event_busy_outlined),
            label: Text(t.dropJob),
          ),
        ],
      ],
    );
  }
}

/// Where one shop's parts are: being prepared, ready to collect, or with the technician.
class _PartRow extends StatelessWidget {
  const _PartRow({required this.part, required this.atBay, required this.cash});

  final BookingPart part;
  final bool atBay;
  final bool cash;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final shop = part.shopName.tr(context);
    final (tone, icon, message) = part.collected
        ? (Tone.success, Icons.check_circle_outline, t.partCollected(shop))
        : part.ready
        ? (
            Tone.success,
            Icons.inventory_2_outlined,
            atBay ? t.partReadyAt(shop) : t.pickUpPart(shop),
          )
        : (Tone.warning, Icons.hourglass_top, t.partPendingAt(shop));
    return InfoBanner(
      tone: tone,
      icon: icon,
      message: cash && !part.collected && part.itemsSdg > 0
          ? '$message\n${t.handCashToShop(context.sdg(part.itemsSdg))}'
          : message,
      action: part.phone == null
          ? null
          : IconButton(
              tooltip: context.core.actionCall,
              onPressed: () => Launch.call(part.phone!),
              icon: const Icon(Icons.call_outlined),
            ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(Space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: Space.md),
          child,
        ],
      ),
    ),
  );
}

class _Photos extends StatelessWidget {
  const _Photos({required this.urls, this.onAdd});

  /// Signed links; null while a link is being made.
  final List<String?> urls;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: Space.sm,
      runSpacing: Space.sm,
      children: [
        for (final u in urls)
          Container(
            width: 72,
            height: 72,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: Radii.smAll,
            ),
            child: u == null
                ? Icon(Icons.image_outlined, color: scheme.onSurfaceVariant)
                : Image.network(
                    u,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        Icon(Icons.broken_image_outlined, color: scheme.onSurfaceVariant),
                  ),
          ),
        if (onAdd != null && urls.length < 5)
          SizedBox(
            width: 72,
            height: 72,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(72, 72),
              ),
              onPressed: onAdd,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add_a_photo_outlined, size: 22),
                  Text(
                    context.t.addPhoto,
                    style: Theme.of(context).textTheme.labelSmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
