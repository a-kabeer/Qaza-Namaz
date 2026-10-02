import 'dart:math';

import '../../core/constants/prayer_types.dart';
import '../../core/utils/qaza_date.dart';
import '../entities/qaza_plan_revision.dart';
import '../entities/qaza_record.dart';
import '../entities/user_profile.dart';
import '../repositories/qaza_plan_revision_repository.dart';
import '../repositories/qaza_profile_plan_mutation_repository.dart';
import 'profile_rules.dart';
import 'qaza_plan_service.dart';
import 'qaza_service.dart';

enum ProfileQazaChangeChoice {
  apply,
}

class ProfileQazaPlanPreview {
  const ProfileQazaPlanPreview({
    required this.oldPlan,
    required this.newPlan,
    required this.oldRevision,
    required this.previousProfileSnapshot,
    required this.calculationChanged,
    required this.existingCompletedInNewPlan,
    required this.pendingToAdd,
    required this.pendingToRemove,
    required this.pendingAdditionKeys,
    required this.removalRecordIds,
  });

  final QazaPlan? oldPlan;
  final QazaPlan newPlan;
  final QazaPlanRevision? oldRevision;
  final Map<String, dynamic> previousProfileSnapshot;
  final bool calculationChanged;
  final int existingCompletedInNewPlan;
  final int pendingToAdd;
  final int pendingToRemove;
  final List<QazaPrayerKey> pendingAdditionKeys;
  final List<String> removalRecordIds;

  QazaPlan? get previousLedgerPlan => oldRevision?.ledgerPlan ?? oldPlan;
  int get newPlanTotal => newPlan.totalWithWitr;
  bool get hasLedgerChanges => pendingToAdd > 0 || pendingToRemove > 0;

  bool get ledgerPlanChanged =>
      previousLedgerPlan == null ||
      ProfileQazaPlanReconciliationService.planFingerprint(
            previousLedgerPlan!,
          ) !=
          ProfileQazaPlanReconciliationService.planFingerprint(newPlan);

  /// Every calculated-plan change requires the user to explicitly apply or
  /// cancel, including decrease-only and mixed changes.
  bool get requiresUserDecision => calculationChanged;
}

class ProfileQazaPlanReconciliationResult {
  const ProfileQazaPlanReconciliationResult({
    required this.revision,
    required this.added,
    required this.removed,
  });

  final QazaPlanRevision revision;
  final int added;
  final int removed;
}

class ProfileQazaPlanReconciliationService {
  ProfileQazaPlanReconciliationService({
    required QazaPlanService planService,
    required QazaService qazaService,
    required QazaPlanRevisionRepository revisionRepository,
    required QazaProfilePlanMutationRepository mutationRepository,
  })  : _planService = planService,
        _qazaService = qazaService,
        _revisionRepository = revisionRepository,
        _mutationRepository = mutationRepository;

  final QazaPlanService _planService;
  final QazaService _qazaService;
  final QazaPlanRevisionRepository _revisionRepository;
  final QazaProfilePlanMutationRepository _mutationRepository;

  Future<ProfileQazaPlanPreview> preview({
    required String userId,
    required UserProfile oldProfile,
    required UserProfile newProfile,
  }) async {
    final oldPlan = _planService.planFor(oldProfile);
    final newPlan = _planService.planFor(newProfile);
    if (newPlan == null) {
      throw StateError('A valid Qaza plan could not be calculated.');
    }

    final oldRevision = await _revisionRepository.latest(userId);
    final previousCalculationFingerprint =
        oldRevision?.planFingerprint ??
        (oldPlan == null ? null : planFingerprint(oldPlan));
    final calculationChanged =
        previousCalculationFingerprint == null ||
        previousCalculationFingerprint != planFingerprint(newPlan);

    if (!calculationChanged) {
      return ProfileQazaPlanPreview(
        oldPlan: oldPlan,
        newPlan: newPlan,
        oldRevision: oldRevision,
        previousProfileSnapshot: profileSnapshot(oldProfile),
        calculationChanged: false,
        existingCompletedInNewPlan: 0,
        pendingToAdd: 0,
        pendingToRemove: 0,
        pendingAdditionKeys: const [],
        removalRecordIds: const [],
      );
    }

    final analysis = await _qazaService.analyzeAvailability(
      userId: userId,
      dates: QazaPlanService.datesFor(newPlan),
      prayerTypes: _planPrayerTypes(newPlan),
    );

    final newPlanKeys = _planKeys(userId, newPlan);
    final removalIds = <String>[];

    DateTime? cursorDate;
    String? cursorId;
    while (true) {
      final page = await _qazaService.repository.getPage(
        userId: userId,
        limit: 500,
        status: QazaStatus.pending,
        afterOriginalDate: cursorDate,
        afterId: cursorId,
      );
      for (final record in page.records) {
        if (record.profilePlanRevisionId == null ||
            record.profilePlanFingerprint == null) {
          continue;
        }
        if (!newPlanKeys.contains(_recordKey(record))) {
          removalIds.add(record.id);
        }
      }
      if (!page.hasMore) break;
      cursorDate = page.nextOriginalDate;
      cursorId = page.nextId;
    }

    return ProfileQazaPlanPreview(
      oldPlan: oldPlan,
      newPlan: newPlan,
      oldRevision: oldRevision,
      previousProfileSnapshot: profileSnapshot(oldProfile),
      calculationChanged: true,
      existingCompletedInNewPlan: analysis.alreadyCompleted,
      pendingToAdd: analysis.newCandidates.length,
      pendingToRemove: removalIds.length,
      pendingAdditionKeys: List.unmodifiable(analysis.newCandidates),
      removalRecordIds: List.unmodifiable(removalIds),
    );
  }

  Future<ProfileQazaPlanReconciliationResult> apply({
    required String userId,
    required UserProfile newProfile,
    required ProfileQazaPlanPreview preview,
    required ProfileQazaChangeChoice choice,
  }) async {
    if (choice != ProfileQazaChangeChoice.apply) {
      throw StateError('A changed Qaza plan must be explicitly applied.');
    }
    if (!preview.calculationChanged) {
      throw StateError('There is no calculated Qaza plan change to apply.');
    }

    final revisionId = newRevisionId();
    final newFingerprint = planFingerprint(preview.newPlan);
    final now = DateTime.now();
    final additions = [
      for (final key in preview.pendingAdditionKeys)
        QazaRecord(
          id: key.value,
          userId: userId,
          prayerType: key.prayerType,
          originalDate: QazaDate.normalize(key.date),
          status: QazaStatus.pending,
          profilePlanRevisionId: revisionId,
          profilePlanFingerprint: newFingerprint,
          createdAt: now,
          updatedAt: now,
        ),
    ];

    final previousLedgerFingerprint =
        preview.previousLedgerPlan == null
            ? newFingerprint
            : planFingerprint(preview.previousLedgerPlan!);

    final mutation = await _mutationRepository.applyProfilePlanChanges(
      userId: userId,
      additions: additions,
      removalIds: preview.removalRecordIds,
      newPlanKeys: _planKeys(userId, preview.newPlan),
      expectedPreviousPlanFingerprint: previousLedgerFingerprint,
    );

    try {
      final revision = await _saveRevision(
        revisionId: revisionId,
        userId: userId,
        previousProfileSnapshot: preview.previousProfileSnapshot,
        profile: newProfile,
        plan: preview.newPlan,
        ledgerPlan: preview.newPlan,
        decision: QazaPlanLedgerDecision.applied,
        addedRecords: mutation.addedCount,
        removedRecords: mutation.removedCount,
        changedFields: changedProfileFields(
          preview.previousProfileSnapshot,
          profileSnapshot(newProfile),
        ),
      );

      return ProfileQazaPlanReconciliationResult(
        revision: revision,
        added: mutation.addedCount,
        removed: mutation.removedCount,
      );
    } catch (_) {
      await _mutationRepository.rollbackProfilePlanChanges(mutation);
      rethrow;
    }
  }

  Future<QazaPlanRevision> recordInitialPlan({
    required String userId,
    required UserProfile profile,
    required QazaPlan plan,
    String? revisionId,
  }) {
    return _saveRevision(
      revisionId: revisionId ?? newRevisionId(),
      userId: userId,
      previousProfileSnapshot: const {},
      profile: profile,
      plan: plan,
      ledgerPlan: plan,
      decision: QazaPlanLedgerDecision.applied,
      addedRecords: 0,
      removedRecords: 0,
      changedFields: const [],
    );
  }

  Future<QazaPlanRevision> _saveRevision({
    required String revisionId,
    required String userId,
    required UserProfile profile,
    required Map<String, dynamic> previousProfileSnapshot,
    required QazaPlan plan,
    required QazaPlan ledgerPlan,
    required QazaPlanLedgerDecision decision,
    required int addedRecords,
    required int removedRecords,
    required List<String> changedFields,
  }) async {
    final revision = QazaPlanRevision.fromPlan(
      revisionId: revisionId,
      userId: userId,
      createdAt: DateTime.now(),
      plan: plan,
      planFingerprint: planFingerprint(plan),
      profileSnapshot: profileSnapshot(profile),
      previousProfileSnapshot: previousProfileSnapshot,
      changedFields: changedFields,
      addedRecords: addedRecords,
      removedRecords: removedRecords,
      ledgerDecision: decision,
      ledgerPlan: ledgerPlan,
      ledgerPlanFingerprint: planFingerprint(ledgerPlan),
    );
    await _revisionRepository.save(revision);
    return revision;
  }

  static String newRevisionId() {
    final now = DateTime.now();
    return 'rev_${now.microsecondsSinceEpoch}_'
        '${Random().nextInt(1 << 30).toRadixString(36)}';
  }

  static String _recordKey(QazaRecord record) =>
      '${record.userId}_${record.prayerType.name}_'
      '${QazaDate.key(record.originalDate)}';

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
      final date = QazaPlanService.planDateAt(plan, offset);
      for (final prayer in _planPrayerTypes(plan)) {
        result.add(
          '${userId}_${prayer.name}_${QazaDate.key(date)}',
        );
      }
    }
    return result;
  }

  /// Versioned fingerprint for the active fixed 30/360 calculation scheme.
  ///
  /// Legacy V1 fingerprints intentionally remain distinct so an existing
  /// real-calendar revision cannot be authorized for automatic deletion.
  static String planFingerprint(QazaPlan plan) {
    return [
      'qazaPlanV2Fixed360',
      QazaDate.key(plan.startDate),
      QazaDate.key(plan.endDate),
      plan.totalDays,
      plan.includeWitr,
      plan.totalWithWitr,
    ].join('|');
  }

  static List<String> changedProfileFields(
    Map<String, dynamic> previous,
    Map<String, dynamic> next,
  ) {
    const keys = [
      'gender',
      'madhab',
      'dateOfBirth',
      'pubertyAge',
      'startPrayingAge',
      'effectiveWitr',
    ];
    return [
      for (final key in keys)
        if (previous[key] != next[key]) key,
    ];
  }

  static Map<String, dynamic> profileSnapshot(UserProfile profile) => {
        'gender': profile.gender?.name,
        'madhab': profile.madhab?.name,
        'dateOfBirth': profile.dateOfBirth?.toIso8601String(),
        'pubertyAge': profile.pubertyAge,
        'startPrayingAge': profile.startPrayingAge,
        'effectiveWitr': ProfileRules.effectiveWitr(profile),
      };
}
