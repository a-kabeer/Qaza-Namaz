import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/utils/date_formatters.dart';
import '../../data/sync/sync_state.dart' as sync_models;

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

SyncStatusPresentation syncStatusPresentation(sync_models.SyncState state) {
  switch (state.status) {
    case sync_models.SyncStatus.synced:
      final last = state.lastSyncAt;
      final label = last == null
          ? 'Synced'
          : 'Synced • ${last.day} ${DateFormatters.gregorianMonthName(last.month)}, ${DateFormatters.formatClockTime(last)}';
      return SyncStatusPresentation(
        icon: Icons.cloud_done_outlined,
        label: label,
        colorRole: SyncStatusColorRole.primary,
      );
    case sync_models.SyncStatus.syncing:
      return const SyncStatusPresentation(
        icon: Icons.cloud_sync_outlined,
        label: 'Syncing',
        colorRole: SyncStatusColorRole.primary,
      );
    case sync_models.SyncStatus.offline:
    case sync_models.SyncStatus.pendingSync:
      return const SyncStatusPresentation(
        icon: Icons.save_outlined,
        label: 'Saved',
        detail: 'Your changes are saved on this device and will sync automatically.',
        colorRole: SyncStatusColorRole.neutral,
      );
    case sync_models.SyncStatus.syncError:
      return const SyncStatusPresentation(
        icon: Icons.sync_problem_outlined,
        label: 'Sync Error',
        detail: 'Your changes are saved on this device. We will retry automatically.',
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

    final state = ref.watch(syncStateProvider).valueOrNull ?? offline.currentState;
    final presentation = syncStatusPresentation(state);
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
                  Text(presentation.label, style: Theme.of(context).textTheme.bodySmall),
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
                child: const Text('Retry'),
              ),
          ],
        ),
      ),
    );
  }
}
