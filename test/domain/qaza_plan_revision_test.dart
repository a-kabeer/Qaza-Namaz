import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/domain/entities/qaza_plan_revision.dart';
import 'package:qaza_namaz/domain/entities/user_profile.dart';
import 'package:qaza_namaz/domain/services/profile_qaza_plan_reconciliation_service.dart';
import 'package:qaza_namaz/domain/services/qaza_plan_service.dart';

void main() {
  const planService = QazaPlanService();

  test('QazaPlanRevision survives JSON round trip with audit snapshot', () {
    final profile = UserProfile(
      languageCode: 'en',
      gender: Gender.male,
      madhab: Madhab.hanafi,
      dateOfBirth: DateTime(1994, 12, 31),
      pubertyAge: 12,
      startPrayingAge: 15,
      witrIncluded: true,
      onboardingCompleted: true,
    );
    final plan = planService.planFor(profile);
    expect(plan, isNotNull);

    final revision = QazaPlanRevision.fromPlan(
      revisionId: 'rev_test',
      userId: UserProfile.localLedgerUserId,
      createdAt: DateTime(2026, 9, 30, 12),
      plan: plan!,
      planFingerprint:
          ProfileQazaPlanReconciliationService.planFingerprint(plan),
      profileSnapshot:
          ProfileQazaPlanReconciliationService.profileSnapshot(profile),
      ledgerDecision: QazaPlanLedgerDecision.applied,
      ledgerPlan: plan,
      ledgerPlanFingerprint:
          ProfileQazaPlanReconciliationService.planFingerprint(plan),
    );

    final restored = QazaPlanRevision.fromJson(revision.toJson());

    expect(restored.revisionId, revision.revisionId);
    expect(restored.planFingerprint, revision.planFingerprint);
    expect(restored.profileSnapshot, revision.profileSnapshot);
    expect(restored.ledgerDecision, QazaPlanLedgerDecision.applied);
    expect(restored.ledgerPlanFingerprint, revision.ledgerPlanFingerprint);
  });

  test('revision preserves profile-change audit metadata', () {
    final profile = UserProfile(
      gender: Gender.male,
      madhab: Madhab.hanafi,
      dateOfBirth: DateTime(1994, 12, 31),
      pubertyAge: 12,
      startPrayingAge: 15,
      witrIncluded: true,
      onboardingCompleted: true,
    );
    final previous = {
      ...ProfileQazaPlanReconciliationService.profileSnapshot(profile),
      'startPrayingAge': 14,
    };
    final plan = planService.planFor(profile)!;

    final revision = QazaPlanRevision.fromPlan(
      revisionId: 'rev_audit',
      userId: UserProfile.localLedgerUserId,
      createdAt: DateTime(2026, 10, 1, 12),
      plan: plan,
      planFingerprint:
          ProfileQazaPlanReconciliationService.planFingerprint(plan),
      profileSnapshot:
          ProfileQazaPlanReconciliationService.profileSnapshot(profile),
      previousProfileSnapshot: previous,
      changedFields: const ['startPrayingAge'],
      addedRecords: 25,
      removedRecords: 0,
      ledgerDecision: QazaPlanLedgerDecision.applied,
      ledgerPlan: plan,
      ledgerPlanFingerprint:
          ProfileQazaPlanReconciliationService.planFingerprint(plan),
    );

    final restored = QazaPlanRevision.fromJson(revision.toJson());

    expect(restored.previousProfileSnapshot['startPrayingAge'], 14);
    expect(restored.changedFields, ['startPrayingAge']);
    expect(restored.addedRecords, 25);
    expect(restored.removedRecords, 0);
  });

  test('legacy ledger fingerprint remains distinguishable for history safety', () {
    final profile = UserProfile(
      gender: Gender.male,
      madhab: Madhab.hanafi,
      dateOfBirth: DateTime(1994, 12, 31),
      pubertyAge: 12,
      startPrayingAge: 15,
      witrIncluded: true,
      onboardingCompleted: true,
    );
    final plan = planService.planFor(profile)!;
    final fixedFingerprint =
        ProfileQazaPlanReconciliationService.planFingerprint(plan);
    final legacyFingerprint =
        fixedFingerprint.replaceFirst('qazaPlanV2Fixed360', 'qazaPlanV1');

    final revision = QazaPlanRevision.fromPlan(
      revisionId: 'rev_legacy_history',
      userId: UserProfile.localLedgerUserId,
      createdAt: DateTime(2026, 10, 2, 12),
      plan: plan,
      planFingerprint: fixedFingerprint,
      profileSnapshot:
          ProfileQazaPlanReconciliationService.profileSnapshot(profile),
      ledgerDecision: QazaPlanLedgerDecision.keptExisting,
      ledgerPlan: plan,
      ledgerPlanFingerprint: legacyFingerprint,
    );

    final restored = QazaPlanRevision.fromJson(revision.toJson());

    expect(restored.planFingerprint, fixedFingerprint);
    expect(restored.ledgerPlanFingerprint, legacyFingerprint);
    expect(restored.ledgerPlanFingerprint, isNot(fixedFingerprint));
  });

  test('plan fingerprint represents the effective calculated plan', () {
    final hanafi = UserProfile(
      gender: Gender.male,
      madhab: Madhab.hanafi,
      dateOfBirth: DateTime(2000, 1, 1),
      pubertyAge: 12,
      startPrayingAge: 15,
      witrIncluded: true,
      onboardingCompleted: true,
    );
    final other = hanafi.copyWith(
      madhab: Madhab.other,
      witrIncluded: true,
    );
    final withoutWitr = hanafi.copyWith(
      madhab: Madhab.other,
      witrIncluded: false,
    );

    final first = planService.planFor(hanafi)!;
    final same = planService.planFor(other)!;
    final changed = planService.planFor(withoutWitr)!;

    final firstFingerprint =
        ProfileQazaPlanReconciliationService.planFingerprint(first);
    final legacyFingerprint =
        firstFingerprint.replaceFirst('qazaPlanV2Fixed360', 'qazaPlanV1');
    expect(firstFingerprint, startsWith('qazaPlanV2Fixed360|'));
    expect(
      firstFingerprint,
      ProfileQazaPlanReconciliationService.planFingerprint(same),
    );
    expect(firstFingerprint, isNot(legacyFingerprint));
    expect(
      ProfileQazaPlanReconciliationService.planFingerprint(first),
      isNot(ProfileQazaPlanReconciliationService.planFingerprint(changed)),
    );
  });
}
