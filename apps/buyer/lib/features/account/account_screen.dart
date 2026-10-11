import 'package:alghali_core/alghali_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../router.dart';
import '../../state/garage.dart';
import '../../state/orders.dart';
import '../../state/session.dart';

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final core = context.core;
    final theme = Theme.of(context);
    final session = ref.watch(sessionProvider);
    final cars = ref.watch(garageProvider).vehicles.length;
    final unread = ref.watch(unreadCountProvider);
    final locale = ref.watch(localeControllerProvider).locale;
    final mode = ref.watch(themeModeProvider);
    final dataSaver = ref.watch(dataSaverProvider);
    final chevron = Directionality.of(context) == TextDirection.rtl
        ? Icons.chevron_left
        : Icons.chevron_right;

    Widget section(String title, List<Widget> rows) => Padding(
      padding: const EdgeInsets.fromLTRB(Space.page, Space.lg, Space.page, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(start: Space.xs, bottom: Space.sm),
            child: Text(
              title,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Card(
            child: Column(
              children: [
                for (final (i, row) in rows.indexed) ...[if (i > 0) const Divider(indent: 56), row],
              ],
            ),
          ),
        ],
      ),
    );

    ListTile row(
      IconData icon,
      String title, {
      String? value,
      VoidCallback? onTap,
      Widget? trailing,
    }) => ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: value == null ? null : Text(value),
      trailing: trailing ?? Icon(chevron),
      onTap: onTap,
    );

    return Scaffold(
      appBar: AppBar(title: Text(t.navAccount)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: Space.xxl),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.page, Space.lg, Space.page, 0),
            child: session.signedIn
                ? Card(
                    child: Padding(
                      padding: const EdgeInsets.all(Space.lg),
                      child: Row(
                        children: [
                          InitialsAvatar(name: session.name ?? '', size: 56, tone: Tone.brand),
                          const SizedBox(width: Space.lg),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(session.name ?? '', style: theme.textTheme.titleLarge),
                                Text(
                                  session.email ?? '',
                                  textDirection: TextDirection.ltr,
                                  style: theme.textTheme.bodyMedium,
                                ),
                                if (session.phone != null)
                                  Text(
                                    session.phone!,
                                    textDirection: TextDirection.ltr,
                                    style: theme.textTheme.bodySmall,
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : Card(
                    child: Padding(
                      padding: const EdgeInsets.all(Space.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(t.accountGuestTitle, style: theme.textTheme.titleMedium),
                          Text(t.accountGuestBody, style: theme.textTheme.bodyMedium),
                          const SizedBox(height: Space.lg),
                          FilledButton(
                            onPressed: () => context.push(Routes.signIn),
                            child: Text(t.accountSignIn),
                          ),
                          const SizedBox(height: Space.sm),
                          OutlinedButton(
                            onPressed: () => context.push(Routes.signUp),
                            child: Text(t.accountSignUp),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
          section(t.accountShopping, [
            row(
              Icons.garage_outlined,
              t.accountGarage,
              value: t.accountCars(cars),
              onTap: () => context.push(Routes.garage),
            ),
            row(
              Icons.notifications_none_outlined,
              t.accountNotifications,
              onTap: () => context.push(Routes.notifications),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (unread > 0) ...[
                    Badge(label: Text('$unread')),
                    const SizedBox(width: Space.sm),
                  ],
                  Icon(chevron),
                ],
              ),
            ),
            row(Icons.receipt_long_outlined, t.navOrders, onTap: () => context.go(Routes.orders)),
          ]),
          section(t.accountSettings, [
            row(
              Icons.translate,
              t.accountLanguage,
              value: locale.languageCode == 'ar' ? core.languageArabic : core.languageEnglish,
              onTap: () => _pick<String>(
                context,
                title: t.accountLanguage,
                value: locale.languageCode,
                options: [('ar', core.languageArabic), ('en', core.languageEnglish)],
                onPick: (code) => ref.read(localeControllerProvider.notifier).select(Locale(code)),
              ),
            ),
            row(
              Icons.dark_mode_outlined,
              t.accountAppearance,
              value: switch (mode) {
                ThemeMode.light => t.appearanceLight,
                ThemeMode.dark => t.appearanceDark,
                ThemeMode.system => t.appearanceSystem,
              },
              onTap: () => _pick<ThemeMode>(
                context,
                title: t.accountAppearance,
                value: mode,
                options: [
                  (ThemeMode.system, t.appearanceSystem),
                  (ThemeMode.light, t.appearanceLight),
                  (ThemeMode.dark, t.appearanceDark),
                ],
                onPick: (m) => ref.read(themeModeProvider.notifier).set(m),
              ),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.data_saver_on_outlined),
              title: Text(t.accountDataSaver),
              subtitle: Text(t.accountDataSaverBody),
              value: dataSaver,
              onChanged: (v) => ref.read(dataSaverProvider.notifier).set(v),
            ),
          ]),
          section(t.accountSupport, [
            row(Icons.help_outline, t.accountHelp, onTap: () => showDemoDisabled(context)),
            row(
              Icons.description_outlined,
              t.accountTerms,
              onTap: () => showDialog<void>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(t.accountTerms),
                  content: Text(t.accountTermsBody),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(core.actionClose),
                    ),
                  ],
                ),
              ),
            ),
            row(Icons.info_outline, t.accountAbout, onTap: () => _about(context)),
          ]),
          if (session.signedIn)
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.page, Space.xl, Space.page, 0),
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: theme.colorScheme.error),
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text(t.accountSignOutConfirm),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: Text(core.actionCancel),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: Text(t.accountSignOut),
                        ),
                      ],
                    ),
                  );
                  if (ok ?? false) await ref.read(sessionProvider.notifier).signOut();
                },
                icon: const Icon(Icons.logout),
                label: Text(t.accountSignOut),
              ),
            ),
        ],
      ),
    );
  }

  static Future<void> _pick<T>(
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
              children: [
                for (final (v, label) in options) RadioListTile<T>(value: v, title: Text(label)),
              ],
            ),
          ),
          const SizedBox(height: Space.md),
        ],
      ),
    ),
  );

  static void _about(BuildContext context) {
    final t = context.t;
    final core = context.core;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const AlghaliMark(size: 48),
        title: Text(core.brandName),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(t.accountVersion('0.2.0'), style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: Space.md),
            Text(core.demoNote, textAlign: TextAlign.center),
            const SizedBox(height: Space.md),
            const BackendStatusChip(),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => showLicensePage(context: context, applicationName: core.brandName),
            child: Text(t.accountLicenses),
          ),
          TextButton(onPressed: () => Navigator.pop(context), child: Text(core.actionClose)),
        ],
      ),
    );
  }
}
