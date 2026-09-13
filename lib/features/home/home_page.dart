import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../domain/repositories/qaza_repository.dart';
import '../calculator/calculator_page.dart';
import '../dashboard/dashboard_page.dart';
import '../history/history_page.dart';
import '../settings/settings_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({required this.userId, required this.repository, required this.onSignOut, required this.themeMode, required this.onThemeModeChanged, super.key});
  final String userId;
  final QazaRepository repository;
  final Future<void> Function() onSignOut;
  final AppThemeMode themeMode;
  final ValueChanged<AppThemeMode> onThemeModeChanged;
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardPage(userId: widget.userId, repository: widget.repository),
      const CalculatorPage(),
      HistoryPage(userId: widget.userId, repository: widget.repository),
      SettingsPage(themeMode: widget.themeMode, onThemeModeChanged: widget.onThemeModeChanged, onSignOut: widget.onSignOut),
    ];
    const labels = ['Dashboard', 'Calculator', 'Logs', 'Settings'];
    const icons = [Icons.dashboard_rounded, Icons.calculate_rounded, Icons.auto_stories_rounded, Icons.settings_rounded];
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(children: [Icon(Icons.mosque_rounded, color: Theme.of(context).colorScheme.primary), const SizedBox(width: 10), Text(labels[_index], style: Theme.of(context).textTheme.titleLarge)]),
        actions: [
          IconButton(tooltip: 'Sync status', onPressed: () {}, icon: Icon(Icons.cloud_done_rounded, color: Theme.of(context).colorScheme.tertiary)),
          IconButton(tooltip: 'Account', onPressed: () => setState(() => _index = 3), icon: const Icon(Icons.account_circle_outlined)),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(child: IndexedStack(index: _index, children: pages)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: [for (var i = 0; i < labels.length; i++) NavigationDestination(icon: Icon(icons[i]), selectedIcon: Icon(icons[i]), label: labels[i])],
      ),
    );
  }
}
