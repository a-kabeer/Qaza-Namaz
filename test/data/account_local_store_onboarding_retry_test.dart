import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/data/local/account_local_store.dart';
import 'package:qaza_namaz/data/local/database/app_database.dart';
import 'package:qaza_namaz/domain/entities/qaza_plan_revision.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';
import 'package:qaza_namaz/domain/entities/user_profile.dart';
import 'package:qaza_namaz/domain/services/qaza_plan_service.dart';
import 'package:qaza_namaz/features/account/account_session_manager.dart';

void main() {
  late AppDatabase db;
  late AccountLocalStore store;
  late AccountSessionManager sessionManager;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    store = AccountLocalStore(database: db);
    sessionManager = AccountSessionManager(accountStore: store);
    await sessionManager.initialize();
  });

  tearDown(() => db.close());

  test('commitOnboarding succeeds gracefully when records already exist from earlier sync', () async {
    final activeId = sessionManager.state.activeLocalAccountId;
    expect(activeId, isNotNull);

    final profile = UserProfile(
      gender: Gender.male,
      madhab: Madhab.hanafi,
      dateOfBirth: DateTime(1995, 1, 1),
      pubertyAge: 12,
      startPrayingAge: 13,
      onboardingCompleted: false,
    );

    final plan = QazaPlan(
      startDate: DateTime(2007, 1, 1),
      endDate: DateTime(2007, 1, 2),
      totalDays: 1,
      includeWitr: true,
      totalPrayers: 6,
      prayerBreakdown: {
        for (final p in PrayerType.values) p: 1,
      },
    );

    const revId = 'test_rev_1';
    final revision = QazaPlanRevision.fromPlan(
      revisionId: revId,
      userId: activeId!,
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
      plan: plan,
      planFingerprint: 'fingerprint_1',
      profileSnapshot: profile.toJson(),
      previousProfileSnapshot: const {},
      changedFields: const [],
      addedRecords: 6,
      removedRecords: 0,
      ledgerDecision: QazaPlanLedgerDecision.applied,
      ledgerPlan: plan,
      ledgerPlanFingerprint: 'fingerprint_1',
    );

    // Pre-insert records with an older timestamp (simulating prior cloud sync / partial commit)
    final oldTimestamp = DateTime.now().subtract(const Duration(days: 5));
    final initialRecords = [
      for (final p in PrayerType.values)
        QazaRecord(
          id: '2007-01-01_${p.name}',
          userId: activeId,
          prayerType: p,
          originalDate: DateTime(2007, 1, 1),
          status: QazaStatus.pending,
          profilePlanRevisionId: revId,
          profilePlanFingerprint: 'fingerprint_1',
          createdAt: oldTimestamp,
          updatedAt: oldTimestamp,
        ),
    ];

    final insertedIds = await db.qazaRecordsDao.insertRecordsReturningInsertedIds([
      for (final r in initialRecords)
        QazaRecordsCompanion.insert(
          id: r.id,
          userId: r.userId,
          prayerType: r.prayerType.name,
          originalDate: r.originalDate,
          status: r.status.name,
          createdAt: r.createdAt,
          updatedAt: r.updatedAt,
        ),
    ]);
    expect(insertedIds.length, 6);

    // Now attempt commitOnboarding with newly created QazaRecord objects (DateTime.now() timestamps)
    final retryRecords = [
      for (final p in PrayerType.values)
        QazaRecord(
          id: '2007-01-01_${p.name}',
          userId: activeId,
          prayerType: p,
          originalDate: DateTime(2007, 1, 1),
          status: QazaStatus.pending,
          profilePlanRevisionId: revId,
          profilePlanFingerprint: 'fingerprint_1',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
    ];

    // This should NOT throw StateError and should commit cleanly
    await expectLater(
      store.commitOnboarding(
        localAccountId: activeId,
        profile: profile,
        revision: revision,
        records: retryRecords,
      ),
      completes,
    );

    final savedProfile = await store.loadProfile(activeId);
    expect(savedProfile?.onboardingCompleted, isTrue);
  });

  test('commitOnboarding retains existing completed records without conflict', () async {
    final activeId = sessionManager.state.activeLocalAccountId;
    expect(activeId, isNotNull);

    final profile = UserProfile(
      gender: Gender.male,
      madhab: Madhab.hanafi,
      dateOfBirth: DateTime(1995, 1, 1),
      pubertyAge: 12,
      startPrayingAge: 13,
      onboardingCompleted: false,
    );

    final plan = QazaPlan(
      startDate: DateTime(2007, 1, 1),
      endDate: DateTime(2007, 1, 2),
      totalDays: 1,
      includeWitr: true,
      totalPrayers: 6,
      prayerBreakdown: {
        for (final p in PrayerType.values) p: 1,
      },
    );

    const revId = 'test_rev_2';
    final revision = QazaPlanRevision.fromPlan(
      revisionId: revId,
      userId: activeId!,
      createdAt: DateTime.now(),
      plan: plan,
      planFingerprint: 'fingerprint_2',
      profileSnapshot: profile.toJson(),
      previousProfileSnapshot: const {},
      changedFields: const [],
      addedRecords: 6,
      removedRecords: 0,
      ledgerDecision: QazaPlanLedgerDecision.applied,
      ledgerPlan: plan,
      ledgerPlanFingerprint: 'fingerprint_2',
    );

    // Pre-insert one record as completed
    await db.qazaRecordsDao.insertRecordsReturningInsertedIds([
      QazaRecordsCompanion.insert(
        id: '2007-01-01_fajr',
        userId: activeId,
        prayerType: 'fajr',
        originalDate: DateTime(2007, 1, 1),
        status: 'completed',
        completedAt: Value(DateTime(2026, 1, 1)),
        completionId: const Value('cmp_1'),
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ),
    ]);

    final onboardingRecords = [
      for (final p in PrayerType.values)
        QazaRecord(
          id: '2007-01-01_${p.name}',
          userId: activeId,
          prayerType: p,
          originalDate: DateTime(2007, 1, 1),
          status: QazaStatus.pending,
          profilePlanRevisionId: revId,
          profilePlanFingerprint: 'fingerprint_2',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
    ];

    await expectLater(
      store.commitOnboarding(
        localAccountId: activeId,
        profile: profile,
        revision: revision,
        records: onboardingRecords,
      ),
      completes,
    );

    // Verify the completed record is preserved and not overwritten
    final fajrRows = await db.qazaRecordsDao.getRowsByIds(
      userId: activeId,
      ids: ['2007-01-01_fajr'],
    );
    expect(fajrRows.length, 1);
    expect(fajrRows.first.status, 'completed');
    expect(fajrRows.first.completionId, 'cmp_1');
  });

  test('commitOnboarding for two distinct accounts with identical dates succeeds without collision', () async {
    const user1 = 'supabase_user_1';
    const user2 = 'supabase_user_2';

    await store.ensureAccountActive(user1);
    await store.activate(user1);

    final profile1 = UserProfile(
      gender: Gender.male,
      madhab: Madhab.hanafi,
      dateOfBirth: DateTime(1995, 1, 1),
      pubertyAge: 12,
      startPrayingAge: 13,
      onboardingCompleted: false,
    );

    final plan = QazaPlan(
      startDate: DateTime(2007, 1, 1),
      endDate: DateTime(2007, 1, 2),
      totalDays: 1,
      includeWitr: true,
      totalPrayers: 6,
      prayerBreakdown: {
        for (final p in PrayerType.values) p: 1,
      },
    );

    final rev1 = QazaPlanRevision.fromPlan(
      revisionId: 'rev_user1',
      userId: user1,
      createdAt: DateTime.now(),
      plan: plan,
      planFingerprint: 'fp_1',
      profileSnapshot: profile1.toJson(),
      previousProfileSnapshot: const {},
      changedFields: const [],
      addedRecords: 6,
      removedRecords: 0,
      ledgerDecision: QazaPlanLedgerDecision.applied,
      ledgerPlan: plan,
      ledgerPlanFingerprint: 'fp_1',
    );

    final user1Records = [
      for (final p in PrayerType.values)
        QazaRecord(
          id: '${user1}_${p.name}_2007-01-01',
          userId: user1,
          prayerType: p,
          originalDate: DateTime(2007, 1, 1),
          status: QazaStatus.pending,
          profilePlanRevisionId: 'rev_user1',
          profilePlanFingerprint: 'fp_1',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
    ];

    await store.commitOnboarding(
      localAccountId: user1,
      profile: profile1,
      revision: rev1,
      records: user1Records,
    );

    expect(await store.countQazaRecords(user1), 6);

    // Now switch to user2
    await store.ensureAccountActive(user2);
    await store.activate(user2);

    final profile2 = UserProfile(
      gender: Gender.male,
      madhab: Madhab.hanafi,
      dateOfBirth: DateTime(1995, 1, 1),
      pubertyAge: 12,
      startPrayingAge: 13,
      onboardingCompleted: false,
    );

    final rev2 = QazaPlanRevision.fromPlan(
      revisionId: 'rev_user2',
      userId: user2,
      createdAt: DateTime.now(),
      plan: plan,
      planFingerprint: 'fp_2',
      profileSnapshot: profile2.toJson(),
      previousProfileSnapshot: const {},
      changedFields: const [],
      addedRecords: 6,
      removedRecords: 0,
      ledgerDecision: QazaPlanLedgerDecision.applied,
      ledgerPlan: plan,
      ledgerPlanFingerprint: 'fp_2',
    );

    final user2Records = [
      for (final p in PrayerType.values)
        QazaRecord(
          id: '${user2}_${p.name}_2007-01-01',
          userId: user2,
          prayerType: p,
          originalDate: DateTime(2007, 1, 1),
          status: QazaStatus.pending,
          profilePlanRevisionId: 'rev_user2',
          profilePlanFingerprint: 'fp_2',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
    ];

    // User2 commits onboarding on the same dates - must complete cleanly!
    await expectLater(
      store.commitOnboarding(
        localAccountId: user2,
        profile: profile2,
        revision: rev2,
        records: user2Records,
      ),
      completes,
    );

    expect(await store.countQazaRecords(user2), 6);
    expect(await store.countQazaRecords(user1), 6);
  });
}
