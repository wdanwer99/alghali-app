import 'package:alghali_core/alghali_core.dart';
import 'package:material_ui/material_ui.dart';

import '../../l10n/generated/app_localizations.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.appTitle), actions: const [LanguageToggleButton()]),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(t.welcomeHeadline, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(t.welcomeBody, style: theme.textTheme.bodyLarge),
          const SizedBox(height: 24),
          Card(
            child: ListTile(
              leading: const Icon(Icons.construction_outlined),
              title: Text(t.homeComingSoon),
            ),
          ),
          const SizedBox(height: 16),
          const Align(alignment: AlignmentDirectional.centerStart, child: BackendStatusChip()),
        ],
      ),
    );
  }
}
