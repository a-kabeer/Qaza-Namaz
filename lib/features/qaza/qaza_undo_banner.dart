import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/constants/prayer_types.dart';
import '../../core/widgets/app_card.dart';
import '../../domain/services/qaza_undo_service.dart';
import '../../l10n/app_localizations.dart';

/// Persists and surfaces the currently active completion undo window.
class QazaUndoBanner extends ConsumerStatefulWidget {
  const QazaUndoBanner({
    super.key,
    this.onUndone,
  });

  final Future<void> Function()? onUndone;

  @override
  ConsumerState<QazaUndoBanner> createState() => _QazaUndoBannerState();
}

class _QazaUndoBannerState extends ConsumerState<QazaUndoBanner> {
  Future<QazaUndoBatch?>? _restoreFuture;
  String? _loadedUserId;

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(activeUserIdProvider);
    if (userId != _loadedUserId) {
      _loadedUserId = userId;
      _restoreFuture = userId == null
          ? Future<QazaUndoBatch?>.value(null)
          : ref.read(qazaUndoManagerProvider).restore(userId: userId);
    }

    final future = _restoreFuture;
    if (future == null) return const SizedBox.shrink();

    return FutureBuilder<QazaUndoBatch?>(
      future: future,
      builder: (context, snapshot) {
        final batch = snapshot.data;
        if (!snapshot.hasData || batch == null) {
          return const SizedBox.shrink();
        }

        final count = batch.recordIds.length;
        final l10n = AppLocalizations.of(context);
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: AppCard(
            key: const Key('qaza_undo_banner'),
            padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 8, 10),
            child: Row(
              children: [
                Icon(
                  Icons.undo_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.qazaUndoAvailable(count),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                TextButton(
                  key: const Key('qaza_undo_banner_action'),
                  onPressed: () => _undo(
                    userId,
                    expectedBatch: batch,
                  ),
                  child: Text(l10n.qazaUndoAction),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _undo(
    String? userId, {
    QazaUndoBatch? expectedBatch,
  }) async {
    if (userId == null) return;

    final messenger = ScaffoldMessenger.maybeOf(context);
    final l10n = AppLocalizations.of(context);
    final count = await ref.read(qazaUndoManagerProvider).undo(
          userId: userId,
          service: ref.read(qazaServiceProvider),
          expectedBatch: expectedBatch,
        );
    if (!mounted) return;

    if (count > 0) {
      ref.invalidate(progressSummaryProvider);
      for (final prayer in PrayerType.values) {
        ref.invalidate(oldestPendingProvider(prayer));
      }
      await widget.onUndone?.call();
      if (!mounted) return;
      setState(() {
        _loadedUserId = userId;
        _restoreFuture = Future<QazaUndoBatch?>.value(null);
      });
      messenger
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(l10n.qazaUndoCount(count))),
        );
    }
  }
}

Future<void> showQazaUndoSnackBar({
  required BuildContext context,
  required WidgetRef ref,
  required String userId,
  required Iterable<String> recordIds,
  required DateTime completedAt,
  Future<void> Function()? onUndone,
}) async {
  final batch = await ref.read(qazaUndoManagerProvider).register(
        userId: userId,
        recordIds: recordIds,
        completedAt: completedAt,
      );
  if (batch == null || !context.mounted) return;

  final l10n = AppLocalizations.of(context);
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        duration: QazaUndoStore.window,
        content: Text(l10n.qazaUndoAvailable(batch.recordIds.length)),
        action: SnackBarAction(
          label: l10n.qazaUndoAction,
          onPressed: () {
            unawaited(
              _undoFromSnack(
                context: context,
                ref: ref,
                userId: userId,
                batch: batch,
                onUndone: onUndone,
              ),
            );
          },
        ),
      ),
    );
}

Future<void> _undoFromSnack({
  required BuildContext context,
  required WidgetRef ref,
  required String userId,
  required QazaUndoBatch batch,
  Future<void> Function()? onUndone,
}) async {
  final count = await ref.read(qazaUndoManagerProvider).undo(
        userId: userId,
        service: ref.read(qazaServiceProvider),
        expectedBatch: batch,
      );
  if (!context.mounted || count == 0) return;

  ref.invalidate(progressSummaryProvider);
  for (final prayer in PrayerType.values) {
    ref.invalidate(oldestPendingProvider(prayer));
  }
  await onUndone?.call();
  if (!context.mounted) return;

  final l10n = AppLocalizations.of(context);
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(l10n.qazaUndoCount(count))),
    );
}
