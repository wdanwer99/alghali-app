import 'package:alghali_core/alghali_core.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../state/tech_state.dart';
import '../../widgets/partner_widgets.dart';

/// One job from offer to done: on my way → check in → photos → buyer's code.
class JobScreen extends ConsumerStatefulWidget {
  const JobScreen({super.key, required this.jobId});

  final String jobId;

  @override
  ConsumerState<JobScreen> createState() => _JobScreenState();
}

class _JobScreenState extends ConsumerState<JobScreen> {
  final _code = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _finish() {
    final t = context.t;
    final result = ref.read(techJobsProvider.notifier).complete(widget.jobId, _code.text);
    final left = ref.read(techJobsProvider).progressOf(widget.jobId).codeAttemptsLeft;
    setState(() {
      _error = switch (result) {
        CodeResult.ok => null,
        CodeResult.needPhoto => t.needAfterPhoto,
        CodeResult.wrong => t.codeWrong(left),
        CodeResult.locked => t.codeWrong(0),
      };
    });
    if (result == CodeResult.ok) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.jobDone)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final core = context.core;
    final theme = Theme.of(context);
    final jobs = ref.watch(techJobsProvider);
    final notifier = ref.read(techJobsProvider.notifier);
    final b = notifier.job(widget.jobId);
    if (b == null) {
      return Scaffold(
        appBar: AppBar(),
        body: EmptyState(icon: Icons.handyman_outlined, title: t.noJobsToday),
      );
    }
    final catalogue = ref.watch(catalogueProvider);
    final p = jobs.progressOf(b.id);
    final partShop = b.partShopId == null ? null : catalogue.shop(b.partShopId!);
    final cash = b.method == PaymentMethod.cash;
    final collect = b.labourSdg + b.travelFeeSdg + b.bookingFeeSdg - b.depositSdg;

    final action = switch (b.status) {
      BookingStatus.accepted when b.place == BookingPlace.customer => FilledButton.icon(
        onPressed: () => notifier.onMyWay(b.id),
        icon: const Icon(Icons.near_me_outlined),
        label: Text(t.onMyWay),
      ),
      BookingStatus.accepted || BookingStatus.enRoute => FilledButton.icon(
        onPressed: () => notifier.checkIn(b.id),
        icon: const Icon(Icons.play_arrow_rounded),
        label: Text(t.checkIn),
      ),
      BookingStatus.inProgress => FilledButton.icon(
        onPressed: p.codeAttemptsLeft <= 0 ? null : _finish,
        icon: const Icon(Icons.check),
        label: Text(t.finishJob),
      ),
      _ => null,
    };

    return Scaffold(
      appBar: AppBar(title: Text(t.jobTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Space.page, Space.lg, Space.page, Space.xxl),
        children: [
          Card(
            color: AppColors.of(context).brandSurface,
            child: Padding(
              padding: const EdgeInsets.all(Space.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.day(b.startAt),
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: AppColors.of(context).onBrandSurfaceMuted,
                    ),
                  ),
                  Text(
                    context.time(b.startAt),
                    style: theme.textTheme.displaySmall?.copyWith(
                      color: AppColors.of(context).onBrandSurface,
                    ),
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
                          if (b.variantId != null)
                            Text(
                              carLabel(context, catalogue, b.variantId!),
                              style: theme.textTheme.bodySmall,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Space.md),
                const ContactActions(),
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
                const SizedBox(height: Space.sm),
                if (partShop == null)
                  InfoBanner(
                    tone: Tone.neutral,
                    icon: Icons.inventory_2_outlined,
                    message: t.partWithCustomer,
                  )
                else if (p.partReady)
                  InfoBanner(
                    tone: Tone.success,
                    icon: Icons.inventory_2_outlined,
                    message: b.bayShopId == partShop.id
                        ? t.partReadyAt(partShop.name.tr(context))
                        : t.pickUpPart(partShop.name.tr(context)),
                  )
                else
                  InfoBanner(
                    tone: Tone.warning,
                    icon: Icons.hourglass_top,
                    message: t.partPendingAt(partShop.name.tr(context)),
                  ),
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
                  Text(t.atYourBay, style: theme.textTheme.titleSmall)
                else ...[
                  Text(b.address?.label.tr(context) ?? '', style: theme.textTheme.titleSmall),
                  Text(b.address?.description.tr(context) ?? '', style: theme.textTheme.bodyMedium),
                  Text(core.distance(b.address?.distanceKm ?? 0), style: theme.textTheme.bodySmall),
                  const SizedBox(height: Space.sm),
                  OutlinedButton.icon(
                    onPressed: () => showDemoDisabled(context),
                    icon: const Icon(Icons.directions_outlined),
                    label: Text(core.actionDirections),
                  ),
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
                  label: t.jobPay,
                  value: context.sdg(b.labourSdg + b.travelFeeSdg),
                  emphasis: true,
                ),
                if (cash) ...[
                  const SizedBox(height: Space.sm),
                  InfoBanner(
                    tone: Tone.warning,
                    icon: Icons.payments_outlined,
                    message: t.collectFromCustomer(context.sdg(collect)),
                  ),
                ],
              ],
            ),
          ),
          if (b.status == BookingStatus.inProgress) ...[
            const SizedBox(height: Space.md),
            _Card(
              title: t.photosBefore,
              child: _Photos(count: p.before, onAdd: () => notifier.addPhoto(b.id, after: false)),
            ),
            const SizedBox(height: Space.md),
            _Card(
              title: t.photosAfter,
              child: _Photos(count: p.after, onAdd: () => notifier.addPhoto(b.id, after: true)),
            ),
            const SizedBox(height: Space.md),
            _Card(
              title: t.enterCode,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _code,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.ltr,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontFeatures: AppTypography.tabular,
                    ),
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: '••••',
                      helperText: t.codeHint,
                      helperMaxLines: 2,
                      errorText: _error,
                      errorMaxLines: 3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Space.md),
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(t.partNotFit),
                    content: Text(t.partNotFitBody),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text(core.actionCancel),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: Text(core.actionConfirm),
                      ),
                    ],
                  ),
                );
                if (ok ?? false) notifier.partDoesNotFit(b.id);
              },
              icon: const Icon(Icons.report_gmailerrorred_outlined),
              label: Text(t.partNotFit),
            ),
          ],
        ],
      ),
      bottomNavigationBar: action == null ? null : BottomActionBar(child: action),
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
  const _Photos({required this.count, required this.onAdd});

  final int count;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: Space.sm,
      runSpacing: Space.sm,
      children: [
        for (var i = 0; i < count; i++)
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: Radii.smAll,
            ),
            child: Icon(Icons.image_outlined, color: scheme.onSurfaceVariant),
          ),
        if (count < 4)
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
