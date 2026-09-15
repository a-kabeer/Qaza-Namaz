// Settings, Account and companion screens.
//
// These screens are shared by WorkspaceShellV2. The dashboard/namaz flows live
// in workspace_v2.dart and the *_v2.dart flow files; legacy stand-alone
// screens were removed when the shared component library was introduced.

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../domain/entities/app_user.dart';
import 'components.dart';

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
          Text('Use this screen for planning and estimation. It does not replace individual Qaza records.'),
          SizedBox(height: 20),
          TextField(keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Years of missed prayers')),
          SizedBox(height: 12),
          FilledButton(onPressed: null, child: Text('Calculate')),
        ],
      ),
    );
  }
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.onSignOut,
    this.user,
    this.themeMode = AppThemeMode.system,
    this.onThemeModeChanged,
  });

  final Future<void> Function() onSignOut;
  final AppUser? user;
  final AppThemeMode themeMode;
  final ValueChanged<AppThemeMode>? onThemeModeChanged;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String get _accountSubtitle {
    final account = widget.user;
    if (account == null || account.email.isEmpty) return 'Google sign-in';
    final name = account.displayName;
    if (name == null || name.isEmpty) return account.email;
    return name;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                  ButtonSegment(value: AppThemeMode.system, icon: Icon(Icons.brightness_6_outlined), label: Text('System')),
                  ButtonSegment(value: AppThemeMode.light, icon: Icon(Icons.light_mode_outlined), label: Text('Light')),
                  ButtonSegment(value: AppThemeMode.dark, icon: Icon(Icons.dark_mode_outlined), label: Text('Dark')),
                ],
                selected: {widget.themeMode},
                onSelectionChanged: (value) {
                  final selected = value.first;
                  if (selected == widget.themeMode) return;
                  widget.onThemeModeChanged?.call(selected);
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
                  Text(
                    'Urdu translation is not available yet. English is used across the app.',
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
                  subtitle: _accountSubtitle,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AccountScreen(
                        user: widget.user ?? const AppUser(id: 'unknown', email: ''),
                        onSignOut: widget.onSignOut,
                      ),
                    ),
                  ),
                ),
                const Divider(indent: 16, endIndent: 16),
                SettingsNavRow(
                  icon: Icons.menu_book_outlined,
                  title: 'Prayer & Fiqh Rules',
                  subtitle: 'Calculation method, Baligh, Witr',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const FiqhScreen()),
                  ),
                ),
                const Divider(indent: 16, endIndent: 16),
                SettingsNavRow(
                  icon: Icons.notifications_none,
                  title: 'Notifications',
                  subtitle: 'Reminders are not implemented yet',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                  ),
                ),
                const Divider(indent: 16, endIndent: 16),
                SettingsNavRow(
                  icon: Icons.cloud_outlined,
                  title: 'Data & Cloud',
                  subtitle: 'Sync, export and import status',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const DataCloudScreen()),
                  ),
                ),
                const Divider(indent: 16, endIndent: 16),
                SettingsNavRow(
                  icon: Icons.info_outline,
                  title: 'About',
                  subtitle: 'Qaza Namaz • version 0.2.0',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AboutScreen()),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key, required this.user, required this.onSignOut});

  final AppUser user;
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
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
              await onSignOut();
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
        ListTile(title: Text('Calculation Method'), subtitle: Text('Choose the method applicable to your circumstances.')),
        ListTile(title: Text('Baligh / Puberty'), subtitle: Text('Used by the planning calculator.')),
        ListTile(title: Text('Witr'), subtitle: Text('Witr remains an independent prayer category.')),
      ],
    ),
  );
}

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});
  @override
  Widget build(BuildContext context) => PageScaffold(
    title: 'Notifications',
    child: ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        SwitchListTile(
          value: false,
          onChanged: null,
          title: Text('Daily reminder'),
          subtitle: Text('Notification support will be implemented in the notifications task.'),
        ),
      ],
    ),
  );
}

class DataCloudScreen extends StatelessWidget {
  const DataCloudScreen({super.key});
  @override
  Widget build(BuildContext context) => PageScaffold(
    title: 'Data & Cloud',
    child: ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        Card(child: ListTile(leading: Icon(Icons.cloud_done_outlined), title: Text('Cloud Sync'), subtitle: Text('Sync status will be provided by the sync task.'))),
        SizedBox(height: 10),
        Card(child: ListTile(title: Text('Export / Import'), subtitle: Text('Data export and import will be connected by the data task.'))),
      ],
    ),
  );
}

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});
  @override
  Widget build(BuildContext context) => PageScaffold(
    title: 'About',
    child: ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        ListTile(title: Text('Qaza Namaz'), subtitle: Text('Islamic Prayer Qaza Tracker')),
        ListTile(title: Text('Version'), subtitle: Text('0.2.0')),
      ],
    ),
  );
}

