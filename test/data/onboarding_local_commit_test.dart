import 'dart:convert';

import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/data/local/account_local_store.dart';
import 'package:qaza_namaz/data/local/database/app_database.dart';
import 'package:qaza_namaz/domain/entities/qaza_plan_revision.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';
import 'package:qaza_namaz/domain/entities/user_profile.dart';
import 'package:qaza_namaz/domain/services/profile_qaza_plan_reconciliation_service.dart';
import 'package:qaza_namaz/domain/services/qaza_plan_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<(AppDatabase, AccountLocalStore, String)> _setupGoogle() async {
  SharedPreferences.setMockInitialValues({});
  final database = AppDatabase(NativeDatabase.memory());
  final store = AccountLocalStore(database: database);
  await store.ensureInitialized(
    hasLegacyProfile: false,
    hasLegacyQaza: false,
  );
  final accountId = await store.createGooglePartition(
    firebaseUid: 'onboarding-uid',
    email: 'onboarding@example.com',
  );
  await store.activate(accountId);
  return (database, store, accountId);
}

final _plan = QazaPlan(
  startDate: DateTime(2012, 1, 1),
  endDate: DateTime(2012, 1, 2),
  totalDays: 1,
  includeWitr: false,
  totalPrayers: 5,
  prayerBreakdown: {
    PrayerType.fajr: 1,
    PrayerType.zuhr: 1,
    PrayerType.asr: 1,
    PrayerType.maghrib: 1,
    PrayerType.isha: 1,
  },
);

UserProfile _profile() => UserProfile(
      languageCode: 'en',
      gender: Gender.male,
      madhab: Madhab.hanafi,
      dateOfBirth: DateTime(2000, 1, 1),
      pubertyAge: 12,
      startPrayingAge: 15,
      onboardingCompleted: true,
    );

QazaPlanRevision _revision({
  required String accountId,
  required String id,
  required int addedRecords,
}) =>
    ProfileQazaPlanReconciliationService.createInitialRevision(
      revisionId: id,
      userId: accountId,
      profile: _profile(),
      plan: _plan,
      addedRecords: addedRecords,
    );

QazaRecord _record({
  required String id,
  required String accountId,
  required String revisionId,
  required String fingerprint,
  required PrayerType prayerType,
  required DateTime date,
}) {
  final now = DateTime(2026, 10, 6);
  return QazaRecord(
    id: id,
    userId: accountId,
    prayerType: prayerType,
    originalDate: date,
    status: QazaStatus.pending,
    profilePlanRevisionId: revisionId,
    profilePlanFingerprint: fingerprint,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  test('onboarding draft is local-only and does not queue cloud backup', () async {
    final (database, store, accountId) = await _setupGoogle();
    addTearDown(database.close);

    await store.saveProfileLocalOnly(
      accountId,
      const UserProfile(
        languageCode: 'en',
        onboardingCompleted: false,
      ),
    );

    expect(
      await database.customSelect(
        '''SELECT 1 FROM account_profiles WHERE local_account_id = ?''',
        variables: [Variable(accountId)],
      ).get(),
      hasLength(1),
    );
    expect(
      await database.customSelect(
        '''SELECT 1 FROM sync_outbox WHERE user_id = ?''',
        variables: [Variable(accountId)],
      ).get(),
      isEmpty,
    );
  });

  test('atomic onboarding commit keeps profile, revision, records, provenance and outbox together',
      () async {
    final (database, store, accountId) = await _setupGoogle();
    addTearDown(database.close);

    final revision = _revision(
      accountId: accountId,
      id: 'rev-atomic',
      addedRecords: 1,
    );
    final record = _record(
      id: 'qaza-atomic',
      accountId: accountId,
      revisionId: revision.revisionId,
      fingerprint: revision.planFingerprint,
      prayerType: PrayerType.fajr,
      date: DateTime(2012, 1, 1),
    );

    await store.commitOnboarding(
      localAccountId: accountId,
      profile: _profile(),
      revision: revision,
      records: [record],
    );

    final profileRows = await database.customSelect(
      'SELECT payload_json FROM account_profiles WHERE local_account_id = ?',
      variables: [Variable(accountId)],
    ).get();
    expect(profileRows, hasLength(1));
    final profileJson =
        jsonDecode(profileRows.single.read<String>('payload_json')) as Map;
    expect(profileJson['onboardingCompleted'], isTrue);

    expect(
      await database.customSelect(
        '''SELECT local_account_id FROM account_plan_revisions
           WHERE local_account_id = ? AND revision_id = ?''',
        variables: [Variable(accountId), Variable(revision.revisionId)],
      ).get(),
      hasLength(1),
    );
    expect(
      await database.customSelect(
        '''SELECT user_id, id FROM qaza_records
           WHERE user_id = ? AND id = ?''',
        variables: [Variable(accountId), Variable(record.id)],
      ).get(),
      hasLength(1),
    );
    expect(
      await database.customSelect(
        '''SELECT user_id, plan_revision_id, plan_fingerprint
           FROM qaza_profile_plan_provenance
           WHERE user_id = ? AND record_id = ?''',
        variables: [Variable(accountId), Variable(record.id)],
      ).get(),
      hasLength(1),
    );
    expect(
      await database.customSelect(
        '''SELECT user_id, type
           FROM sync_outbox
           WHERE user_id = ? AND type = 'account_snapshot' ''',
        variables: [Variable(accountId)],
      ).get(),
      hasLength(1),
    );
  });

  test('zero-Qaza onboarding still commits the initial plan revision atomically', () async {
    final (database, store, accountId) = await _setupGoogle();
    addTearDown(database.close);

    final zeroPlan = QazaPlan(
      startDate: DateTime(2026, 10, 6),
      endDate: DateTime(2026, 10, 6),
      totalDays: 0,
      includeWitr: false,
      totalPrayers: 0,
      prayerBreakdown: {
        PrayerType.fajr: 0,
        PrayerType.zuhr: 0,
        PrayerType.asr: 0,
        PrayerType.maghrib: 0,
        PrayerType.isha: 0,
      },
    );
    final revision =
        ProfileQazaPlanReconciliationService.createInitialRevision(
      revisionId: 'rev-zero',
      userId: accountId,
      profile: _profile(),
      plan: zeroPlan,
      addedRecords: 0,
    );

    await store.commitOnboarding(
      localAccountId: accountId,
      profile: _profile(),
      revision: revision,
      records: const [],
    );

    expect(
      await database.customSelect(
        '''SELECT 1 FROM account_profiles WHERE local_account_id = ?''',
        variables: [Variable(accountId)],
      ).get(),
      hasLength(1),
    );
    expect(
      await database.customSelect(
        '''SELECT 1 FROM account_plan_revisions
           WHERE local_account_id = ? AND revision_id = ?''',
        variables: [Variable(accountId), Variable(revision.revisionId)],
      ).get(),
      hasLength(1),
    );
    expect(
      await database.customSelect(
        '''SELECT 1 FROM sync_outbox WHERE user_id = ?''',
        variables: [Variable(accountId)],
      ).get(),
      hasLength(1),
    );
  });

  test('atomic onboarding rolls back earlier writes after an in-transaction revision conflict',
      () async {
    final (database, store, accountId) = await _setupGoogle();
    addTearDown(database.close);

    final revision = _revision(
      accountId: accountId,
      id: 'rev-rollback',
      addedRecords: 1,
    );

    // Force the commit to fail after the profile write but before the Qaza
    // records/outbox are persisted. The revision is immutable, so a different
    // payload with the same ID is a deterministic transaction-local failure.
    final conflictingRevision = revision.copyWith(
      addedRecords: 999,
    );
    await database.customInsert(
      '''INSERT INTO account_plan_revisions
         (local_account_id, revision_id, payload_json, created_at)
         VALUES (?, ?, ?, ?)''',
      variables: [
        Variable(accountId),
        Variable(conflictingRevision.revisionId),
        Variable(jsonEncode(conflictingRevision.toJson())),
        Variable(conflictingRevision.createdAt.microsecondsSinceEpoch),
      ],
    );

    final record = _record(
      id: 'new-qaza',
      accountId: accountId,
      revisionId: revision.revisionId,
      fingerprint: revision.planFingerprint,
      prayerType: PrayerType.fajr,
      date: DateTime(2012, 1, 1),
    );

    await expectLater(
      store.commitOnboarding(
        localAccountId: accountId,
        profile: _profile(),
        revision: revision,
        records: [record],
      ),
      throwsStateError,
    );

    expect(
      await database.customSelect(
        'SELECT 1 FROM account_profiles WHERE local_account_id = ?',
        variables: [Variable(accountId)],
      ).get(),
      isEmpty,
    );
    expect(
      await database.customSelect(
        '''SELECT payload_json FROM account_plan_revisions
           WHERE local_account_id = ? AND revision_id = ?''',
        variables: [Variable(accountId), Variable(revision.revisionId)],
      ).get(),
      hasLength(1),
    );
    expect(
      await database.customSelect(
        '''SELECT id FROM qaza_records WHERE user_id = ? AND id = ?''',
        variables: [Variable(accountId), Variable(record.id)],
      ).get(),
      isEmpty,
    );
    expect(
      await database.customSelect(
        '''SELECT 1 FROM qaza_profile_plan_provenance WHERE user_id = ?''',
        variables: [Variable(accountId)],
      ).get(),
      isEmpty,
    );
    expect(
      await database.customSelect(
        '''SELECT 1 FROM sync_outbox WHERE user_id = ?''',
        variables: [Variable(accountId)],
      ).get(),
      isEmpty,
    );
  });;
}
