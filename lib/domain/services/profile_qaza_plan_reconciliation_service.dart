import 'dart:math';

import '../../core/constants/prayer_types.dart';
import '../../core/utils/qaza_date.dart';
import '../entities/qaza_plan_revision.dart';
import '../entities/qaza_record.dart';
import '../entities/user_profile.dart';
import '../repositories/qaza_plan_revision_repository.dart';
import 'profile_rules.dart';
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
    required this.previousProfileSnapshot,
    required this.calculationChanged,
    required this.existingCompletedInNewPlan,
    required this.pendingToAdd,
  });

  final QazaPlan? oldPlan;
  final QazaPlan newPlan;
  final QazaPlanRevision? oldRevision;
  final Map<String, dynamic> previousProfileSnapshot;
  final bool calculationChanged;
  final int existingCompletedInNewPlan;
  final int pendingToAdd;

  QazaPlan? get previousLedgerPlan => oldRevision?.ledgerPlan ?? oldPlan;
  int get newPlanTotal => newPlan.totalWithWitr;

  /// Profile edits never silently delete existing Qaza records. Applying a
  /// changed plan only adds missing records for the new plan.
  bool get hasLedgerChanges => pendingToAdd > 0;

  bool get ledgerPlanChanged =>
      oldRevision == null ||
      oldRevision!.ledgerPlanFingerprint !=
          ProfileQazaPlanReconciliationService.planFingerprint(newPlan);

  bool get requiresUserDecision => calculationChanged && hasLedgerChanges;
}

class ProfileQazaPlanReconciliationResult {
  const ProfileQazaPlanReconciliationResult({
    required this.revision,
    required this.added,
    required this.removed,
    required this.keptExisting,
  });

  final QazaPlanRevision revision;
  final int added;
  final int removed;
  final bool keptExisting;
}

class ProfileQazaPlanReconciliationService {
  ProfileQazaPlanReconciliationService({
    required QazaPlanService planService,
    required QazaService qazaService,
    required QazaPlanRevisionRepository revisionRepository,
  })  : _planService = planService,
        _qazaService = qazaService,
        _revisionRepository = revisionRepository;

  final QazaPlanService _planService;
  final QazaService _qazaService;
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
    final previousCalculationFingerprint =
        oldRevision?.planFingerprint ??
        (oldProfilePlan == null ? null : planFingerprint(oldProfilePlan));
    final calculationChanged =
        previousCalculationFingerprint == null ||
        previousCalculationFingerprint != planFingerprint(newPlan);

    if (!calculationChanged) {
      return ProfileQazaPlanPreview(
        oldPlan: oldProfilePlan,
        newPlan: newPlan,
        oldRevision: oldRevision,
        previousProfileSnapshot: profileSnapshot(oldProfile),
        calculationChanged: false,
        existingCompletedInNewPlan: 0,
        pendingToAdd: 0,
      );
    }

    final records = await _loadRecordsForPlan(userId, newPlan);
    final newPlanKeys = _planKeys(userId, newPlan);
    final existingKeys = <String>{};
    var completed = 0;

    for (final record in records) {
      final key = _recordKey(record);
      existingKeys.add(key);
      if (record.status == QazaStatus.completed &&
          newPlanKeys.contains(key)) {
        completed++;
      }
    }

    return ProfileQazaPlanPreview(
      oldPlan: oldProfilePlan,
      newPlan: newPlan,
      oldRevision: oldRevision,
      previousProfileSnapshot: profileSnapshot(oldProfile),
      calculationChanged: true,
      existingCompletedInNewPlan: completed,
      pendingToAdd: newPlanKeys.difference(existingKeys).length,
    );
  }

  Future<ProfileQazaPlanReconciliationResult> apply({
    required String userId,
    required UserProfile newProfile,
    required ProfileQazaPlanPreview preview,
    required ProfileQazaChangeChoice choice,
  }) async {
    final oldLedgerPlan = preview.previousLedgerPlan ?? preview.newPlan;

    if (choice == ProfileQazaChangeChoice.keepExisting &&
        preview.hasLedgerChanges) {
      final revision = await _saveRevision(
        userId: userId,
        profile: newProfile,
        previousProfileSnapshot: preview.previousProfileSnapshot,
        plan: preview.newPlan,
        ledgerPlan: oldLedgerPlan,
        decision: QazaPlanLedgerDecision.keptExisting,
        addedRecords: 0,
        removedRecords: 0,
        changedFields: changedProfileFields(
          preview.previousProfileSnapshot,
          profileSnapshot(newProfile),
        ),
      );
      return ProfileQazaPlanReconciliationResult(
        revision: revision,
        added: 0,
        removed: 0,
        keptExisting: true,
      );
    }

    var added = 0;
    if (choice == ProfileQazaChangeChoice.apply && preview.pendingToAdd > 0) {
      final importResult = await _qazaService.importQazaForDates(
        userId: userId,
        dates: _planDates(preview.newPlan),
        prayerTypes: _planPrayerTypes(preview.newPlan),
        witrAllowed: preview.newPlan.includeWitr,
      );
      if (importResult.cancelled) {
        throw StateError('Qaza plan update was cancelled.');
      }
      added = importResult.added;
    }

    final ledgerPlan =
        choice == ProfileQazaChangeChoice.keepExisting
            ? oldLedgerPlan
            : preview.newPlan;
    final revision = await _saveRevision(
      userId: userId,
      previousProfileSnapshot: preview.previousProfileSnapshot,
      profile: newProfile,
      plan: preview.newPlan,
      ledgerPlan: ledgerPlan,
      decision: choice == ProfileQazaChangeChoice.keepExisting
          ? QazaPlanLedgerDecision.keptExisting
          : QazaPlanLedgerDecision.applied,
      addedRecords: added,
      removedRecords: 0,
      changedFields: changedProfileFields(
        preview.previousProfileSnapshot,
        profileSnapshot(newProfile),
      ),
    );

    return ProfileQazaPlanReconciliationResult(
      revision: revision,
      added: added,
      removed: 0,
      keptExisting: choice == ProfileQazaChangeChoice.keepExisting,
    );
  }

  Future<QazaPlanRevision> recordInitialPlan({
    required String userId,
    required UserProfile profile,
    required QazaPlan plan,
  }) {
    return _saveRevision(
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
    final now = DateTime.now();
    final revisionId =
        'rev_${now.microsecondsSinceEpoch}_${Random().nextInt(1 << 30).toRadixString(36)}';
    final revision = QazaPlanRevision.fromPlan(
      revisionId: revisionId,
      userId: userId,
      createdAt: now,
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

  Future<List<QazaRecord>> _loadRecordsForPlan(
    String userId,
    QazaPlan plan,
  ) async {
    if (plan.totalDays <= 0) return const <QazaRecord>[];
    final lastDate = planDateAt(plan, plan.totalDays - 1);
    return _loadPagedRecords(
      userId: userId,
      from: plan.startDate,
      to: lastDate,
    );
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

  static DateTime planDateAt(QazaPlan plan, int offset) =>
      QazaPlanService.planDateAt(plan, offset);

  static Iterable<DateTime> _planDates(QazaPlan plan) =>
      QazaPlanService.datesFor(plan);

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

  static String _recordKey(QazaRecord record) =>
      '${record.userId}_${record.prayerType.name}_'
      '${QazaDate.key(record.originalDate)}';

  /// Versioned fingerprint for the active fixed 30/360 calculation scheme.
  ///
  /// Legacy V1 fingerprints intentionally remain distinct so an existing
  /// real-calendar revision cannot be mistaken for a fixed-arithmetic plan.
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
