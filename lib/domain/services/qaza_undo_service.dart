import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/prayer_types.dart';
import '../../core/utils/qaza_completion_id.dart';
import '../entities/qaza_completion_result.dart';
import '../entities/qaza_record.dart';
import 'qaza_service.dart';

enum QazaUndoFailureReason {
  expired,
  staleBatch,
  targetChanged,
  failed,
}

class QazaUndoException implements Exception {
  const QazaUndoException({
    required this.reason,
    this.cause,
  });

  final QazaUndoFailureReason reason;
  final Object? cause;

  @override
  String toString() => 'QazaUndoException(reason: $reason, cause: $cause)';
}

/// One completion captured by the active undo window.
class QazaUndoEntry {
  const QazaUndoEntry({
    required this.recordId,
    required this.completionId,
    required this.prayerType,
    required this.originalDate,
    required this.completedAt,
  });

  final String recordId;
  final String completionId;
  final PrayerType prayerType;
  final DateTime originalDate;
  final DateTime completedAt;

  Map<String, dynamic> toJson() => {
        'recordId': recordId,
        'completionId': completionId,
        'prayerType': prayerType.name,
        'originalDate': originalDate.toIso8601String(),
        'completedAt': completedAt.toIso8601String(),
      };

  factory QazaUndoEntry.fromJson(Map<String, dynamic> json) {
    final recordId = json['recordId'] as String?;
    final completionId = json['completionId'] as String?;
    final prayerName = json['prayerType'] as String?;
    final originalDate = json['originalDate'] as String?;
    final completedAt = json['completedAt'] as String?;
    if (recordId == null ||
        recordId.isEmpty ||
        completionId == null ||
        completionId.isEmpty ||
        prayerName == null ||
        originalDate == null ||
        completedAt == null) {
      throw const FormatException('Invalid persisted Qaza undo entry.');
    }

    return QazaUndoEntry(
      recordId: recordId,
      completionId: completionId,
      prayerType: PrayerType.values.firstWhere(
        (value) => value.name == prayerName,
        orElse: () => throw FormatException(
          'Unknown prayer type in Qaza undo entry: $prayerName',
        ),
      ),
      originalDate: DateTime.parse(originalDate),
      completedAt: DateTime.parse(completedAt),
    );
  }
}

/// Persisted metadata for the one active completion Undo window.
///
/// The session groups recent completions only for temporary Undo convenience;
/// each entry remains independently identifiable and reversible.
class QazaUndoBatch {
  const QazaUndoBatch({
    required this.sessionId,
    required this.entries,
    required this.expiresAt,
  });

  final String sessionId;
  final List<QazaUndoEntry> entries;
  final DateTime expiresAt;

  List<String> get recordIds =>
      entries.map((entry) => entry.recordId).toList(growable: false);

  Map<String, String> get completionIds => {
        for (final entry in entries) entry.recordId: entry.completionId,
      };

  bool isExpired(DateTime now) => !now.isBefore(expiresAt);

  bool matches(QazaUndoBatch other) {
    if (sessionId != other.sessionId ||
        !expiresAt.isAtSameMomentAs(other.expiresAt) ||
        entries.length != other.entries.length) {
      return false;
    }

    for (var index = 0; index < entries.length; index++) {
      final left = entries[index];
      final right = other.entries[index];
      if (left.recordId != right.recordId ||
          left.completionId != right.completionId ||
          left.prayerType != right.prayerType ||
          !left.originalDate.isAtSameMomentAs(right.originalDate) ||
          !left.completedAt.isAtSameMomentAs(right.completedAt)) {
        return false;
      }
    }
    return true;
  }

  Map<String, dynamic> toJson() => {
        'sessionId': sessionId,
        'entries': entries.map((entry) => entry.toJson()).toList(),
        'expiresAt': expiresAt.toIso8601String(),
      };

  factory QazaUndoBatch.fromJson(Map<String, dynamic> json) {
    final rawSessionId = json['sessionId'];
    final rawEntries = json['entries'];
    final rawExpiresAt = json['expiresAt'];
    if (rawSessionId is! String ||
        rawSessionId.isEmpty ||
        rawEntries is! List ||
        rawExpiresAt is! String) {
      throw const FormatException('Invalid persisted Qaza undo batch.');
    }

    final expiresAt = DateTime.tryParse(rawExpiresAt);
    if (expiresAt == null || rawEntries.isEmpty) {
      throw const FormatException('Invalid persisted Qaza undo batch.');
    }

    final entries = <QazaUndoEntry>[
      for (final raw in rawEntries)
        if (raw is Map<String, dynamic>)
          QazaUndoEntry.fromJson(raw)
        else
          throw const FormatException('Invalid Qaza undo entry.'),
    ];

    final ids = entries.map((entry) => entry.recordId).toSet();
    if (entries.isEmpty || ids.length != entries.length) {
      throw const FormatException('Invalid persisted Qaza undo batch.');
    }

    return QazaUndoBatch(
      sessionId: rawSessionId,
      entries: List.unmodifiable(entries),
      expiresAt: expiresAt,
    );
  }
}

class QazaUndoStore {
  const QazaUndoStore();

  static const Duration window = Duration(seconds: 5);
  static const String _keyPrefix = 'qaza_undo_v3_';

  String _key(String userId) => '$_keyPrefix$userId';

  Future<void> save({
    required String userId,
    required QazaUndoBatch batch,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(userId), jsonEncode(batch.toJson()));
  }

  Future<QazaUndoBatch?> load({
    required String userId,
    required DateTime now,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(userId));
    if (raw == null) return null;

    try {
      final batch =
          QazaUndoBatch.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      if (batch.isExpired(now)) {
        await prefs.remove(_key(userId));
        return null;
      }
      return batch;
    } catch (_) {
      await prefs.remove(_key(userId));
      return null;
    }
  }

  Future<void> clear({required String userId}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(userId));
  }
}

class QazaUndoResult {
  const QazaUndoResult({
    required this.batch,
    required this.count,
    required this.remainingBatch,
  });

  final QazaUndoBatch batch;
  final int count;
  final QazaUndoBatch? remainingBatch;
}

class QazaUndoManager {
  QazaUndoManager({
    QazaUndoStore? store,
    DateTime Function()? now,
  })  : _store = store ?? const QazaUndoStore(),
        _now = now ?? DateTime.now;

  final QazaUndoStore _store;
  final DateTime Function() _now;

  Future<QazaUndoBatch?> restore({required String userId}) =>
      _store.load(userId: userId, now: _now());

  /// Compatibility entry point for callers that still have QazaRecord objects.
  Future<QazaUndoBatch?> register({
    required String userId,
    required Iterable<QazaRecord> records,
  }) {
    final entries = [
      for (final record in records)
        if (record.status == QazaStatus.completed &&
            record.completionId != null &&
            record.completionId!.isNotEmpty &&
            record.completedAt != null)
          QazaCompletionEntry(
            recordId: record.id,
            completionId: record.completionId!,
            prayerType: record.prayerType,
            originalDate: record.originalDate,
            completedAt: record.completedAt!,
          ),
    ];
    return registerEntries(userId: userId, entries: entries);
  }

  Future<QazaUndoBatch?> registerEntries({
    required String userId,
    required Iterable<QazaCompletionEntry> entries,
  }) async {
    final now = _now();
    final existing = await _store.load(userId: userId, now: now);
    final combined = <QazaUndoEntry>[
      ...?existing?.entries,
    ];
    final seen = combined.map((entry) => entry.recordId).toSet();

    for (final entry in entries) {
      if (entry.recordId.isEmpty ||
          entry.completionId.isEmpty ||
          !seen.add(entry.recordId)) {
        continue;
      }
      combined.add(
        QazaUndoEntry(
          recordId: entry.recordId,
          completionId: entry.completionId,
          prayerType: entry.prayerType,
          originalDate: entry.originalDate,
          completedAt: entry.completedAt,
        ),
      );
    }

    if (combined.isEmpty) return existing;

    final batch = QazaUndoBatch(
      sessionId: existing?.sessionId ?? newQazaCompletionId(),
      entries: List.unmodifiable(combined),
      expiresAt: now.add(QazaUndoStore.window),
    );
    await _store.save(userId: userId, batch: batch);
    return batch;
  }

  Future<QazaUndoResult> undo({
    required String userId,
    required QazaService service,
    QazaUndoBatch? expectedBatch,
  }) =>
      _undoEntries(
        userId: userId,
        service: service,
        expectedBatch: expectedBatch,
        selectedIds: null,
      );

  Future<QazaUndoResult> undoSelected({
    required String userId,
    required QazaService service,
    required QazaUndoBatch expectedBatch,
    required Set<String> selectedIds,
  }) =>
      _undoEntries(
        userId: userId,
        service: service,
        expectedBatch: expectedBatch,
        selectedIds: selectedIds,
      );

  Future<QazaUndoResult> _undoEntries({
    required String userId,
    required QazaService service,
    required QazaUndoBatch? expectedBatch,
    required Set<String>? selectedIds,
  }) async {
    try {
      final batch = await restore(userId: userId);
      if (batch == null) {
        throw const QazaUndoException(
          reason: QazaUndoFailureReason.expired,
        );
      }
      if (expectedBatch != null && !batch.matches(expectedBatch)) {
        // Never clear the store here: it may contain a newer session.
        throw const QazaUndoException(
          reason: QazaUndoFailureReason.staleBatch,
        );
      }

      final targetEntries = selectedIds == null
          ? batch.entries
          : batch.entries
              .where((entry) => selectedIds.contains(entry.recordId))
              .toList(growable: false);
      if (targetEntries.isEmpty) {
        throw const QazaUndoException(
          reason: QazaUndoFailureReason.targetChanged,
        );
      }

      final changedIds = await service.undoCompletions(
        userId: userId,
        expectedCompletionIds: {
          for (final entry in targetEntries)
            entry.recordId: entry.completionId,
        },
        undoneAt: _now(),
      );

      final changedSet = changedIds.toSet();
      final remainingEntries = batch.entries
          .where((entry) => !changedSet.contains(entry.recordId))
          .toList(growable: false);

      final latest = await _store.load(userId: userId, now: _now());
      QazaUndoBatch? remainingBatch = remainingEntries.isEmpty
          ? null
          : QazaUndoBatch(
              sessionId: batch.sessionId,
              entries: List.unmodifiable(remainingEntries),
              expiresAt: batch.expiresAt,
            );

      if (latest != null && latest.matches(batch)) {
        if (remainingBatch == null || remainingBatch.isExpired(_now())) {
          await _store.clear(userId: userId);
          remainingBatch = null;
        } else {
          await _store.save(userId: userId, batch: remainingBatch);
        }
      } else if (latest != null) {
        // A newer session won the race; never overwrite it.
        remainingBatch = latest;
      }

      if (changedIds.isEmpty) {
        throw const QazaUndoException(
          reason: QazaUndoFailureReason.targetChanged,
        );
      }

      return QazaUndoResult(
        batch: batch,
        count: changedIds.length,
        remainingBatch: remainingBatch,
      );
    } catch (error, stack) {
      if (error is QazaUndoException) rethrow;
      final wrapped = QazaUndoException(
        reason: QazaUndoFailureReason.failed,
        cause: error,
      );
      Error.throwWithStackTrace(wrapped, stack);
    }
  }

  Future<void> clear({required String userId}) => _store.clear(userId: userId);
}
