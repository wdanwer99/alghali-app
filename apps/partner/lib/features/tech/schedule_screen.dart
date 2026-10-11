import 'package:alghali_core/alghali_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../state/tech_state.dart';

/// Weekly hours (Khartoum time), quick block and time off — the inputs of
/// the slot engine (PLAN §5).
class ScheduleScreen extends ConsumerWidget {
  const ScheduleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final theme = Theme.of(context);
    final schedule = ref.watch(scheduleProvider);
    final controller = ref.read(scheduleProvider.notifier);
    final now = ref.watch(clockProvider)();
    final blocked = schedule.blockedUntil != null && schedule.blockedUntil!.isAfter(now);
    // Saturday first: the Sudanese working week.
    const week = [
      DateTime.saturday,
      DateTime.sunday,
      DateTime.monday,
      DateTime.tuesday,
      DateTime.wednesday,
      DateTime.thursday,
      DateTime.friday,
    ];
    // Any date with the right weekday, at Khartoum midday, for the day name.
    DateTime sample(int weekday) =>
        DateTime.utc(2026, 10, 10 + (weekday - DateTime.saturday) % 7, 10);
    String hhmm(int min) =>
        context.time(DateTime.utc(2026, 1, 1).add(Duration(minutes: min)).subtract(khartoumOffset));

    return Scaffold(
      appBar: AppBar(title: Text(t.techNavSchedule)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Space.page, Space.lg, Space.page, Space.xxl),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(Space.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(t.quickBlock, style: theme.textTheme.titleMedium),
                  Text(t.quickBlockBody, style: theme.textTheme.bodySmall),
                  const SizedBox(height: Space.md),
                  if (blocked)
                    InfoBanner(
                      tone: Tone.warning,
                      icon: Icons.do_not_disturb_on_outlined,
                      message: t.blockedUntil(context.time(schedule.blockedUntil!)),
                      action: OutlinedButton(onPressed: controller.unblock, child: Text(t.unblock)),
                    )
                  else
                    Row(
                      children: [
                        for (final (i, (label, d)) in [
                          (t.block1h, const Duration(hours: 1)),
                          (t.block2h, const Duration(hours: 2)),
                          (t.blockDay, null),
                        ].indexed) ...[
                          if (i > 0) const SizedBox(width: Space.sm),
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(0, Hit.min),
                                padding: const EdgeInsets.symmetric(horizontal: Space.sm),
                              ),
                              onPressed: () => controller.block(d),
                              child: Text(label, maxLines: 1),
                            ),
                          ),
                        ],
                      ],
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Space.md),
          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(Space.lg, Space.lg, Space.lg, Space.xs),
                  child: Text(t.weeklyHours, style: theme.textTheme.titleMedium),
                ),
                for (final (i, day) in week.indexed) ...[
                  if (i > 0) const Divider(indent: Space.lg, endIndent: Space.lg),
                  SwitchListTile(
                    title: Text(context.weekday(sample(day))),
                    subtitle: Text(
                      (schedule.hours[day] ?? const []).isEmpty
                          ? t.dayOff
                          // One range per line. No ltr() here: the Arabic ص/م markers
                          // already keep each range in reading order, and an LTR
                          // isolate would scramble them.
                          : [
                              for (final w in schedule.hours[day]!)
                                '${hhmm(w.startMin)} – ${hhmm(w.endMin)}',
                            ].join('\n'),
                    ),
                    value: (schedule.hours[day] ?? const []).isNotEmpty,
                    onChanged: (v) => controller.toggleDay(day, v),
                  ),
                ],
                const SizedBox(height: Space.sm),
              ],
            ),
          ),
          const SizedBox(height: Space.md),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(Space.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(t.timeOff, style: theme.textTheme.titleMedium),
                  const SizedBox(height: Space.sm),
                  if (schedule.timeOff.isEmpty)
                    Text(
                      t.noTimeOff,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    )
                  else
                    for (final off in schedule.timeOff)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.beach_access_outlined),
                        title: Text(off.reason.tr(context)),
                        subtitle: Text(context.day(off.from)),
                        trailing: IconButton(
                          tooltip: context.core.actionRemove,
                          onPressed: () => controller.removeTimeOff(off.id),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ),
                  const SizedBox(height: Space.sm),
                  OutlinedButton.icon(
                    onPressed: () {
                      controller.addDayOffTomorrow();
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text(t.timeOffAdded)));
                    },
                    icon: const Icon(Icons.add),
                    label: Text(t.addTimeOff),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
