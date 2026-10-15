import 'package:alghali_core/alghali_core.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../router.dart';
import '../../state/inbox.dart';
import '../../state/push.dart';
import '../../state/session.dart';
import '../../state/tech.dart';
import '../../widgets/partner_widgets.dart';

class TechJobsScreen extends ConsumerWidget {
  const TechJobsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final session = ref.watch(partnerSessionProvider);
    final release = ref.watch(platformSettingsProvider).partnerRelease;
    final status = session.technician?.status ?? PartnerStatus.pending;
    final me = ref.watch(myTechnicianProvider).value;
    final jobsValue = ref.watch(techJobsProvider);
    final jobs = jobsValue.value ?? const TechJobs();
    final now = ref.watch(clockProvider)();
    final today = khartoumDay(now);
    final busyUntil = me?.busyUntil(now);
    final approved = status == PartnerStatus.approved;
    final todays = [
      ...jobs.upcoming.where((b) => khartoumDay(b.startAt) == today),
      ...jobs.past.where(
        (b) => b.status == BookingStatus.completed && khartoumDay(b.startAt) == today,
      ),
    ];
    final upcoming = jobs.upcoming.where((b) => khartoumDay(b.startAt).isAfter(today)).toList();

    Future<void> toggle(bool online) async {
      final c = ref.read(myTechnicianProvider.notifier);
      try {
        online ? await c.goOnline() : await c.goOffline();
      } on BackendException catch (e) {
        if (context.mounted) showError(context, e);
      }
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: RefreshIndicator(
          onRefresh: () => Future.wait([
            ref.read(techJobsProvider.notifier).refresh(),
            ref.read(myTechnicianProvider.notifier).refresh(),
            ref.read(inboxProvider.notifier).refresh(),
            ref.read(partnerSessionProvider.notifier).refreshAccount(),
          ]),
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              Container(
                color: colors.brandSurface,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(Space.page, Space.lg, Space.sm, Space.xl),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            InitialsAvatar(name: session.name ?? '', size: 48, tone: Tone.info),
                            const SizedBox(width: Space.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    session.name ?? '',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      color: colors.onBrandSurface,
                                    ),
                                  ),
                                  if (me != null)
                                    Row(
                                      children: [
                                        Icon(Icons.star_rounded, size: 16, color: colors.star),
                                        const SizedBox(width: Space.xxs),
                                        Text(
                                          '${me.ratingCount == 0 ? '—' : me.rating.toStringAsFixed(1)} · ${context.core.jobsDone(me.completedJobs)}',
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            color: colors.onBrandSurfaceMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                            HeaderIconButton(
                              icon: Icons.notifications_outlined,
                              tooltip: t.notificationsTitle,
                              badge: ref.watch(unreadCountProvider),
                              onPressed: () => context.push(Routes.notifications),
                            ),
                          ],
                        ),
                        const SizedBox(height: Space.lg),
                        Padding(
                          padding: const EdgeInsetsDirectional.only(end: Space.sm),
                          child: HeaderSwitch(
                            value: approved && busyUntil == null,
                            onChanged: approved && me != null ? toggle : null,
                            title: approved && busyUntil == null ? t.techOnline : t.techOffline,
                            icon: busyUntil == null
                                ? Icons.wifi_tethering
                                : Icons.wifi_tethering_off,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const OfflineBanner(),
              Padding(
                padding: const EdgeInsets.fromLTRB(Space.page, 0, Space.page, Space.xxl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (release.updateAvailable(partnerBuild)) ...[
                      const SizedBox(height: Space.lg),
                      UpdateBanner(release: release, appBuild: partnerBuild),
                    ],
                    if (!approved) ...[
                      const SizedBox(height: Space.lg),
                      ReviewBanner(
                        status: status,
                        reason: session.technician?.statusReason,
                        pendingBody: t.techPendingBody,
                      ),
                    ],
                    if (busyUntil != null) ...[
                      const SizedBox(height: Space.lg),
                      InfoBanner(
                        tone: Tone.warning,
                        icon: Icons.do_not_disturb_on_outlined,
                        message: t.blockedUntil(context.time(busyUntil)),
                        action: OutlinedButton(
                          onPressed: () => toggle(true),
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
                        OfferCard(key: ValueKey(o.id), job: o),
                        const SizedBox(height: Space.sm),
                      ],
                    ],
                    SectionHeader(
                      title: t.todayJobs,
                      padding: const EdgeInsets.fromLTRB(Space.xs, Space.xl, 0, Space.sm),
                    ),
                    if (jobsValue.isLoading && !jobsValue.hasValue)
                      const SizedBox(height: 240, child: SkeletonList(count: 2))
                    else if (todays.isEmpty)
                      EmptyState(
                        icon: Icons.event_available_outlined,
                        title: t.noJobsToday,
                        message: t.noJobsTodayBody,
                        compact: true,
                      )
                    else
                      for (final b in todays) ...[
                        JobCard(job: b),
                        const SizedBox(height: Space.sm),
                      ],
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
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Where the job is, in words: the bay, or the customer's place and how far from home.
String jobPlace(BuildContext context, Booking b, MyTechnician? me) {
  final t = context.t;
  if (b.place == BookingPlace.bay) return t.atYourBay;
  final lat = b.lat;
  final lng = b.lng;
  final homeLat = me?.homeLat;
  final homeLng = me?.homeLng;
  if (lat == null || lng == null || homeLat == null || homeLng == null) {
    return t.atCustomerPlace;
  }
  return t.atCustomer(context.core.distance(distanceKm(homeLat, homeLng, lat, lng)));
}

/// A job offer with its response countdown and accept / decline.
class OfferCard extends ConsumerStatefulWidget {
  const OfferCard({super.key, required this.job});

  final Booking job;

  @override
  ConsumerState<OfferCard> createState() => _OfferCardState();
}

class _OfferCardState extends ConsumerState<OfferCard> {
  var _busy = false;

  Future<void> _respond({required bool accept}) async {
    final t = context.t;
    if (!accept) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(t.decline),
          content: Text(t.declineBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.core.actionCancel),
            ),
            TextButton(onPressed: () => Navigator.pop(context, true), child: Text(t.decline)),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(techJobsProvider.notifier).respond(widget.job, accept: accept);
      if (mounted && accept) showSnack(context, t.jobAccepted);
    } on BackendException catch (e) {
      if (!mounted) return;
      showError(context, e);
      await ref.read(techJobsProvider.notifier).refresh();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final core = context.core;
    final theme = Theme.of(context);
    final b = widget.job;
    final catalogue = ref.watch(catalogueProvider);
    final me = ref.watch(myTechnicianProvider).value;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: Radii.mdAll,
        side: BorderSide(color: theme.colorScheme.secondary, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Space.md),
        child: Countdown(
          until: b.offer?.expiresAt ?? DateTime.fromMillisecondsSinceEpoch(0),
          builder: (context, left) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: Text(jobTitle(context, b), style: theme.textTheme.titleMedium)),
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
              Text(jobPlace(context, b, me), style: theme.textTheme.bodySmall),
              if (b.variantId != null && catalogue.hasVariant(b.variantId!))
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
                      onPressed: left == Duration.zero || _busy
                          ? null
                          : () => _respond(accept: false),
                      child: Text(t.decline),
                    ),
                  ),
                  const SizedBox(width: Space.md),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: left == Duration.zero || _busy
                          ? null
                          : () => _respond(accept: true),
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

/// What the job is: the first part (and how many more).
String jobTitle(BuildContext context, Booking b) {
  final first = b.items.firstOrNull?.title.tr(context) ?? '';
  return b.items.length > 1 ? context.t.jobAndMore(first, b.items.length - 1) : first;
}

class JobCard extends ConsumerWidget {
  const JobCard({super.key, required this.job});

  final Booking job;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final core = context.core;
    final theme = Theme.of(context);
    final catalogue = ref.watch(catalogueProvider);
    final me = ref.watch(myTechnicianProvider).value;
    final car = job.variantId != null && catalogue.hasVariant(job.variantId!)
        ? catalogue.modelOfVariant(job.variantId!).name.tr(context)
        : '';
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
                Text(jobTitle(context, job), style: theme.textTheme.titleSmall),
                Text(
                  [isolate(job.buyerName), car].where((s) => s.isNotEmpty).join(' · '),
                  style: theme.textTheme.bodySmall,
                ),
                Text(jobPlace(context, job, me), style: theme.textTheme.bodySmall),
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
