import 'package:alghali_core/alghali_core.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../router.dart';
import '../../state/session.dart';
import '../../state/tech_state.dart';
import '../../widgets/partner_widgets.dart';

class TechJobsScreen extends ConsumerWidget {
  const TechJobsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final catalogue = ref.watch(catalogueProvider);
    final session = ref.watch(partnerSessionProvider);
    final tech = catalogue.technician(session.technicianId);
    final jobs = ref.watch(techJobsProvider);
    final online = ref.watch(techOnlineProvider);
    final schedule = ref.watch(scheduleProvider);
    final now = ref.watch(clockProvider)();
    final today = khartoumDay(now);
    final active = jobs.jobs
        .where((b) => b.isActive || b.status == BookingStatus.completed)
        .toList();
    final todays = active.where((b) => khartoumDay(b.startAt) == today).toList();
    final upcoming = active.where((b) => khartoumDay(b.startAt).isAfter(today)).toList();
    final blocked = schedule.blockedUntil != null && schedule.blockedUntil!.isAfter(now);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(
              color: colors.brandSurface,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(Space.page, Space.lg, Space.page, Space.xl),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          InitialsAvatar(name: tech.name.tr(context), size: 48, tone: Tone.info),
                          const SizedBox(width: Space.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tech.name.tr(context),
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    color: colors.onBrandSurface,
                                  ),
                                ),
                                Row(
                                  children: [
                                    Icon(Icons.star_rounded, size: 16, color: colors.star),
                                    const SizedBox(width: Space.xxs),
                                    Text(
                                      '${tech.rating.toStringAsFixed(1)} · ${context.core.jobsDone(tech.completedJobs)}',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: colors.onBrandSurfaceMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const DemoBadge(onDark: true),
                        ],
                      ),
                      const SizedBox(height: Space.lg),
                      HeaderSwitch(
                        value: online,
                        onChanged: ref.read(techOnlineProvider.notifier).set,
                        title: online ? t.techOnline : t.techOffline,
                        icon: online ? Icons.wifi_tethering : Icons.wifi_tethering_off,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.page, 0, Space.page, Space.xxl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (blocked) ...[
                    const SizedBox(height: Space.lg),
                    InfoBanner(
                      tone: Tone.warning,
                      icon: Icons.do_not_disturb_on_outlined,
                      message: t.blockedUntil(context.time(schedule.blockedUntil!)),
                      action: OutlinedButton(
                        onPressed: ref.read(scheduleProvider.notifier).unblock,
                        child: Text(t.unblock),
                      ),
                    ),
                  ],
                  if (jobs.offers.isNotEmpty) ...[
                    SectionHeader(
                      title: t.newOffers,
                      padding: const EdgeInsets.fromLTRB(Space.xs, Space.xl, 0, Space.sm),
                    ),
                    for (final o in jobs.offers) ...[
                      OfferCard(offer: o),
                      const SizedBox(height: Space.sm),
                    ],
                  ],
                  SectionHeader(
                    title: t.todayJobs,
                    padding: const EdgeInsets.fromLTRB(Space.xs, Space.xl, 0, Space.sm),
                  ),
                  if (todays.isEmpty)
                    EmptyState(
                      icon: Icons.event_available_outlined,
                      title: t.noJobsToday,
                      message: t.noJobsTodayBody,
                      compact: true,
                    )
                  else
                    for (final b in todays) ...[JobCard(job: b), const SizedBox(height: Space.sm)],
                  if (upcoming.isNotEmpty) ...[
                    SectionHeader(
                      title: t.upcomingJobs,
                      padding: const EdgeInsets.fromLTRB(Space.xs, Space.xl, 0, Space.sm),
                    ),
                    for (final b in upcoming) ...[
                      JobCard(job: b),
                      const SizedBox(height: Space.sm),
                    ],
                  ],
                  const SizedBox(height: Space.lg),
                  DemoControls(
                    label: t.demoNewOffer,
                    onTap: () => ref.read(techJobsProvider.notifier).demoNewOffer(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A job offer with its response countdown and accept / decline.
class OfferCard extends ConsumerWidget {
  const OfferCard({super.key, required this.offer});

  final JobOffer offer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final core = context.core;
    final theme = Theme.of(context);
    final b = offer.booking;
    final catalogue = ref.watch(catalogueProvider);
    final jobs = ref.read(techJobsProvider.notifier);

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: Radii.mdAll,
        side: BorderSide(color: theme.colorScheme.secondary, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Space.md),
        child: Countdown(
          until: offer.expiresAt,
          builder: (context, left) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      b.items.first.title.tr(context),
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  StatusPill(
                    label: left == Duration.zero ? t.offerExpired : t.respondIn(clockText(left)),
                    tone: left.inMinutes < 5 ? Tone.danger : Tone.warning,
                    icon: Icons.timer_outlined,
                  ),
                ],
              ),
              const SizedBox(height: Space.xs),
              Text(
                '${context.dayTime(b.startAt)} · ${core.minutes(b.durationMin)}',
                style: theme.textTheme.bodyMedium,
              ),
              Text(
                b.place == BookingPlace.bay
                    ? t.atYourBay
                    : t.atCustomer(core.distance(b.address?.distanceKm ?? 0)),
                style: theme.textTheme.bodySmall,
              ),
              if (b.variantId != null)
                Text(carLabel(context, catalogue, b.variantId!), style: theme.textTheme.bodySmall),
              const SizedBox(height: Space.sm),
              Text(
                t.youEarn(context.sdg(b.labourSdg + b.travelFeeSdg)),
                style: theme.textTheme.titleMedium?.copyWith(color: AppColors.of(context).success),
              ),
              const SizedBox(height: Space.md),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: left == Duration.zero ? null : () => jobs.decline(offer.id),
                      child: Text(t.decline),
                    ),
                  ),
                  const SizedBox(width: Space.md),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: left == Duration.zero
                          ? null
                          : () {
                              jobs.accept(offer.id);
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(SnackBar(content: Text(t.jobAccepted)));
                            },
                      child: Text(t.accept),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class JobCard extends ConsumerWidget {
  const JobCard({super.key, required this.job});

  final Booking job;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final core = context.core;
    final theme = Theme.of(context);
    final catalogue = ref.watch(catalogueProvider);
    return TapCard(
      onTap: () => context.push(Routes.techJob(job.id)),
      child: Row(
        children: [
          Container(
            width: 64,
            padding: const EdgeInsets.symmetric(vertical: Space.sm),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainer,
              borderRadius: Radii.mdAll,
            ),
            child: Text(
              context.time(job.startAt),
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall,
            ),
          ),
          const SizedBox(width: Space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(job.items.first.title.tr(context), style: theme.textTheme.titleSmall),
                Text(
                  '${isolate(job.buyerName)} · ${job.variantId == null ? '' : catalogue.modelOfVariant(job.variantId!).name.tr(context)}',
                  style: theme.textTheme.bodySmall,
                ),
                Text(
                  job.place == BookingPlace.bay
                      ? t.atYourBay
                      : t.atCustomer(core.distance(job.address?.distanceKm ?? 0)),
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: Space.xs),
                StatusPill(label: core.bookingStatus(job.status), tone: jobTone(job.status)),
              ],
            ),
          ),
          Icon(
            Directionality.of(context) == TextDirection.rtl
                ? Icons.chevron_left
                : Icons.chevron_right,
          ),
        ],
      ),
    );
  }
}
