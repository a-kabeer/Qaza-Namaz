import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../l10n/app_localizations.dart';
import '../auth/backup_prompt.dart';
import '../calculator/calculator_screen.dart';
import '../home/home_screen.dart';
import '../knowledge_base/presentation/knowledge_base_page.dart';
import '../prayer_times/presentation/prayer_times_localizations.dart';
import '../prayer_times/presentation/prayer_times_screen.dart';
import '../qaza/add_actions_fab.dart';
import '../qaza/add_qaza_screen.dart';
import '../qaza/qaza_tracker_screen.dart';
import '../settings/settings_screen.dart';

/// Every workspace destination.
///
/// Calculator remains contextual; the other five destinations are primary navigation.
enum WorkspaceDestination {
  home,
  qaza,
  calculator,
  knowledge,
  settings,
  prayerTimes,
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
    CalculatorScreen(),
    KnowledgeBasePage(),
    SettingsScreen(),
    PrayerTimesScreen(),
  ];

  /// The five primary destinations in the bottom navigation.
  static const _barDestinations = [
    WorkspaceDestination.home,
    WorkspaceDestination.qaza,
    WorkspaceDestination.prayerTimes,
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

  Future<void> _push(Widget page) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
    if (mounted) ref.invalidate(progressSummaryProvider);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // A guest who has just recorded their first Qaza is offered a backup,
    // once. Shown from here so it reaches them wherever they added it.
    ref.listen<bool>(shouldOfferBackupProvider, (_, offer) {
      if (!offer || !mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) showBackupPrompt(context, ref);
      });
    });

    final destination = ref.watch(workspaceDestinationProvider);
    final index = destination.index;
    // A destination stays mounted once visited, so returning to it keeps its
    // scroll position and in-progress state.
    _mounted.add(index);

    // Calculator remains contextual; Prayer Times is a primary destination.
    final barIndex = _barDestinations.indexOf(destination);
    final selectedBarIndex = barIndex < 0 ? 0 : barIndex;

    final overall = ref.watch(progressSummaryProvider).valueOrNull?.overall;
    final hasQazaRecords = (overall?.total ?? 0) > 0;

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
        // Home exposes Add/Calculate only when Qaza records exist.
        // Completion remains in the embedded Home section. Qaza keeps the
        // same Add/Calculate action menu.
        floatingActionButton:
            destination == WorkspaceDestination.qaza ||
                    (destination == WorkspaceDestination.home && hasQazaRecords)
                ? AddActionsFab(
                    onAddQaza: () => _push(const AddQazaScreen()),
                    onCalculateQaza: () => _push(const CalculatorScreen()),
                  )
                : null,
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
                label: l10n.navQaza),
            NavigationDestination(
                icon: const Icon(Icons.schedule_outlined),
                selectedIcon: const Icon(Icons.schedule_rounded),
                label: PrayerTimesStrings.title(context)),
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
