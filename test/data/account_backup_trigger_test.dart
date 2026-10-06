import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/data/local/database/app_database.dart';

void main() {
  test('Deletion action metadata versions increment on lifecycle changes',
      () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    await database.customInsert(
      '''INSERT INTO local_accounts
         (local_account_id, account_mode, firebase_uid, google_email,
          lifecycle_state, cloud_backup_enabled, cloud_generation,
          created_at, updated_at)
         VALUES (?, 'google', ?, ?, 'active', 1, 1, ?, ?)''',
      variables: [
        Variable('google-1'),
        Variable('uid-1'),
        Variable('user@example.com'),
        Variable(DateTime(2026, 1, 1).microsecondsSinceEpoch),
        Variable(DateTime(2026, 1, 1).microsecondsSinceEpoch),
      ],
    );
    await database.customInsert(
      '''INSERT INTO device_metadata (id, device_instance_id)
         VALUES (1, ?)''',
      variables: [Variable('device-1')],
    );

    await database.customInsert(
      '''INSERT INTO qaza_deletion_actions
         (id, user_id, addition_id, created_at, resolved_at)
         VALUES (?, ?, ?, ?, NULL)''',
      variables: [
        Variable('action-1'),
        Variable('google-1'),
        Variable('addition-1'),
        Variable('2026-01-01T00:00:00.000Z'),
      ],
    );

    final inserted = await database.customSelect(
      '''SELECT entity_version FROM entity_metadata
         WHERE local_account_id = ? AND entity_type = 'deletionAction'
           AND entity_id = ?''',
      variables: [Variable('google-1'), Variable('action-1')],
    ).get();
    expect(inserted.single.read<int>('entity_version'), 1);

    await database.customUpdate(
      '''UPDATE qaza_deletion_actions
         SET resolved_at = ?, entity_version = entity_version + 1
         WHERE user_id = ? AND id = ?''',
      variables: [
        Variable('2026-01-02T00:00:00.000Z'),
        Variable('google-1'),
        Variable('action-1'),
      ],
    );

    final updated = await database.customSelect(
      '''SELECT entity_version FROM entity_metadata
         WHERE local_account_id = ? AND entity_type = 'deletionAction'
           AND entity_id = ?''',
      variables: [Variable('google-1'), Variable('action-1')],
    ).get();
    expect(updated.single.read<int>('entity_version'), 2);
  });

  test('account backup revision advances with Google data changes', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    await database.customInsert(
      '''INSERT INTO local_accounts
         (local_account_id, account_mode, firebase_uid, google_email,
          lifecycle_state, cloud_backup_enabled, cloud_generation,
          created_at, updated_at)
         VALUES (?, 'google', ?, ?, 'active', 1, 1, ?, ?)''',
      variables: [
        Variable('google-revision'),
        Variable('uid-revision'),
        Variable('revision@example.com'),
        Variable(DateTime(2026, 1, 1).microsecondsSinceEpoch),
        Variable(DateTime(2026, 1, 1).microsecondsSinceEpoch),
      ],
    );

    await database.customInsert(
      '''INSERT INTO account_backup_state
         (local_account_id, current_dataset_revision,
          acknowledged_dataset_revision, acknowledged_cloud_generation,
          state)
         VALUES (?, 0, 0, 1, 'pending')''',
      variables: [Variable('google-revision')],
    );

    final initial = await database.customSelect(
      '''SELECT current_dataset_revision, acknowledged_dataset_revision
         FROM account_backup_state
         WHERE local_account_id = ?''',
      variables: [Variable('google-revision')],
    ).get();
    expect(initial.single.read<int>('current_dataset_revision'), 0);
    expect(initial.single.read<int>('acknowledged_dataset_revision'), 0);

    await database.customInsert(
      '''INSERT INTO qaza_records
         (id, user_id, prayer_type, original_date, status,
          completion_id, addition_id, record_version, created_at, updated_at)
         VALUES (?, ?, ?, ?, 'pending', NULL, NULL, 1, ?, ?)''',
      variables: [
        Variable('revision-record'),
        Variable('google-revision'),
        Variable('fajr'),
        Variable(20260101),
        Variable(DateTime(2026, 1, 1).microsecondsSinceEpoch),
        Variable(DateTime(2026, 1, 1).microsecondsSinceEpoch),
      ],
    );

    final changed = await database.customSelect(
      '''SELECT current_dataset_revision
         FROM account_backup_state
         WHERE local_account_id = ?''',
      variables: [Variable('google-revision')],
    ).get();
    expect(changed.single.read<int>('current_dataset_revision'), greaterThan(0));

    final acknowledged = await database.customUpdate(
      '''UPDATE account_backup_state
         SET acknowledged_dataset_revision = current_dataset_revision,
             acknowledged_cloud_generation = 1,
             state = 'idle'
         WHERE local_account_id = ?''',
      variables: [Variable('google-revision')],
    );
    expect(acknowledged, 1);

    await database.customUpdate(
      '''UPDATE qaza_records
         SET status = 'completed', completed_at = ?, record_version = 2,
             updated_at = ?
         WHERE id = ? AND user_id = ?''',
      variables: [
        Variable(DateTime(2026, 1, 2).microsecondsSinceEpoch),
        Variable(DateTime(2026, 1, 2).microsecondsSinceEpoch),
        Variable('revision-record'),
        Variable('google-revision'),
      ],
    );

    final newer = await database.customSelect(
      '''SELECT current_dataset_revision, acknowledged_dataset_revision
         FROM account_backup_state
         WHERE local_account_id = ?''',
      variables: [Variable('google-revision')],
    ).get();
    expect(
      newer.single.read<int>('current_dataset_revision'),
      greaterThan(newer.single.read<int>('acknowledged_dataset_revision')),
    );
  });
}
