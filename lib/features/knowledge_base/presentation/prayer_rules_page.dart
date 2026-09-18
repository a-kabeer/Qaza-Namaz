import 'package:flutter/material.dart';

import '../../../core/widgets/app_scaffold.dart';
import '../../../l10n/app_localizations.dart';

/// The fiqh rules the calculator applies.
///
/// Reference material, so it sits under Knowledge with the Masail and
/// Mugalat rather than under Settings, which is for configuration.
class FiqhScreen extends StatelessWidget {
  const FiqhScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppScaffold(
      title: l10n.settingsPrayerRules,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
              title: Text(l10n.rulesCalculationMethod),
              subtitle: Text(l10n.rulesCalculationMethodSubtitle)),
          ListTile(
              title: Text(l10n.rulesBaligh),
              subtitle: Text(l10n.rulesBalighSubtitle)),
          ListTile(
              title: Text(l10n.rulesWitr),
              subtitle: Text(l10n.rulesWitrSubtitle)),
        ],
      ),
    );
  }
}
