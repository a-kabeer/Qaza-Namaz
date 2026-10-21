import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/data/local/account_local_store.dart';
import 'package:qaza_namaz/data/local/database/app_database.dart';
import 'package:qaza_namaz/domain/entities/local_account.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';
import 'package:qaza_namaz/domain/entities/user_profile.dart';
import 'package:qaza_namaz/features/account/account_session_manager.dart';

/// Scenario 18 listing rule — a Guest draft is listed (chooser and Guest
/// management) only when it holds data. An empty draft (no saved name, no
/// profile, no records, no logs, no plan data — the same emptiness test
/// Start Fresh reuse applies) stays hidden, but it is not deleted and it
/// remains resumable: startup resume follows the persisted session, and
/// Start Fresh finds the hidden draft directly.
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

  Future<List<String>> listedIds() async {
    final listed = await store.listGuestWorkspaces();
    return listed.map((account) => account.localAccountId).toList();
  }

  test('an empty draft is not listed, but still exists as a draft', () async {
    final draftId = await store.createGuestWorkspace(draft: true);

    expect(await listedIds(), isNot(contains(draftId)));
    final account = await store.getAccount(draftId);
    expect(account, isNotNull);
    expect(account!.lifecycleState, AccountLifecycleState.draft);
  });

  test('a draft holding a saved profile is listed as a draft', () async {
    final draftId = await store.createGuestWorkspace(draft: true);
    await store.saveProfileLocalOnly(
      draftId,
      const UserProfile(onboardingCompleted: false),
    );

    final listed = await store.listGuestWorkspaces();
    final entry = listed.singleWhere(
      (account) => account.localAccountId == draftId,
    );
    expect(entry.lifecycleState, AccountLifecycleState.draft);
  });

  test('a draft holding only a saved name is listed', () async {
    final draftId = await store.createGuestWorkspace(
      draft: true,
      displayName: 'Named Draft',
    );

    expect(await listedIds(), contains(draftId));
  });

  test('a draft holding Qaza records is listed', () async {
    final draftId = await store.createGuestWorkspace(draft: true);
    await database.qazaRecordsDao.insertRecord(
      QazaRecordsCompanion.insert(
        id: 'listed_draft_fajr',
        userId: draftId,
        prayerType: PrayerType.fajr.name,
        originalDate: DateTime(2025, 1, 1),
        status: QazaStatus.pending.name,
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
      ),
    );

    expect(await listedIds(), contains(draftId));
  });

  test(
      'Start Fresh reuses the hidden empty draft instead of creating '
      'another workspace', () async {
    final draftId = await store.createGuestWorkspace(draft: true);
    expect(await listedIds(), isNot(contains(draftId)));

    final reusedId = await store.startFreshGuestWorkspace();

    expect(reusedId, draftId);
    expect((await store.activeAccount())?.localAccountId, draftId);
    // Still hidden until it gains data, and still the only Guest row.
    expect(await listedIds(), isNot(contains(draftId)));
    final rows = await database
        .customSelect(
          'SELECT local_account_id FROM local_accounts',
        )
        .get();
    expect(rows, hasLength(1));
  });

  test(
      'an empty draft still resumes on startup even though it is not '
      'listed', () async {
    final manager = AccountSessionManager(accountStore: store);
    await manager.initialize();
    final draftId = await store.createGuestWorkspace(draft: true);
    expect(await listedIds(), isNot(contains(draftId)));

    // A cold start follows the persisted session, not the listing, so the
    // hidden draft is reopened exactly where onboarding left off.
    final restartedManager = AccountSessionManager(accountStore: store);
    await restartedManager.initialize();

    expect(restartedManager.activeLocalAccountId, draftId);
    expect(
      (await store.getAccount(draftId))!.lifecycleState,
      AccountLifecycleState.draft,
    );
  });
}
