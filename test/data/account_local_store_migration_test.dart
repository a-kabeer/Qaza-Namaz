import 'package:drift/drift.dart' show Variable;
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

  test(
    'existing Google migration snapshot restores target partition after failure',
    () async {
      await store.ensureGuestActive();
      final googleId = await store.createGooglePartition(
        firebaseUid: 'firebase-snapshot-user',
        email: 'snapshot@example.com',
      );
      await database.qazaRecordsDao.insertRecord(
        QazaRecordsCompanion.insert(
          id: 'google-before-migration',
          userId: googleId,
          prayerType: PrayerType.fajr.name,
          originalDate: DateTime(2026, 2, 2),
          status: 'pending',
          createdAt: DateTime(2026, 2, 2),
          updatedAt: DateTime(2026, 2, 2),
        ),
      );

      await store.createMigrationSnapshot(googleId);
      await database.qazaRecordsDao.deleteById(
        userId: googleId,
        id: 'google-before-migration',
      );

      await store.rollbackGoogleMigration(UserProfile.localLedgerUserId);

      final restored = await database.qazaRecordsDao.getAll(userId: googleId);
      expect(restored.single.id, 'google-before-migration');
      final snapshotId = await store.migrationSnapshotId();
      expect(snapshotId, isNull);
      final active = await store.activeAccount();
      expect(active?.isGuest, isTrue);
    },
  );

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

  test(
    'Sign Out after Guest to Google creates an independent Guest partition',
    () async {
      await database.qazaRecordsDao.insertRecord(
        QazaRecordsCompanion.insert(
          id: 'record-stable-signout',
          userId: UserProfile.localLedgerUserId,
          prayerType: PrayerType.fajr.name,
          originalDate: DateTime(2026, 3, 1),
          status: 'pending',
          createdAt: DateTime(2026, 3, 1),
          updatedAt: DateTime(2026, 3, 1),
        ),
      );

      await store.cloneGuestToGoogle(
        firebaseUid: 'firebase-user-signout',
        email: 'signout@example.com',
      );

      final guestId = await store.ensureGuestActive();

      expect(guestId, isNot(UserProfile.localLedgerUserId));

      final guest = await store.getAccount(guestId);
      expect(guest?.isGuest, isTrue);
      expect(await store.hasAnyQaza(guestId), isFalse);

      final google = await store.findGoogleByUid('firebase-user-signout');
      expect(google?.isGoogle, isTrue);
      expect(await store.hasAnyQaza(google!.localAccountId), isTrue);
    },
  );

  test(
    'Guest to an existing empty Google partition preserves record identity',
    () async {
      await store.ensureGuestActive();
      final googleId = await store.createGooglePartition(
        firebaseUid: 'firebase-user-empty',
        email: 'empty@example.com',
      );

      await database.qazaRecordsDao.insertRecord(
        QazaRecordsCompanion.insert(
          id: 'record-preserved-empty-target',
          userId: UserProfile.localLedgerUserId,
          prayerType: PrayerType.isha.name,
          originalDate: DateTime(2026, 3, 2),
          status: 'pending',
          createdAt: DateTime(2026, 3, 2),
          updatedAt: DateTime(2026, 3, 2),
        ),
      );

      final targetId = await store.cloneGuestToGoogle(
        firebaseUid: 'firebase-user-empty',
        email: 'empty@example.com',
      );

      expect(targetId, UserProfile.localLedgerUserId);
      expect(await store.getAccount(googleId), isNull);

      final google = await store.findGoogleByUid('firebase-user-empty');
      expect(google?.localAccountId, UserProfile.localLedgerUserId);

      final rows = await database.qazaRecordsDao.getAll(
        userId: UserProfile.localLedgerUserId,
      );
      expect(rows.single.id, 'record-preserved-empty-target');
    },
  );

  test('An existing Google partition is reconciled without overwriting its data',
      () async {
    final googleId = await store.createGooglePartition(
      firebaseUid: 'firebase-user-3',
      email: 'user3@example.com',
    );

    await database.qazaRecordsDao.insertRecord(
      QazaRecordsCompanion.insert(
        id: 'google-existing-record',
        userId: googleId,
        prayerType: PrayerType.fajr.name,
        originalDate: DateTime(2026, 3, 3),
        status: 'pending',
        createdAt: DateTime(2026, 3, 3),
        updatedAt: DateTime(2026, 3, 3),
      ),
    );

    await database.qazaRecordsDao.insertRecord(
      QazaRecordsCompanion.insert(
        id: 'guest-record-to-merge',
        userId: UserProfile.localLedgerUserId,
        prayerType: PrayerType.isha.name,
        originalDate: DateTime(2026, 3, 4),
        status: 'pending',
        createdAt: DateTime(2026, 3, 4),
        updatedAt: DateTime(2026, 3, 4),
      ),
    );

    final targetId = await store.cloneGuestToGoogle(
      firebaseUid: 'firebase-user-3',
      email: 'user3@example.com',
    );

    expect(targetId, googleId);

    final googleRecords =
        await database.qazaRecordsDao.getAll(userId: googleId);
    expect(
      googleRecords.map((record) => record.id),
      containsAll(<String>[
        'google-existing-record',
        'guest-record-to-merge',
      ]),
    );

    final guest = await store.getAccount(UserProfile.localLedgerUserId);
    expect(guest?.isGuest, isTrue);
  });
}
