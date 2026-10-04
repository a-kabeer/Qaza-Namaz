import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/data/local/account_local_store.dart';
import 'package:qaza_namaz/data/local/database/app_database.dart';
import 'package:qaza_namaz/domain/entities/user_profile.dart';

void main() {
  late AppDatabase database;
  late AccountLocalStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    database = AppDatabase(NativeDatabase.memory());
    store = AccountLocalStore(database: database);
    await store.ensureInitialized(
      hasLegacyProfile: false,
      hasLegacyQaza: true,
    );
  });

  tearDown(() async {
    await database.close();
  });

  test('Guest to Google reuses the same partition and preserves Qaza IDs',
      () async {
    await database.qazaRecordsDao.insertRecord(
      QazaRecordsCompanion.insert(
        id: 'record-stable-1',
        userId: UserProfile.localLedgerUserId,
        prayerType: PrayerType.fajr.name,
        originalDate: DateTime(2026, 1, 1),
        status: 'pending',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ),
    );

    final targetId = await store.cloneGuestToGoogle(
      firebaseUid: 'firebase-user-1',
      email: 'user@example.com',
    );

    expect(targetId, UserProfile.localLedgerUserId);
    final account = await store.getAccount(UserProfile.localLedgerUserId);
    expect(account?.isGoogle, isTrue);
    expect(account?.firebaseUid, 'firebase-user-1');

    final rows =
        await database.qazaRecordsDao.getAll(userId: UserProfile.localLedgerUserId);
    expect(rows.single.id, 'record-stable-1');

    final state = await database.customSelect(
      'SELECT active_local_account_id FROM app_session_state WHERE id = 1',
    ).get();
    expect(
      state.single.read<String>('active_local_account_id'),
      UserProfile.localLedgerUserId,
    );
  });

  test('failed in-place migration rolls the account back to Guest', () async {
    await database.qazaRecordsDao.insertRecord(
      QazaRecordsCompanion.insert(
        id: 'record-stable-2',
        userId: UserProfile.localLedgerUserId,
        prayerType: PrayerType.isha.name,
        originalDate: DateTime(2026, 2, 1),
        status: 'pending',
        createdAt: DateTime(2026, 2, 1),
        updatedAt: DateTime(2026, 2, 1),
      ),
    );

    await store.cloneGuestToGoogle(
      firebaseUid: 'firebase-user-2',
      email: 'user2@example.com',
    );
    await store.rollbackGoogleMigration(UserProfile.localLedgerUserId);

    final account = await store.getAccount(UserProfile.localLedgerUserId);
    expect(account?.isGuest, isTrue);
    expect(account?.firebaseUid, isNull);

    final rows =
        await database.qazaRecordsDao.getAll(userId: UserProfile.localLedgerUserId);
    expect(rows.single.id, 'record-stable-2');
  });

  test('an existing Google partition with local data is never overwritten',
      () async {
    final googleId = await store.createGooglePartition(
      firebaseUid: 'firebase-user-3',
      email: 'user3@example.com',
    );
    await database.customInsert(
      '''INSERT INTO account_profiles
         (local_account_id, payload_json, entity_version, updated_at,
          writer_device_id, operation_id)
         VALUES (?, ?, 1, ?, ?, ?)''',
      variables: [
        Variable(googleId),
        Variable('{}'),
        Variable(DateTime(2026, 1, 1).microsecondsSinceEpoch),
        Variable('device'),
        Variable('operation'),
      ],
    );

    await expectLater(
      store.cloneGuestToGoogle(
        firebaseUid: 'firebase-user-3',
        email: 'user3@example.com',
      ),
      throwsStateError,
    );

    final guest = await store.getAccount(UserProfile.localLedgerUserId);
    final google = await store.getAccount(googleId);
    expect(guest?.isGuest, isTrue);
    expect(google?.isGoogle, isTrue);
  });
}
