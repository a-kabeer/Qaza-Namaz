import 'dart:convert';

import 'package:drift/drift.dart';

import '../../core/constants/prayer_types.dart';
import '../../core/utils/qaza_date.dart';
import '../../data/local/database/app_database.dart';
import '../../domain/entities/qaza_record.dart';
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
  });

  final String userId;
  final DateTime prayerDate;
  final PrayerType prayerType;
  final DailySalahStatus status;
  final String? trackerCreatedQazaId;
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
  })  : _database = database,
        _qazaService = qazaService;

  final AppDatabase _database;
  final QazaService _qazaService;

  Future<bool> isEnabled() => _database.isDailySalahTrackingEnabled();

  Future<void> setEnabled(bool enabled) =>
      _database.setDailySalahTrackingEnabled(enabled);

  Future<Map<PrayerType, DailySalahLog>> logsForDate({
    required String userId,
    required DateTime date,
    bool includeWitr = true,
  }) async {
    final dayKey = _dayKey(date);
    final rows = await _database.customSelect(
      'SELECT user_id, prayer_date, prayer_type, status, '
      'tracker_created_qaza_id, updated_at FROM daily_salah_logs '
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
        updatedAt: DateTime.parse(row.read<String>('updated_at')),
      );
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
      'tracker_created_qaza_id, updated_at FROM daily_salah_logs '
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
      updatedAt: DateTime.parse(row.read<String>('updated_at')),
    );
  }

  /// Sets Prayed or Unrecorded. Missed must go through [recordMissed] after
  /// explicit user confirmation.
  Future<void> setStatus({
    required String userId,
    required PrayerType prayerType,
    required DateTime date,
    required DailySalahStatus status,
  }) async {
    await _requireEnabled();
    if (status == DailySalahStatus.missed) {
      throw ArgumentError('Use recordMissed after explicit confirmation.');
    }
    final existing = await logForDate(
      userId: userId,
      date: date,
      prayerType: prayerType,
    );
    if (existing == null && status == DailySalahStatus.unrecorded) return;
    await _writeLog(
      userId: userId,
      prayerType: prayerType,
      date: date,
      status: status,
    );
  }

  /// Records Missed and creates a Qaza record only when none exists for this
  /// prayer/date. Repeated calls are idempotent.
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

    if (matching.isNotEmpty) {
      final previousId = previous?.trackerCreatedQazaId;
      final deterministicId = _trackerQazaId(
        userId,
        prayerType,
        normalizedDate,
      );
      final trackerId = matching.any((record) => record.id == deterministicId)
          ? deterministicId
          : previousId != null &&
                  matching.any((record) => record.id == previousId)
              ? previousId
              : null;
      await _writeLog(
        userId: userId,
        prayerType: prayerType,
        date: normalizedDate,
        status: DailySalahStatus.missed,
        trackerCreatedQazaId: trackerId,
        replaceTrackerCreatedQazaId: true,
      );
      return;
    }

    final trackerId = _trackerQazaId(userId, prayerType, normalizedDate);
    final alreadyById = await _qazaService.repository.getRecordsByIds(
      userId: userId,
      recordIds: [trackerId],
    );
    if (alreadyById.isNotEmpty) {
      if (!_matches(alreadyById.first, userId, prayerType, normalizedDate)) {
        throw StateError('A tracker Qaza ID is already used by another record.');
      }
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

    // Verify through the canonical repository. If another Qaza record won a
    // race for this prayer/date, never claim ownership of that record.
    final created = await _qazaService.repository.getRecordsByIds(
      userId: userId,
      recordIds: [trackerId],
    );
    final verified = created.any(
      (record) => _matches(record, userId, prayerType, normalizedDate),
    );
    if (!verified) {
      final raced = await _matchingQaza(
        userId: userId,
        prayerType: prayerType,
        date: normalizedDate,
      );
      if (raced.isEmpty) {
        throw StateError('The missed prayer could not be saved as Qaza.');
      }
      await _writeLog(
        userId: userId,
        prayerType: prayerType,
        date: normalizedDate,
        status: DailySalahStatus.missed,
        trackerCreatedQazaId: null,
        replaceTrackerCreatedQazaId: true,
      );
      return;
    }

    await _writeLog(
      userId: userId,
      prayerType: prayerType,
      date: normalizedDate,
      status: DailySalahStatus.missed,
      trackerCreatedQazaId: trackerId,
      replaceTrackerCreatedQazaId: true,
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
        _matches(record, userId, prayerType, date);
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
    final deleted = await repository.deletePendingRecord(
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
    );
    return true;
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
        .where((record) => _matches(record, userId, prayerType, date))
        .toList(growable: false);
  }

  bool _matches(
    QazaRecord record,
    String userId,
    PrayerType prayerType,
    DateTime date,
  ) =>
      record.userId == userId &&
      record.prayerType == prayerType &&
      _dayKey(record.originalDate) == _dayKey(date);

  Future<void> _writeLog({
    required String userId,
    required PrayerType prayerType,
    required DateTime date,
    required DailySalahStatus status,
    String? trackerCreatedQazaId,
    bool replaceTrackerCreatedQazaId = false,
  }) async {
    final existing = await logForDate(
      userId: userId,
      date: date,
      prayerType: prayerType,
    );
    final trackerId = replaceTrackerCreatedQazaId
        ? trackerCreatedQazaId
        : trackerCreatedQazaId ?? existing?.trackerCreatedQazaId;
    await _database.transactionWithRevision<void>(() async {
      await _database.customUpdate(
        'INSERT INTO daily_salah_logs '
        '(user_id, prayer_date, prayer_type, status, tracker_created_qaza_id, updated_at) '
        'VALUES (?, ?, ?, ?, ?, ?) '
        'ON CONFLICT(user_id, prayer_date, prayer_type) DO UPDATE SET '
        'status = excluded.status, '
        'tracker_created_qaza_id = excluded.tracker_created_qaza_id, '
        'updated_at = excluded.updated_at',
        variables: [
          Variable(userId),
          Variable(_dayKey(date)),
          Variable(prayerType.name),
          Variable(status.name),
          Variable(trackerId),
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
    return 'daily-salah-' +
        encodedUser +
        '-' +
        _dayKey(date) +
        '-' +
        prayerType.name;
  }
}
