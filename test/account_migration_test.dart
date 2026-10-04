import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/data/local/account_local_store.dart';
import '../lib/data/local/database/app_database.dart';
import '../lib/domain/entities/user_profile.dart';

void main() {
  late AppDatabase database;
  late AccountLocalStore store;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    store = AccountLocalStore(database: database);
    await store.ensureInitialized(
      hasLegacyProfile: true,
      hasLegacyQaza: true,
    );
  });

  tearDown(() => database.close());

  test('Guest → Google preserves the existing local record ID', () async {
    await store.ensureGuestActive();

    const recordId = 'stable-record-id';
    final timestamp = DateTime.utc(2026, 10, 4).microsecondsSinceEpoch;
    await database.customInsert(
      '''INSERT INTO qaza_records
         (id, user_id, prayer_type, original_date, status, completed_at,
          completion_id, addition_id, record_version, created_at, updated_at)
         VALUES (?, ?, 'fajr', ?, 'pending', NULL, NULL, NULL, 1, ?, ?)''',
      variables: [
        const Variable(recordId),
        const Variable(UserProfile.localLedgerUserId),
        Variable(timestamp),
        Variable(timestamp),
        Variable(timestamp),
      ],
    );

    final targetId = await store.cloneGuestToGoogle(
      firebaseUid: 'firebase-user-a',
      email: 'a@example.com',
    );

    expect(targetId, UserProfile.localLedgerUserId);

    final account = await store.getAccount(targetId);
    expect(account?.isGoogle, isTrue);
    expect(account?.firebaseUid, 'firebase-user-a');

    final rows = await database.customSelect(
      'SELECT id, user_id FROM qaza_records WHERE id = ?',
      variables: [const Variable(recordId)],
    ).get();
    expect(rows, hasLength(1));
    expect(rows.first.read<String>('id'), recordId);
    expect(rows.first.read<String>('user_id'), targetId);
  });

  test('Sign Out after Guest → Google creates an independent Guest partition',
      () async {
    await store.ensureGuestActive();

    await store.cloneGuestToGoogle(
      firebaseUid: 'firebase-user-a',
      email: 'a@example.com',
    );

    final guestId = await store.ensureGuestActive();

    expect(guestId, isNot(UserProfile.localLedgerUserId));

    final guest = await store.getAccount(guestId);
    expect(guest?.isGuest, isTrue);
    expect(await store.hasAnyQaza(guestId), isFalse);

    final google = await store.findGoogleByUid('firebase-user-a');
    expect(google, isNotNull);
    expect(google?.isGoogle, isTrue);
  });

  test('Guest → existing Google partition moves records without renaming IDs',
      () async {
    await store.ensureGuestActive();
    final googleId = await store.createGooglePartition(
      firebaseUid: 'firebase-user-a',
      email: 'a@example.com',
    );

    const recordId = 'guest-record-preserved';
    final timestamp = DateTime.utc(2026, 10, 4).microsecondsSinceEpoch;
    await database.customInsert(
      '''INSERT INTO qaza_records
         (id, user_id, prayer_type, original_date, status, completed_at,
          completion_id, addition_id, record_version, created_at, updated_at)
         VALUES (?, ?, 'isha', ?, 'pending', NULL, NULL, NULL, 1, ?, ?)''',
      variables: [
        const Variable(recordId),
        const Variable(UserProfile.localLedgerUserId),
        Variable(timestamp),
        Variable(timestamp),
        Variable(timestamp),
      ],
    );

    final targetId = await store.cloneGuestToGoogle(
      firebaseUid: 'firebase-user-a',
      email: 'a@example.com',
    );

    expect(targetId, googleId);
    final row = await database.customSelect(
      'SELECT id, user_id FROM qaza_records WHERE id = ?',
      variables: [const Variable(recordId)],
    ).get();

    expect(row, hasLength(1));
    expect(row.first.read<String>('id'), recordId);
    expect(row.first.read<String>('user_id'), googleId);
  });
}
