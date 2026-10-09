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
}
