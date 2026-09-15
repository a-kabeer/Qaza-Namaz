// Settings, Account and companion screens.
//
// Every screen reads its state from providers (theme mode, signed-in account,
// sync layer), so nothing is threaded through widget constructors and a change
// made here is visible app-wide immediately.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/entities/app_user.dart';
import '../../data/sync/sync_state.dart';
import '../notifications/notification_controller.dart';
import '../sync/sync_status_bar.dart';
import 'components.dart';
import 'qaza_data_management_screen.dart';

class CalculatorScreen extends StatelessWidget {
  const CalculatorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: 'Calculator',
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          Text('Qaza estimate calculator'),
          SizedBox(height: 12),
          Text(
            'Use this screen for planning and estimation. It does not replace '
            'individual Qaza records.',
          ),
          SizedBox(height: 20),
          TextField(
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: 'Years of missed prayers'),
          ),
          SizedBox(height: 12),
          FilledButton(onPressed: null, child: Text('Calculate')),
        ],
      ),
    );
  }
}

String _accountSubtitle(AppUser? account) {
  if (account == null || account.email.isEmpty) return 'Google sign-in';
  final name = account.displayName;
  if (name == null || name.isEmpty) return account.email;
  return name;
}

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final account = ref.watch(currentUserProvider);
    final themeMode = ref.watch(themeModeProvider);

    void open(Widget screen) => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => screen),
        );

    return PageScaffold(
      title: 'Settings',
      child: ListView(
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
                  ButtonSegment(
                    value: AppThemeMode.system,
                    icon: Icon(Icons.brightness_6_outlined),
                    label: Text('System'),
                  ),
                  ButtonSegment(
                    value: AppThemeMode.light,
                    icon: Icon(Icons.light_mode_outlined),
                    label: Text('Light'),
                  ),
                  ButtonSegment(
                    value: AppThemeMode.dark,
                    icon: Icon(Icons.dark_mode_outlined),
                    label: Text('Dark'),
                  ),
                ],
                selected: {themeMode},
                onSelectionChanged: (value) {
                  final selected = value.first;
                  if (selected == themeMode) return;
                  ref.read(themeModeProvider.notifier).set(selected);
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
                      ButtonSegment(
                        value: false,
                        icon: Icon(Icons.language_outlined),
                        label: Text('English'),
                      ),
                      ButtonSegment(
                        value: true,
                        label: Text('اردو (Soon)'),
                        enabled: false,
                      ),
                    ],
                    selected: const {false},
                    onSelectionChanged: (_) {},
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Urdu translation is not available yet. English is used '
                    'across the app.',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SettingsSection(
            title: 'General',
            child: Column(
              children: [
                SettingsNavRow(
                  icon: Icons.account_circle_outlined,
                  title: 'Account',
                  subtitle: _accountSubtitle(account),
                  onTap: () => open(const AccountScreen()),
                ),
                const Divider(indent: 16, endIndent: 16),
                SettingsNavRow(
                  icon: Icons.menu_book_outlined,
                  title: 'Prayer & Fiqh Rules',
                  subtitle: 'Calculation method, Baligh, Witr',
                  onTap: () => open(const FiqhScreen()),
                ),
                const Divider(indent: 16, endIndent: 16),
                SettingsNavRow(
                  icon: Icons.notifications_none,
                  title: 'Notifications',
                  subtitle: 'Daily reminder and schedule',
                  onTap: () => open(const NotificationsScreen()),
                ),
                const Divider(indent: 16, endIndent: 16),
                SettingsNavRow(
                  icon: Icons.cloud_outlined,
                  title: 'Data & Cloud',
                  subtitle: 'Sync, export and import status',
                  onTap: () => open(const DataCloudScreen()),
                ),
                const Divider(indent: 16, endIndent: 16),
                SettingsNavRow(
                  icon: Icons.info_outline,
                  title: 'About',
                  subtitle: 'Qaza Namaz • version 0.2.0',
                  onTap: () => open(const AboutScreen()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user =
        ref.watch(currentUserProvider) ?? const AppUser(id: '', email: '');

    return PageScaffold(
      title: 'Account',
      onBack: () => Navigator.maybePop(context),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          AccountSection(
            user: user,
            onSignOut: () async {
              await ref.read(authRepositoryProvider).signOut();
              if (context.mounted) Navigator.maybePop(context);
            },
          ),
        ],
      ),
    );
  }
}

class FiqhScreen extends StatelessWidget {
  const FiqhScreen({super.key});

  @override
  Widget build(BuildContext context) => PageScaffold(
        title: 'Prayer & Fiqh Rules',
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: const [
            ListTile(
              title: Text('Calculation Method'),
              subtitle: Text(
                'Choose the method applicable to your circumstances.',
              ),
            ),
            ListTile(
              title: Text('Baligh / Puberty'),
              subtitle: Text('Used by the planning calculator.'),
            ),
            ListTile(
              title: Text('Witr'),
              subtitle: Text('Witr remains an independent prayer category.'),
            ),
          ],
        ),
      );
}

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(notificationSettingsProvider);
    return PageScaffold(
      title: 'Notifications',
      child: settings.when(
        loading: () => const LoadingState(message: 'Loading notification settings…'),
        error: (error, stack) => ErrorState(
          message: 'Notification settings could not be loaded: $error',
          onRetry: () => ref.invalidate(notificationSettingsProvider),
        ),
        data: (value) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: SwitchListTile(
                key: const Key('daily_notification_switch'),
                value: value.enabled,
                title: const Text('Daily reminder'),
                subtitle: Text(
                  value.enabled
                      ? 'Reminder scheduled for ${value.formattedTime}.'
                      : 'Turn on a daily reminder to continue your Qaza routine.',
                ),
                onChanged: (enabled) async {
                  final ok = await ref
                      .read(notificationSettingsProvider.notifier)
                      .setEnabled(enabled);
                  if (!enabled || ok || !context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Notification permission was not granted.'),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.schedule_outlined),
                title: const Text('Reminder time'),
                subtitle: Text(value.formattedTime),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay(hour: value.hour, minute: value.minute),
                  );
                  if (picked == null || !context.mounted) return;
                  await ref
                      .read(notificationSettingsProvider.notifier)
                      .setTime(picked.hour, picked.minute);
                },
              ),
            ),
            const SizedBox(height: 12),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'The reminder is stored on this device. Turning it off cancels '
                  'the scheduled notification. No cloud notification service is used.',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DataCloudScreen extends ConsumerWidget {
  const DataCloudScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offline = ref.watch(offlineRepositoryProvider);
    final state =
        ref.watch(syncStateProvider).valueOrNull ?? offline?.currentState;

    return PageScaffold(
      title: 'Data & Cloud',
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SyncStatusBar(),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.cloud_done_outlined),
                  title: const Text('Cloud Sync'),
                  subtitle: Text(_syncSubtitle(state)),
                  trailing: offline == null
                      ? null
                      : IconButton(
                          key: const Key('data_cloud_sync_now'),
                          tooltip: 'Sync now',
                          onPressed: offline.syncNow,
                          icon: const Icon(Icons.sync_rounded),
                        ),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.cloud_upload_outlined),
                  title: const Text('Pending changes'),
                  subtitle: Text(
                    '${state?.pendingCount ?? 0} local '
                    '${(state?.pendingCount ?? 0) == 1 ? 'change' : 'changes'} '
                    'waiting to be confirmed by the cloud.',
                  ),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.schedule_outlined),
                  title: const Text('Last synced'),
                  subtitle: Text(formatDateTime(state?.lastSyncAt)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.import_export_rounded),
                  title: const Text('Export & Import'),
                  subtitle: const Text(
                    'User-controlled JSON backup and safe restore. No cloud '
                    'data is deleted by these actions.',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const QazaDataManagementScreen(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _syncSubtitle(SyncState? state) {
    if (state == null) {
      return 'Offline storage is not active in this build.';
    }
    return switch (state.status) {
      SyncStatus.synced => 'All your Qaza records are saved in the cloud.',
      SyncStatus.syncing => 'Syncing your ledger…',
      SyncStatus.offline =>
        'Offline — records are saved on this device and sync automatically.',
      SyncStatus.pendingSync =>
        '${state.pendingCount} ${state.pendingCount == 1 ? 'change' : 'changes'} '
            'waiting to sync.',
      SyncStatus.syncError =>
        state.detail ?? 'Sync problem — your data is safe on this device.',
    };
  }
}

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) => PageScaffold(
        title: 'About',
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: const [
            ListTile(
              title: Text('Qaza Namaz'),
              subtitle: Text('Islamic Prayer Qaza Tracker'),
            ),
            ListTile(title: Text('Version'), subtitle: Text('0.2.0')),
          ],
        ),
      );
}
