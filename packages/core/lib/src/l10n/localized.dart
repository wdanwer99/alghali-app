import 'package:material_ui/material_ui.dart';

import '../l10n/generated/core_localizations.dart';
import '../models/catalogue.dart';

extension LocalizedTextIn on LocalizedText {
  /// The text in the app's current language.
  String tr(BuildContext context) => of(Localizations.localeOf(context));
}

extension CoreL10nContext on BuildContext {
  CoreLocalizations get core => CoreLocalizations.of(this);
}
