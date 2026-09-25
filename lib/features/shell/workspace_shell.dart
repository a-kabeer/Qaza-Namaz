import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../home/home_screen.dart';
import '../knowledge_base/presentation/knowledge_base_page.dart';
import '../qaza/qaza_tracker_screen.dart';
import '../settings/settings_screen.dart';

/// Every workspace destination.
///
/// The four destinations are the primary navigation.
enum WorkspaceDestination {
  home,
  qaza,
  knowledge,
  settings,
}

/// The selected destination.
///
/// Lifted out of the shell's own State so another screen — Home's prayer
/// rows — can send the user to the Qaza tab through the existing navigation
/// rather than pushing a second copy of the tracker on top of it.
final workspaceDestinationProvider =
    StateProvider<WorkspaceDestination>((ref) => WorkspaceDestination.home);

class WorkspaceShell extends ConsumerStatefulWidget {
  const WorkspaceShell({super.key});

  @override
  ConsumerState<WorkspaceShell> createState() => _WorkspaceShellState();
}

class _WorkspaceShellState extends ConsumerState<WorkspaceShell> {
  static const _pages = <Widget>[
    HomeScreen(),
    QazaTrackerScreen(),
    KnowledgeBasePage(),
    SettingsScreen(),
  ];

  /// The four primary destinations in the bottom navigation.
  static const _barDestinations = [
    WorkspaceDestination.home,
    WorkspaceDestination.qaza,
    WorkspaceDestination.knowledge,
    WorkspaceDestination.settings,
  ];

  final Set<int> _mounted = {0};

  void _selectDestination(int value) {
    ref.read(workspaceDestinationProvider.notifier).state =
        _barDestinations[value];
  }

  void _handleBack() {
    ref.read(workspaceDestinationProvider.notifier).state =
        WorkspaceDestination.home;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    ref.listen<WorkspaceDestination>(
      workspaceDestinationProvider,
      (previous, next) {
        if (previous == null || previous == next || !mounted) return;
        ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
      },
    );

    final destination = ref.watch(workspaceDestinationProvider);
    final index = destination.index;
    // A destination stays mounted once visited, so returning to it keeps its
    // scroll position and in-progress state.
    _mounted.add(index);

    final barIndex = _barDestinations.indexOf(destination);
    final selectedBarIndex = barIndex < 0 ? 0 : barIndex;

    return PopScope<void>(
      canPop: destination == WorkspaceDestination.home,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        body: IndexedStack(
          index: index,
          children: [
            for (var i = 0; i < _pages.length; i++)
              if (_mounted.contains(i)) _pages[i] else const SizedBox.shrink(),
          ],
        ),
        floatingActionButton: null,
        bottomNavigationBar: NavigationBar(
          selectedIndex: selectedBarIndex,
          onDestinationSelected: _selectDestination,
          destinations: [
            NavigationDestination(
                icon: const Icon(Icons.mosque_outlined),
                selectedIcon: const Icon(Icons.mosque_rounded),
                label: l10n.navHome),
            NavigationDestination(
                icon: const Icon(Icons.checklist_outlined),
                selectedIcon: const Icon(Icons.checklist_rounded),
                label: l10n.navQaza),            NavigationDestination(
                icon: const Icon(Icons.menu_book_outlined),
                selectedIcon: const Icon(Icons.menu_book_rounded),
                label: l10n.navKnowledge),
            NavigationDestination(
                icon: const Icon(Icons.tune_outlined),
                selectedIcon: const Icon(Icons.tune_rounded),
                label: l10n.navSettings),
          ],
        ),
      ),
    );
  }
}