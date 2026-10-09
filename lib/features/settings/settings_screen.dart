import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/constants/app_metadata.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/settings_components.dart';
import '../../l10n/app_localizations.dart';
import '../prayer_time/application/prayer_time_providers.dart';
import 'profile_screen.dart';
import '../account/account_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = ref.watch(localeProvider);

    void open(Widget screen) {
      Navigator.push(
        context,
        MaterialPageRoute<void>(builder: (_) => screen),
      );
    }

    Future<void> changeLanguage(Locale selectedLocale) async {
      final resolved = LocaleNotifier.resolve(selectedLocale.languageCode);
      if (resolved == null ||
          ref.read(localeProvider).languageCode == resolved.languageCode) {
        return;
      }

      ref.read(localeProvider.notifier).set(resolved);
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
          SettingsSection(
            title: l10n.settingsLanguage,
            subtitle: l10n.settingsLanguageSubtitle,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SegmentedButton<String>(
                key: const Key('settings_language'),
                segments: [
                  ButtonSegment<String>(
                    value: 'en',
                    icon: const Icon(Icons.language_outlined),
                    label: Text(l10n.languageEnglish),
                  ),
                  ButtonSegment<String>(
                    value: 'ur',
                    label: Text(l10n.languageUrdu),
                  ),
                ],
                selected: {locale.languageCode},
                onSelectionChanged: (value) {
                  changeLanguage(Locale(value.first));
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

class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            title: const Text('GeoNames attribution'),
            subtitle: Text(
              ref.read(offlineCityResolverProvider).attribution,
            ),
          ),
        ],
      ),
    );
  }
}
