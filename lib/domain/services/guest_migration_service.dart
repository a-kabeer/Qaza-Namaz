import '../../core/utils/qaza_date.dart';
import '../entities/qaza_record.dart';
import '../repositories/qaza_repository.dart';
import 'qaza_availability_service.dart';

/// What a migration did, for the caller to report and for tests to assert.
class GuestMigrationResult {
  const GuestMigrationResult({
    required this.examined,
    required this.added,
    required this.completed,
  });

  static const none = GuestMigrationResult(examined: 0, added: 0, completed: 0);

  /// Guest records read.
  final int examined;

  /// Records the account did not already have.
  final int added;

  /// Records marked completed because the guest had completed them.
  final int completed;

  bool get movedAnything => added > 0 || completed > 0;
}

/// Moves a guest's records into the account they have just signed in to.
///
/// Neither side is deleted: the guest rows stay in the local database, and an
/// account record that already exists is left exactly as it is. A guest
/// record that duplicates one the account already holds is skipped by the
/// same date-and-prayer rule the repository applies to every other write, so
/// signing in can never double a ledger.
class GuestMigrationService {
  const GuestMigrationService(this.repository);

  final QazaRepository repository;

  static const int _pageSize = 500;

  Future<GuestMigrationResult> migrate({
    required String guestUserId,
    required String accountUserId,
    DateTime? completedAt,
  }) async {
    if (guestUserId == accountUserId) return GuestMigrationResult.none;

    final guestRecords = await _allRecords(guestUserId);
    if (guestRecords.isEmpty) return GuestMigrationResult.none;

    final existing = await _allRecords(accountUserId);
    final existingKeys = {for (final record in existing) _key(record)};
    final completedKeys = {
      for (final record in existing)
        if (record.status == QazaStatus.completed) _key(record),
    };

    final now = completedAt ?? DateTime.now();
    final fresh = <QazaRecord>[];
    final toComplete = <String>[];

    for (final guest in guestRecords) {
      final key = _key(guest);
      // The same id the app builds for any new record of this account.
      final id = QazaPrayerKey(
        userId: accountUserId,
        prayerType: guest.prayerType,
        date: QazaDate.normalize(guest.originalDate),
      ).value;
      if (existingKeys.add(key)) {
        fresh.add(QazaRecord(
          id: id,
          userId: accountUserId,
          prayerType: guest.prayerType,
          originalDate: QazaDate.normalize(guest.originalDate),
          status: QazaStatus.pending,
          createdAt: guest.createdAt,
          updatedAt: now,
        ));
      }
      // A guest completion is carried over, including onto a record the
      // account already had pending. Completion is never undone the other way.
      if (guest.status == QazaStatus.completed &&
          !completedKeys.contains(key)) {
        completedKeys.add(key);
        toComplete.add(id);
      }
    }

    if (fresh.isNotEmpty) await repository.addRecords(fresh);
    if (toComplete.isNotEmpty) {
      await repository.completeRecords(
        userId: accountUserId,
        recordIds: toComplete,
        completedAt: now,
      );
    }

    return GuestMigrationResult(
      examined: guestRecords.length,
      added: fresh.length,
      completed: toComplete.length,
    );
  }

  /// Every record for one user, read in bounded pages.
  Future<List<QazaRecord>> _allRecords(String userId) async {
    final result = <QazaRecord>[];
    DateTime? afterDate;
    String? afterId;
    while (true) {
      final page = await repository.getPage(
        userId: userId,
        limit: _pageSize,
        afterOriginalDate: afterDate,
        afterId: afterId,
      );
      result.addAll(page.records);
      if (!page.hasMore) return result;
      afterDate = page.nextOriginalDate;
      afterId = page.nextId;
    }
  }

  String _key(QazaRecord record) =>
      '${record.prayerType.name}|${QazaDate.key(record.originalDate)}';
}
