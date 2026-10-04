import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qaza_namaz/data/local/account_local_store.dart';
import 'package:qaza_namaz/data/local/database/app_database.dart';

void main() {
  late AppDatabase database;
  late AccountLocalStore store;
  late String googleAccountId;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    database = AppDatabase(NativeDatabase.memory());
    store = AccountLocalStore(database: database);
    await store.ensureInitialized(
      hasLegacyProfile: false,
      hasLegacyQaza: false,
    );
    googleAccountId = await store.createGooglePartition(
      firebaseUid: 'outbox-user',
      email: 'outbox@example.com',
    );
    await store.activate(googleAccountId);
    await store.enqueueSnapshot(googleAccountId);
  });

  tearDown(() => database.close());

  test('outbox lease is owned by one worker and late worker cannot remove it', () async {
    final rows = await store.loadModernOutboxBatch(
      localAccountId: googleAccountId,
      nowMicros: DateTime.now().microsecondsSinceEpoch,
      limit: 10,
    );

    expect(rows, isNotEmpty);
    final operationId = rows.single['id']! as String;

    final claimed = await store.claimOutbox(
      localAccountId: googleAccountId,
      operationId: operationId,
      workerId: 'worker-a',
      leaseUntilMicros:
          DateTime.now().add(const Duration(minutes: 5)).microsecondsSinceEpoch,
    );
    expect(claimed, isTrue);

    final secondClaim = await store.claimOutbox(
      localAccountId: googleAccountId,
      operationId: operationId,
      workerId: 'worker-b',
      leaseUntilMicros:
          DateTime.now().add(const Duration(minutes: 5)).microsecondsSinceEpoch,
    );
    expect(secondClaim, isFalse);

    await store.removeOutboxOperation(
      localAccountId: googleAccountId,
      operationId: operationId,
      workerId: 'worker-b',
    );
    final stillQueued = await store.loadModernOutboxBatch(
      localAccountId: googleAccountId,
      nowMicros: DateTime.now().microsecondsSinceEpoch,
      limit: 10,
    );
    expect(stillQueued.map((row) => row['id']), contains(operationId));

    await store.removeOutboxOperation(
      localAccountId: googleAccountId,
      operationId: operationId,
      workerId: 'worker-a',
    );
    final removed = await store.loadModernOutboxBatch(
      localAccountId: googleAccountId,
      nowMicros: DateTime.now().microsecondsSinceEpoch,
      limit: 10,
    );
    expect(removed.map((row) => row['id']), isNot(contains(operationId)));
  });
}
