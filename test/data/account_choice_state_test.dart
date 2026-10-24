import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qaza_namaz/data/local/database/app_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('local account-choice completion is durable database metadata', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    expect(await database.isAccountChoiceComplete(), isFalse);
    await database.markAccountChoiceComplete();
    expect(await database.isAccountChoiceComplete(), isTrue);
  });

  test('returning account choice and Guest prompt markers are durable',
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

  test('local recovery snapshot can be saved, read, and cleared', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    const snapshot = '{"metadata":{"app_id":"qaza_namaz_app"},"data":{}}';

    expect(await database.readLocalRecoverySnapshot(), isNull);
    await database.saveLocalRecoverySnapshot(snapshot);

    expect(await database.readLocalRecoverySnapshot(), snapshot);
    expect(await database.hasLocalRecoverySnapshot(), isTrue);

    await database.clearLocalRecoverySnapshot();
    expect(await database.readLocalRecoverySnapshot(), isNull);
    expect(await database.hasLocalRecoverySnapshot(), isFalse);
  });
}
