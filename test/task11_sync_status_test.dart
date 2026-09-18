import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/core/widgets/sync_status.dart';
import 'package:qaza_namaz/data/sync/sync_state.dart' as sync_models;
import 'package:qaza_namaz/l10n/app_localizations_en.dart';

void main() {
  final l10n = AppLocalizationsEn();

  test('maps pending and offline states to user-facing Saved', () {
    for (final status in [
      sync_models.SyncStatus.pendingSync,
      sync_models.SyncStatus.offline
    ]) {
      final presentation = syncStatusPresentation(
        sync_models.SyncState(status: status, pendingCount: 2),
        l10n,
      );
      expect(presentation.label, 'Saved');
      expect(presentation.detail, contains('saved on this device'));
      expect(presentation.showRetry, isFalse);
    }
  });

  test('maps syncing to a simple user-facing state', () {
    final presentation = syncStatusPresentation(
      const sync_models.SyncState(
          status: sync_models.SyncStatus.syncing, pendingCount: 1),
      l10n,
    );
    expect(presentation.label, 'Syncing');
    expect(presentation.detail, isNull);
    expect(presentation.showRetry, isFalse);
  });

  test('maps synced without exposing backend details', () {
    final presentation = syncStatusPresentation(
      sync_models.SyncState(
        status: sync_models.SyncStatus.synced,
        lastSyncAt: DateTime(2026, 9, 16, 12, 5),
      ),
      l10n,
    );
    expect(presentation.label, contains('Synced'));
    expect(presentation.detail, isNull);
    expect(presentation.showRetry, isFalse);
  });

  test('maps sync failures to generic Sync Error and hides technical detail',
      () {
    final presentation = syncStatusPresentation(
      const sync_models.SyncState(
        status: sync_models.SyncStatus.syncError,
        detail: 'FirebaseException: permission-denied at /users/test-user',
      ),
      l10n,
    );
    expect(presentation.label, 'Sync Error');
    expect(presentation.detail,
        'Your changes are saved on this device. We will retry automatically.');
    expect(presentation.detail, isNot(contains('FirebaseException')));
    expect(presentation.showRetry, isTrue);
  });
}
