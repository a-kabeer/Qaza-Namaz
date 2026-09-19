import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../l10n/app_localizations.dart';
import '../auth/backup_prompt.dart';
import '../calculator/calculator_screen.dart';
import '../home/home_screen.dart';
import '../knowledge_base/presentation/knowledge_base_page.dart';
import '../qaza/add_actions_fab.dart';
import '../qaza/add_qaza_screen.dart';
import '../qaza/completion_screen.dart';
import '../qaza/qaza_tracker_screen.dart';
import '../settings/settings_screen.dart';

/// Every workspace destination.
///
/// Not all of them are bottom-bar entries: Qaza and Calculator are reached
/// from Home. See `_barDestinations` for what the bar offers.
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
  static const _completeQazaDestinations = {WorkspaceDestination.home};

  /// The destinations the bottom bar offers.
  ///
  /// Qaza and Calculator stay part of the workspace — Home's prayer rows open
  /// the tracker, and its quick action opens the calculator — they are simply
  /// not bar destinations any more.
  static const _barDestinations = [
    WorkspaceDestination.home,
    WorkspaceDestination.knowledge,
    WorkspaceDestination.settings,
  ];

  /// How long the Complete Qaza action names itself before collapsing to its
  /// icon.
  static const _fabLabelDuration = Duration(seconds: 5);

  final Set<int> _mounted = {0};

  /// Starts the collapse countdown when the action first appears.
  ///
  /// Keyed on the action becoming visible, not on every build, so scrolling
  /// and unrelated rebuilds never hold the label open.
  void _syncFabLabel({required bool visible}) {
    if (visible == _fabVisible) return;
    _fabVisible = visible;
    _fabCollapseTimer?.cancel();
    if (!visible) return;
    _fabExtended = true;
    _fabCollapseTimer = Timer(_fabLabelDuration, () {
      if (mounted) setState(() => _fabExtended = false);
    });
  }

  void _selectDestination(int value) {
    ref.read(workspaceDestinationProvider.notifier).state =
        _barDestinations[value];
  }

  void _handleBack() {
    ref.read(workspaceDestinationProvider.notifier).state =
        WorkspaceDestination.home;
  }

  Future<void> _openCompleteQaza() => _push(const CompleteQazaScreen());

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

    // Qaza and Calculator are reached from Home, so while one of them is open
    // the bar keeps Home lit rather than showing nothing selected.
    final barIndex = _barDestinations.indexOf(destination);
    final selectedBarIndex = barIndex < 0 ? 0 : barIndex;

    // Nothing pending means nothing to complete, so the action is absent
    // rather than present and inert.
    final pending = ref.watch(progressSummaryProvider).valueOrNull?.overall;
    final showCompleteQaza = _completeQazaDestinations.contains(destination) &&
        (pending?.pending ?? 0) > 0;
    _syncFabLabel(visible: showCompleteQaza);

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
        // The Qaza page's action is adding; Home's is completing.
        floatingActionButton: destination == WorkspaceDestination.qaza
            ? AddActionsFab(
                onAddQaza: () => _push(const AddQazaScreen()),
                onCalculateQaza: () => _push(const CalculatorScreen()),
              )
            : showCompleteQaza
                ? FloatingActionButton.extended(
                    key: const Key('complete_qaza_fab'),
                    onPressed: _openCompleteQaza,
                    // Material animates the label away on its own; the icon
                    // and the button's behaviour are untouched either way.
                    isExtended: _fabExtended,
                    icon: const Icon(Icons.check_circle_outline_rounded),
                    label: Text(l10n.homeCompleteQaza),
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
