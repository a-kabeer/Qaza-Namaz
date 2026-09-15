import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/sync/sync_state.dart' as sync_models;
import '../../core/utils/date_formatters.dart';

class SyncStatus extends ConsumerWidget {
  const SyncStatus({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offline = ref.watch(offlineRepositoryProvider);
    if (offline == null) return const SizedBox.shrink();
    final state = ref.watch(syncStateProvider).valueOrNull ?? offline.currentState;
    final scheme = Theme.of(context).colorScheme;
    final (icon, color, label, showRetry) = switch (state.status) {
      sync_models.SyncStatus.synced => (Icons.cloud_done_outlined, scheme.primary, _syncedLabel(state), false),
      sync_models.SyncStatus.syncing => (Icons.cloud_sync_outlined, scheme.primary, 'Syncing your ledger…', false),
      sync_models.SyncStatus.offline => (Icons.cloud_off_outlined, scheme.onSurfaceVariant, 'Offline — records are saved on this device and will sync automatically', false),
      sync_models.SyncStatus.pendingSync => (Icons.cloud_upload_outlined, scheme.tertiary, '${state.pendingCount} pending ${state.pendingCount == 1 ? 'change' : 'changes'} to sync', true),
      sync_models.SyncStatus.syncError => (Icons.sync_problem_outlined, scheme.error, state.detail ?? 'Sync problem — your data is safe on this device', true),
    };

    return Card(
      key: const Key('sync_status_bar'),
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 10),
            Expanded(child: Text(label, style: Theme.of(context).textTheme.bodySmall)),
            if (showRetry)
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

  String _syncedLabel(sync_models.SyncState state) {
    final last = state.lastSyncAt;
    if (last == null) return 'All changes saved to the cloud';
    return 'Synced • ${last.day} ${DateFormatters.gregorianMonthName(last.month)}, ${DateFormatters.formatClockTime(last)}';
  }
}
