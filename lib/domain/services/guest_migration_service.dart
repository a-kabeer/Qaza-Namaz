import '../../core/utils/qaza_date.dart';
import '../entities/qaza_record.dart';
import '../repositories/qaza_repository.dart';
import '../services/qaza_availability_service.dart';
import '../../data/local/qaza_local_store.dart';

/// What a migration did, for reporting and regression assertions.
class GuestDataSummary {
  const GuestDataSummary({
    required this.localCount,
    required this.localCompleted,
    required this.accountCount,
    required this.accountCompleted,
  });

  static const empty = GuestDataSummary(
    localCount: 0,
    localCompleted: 0,
    accountCount: 0,
    accountCompleted: 0,
  );

  final int localCount;
  final int localCompleted;
  final int accountCount;
  final int accountCompleted;
}

class GuestMigrationResult {
  const GuestMigrationResult({
    required this.examined,
    required this.added,
    required this.completed,
  });

  static const none = GuestMigrationResult(examined: 0, added: 0, completed: 0);

  final int examined;
  final int added;
  final int completed;

  bool get movedAnything => added > 0 || completed > 0;
}

/// Reconciles guest data with an explicitly identified Firebase account.
///
/// This service deliberately bypasses OfflineFirstQazaRepository. That
/// repository is bound to the active auth ledger, which can change from
/// "guest" to the Firebase UID as authStateChanges() fires. This migration
/// instead addresses guest and account datasets by explicit user ID through
/// QazaLocalStore and reads the account's cloud ledger directly.
class GuestMigrationService {
  const GuestMigrationService({
    required QazaLocalStore localStore,
    required QazaRepository remoteRepository,
  })  : _localStore = localStore,
        _remoteRepository = remoteRepository;

  final QazaLocalStore _localStore;
  final QazaRepository _remoteRepository;

  static const int _pageSize = 500;

  Future<bool> hasGuestData({required String guestUserId}) async {
    final page = await _localStore.getPage(userId: guestUserId, limit: 1);
    return page.records.isNotEmpty;
  }

  Future<GuestDataSummary> summarize({
    required String guestUserId,
    required String accountUserId,
  }) async {
    if (guestUserId.isEmpty || accountUserId.isEmpty) {
      throw StateError('Guest and account user IDs are required.');
    }
    if (guestUserId == accountUserId) return GuestDataSummary.empty;

    final guestRecords = await _allLocalRecords(guestUserId);
    final localAccountRecords = await _allLocalRecords(accountUserId);
    final remoteAccountRecords =
        await _remoteRepository.getRecords(userId: accountUserId);

    final accountByKey = <String, QazaRecord>{};
    for (final record in localAccountRecords) {
      _preferCompleted(
        accountByKey,
        _key(record),
        _normalizeForUser(record, accountUserId),
      );
    }
    for (final record in remoteAccountRecords) {
      _preferCompleted(
        accountByKey,
        _key(record),
        _normalizeForUser(record, accountUserId),
      );
    }

    return GuestDataSummary(
      localCount: guestRecords.length,
      localCompleted:
          guestRecords.where((record) => record.status == QazaStatus.completed).length,
      accountCount: accountByKey.length,
      accountCompleted: accountByKey.values
          .where((record) => record.status == QazaStatus.completed)
          .length,
    );
  }

  Future<GuestMigrationResult> migrate({
    required String guestUserId,
    required String accountUserId,
    DateTime? completedAt,
  }) async {
    if (guestUserId.isEmpty || accountUserId.isEmpty) {
      throw StateError('Guest and account user IDs are required.');
    }
    if (guestUserId == accountUserId) return GuestMigrationResult.none;

    final guestRecords = await _allLocalRecords(guestUserId);
    if (guestRecords.isEmpty) return GuestMigrationResult.none;

    final localAccountRecords = await _allLocalRecords(accountUserId);
    final remoteAccountRecords =
        await _remoteRepository.getRecords(userId: accountUserId);

    final localByKey = <String, QazaRecord>{};
    for (final record in localAccountRecords) {
      _preferCompleted(
        localByKey,
        _key(record),
        _normalizeForUser(record, accountUserId),
      );
    }

    // Firestore has no equivalent of the local SQLite unique constraint, so
    // legacy data may contain multiple documents for the same prayer/date.
    // Collapse those duplicates with completed status taking precedence.
    final remoteByKey = <String, QazaRecord>{};
    for (final record in remoteAccountRecords) {
      _preferCompleted(
        remoteByKey,
        _key(record),
        _normalizeForUser(record, accountUserId),
      );
    }

    final desiredByKey = <String, QazaRecord>{};
    for (final record in localAccountRecords) {
      _preferCompleted(
        desiredByKey,
        _key(record),
        _normalizeForUser(record, accountUserId),
      );
    }
    for (final record in remoteAccountRecords) {
      _preferCompleted(
        desiredByKey,
        _key(record),
        _normalizeForUser(record, accountUserId),
      );
    }

    final now = completedAt ?? DateTime.now();
    for (final guest in guestRecords) {
      final key = _key(guest);
      final current = desiredByKey[key];
      if (current == null) {
        desiredByKey[key] = QazaRecord(
          id: QazaPrayerKey(
            userId: accountUserId,
            prayerType: guest.prayerType,
            date: QazaDate.normalize(guest.originalDate),
          ).value,
          userId: accountUserId,
          prayerType: guest.prayerType,
          originalDate: QazaDate.normalize(guest.originalDate),
          status: guest.status,
          completedAt: guest.completedAt,
          createdAt: guest.createdAt,
          updatedAt: guest.updatedAt,
        );
      } else if (guest.status == QazaStatus.completed &&
          current.status == QazaStatus.pending) {
        // Account record identity is preserved; completion wins.
        desiredByKey[key] = current.copyWith(
          status: QazaStatus.completed,
          completedAt: guest.completedAt ?? now,
          updatedAt: now,
        );
      }
    }

    final accountKeysBefore = <String>{
      ...localByKey.keys,
      ...remoteByKey.keys,
    };

    final existingOutbox = await _localStore.loadOutbox(accountUserId);
    final outbox = <String, PendingSyncOp>{
      for (final op in existingOutbox) op.id: op,
    };

    // Build the entire target account ledger before writing anything. The
    // production Drift store persists records and outbox in one transaction,
    // so a failed migration cannot leave a partially imported account.
    final finalLocalByKey = <String, QazaRecord>{
      for (final entry in localByKey.entries) entry.key: entry.value,
    };

    for (final entry in desiredByKey.entries) {
      final key = entry.key;
      final desired = entry.value;
      final existingLocal = finalLocalByKey[key];

      if (existingLocal == null) {
        finalLocalByKey[key] = desired;
      } else if (desired.status == QazaStatus.completed &&
          existingLocal.status == QazaStatus.pending) {
        finalLocalByKey[key] = existingLocal.copyWith(
          status: QazaStatus.completed,
          completedAt: desired.completedAt ?? now,
          updatedAt: now,
        );
      }
    }

    final finalLocalRecords = finalLocalByKey.values.toList(growable: false);

    for (final entry in desiredByKey.entries) {
      final key = entry.key;
      final desired = entry.value;
      final local = finalLocalByKey[key] ?? desired;
      final remote = remoteByKey[key];

      if (remote == null) {
        final id = 'add_${local.id}';
        final existing = outbox[id];
        final addRecord = existing?.record?.status == QazaStatus.completed
            ? existing!.record!
            : local;
        outbox[id] = PendingSyncOp(
          id: id,
          type: SyncOpType.add,
          userId: accountUserId,
          queuedAt: existing?.queuedAt ?? now,
          record: addRecord,
          attempts: existing?.attempts ?? 0,
          lastError: existing?.lastError,
        );
        continue;
      }

      if (desired.status == QazaStatus.completed &&
          remote.status == QazaStatus.pending) {
        // The remote document ID is authoritative when local and remote IDs
        // differ, so the queued completion is always safe to replay.
        final id = 'complete_${remote.id}';
        final existing = outbox[id];
        outbox[id] = PendingSyncOp(
          id: id,
          type: SyncOpType.complete,
          userId: accountUserId,
          queuedAt: existing?.queuedAt ?? now,
          targetRecordId: remote.id,
          completedAt: desired.completedAt ?? now,
          record: remote.copyWith(
            status: QazaStatus.completed,
            completedAt: desired.completedAt ?? now,
            updatedAt: now,
          ),
          attempts: existing?.attempts ?? 0,
          lastError: existing?.lastError,
        );
      }
    }

    await _localStore.saveRecordsAndOutbox(
      accountUserId,
      finalLocalRecords,
      outbox.values.toList(growable: false),
    );

    final guestKeys = <String>{for (final record in guestRecords) _key(record)};
    var completedCount = 0;
    for (final guest in guestRecords) {
      if (guest.status != QazaStatus.completed) continue;
      final key = _key(guest);
      final localBefore = localAccountRecords
          .where((record) => _key(record) == key)
          .firstOrNull;
      final remote = remoteByKey[key];
      if (localBefore?.status == QazaStatus.pending ||
          remote?.status == QazaStatus.pending) {
        completedCount++;
      }
    }

    return GuestMigrationResult(
      examined: guestRecords.length,
      added: guestKeys.difference(accountKeysBefore).length,
      completed: completedCount,
    );
  }

  /// Retires only the guest namespace. Call this only after [migrate] has
  /// completed successfully or after the user explicitly chose account data.
  Future<void> retireGuestData({required String guestUserId}) =>
      _localStore.retireUserData(userId: guestUserId);

  Future<List<QazaRecord>> _allLocalRecords(String userId) async {
    final result = <QazaRecord>[];
    DateTime? afterDate;
    String? afterId;
    while (true) {
      final page = await _localStore.getPage(
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

  static String _key(QazaRecord record) =>
      '${record.prayerType.name}|${QazaDate.key(record.originalDate)}';

  static QazaRecord _normalizeForUser(QazaRecord record, String userId) =>
      record.copyWith(
        userId: userId,
        originalDate: QazaDate.normalize(record.originalDate),
      );

  static void _preferCompleted(
    Map<String, QazaRecord> target,
    String key,
    QazaRecord candidate,
  ) {
    final existing = target[key];
    if (existing == null) {
      target[key] = candidate;
      return;
    }
    if (existing.status == QazaStatus.pending &&
        candidate.status == QazaStatus.completed) {
      target[key] = candidate;
    }
  }
}
