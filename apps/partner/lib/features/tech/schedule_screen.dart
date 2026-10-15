import 'package:alghali_core/alghali_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../state/session.dart';
import '../../state/tech.dart';
import '../../widgets/partner_widgets.dart';

/// Weekly hours (Khartoum time), quick breaks and time off: what the slot engine offers
/// buyers (PLAN §5). Every change is saved at once and needs a connection.
class ScheduleScreen extends ConsumerStatefulWidget {
  const ScheduleScreen({super.key});

  @override
  ConsumerState<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends ConsumerState<ScheduleScreen> {
  var _busy = false;

  MyTechnicianController get _me => ref.read(myTechnicianProvider.notifier);

  Future<void> _run(Future<void> Function() change, {String? done}) async {
    setState(() => _busy = true);
    try {
      await change();
      if (mounted && done != null) showSnack(context, done);
    } on BackendException catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editDay(int weekday, List<(int, int)> windows) async {
    final next = await showModalBottomSheet<List<(int, int)>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _DaySheet(weekday: weekday, windows: windows),
    );
    if (next == null || !mounted) return;
    await _run(() => _me.setDay(weekday, next), done: context.t.saved);
  }

  Future<void> _addTimeOff() async {
    final t = context.t;
    final now = ref.read(clockProvider)();
    final today = khartoumDay(now);
    final range = await showDateRangePicker(
      context: context,
      firstDate: today,
      lastDate: today.add(const Duration(days: 120)),
      initialDateRange: DateTimeRange(
        start: today.add(const Duration(days: 1)),
        end: today.add(const Duration(days: 1)),
      ),
    );
    if (range == null || !mounted) return;
    // Whole Khartoum days, from the first day's midnight to the day after the last.
    DateTime midnight(DateTime d) => DateTime.utc(d.year, d.month, d.day).subtract(khartoumOffset);
    final from = midnight(range.start);
    final to = midnight(range.end).add(const Duration(days: 1));
    await _run(() => _me.addTimeOff(from.isBefore(now) ? now : from, to), done: t.timeOffAdded);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final approved = ref.watch(
      partnerSessionProvider.select((s) => s.technician?.status == PartnerStatus.approved),
    );
    return Scaffold(
      appBar: AppBar(title: Text(t.techNavSchedule)),
      body: AsyncBody(
        value: ref.watch(myTechnicianProvider),
        onRefresh: () => _me.refresh(),
        data: (me) => me == null ? const SizedBox.shrink() : _body(context, me, approved),
      ),
    );
  }

  Widget _body(BuildContext context, MyTechnician me, bool approved) {
    final t = context.t;
    final theme = Theme.of(context);
    final now = ref.watch(clockProvider)();
    final busyUntil = me.busyUntil(now);
    final hours = me.hoursByDay;
    final off = me.plannedOff(now);
    final restOfDay = endOfKhartoumDay(now).difference(now).inMinutes;

    return ListView(
      padding: const EdgeInsets.fromLTRB(Space.page, Space.lg, Space.page, Space.xxl),
      children: [
        if (_busy) ...[const LinearProgressIndicator(), const SizedBox(height: Space.sm)],
        Card(
          child: Padding(
            padding: const EdgeInsets.all(Space.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(t.quickBlock, style: theme.textTheme.titleMedium),
                Text(t.quickBlockBody, style: theme.textTheme.bodySmall),
                const SizedBox(height: Space.md),
                if (busyUntil != null)
                  InfoBanner(
                    tone: Tone.warning,
                    icon: Icons.do_not_disturb_on_outlined,
                    message: t.blockedUntil(context.time(busyUntil)),
                    action: OutlinedButton(
                      onPressed: _busy ? null : () => _run(_me.goOnline),
                      child: Text(t.unblock),
                    ),
                  )
                else
                  Row(
                    children: [
                      for (final (i, (label, minutes)) in [
                        (t.block1h, 60),
                        (t.block2h, 120),
                        (t.blockDay, restOfDay),
                      ].indexed) ...[
                        if (i > 0) const SizedBox(width: Space.sm),
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, Hit.min),
                              padding: const EdgeInsets.symmetric(horizontal: Space.sm),
                            ),
                            onPressed: _busy || !approved || minutes < 5
                                ? null
                                : () => _run(
                                    () => i == 2 ? _me.goOffline() : _me.quickBlock(minutes),
                                  ),
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
              for (final (i, day) in weekOrder.indexed) ...[
                if (i > 0) const Divider(indent: Space.lg, endIndent: Space.lg),
                Builder(
                  builder: (context) {
                    final windows = [
                      for (final r in hours[day] ?? const <AvailabilityRule>[])
                        (r.startMin, r.endMin),
                    ];
                    return SwitchListTile(
                      title: Text(dayName(context, day)),
                      // One range per line. No ltr() here: the Arabic ص/م markers already
                      // keep each range in reading order, and an LTR isolate would
                      // scramble them.
                      subtitle: Text(
                        windows.isEmpty
                            ? t.dayOff
                            : [
                                for (final (s, e) in windows)
                                  '${clockOf(context, s)} – ${clockOf(context, e)}',
                              ].join('\n'),
                      ),
                      secondary: IconButton(
                        tooltip: t.editHours,
                        onPressed: _busy ? null : () => _editDay(day, windows),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      value: windows.isNotEmpty,
                      onChanged: _busy
                          ? null
                          : (v) => _run(() => _me.setDay(day, v ? const [(540, 1080)] : const [])),
                    );
                  },
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
                if (off.isEmpty)
                  Text(
                    t.noTimeOff,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  )
                else
                  for (final o in off)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.beach_access_outlined),
                      title: Text(o.reason.ar.isEmpty ? t.timeOffDefault : o.reason.tr(context)),
                      subtitle: Text(
                        o.to.difference(o.from) <= const Duration(days: 1)
                            ? context.day(o.from)
                            : '${context.day(o.from)} – ${context.day(o.to.subtract(const Duration(minutes: 1)))}',
                      ),
                      trailing: IconButton(
                        tooltip: context.core.actionRemove,
                        onPressed: _busy ? null : () => _run(() => _me.removeTimeOff(o.id)),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ),
                const SizedBox(height: Space.sm),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _addTimeOff,
                  icon: const Icon(Icons.add),
                  label: Text(t.addTimeOff),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// One weekday's working periods (up to three, e.g. a break at midday).
class _DaySheet extends StatefulWidget {
  const _DaySheet({required this.weekday, required this.windows});

  final int weekday;
  final List<(int, int)> windows;

  @override
  State<_DaySheet> createState() => _DaySheetState();
}

class _DaySheetState extends State<_DaySheet> {
  late var _windows = widget.windows.isEmpty ? [(540, 1080)] : [...widget.windows];

  bool get _valid {
    for (var i = 0; i < _windows.length; i++) {
      if (_windows[i].$2 <= _windows[i].$1) return false;
      if (i > 0 && _windows[i].$1 < _windows[i - 1].$2) return false;
    }
    return true;
  }

  Future<void> _pick(int i, {required bool start}) async {
    final (s, e) = _windows[i];
    final v = await pickClock(context, start ? s : e);
    if (v == null) return;
    setState(() {
      _windows = [...(_windows..[i] = start ? (v, e) : (s, v == 0 ? 1440 : v))]
        ..sort((a, b) => a.$1 - b.$1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.page, 0, Space.page, Space.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(dayName(context, widget.weekday), style: theme.textTheme.titleLarge),
            const SizedBox(height: Space.md),
            for (final (i, (s, e)) in _windows.indexed)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _pick(i, start: true),
                      child: Text(clockOf(context, s)),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: Space.sm),
                    child: Text('–'),
                  ),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _pick(i, start: false),
                      child: Text(clockOf(context, e)),
                    ),
                  ),
                  IconButton(
                    tooltip: context.core.actionRemove,
                    onPressed: _windows.length == 1
                        ? null
                        : () => setState(() => _windows = [..._windows]..removeAt(i)),
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                ],
              ),
            if (_windows.length < 3)
              TextButton.icon(
                onPressed: () => setState(() {
                  final last = _windows.last.$2;
                  _windows = [..._windows, (last + 60 > 1380 ? 1380 : last + 60, 1440)];
                }),
                icon: const Icon(Icons.add),
                label: Text(t.addPeriod),
              ),
            if (!_valid) ...[
              const SizedBox(height: Space.sm),
              InfoBanner(tone: Tone.warning, message: t.periodsOverlap),
            ],
            const SizedBox(height: Space.lg),
            FilledButton(
              onPressed: _valid ? () => Navigator.pop(context, _windows) : null,
              child: Text(context.core.actionSave),
            ),
          ],
        ),
      ),
    );
  }
}
