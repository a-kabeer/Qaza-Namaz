import 'dart:math';

import '../../core/constants/prayer_types.dart';
import '../../core/utils/qaza_date.dart';
import '../entities/qaza_operation.dart';
import '../entities/qaza_plan_revision.dart';
import '../entities/qaza_record.dart';
import '../entities/user_profile.dart';
import '../repositories/qaza_plan_revision_repository.dart';
import '../repositories/qaza_recovery_repository.dart';
import 'profile_rules.dart';
import 'qaza_operation_service.dart';
import 'qaza_plan_service.dart';
import 'qaza_service.dart';

enum ProfileQazaChangeChoice {
  apply,
  keepExisting,
}

class ProfileQazaPlanPreview {
  const ProfileQazaPlanPreview({
    required this.oldPlan,
    required this.newPlan,
    required this.oldRevision,
    required this.calculationChanged,
    required this.existingCompletedInNewPlan,
    required this.pendingToAdd,
    required this.recordsToRemove,
    required this.recordsToRestore,
  });

  final QazaPlan? oldPlan;
  final QazaPlan newPlan;
  final QazaPlanRevision? oldRevision;
  final bool calculationChanged;
  final int existingCompletedInNewPlan;
  final int pendingToAdd;
  final List<QazaRecord> recordsToRemove;
  final List<QazaRecord> recordsToRestore;

  QazaPlan? get previousLedgerPlan => oldRevision?.ledgerPlan ?? oldPlan;
  int get pendingToRemove => recordsToRemove.length;
  int get pendingToRestore => recordsToRestore.length;
  int get newPlanTotal => newPlan.totalWithWitr;
  bool get hasLedgerChanges =>
      pendingToAdd > 0 || pendingToRemove > 0 || pendingToRestore > 0;
  bool get requiresReview => pendingToRemove > 0;
}

class ProfileQazaPlanReconciliationResult {
  const ProfileQazaPlanReconciliationResult({
    required this.revision,
    required this.added,
    required this.removed,
    required this.restored,
    required this.keptExisting,
  });

  final QazaPlanRevision revision;
  final int added;
  final int removed;
  final int restored;
  final bool keptExisting;
}

class ProfileQazaPlanReconciliationService {
  ProfileQazaPlanReconciliationService({
    required QazaPlanService planService,
    required QazaService qazaService,
    required QazaOperationService operationService,
    required QazaPlanRevisionRepository revisionRepository,
  })  : _planService = planService,
        _qazaService = qazaService,
        _operationService = operationService,
        _revisionRepository = revisionRepository;

  final QazaPlanService _planService;
  final QazaService _qazaService;
  final QazaOperationService _operationService;
  final QazaPlanRevisionRepository _revisionRepository;

  Future<ProfileQazaPlanPreview> preview({
    required String userId,
    required UserProfile oldProfile,
    required UserProfile newProfile,
  }) async {
    final oldProfilePlan = _planService.planFor(oldProfile);
    final newPlan = _planService.planFor(newProfile);
    if (newPlan == null) {
      throw StateError('A valid Qaza plan could not be calculated.');
    }

    final oldRevision = await _revisionRepository.latest(userId);
    final oldLedgerFingerprint =
        oldRevision?.ledgerPlanFingerprint ?? 
        (oldProfilePlan == null ? null : planFingerprint(oldProfilePlan));
    final calculationChanged =
        oldLedgerFingerprint == null ||
        oldLedgerFingerprint != planFingerprint(newPlan);

    if (!calculationChanged) {
      return ProfileQazaPlanPreview(
        oldPlan: oldProfilePlan,
        newPlan: newPlan,
        oldRevision: oldRevision,
        calculationChanged: false,
        existingCompletedInNewPlan: 0,
        pendingToAdd: 0,
        recordsToRemove: const [],
        recordsToRestore: const [],
      );
    }

    final records = await _loadRecordsForPlan(userId, newPlan);
    final newPlanKeys = _planKeys(userId, newPlan);
    final existingKeys = <String>{};

    var completed = 0;
    final deletedRecords = <QazaRecord>[];
    for (final record in records) {
      final key = _recordKey(record);
      existingKeys.add(key);
      if (record.status == QazaStatus.completed &&
          newPlanKeys.contains(key)) {
        completed++;
      }
      if (record.status == QazaStatus.deleted) {
        deletedRecords.add(record);
      }
    }

    final generationOperationIds =
        oldRevision?.generationOperationIds ?? const <String>[];

    final generatedPending = await _loadGeneratedPendingRecords(
      userId: userId,
      operationIds: generationOperationIds,
    );

    final recordsToRemove = <QazaRecord>[];
    final seenRemoveIds = <String>{};
    for (final record in generatedPending) {
      final key = _recordKey(record);
      if (newPlanKeys.contains(key)) continue;
      if (!record.createdAt.isAtSameMomentAs(record.updatedAt)) continue;
      if (record.status != QazaStatus.pending) continue;
      if (seenRemoveIds.add(record.id)) {
        recordsToRemove.add(record);
      }
    }

    final recordsToRestore = await _loadRestorableDeletedRecords(
      userId: userId,
      deletedRecords: deletedRecords,
      generationOperationIds: generationOperationIds,
      retirementOperationIds:
          oldRevision?.retirementOperationIds ?? const <String>[],
    );

    final restorableKeys = {
      for (final record in recordsToRestore) _recordKey(record),
    };
    final pendingToAdd = newPlanKeys
        .difference(existingKeys)
        .difference(restorableKeys)
        .length;

    return ProfileQazaPlanPreview(
      oldPlan: oldProfilePlan,
      newPlan: newPlan,
      oldRevision: oldRevision,
      calculationChanged: true,
      existingCompletedInNewPlan: completed,
      pendingToAdd: pendingToAdd,
      recordsToRemove: List.unmodifiable(recordsToRemove),
      recordsToRestore: List.unmodifiable(recordsToRestore),
    );
  }

  Future<ProfileQazaPlanReconciliationResult> apply({
    required String userId,
    required UserProfile newProfile,
    required ProfileQazaPlanPreview preview,
    required ProfileQazaChangeChoice choice,
  }) async {
    final oldLedgerPlan = preview.oldRevision?.ledgerPlan ??
        preview.oldPlan ??
        preview.newPlan;
    final oldGenerationIds =
        preview.oldRevision?.generationOperationIds ?? const <String>[];
    final oldRetirementIds =
        preview.oldRevision?.retirementOperationIds ?? const <String>[];

    if (!preview.calculationChanged) {
      final revision = await _saveRevision(
        userId: userId,
        profile: newProfile,
        plan: preview.newPlan,
        ledgerPlan: oldLedgerPlan,
        generatedOperationId: null,
        generationOperationIds: oldGenerationIds,
        retirementOperationIds: oldRetirementIds,
        decision: QazaPlanLedgerDecision.applied,
      );
      return ProfileQazaPlanReconciliationResult(
        revision: revision,
        added: 0,
        removed: 0,
        restored: 0,
        keptExisting: false,
      );
    }

    final operation = await _operationService.begin(
      userId: userId,
      type: QazaOperationType.profileReconciliation,
      inputSnapshot: _operationSnapshot(
        oldRevision: preview.oldRevision,
        profile: newProfile,
        plan: preview.newPlan,
        pendingToAdd: preview.pendingToAdd,
        pendingToRemove: preview.pendingToRemove,
        pendingToRestore: preview.pendingToRestore,
        choice: choice,
      ),
    );

    if (choice == ProfileQazaChangeChoice.keepExisting) {
      try {
        await _operationService.finish(
          operation,
          status: QazaOperationStatus.completed,
          affectedRecordCount: 0,
          note: 'Profile changed; existing Qaza records were kept.',
        );
        final revision = await _saveRevision(
          userId: userId,
          profile: newProfile,
          plan: preview.newPlan,
          ledgerPlan: oldLedgerPlan,
          generatedOperationId: null,
          generationOperationIds: oldGenerationIds,
          retirementOperationIds: oldRetirementIds,
          decision: QazaPlanLedgerDecision.keptExisting,
        );
        return ProfileQazaPlanReconciliationResult(
          revision: revision,
          added: 0,
          removed: 0,
          restored: 0,
          keptExisting: true,
        );
      } catch (error) {
        try {
          await _operationService.finish(
            operation,
            status: QazaOperationStatus.failed,
            affectedRecordCount: 0,
            note: error.toString(),
          );
        } catch (_) {}
        rethrow;
      }
    }

    final recovery = _qazaService.repository is QazaRecoveryRepository
        ? _qazaService.repository as QazaRecoveryRepository
        : null;
    if (recovery == null) {
      await _operationService.finish(
        operation,
        status: QazaOperationStatus.failed,
        affectedRecordCount: 0,
        note: 'Qaza recovery is unavailable on the active repository.',
      );
      throw StateError('Qaza recovery is unavailable.');
    }

    final removedRecords = <QazaRecord>[];
    final restoredRecords = <QazaRecord>[];
    var added = 0;

    try {
      // Restore only records that this app previously retired during profile
      // reconciliation and whose tombstone timestamp still matches that
      // retirement operation. Manual deletions remain untouched.
      final currentRestoreCandidates =
          await _qazaService.repository.getRecordsByIds(
        userId: userId,
        recordIds: [
          for (final record in preview.recordsToRestore) record.id,
        ],
      );
      final currentById = {
        for (final record in currentRestoreCandidates) record.id: record,
      };
      final safeRestoreIds = <String>[];
      for (final expected in preview.recordsToRestore) {
        final current = currentById[expected.id];
        if (current == null) continue;
        if (current.status != QazaStatus.deleted) continue;
        if (!current.updatedAt.isAtSameMomentAs(expected.updatedAt)) continue;
        safeRestoreIds.add(current.id);
      }
      if (safeRestoreIds.isNotEmpty) {
        restoredRecords.addAll(
          await recovery.restoreDeletedRecords(
            userId: userId,
            recordIds: safeRestoreIds,
            restoredAt: DateTime.now(),
            operationId: operation.operationId,
          ).then(
            (_) async => _qazaService.repository.getRecordsByIds(
              userId: userId,
              ids: safeRestoreIds,
            ),
          ),
        );
      }

      if (preview.pendingToAdd > 0) {
        final importResult = await _qazaService.importQazaForDates(
          userId: userId,
          dates: _planDates(preview.newPlan),
          prayerTypes: _planPrayerTypes(preview.newPlan),
          operationId: operation.operationId,
          operationCreatedAt: operation.createdAt,
          witrAllowed: preview.newPlan.includeWitr,
        );
        added = importResult.added;
        if (importResult.cancelled) {
          throw StateError('Qaza plan update was cancelled.');
        }
      }

      final groups = <int, List<String>>{};
      for (final record in preview.recordsToRemove) {
        groups
            .putIfAbsent(record.createdAt.microsecondsSinceEpoch, () => [])
            .add(record.id);
      }

      for (final entry in groups.entries) {
        final expectedCreatedAt = preview.recordsToRemove.firstWhere(
          (record) =>
              record.createdAt.microsecondsSinceEpoch == entry.key,
        ).createdAt;
        removedRecords.addAll(
          await recovery.softDeletePendingIfUnchanged(
            userId: userId,
            recordIds: entry.value,
            expectedCreatedAt: expectedCreatedAt,
            deletedAt: operation.createdAt,
            operationId: operation.operationId,
          ),
        );
      }

      final nextGenerationIds = <String>{...oldGenerationIds};
      if (added > 0) {
        nextGenerationIds.add(operation.operationId);
      }

      final nextRetirementIds = <String>{...oldRetirementIds};
      if (removedRecords.isNotEmpty) {
        nextRetirementIds.add(operation.operationId);
      }

      await _operationService.finish(
        operation,
        status: QazaOperationStatus.completed,
        affectedRecordCount:
            added + removedRecords.length + restoredRecords.length,
        note: 'Profile Qaza plan reconciled.',
      );

      final revision = await _saveRevision(
        userId: userId,
        profile: newProfile,
        plan: preview.newPlan,
        ledgerPlan: preview.newPlan,
        generatedOperationId: added > 0 ? operation.operationId : null,
        generationOperationIds: nextGenerationIds,
        retirementOperationIds: nextRetirementIds,
        decision: QazaPlanLedgerDecision.applied,
      );

      return ProfileQazaPlanReconciliationResult(
        revision: revision,
        added: added,
        removed: removedRecords.length,
        restored: restoredRecords.length,
        keptExisting: false,
      );
    } catch (error) {
      try {
        if (added > 0) {
          await recovery.removeAddition(
            userId: userId,
            operationId: operation.operationId,
            expectedCreatedAt: operation.createdAt,
            deletedAt: DateTime.now(),
          );
        }
        if (removedRecords.isNotEmpty) {
          await recovery.restoreDeletedRecords(
            userId: userId,
            recordIds: [
              for (final record in removedRecords) record.id,
            ],
            restoredAt: DateTime.now(),
            operationId: operation.operationId,
          );
        }
        if (restoredRecords.isNotEmpty) {
          await recovery.softDeleteRecords(
            userId: userId,
            recordIds: [
              for (final record in restoredRecords) record.id,
            ],
            deletedAt: DateTime.now(),
            operationId: operation.operationId,
          );
        }
      } catch (_) {
        // Preserve the original failure.
      }

      try {
        await _operationService.finish(
          operation,
          status: QazaOperationStatus.failed,
          affectedRecordCount:
              added + removedRecords.length + restoredRecords.length,
          note: error.toString(),
        );
      } catch (_) {}
      rethrow;
    }
  }

  Future<QazaPlanRevision> recordInitialPlan({
    required String userId,
    required UserProfile profile,
    required QazaPlan plan,
    String? generatedOperationId,
  }) {
    return _saveRevision(
      userId: userId,
      profile: profile,
      plan: plan,
      ledgerPlan: plan,
      generatedOperationId: generatedOperationId,
      generationOperationIds: generatedOperationId == null
          ? const <String>[]
          : [generatedOperationId],
      retirementOperationIds: const <String>[],
      decision: QazaPlanLedgerDecision.applied,
    );
  }

  static String planFingerprint(QazaPlan plan) {
    return [
      'qazaPlanV1',
      QazaDate.key(plan.startDate),
      QazaDate.key(plan.endDate),
      plan.totalDays,
      plan.includeWitr,
      plan.totalWithWitr,
    ].join('|');
  }

  static Map<String, dynamic> profileSnapshot(UserProfile profile) => {
        'gender': profile.gender?.name,
        'madhab': profile.madhab?.name,
        'dateOfBirth': profile.dateOfBirth?.toIso8601String(),
        'pubertyAge': profile.pubertyAge,
        'startPrayingAge': profile.startPrayingAge,
        'effectiveWitr': ProfileRules.effectiveWitr(profile),
      };

  Future<QazaPlanRevision> _saveRevision({
    required String userId,
    required UserProfile profile,
    required QazaPlan plan,
    required QazaPlan ledgerPlan,
    required String? generatedOperationId,
    required Iterable<String> generationOperationIds,
    required Iterable<String> retirementOperationIds,
    required QazaPlanLedgerDecision decision,
  }) async {
    final now = DateTime.now();
    final revisionId = generatedOperationId == null
        ? 'rev_${now.microsecondsSinceEpoch}_${Random().nextInt(1 << 30).toRadixString(36)}'
        : 'rev_$generatedOperationId';
    final revision = QazaPlanRevision.fromPlan(
      revisionId: revisionId,
      userId: userId,
      createdAt: now,
      plan: plan,
      planFingerprint: planFingerprint(plan),
      profileSnapshot: profileSnapshot(profile),
      generationOperationIds: generationOperationIds,
      retirementOperationIds: retirementOperationIds,
      ledgerDecision: decision,
      generatedOperationId: generatedOperationId,
      ledgerPlan: ledgerPlan,
      ledgerPlanFingerprint: planFingerprint(ledgerPlan),
    );
    await _revisionRepository.save(revision);
    return revision;
  }

  Future<List<QazaRecord>> _loadRecordsForPlan(
    String userId,
    QazaPlan plan,
  ) async {
    if (plan.totalDays <= 0) return const <QazaRecord>[];
    final lastDate = planDateAt(plan, plan.totalDays - 1);
    final records = <QazaRecord>[
      ...await _loadPagedRecords(
        userId: userId,
        from: plan.startDate,
        to: lastDate,
      ),
      ...await _loadPagedRecords(
        userId: userId,
        from: plan.startDate,
        to: lastDate,
        status: QazaStatus.deleted,
      ),
    ];
    final unique = <String, QazaRecord>{};
    for (final record in records) {
      unique[record.id] = record;
    }
    return unique.values.toList(growable: false);
  }

  Future<List<QazaRecord>> _loadPagedRecords({
    required String userId,
    required DateTime from,
    required DateTime to,
    QazaStatus? status,
  }) async {
    final records = <QazaRecord>[];
    DateTime? cursorDate;
    String? cursorId;
    while (true) {
      final page = await _qazaService.repository.getPage(
        userId: userId,
        limit: 500,
        status: status,
        from: from,
        to: to,
        afterOriginalDate: cursorDate,
        afterId: cursorId,
      );
      records.addAll(page.records);
      if (!page.hasMore) break;
      cursorDate = page.nextOriginalDate;
      cursorId = page.nextId;
    }
    return records;
  }

  Future<List<QazaRecord>> _loadGeneratedPendingRecords({
    required String userId,
    required Iterable<String> operationIds,
  }) async {
    if (operationIds.isEmpty) return const <QazaRecord>[];
    final recovery = _qazaService.repository is QazaRecoveryRepository
        ? _qazaService.repository as QazaRecoveryRepository
        : null;
    if (recovery == null) {
      throw StateError('Qaza recovery is unavailable.');
    }

    final records = <QazaRecord>[];
    for (final operationId in operationIds.toSet()) {
      DateTime? cursorDate;
      String? cursorId;
      while (true) {
        final page = await recovery.getOperationPage(
          userId: userId,
          operationId: operationId,
          matchLastAction: false,
          operationAt: DateTime.fromMillisecondsSinceEpoch(0),
          status: QazaStatus.pending,
          limit: 500,
          beforeOriginalDate: cursorDate,
          beforeId: cursorId,
        );
        records.addAll(page.records);
        if (!page.hasMore) break;
        cursorDate = page.nextOriginalDate;
        cursorId = page.nextId;
      }
    }
    return records;
  }

  Future<List<QazaRecord>> _loadRestorableDeletedRecords({
    required String userId,
    required List<QazaRecord> deletedRecords,
    required Iterable<String> generationOperationIds,
    required Iterable<String> retirementOperationIds,
  }) async {
    if (deletedRecords.isEmpty ||
        generationOperationIds.isEmpty ||
        retirementOperationIds.isEmpty) {
      return const <QazaRecord>[];
    }

    final generationIds = generationOperationIds.toSet();
    final retirementTimes = <int>{};
    for (final operationId in retirementOperationIds.toSet()) {
      final operation = await _operationService.repository.get(
        userId,
        operationId,
      );
      if (operation?.type == QazaOperationType.profileReconciliation) {
        retirementTimes.add(operation!.createdAt.microsecondsSinceEpoch);
      }
    }

    if (retirementTimes.isEmpty) return const <QazaRecord>[];

    return [
      for (final record in deletedRecords)
        if (record.operationId != null &&
            generationIds.contains(record.operationId) &&
            retirementTimes.contains(
              record.updatedAt.microsecondsSinceEpoch,
            ))
          record,
    ];
  }

  static DateTime planDateAt(QazaPlan plan, int offset) =>
      plan.startDate.add(Duration(days: offset));

  static Iterable<DateTime> _planDates(QazaPlan plan) sync* {
    for (var offset = 0; offset < plan.totalDays; offset++) {
      yield planDateAt(plan, offset);
    }
  }

  static List<PrayerType> _planPrayerTypes(QazaPlan plan) => [
        PrayerType.fajr,
        PrayerType.zuhr,
        PrayerType.asr,
        PrayerType.maghrib,
        PrayerType.isha,
        if (plan.includeWitr) PrayerType.witr,
      ];

  static Set<String> _planKeys(String userId, QazaPlan plan) {
    final result = <String>{};
    for (var offset = 0; offset < plan.totalDays; offset++) {
      final date = planDateAt(plan, offset);
      for (final prayer in _planPrayerTypes(plan)) {
        result.add('${userId}_${prayer.name}_${QazaDate.key(date)}');
      }
    }
    return result;
  }

  static String _recordKey(QazaRecord record) =>
      '${record.userId}_${record.prayerType.name}_${QazaDate.key(record.originalDate)}';

  static Map<String, dynamic> _operationSnapshot({
    required QazaPlanRevision? oldRevision,
    required UserProfile profile,
    required QazaPlan plan,
    required int pendingToAdd,
    required int pendingToRemove,
    required int pendingToRestore,
    required ProfileQazaChangeChoice choice,
  }) =>
      {
        'version': 2,
        'choice': choice.name,
        'oldRevisionId': oldRevision?.revisionId,
        'oldLedgerPlanFingerprint': oldRevision?.ledgerPlanFingerprint,
        'profile': profileSnapshot(profile),
        'plan': {
          'startDate': plan.startDate.toIso8601String(),
          'endDate': plan.endDate.toIso8601String(),
          'totalDays': plan.totalDays,
          'includeWitr': plan.includeWitr,
          'totalPrayers': plan.totalPrayers,
          'totalWithWitr': plan.totalWithWitr,
          'fingerprint': planFingerprint(plan),
        },
        'pendingToAdd': pendingToAdd,
        'pendingToRemove': pendingToRemove,
        'pendingToRestore': pendingToRestore,
      };
}
