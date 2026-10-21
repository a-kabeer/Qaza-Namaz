import 'package:drift/drift.dart';
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

/// Scenario 24 — adoption recovery-snapshot retention.
///
/// The snapshot taken before a Guest workspace is adopted into a Google
/// workspace is the only copy of the pre-adoption data. It must survive
/// for as long as the adoption's cloud backup is still pending (no matter
/// how much time passes), and may only be purged once a backup has been
/// verified *and* a further 30 days have elapsed; the purge then marks
/// the adoption journal `cleaned`.
void main() {
  late AppDatabase database;
  late LocalBackupService service;
  late AccountLocalStore store;

  const googleId = 'google_stable-retention-account';

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

  /// Runs a complete Guest -> Google adoption and returns the Guest ID.
  /// Afterwards the adoption journal is `committed`, one recovery
  /// snapshot exists, and its backup is still pending (never verified).
  Future<String> adoptGuest() async {
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
      _recordFor(guestId, 'retention_fajr_1', DateTime(2025, 1, 1)),
    );
    await store.ensureAccountActive(googleId);
    await service.adoptGuestWorkspace(
      sourceLocalAccountId: guestId,
      targetGoogleLocalAccountId: googleId,
      googleDisplayName: 'Amina Google',
    );
    return guestId;
  }

  Future<int> snapshotCount(String guestId) async {
    final rows = await database.customSelect(
      'SELECT snapshot_id FROM local_account_adoption_snapshots '
      'WHERE source_local_account_id = ? AND target_local_account_id = ?',
      variables: [Variable(guestId), Variable(googleId)],
    ).get();
    return rows.length;
  }

  Future<({String phase, int? backupVerifiedAt})> journalState() async {
    final rows = await database.customSelect(
      'SELECT phase, backup_verified_at FROM workspace_operation_journal '
      "WHERE operation_type = 'guest_adoption' "
      'AND target_local_account_id = ?',
      variables: [Variable(googleId)],
    ).get();
    expect(rows, hasLength(1));
    return (
      phase: rows.single.read<String>('phase'),
      backupVerifiedAt: rows.single.readNullable<int>('backup_verified_at'),
    );
  }

  test(
      'an adoption snapshot is never purged while its backup is still '
      'pending, even long past 30 days', () async {
    final guestId = await adoptGuest();
    expect(await snapshotCount(guestId), 1);
    final journal = await journalState();
    expect(journal.phase, 'committed');
    expect(journal.backupVerifiedAt, equals(null));

    // A year later the backup has still never been verified: the purge
    // must not touch the snapshot, because it is the only recovery copy
    // of the pre-adoption data.
    final removed = await service.purgeExpiredGuestAdoptionSnapshots(
      now: DateTime.now().add(const Duration(days: 365)),
    );

    expect(removed, 0);
    expect(await snapshotCount(guestId), 1);
    expect((await journalState()).phase, 'committed');
  });

  test(
      'a verified adoption snapshot is kept inside the 30-day recovery '
      'window', () async {
    final guestId = await adoptGuest();
    final verifiedAt = DateTime.utc(2026, 1, 1);
    await service.markGuestAdoptionBackupVerified(
      googleId,
      verifiedAt: verifiedAt,
    );
    expect(
      (await journalState()).backupVerifiedAt,
      verifiedAt.microsecondsSinceEpoch,
    );

    final removed = await service.purgeExpiredGuestAdoptionSnapshots(
      now: verifiedAt.add(const Duration(days: 29)),
    );

    expect(removed, 0);
    expect(await snapshotCount(guestId), 1);
    expect((await journalState()).phase, 'committed');
  });

  test(
      'a verified adoption snapshot is purged after 30 days and the '
      'journal is marked cleaned', () async {
    final guestId = await adoptGuest();
    final verifiedAt = DateTime.utc(2026, 1, 1);
    await service.markGuestAdoptionBackupVerified(
      googleId,
      verifiedAt: verifiedAt,
    );

    final removed = await service.purgeExpiredGuestAdoptionSnapshots(
      now: verifiedAt.add(const Duration(days: 31)),
    );

    expect(removed, 1);
    expect(await snapshotCount(guestId), 0);
    expect((await journalState()).phase, 'cleaned');
    // Purging the recovery snapshot must not touch the adopted data
    // itself: the Google workspace keeps the adopted record.
    expect(
      (await database.qazaRecordsDao.getAll(
        userId: googleId,
      ))
          .map((record) => record.id),
      ['retention_fajr_1'],
    );
  });
}
