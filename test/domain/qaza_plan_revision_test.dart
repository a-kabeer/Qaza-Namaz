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
      generationOperationIds: const ['op_initial'],
      ledgerDecision: QazaPlanLedgerDecision.applied,
      generatedOperationId: 'op_initial',
    );

    final restored = QazaPlanRevision.fromJson(revision.toJson());

    expect(restored.revisionId, revision.revisionId);
    expect(restored.planFingerprint, revision.planFingerprint);
    expect(restored.profileSnapshot, revision.profileSnapshot);
    expect(restored.generationOperationIds, ['op_initial']);
    expect(restored.ledgerDecision, QazaPlanLedgerDecision.applied);
    expect(restored.generatedOperationId, 'op_initial');
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

    expect(
      ProfileQazaPlanReconciliationService.planFingerprint(first),
      ProfileQazaPlanReconciliationService.planFingerprint(same),
    );
    expect(
      ProfileQazaPlanReconciliationService.planFingerprint(first),
      isNot(ProfileQazaPlanReconciliationService.planFingerprint(changed)),
    );
  });
}
