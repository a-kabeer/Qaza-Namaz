import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/core/widgets/sync_status.dart';
import 'package:qaza_namaz/data/sync/sync_state.dart';

void main() {
  test('maps pending and offline states to user-facing Saved', () {
    for (final status in [SyncStatus.pendingSync, SyncStatus.offline]) {
      final presentation = syncStatusPresentation(
        SyncState(status: status, pendingCount: 2),
      );
      expect(presentation.label, 'Saved');
      expect(presentation.detail, contains('saved on this device'));
      expect(presentation.showRetry, isFalse);
    }
  });

  test('maps syncing to a simple user-facing state', () {
    final presentation = syncStatusPresentation(
      const SyncState(status: SyncStatus.syncing, pendingCount: 1),
    );
    expect(presentation.label, 'Syncing');
    expect(presentation.detail, isNull);
    expect(presentation.showRetry, isFalse);
  });

  test('maps synced without exposing backend details', () {
    final presentation = syncStatusPresentation(
      SyncState(
        status: SyncStatus.synced,
        lastSyncAt: DateTime(2026, 9, 16, 12, 5),
      ),
    );
    expect(presentation.label, contains('Synced'));
    expect(presentation.detail, isNull);
    expect(presentation.showRetry, isFalse);
  });

  test('maps sync failures to generic Sync Error and hides technical detail', () {
    final presentation = syncStatusPresentation(
      const SyncState(
        status: SyncStatus.syncError,
        detail: 'FirebaseException: permission-denied at /users/test-user',
      ),
    );
    expect(presentation.label, 'Sync Error');
    expect(presentation.detail, 'Your changes are saved on this device. We will retry automatically.');
    expect(presentation.detail, isNot(contains('FirebaseException')));
    expect(presentation.showRetry, isTrue);
  });
}
