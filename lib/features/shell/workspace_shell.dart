import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../l10n/app_localizations.dart';
import '../calculator/calculator_screen.dart';
import '../home/home_screen.dart';
import '../knowledge_base/presentation/knowledge_base_page.dart';
import '../qaza/completion_screen.dart';
import '../qaza/qaza_tracker_screen.dart';
import '../settings/settings_screen.dart';

/// The five workspace destinations, in navigation-bar order.
enum WorkspaceDestination { home, qaza, calculator, knowledge, settings }

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
    CalculatorScreen(),
    KnowledgeBasePage(),
    SettingsScreen(),
  ];

  /// The destinations that carry the Complete Qaza action.
  ///
  /// It lives on the shell rather than inside each page, so the two screens
  /// share one button and one rule about when it appears.
  static const _completeQazaDestinations = {
    WorkspaceDestination.home,
    WorkspaceDestination.qaza,
  };

  final Set<int> _mounted = {0};

  void _selectDestination(int value) {
    ref.read(workspaceDestinationProvider.notifier).state =
        WorkspaceDestination.values[value];
  }

  void _handleBack() {
    ref.read(workspaceDestinationProvider.notifier).state =
        WorkspaceDestination.home;
  }

  Future<void> _openCompleteQaza() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => const CompleteQazaScreen()),
    );
    if (mounted) ref.invalidate(progressSummaryProvider);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final destination = ref.watch(workspaceDestinationProvider);
    final index = destination.index;
    // A destination stays mounted once visited, so returning to it keeps its
    // scroll position and in-progress state.
    _mounted.add(index);

    // Nothing pending means nothing to complete, so the action is absent
    // rather than present and inert.
    final pending = ref.watch(progressSummaryProvider).valueOrNull?.overall;
    final showCompleteQaza = _completeQazaDestinations.contains(destination) &&
        (pending?.pending ?? 0) > 0;

    return PopScope<void>(
      canPop: index == 0,
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
        floatingActionButton: showCompleteQaza
            ? FloatingActionButton.extended(
                key: const Key('complete_qaza_fab'),
                onPressed: _openCompleteQaza,
                icon: const Icon(Icons.check_circle_outline_rounded),
                label: Text(l10n.homeCompleteQaza),
              )
            : null,
        bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: _selectDestination,
          destinations: [
            NavigationDestination(
                icon: const Icon(Icons.mosque_outlined),
                selectedIcon: const Icon(Icons.mosque_rounded),
                label: l10n.navHome),
            NavigationDestination(
                icon: const Icon(Icons.checklist_outlined),
                selectedIcon: const Icon(Icons.checklist_rounded),
                label: l10n.navQaza),
            NavigationDestination(
                icon: const Icon(Icons.calculate_outlined),
                selectedIcon: const Icon(Icons.calculate_rounded),
                label: l10n.navCalculator),
            NavigationDestination(
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
