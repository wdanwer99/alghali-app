import 'package:alghali_core/alghali_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'features/home/home_screen.dart';
import 'l10n/generated/app_localizations.dart';

abstract final class Routes {
  static const home = '/';
  static const language = '/language';
}

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: Routes.home,
    redirect: (context, state) {
      final chosen = ref.read(localeControllerProvider).chosen;
      if (!chosen && state.matchedLocation != Routes.language) return Routes.language;
      return null;
    },
    routes: [
      GoRoute(path: Routes.home, builder: (context, state) => const HomeScreen()),
      GoRoute(
        path: Routes.language,
        builder: (context, state) => LanguagePickerScreen(
          header: const _WelcomeHeader(),
          onContinue: () => context.go(Routes.home),
        ),
      ),
    ],
  );
});

class _WelcomeHeader extends StatelessWidget {
  const _WelcomeHeader();

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t.appTitle, style: theme.textTheme.displaySmall?.copyWith(color: AppTheme.brand)),
        const SizedBox(height: 8),
        Text(t.welcomeHeadline, style: theme.textTheme.titleMedium),
      ],
    );
  }
}
