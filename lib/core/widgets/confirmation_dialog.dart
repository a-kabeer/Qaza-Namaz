import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

Future<bool> showConfirmationDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = false,
}) async {
  final scheme = Theme.of(context).colorScheme;
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(AppLocalizations.of(context).commonCancel),
        ),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(
                  backgroundColor: scheme.error,
                  foregroundColor: scheme.onError,
                )
              : null,
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

Future<bool> confirmDestructive(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
}) =>
    showConfirmationDialog(
      context,
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      destructive: true,
    );

/// Destructive confirmation that a single stray tap cannot complete.
///
/// The confirm button stays disabled until [acknowledgeLabel] is ticked, so
/// destroying data takes two deliberate gestures on two different parts of the
/// dialog rather than one tap that happens to land on a button.
Future<bool> confirmDestructiveWithAcknowledgement(
  BuildContext context, {
  required String title,
  required String message,
  required String acknowledgeLabel,
  required String confirmLabel,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => _AcknowledgedDestructiveDialog(
      title: title,
      message: message,
      acknowledgeLabel: acknowledgeLabel,
      confirmLabel: confirmLabel,
    ),
  );
  return result ?? false;
}

class _AcknowledgedDestructiveDialog extends StatefulWidget {
  const _AcknowledgedDestructiveDialog({
    required this.title,
    required this.message,
    required this.acknowledgeLabel,
    required this.confirmLabel,
  });

  final String title;
  final String message;
  final String acknowledgeLabel;
  final String confirmLabel;

  @override
  State<_AcknowledgedDestructiveDialog> createState() =>
      _AcknowledgedDestructiveDialogState();
}

class _AcknowledgedDestructiveDialogState
    extends State<_AcknowledgedDestructiveDialog> {
  bool _acknowledged = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.message),
            const SizedBox(height: 16),
            CheckboxListTile(
              key: const Key('destructive_acknowledge'),
              value: _acknowledged,
              onChanged: (value) =>
                  setState(() => _acknowledged = value ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              title: Text(widget.acknowledgeLabel,
                  style: Theme.of(context).textTheme.bodyMedium),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          key: const Key('destructive_confirm'),
          style: FilledButton.styleFrom(
            backgroundColor: scheme.error,
            foregroundColor: scheme.onError,
          ),
          onPressed: _acknowledged ? () => Navigator.pop(context, true) : null,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
