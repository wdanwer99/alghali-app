import 'package:alghali_core/alghali_core.dart';
import 'package:material_ui/material_ui.dart';

import '../../l10n/generated/app_localizations.dart';

/// Role-based home. In M5 this shows the shop or technician dashboard
/// depending on the signed-in user's roles; for now both are placeholders.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);

    Widget roleCard(IconData icon, String title, String hint) => Card(
      child: ListTile(
        leading: Icon(icon, size: 32),
        title: Text(title, style: theme.textTheme.titleMedium),
        subtitle: Text(hint),
        trailing: Chip(label: Text(t.comingSoon)),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: Text(t.appTitle), actions: const [LanguageToggleButton()]),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(t.welcomeHeadline, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 16),
          roleCard(Icons.storefront_outlined, t.roleShop, t.roleShopHint),
          const SizedBox(height: 8),
          roleCard(Icons.build_outlined, t.roleTechnician, t.roleTechnicianHint),
          const SizedBox(height: 16),
          const Align(alignment: AlignmentDirectional.centerStart, child: BackendStatusChip()),
        ],
      ),
    );
  }
}
