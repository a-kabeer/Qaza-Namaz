import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qaza_namaz/data/local/database/app_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('cloud setup choice is durable in local database metadata', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    expect(await database.isCloudSetupChoiceComplete(), isFalse);

    await database.markCloudSetupChoiceComplete();

    expect(await database.isCloudSetupChoiceComplete(), isTrue);
  });

  test('returning account choice and guest prompt markers are durable',
      () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    expect(await database.hasReturningAccountChoicePending(), isFalse);
    await database.markReturningAccountChoicePending();
    expect(await database.hasReturningAccountChoicePending(), isTrue);
    await database.clearReturningAccountChoicePending();
    expect(await database.hasReturningAccountChoicePending(), isFalse);

    expect(await database.hasShownGuestGooglePrompt(), isFalse);
    await database.markGuestGooglePromptShown();
    expect(await database.hasShownGuestGooglePrompt(), isTrue);
  });

  test('recovery snapshot can be saved, read, and cleared', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    const backup = '{"metadata":{"app_id":"qaza_namaz_app"},"data":{}}';

    expect(await database.readLocalRecoverySnapshot(), isNull);

    await database.saveLocalRecoverySnapshot(backup);

    expect(await database.readLocalRecoverySnapshot(), backup);
    expect(await database.hasLocalRecoverySnapshot(), isTrue);

    await database.clearLocalRecoverySnapshot();

    expect(await database.readLocalRecoverySnapshot(), isNull);
    expect(await database.hasLocalRecoverySnapshot(), isFalse);
  });
  test('fresh-install restore gate allows only an empty uncompleted database',
      () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    expect(await database.isFreshInstallationForCloudRestore(), isTrue);
    expect(
      await database.isFreshInstallationForCloudRestore(
        localAccountId: 'google:account-A',
      ),
      isTrue,
    );

    await database.customStatement(
      '''INSERT INTO account_profiles
         (local_account_id, payload_json, updated_at, writer_device_id, operation_id)
         VALUES ('guest', '{}', 1, 'device-test', 'operation-test')''',
    );
    expect(await database.isFreshInstallationForCloudRestore(), isFalse);
    expect(
      await database.isFreshInstallationForCloudRestore(
        localAccountId: 'google:account-A',
      ),
      isTrue,
    );

    await database.customInsert(
      '''INSERT INTO daily_salah_logs
         (user_id, prayer_date, prayer_type, status, updated_at)
         VALUES (?, ?, ?, ?, ?)''',
      variables: [
        Variable.withString('google:account-A'),
        Variable.withString('2025-01-01'),
        Variable.withString('fajr'),
        Variable.withString('missed'),
        Variable.withString('2025-01-01'),
      ],
    );
    expect(
      await database.isFreshInstallationForCloudRestore(
        localAccountId: 'google:account-A',
      ),
      isFalse,
    );
  });

  test('initial cloud backup pending marker survives reads and can be cleared',
      () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    expect(await database.hasPendingInitialCloudBackup(), isFalse);
    await database.markInitialCloudBackupPending();
    expect(await database.hasPendingInitialCloudBackup(), isTrue);

    await database.clearPendingInitialCloudBackup();
    expect(await database.hasPendingInitialCloudBackup(), isFalse);
  });
}
