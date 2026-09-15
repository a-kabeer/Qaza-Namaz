import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/sync/sync_state.dart';
import '../../core/utils/date_formatters.dart';

class SyncStatusBar extends ConsumerWidget {
  const SyncStatusBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offline = ref.watch(offlineRepositoryProvider);
    if (offline == null) return const SizedBox.shrink();
    final state = ref.watch(syncStateProvider).valueOrNull ?? offline.currentState;
    return _SyncBarView(state: state, onRetry: offline.syncNow);
  }
}

class _SyncBarView extends StatelessWidget {
  const _SyncBarView({required this.state, required this.onRetry});

  final SyncState state;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (icon, color, label, showRetry) = switch (state.status) {
      SyncStatus.synced => (Icons.cloud_done_outlined, scheme.primary, _syncedLabel(), false),
      SyncStatus.syncing => (Icons.cloud_sync_outlined, scheme.primary, 'Syncing your ledger…', false),
      SyncStatus.offline => (Icons.cloud_off_outlined, scheme.onSurfaceVariant, 'Offline — records are saved on this device and will sync automatically', false),
      SyncStatus.pendingSync => (Icons.cloud_upload_outlined, scheme.tertiary, '${state.pendingCount} pending ${state.pendingCount == 1 ? 'change' : 'changes'} to sync', true),
      SyncStatus.syncError => (Icons.sync_problem_outlined, scheme.error, state.detail ?? 'Sync problem — your data is safe on this device', true),
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
                onPressed: () => onRetry(),
                child: const Text('Retry'),
              ),
          ],
        ),
      ),
    );
  }

  String _syncedLabel() {
    final last = state.lastSyncAt;
    if (last == null) return 'All changes saved to the cloud';
    return 'Synced • ${last.day} ${DateFormatters.gregorianMonthName(last.month)}, ${DateFormatters.formatClockTime(last)}';
  }
}
