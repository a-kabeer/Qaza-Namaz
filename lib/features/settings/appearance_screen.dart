import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_theme_labels.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/settings_components.dart';
import '../../l10n/app_localizations.dart';

class AppearanceScreen extends ConsumerWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final themeMode = ref.watch(themeModeProvider);
    final primaryColor = ref.watch(primaryColorProvider);
    final scheme = Theme.of(context).colorScheme;

    return AppScaffold(
      title: l10n.settingsAppearance,
      body: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          SettingsSection(
            title: l10n.settingsThemeSelector,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final mode in AppThemeMode.values)
                    ChoiceChip(
                      key: Key('appearance_theme_${mode.name}'),
                      label: Text(appThemeModeLabel(l10n, mode)),
                      selected: themeMode == mode,
                      onSelected: (selected) {
                        if (selected) {
                          ref.read(themeModeProvider.notifier).set(mode);
                        }
                      },
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          SettingsSection(
            title: l10n.settingsPrimaryColor,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final color in AppPrimaryColor.values)
                    ChoiceChip(
                      key: Key('appearance_primary_color_${color.name}'),
                      avatar: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: AppTheme.colorFor(color),
                          shape: BoxShape.circle,
                          border: Border.all(color: scheme.outlineVariant),
                        ),
                      ),
                      label: Text(appPrimaryColorLabel(l10n, color)),
                      selected: primaryColor == color,
                      onSelected: (selected) {
                        if (selected) {
                          ref.read(primaryColorProvider.notifier).set(color);
                        }
                      },
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
