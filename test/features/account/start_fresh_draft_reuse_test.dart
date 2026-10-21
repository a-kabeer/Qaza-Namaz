import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/data/local/account_local_store.dart';
import 'package:qaza_namaz/data/local/database/app_database.dart';
import 'package:qaza_namaz/domain/entities/local_account.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';
import 'package:qaza_namaz/domain/entities/user_profile.dart';

/// Scenario 23 — Start Fresh reuses an existing empty hidden draft instead
/// of creating a new Guest workspace every time, so abandoned empty drafts
/// do not pile up. A draft holding any user data is never reused.
void main() {
  late AppDatabase database;
  late AccountLocalStore store;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    store = AccountLocalStore(database: database);
  });

  tearDown(() async {
    await database.close();
  });

  Future<List<String>> guestLifecycles() async {
    final rows = await database.customSelect(
      '''SELECT lifecycle_state FROM local_accounts
         WHERE local_account_id = 'guest'
            OR local_account_id GLOB 'guest:*'
            OR local_account_id GLOB 'guest_*'
         ORDER BY created_at ASC''',
    ).get();
    return rows.map((row) => row.read<String>('lifecycle_state')).toList();
  }

  test('Start Fresh with no existing draft creates and activates one draft',
      () async {
    final id = await store.startFreshGuestWorkspace();

    final account = await store.getAccount(id);
    expect(account, isNotNull);
    expect(account!.lifecycleState, AccountLifecycleState.draft);
    expect((await store.activeAccount())?.localAccountId, id);
    expect(await guestLifecycles(), ['draft']);
    expect(await store.findReusableEmptyGuestDraft(), id);
  });

  test('Start Fresh reuses an abandoned empty draft instead of piling up',
      () async {
    final firstId = await store.startFreshGuestWorkspace();

    // The user abandons onboarding without entering anything, then chooses
    // Start Fresh again (and again). The same empty draft must be resumed.
    final secondId = await store.startFreshGuestWorkspace();
    final thirdId = await store.startFreshGuestWorkspace();

    expect(secondId, firstId);
    expect(thirdId, firstId);
    expect(await guestLifecycles(), ['draft']);
    expect((await store.activeAccount())?.localAccountId, firstId);
  });

  test('Start Fresh does not reuse a draft holding a saved profile', () async {
    final draftWithData = await store.createGuestWorkspace(draft: true);
    await store.saveProfileLocalOnly(
      draftWithData,
      const UserProfile(onboardingCompleted: false),
    );

    final freshId = await store.startFreshGuestWorkspace();

    expect(freshId, isNot(draftWithData));
    expect((await store.activeAccount())?.localAccountId, freshId);
    // The data-holding draft is untouched and still resumable.
    final preserved = await store.getAccount(draftWithData);
    expect(preserved!.lifecycleState, AccountLifecycleState.draft);
    expect(await store.loadProfile(draftWithData), isNotNull);
    expect(await guestLifecycles(), ['draft', 'draft']);
  });

  test('Start Fresh does not reuse a draft holding Qaza records', () async {
    final draftWithData = await store.createGuestWorkspace(draft: true);
    await database.qazaRecordsDao.insertRecord(
      QazaRecordsCompanion.insert(
        id: 'draft_fajr_1',
        userId: draftWithData,
        prayerType: PrayerType.fajr.name,
        originalDate: DateTime(2025, 1, 1),
        status: QazaStatus.pending.name,
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
      ),
    );

    final freshId = await store.startFreshGuestWorkspace();

    expect(freshId, isNot(draftWithData));
    expect(
      (await database.qazaRecordsDao.getAll(userId: draftWithData))
          .map((record) => record.id),
      ['draft_fajr_1'],
    );
    expect(await guestLifecycles(), ['draft', 'draft']);
  });

  test('Start Fresh does not reuse a draft holding daily Salah records',
      () async {
    final draftWithData = await store.createGuestWorkspace(draft: true);
    await database.customInsert(
      '''INSERT INTO daily_salah_logs
         (user_id, prayer_date, prayer_type, status,
          tracker_created_qaza_id, linked_qaza_id, completion_sync_id,
          updated_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?)''',
      variables: [
        Variable.withString(draftWithData),
        Variable.withString('2025-01-01'),
        Variable.withString('fajr'),
        Variable.withString('missed'),
        Variable.withString('draft_fajr_1'),
        Variable.withString('draft_fajr_1'),
        Variable.withString('sync-draft-1'),
        Variable.withString(DateTime.utc(2025, 1, 1).toIso8601String()),
      ],
    );

    final freshId = await store.startFreshGuestWorkspace();

    expect(freshId, isNot(draftWithData));
    expect(await guestLifecycles(), ['draft', 'draft']);
  });

  test('Start Fresh does not reuse a draft that only has a saved name',
      () async {
    final namedDraft = await store.createGuestWorkspace(
      draft: true,
      displayName: 'Named Draft',
    );

    final freshId = await store.startFreshGuestWorkspace();

    expect(freshId, isNot(namedDraft));
    expect(
      (await store.getAccount(namedDraft))!.lifecycleState,
      AccountLifecycleState.draft,
    );
    expect(await guestLifecycles(), ['draft', 'draft']);
  });

  test('Start Fresh never reuses an empty active workspace as a draft',
      () async {
    final activeId = await store.createGuestWorkspace();

    final freshId = await store.startFreshGuestWorkspace();

    expect(freshId, isNot(activeId));
    expect(
      (await store.getAccount(freshId))!.lifecycleState,
      AccountLifecycleState.draft,
    );
    expect(
      (await store.getAccount(activeId))!.lifecycleState,
      AccountLifecycleState.active,
    );
    expect(await guestLifecycles(), ['active', 'draft']);
  });
}
