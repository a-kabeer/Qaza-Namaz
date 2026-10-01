import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../l10n/app_localizations.dart';
import 'qaza_import_controller.dart';

/// Presents the shared progress state for long-running Qaza imports.
///
/// The caller owns what should happen after the import reaches a terminal state.
class QazaImportProgressDialog extends ConsumerStatefulWidget {
  const QazaImportProgressDialog({super.key});

  @override
  ConsumerState<QazaImportProgressDialog> createState() =>
      _QazaImportProgressDialogState();
}

class _QazaImportProgressDialogState
    extends ConsumerState<QazaImportProgressDialog> {
  ProviderSubscription<QazaImportTaskState>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = ref.listenManual<QazaImportTaskState>(
      qazaImportProvider,
      (_, next) {
        if (next.phase == QazaImportTaskPhase.failed) return;
        if (next.isActive) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.of(context).pop();
        });
      },
    );

    final current = ref.read(qazaImportProvider);
    if (current.phase != QazaImportTaskPhase.failed && !current.isActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
    }
  }

  @override
  void dispose() {
    _subscription?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(qazaImportProvider);

    if (state.phase == QazaImportTaskPhase.failed) {
      return PopScope(
        canPop: false,
        child: AlertDialog(
          title: Text(l10n.stateErrorTitle),
          content: Text(
            l10n.qazaReviewError,
            textAlign: TextAlign.center,
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () =>
                    ref.read(qazaImportProvider.notifier).retry(),
                child: Text(l10n.commonRetry),
              ),
            ),
          ],
        ),
      );
    }

    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: Text(l10n.addQazaInProgress),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (state.phase == QazaImportTaskPhase.preparing) ...[
              Text(
                l10n.addQazaChecking,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ] else if (state.phase == QazaImportTaskPhase.importing) ...[
              if (state.progress == null) ...[
                Text(
                  l10n.addQazaChecking,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 12),
                const LinearProgressIndicator(),
                const SizedBox(height: 12),
                Text('${state.processed} / ${state.total}'),
              ] else ...[
                Semantics(
                  label: l10n.addQazaInProgress,
                  value: '${(state.progress! * 100).round()}%',
                  child: Text(
                    '${(state.progress! * 100).round()}%',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(value: state.progress),
                const SizedBox(height: 12),
                Text('${state.processed} / ${state.total}'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _ImportStat(
                        label: l10n.qazaImportAdded,
                        value: state.added,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _ImportStat(
                        label: l10n.qazaImportSkipped,
                        value: state.skipped,
                      ),
                    ),
                  ],
                ),
              ],
            ] else ...[
              const LinearProgressIndicator(),
            ],
          ],
        ),
      ),
    );
  }
}

class _ImportStat extends StatelessWidget {
  const _ImportStat({
    required this.label,
    required this.value,
  });

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          value.toString(),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}