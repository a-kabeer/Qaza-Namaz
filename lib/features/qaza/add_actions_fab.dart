import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// The workspace Add Qaza action.
///
/// The action starts expanded as "Add Qaza +" to make the primary affordance
/// obvious, then contracts to a compact "+" FAB after a short delay. There is
/// intentionally no secondary FAB action.
class AddQazaFab extends StatefulWidget {
  const AddQazaFab({
    super.key,
    required this.onAddQaza,
  });

  final VoidCallback onAddQaza;

  static const Duration collapseDelay = Duration(seconds: 4);
  static const Duration animationDuration = Duration(milliseconds: 220);

  @override
  State<AddQazaFab> createState() => _AddQazaFabState();
}

class _AddQazaFabState extends State<AddQazaFab> {
  Timer? _collapseTimer;
  bool _expanded = true;

  @override
  void initState() {
    super.initState();
    _collapseTimer = Timer(AddQazaFab.collapseDelay, () {
      if (!mounted) return;
      setState(() => _expanded = false);
    });
  }

  @override
  void dispose() {
    _collapseTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AnimatedSwitcher(
      duration: AddQazaFab.animationDuration,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1).animate(animation),
          child: child,
        ),
      ),
      child: _expanded
          ? FloatingActionButton.extended(
              key: const Key('add_qaza_fab_expanded'),
              heroTag: null,
              tooltip: l10n.qazaAddTooltip,
              onPressed: widget.onAddQaza,
              label: Text('${l10n.qazaAddTooltip} +'),
            )
          : FloatingActionButton(
              key: const Key('add_qaza_fab_collapsed'),
              heroTag: null,
              tooltip: l10n.qazaAddTooltip,
              onPressed: widget.onAddQaza,
              child: const Icon(Icons.add_rounded),
            ),
    );
  }
}
