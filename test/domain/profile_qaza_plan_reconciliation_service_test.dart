import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/data/local/database/app_database.dart';
import 'package:qaza_namaz/data/local/drift_qaza_local_store.dart';
import 'package:qaza_namaz/data/local/qaza_local_store.dart';
import 'package:qaza_namaz/domain/entities/qaza_plan_revision.dart';
import 'package:qaza_namaz/domain/entities/qaza_progress.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';
import 'package:qaza_namaz/domain/entities/qaza_completion_result.dart';
import 'package:qaza_namaz/domain/entities/user_profile.dart';
import 'package:qaza_namaz/domain/repositories/qaza_plan_revision_repository.dart';
import 'package:qaza_namaz/domain/repositories/qaza_profile_plan_mutation_repository.dart';
import 'package:qaza_namaz/domain/repositories/qaza_repository.dart';
import 'package:qaza_namaz/domain/services/profile_qaza_plan_reconciliation_service.dart';
import 'package:qaza_namaz/domain/services/qaza_availability_service.dart';
import 'package:qaza_namaz/domain/services/qaza_plan_service.dart';
import 'package:qaza_namaz/domain/services/qaza_service.dart';

class MemoryRevisionRepository implements QazaPlanRevisionRepository {
  QazaPlanRevision? stored;

  @override
  Future<QazaPlanRevision?> latest(String userId) async => stored;

  @override
  Future<void> save(QazaPlanRevision revision) async {
    stored = revision;
  }
}

class FailingRevisionRepository extends MemoryRevisionRepository {
  bool fail = false;

  @override
  Future<void> save(QazaPlanRevision revision) async {
    if (fail) throw StateError('revision failure');
    stored = revision;
  }
}

class MemoryQazaRepository implements QazaRepository {
  final records = <QazaRecord>[];

  String key(QazaRecord record) => QazaPrayerKey.fromRecord(record).value;

  @override
  Future<List<QazaRecord>> getRecords({required String userId, PrayerType? prayerType, QazaStatus? status}) async => records.where((r) => r.userId == userId && (prayerType == null || r.prayerType == prayerType) && (status == null || r.status == status)).toList();

  @override
  Future<QazaPage> getPage({required String userId, int limit = 50, PrayerType? prayerType, Iterable<PrayerType>? prayerTypes, QazaStatus? status, String? additionId, DateTime? from, DateTime? to, DateTime? toExclusive, DateTime? afterOriginalDate, String? afterId, DateTime? beforeOriginalDate, String? beforeId, DateTime? afterCompletedAt, DateTime? beforeCompletedAt, bool descending = false}) async {
    var values = records.where((r) => r.userId == userId).toList();
    if (prayerType != null) values = values.where((r) => r.prayerType == prayerType).toList();
    if (prayerTypes != null) values = values.where((r) => prayerTypes.contains(r.prayerType)).toList();
    if (status != null) values = values.where((r) => r.status == status).toList();
    if (additionId != null) values = values.where((r) => r.additionId == additionId).toList();
    if (from != null) values = values.where((r) => !r.originalDate.isBefore(from)).toList();
    if (to != null) values = values.where((r) => !r.originalDate.isAfter(to)).toList();
    values.sort((a, b) => descending ? b.originalDate.compareTo(a.originalDate) : a.originalDate.compareTo(b.originalDate));
    if (afterOriginalDate != null) {
      values = values.where((r) => r.originalDate.isAfter(afterOriginalDate) || (r.originalDate.isAtSameMomentAs(afterOriginalDate) && r.id.compareTo(afterId!) > 0)).toList();
    }
    return QazaPage(records: values.take(limit).toList(), hasMore: values.length > limit);
  }

  @override
  Future<QazaRecord?> getOldestPending({required String userId, required PrayerType prayerType}) async {
    final page = await getPage(userId: userId, prayerType: prayerType, status: QazaStatus.pending, limit: 1);
    return page.records.isEmpty ? null : page.records.first;
  }

  @override
  Future<List<QazaRecord>> getPendingRecordsByIds({
    required String userId,
    required Iterable<String> recordIds,
  }) async =>
      (await getRecordsByIds(userId: userId, recordIds: recordIds))
          .where((record) => record.status == QazaStatus.pending)
          .toList();

  @override
  Future<List<QazaRecord>> getRecordsByIds({required String userId, required Iterable<String> recordIds}) async {
    final ids = recordIds.toSet();
    return records.where((r) => r.userId == userId && ids.contains(r.id)).toList();
  }

  @override
  Future<QazaProgressSummary> getProgressSummary({required String userId}) async => QazaProgressSummary.fromRecords(records.where((r) => r.userId == userId));

  @override
  Future<int> countCompletedBetween({required String userId, required DateTime from, required DateTime to, Iterable<PrayerType>? prayerTypes}) async => records.where((r) => r.userId == userId && r.status == QazaStatus.completed && r.completedAt != null && !r.completedAt!.isBefore(from) && r.completedAt!.isBefore(to) && (prayerTypes == null || prayerTypes.contains(r.prayerType))).length;

  @override
  Future<void> addRecord(QazaRecord record) async {
    if (!records.any((r) => key(r) == key(record))) records.add(record);
  }

  @override
  Future<void> addRecords(List<QazaRecord> values) async {
    for (final record in values) { await addRecord(record); }
  }

  @override
  Future<bool> updateRecord({required QazaRecord record}) async {
    final index = records.indexWhere((r) => r.id == record.id);
    if (index < 0) return false;
    records[index] = record;
    return true;
  }

  @override
  Future<void> deleteRecord({required String userId, required String recordId}) async {
    records.removeWhere((r) => r.userId == userId && r.id == recordId);
  }

  @override
  Future<QazaCompletionResult> completeRecord({required String userId, required String recordId, required DateTime completedAt, String? completionId}) async => QazaCompletionResult.notFound;

  @override
  Future<List<QazaRecord>> completeRecords({required String userId, required List<String> recordIds, required DateTime completedAt, Map<String, String>? completionIds}) async => [];

  @override
  Future<List<QazaRecord>> markCompletedAsPendingBatch({required String userId, required Map<String, String> expectedCompletionIds, required DateTime updatedAt}) async => [];

  @override
  Future<void> resetUserRecords({required String userId}) async { records.removeWhere((r) => r.userId == userId); }
}

class MemoryMutationRepository implements QazaProfilePlanMutationRepository {
  MemoryMutationRepository(this.qaza);
  final MemoryQazaRepository qaza;
  QazaProfilePlanMutationResult? last;

  @override
  Future<QazaProfilePlanMutationResult> applyProfilePlanChanges({required String userId, required List<QazaRecord> additions, required List<String> removalIds, required Set<String> newPlanKeys, required String expectedPreviousPlanFingerprint}) async {
    final removed = <QazaRecord>[];
    for (final id in removalIds) {
      final index = qaza.records.indexWhere((r) => r.id == id);
      if (index < 0) continue;
      final record = qaza.records[index];
      if (record.status != QazaStatus.pending || record.profilePlanRevisionId == null || record.profilePlanFingerprint == null || newPlanKeys.contains(qaza.key(record))) continue;
      removed.add(record);
    }
    qaza.records.removeWhere((r) => removed.any((x) => x.id == r.id));
    final added = <QazaRecord>[];
    for (final record in additions) {
      if (qaza.records.any((x) => qaza.key(x) == qaza.key(record))) continue;
      qaza.records.add(record);
      added.add(record);
    }
    last = QazaProfilePlanMutationResult(userId: userId, added: added, removed: removed, operationIds: [...added.map((r) => 'add_' + r.id), ...removed.map((r) => 'delete_' + r.id)]);
    return last!;
  }

  @override
  Future<void> rollbackProfilePlanChanges(QazaProfilePlanMutationResult mutation) async {
    qaza.records.removeWhere((r) => mutation.added.any((x) => x.id == r.id));
    qaza.records.addAll(mutation.removed);
  }
}

UserProfile profile({required int startAge, bool witr = false}) => UserProfile(languageCode: 'en', gender: Gender.male, madhab: Madhab.other, dateOfBirth: DateTime(1990, 1, 1), pubertyAge: 12, startPrayingAge: startAge, witrIncluded: witr, onboardingCompleted: true);

QazaRecord profileRecord({required String id, required PrayerType prayer, required DateTime date, String? revision, String? fingerprint, QazaStatus status = QazaStatus.pending}) => QazaRecord(id: id, userId: UserProfile.localLedgerUserId, prayerType: prayer, originalDate: date, status: status, completedAt: status == QazaStatus.completed ? DateTime(2026, 10, 1) : null, completionId: status == QazaStatus.completed ? 'completion' : null, profilePlanRevisionId: revision, profilePlanFingerprint: fingerprint, createdAt: DateTime(2026, 10, 1), updatedAt: DateTime(2026, 10, 1));

Future<void> saveRevision(MemoryRevisionRepository repo, QazaPlan plan, UserProfile p, {String id = 'old'}) => repo.save(QazaPlanRevision.fromPlan(revisionId: id, userId: UserProfile.localLedgerUserId, createdAt: DateTime(2026, 10, 1), plan: plan, planFingerprint: ProfileQazaPlanReconciliationService.planFingerprint(plan), profileSnapshot: ProfileQazaPlanReconciliationService.profileSnapshot(p), ledgerDecision: QazaPlanLedgerDecision.applied, ledgerPlan: plan, ledgerPlanFingerprint: ProfileQazaPlanReconciliationService.planFingerprint(plan)));

ProfileQazaPlanReconciliationService service(MemoryQazaRepository qaza, MemoryRevisionRepository revisions) => ProfileQazaPlanReconciliationService(planService: const QazaPlanService(), qazaService: QazaService(qaza), revisionRepository: revisions, mutationRepository: MemoryMutationRepository(qaza));

void main() {
  test('increase identifies missing records under fixed 30/360 plan', () async {
    final qaza = MemoryQazaRepository();
    final revisions = MemoryRevisionRepository();
    final old = profile(startAge: 13);
    final oldPlan = const QazaPlanService().planFor(old)!;
    await saveRevision(revisions, oldPlan, old);
    final oldFingerprint =
        ProfileQazaPlanReconciliationService.planFingerprint(oldPlan);
    for (final date in QazaPlanService.datesFor(oldPlan)) {
      for (final prayer in const [
        PrayerType.fajr,
        PrayerType.zuhr,
        PrayerType.asr,
        PrayerType.maghrib,
        PrayerType.isha,
      ]) {
        qaza.records.add(
          profileRecord(
            id: 'old_${prayer.name}_${date.millisecondsSinceEpoch}',
            prayer: prayer,
            date: date,
            revision: 'old',
            fingerprint: oldFingerprint,
          ),
        );
      }
    }
    final preview = await service(qaza, revisions).preview(
      userId: UserProfile.localLedgerUserId,
      oldProfile: old,
      newProfile: profile(startAge: 14),
    );
    expect(preview.pendingToAdd, 5 * 360);
    expect(preview.pendingToRemove, 0);
    expect(preview.requiresUserDecision, isTrue);
  });

  test('decrease removes only pending profile-generated records outside new plan', () async {
    final qaza = MemoryQazaRepository();
    final revisions = MemoryRevisionRepository();
    final old = profile(startAge: 14);
    final plan = const QazaPlanService().planFor(old)!;
    final fingerprint = ProfileQazaPlanReconciliationService.planFingerprint(plan);
    final outside = QazaPlanService.planDateAt(plan, plan.totalDays - 1);
    qaza.records.add(profileRecord(id: 'profile_outside', prayer: PrayerType.fajr, date: outside, revision: 'old', fingerprint: fingerprint));
    await saveRevision(revisions, plan, old);
    final preview = await service(qaza, revisions).preview(userId: UserProfile.localLedgerUserId, oldProfile: old, newProfile: profile(startAge: 13));
    expect(preview.pendingToRemove, 1);
    expect(preview.removalRecordIds, contains('profile_outside'));
  });

  test('completed, manual, legacy and edited records remain protected', () async {
    final qaza = MemoryQazaRepository();
    final revisions = MemoryRevisionRepository();
    final old = profile(startAge: 14);
    final plan = const QazaPlanService().planFor(old)!;
    final fingerprint = ProfileQazaPlanReconciliationService.planFingerprint(plan);
    final date = QazaPlanService.planDateAt(plan, plan.totalDays - 1);
    qaza.records.add(profileRecord(id: 'completed', prayer: PrayerType.fajr, date: date, revision: 'old', fingerprint: fingerprint, status: QazaStatus.completed));
    qaza.records.add(profileRecord(id: 'manual', prayer: PrayerType.zuhr, date: date));
    qaza.records.add(profileRecord(id: 'legacy', prayer: PrayerType.asr, date: date, fingerprint: null));
    qaza.records.add(profileRecord(id: 'edited', prayer: PrayerType.maghrib, date: date));
    await saveRevision(revisions, plan, old);
    final preview = await service(qaza, revisions).preview(userId: UserProfile.localLedgerUserId, oldProfile: old, newProfile: profile(startAge: 13));
    expect(preview.removalRecordIds, isEmpty);
  });

  test('decrease-only change requires explicit decision even with no safe removals', () async {
    final qaza = MemoryQazaRepository();
    final revisions = MemoryRevisionRepository();
    final old = profile(startAge: 14);
    final plan = const QazaPlanService().planFor(old)!;
    await saveRevision(revisions, plan, old);
    final preview = await service(qaza, revisions).preview(userId: UserProfile.localLedgerUserId, oldProfile: old, newProfile: profile(startAge: 13));
    expect(preview.calculationChanged, isTrue);
    expect(preview.requiresUserDecision, isTrue);
  });

  test('Witr exclusion removes profile Witr but not manual Witr', () async {
    final qaza = MemoryQazaRepository();
    final revisions = MemoryRevisionRepository();
    final old = profile(startAge: 13, witr: true);
    final plan = const QazaPlanService().planFor(old)!;
    final fingerprint = ProfileQazaPlanReconciliationService.planFingerprint(plan);
    qaza.records.add(profileRecord(id: 'profile_witr', prayer: PrayerType.witr, date: plan.startDate, revision: 'old', fingerprint: fingerprint));
    qaza.records.add(profileRecord(id: 'manual_witr', prayer: PrayerType.witr, date: QazaPlanService.planDateAt(plan, 1)));
    await saveRevision(revisions, plan, old);
    final preview = await service(qaza, revisions).preview(userId: UserProfile.localLedgerUserId, oldProfile: old, newProfile: profile(startAge: 13, witr: false));
    expect(preview.removalRecordIds, contains('profile_witr'));
    expect(preview.removalRecordIds, isNot(contains('manual_witr')));
  });

  test('revision failure rolls back the atomic ledger mutation', () async {
    final qaza = MemoryQazaRepository();
    final revisions = FailingRevisionRepository()..fail = false;
    final old = profile(startAge: 13);
    final plan = const QazaPlanService().planFor(old)!;
    await saveRevision(revisions, plan, old);
    revisions.fail = true;
    final s = service(qaza, revisions);
    final preview = await s.preview(userId: UserProfile.localLedgerUserId, oldProfile: old, newProfile: profile(startAge: 14));
    await expectLater(s.apply(userId: UserProfile.localLedgerUserId, newProfile: profile(startAge: 14), preview: preview, choice: ProfileQazaChangeChoice.apply), throwsStateError);
    expect(qaza.records, isEmpty);
  });

  test('explicit Qaza record identity edits detach profile provenance', () async {
    final qaza = MemoryQazaRepository();
    final service = QazaService(qaza);
    final record = profileRecord(
      id: 'editable',
      prayer: PrayerType.fajr,
      date: DateTime(2020, 1, 1),
      revision: 'revision',
      fingerprint: 'qazaPlanV2Fixed360|start|end',
    );
    await qaza.addRecord(record);

    await service.updateRecord(
      userId: UserProfile.localLedgerUserId,
      record: record.copyWith(originalDate: DateTime(2020, 1, 2)),
    );

    expect(qaza.records.single.profilePlanRevisionId, isNull);
    expect(qaza.records.single.profilePlanFingerprint, isNull);
  });

  test('Drift removal queues an idempotent delete outbox operation', () async {
    final database = AppDatabase(NativeDatabase.memory());
    final store = DriftQazaLocalStore(database: database);
    final record = profileRecord(
      id: 'removable',
      prayer: PrayerType.fajr,
      date: DateTime(2020, 1, 1),
      revision: 'revision',
      fingerprint: 'qazaPlanV2Fixed360|start|end',
    );
    await store.appendRecords(UserProfile.localLedgerUserId, [record]);

    final first = await store.applyProfilePlanChanges(
      userId: UserProfile.localLedgerUserId,
      additions: const [],
      removalIds: const ['removable'],
      newPlanKeys: const {},
      expectedPreviousPlanFingerprint: 'qazaPlanV2Fixed360|start|end',
    );
    expect(first.removed, hasLength(1));

    final second = await store.applyProfilePlanChanges(
      userId: UserProfile.localLedgerUserId,
      additions: const [],
      removalIds: const ['removable'],
      newPlanKeys: const {},
      expectedPreviousPlanFingerprint: 'qazaPlanV2Fixed360|start|end',
    );
    expect(second.removed, isEmpty);

    final outbox = await store.loadOutbox(UserProfile.localLedgerUserId);
    final deletes = outbox.where(
      (operation) =>
          operation.type == SyncOpType.delete &&
          operation.targetRecordId == 'removable',
    );
    expect(deletes, hasLength(1));
    await database.close();
  });

  test('provenance survives JSON and Drift persistence reload', () async {
    final record = profileRecord(id: 'persisted', prayer: PrayerType.fajr, date: DateTime(2020, 1, 1), revision: 'revision', fingerprint: 'qazaPlanV2Fixed360|start|end');
    final restored = QazaRecord.fromJson(record.toJson());
    expect(restored.profilePlanRevisionId, record.profilePlanRevisionId);
    expect(restored.profilePlanFingerprint, record.profilePlanFingerprint);

    final database = AppDatabase(NativeDatabase.memory());
    final store = DriftQazaLocalStore(database: database);
    await store.appendRecords(UserProfile.localLedgerUserId, [record]);
    final page = await store.getPage(userId: UserProfile.localLedgerUserId, limit: 1);
    expect(page.records.single.profilePlanRevisionId, 'revision');
    expect(page.records.single.profilePlanFingerprint, 'qazaPlanV2Fixed360|start|end');
    await database.close();
  });
}