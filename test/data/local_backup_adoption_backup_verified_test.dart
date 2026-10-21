import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/data/data_transfer/local_backup_service.dart';
import 'package:qaza_namaz/data/local/account_local_store.dart';
import 'package:qaza_namaz/data/local/database/app_database.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';
import 'package:qaza_namaz/domain/entities/user_profile.dart';

QazaRecordsCompanion _recordFor(String userId, String id, DateTime date) =>
    QazaRecordsCompanion.insert(
      id: id,
      userId: userId,
      prayerType: PrayerType.fajr.name,
      originalDate: date,
      status: QazaStatus.pending.name,
      createdAt: date,
      updatedAt: date,
    );

/// Scenario 4 leftover — the `markGuestAdoptionBackupVerified` marking path.
///
/// Adopting a Guest workspace into a Google workspace takes a recovery
/// snapshot whose cloud backup starts out *pending*: the adoption journal
/// is committed, but `backup_verified_at` must stay empty until the first
/// cloud backup of the adopted workspace has actually succeeded and the
/// caller records that success through this method. (What the verified
/// timestamp later unlocks — the 30-day purge — is covered by
/// local_backup_adoption_retention_test.dart; this file pins the marking
/// semantics themselves.)
void main() {
  late AppDatabase database;
  late LocalBackupService service;
  late AccountLocalStore store;

  const googleId = 'google_stable-marking-account';

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    service = LocalBackupService(database);
    store = AccountLocalStore(database: database);
    final now = DateTime.now().microsecondsSinceEpoch;
    await database.customInsert(
      '''INSERT INTO local_accounts
         (local_account_id, account_mode, lifecycle_state, created_at, updated_at)
         VALUES (?, 'local', 'active', ?, ?)''',
      variables: [
        Variable.withString('guest'),
        Variable.withInt(now),
        Variable.withInt(now),
      ],
    );
    await database.customInsert(
      '''INSERT INTO app_session_state (id, active_local_account_id)
         VALUES (1, ?)''',
      variables: [Variable.withString('guest')],
    );
  });

  tearDown(() async {
    await database.close();
  });

  /// Runs a complete Guest -> Google adoption. Afterwards the journal is
  /// `committed` and the recovery snapshot exists, still unverified.
  Future<void> adoptGuest() async {
    final guestId = await store.createGuestWorkspace(displayName: 'Amina');
    await store.saveProfile(
      guestId,
      UserProfile(
        gender: Gender.male,
        madhab: Madhab.hanafi,
        dateOfBirth: DateTime(1990, 1, 1),
        pubertyAge: 12,
        startPrayingAge: 15,
        witrIncluded: true,
        onboardingCompleted: true,
      ),
    );
    await database.qazaRecordsDao.insertRecord(
      _recordFor(guestId, 'marking_fajr_1', DateTime(2025, 1, 1)),
    );
    await store.ensureAccountActive(googleId);
    await service.adoptGuestWorkspace(
      sourceLocalAccountId: guestId,
      targetGoogleLocalAccountId: googleId,
      googleDisplayName: 'Amina Google',
    );
  }

  Future<({String phase, int? backupVerifiedAt})?> journalState(
    String target,
  ) async {
    final rows = await database.customSelect(
      'SELECT phase, backup_verified_at FROM workspace_operation_journal '
      "WHERE operation_type = 'guest_adoption' "
      'AND target_local_account_id = ?',
      variables: [Variable(target)],
    ).get();
    if (rows.isEmpty) return null;
    expect(rows, hasLength(1));
    return (
      phase: rows.single.read<String>('phase'),
      backupVerifiedAt: rows.single.readNullable<int>('backup_verified_at'),
    );
  }

  test(
      'a completed adoption is committed but unverified until the first '
      'successful backup is marked', () async {
    await adoptGuest();

    final before = await journalState(googleId);
    expect(before?.phase, 'committed');
    expect(before?.backupVerifiedAt, equals(null));

    final verifiedAt = DateTime.utc(2026, 1, 1, 12);
    await service.markGuestAdoptionBackupVerified(
      googleId,
      verifiedAt: verifiedAt,
    );

    final after = await journalState(googleId);
    expect(after?.phase, 'committed');
    expect(after?.backupVerifiedAt, verifiedAt.microsecondsSinceEpoch);
  });

  test('marking twice keeps the first verified time', () async {
    await adoptGuest();

    final first = DateTime.utc(2026, 1, 1, 12);
    final second = DateTime.utc(2026, 1, 2, 12);
    await service.markGuestAdoptionBackupVerified(
      googleId,
      verifiedAt: first,
    );
    await service.markGuestAdoptionBackupVerified(
      googleId,
      verifiedAt: second,
    );

    // The retention clock runs from the *first* verified backup; a later
    // re-mark (e.g. a repeated Backup Now success) must not extend it.
    expect(
      (await journalState(googleId))?.backupVerifiedAt,
      first.microsecondsSinceEpoch,
    );
  });

  test(
      'marking a workspace with no adoption journal is a harmless no-op '
      'and does not verify another workspace\'s adoption', () async {
    await adoptGuest();

    const otherGoogleId = 'google_never-adopted-account';
    await service.markGuestAdoptionBackupVerified(
      otherGoogleId,
      verifiedAt: DateTime.utc(2026, 1, 1, 12),
    );

    // No journal row was manufactured for the other workspace...
    expect(await journalState(otherGoogleId), isNull);
    // ...and this adoption is still unverified.
    expect((await journalState(googleId))?.backupVerifiedAt, equals(null));
  });
}
