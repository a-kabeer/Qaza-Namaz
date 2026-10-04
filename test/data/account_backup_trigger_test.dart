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
}
