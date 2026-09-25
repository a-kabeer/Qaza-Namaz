
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/constants/app_metadata.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/settings_components.dart';
import '../../l10n/app_localizations.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';
import 'qaza_reset_controller.dart';

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

    return AppScaffold(
      title: l10n.settingsTitle,
      body: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          AppCard(
            padding: EdgeInsets.zero,
            child: SettingsNavRow(
              key: const Key('settings_profile'),
              icon: Icons.person_outline_rounded,
              title: l10n.profileTitle,
              subtitle: l10n.profileSettingsSubtitle,
              onTap: () => open(const ProfileScreen()),
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            padding: EdgeInsets.zero,
            child: SettingsNavRow(
              key: const Key('settings_notifications'),
              icon: Icons.notifications_none_rounded,
              title: l10n.notificationsTitle,
              subtitle: l10n.settingsNotificationsRowSubtitle,
              onTap: () => open(const NotificationsScreen()),
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
                  ref.read(localeProvider.notifier).set(Locale(value.first));
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          const _ResetQazaCounterRow(),
          const SizedBox(height: 12),
          AppCard(
            padding: EdgeInsets.zero,
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

class _ResetQazaCounterRow extends ConsumerWidget {
  const _ResetQazaCounterRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final summary = ref.watch(progressSummaryProvider).valueOrNull;
    final running = ref.watch(qazaResetControllerProvider).running;
    final total = summary?.overall.total ?? 0;
    final empty = summary != null && total == 0;

    return DestructiveActionRow(
      key: const Key('settings_reset_qaza_counter'),
      icon: Icons.restart_alt_rounded,
      label: l10n.settingsResetCounterTitle,
      description: empty
          ? l10n.settingsResetCounterEmpty
          : l10n.settingsResetCounterSubtitle,
      enabled: summary != null && total > 0 && !running,
      confirmationTitle: l10n.settingsResetCounterDialogTitle,
      confirmationMessage: l10n.settingsResetCounterDialogMessage,
      acknowledgeLabel: l10n.settingsResetCounterAcknowledge(total),
      confirmLabel: l10n.settingsResetCounterConfirm,
      onConfirm: () async {
        final messenger = ScaffoldMessenger.of(context);
        final done =
            await ref.read(qazaResetControllerProvider.notifier).reset();
        final error = ref.read(qazaResetControllerProvider).error;
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                done
                    ? l10n.settingsResetCounterDone
                    : l10n.settingsResetCounterFailed(error ?? ''),
              ),
            ),
          );
      },
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
        ],
      ),
    );
  }
}