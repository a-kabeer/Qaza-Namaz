import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/constants/app_metadata.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_theme_labels.dart';
import '../../core/widgets/language_selector.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/settings_components.dart';
import '../../l10n/app_localizations.dart';
import '../prayer_time/application/prayer_time_providers.dart';
import 'appearance_screen.dart';
import 'profile_screen.dart';
import '../account/account_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = ref.watch(localeProvider);
    final themeMode = ref.watch(themeModeProvider);
    final primaryColor = ref.watch(primaryColorProvider);

    void open(Widget screen) {
      Navigator.push(
        context,
        MaterialPageRoute<void>(builder: (_) => screen),
      );
    }

    Future<void> changeLanguage(Locale selectedLocale) async {
      final resolved =
          LocaleNotifier.resolve(LocaleNotifier.localeKey(selectedLocale));
      if (resolved == null ||
          LocaleNotifier.localeKey(ref.read(localeProvider)) ==
              LocaleNotifier.localeKey(resolved)) {
        return;
      }

      try {
        await ref.read(localeProvider.notifier).set(resolved);
      } catch (_) {
        if (!context.mounted) return;
        ref
            .read(appSnackbarServiceProvider)
            .error(AppLocalizations.of(context).errorStorage);
      }
    }

    final accountSubtitle = l10n.settingsAccountGuestSubtitle;

    return AppScaffold(
      title: l10n.settingsTitle,
      body: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          Card(
            child: SettingsNavRow(
              key: const Key('settings_account'),
              icon: Icons.account_circle_outlined,
              title: l10n.accountTitle,
              subtitle: accountSubtitle,
              onTap: () => open(const AccountScreen()),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: SettingsNavRow(
              key: const Key('settings_profile'),
              icon: Icons.person_outline_rounded,
              title: l10n.profileTitle,
              subtitle: l10n.profileSettingsSubtitle,
              onTap: () => open(const ProfileScreen()),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: SettingsNavRow(
              key: const Key('settings_appearance'),
              icon: Icons.palette_outlined,
              title: l10n.settingsAppearance,
              subtitle:
                  '${appThemeModeLabel(l10n, themeMode)} · ${appPrimaryColorLabel(l10n, primaryColor)}',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    key: const Key('settings_appearance_color_swatch'),
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: AppTheme.colorFor(primaryColor),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
              onTap: () => open(const AppearanceScreen()),
            ),
          ),
          const SizedBox(height: 12),
          SettingsSection(
            title: l10n.settingsLanguage,
            subtitle: l10n.settingsLanguageSubtitle,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: LanguageSelector<Locale>(
                key: const Key('settings_language'),
                options: AppLocalizations.supportedLocales
                    .map(
                      (supportedLocale) => LanguageOption<Locale>(
                        value: supportedLocale,
                        languageCode: supportedLocale.languageCode,
                        scriptCode: supportedLocale.scriptCode,
                      ),
                    )
                    .toList(growable: false),
                value: locale,
                layout: LanguageSelectorLayout.fullWidth,
                semanticLabel: l10n.settingsLanguage,
                optionKeyPrefix: 'settings_language_option',
                onChanged: (selectedLocale) {
                  unawaited(changeLanguage(selectedLocale));
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: SettingsNavRow(
              key: const Key('settings_about'),
              icon: Icons.info_outline_rounded,
              title: l10n.settingsAboutSection,
              subtitle: l10n.settingsAboutRowSubtitle(appDisplayVersion),
              onTap: () => open(const AboutScreen()),
            ),
          ),
        ],
      ),
    );
  }
}

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppScaffold(
      title: l10n.settingsAboutSection,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            title: Text(l10n.appTitle),
            subtitle: Text(l10n.settingsAppDescription),
          ),
          ListTile(
            title: Text(l10n.commonVersion),
            subtitle: Text(appDisplayVersion),
          ),
          ListTile(
            key: const Key('about_licenses'),
            leading: const Icon(Icons.article_outlined),
            title: Text(MaterialLocalizations.of(context).licensesPageTitle),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const LicensesScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Separates data attribution from the complete software licence catalogue.
class LicensesScreen extends ConsumerWidget {
  const LicensesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final attribution = ref.watch(offlineCityResolverProvider).attribution;

    return AppScaffold(
      title: MaterialLocalizations.of(context).licensesPageTitle,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ListTile(
                  key: const Key('licenses_geonames_attribution'),
                  leading: const Icon(Icons.public_outlined),
                  title: Text(l10n.settingsLicensesGeoNamesTitle),
                  subtitle: Text(l10n.settingsLicensesGeoNamesSubtitle),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: SelectableText(attribution),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              key: const Key('licenses_software_catalogue'),
              leading: const Icon(Icons.article_outlined),
              title: Text(l10n.settingsLicensesSoftwareTitle),
              subtitle: Text(l10n.settingsLicensesSoftwareSubtitle),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                showLicensePage(
                  context: context,
                  applicationName: l10n.appTitle,
                  applicationVersion: appDisplayVersion,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
