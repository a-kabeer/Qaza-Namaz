import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({required this.themeMode, required this.onThemeModeChanged, required this.onSignOut, super.key});
  final AppThemeMode themeMode;
  final ValueChanged<AppThemeMode> onThemeModeChanged;
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 32), children: [
      Text('Settings', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 4),
      Text('Personalize your Qaza workspace', style: Theme.of(context).textTheme.bodyMedium),
      const SizedBox(height: 20),
      Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(Icons.palette_outlined, color: cs.primary), const SizedBox(width: 10), Text('Appearance & Theme', style: Theme.of(context).textTheme.titleLarge)]),
        const SizedBox(height: 14),
        SegmentedButton<AppThemeMode>(segments: const [
          ButtonSegment(value: AppThemeMode.light, icon: Icon(Icons.light_mode_outlined), label: Text('Light')),
          ButtonSegment(value: AppThemeMode.dark, icon: Icon(Icons.dark_mode_outlined), label: Text('Dark')),
          ButtonSegment(value: AppThemeMode.system, icon: Icon(Icons.settings_suggest_outlined), label: Text('System')),
        ], selected: {themeMode}, onSelectionChanged: (s) => onThemeModeChanged(s.first)),
        const SizedBox(height: 10),
        Text('System follows your Android device appearance automatically.', style: Theme.of(context).textTheme.bodySmall),
      ]))),
      const SizedBox(height: 12),
      Card(child: Column(children: [
        const ListTile(leading: Icon(Icons.menu_book_outlined), title: Text('Prayer & Fiqh Rules'), subtitle: Text('Prayer preferences remain separate from Isha/Witr ledgers.')),
        SwitchListTile(value: true, onChanged: null, title: const Text('Keep Witr as a separate prayer'), subtitle: const Text('Witr is always tracked independently.')),
      ])),
      const SizedBox(height: 12),
      Card(child: Column(children: [
        const ListTile(leading: Icon(Icons.cloud_outlined), title: Text('Data & Cloud Vault'), subtitle: Text('Your signed-in account is the source for cloud-synced records.')),
        ListTile(leading: const Icon(Icons.sync_rounded), title: const Text('Cloud sync'), trailing: Icon(Icons.check_circle, color: cs.tertiary)),
      ])),
      const SizedBox(height: 12),
      Card(child: ListTile(leading: Icon(Icons.info_outline, color: cs.primary), title: const Text('About Qaza Namaz'), subtitle: const Text('Task 3 • Serene Sanctuary UI'))),
      const SizedBox(height: 20),
      OutlinedButton.icon(onPressed: onSignOut, icon: const Icon(Icons.logout), label: const Text('Sign out'), style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50))),
    ]);
  }
}
