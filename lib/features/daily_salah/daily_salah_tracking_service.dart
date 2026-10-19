import 'dart:convert';

import 'package:drift/drift.dart';

import '../../core/constants/prayer_types.dart';
import '../../core/utils/qaza_date.dart';
import '../../data/local/database/app_database.dart';
import '../../domain/entities/qaza_record.dart';
import '../../domain/entities/qaza_completion_result.dart';
import '../../domain/repositories/pending_qaza_deletion_repository.dart';
import '../../domain/services/qaza_service.dart';

enum DailySalahStatus { prayed, missed, unrecorded }

class DailySalahLog {
  const DailySalahLog({
    required this.userId,
    required this.prayerDate,
    required this.prayerType,
    required this.status,
    required this.updatedAt,
    this.trackerCreatedQazaId,
    this.linkedQazaId,
    this.completionSyncId,
  });

  final String userId;
  final DateTime prayerDate;
  final PrayerType prayerType;
  final DailySalahStatus status;

  /// Ownership marker: only non-null when Daily Salah Tracking created it.
  final String? trackerCreatedQazaId;

  /// Association marker, independent of who created the Qaza record.
  final String? linkedQazaId;

  /// Completion marker that changed this log from Missed to Prayed.
  /// Used to safely reverse that projection if the exact completion is undone.
  final String? completionSyncId;
  final DateTime updatedAt;
}

/// Offline-first daily Salah history.
///
/// Salah logs are stored separately from Qaza records. A log only links to a
/// Qaza record when this service can identify the exact record it created.
class DailySalahTrackingService {
  DailySalahTrackingService({
    required AppDatabase database,
    required QazaService qazaService,
    String? Function()? activeUserId,
  })  : _database = database,
        _qazaService = qazaService,
        _activeUserId = activeUserId ?? (() => null);

  final AppDatabase _database;
  final QazaService _qazaService;
  final String? Function() _activeUserId;

  String get _workspaceId {
    final value = _activeUserId()?.trim();
    return value == null || value.isEmpty ? 'guest' : value;
  }

  /// Reads the enabled state for the currently active local workspace.
  Future<bool> isEnabled() =>
      _database.isDailySalahTrackingEnabled(userId: _workspaceId);

  Future<void> setEnabled(bool enabled) =>
      _database.setDailySalahTrackingEnabled(
        enabled,
        userId: _workspaceId,
      );

  Future<bool> isSetupDismissed() =>
      _database.isDailySalahTrackingSetupDismissed(userId: _workspaceId);

  Future<void> setSetupDismissed(bool dismissed) =>
      _database.setDailySalahTrackingSetupDismissed(
        dismissed,
        userId: _workspaceId,
      );

  Future<Map<PrayerType, DailySalahLog>> logsForDate({
    required String userId,
    required DateTime date,
    bool includeWitr = true,
  }) async {
    final dayKey = _dayKey(date);
    final rows = await _database.customSelect(
      'SELECT user_id, prayer_date, prayer_type, status, '
      'tracker_created_qaza_id, linked_qaza_id, completion_sync_id, updated_at FROM daily_salah_logs '
      'WHERE user_id = ? AND prayer_date = ? ORDER BY prayer_type',
      variables: [Variable(userId), Variable(dayKey)],
    ).get();

    final result = <PrayerType, DailySalahLog>{};
    for (final row in rows) {
      final prayerName = row.read<String>('prayer_type');
      final prayer = PrayerType.values.firstWhere(
        (value) => value.name == prayerName,
        orElse: () =>
            throw StateError('Unknown daily Salah prayer "$prayerName".'),
      );
      if (prayer == PrayerType.witr && !includeWitr) continue;
      result[prayer] = DailySalahLog(
        userId: row.read<String>('user_id'),
        prayerDate: _normalizeDate(date),
        prayerType: prayer,
        status: DailySalahStatus.values.firstWhere(
          (value) => value.name == row.read<String>('status'),
          orElse: () => throw StateError('Unknown daily Salah status.'),
        ),
        trackerCreatedQazaId: row.read<String?>('tracker_created_qaza_id'),
        linkedQazaId: row.read<String?>('linked_qaza_id'),
        completionSyncId: row.read<String?>('completion_sync_id'),
        updatedAt: DateTime.parse(row.read<String>('updated_at')),
      );
    }
    // Recover a persisted Qaza completion or reopen when the process ended
    // between the ledger mutation and its corresponding tracking update.
    for (final item in result.entries.toList(growable: false)) {
      final log = item.value;
      var recordId = log.linkedQazaId ?? log.trackerCreatedQazaId;
      if (recordId == null && log.status == DailySalahStatus.missed) {
        final matching = await _matchingQaza(
          userId: userId,
          prayerType: log.prayerType,
          date: date,
        );
        if (matching.length == 1) recordId = matching.single.id;
      }
      if (recordId == null) continue;
      final records = await _qazaService.repository.getRecordsByIds(
        userId: userId,
        recordIds: [recordId],
      );
      if (records.length != 1 ||
          !_matches(
            records.single,
            userId: userId,
            prayer: log.prayerType,
            date: date,
          )) {
        continue;
      }
      final record = records.single;
      if (log.status == DailySalahStatus.missed &&
          record.status == QazaStatus.completed &&
          record.completedAt != null &&
          record.completionId != null) {
        await syncQazaCompleted(
          userId: userId,
          entry: QazaCompletionEntry(
            recordId: record.id,
            completionId: record.completionId!,
            prayerType: record.prayerType,
            originalDate: record.originalDate,
            completedAt: record.completedAt!,
          ),
        );
        result[item.key] = (await logForDate(
          userId: userId,
          date: date,
          prayerType: log.prayerType,
        ))!;
      } else if (log.status == DailySalahStatus.prayed &&
          log.completionSyncId != null &&
          record.status == QazaStatus.pending) {
        await syncQazaReopened(
          userId: userId,
          recordId: record.id,
          prayerType: record.prayerType,
          originalDate: record.originalDate,
          expectedCompletionId: log.completionSyncId!,
        );
        result[item.key] = (await logForDate(
          userId: userId,
          date: date,
          prayerType: log.prayerType,
        ))!;
      }
    }
    return result;
  }

  Future<DailySalahLog?> logForDate({
    required String userId,
    required DateTime date,
    required PrayerType prayerType,
  }) async {
    final rows = await _database.customSelect(
      'SELECT user_id, prayer_date, prayer_type, status, '
      'tracker_created_qaza_id, linked_qaza_id, completion_sync_id, updated_at FROM daily_salah_logs '
      'WHERE user_id = ? AND prayer_date = ? AND prayer_type = ? LIMIT 1',
      variables: [
        Variable(userId),
        Variable(_dayKey(date)),
        Variable(prayerType.name),
      ],
    ).get();
    if (rows.isEmpty) return null;
    final row = rows.first;
    return DailySalahLog(
      userId: row.read<String>('user_id'),
      prayerDate: _normalizeDate(date),
      prayerType: prayerType,
      status: DailySalahStatus.values.firstWhere(
        (value) => value.name == row.read<String>('status'),
      ),
      trackerCreatedQazaId: row.read<String?>('tracker_created_qaza_id'),
      linkedQazaId: row.read<String?>('linked_qaza_id'),
      completionSyncId: row.read<String?>('completion_sync_id'),
      updatedAt: DateTime.parse(row.read<String>('updated_at')),
    );
  }

  /// Sets Prayed, synchronizing an existing missed prayer with its Qaza.
  ///
  /// Unrecorded is the initial state; a selected status is not cleared by
  /// tapping its button again.
  Future<void> setStatus({
    required String userId,
    required PrayerType prayerType,
    required DateTime date,
    required DailySalahStatus status,
  }) async {
    await _requireEnabled();
    if (status != DailySalahStatus.prayed) {
      throw ArgumentError(
        'Use recordMissed for Missed; a selected status cannot be cleared.',
      );
    }

    final normalizedDate = _normalizeDate(date);
    final existing = await logForDate(
      userId: userId,
      date: normalizedDate,
      prayerType: prayerType,
    );
    if (existing?.status == DailySalahStatus.prayed) return;

    final hasMissedHistory = existing?.status == DailySalahStatus.missed ||
        existing?.linkedQazaId != null ||
        existing?.trackerCreatedQazaId != null;
    if (!hasMissedHistory) {
      await _writeLog(
        userId: userId,
        prayerType: prayerType,
        date: normalizedDate,
        status: DailySalahStatus.prayed,
        linkedQazaId: null,
        replaceLinkedQazaId: true,
        completionSyncId: null,
        replaceCompletionSyncId: true,
      );
      return;
    }

    final linked = await _associatedQaza(
      userId: userId,
      prayerType: prayerType,
      date: normalizedDate,
      log: existing,
    );
    if (linked == null) {
      throw StateError(
        'The linked Qaza record could not be found safely. The prayer status was not changed.',
      );
    }

    var completionId = linked.completionId;
    var completedByThisAction = false;
    if (linked.status == QazaStatus.pending) {
      final receipt = await _qazaService.completeRecordWithReceipt(
        userId: userId,
        recordId: linked.id,
        completedAt: DateTime.now(),
      );
      if (receipt.result == QazaCompletionResult.completed &&
          receipt.completionId != null) {
        completionId = receipt.completionId;
        completedByThisAction = true;
      } else {
        final current = await _qazaService.repository.getRecordsByIds(
          userId: userId,
          recordIds: [linked.id],
        );
        if (current.length == 1 &&
            current.single.status == QazaStatus.completed &&
            current.single.completionId != null) {
          completionId = current.single.completionId;
        } else {
          throw StateError('The linked Qaza record could not be completed.');
        }
      }
    }
    if (completionId == null) {
      throw StateError(
        'This completed Qaza has no safe completion marker, so its tracking status was not changed.',
      );
    }

    try {
      await _writeLog(
        userId: userId,
        prayerType: prayerType,
        date: normalizedDate,
        status: DailySalahStatus.prayed,
        linkedQazaId: linked.id,
        replaceLinkedQazaId: true,
        completionSyncId: completionId,
        replaceCompletionSyncId: true,
      );
    } catch (_) {
      // Compensate with the exact marker if the tracking write failed.
      if (completedByThisAction) {
        try {
          await _qazaService.undoCompletions(
            userId: userId,
            expectedCompletionIds: {linked.id: completionId},
            undoneAt: DateTime.now(),
          );
        } catch (_) {
          // Read-time reconciliation is the last-resort recovery path.
        }
      }
      rethrow;
    }
  }

  /// Records Missed and ensures exactly one Pending Qaza is linked.
  /// Repeated calls are idempotent and never claim ownership of manual records.
  Future<void> recordMissed({
    required String userId,
    required PrayerType prayerType,
    required DateTime date,
  }) async {
    await _requireEnabled();
    final normalizedDate = _normalizeDate(date);
    final previous = await logForDate(
      userId: userId,
      date: normalizedDate,
      prayerType: prayerType,
    );
    final matching = await _matchingQaza(
      userId: userId,
      prayerType: prayerType,
      date: normalizedDate,
    );
    if (matching.length > 1) {
      throw StateError('Multiple Qaza records match this prayer and date.');
    }

    QazaRecord? record;
    var trackerCreatedId = previous?.trackerCreatedQazaId;
    if (matching.isNotEmpty) {
      record = matching.single;
      if (record.status == QazaStatus.completed) {
        final completionId = record.completionId;
        if (completionId == null || completionId.isEmpty) {
          throw StateError(
            'This completed Qaza cannot be safely reopened because its completion marker is missing.',
          );
        }
        final reopened = await _qazaService.markCompletedAsPending(
          userId: userId,
          recordId: record.id,
        );
        if (!reopened) {
          final current = await _qazaService.repository.getRecordsByIds(
            userId: userId,
            recordIds: [record.id],
          );
          if (current.length != 1 ||
              current.single.status != QazaStatus.pending) {
            throw StateError('The matching Qaza could not be reopened.');
          }
          record = current.single;
        } else {
          record = (await _qazaService.repository.getRecordsByIds(
            userId: userId,
            recordIds: [record.id],
          ))
              .single;
        }
      }
      if (trackerCreatedId != record.id) trackerCreatedId = null;
    } else {
      final trackerId = _trackerQazaId(userId, prayerType, normalizedDate);
      final byId = await _qazaService.repository.getRecordsByIds(
        userId: userId,
        recordIds: [trackerId],
      );
      if (byId.isNotEmpty) {
        if (!_matches(
          byId.first,
          userId: userId,
          prayer: prayerType,
          date: normalizedDate,
        )) {
          throw StateError(
              'A tracker Qaza ID is already used by another record.');
        }
        record = byId.first;
      } else {
        final now = DateTime.now();
        await _qazaService.addRecords([
          QazaRecord(
            id: trackerId,
            userId: userId,
            prayerType: prayerType,
            originalDate: normalizedDate,
            status: QazaStatus.pending,
            createdAt: now,
            updatedAt: now,
          ),
        ]);
      }

      final afterCreate = await _matchingQaza(
        userId: userId,
        prayerType: prayerType,
        date: normalizedDate,
      );
      if (afterCreate.length != 1) {
        throw StateError('The missed prayer could not be saved as Qaza.');
      }
      record = afterCreate.single;
      if (record.status == QazaStatus.completed) {
        final completionId = record.completionId;
        if (completionId == null ||
            completionId.isEmpty ||
            !await _qazaService.markCompletedAsPending(
              userId: userId,
              recordId: record.id,
            )) {
          throw StateError(
              'The matching completed Qaza could not be reopened.');
        }
        record = (await _qazaService.repository.getRecordsByIds(
          userId: userId,
          recordIds: [record.id],
        ))
            .single;
      }
      trackerCreatedId = record.id == trackerId ? trackerId : null;
    }

    if (record.status != QazaStatus.pending ||
        !_matches(
          record,
          userId: userId,
          prayer: prayerType,
          date: normalizedDate,
        )) {
      throw StateError('The matching Qaza is not safely Pending.');
    }

    await _writeLog(
      userId: userId,
      prayerType: prayerType,
      date: normalizedDate,
      status: DailySalahStatus.missed,
      trackerCreatedQazaId: trackerCreatedId,
      replaceTrackerCreatedQazaId: true,
      linkedQazaId: record.id,
      replaceLinkedQazaId: true,
      completionSyncId: null,
      replaceCompletionSyncId: true,
    );
  }

  Future<bool> canUndoTrackerCreatedQaza({
    required String userId,
    required PrayerType prayerType,
    required DateTime date,
  }) async {
    final log = await logForDate(
      userId: userId,
      date: date,
      prayerType: prayerType,
    );
    final id = log?.trackerCreatedQazaId;
    if (id == null || id != _trackerQazaId(userId, prayerType, date)) {
      return false;
    }
    final records = await _qazaService.repository.getRecordsByIds(
      userId: userId,
      recordIds: [id],
    );
    if (records.length != 1) return false;
    final record = records.single;
    return record.status == QazaStatus.pending &&
        _matches(record, userId: userId, prayer: prayerType, date: date);
  }

  /// Deletes only the linked tracker-created record, and only if an atomic
  /// pending-only delete succeeds. A completed or unrelated entry is untouched.
  Future<bool> undoTrackerCreatedQaza({
    required String userId,
    required PrayerType prayerType,
    required DateTime date,
  }) async {
    final log = await logForDate(
      userId: userId,
      date: date,
      prayerType: prayerType,
    );
    final id = log?.trackerCreatedQazaId;
    if (id == null ||
        id != _trackerQazaId(userId, prayerType, date) ||
        !await canUndoTrackerCreatedQaza(
          userId: userId,
          prayerType: prayerType,
          date: date,
        )) {
      return false;
    }

    final repository = _qazaService.repository;
    if (repository is! PendingQazaRecordDeletionRepository) return false;
    final pendingRepository = repository as PendingQazaRecordDeletionRepository;
    final deleted = await pendingRepository.deletePendingRecord(
      userId: userId,
      recordId: id,
    );
    if (!deleted) return false;

    await _writeLog(
      userId: userId,
      prayerType: prayerType,
      date: date,
      status: log!.status == DailySalahStatus.missed
          ? DailySalahStatus.unrecorded
          : log.status,
      trackerCreatedQazaId: null,
      replaceTrackerCreatedQazaId: true,
      linkedQazaId: null,
      replaceLinkedQazaId: true,
      completionSyncId: null,
      replaceCompletionSyncId: true,
    );
    return true;
  }

  Future<QazaRecord?> _associatedQaza({
    required String userId,
    required PrayerType prayerType,
    required DateTime date,
    required DailySalahLog? log,
  }) async {
    final id = log?.linkedQazaId ?? log?.trackerCreatedQazaId;
    if (id != null) {
      final byId = await _qazaService.repository.getRecordsByIds(
        userId: userId,
        recordIds: [id],
      );
      if (byId.length != 1 ||
          !_matches(
            byId.single,
            userId: userId,
            prayer: prayerType,
            date: date,
          )) {
        throw StateError(
            'The linked Qaza record no longer matches this prayer.');
      }
      return byId.single;
    }

    final matching = await _matchingQaza(
      userId: userId,
      prayerType: prayerType,
      date: date,
    );
    if (matching.length > 1) {
      throw StateError('Multiple Qaza records match this prayer and date.');
    }
    return matching.isEmpty ? null : matching.single;
  }

  /// Reflects completion from any Qaza completion entry point in the linked
  /// Daily Salah log. Does not create a log for a Qaza without a matching log.
  Future<void> syncQazaCompleted({
    required String userId,
    required QazaCompletionEntry entry,
  }) async {
    final log = await logForDate(
      userId: userId,
      date: entry.originalDate,
      prayerType: entry.prayerType,
    );
    if (log == null || log.status != DailySalahStatus.missed) return;

    final linkedId = log.linkedQazaId ?? log.trackerCreatedQazaId;
    if (linkedId != null && linkedId != entry.recordId) return;
    final matching = await _matchingQaza(
      userId: userId,
      prayerType: entry.prayerType,
      date: entry.originalDate,
    );
    if (matching.length != 1 || matching.single.id != entry.recordId) return;
    if (matching.single.status != QazaStatus.completed ||
        matching.single.completionId != entry.completionId) {
      return;
    }

    await _writeLog(
      userId: userId,
      prayerType: entry.prayerType,
      date: entry.originalDate,
      status: DailySalahStatus.prayed,
      linkedQazaId: entry.recordId,
      replaceLinkedQazaId: true,
      completionSyncId: entry.completionId,
      replaceCompletionSyncId: true,
    );
  }

  /// Reverses only the status change produced by the exact completion event.
  /// A later manual status correction is preserved.
  Future<void> syncQazaReopened({
    required String userId,
    required String recordId,
    required PrayerType prayerType,
    required DateTime originalDate,
    required String expectedCompletionId,
  }) async {
    final log = await logForDate(
      userId: userId,
      date: originalDate,
      prayerType: prayerType,
    );
    if (log == null ||
        log.status != DailySalahStatus.prayed ||
        log.completionSyncId != expectedCompletionId ||
        (log.linkedQazaId ?? log.trackerCreatedQazaId) != recordId) {
      return;
    }

    final records = await _qazaService.repository.getRecordsByIds(
      userId: userId,
      recordIds: [recordId],
    );
    if (records.length != 1 ||
        records.single.status != QazaStatus.pending ||
        !_matches(
          records.single,
          userId: userId,
          prayer: prayerType,
          date: originalDate,
        )) {
      return;
    }

    await _writeLog(
      userId: userId,
      prayerType: prayerType,
      date: originalDate,
      status: DailySalahStatus.missed,
      linkedQazaId: recordId,
      replaceLinkedQazaId: true,
      completionSyncId: null,
      replaceCompletionSyncId: true,
    );
  }

  Future<List<QazaRecord>> _matchingQaza({
    required String userId,
    required PrayerType prayerType,
    required DateTime date,
  }) async {
    final page = await _qazaService.getPage(
      userId: userId,
      limit: 2,
      prayerType: prayerType,
      from: _normalizeDate(date),
      to: _normalizeDate(date),
      status: null,
    );
    return page.records
        .where((record) =>
            _matches(record, userId: userId, prayer: prayerType, date: date))
        .toList(growable: false);
  }

  bool _matches(
    QazaRecord record, {
    required String userId,
    required PrayerType prayer,
    required DateTime date,
  }) =>
      record.userId == userId &&
      record.prayerType == prayer &&
      _dayKey(record.originalDate) == _dayKey(date);

  Future<void> _writeLog({
    required String userId,
    required PrayerType prayerType,
    required DateTime date,
    required DailySalahStatus status,
    String? trackerCreatedQazaId,
    bool replaceTrackerCreatedQazaId = false,
    String? linkedQazaId,
    bool replaceLinkedQazaId = false,
    String? completionSyncId,
    bool replaceCompletionSyncId = false,
  }) async {
    final existing = await logForDate(
      userId: userId,
      date: date,
      prayerType: prayerType,
    );
    final trackerId = replaceTrackerCreatedQazaId
        ? trackerCreatedQazaId
        : trackerCreatedQazaId ?? existing?.trackerCreatedQazaId;
    final qazaId = replaceLinkedQazaId
        ? linkedQazaId
        : linkedQazaId ?? existing?.linkedQazaId;
    final syncedCompletionId = replaceCompletionSyncId
        ? completionSyncId
        : completionSyncId ?? existing?.completionSyncId;
    await _database.transactionWithRevision<void>(() async {
      await _database.customUpdate(
        'INSERT INTO daily_salah_logs '
        '(user_id, prayer_date, prayer_type, status, tracker_created_qaza_id, '
        'linked_qaza_id, completion_sync_id, updated_at) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?) '
        'ON CONFLICT(user_id, prayer_date, prayer_type) DO UPDATE SET '
        'status = excluded.status, '
        'tracker_created_qaza_id = excluded.tracker_created_qaza_id, '
        'linked_qaza_id = excluded.linked_qaza_id, '
        'completion_sync_id = excluded.completion_sync_id, '
        'updated_at = excluded.updated_at',
        variables: [
          Variable(userId),
          Variable(_dayKey(date)),
          Variable(prayerType.name),
          Variable(status.name),
          Variable(trackerId),
          Variable(qazaId),
          Variable(syncedCompletionId),
          Variable(DateTime.now().toUtc().toIso8601String()),
        ],
      );
    }, mutationPredicate: (_) => true);
  }

  Future<void> _requireEnabled() async {
    if (!await isEnabled()) {
      throw StateError('Daily Salah tracking is disabled.');
    }
  }

  static DateTime _normalizeDate(DateTime date) => QazaDate.normalize(date);

  static String _dayKey(DateTime date) {
    final normalized = _normalizeDate(date);
    final year = normalized.year.toString().padLeft(4, '0');
    final month = normalized.month.toString().padLeft(2, '0');
    final day = normalized.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  static String _trackerQazaId(
    String userId,
    PrayerType prayerType,
    DateTime date,
  ) {
    final encodedUser =
        base64Url.encode(utf8.encode(userId)).replaceAll('=', '');
    return 'daily-salah-$encodedUser-${_dayKey(date)}-${prayerType.name}';
  }
}
