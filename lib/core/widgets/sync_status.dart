import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/utils/date_formatters.dart';
import '../../data/sync/sync_state.dart' as sync_models;
import '../../l10n/app_localizations.dart';

class SyncStatusPresentation {
  const SyncStatusPresentation({
    required this.icon,
    required this.label,
    required this.colorRole,
    this.detail,
    this.showRetry = false,
  });

  final IconData icon;
  final String label;
  final SyncStatusColorRole colorRole;
  final String? detail;
  final bool showRetry;
}

enum SyncStatusColorRole { primary, neutral, error }

SyncStatusPresentation syncStatusPresentation(
  sync_models.SyncState state,
  AppLocalizations l10n,
) {
  switch (state.status) {
    // Startup states stay in the user's vocabulary: they describe setting the
    // account up, never the mechanism behind it.
    case sync_models.SyncStatus.bootstrapping:
      return SyncStatusPresentation(
        icon: Icons.cloud_sync_outlined,
        label: l10n.syncSettingUp,
        detail: l10n.syncSettingUpDetail,
        colorRole: SyncStatusColorRole.primary,
      );
    case sync_models.SyncStatus.hydrating:
      return SyncStatusPresentation(
        icon: Icons.cloud_download_outlined,
        label: l10n.syncRestoring,
        detail: l10n.syncRestoringDetail,
        colorRole: SyncStatusColorRole.primary,
      );
    case sync_models.SyncStatus.synced:
      final last = state.lastSyncAt;
      final label = last == null
          ? l10n.syncSynced
          : l10n.syncSyncedAt(
              '${last.day} ${DateFormatters.gregorianMonthName(last.month)}, ${DateFormatters.formatClockTime(last)}');
      return SyncStatusPresentation(
        icon: Icons.cloud_done_outlined,
        label: label,
        colorRole: SyncStatusColorRole.primary,
      );
    case sync_models.SyncStatus.syncing:
      return SyncStatusPresentation(
        icon: Icons.cloud_sync_outlined,
        label: l10n.syncSyncing,
        colorRole: SyncStatusColorRole.primary,
      );
    case sync_models.SyncStatus.offline:
    case sync_models.SyncStatus.pendingSync:
      return SyncStatusPresentation(
        icon: Icons.save_outlined,
        label: l10n.syncSaved,
        detail: l10n.syncSavedDetail,
        colorRole: SyncStatusColorRole.neutral,
      );
    case sync_models.SyncStatus.syncError:
      return SyncStatusPresentation(
        icon: Icons.sync_problem_outlined,
        label: l10n.syncErrorLabel,
        detail: l10n.syncErrorDetail,
        colorRole: SyncStatusColorRole.error,
        showRetry: true,
      );
  }
}

class SyncStatus extends ConsumerWidget {
  const SyncStatus({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offline = ref.watch(offlineRepositoryProvider);
    if (offline == null) return const SizedBox.shrink();

    final state =
        ref.watch(syncStateProvider).valueOrNull ?? offline.currentState;
    final presentation =
        syncStatusPresentation(state, AppLocalizations.of(context));
    final scheme = Theme.of(context).colorScheme;
    final color = switch (presentation.colorRole) {
      SyncStatusColorRole.primary => scheme.primary,
      SyncStatusColorRole.neutral => scheme.onSurfaceVariant,
      SyncStatusColorRole.error => scheme.error,
    };

    return Card(
      key: const Key('sync_status_bar'),
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          children: [
            Icon(presentation.icon, size: 20, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(presentation.label,
                      style: Theme.of(context).textTheme.bodySmall),
                  if (presentation.detail != null)
                    Text(
                      presentation.detail!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
            if (presentation.showRetry)
              TextButton(
                key: const Key('sync_retry_button'),
                onPressed: offline.syncNow,
                child: Text(AppLocalizations.of(context).commonRetry),
              ),
          ],
        ),
      ),
    );
  }
}
