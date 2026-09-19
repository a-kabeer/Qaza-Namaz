import '../../core/constants/prayer_types.dart';
import '../../core/utils/qaza_date.dart';
import '../entities/qaza_record.dart';
import '../repositories/qaza_repository.dart';
import '../services/qaza_availability_service.dart';
import '../../data/local/qaza_local_store.dart';

/// What a migration did, for reporting and regression assertions.
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

    final localByKey = <String, QazaRecord>{
      for (final record in localAccountRecords)
        _key(record): _normalizeForUser(record, accountUserId),
    };
    final remoteByKey = <String, QazaRecord>{
      for (final record in remoteAccountRecords)
        _key(record): _normalizeForUser(record, accountUserId),
    };

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

    final toAppend = <QazaRecord>[];
    final toCompleteLocally = <String>[];
    for (final entry in desiredByKey.entries) {
      final key = entry.key;
      final desired = entry.value;
      final local = localByKey[key];

      if (local == null) {
        toAppend.add(desired);
        localByKey[key] = desired;
      }

      final effectiveLocal = localByKey[key]!;
      if (desired.status == QazaStatus.completed &&
          effectiveLocal.status == QazaStatus.pending) {
        toCompleteLocally.add(effectiveLocal.id);
      }
    }

    if (toAppend.isNotEmpty) {
      await _localStore.appendRecords(accountUserId, toAppend);
    }
    if (toCompleteLocally.isNotEmpty) {
      await _localStore.completeRecords(
        userId: accountUserId,
        recordIds: toCompleteLocally,
        completedAt: now,
      );
    }

    // Re-read the account rows after local writes. This makes recovery safe if
    // the process dies between the local record write and outbox persistence.
    final refreshedLocal = await _allLocalRecords(accountUserId);
    final refreshedByKey = <String, QazaRecord>{
      for (final record in refreshedLocal)
        _key(record): _normalizeForUser(record, accountUserId),
    };

    final existingOutbox = await _localStore.loadOutbox(accountUserId);
    final outbox = <String, PendingSyncOp>{
      for (final op in existingOutbox) op.id: op,
    };

    for (final entry in desiredByKey.entries) {
      final key = entry.key;
      final desired = entry.value;
      final local = refreshedByKey[key] ?? desired;
      final remote = remoteByKey[key];

      if (remote == null) {
        final id = 'add_' + local.id;
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
        // The remote document ID is authoritative when local/remote IDs differ.
        final id = 'complete_' + remote.id;
        final existing = outbox[id];
        outbox[id] = PendingSyncOp(
          id: id,
          type: SyncOpType.complete,
          userId: accountUserId,
          queuedAt: existing?.queuedAt ?? now,
          targetRecordId: remote.id,
          completedAt: desired.completedAt ?? now,
          attempts: existing?.attempts ?? 0,
          lastError: existing?.lastError,
        );
      }
    }

    await _localStore.saveOutbox(
      accountUserId,
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
      _localStore.retireUserData(guestUserId);

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
      record.prayerType.name + '|' + QazaDate.key(record.originalDate);

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
