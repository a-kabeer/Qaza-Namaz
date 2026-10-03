import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/native.dart';

import 'package:qaza_namaz/core/diagnostics/diagnostics.dart';
import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/core/utils/qaza_date.dart';
import 'package:qaza_namaz/data/local/database/app_database.dart';
import 'package:qaza_namaz/data/local/drift_qaza_local_store.dart';
import 'package:qaza_namaz/data/local/qaza_plan_revision_repository.dart';
import 'package:qaza_namaz/data/local/user_profile_repository.dart';
import 'package:qaza_namaz/data/repositories/offline_first_qaza_repository.dart';
import 'package:qaza_namaz/domain/entities/qaza_plan_revision.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';
import 'package:qaza_namaz/domain/entities/user_profile.dart';
import 'package:qaza_namaz/domain/services/profile_qaza_plan_reconciliation_service.dart';
import 'package:qaza_namaz/domain/services/qaza_plan_service.dart';
import 'package:qaza_namaz/domain/services/qaza_service.dart';
import 'package:qaza_namaz/domain/services/save_profile_use_case.dart';

const _userId = UserProfile.localLedgerUserId;

UserProfile _profile({
  DateTime? dob,
  int pubertyAge = 12,
  int startPrayingAge = 14,
}) => UserProfile(
      languageCode: 'en',
      gender: Gender.male,
      madhab: Madhab.other,
      dateOfBirth: dob ?? DateTime(1990, 1, 1),
      pubertyAge: pubertyAge,
      startPrayingAge: startPrayingAge,
      witrIncluded: false,
      onboardingCompleted: true,
    );

String _key(PrayerType prayer, DateTime date) =>
    _userId + '_' + prayer.name + '_' + QazaDate.key(date);

String _recordId(int offset, PrayerType prayer) =>
    offset.toString().padLeft(4, '0') + '_' + prayer.name;

class _Harness {
  _Harness({
    required this.database,
    required this.qaza,
    required this.profiles,
    required this.useCase,
    required this.diagnostics,
  });

  final AppDatabase database;
  final OfflineFirstQazaRepository qaza;
  final SharedPreferencesUserProfileRepository profiles;
  final SaveProfileUseCase useCase;
  final BufferedDiagnostics diagnostics;

  Future<void> dispose() => database.close();
}

Future<_Harness> _createHarness({
  required UserProfile oldProfile,
  required int missingOffset,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final profiles = SharedPreferencesUserProfileRepository(preferences: prefs);
  await profiles.save(oldProfile);

  final database = AppDatabase(NativeDatabase.memory());
  final store = DriftQazaLocalStore(database: database);
  final qaza = OfflineFirstQazaRepository(localStore: store);
  await qaza.setActiveUser(_userId);

  final revisions = SharedPreferencesQazaPlanRevisionRepository();
  final plan = const QazaPlanService().planFor(oldProfile)!;
  final fingerprint =
      ProfileQazaPlanReconciliationService.planFingerprint(plan);
  await revisions.save(
    QazaPlanRevision.fromPlan(
      revisionId: 'old-revision',
      userId: _userId,
      createdAt: DateTime(2026, 10, 1),
      plan: plan,
      planFingerprint: fingerprint,
      profileSnapshot:
          ProfileQazaPlanReconciliationService.profileSnapshot(oldProfile),
      ledgerDecision: QazaPlanLedgerDecision.applied,
      ledgerPlan: plan,
      ledgerPlanFingerprint: fingerprint,
    ),
  );

  final records = <QazaRecord>[];
  for (var offset = 0; offset < plan.totalDays; offset++) {
    final date = QazaPlanService.planDateAt(plan, offset);
    for (final prayer in const [
      PrayerType.fajr,
      PrayerType.zuhr,
      PrayerType.asr,
      PrayerType.maghrib,
      PrayerType.isha,
    ]) {
      if (offset == missingOffset && prayer == PrayerType.fajr) {
        continue;
      }

      final isCompleted = offset == 250 && prayer == PrayerType.fajr;
      final isManual = offset == 250 && prayer == PrayerType.zuhr;

      records.add(
        QazaRecord(
          id: _recordId(offset, prayer),
          userId: _userId,
          prayerType: prayer,
          originalDate: date,
          status: isCompleted ? QazaStatus.completed : QazaStatus.pending,
          completedAt: isCompleted
              ? DateTime(2026, 10, 1, 12)
              : null,
          completionId: isCompleted ? 'protected-completion' : null,
          profilePlanRevisionId: isManual ? null : 'old-revision',
          profilePlanFingerprint: isManual ? null : fingerprint,
          createdAt: DateTime(2026, 10, 1),
          updatedAt: DateTime(2026, 10, 1),
        ),
      );
    }
  }
  await store.appendRecords(_userId, records);

  final diagnostics = BufferedDiagnostics();
  final reconciliation = ProfileQazaPlanReconciliationService(
    planService: const QazaPlanService(),
    qazaService: QazaService(
      qaza,
      witrInclusionResolver: () => false,
    ),
    revisionRepository: revisions,
    mutationRepository: qaza,
  );
  final useCase = SaveProfileUseCase(
    profileRepository: profiles,
    reconciliationService: reconciliation,
    diagnostics: diagnostics,
  );

  return _Harness(
    database: database,
    qaza: qaza,
    profiles: profiles,
    useCase: useCase,
    diagnostics: diagnostics,
  );
}

void main() {
  test(
    'settings save traverses all pending pages for DOB, puberty age, and start-praying age changes',
    () async {
      final cases = [
        (
          name: 'DOB',
          oldProfile: _profile(),
          newProfile: _profile(dob: DateTime(1991, 1, 1)),
          missingOffset: 400,
          expectedTotalDays: 720,
          expectedMissingOffset: 400,
        ),
        (
          name: 'puberty age',
          oldProfile: _profile(),
          newProfile: _profile(pubertyAge: 13),
          missingOffset: 400,
          expectedTotalDays: 360,
          expectedMissingOffset: 400,
        ),
        (
          name: 'start-praying age',
          oldProfile: _profile(),
          newProfile: _profile(startPrayingAge: 13),
          missingOffset: 100,
          expectedTotalDays: 360,
          expectedMissingOffset: 100,
        ),
      ];

      for (final testCase in cases) {
        final harness = await _createHarness(
          oldProfile: testCase.oldProfile,
          missingOffset: testCase.missingOffset,
        );

        try {
          final preview = await harness.useCase.prepareSettingsSave(
            newProfile: testCase.newProfile,
          );

          expect(preview.calculationChanged, isTrue);
          expect(preview.newPlan.totalDays, testCase.expectedTotalDays);
          expect(preview.pendingToRemove, greaterThan(500));
          expect(preview.pendingToAdd, greaterThan(0));
          expect(harness.diagnostics.events, isEmpty);

          final result = await harness.useCase.saveSettings(
            newProfile: testCase.newProfile,
            preview: preview,
            choice: ProfileQazaChangeChoice.apply,
          );

          expect(result.qazaPlanChanged, isTrue);
          expect(result.revision, isNotNull);
          expect(result.qazaRecordsRemoved, greaterThan(500));
          expect(result.qazaRecordsAdded, greaterThan(0));

          final savedProfile = await harness.profiles.load();
          expect(savedProfile?.dateOfBirth, testCase.newProfile.dateOfBirth);
          expect(savedProfile?.pubertyAge, testCase.newProfile.pubertyAge);
          expect(savedProfile?.startPrayingAge, testCase.newProfile.startPrayingAge);

          final oldPlan = const QazaPlanService().planFor(
            testCase.oldProfile,
          )!;
          final missingDate = QazaPlanService.planDateAt(
            oldPlan,
            testCase.expectedMissingOffset,
          );
          final missingKey = _key(PrayerType.fajr, missingDate);
          expect(
            preview.pendingAdditionKeys.map((key) => key.value),
            contains(missingKey),
          );

          final restored = await harness.qaza.getRecordsByIds(
            userId: _userId,
            recordIds: [missingKey],
          );
          expect(restored, hasLength(1));
          expect(restored.single.status, QazaStatus.pending);
          expect(
            restored.single.profilePlanFingerprint,
            ProfileQazaPlanReconciliationService.planFingerprint(
              preview.newPlan,
            ),
          );
          expect(restored.single.profilePlanRevisionId, isNotNull);

          final protectedRecords = await harness.qaza.getRecordsByIds(
            userId: _userId,
            recordIds: [
              _recordId(250, PrayerType.fajr),
              _recordId(250, PrayerType.zuhr),
            ],
          );
          expect(protectedRecords, hasLength(2));
          expect(
            protectedRecords
                .firstWhere((record) => record.id == _recordId(250, PrayerType.fajr))
                .status,
            QazaStatus.completed,
          );
          expect(
            protectedRecords
                .firstWhere((record) => record.id == _recordId(250, PrayerType.zuhr))
                .profilePlanFingerprint,
            isNull,
          );
        } finally {
          await harness.dispose();
        }
      }
    },
  );

  test(
    'prepareSettingsSave records diagnostics while keeping technical errors out of the user-facing layer',
    () async {
      final harness = await _createHarness(
        oldProfile: _profile(),
        missingOffset: 100,
      );

      try {
        final invalidProfile = _profile(dob: null).copyWith(
          clearDateOfBirth: true,
        );

        await expectLater(
          harness.useCase.prepareSettingsSave(newProfile: invalidProfile),
          throwsStateError,
        );

        final failures = harness.diagnostics.events.where(
          (event) => event.code == 'profile_settings_prepare_failed',
        );
        expect(failures, hasLength(1));
        expect(failures.single.errorType, 'StateError');
      } finally {
        await harness.dispose();
      }
    },
  );
}