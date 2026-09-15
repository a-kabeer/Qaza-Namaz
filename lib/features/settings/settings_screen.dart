import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/date_display.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/sync_status.dart';
import '../../core/widgets/legacy_components.dart';
import '../../data/sync/sync_state.dart';
import '../../domain/entities/app_user.dart';
import '../data_management/qaza_data_management_screen.dart';
import 'account_screen.dart';
import 'notifications_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final account = ref.watch(currentUserProvider);
    final themeMode = ref.watch(themeModeProvider);

    void open(Widget screen) => Navigator.push(context, MaterialPageRoute(builder: (_) => screen));

    return AppScaffold(
      title: 'Settings',
      body: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          SettingsSection(
            title: 'Appearance',
            subtitle: 'Theme changes apply to the entire app instantly.',
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SegmentedButton<AppThemeMode>(
                key: const Key('settings_theme_mode'),
                segments: const [
                  ButtonSegment(value: AppThemeMode.system, icon: Icon(Icons.brightness_6_outlined), label: Text('System')),
                  ButtonSegment(value: AppThemeMode.light, icon: Icon(Icons.light_mode_outlined), label: Text('Light')),
                  ButtonSegment(value: AppThemeMode.dark, icon: Icon(Icons.dark_mode_outlined), label: Text('Dark')),
                ],
                selected: {themeMode},
                onSelectionChanged: (value) {
                  final selected = value.first;
                  if (selected != themeMode) ref.read(themeModeProvider.notifier).set(selected);
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          SettingsSection(
            title: 'Language',
            subtitle: 'English is the current app language.',
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, icon: Icon(Icons.language_outlined), label: Text('English')),
                      ButtonSegment(value: true, label: Text('اردو (Soon)'), enabled: false),
                    ],
                    selected: const {false},
                    onSelectionChanged: (_) {},
                  ),
                  const SizedBox(height: 8),
                  Text('Urdu translation is not available yet. English is used across the app.', style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SettingsSection(
            title: 'General',
            child: Column(
              children: [
                SettingsNavRow(icon: Icons.account_circle_outlined, title: 'Account', subtitle: _accountSubtitle(account), onTap: () => open(const AccountScreen())),
                const Divider(indent: 16, endIndent: 16),
                SettingsNavRow(icon: Icons.menu_book_outlined, title: 'Prayer & Fiqh Rules', subtitle: 'Calculation method, Baligh, Witr', onTap: () => open(const FiqhScreen())),
                const Divider(indent: 16, endIndent: 16),
                SettingsNavRow(icon: Icons.notifications_none, title: 'Notifications', subtitle: 'Daily reminder and schedule', onTap: () => open(const NotificationsScreen())),
                const Divider(indent: 16, endIndent: 16),
                SettingsNavRow(icon: Icons.cloud_outlined, title: 'Data & Cloud', subtitle: 'Sync, export and import status', onTap: () => open(const DataCloudScreen())),
                const Divider(indent: 16, endIndent: 16),
                SettingsNavRow(icon: Icons.info_outline, title: 'About', subtitle: 'Qaza Namaz • version 0.2.0', onTap: () => open(const AboutScreen())),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _accountSubtitle(AppUser? account) {
    if (account == null || account.email.isEmpty) return 'Google sign-in';
    final name = account.displayName;
    return name == null || name.isEmpty ? account.email : name;
  }
}

class FiqhScreen extends StatelessWidget {
  const FiqhScreen({super.key});

  @override
  Widget build(BuildContext context) => AppScaffold(
        title: 'Prayer & Fiqh Rules',
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: const [
            ListTile(title: Text('Calculation Method'), subtitle: Text('Choose the method applicable to your circumstances.')),
            ListTile(title: Text('Baligh / Puberty'), subtitle: Text('Used by the planning calculator.')),
            ListTile(title: Text('Witr'), subtitle: Text('Witr remains an independent prayer category.')),
          ],
        ),
      );
}

class DataCloudScreen extends ConsumerWidget {
  const DataCloudScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offline = ref.watch(offlineRepositoryProvider);
    final state = ref.watch(syncStateProvider).valueOrNull ?? offline?.currentState;
    return AppScaffold(
      title: 'Data & Cloud',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SyncStatus(),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(leading: const Icon(Icons.cloud_done_outlined), title: const Text('Cloud Sync'), subtitle: Text(_syncSubtitle(state)), trailing: offline == null ? null : IconButton(key: const Key('data_cloud_sync_now'), tooltip: 'Sync now', onPressed: offline.syncNow, icon: const Icon(Icons.sync_rounded))),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(leading: const Icon(Icons.cloud_upload_outlined), title: const Text('Pending changes'), subtitle: Text('${state?.pendingCount ?? 0} local ${(state?.pendingCount ?? 0) == 1 ? 'change' : 'changes'} waiting to be confirmed by the cloud.')),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(leading: const Icon(Icons.schedule_outlined), title: const Text('Last synced'), subtitle: Text(formatAppDateTime(state?.lastSyncAt))),
              ],
            ),
          ),
          const SizedBox(height: 10),
          AppCard(
            padding: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(Icons.import_export_rounded),
              title: const Text('Export & Import'),
              subtitle: const Text('User-controlled JSON backup and safe restore. No cloud data is deleted by these actions.'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const QazaDataManagementScreen())),
            ),
          ),
        ],
      ),
    );
  }

  String _syncSubtitle(SyncState? state) {
    if (state == null) return 'Offline storage is not active in this build.';
    return switch (state.status) {
      SyncStatus.synced => 'All your Qaza records are saved in the cloud.',
      SyncStatus.syncing => 'Syncing your ledger…',
      SyncStatus.offline => 'Offline — records are saved on this device and sync automatically.',
      SyncStatus.pendingSync => '${state.pendingCount} ${state.pendingCount == 1 ? 'change' : 'changes'} waiting to sync.',
      SyncStatus.syncError => state.detail ?? 'Sync problem — your data is safe on this device.',
    };
  }
}

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) => AppScaffold(
        title: 'About',
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: const [
            ListTile(title: Text('Qaza Namaz'), subtitle: Text('Islamic Prayer Qaza Tracker')),
            ListTile(title: Text('Version'), subtitle: Text('0.2.0')),
          ],
        ),
      );
}
