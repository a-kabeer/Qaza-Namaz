import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// The workspace's add action: a plus that opens into Add Qaza and Calculate
/// Qaza, and a cross that closes again.
///
/// The plus rotates an eighth of a turn to become the cross, which is the
/// Material idiom for this control and gives the open and close states one
/// continuous animation rather than two icons swapping.
class AddActionsFab extends StatefulWidget {
  const AddActionsFab({
    super.key,
    required this.onAddQaza,
    required this.onCalculateQaza,
  });

  final VoidCallback onAddQaza;
  final VoidCallback onCalculateQaza;

  static const Duration _duration = Duration(milliseconds: 200);

  @override
  State<AddActionsFab> createState() => _AddActionsFabState();
}

class _AddActionsFabState extends State<AddActionsFab> {
  bool _open = false;

  void _toggle() => setState(() => _open = !_open);

  /// Runs an action and closes the menu, so returning to the workspace never
  /// finds it still open.
  void _run(VoidCallback action) {
    setState(() => _open = false);
    action();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // The actions take no space at all while closed, so the plus keeps
        // its usual position.
        AnimatedSize(
          duration: AddActionsFab._duration,
          curve: Curves.easeOutCubic,
          alignment: Alignment.bottomCenter,
          child: AnimatedOpacity(
            duration: AddActionsFab._duration,
            opacity: _open ? 1 : 0,
            child: _open
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _MenuAction(
                        actionKey: const Key('fab_action_add_qaza'),
                        icon: Icons.playlist_add_rounded,
                        label: l10n.qazaAddTooltip,
                        onPressed: () => _run(widget.onAddQaza),
                      ),
                      const SizedBox(height: 12),
                      _MenuAction(
                        actionKey: const Key('fab_action_calculate_qaza'),
                        icon: Icons.calculate_outlined,
                        label: l10n.homeCalculateQaza,
                        onPressed: () => _run(widget.onCalculateQaza),
                      ),
                      const SizedBox(height: 12),
                    ],
                  )
                : const SizedBox(width: 0, height: 0),
          ),
        ),
        FloatingActionButton(
          key: const Key('add_actions_fab'),
          heroTag: null,
          tooltip: _open ? l10n.commonClose : l10n.qazaAddTooltip,
          onPressed: _toggle,
          child: AnimatedRotation(
            duration: AddActionsFab._duration,
            curve: Curves.easeOutCubic,
            // An eighth of a turn takes the plus exactly onto the cross.
            turns: _open ? 0.125 : 0,
            child: const Icon(Icons.add_rounded),
          ),
        ),
      ],
    );
  }
}

class _MenuAction extends StatelessWidget {
  const _MenuAction({
    required this.actionKey,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final Key actionKey;
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FloatingActionButton.extended(
      key: actionKey,
      heroTag: null,
      onPressed: onPressed,
      backgroundColor: scheme.secondaryContainer,
      foregroundColor: scheme.onSecondaryContainer,
      icon: Icon(icon),
      label: Text(label),
    );
  }
}
