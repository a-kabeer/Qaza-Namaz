import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../calculator/calculator_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../history/history_progress.dart';
import '../settings/settings_screen.dart';

class WorkspaceShell extends ConsumerStatefulWidget {
  const WorkspaceShell({super.key});

  @override
  ConsumerState<WorkspaceShell> createState() => _WorkspaceShellState();
}

class _WorkspaceShellState extends ConsumerState<WorkspaceShell> {
  static const _pages = <Widget>[
    DashboardScreen(),
    CalculatorScreen(),
    HistoryProgressScreen(),
    SettingsScreen(),
  ];

  int index = 0;
  final Set<int> _mounted = {0};

  @override
  Widget build(BuildContext context) => Scaffold(
        body: IndexedStack(
          index: index,
          children: [
            for (var i = 0; i < _pages.length; i++)
              if (_mounted.contains(i)) _pages[i] else const SizedBox.shrink(),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: (value) => setState(() {
            index = value;
            _mounted.add(value);
          }),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.mosque_outlined), selectedIcon: Icon(Icons.mosque_rounded), label: 'Dashboard'),
            NavigationDestination(icon: Icon(Icons.calculate_outlined), selectedIcon: Icon(Icons.calculate_rounded), label: 'Calculator'),
            NavigationDestination(icon: Icon(Icons.history_outlined), selectedIcon: Icon(Icons.history_rounded), label: 'Logs'),
            NavigationDestination(icon: Icon(Icons.tune_outlined), selectedIcon: Icon(Icons.tune_rounded), label: 'Settings'),
          ],
        ),
      );
}
