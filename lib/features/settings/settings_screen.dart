import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/constants/app_metadata.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/date_display.dart';
import '../../core/widgets/settings_components.dart';
import '../../core/widgets/sync_status.dart';
import '../../data/sync/sync_state.dart' as sync_models;
import '../../domain/entities/app_user.dart';
import '../../l10n/app_localizations.dart';
import '../data_management/qaza_data_management_screen.dart';
import '../knowledge_base/presentation/knowledge_base_page.dart';
import 'account_screen.dart';
import 'notifications_screen.dart';
import 'qaza_reset_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final account = ref.watch(currentUserProvider);
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);

    void open(Widget screen) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    }

    return AppScaffold(
      title: l10n.settingsTitle,
      body: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          SettingsSection(
            title: l10n.settingsAppearance,
            subtitle: l10n.settingsAppearanceSubtitle,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SegmentedButton<AppThemeMode>(
                key: const Key('settings_theme_mode'),
                segments: [
                  ButtonSegment(
                      value: AppThemeMode.system,
                      icon: const Icon(Icons.brightness_6_outlined),
                      label: Text(l10n.settingsThemeSystem)),
                  ButtonSegment(
                      value: AppThemeMode.light,
                      icon: const Icon(Icons.light_mode_outlined),
                      label: Text(l10n.settingsThemeLight)),
                  ButtonSegment(
                      value: AppThemeMode.dark,
                      icon: const Icon(Icons.dark_mode_outlined),
                      label: Text(l10n.settingsThemeDark)),
                ],
                selected: {themeMode},
                onSelectionChanged: (value) {
                  final selected = value.first;
                  if (selected != themeMode)
                    ref.read(themeModeProvider.notifier).set(selected);
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          SettingsSection(
            title: l10n.settingsLanguage,
            subtitle: l10n.settingsLanguageSubtitle,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SegmentedButton<String>(
                    key: const Key('settings_language'),
                    segments: [
                      ButtonSegment(
                        value: 'en',
                        icon: const Icon(Icons.language_outlined),
                        label: Text(l10n.languageEnglish),
                      ),
                      ButtonSegment(
                        value: 'ur',
                        label: Text(l10n.languageUrdu),
                      ),
                    ],
                    selected: {locale.languageCode},
                    onSelectionChanged: (value) {
                      final selected = value.first;
                      if (selected != locale.languageCode) {
                        ref.read(localeProvider.notifier).set(Locale(selected));
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(l10n.settingsLanguageNote,
                      style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SettingsSection(
            title: l10n.settingsAccountSection,
            subtitle: l10n.settingsAccountSubtitle,
            child: SettingsNavRow(
              icon: Icons.account_circle_outlined,
              title: l10n.settingsAccountSection,
              subtitle: _accountSubtitle(l10n, account),
              onTap: () => open(const AccountScreen()),
            ),
          ),
          const SizedBox(height: 16),
          SettingsSection(
            title: l10n.settingsPrayerSection,
            subtitle: l10n.settingsPrayerSubtitle,
            child: Column(
              children: [
                SettingsNavRow(
                  icon: Icons.menu_book_outlined,
                  title: l10n.settingsPrayerRules,
                  subtitle: l10n.settingsPrayerRulesSubtitle,
                  onTap: () => open(const FiqhScreen()),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                SettingsNavRow(
                  icon: Icons.library_books_outlined,
                  title: l10n.knowledgeBaseTitle,
                  subtitle: l10n.settingsKnowledgeBaseSubtitle,
                  onTap: () => open(const KnowledgeBasePage()),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SettingsSection(
            title: l10n.notificationsTitle,
            subtitle: l10n.settingsNotificationsSubtitle,
            child: SettingsNavRow(
              icon: Icons.notifications_none,
              title: l10n.notificationsTitle,
              subtitle: l10n.settingsNotificationsRowSubtitle,
              onTap: () => open(const NotificationsScreen()),
            ),
          ),
          const SizedBox(height: 16),
          SettingsSection(
            title: l10n.settingsDataSection,
            subtitle: l10n.settingsDataSubtitle,
            child: SettingsNavRow(
              icon: Icons.cloud_outlined,
              title: l10n.settingsDataCloud,
              subtitle: l10n.settingsDataCloudSubtitle,
              onTap: () => open(const DataCloudScreen()),
            ),
          ),
          const SizedBox(height: 12),
          const _ResetQazaCounterRow(),
          const SizedBox(height: 16),
          SettingsSection(
            title: l10n.settingsAboutSection,
            subtitle: l10n.settingsAboutSubtitle,
            child: SettingsNavRow(
              icon: Icons.info_outline,
              title: l10n.settingsAboutSection,
              subtitle: l10n.settingsAboutRowSubtitle(appDisplayVersion),
              onTap: () => open(const AboutScreen()),
            ),
          ),
        ],
      ),
    );
  }

  String _accountSubtitle(AppLocalizations l10n, AppUser? account) {
    if (account == null || account.email.isEmpty) {
      return l10n.settingsGoogleSignIn;
    }
    final name = account.displayName;
    return name == null || name.isEmpty ? account.email : name;
  }
}

/// Destructive entry point for resetting the Qaza counter.
///
/// The row owns no reset logic: it reads the ledger size to size the warning,
/// and hands the work to [QazaResetController].
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
      // Nothing to reset, still loading, or already running: all inert.
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
          ..showSnackBar(SnackBar(
              content: Text(done
                  ? l10n.settingsResetCounterDone
                  : l10n.settingsResetCounterFailed(error ?? ''))));
      },
    );
  }
}

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

class DataCloudScreen extends ConsumerWidget {
  const DataCloudScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final offline = ref.watch(offlineRepositoryProvider);
    final state =
        ref.watch(syncStateProvider).valueOrNull ?? offline?.currentState;

    return AppScaffold(
      title: l10n.settingsDataCloud,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SyncStatus(),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.cloud_done_outlined),
                  title: Text(l10n.cloudSyncTitle),
                  subtitle: Text(_syncSubtitle(l10n, state)),
                  trailing: offline == null
                      ? null
                      : IconButton(
                          key: const Key('data_cloud_sync_now'),
                          tooltip: l10n.cloudSyncNow,
                          onPressed: offline.syncNow,
                          icon: const Icon(Icons.sync_rounded)),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.cloud_upload_outlined),
                  title: Text(l10n.cloudPendingChanges),
                  subtitle:
                      Text(l10n.cloudPendingCount(state?.pendingCount ?? 0)),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                    leading: const Icon(Icons.schedule_outlined),
                    title: Text(l10n.cloudLastSynced),
                    subtitle: Text(formatAppDateTime(state?.lastSyncAt))),
              ],
            ),
          ),
          const SizedBox(height: 10),
          AppCard(
            padding: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(Icons.import_export_rounded),
              title: Text(l10n.dataTitle),
              subtitle: Text(l10n.cloudExportImportSubtitle),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const QazaDataManagementScreen())),
            ),
          ),
        ],
      ),
    );
  }

  String _syncSubtitle(AppLocalizations l10n, sync_models.SyncState? state) {
    if (state == null) return l10n.cloudInactive;
    return switch (state.status) {
      sync_models.SyncStatus.bootstrapping => l10n.cloudBootstrapping,
      sync_models.SyncStatus.hydrating => l10n.cloudHydrating,
      sync_models.SyncStatus.synced => l10n.cloudSynced,
      sync_models.SyncStatus.syncing => l10n.cloudSyncing,
      sync_models.SyncStatus.offline => l10n.cloudOffline,
      sync_models.SyncStatus.pendingSync =>
        l10n.cloudPendingCount(state.pendingCount),
      sync_models.SyncStatus.syncError => state.detail ?? l10n.cloudSyncProblem,
    };
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
              subtitle: Text(l10n.settingsAppDescription)),
          ListTile(
              title: Text(l10n.commonVersion),
              subtitle: Text(appDisplayVersion)),
        ],
      ),
    );
  }
}
