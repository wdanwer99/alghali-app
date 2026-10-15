import 'package:alghali_core/alghali_core.dart';
import 'package:flutter/services.dart' show TextInputFormatter;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../app.dart';

/// Labelled number for dashboards: label, value, optional icon and note.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.tone = Tone.neutral,
    this.note,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData? icon;
  final Tone tone;
  final String? note;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TapCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: AppColors.of(context).strong(tone, theme.colorScheme)),
                const SizedBox(width: Space.xs),
              ],
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.xs),
          // Proportional figures for a standalone value (dataviz: tabular only in columns).
          Text(value, maxLines: 1, style: theme.textTheme.headlineSmall),
          if (note != null)
            Text(
              note!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
        ],
      ),
    );
  }
}

/// One-series column chart of the last 7 days' sales. Follows the dataviz
/// spec: a single validated hue (no legend; the title names the series),
/// ≤24 px bars with a 4 px rounded top, hairline solid grid, compact ticks,
/// tap-to-read values and a screen-reader summary. A table view sits beside it.
class SalesChart extends StatefulWidget {
  const SalesChart({super.key, required this.days});

  final List<SalesDay> days;

  @override
  State<SalesChart> createState() => _SalesChartState();
}

class _SalesChartState extends State<SalesChart> {
  int? _selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final max = widget.days.fold(0, (m, d) => d.sdg > m ? d.sdg : m);
    final step = _niceStep(max);
    final top = step * ((max / step).ceil()).clamp(1, 1000);
    final summary = [
      for (final d in widget.days)
        '${context.weekday(d.day.add(const Duration(hours: 10)))}: ${context.sdg(d.sdg)}',
    ].join('، ');

    return Semantics(
      label: summary,
      child: ExcludeSemantics(
        child: LayoutBuilder(
          builder: (context, box) {
            const plotHeight = 160.0;
            const axisWidth = 48.0;
            final plotWidth = box.maxWidth - axisWidth;
            final slot = plotWidth / widget.days.length;
            final rtl = Directionality.of(context) == TextDirection.rtl;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (e) {
                var x = e.localPosition.dx - (rtl ? 0 : axisWidth);
                if (rtl) x = plotWidth - x;
                final i = (x / slot).floor();
                setState(
                  () => _selected = i >= 0 && i < widget.days.length && i != _selected ? i : null,
                );
              },
              child: SizedBox(
                height: plotHeight + 28,
                child: CustomPaint(
                  painter: _BarsPainter(
                    values: [for (final d in widget.days) d.sdg],
                    top: top,
                    step: step,
                    selected: _selected,
                    rtl: rtl,
                    axisWidth: axisWidth,
                    plotHeight: plotHeight,
                    bar: colors.chart1,
                    grid: theme.colorScheme.outlineVariant,
                    tickStyle: theme.textTheme.labelSmall!.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontFeatures: AppTypography.tabular,
                    ),
                    tick: (v) => v == 0 ? '0' : context.core.thousands('${v ~/ 1000}'),
                    // Day-of-month numbers: short in both languages, unlike
                    // truncated Arabic weekday names.
                    labels: [
                      for (final (i, d) in widget.days.indexed)
                        i == widget.days.length - 1 ? context.core.today : '${d.day.day}',
                    ],
                    tooltip: _selected == null ? null : context.sdg(widget.days[_selected!].sdg),
                    tooltipStyle: theme.textTheme.labelMedium!.copyWith(
                      color: theme.colorScheme.onInverseSurface,
                      fontWeight: FontWeight.w700,
                    ),
                    tooltipBg: theme.colorScheme.inverseSurface,
                    textDirection: Directionality.of(context),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  static int _niceStep(int max) {
    for (final s in [5000, 10000, 20000, 25000, 50000, 100000, 200000, 250000, 500000]) {
      if (max / s <= 4) return s;
    }
    return 1000000;
  }
}

class _BarsPainter extends CustomPainter {
  _BarsPainter({
    required this.values,
    required this.top,
    required this.step,
    required this.selected,
    required this.rtl,
    required this.axisWidth,
    required this.plotHeight,
    required this.bar,
    required this.grid,
    required this.tickStyle,
    required this.tick,
    required this.labels,
    required this.tooltip,
    required this.tooltipStyle,
    required this.tooltipBg,
    required this.textDirection,
  });

  final List<int> values;
  final int top;
  final int step;
  final int? selected;
  final bool rtl;
  final double axisWidth;
  final double plotHeight;
  final Color bar;
  final Color grid;
  final TextStyle tickStyle;
  final String Function(int) tick;
  final List<String> labels;
  final String? tooltip;
  final TextStyle tooltipStyle;
  final Color tooltipBg;
  final TextDirection textDirection;

  TextPainter _text(String s, TextStyle style) => TextPainter(
    text: TextSpan(text: s, style: style),
    textDirection: textDirection,
  )..layout();

  @override
  void paint(Canvas canvas, Size size) {
    final plotLeft = rtl ? 0.0 : axisWidth;
    final plotWidth = size.width - axisWidth;
    final baseline = plotHeight;
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;

    // Hairline solid gridlines with compact ticks on the axis side.
    for (var v = 0; v <= top; v += step) {
      final y = baseline - plotHeight * 0.9 * v / top;
      canvas.drawLine(Offset(plotLeft, y), Offset(plotLeft + plotWidth, y), gridPaint);
      final tp = _text(tick(v), tickStyle);
      final x = rtl ? size.width - tp.width : axisWidth - tp.width - 6;
      tp.paint(canvas, Offset(rtl ? size.width - axisWidth + 6 : x, y - tp.height / 2));
    }

    final slot = plotWidth / values.length;
    final barWidth = (slot * 0.5).clamp(8.0, 24.0);
    for (var i = 0; i < values.length; i++) {
      final ordinal = rtl ? values.length - 1 - i : i;
      final cx = plotLeft + slot * ordinal + slot / 2;
      final h = plotHeight * 0.9 * values[i] / top;
      final paint = Paint()
        ..color = selected == null || selected == i ? bar : bar.withValues(alpha: 0.45);
      if (h > 0) {
        final r = h < 4 ? h : 4.0;
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            Rect.fromLTWH(cx - barWidth / 2, baseline - h, barWidth, h),
            topLeft: Radius.circular(r),
            topRight: Radius.circular(r),
          ),
          paint,
        );
      }
      final label = _text(
        labels[i],
        tickStyle.copyWith(fontWeight: i == values.length - 1 ? FontWeight.w700 : null),
      );
      label.paint(canvas, Offset(cx - label.width / 2, baseline + 8));

      if (selected == i && tooltip != null) {
        final tp = _text(tooltip!, tooltipStyle);
        final w = tp.width + 16;
        final left = (cx - w / 2).clamp(0.0, size.width - w);
        final y = (baseline - h - tp.height - 16).clamp(0.0, baseline);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(left, y, w, tp.height + 8),
            const Radius.circular(6),
          ),
          Paint()..color = tooltipBg,
        );
        tp.paint(canvas, Offset(left + 8, y + 4));
      }
    }
  }

  @override
  bool shouldRepaint(_BarsPainter old) =>
      old.selected != selected || old.values != values || old.bar != bar || old.rtl != rtl;
}

/// Language and appearance pickers shared by the shop and technician menus.
List<Widget> settingsRows(BuildContext context, WidgetRef ref) {
  final t = context.t;
  final core = context.core;
  final locale = ref.watch(localeControllerProvider).locale;
  final mode = ref.watch(themeModeProvider);
  final chevron = Directionality.of(context) == TextDirection.rtl
      ? Icons.chevron_left
      : Icons.chevron_right;
  return [
    ListTile(
      leading: const Icon(Icons.translate),
      title: Text(t.moreLanguage),
      subtitle: Text(locale.languageCode == 'ar' ? core.languageArabic : core.languageEnglish),
      trailing: Icon(chevron),
      onTap: () => pickOption<String>(
        context,
        title: t.moreLanguage,
        value: locale.languageCode,
        options: [('ar', core.languageArabic), ('en', core.languageEnglish)],
        onPick: (c) => ref.read(localeControllerProvider.notifier).select(Locale(c)),
      ),
    ),
    ListTile(
      leading: const Icon(Icons.dark_mode_outlined),
      title: Text(t.moreAppearance),
      subtitle: Text(switch (mode) {
        ThemeMode.light => t.appearanceLight,
        ThemeMode.dark => t.appearanceDark,
        ThemeMode.system => t.appearanceSystem,
      }),
      trailing: Icon(chevron),
      onTap: () => pickOption<ThemeMode>(
        context,
        title: t.moreAppearance,
        value: mode,
        options: [
          (ThemeMode.system, t.appearanceSystem),
          (ThemeMode.light, t.appearanceLight),
          (ThemeMode.dark, t.appearanceDark),
        ],
        onPick: (m) => ref.read(themeModeProvider.notifier).set(m),
      ),
    ),
  ];
}

Future<void> pickOption<T>(
  BuildContext context, {
  required String title,
  required T value,
  required List<(T, String)> options,
  required ValueChanged<T> onPick,
}) => showModalBottomSheet<void>(
  context: context,
  builder: (context) => SafeArea(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.page, 0, Space.page, Space.sm),
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        RadioGroup<T>(
          groupValue: value,
          onChanged: (v) {
            if (v == null) return;
            onPick(v);
            Navigator.pop(context);
          },
          child: Column(
            children: [for (final (v, l) in options) RadioListTile<T>(value: v, title: Text(l))],
          ),
        ),
        const SizedBox(height: Space.md),
      ],
    ),
  ),
);

/// Grouped card of menu rows with dividers.
class MenuCard extends StatelessWidget {
  const MenuCard({super.key, required this.children, this.title});

  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsetsDirectional.only(
              start: Space.xs,
              bottom: Space.sm,
              top: Space.lg,
            ),
            child: Text(
              title!,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        Card(
          child: Column(
            children: [
              for (final (i, c) in children.indexed) ...[if (i > 0) const Divider(indent: 56), c],
            ],
          ),
        ),
      ],
    );
  }
}

Tone shopOrderTone(SubOrderStatus s) => switch (s) {
  SubOrderStatus.pendingPayment || SubOrderStatus.paymentReview => Tone.warning,
  SubOrderStatus.confirmed ||
  SubOrderStatus.outForDelivery ||
  SubOrderStatus.handedToTechnician => Tone.info,
  SubOrderStatus.ready ||
  SubOrderStatus.pickedUp ||
  SubOrderStatus.delivered ||
  SubOrderStatus.completed => Tone.success,
  SubOrderStatus.cancelled || SubOrderStatus.rejectedByShop => Tone.danger,
  SubOrderStatus.returnRequested || SubOrderStatus.returned => Tone.neutral,
};

Tone jobTone(BookingStatus s) => switch (s) {
  BookingStatus.pendingTechAccept ||
  BookingStatus.awaitingPayment ||
  BookingStatus.held => Tone.warning,
  BookingStatus.accepted || BookingStatus.enRoute || BookingStatus.inProgress => Tone.info,
  BookingStatus.completed => Tone.success,
  _ => Tone.danger,
};

/// "Toyota Hilux 2016–2025".
String carLabel(BuildContext context, CatalogueData c, String variantId) =>
    '${c.makeOfVariant(variantId).name.tr(context)} ${c.modelOfVariant(variantId).name.tr(context)} ${c.variant(variantId).years}';

/// On/off switch for the dark brand header (shop open, accepting jobs):
/// green when on so the state reads on charcoal, where the theme's charcoal
/// track would vanish.
class HeaderSwitch extends StatelessWidget {
  const HeaderSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    required this.title,
    required this.icon,
  });

  final bool value;

  /// Null while it can't be changed (still loading).
  final ValueChanged<bool>? onChanged;
  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    bool on(Set<WidgetState> s) => s.contains(WidgetState.selected);
    return Material(
      color: colors.onBrandSurface.withValues(alpha: 0.1),
      borderRadius: Radii.mdAll,
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        shape: const RoundedRectangleBorder(borderRadius: Radii.mdAll),
        thumbColor: const WidgetStatePropertyAll(Colors.white),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => on(s) ? AppPalette.green700 : Colors.white.withValues(alpha: 0.18),
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (s) => on(s) ? AppPalette.green700 : Colors.white.withValues(alpha: 0.5),
        ),
        secondary: Icon(icon, color: value ? AppPalette.green400 : colors.onBrandSurfaceMuted),
        title: Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(color: colors.onBrandSurface),
        ),
      ),
    );
  }
}

/// A short message at the bottom of the screen.
void showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// The photo picker (camera or gallery); tests swap it for one that returns bytes.
final photoPickerProvider = Provider<Future<PickedPhoto?> Function({required bool camera})>(
  (ref) => Photos.pick,
);

/// Asks camera or gallery, then picks one photo (already shrunk for upload).
Future<PickedPhoto?> pickPhoto(BuildContext context, WidgetRef ref) async {
  final camera = await showModalBottomSheet<bool>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: Text(context.core.photoCamera),
            onTap: () => Navigator.pop(context, true),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: Text(context.core.photoGallery),
            onTap: () => Navigator.pop(context, false),
          ),
        ],
      ),
    ),
  );
  if (camera == null) return null;
  return ref.read(photoPickerProvider)(camera: camera);
}

/// Asks for a short text (a reason, an email) in a bottom sheet; null when dismissed.
Future<String?> askText(
  BuildContext context, {
  required String title,
  required String label,
  String? initial,
  String? hint,
  String? submit,
  int maxLines = 1,
  TextInputType? keyboardType,
  List<TextInputFormatter>? inputFormatters,
}) => showModalBottomSheet<String>(
  context: context,
  isScrollControlled: true,
  builder: (context) => _TextSheet(
    title: title,
    label: label,
    initial: initial,
    hint: hint,
    submit: submit,
    maxLines: maxLines,
    keyboardType: keyboardType,
    inputFormatters: inputFormatters,
  ),
);

class _TextSheet extends StatefulWidget {
  const _TextSheet({
    required this.title,
    required this.label,
    this.initial,
    this.hint,
    this.submit,
    this.maxLines = 1,
    this.keyboardType,
    this.inputFormatters,
  });

  final String title;
  final String label;
  final String? initial;
  final String? hint;
  final String? submit;
  final int maxLines;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  @override
  State<_TextSheet> createState() => _TextSheetState();
}

class _TextSheetState extends State<_TextSheet> {
  late final _text = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.page, 0, Space.page, Space.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: Space.lg),
            TextField(
              controller: _text,
              autofocus: true,
              minLines: 1,
              maxLines: widget.maxLines,
              keyboardType: widget.keyboardType,
              inputFormatters: widget.inputFormatters,
              textDirection: widget.keyboardType == TextInputType.emailAddress
                  ? TextDirection.ltr
                  : null,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(labelText: widget.label, hintText: widget.hint),
            ),
            const SizedBox(height: Space.lg),
            FilledButton(
              onPressed: _text.text.trim().isEmpty
                  ? null
                  : () => Navigator.pop(context, _text.text.trim()),
              child: Text(widget.submit ?? context.core.actionNext),
            ),
          ],
        ),
      ),
    ),
  );
}

/// A shop's or technician's review state, when it isn't simply approved.
class PartnerStatusPill extends StatelessWidget {
  const PartnerStatusPill({super.key, required this.status});

  final PartnerStatus status;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return StatusPill(
      label: switch (status) {
        PartnerStatus.pending => t.statusPending,
        PartnerStatus.approved => t.statusApproved,
        PartnerStatus.rejected => t.statusRejected,
        PartnerStatus.suspended => t.statusSuspended,
      },
      tone: switch (status) {
        PartnerStatus.pending => Tone.warning,
        PartnerStatus.approved => Tone.success,
        PartnerStatus.rejected || PartnerStatus.suspended => Tone.danger,
      },
      icon: switch (status) {
        PartnerStatus.pending => Icons.hourglass_top,
        PartnerStatus.approved => Icons.verified_outlined,
        PartnerStatus.rejected || PartnerStatus.suspended => Icons.block,
      },
    );
  }
}

/// The banner on a home screen while the shop or technician isn't approved: waiting for
/// review (with what they can already do), or rejected / suspended with the reason.
class ReviewBanner extends StatelessWidget {
  const ReviewBanner({super.key, required this.status, this.reason, required this.pendingBody});

  final PartnerStatus status;
  final String? reason;
  final String pendingBody;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    if (status == PartnerStatus.approved) return const SizedBox.shrink();
    final pending = status == PartnerStatus.pending;
    final why = reason == null || reason!.isEmpty ? '' : '\n${t.statusReason(reason!)}';
    return InfoBanner(
      tone: pending ? Tone.warning : Tone.danger,
      icon: pending ? Icons.hourglass_top : Icons.block,
      message: pending
          ? pendingBody
          : '${status == PartnerStatus.rejected ? t.statusRejectedBody : t.statusSuspendedBody}$why',
    );
  }
}

/// Khartoum wall-clock "8:00 ص" for minutes after midnight.
String clockOf(BuildContext context, int minutes) =>
    context.time(DateTime.utc(2026, 1, 1).add(Duration(minutes: minutes)).subtract(khartoumOffset));

/// A day's name for a database weekday (0 = Sunday … 6 = Saturday).
String dayName(BuildContext context, int weekday) =>
    context.weekday(DateTime.utc(2026, 10, 11 + weekday, 10));

/// Saturday first: the Sudanese working week, as database weekdays.
const weekOrder = [6, 0, 1, 2, 3, 4, 5];

/// Picks a time of day (Khartoum), as minutes after midnight; null when dismissed.
Future<int?> pickClock(BuildContext context, int minutes) async {
  final picked = await showTimePicker(
    context: context,
    initialTime: TimeOfDay(hour: minutes ~/ 60 % 24, minute: minutes % 60),
  );
  return picked == null ? null : picked.hour * 60 + picked.minute;
}

/// Weekly hours, one window per day, Saturday first: a switch per day and the times to
/// tap. Used for a shop's opening hours and a technician's working hours.
class WeeklyHoursEditor extends StatelessWidget {
  const WeeklyHoursEditor({
    super.key,
    required this.hours,
    required this.onChanged,
    this.defaultWindow = (480, 1200),
  });

  /// By database weekday; a missing or empty day is closed.
  final Map<int, List<(int, int)>> hours;
  final ValueChanged<Map<int, List<(int, int)>>> onChanged;
  final (int, int) defaultWindow;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = Theme.of(context);
    return Column(
      children: [
        for (final (i, day) in weekOrder.indexed) ...[
          if (i > 0) const Divider(height: 1),
          Builder(
            builder: (context) {
              final windows = hours[day] ?? const [];
              final open = windows.isNotEmpty;
              final (start, end) = open ? (windows.first.$1, windows.last.$2) : defaultWindow;
              void set(List<(int, int)> w) => onChanged({...hours, day: w});
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: Space.xs),
                child: Row(
                  children: [
                    Expanded(child: Text(dayName(context, day), style: theme.textTheme.titleSmall)),
                    if (open) ...[
                      TextButton(
                        onPressed: () async {
                          final v = await pickClock(context, start);
                          if (v != null && v < end) set([(v, end)]);
                        },
                        child: Text(clockOf(context, start)),
                      ),
                      const Text('–'),
                      TextButton(
                        onPressed: () async {
                          final v = await pickClock(context, end);
                          if (v != null && v > start) set([(start, v)]);
                        },
                        child: Text(clockOf(context, end)),
                      ),
                    ] else
                      Text(
                        t.dayOff,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    Switch(value: open, onChanged: (v) => set(v ? [defaultWindow] : const [])),
                  ],
                ),
              );
            },
          ),
        ],
      ],
    );
  }
}

/// A white icon button on the dark brand header, with an unread badge.
class HeaderIconButton extends StatelessWidget {
  const HeaderIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.badge = 0,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final int badge;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    onPressed: onPressed,
    color: AppColors.of(context).onBrandSurface,
    icon: Badge(isLabelVisible: badge > 0, label: Text('$badge'), child: Icon(icon)),
  );
}
