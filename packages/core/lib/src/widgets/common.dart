import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:material_ui/material_ui.dart';

import '../data/arabic.dart';
import '../l10n/generated/core_localizations.dart';
import '../models/catalogue.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import '../theme/app_typography.dart';

/// Small rounded label with a tone, e.g. "Paid", "Fits your car".
/// Always carries text (and usually an icon) so colour is never the only cue.
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label, this.tone = Tone.neutral, this.icon});

  final String label;
  final Tone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = AppColors.of(context);
    final fg = colors.onContainer(tone, scheme);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.container(tone, scheme),
        borderRadius: const BorderRadius.all(Radius.circular(Radii.xs)),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(Space.sm, Space.xxs, Space.sm, Space.xxs),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(icon, size: 15, color: fg), const SizedBox(width: Space.xs)],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: fg, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A tinted message box: payment instructions, warnings, tips.
class InfoBanner extends StatelessWidget {
  const InfoBanner({
    super.key,
    required this.message,
    this.title,
    this.tone = Tone.info,
    this.icon,
    this.action,
  });

  final String message;
  final String? title;
  final Tone tone;
  final IconData? icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final fg = colors.onContainer(tone, theme.colorScheme);
    return Container(
      padding: const EdgeInsets.all(Space.md),
      decoration: BoxDecoration(
        color: colors.container(tone, theme.colorScheme),
        borderRadius: Radii.mdAll,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon ?? _defaultIcon(tone), color: colors.strong(tone, theme.colorScheme), size: 22),
          const SizedBox(width: Space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null)
                  Text(title!, style: theme.textTheme.titleSmall?.copyWith(color: fg)),
                Text(message, style: theme.textTheme.bodyMedium?.copyWith(color: fg)),
                if (action != null) ...[const SizedBox(height: Space.sm), action!],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static IconData _defaultIcon(Tone tone) => switch (tone) {
    Tone.success => Icons.check_circle_rounded,
    Tone.warning => Icons.warning_amber_rounded,
    Tone.danger => Icons.error_outline,
    _ => Icons.info_outline,
  };
}

/// Section title with an optional trailing link ("See all").
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.action, this.onAction, this.padding});

  final String title;
  final String? action;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          padding ?? const EdgeInsetsDirectional.fromSTEB(Space.page, Space.xl, Space.xs, Space.xs),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(title, style: Theme.of(context).textTheme.titleMedium),
            ),
          ),
          if (action != null) TextButton(onPressed: onAction, child: Text(action!)),
        ],
      ),
    );
  }
}

/// Centered icon + title + message (+ action) for empty lists and errors.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: Space.xxxl,
          vertical: compact ? Space.xl : Space.huge,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: compact ? 56 : 72,
              height: compact ? 56 : 72,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHigh,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: compact ? 28 : 34, color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: Space.lg),
            Text(title, textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
            if (message != null) ...[
              const SizedBox(height: Space.xs),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (action != null) ...[const SizedBox(height: Space.xl), action!],
          ],
        ),
      ),
    );
  }
}

/// Standard error state with a retry button.
class ErrorState extends StatelessWidget {
  const ErrorState({super.key, this.onRetry});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final t = CoreLocalizations.of(context);
    return EmptyState(
      icon: Icons.cloud_off_outlined,
      title: t.errorGeneric,
      message: t.errorGenericBody,
      action: onRetry == null
          ? null
          : OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(t.actionRetry),
            ),
    );
  }
}

/// Grey placeholder blocks shown while a list loads (no shimmer: cheap to draw).
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.count = 4, this.height = 92});

  final int count;
  final double height;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHigh;
    return ListView.separated(
      padding: Space.pageInsets,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: count,
      separatorBuilder: (_, _) => const SizedBox(height: Space.md),
      itemBuilder: (_, _) => Container(
        height: height,
        decoration: BoxDecoration(color: color, borderRadius: Radii.mdAll),
      ),
    );
  }
}

/// "Label ........ value" row for summaries and receipts.
class KeyValueRow extends StatelessWidget {
  const KeyValueRow({
    super.key,
    required this.label,
    required this.value,
    this.emphasis = false,
    this.valueColor,
  });

  final String label;
  final String value;
  final bool emphasis;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelStyle = emphasis
        ? theme.textTheme.titleMedium
        : theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final valueStyle = (emphasis ? theme.textTheme.titleMedium : theme.textTheme.bodyMedium)
        ?.copyWith(
          fontWeight: emphasis ? FontWeight.w700 : FontWeight.w500,
          color: valueColor,
          fontFeatures: AppTypography.tabular,
        );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: labelStyle)),
          const SizedBox(width: Space.md),
          Text(value, style: valueStyle),
        ],
      ),
    );
  }
}

/// Stars + "4.8 (212)" in one line.
class RatingLine extends StatelessWidget {
  const RatingLine({super.key, required this.rating, this.count, this.dense = false});

  final double rating;
  final int? count;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = (dense ? theme.textTheme.labelMedium : theme.textTheme.bodyMedium)?.copyWith(
      fontWeight: FontWeight.w600,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.star_rounded, size: dense ? 16 : 18, color: AppColors.of(context).star),
        const SizedBox(width: Space.xxs),
        Text(rating.toStringAsFixed(1), style: style),
        if (count != null) ...[
          const SizedBox(width: Space.xs),
          Text(
            '($count)',
            style: style?.copyWith(
              fontWeight: FontWeight.w400,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

/// Five tappable stars for writing a review.
class StarPicker extends StatelessWidget {
  const StarPicker({super.key, required this.value, required this.onChanged, this.size = 40});

  final int value;
  final ValueChanged<int> onChanged;
  final double size;

  @override
  Widget build(BuildContext context) {
    final star = AppColors.of(context).star;
    final off = Theme.of(context).colorScheme.outline;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 1; i <= 5; i++)
          IconButton(
            tooltip: '$i/5',
            iconSize: size,
            onPressed: () => onChanged(i),
            icon: Icon(
              i <= value ? Icons.star_rounded : Icons.star_outline_rounded,
              color: i <= value ? star : off,
            ),
          ),
      ],
    );
  }
}

/// − qty + with large hit areas.
class QuantityStepper extends StatelessWidget {
  const QuantityStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 1,
    this.max = 99,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget button(IconData icon, int next, bool enabled) => SizedBox.square(
      dimension: 40,
      child: IconButton(
        padding: EdgeInsets.zero,
        style: IconButton.styleFrom(minimumSize: const Size.square(40)),
        onPressed: enabled ? () => onChanged(next) : null,
        icon: Icon(icon, size: 20),
      ),
    );
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: Radii.smAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          button(Icons.remove, value - 1, value > min),
          SizedBox(
            width: 32,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall?.copyWith(fontFeatures: AppTypography.tabular),
            ),
          ),
          button(Icons.add, value + 1, value < max),
        ],
      ),
    );
  }
}

/// Sticky bottom bar with the screen's main action; respects the gesture bar.
class BottomActionBar extends StatelessWidget {
  const BottomActionBar({super.key, required this.child, this.top});

  final Widget child;

  /// Optional summary row above the button (e.g. total).
  final Widget? top;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Space.page, Space.md, Space.page, Space.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (top != null) ...[top!, const SizedBox(height: Space.md)],
              child,
            ],
          ),
        ),
      ),
    );
  }
}

/// Rounded square with a soft background and an icon (categories, menu rows).
class IconTile extends StatelessWidget {
  const IconTile({
    super.key,
    required this.icon,
    this.size = 44,
    this.tone = Tone.neutral,
    this.iconColor,
    this.background,
  });

  final IconData icon;
  final double size;
  final Tone tone;
  final Color? iconColor;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = AppColors.of(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background ?? colors.container(tone, scheme),
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Icon(
        icon,
        size: size * 0.52,
        color: iconColor ?? (tone == Tone.neutral ? scheme.onSurface : colors.strong(tone, scheme)),
      ),
    );
  }
}

/// Circle with initials, for shops, technicians and buyers without photos.
class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar({super.key, required this.name, this.size = 44, this.tone = Tone.neutral});

  final String name;
  final double size;
  final Tone tone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = AppColors.of(context);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: colors.container(tone, scheme), shape: BoxShape.circle),
      child: Text(
        initialsOf(name),
        style: Theme.of(context).textTheme.titleSmall
            ?.copyWith(fontSize: size * 0.38, height: 1, color: colors.onContainer(tone, scheme)),
      ),
    );
  }

  /// Arabic names get one letter, skipping the article "ال" ("النيل" → "ن");
  /// initials of joined Arabic letters would read as a word. Latin names get
  /// up to two capitals ("Al-Nour Auto" → "AA").
  static String initialsOf(String name) {
    final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return '?';
    if (arabicLetter.hasMatch(name)) {
      final w = words.first;
      final core = w.length > 3 && w.startsWith('ال') ? w.substring(2) : w;
      return core.characters.first;
    }
    return words.take(2).map((w) => w.characters.first.toUpperCase()).join();
  }
}

/// A tappable card with the standard border, radius and ripple.
class TapCard extends StatelessWidget {
  const TapCard({super.key, required this.child, this.onTap, this.padding, this.color});

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding ?? const EdgeInsets.all(Space.md), child: child),
      ),
    );
  }
}

/// A large, selectable option card (radio-like), e.g. "At a workshop" / "At my place".
class ChoiceCard extends StatelessWidget {
  const ChoiceCard({
    super.key,
    required this.selected,
    required this.onTap,
    required this.title,
    this.subtitle,
    this.icon,
    this.trailing,
  });

  final bool selected;
  final VoidCallback onTap;
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? trailing;

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
            padding: const EdgeInsets.all(Space.lg),
            child: Row(
              children: [
                if (icon != null) ...[
                  IconTile(icon: icon!, size: 44, tone: selected ? Tone.brand : Tone.neutral),
                  const SizedBox(width: Space.md),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.titleSmall),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                if (trailing != null) ...[const SizedBox(width: Space.sm), trailing!],
                const SizedBox(width: Space.sm),
                Icon(
                  selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  color: selected ? scheme.secondary : scheme.outline,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A value the user needs to copy (account number, order reference).
class CopyValue extends StatelessWidget {
  const CopyValue({
    super.key,
    required this.label,
    required this.value,
    this.display,
    this.large = false,
  });

  final String label;
  final String value;

  /// How to show [value] (e.g. grouped digits); [value] is what gets copied.
  final String? display;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final t = CoreLocalizations.of(context);
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.bodySmall),
              Text(
                display ?? value,
                textDirection: TextDirection.ltr,
                style: (large ? theme.textTheme.headlineSmall : theme.textTheme.titleMedium)
                    ?.copyWith(fontFeatures: AppTypography.tabular),
              ),
            ],
          ),
        ),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: value));
            if (!context.mounted) return;
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(content: Text(t.copied), duration: const Duration(seconds: 2)),
              );
          },
          icon: const Icon(Icons.content_copy, size: 18),
          label: Text(t.actionCopy),
        ),
      ],
    );
  }
}

/// Shows "this action is switched off in the demo" for calls and WhatsApp.
void showDemoDisabled(BuildContext context) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(CoreLocalizations.of(context).demoActionDisabled)));
}

/// Call / WhatsApp / Chat buttons for a shop, technician or buyer.
class ContactActions extends StatelessWidget {
  const ContactActions({super.key, this.onChat, this.showWhatsApp = true});

  final VoidCallback? onChat;
  final bool showWhatsApp;

  @override
  Widget build(BuildContext context) {
    final t = CoreLocalizations.of(context);
    // Icon over label keeps three actions readable on a 360 dp phone.
    Widget action(IconData icon, String label, VoidCallback onTap) => Expanded(
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 60),
          padding: const EdgeInsets.symmetric(horizontal: Space.xs, vertical: Space.sm),
        ),
        onPressed: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22),
            const SizedBox(height: Space.xxs),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
    return Row(
      children: [
        action(Icons.call_outlined, t.actionCall, () => showDemoDisabled(context)),
        if (showWhatsApp) ...[
          const SizedBox(width: Space.sm),
          action(Icons.chat_outlined, t.actionWhatsApp, () => showDemoDisabled(context)),
        ],
        if (onChat != null) ...[
          const SizedBox(width: Space.sm),
          action(Icons.chat_bubble_outline, t.actionChat, onChat!),
        ],
      ],
    );
  }
}

/// Icon for a catalogue category.
IconData categoryIcon(CategoryIcon icon) => switch (icon) {
  CategoryIcon.lighting => Icons.lightbulb_outline,
  CategoryIcon.brakes => Icons.album_outlined,
  CategoryIcon.oil => Icons.oil_barrel_outlined,
  CategoryIcon.battery => Icons.battery_charging_full,
  CategoryIcon.electrical => Icons.electrical_services,
  CategoryIcon.ac => Icons.ac_unit,
  CategoryIcon.suspension => Icons.compress,
  CategoryIcon.tyres => Icons.tire_repair,
  CategoryIcon.engine => Icons.build_outlined,
  CategoryIcon.transmission => Icons.settings_outlined,
  CategoryIcon.body => Icons.directions_car_outlined,
  CategoryIcon.accessories => Icons.event_seat_outlined,
};

/// Placeholder "photo" for a part: a tinted square with its category icon.
/// Real listings show the shop's thumbnail here (D-008).
class PartThumb extends StatelessWidget {
  const PartThumb({super.key, required this.icon, this.size = 72, this.badge});

  final CategoryIcon icon;
  final double size;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox.square(
      dimension: size,
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.surfaceContainer,
                borderRadius: BorderRadius.circular(size * 0.16),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: Icon(categoryIcon(icon), size: size * 0.42, color: scheme.onSurfaceVariant),
            ),
          ),
          if (badge != null)
            PositionedDirectional(
              top: Space.xs,
              start: Space.xs,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.primary,
                  borderRadius: const BorderRadius.all(Radius.circular(Radii.xs)),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  child: Text(
                    badge!,
                    textDirection: TextDirection.ltr,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: scheme.onPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Price in SDG with optional struck-through previous price.
class PriceText extends StatelessWidget {
  const PriceText({super.key, required this.text, this.was, this.large = false});

  final String text;
  final String? was;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: Space.sm,
      children: [
        Text(
          text,
          style: (large ? theme.textTheme.titleLarge : theme.textTheme.titleMedium)?.copyWith(
            fontWeight: FontWeight.w700,
            fontFeatures: AppTypography.tabular,
          ),
        ),
        if (was != null)
          Text(
            was!,
            style: theme.textTheme.bodySmall?.copyWith(
              decoration: TextDecoration.lineThrough,
              fontFeatures: AppTypography.tabular,
            ),
          ),
      ],
    );
  }
}

/// Numbered progress for multi-step flows ("1 Place · 2 Technician · 3 Time").
class StepProgress extends StatelessWidget {
  const StepProgress({super.key, required this.steps, required this.current});

  final List<String> steps;
  final int current;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    Widget line(bool on, bool visible) => Expanded(
      child: Container(
        height: 2,
        color: !visible ? Colors.transparent : (on ? scheme.secondary : scheme.outlineVariant),
      ),
    );
    // Equal columns (circle over label) always fit, whatever the language.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < steps.length; i++)
          Expanded(
            child: Semantics(
              selected: i == current,
              child: Column(
                children: [
                  Row(
                    children: [
                      line(i <= current, i > 0),
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: i <= current
                            ? scheme.secondary
                            : scheme.surfaceContainerHigh,
                        child: i < current
                            ? Icon(Icons.check, size: 15, color: scheme.onSecondary)
                            : Text(
                                '${i + 1}',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: i <= current
                                      ? scheme.onSecondary
                                      : scheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                      line(i < current, i < steps.length - 1),
                    ],
                  ),
                  const SizedBox(height: Space.xs),
                  Text(
                    steps[i],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: i <= current ? scheme.onSurface : scheme.onSurfaceVariant,
                      fontWeight: i == current ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// A vertical status timeline (order and booking tracking).
class StatusTimeline extends StatelessWidget {
  const StatusTimeline({super.key, required this.steps});

  final List<TimelineStep> steps;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = AppColors.of(context);
    return Column(
      children: [
        for (var i = 0; i < steps.length; i++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 28,
                  child: Column(
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: switch (steps[i].state) {
                            TimelineState.done => colors.success,
                            TimelineState.current => scheme.secondary,
                            TimelineState.upcoming => scheme.surface,
                          },
                          border: Border.all(
                            color: steps[i].state == TimelineState.upcoming
                                ? scheme.outline
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: switch (steps[i].state) {
                          TimelineState.done => Icon(Icons.check, size: 14, color: scheme.surface),
                          TimelineState.current => Center(
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: scheme.onSecondary,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                          TimelineState.upcoming => null,
                        },
                      ),
                      if (i < steps.length - 1)
                        Expanded(
                          child: Container(
                            width: 2,
                            margin: const EdgeInsets.symmetric(vertical: 2),
                            color: steps[i].state == TimelineState.done
                                ? colors.success
                                : scheme.outlineVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: Space.md),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: i < steps.length - 1 ? Space.lg : 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          steps[i].title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: steps[i].state == TimelineState.upcoming
                                ? scheme.onSurfaceVariant
                                : scheme.onSurface,
                          ),
                        ),
                        if (steps[i].subtitle != null)
                          Text(steps[i].subtitle!, style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

enum TimelineState { done, current, upcoming }

@immutable
class TimelineStep {
  const TimelineStep(this.title, this.state, {this.subtitle});

  final String title;
  final TimelineState state;
  final String? subtitle;
}

/// "Demo" chip for headers, so nobody mistakes sample data for real data.
class DemoBadge extends StatelessWidget {
  const DemoBadge({super.key, this.onDark = false});

  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final t = CoreLocalizations.of(context);
    final theme = Theme.of(context);
    final fg = onDark ? Colors.white : theme.colorScheme.onSurfaceVariant;
    return Tooltip(
      message: t.demoNote,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: Space.sm, vertical: Space.xxs),
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.all(Radius.circular(Radii.xs)),
          border: Border.all(color: fg.withValues(alpha: 0.5)),
        ),
        child: Text(t.demoBadge, style: theme.textTheme.labelSmall?.copyWith(color: fg)),
      ),
    );
  }
}
