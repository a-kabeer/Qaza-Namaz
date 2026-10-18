import '../../l10n/app_localizations.dart';
import 'app_theme.dart';

String appThemeModeLabel(AppLocalizations l10n, AppThemeMode mode) =>
    switch (mode) {
      AppThemeMode.system => l10n.settingsThemeSystem,
      AppThemeMode.light => l10n.settingsThemeLight,
      AppThemeMode.dark => l10n.settingsThemeDark,
    };

String appPrimaryColorLabel(AppLocalizations l10n, AppPrimaryColor color) =>
    switch (color) {
      AppPrimaryColor.teal => l10n.settingsPrimaryColorTeal,
      AppPrimaryColor.blue => l10n.settingsPrimaryColorBlue,
      AppPrimaryColor.green => l10n.settingsPrimaryColorGreen,
      AppPrimaryColor.purple => l10n.settingsPrimaryColorPurple,
      AppPrimaryColor.amber => l10n.settingsPrimaryColorAmber,
      AppPrimaryColor.rose => l10n.settingsPrimaryColorRose,
      AppPrimaryColor.slate => l10n.settingsPrimaryColorSlate,
      AppPrimaryColor.black => l10n.settingsPrimaryColorBlack,
    };
