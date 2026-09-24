import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/prayer_types.dart';
import '../../domain/entities/qaza_record.dart';
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
  String toString() => 'QazaUndoException(reason: ' +
      reason.toString() +
      (cause == null ? '' : ', cause: ' + cause.toString()) +
      ')';
}

/// One completion captured by the active undo window.
class QazaUndoEntry {
  const QazaUndoEntry({
    required this.recordId,
    required this.completionId,
    required this.prayerType,
    required this.originalDate,
  });

  final String recordId;
  final String completionId;
  final PrayerType prayerType;
  final DateTime originalDate;

  Map<String, dynamic> toJson() => {
        'recordId': recordId,
        'completionId': completionId,
        'prayerType': prayerType.name,
        'originalDate': originalDate.toIso8601String(),
      };

  factory QazaUndoEntry.fromJson(Map<String, dynamic> json) {
    final recordId = json['recordId'] as String?;
    final completionId = json['completionId'] as String?;
    final prayerName = json['prayerType'] as String?;
    final originalDate = json['originalDate'] as String?;
    if (recordId == null ||
        recordId.isEmpty ||
        completionId == null ||
        completionId.isEmpty ||
        prayerName == null ||
        originalDate == null) {
      throw const FormatException('Invalid persisted Qaza undo entry.');
    }

    return QazaUndoEntry(
      recordId: recordId,
      completionId: completionId,
      prayerType: PrayerType.values.firstWhere(
        (value) => value.name == prayerName,
        orElse: () => throw FormatException(
          'Unknown prayer type in Qaza undo entry: ' + prayerName,
        ),
      ),
      originalDate: DateTime.parse(originalDate),
    );
  }
}

/// Persisted metadata for the one active completion Undo window.
class QazaUndoBatch {
  const QazaUndoBatch({
    required this.entries,
    required this.expiresAt,
  });

  final List<QazaUndoEntry> entries;
  final DateTime expiresAt;

  List<String> get recordIds =>
      entries.map((entry) => entry.recordId).toList(growable: false);

  Map<String, String> get completionIds => {
        for (final entry in entries) entry.recordId: entry.completionId,
      };

  bool isExpired(DateTime now) => !now.isBefore(expiresAt);

  bool matches(QazaUndoBatch other) {
    if (!expiresAt.isAtSameMomentAs(other.expiresAt) ||
        entries.length != other.entries.length) {
      return false;
    }

    for (var index = 0; index < entries.length; index++) {
      final left = entries[index];
      final right = other.entries[index];
      if (left.recordId != right.recordId ||
          left.completionId != right.completionId ||
          left.prayerType != right.prayerType ||
          !left.originalDate.isAtSameMomentAs(right.originalDate)) {
        return false;
      }
    }
    return true;
  }

  Map<String, dynamic> toJson() => {
        'entries': entries.map((entry) => entry.toJson()).toList(),
        'expiresAt': expiresAt.toIso8601String(),
      };

  factory QazaUndoBatch.fromJson(Map<String, dynamic> json) {
    final rawEntries = json['entries'];
    final rawExpiresAt = json['expiresAt'];
    if (rawEntries is! List || rawExpiresAt is! String) {
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
      entries: List.unmodifiable(entries),
      expiresAt: expiresAt,
    );
  }
}

/// Small durable store for the currently active undo window.
class QazaUndoStore {
  const QazaUndoStore();

  static const Duration window = Duration(seconds: 5);
  static const String _keyPrefix = 'qaza_undo_v2_';

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
  });

  final QazaUndoBatch batch;
  final int count;
}

/// Coordinates persistence and conditional completion rollback.
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

  Future<QazaUndoBatch?> register({
    required String userId,
    required Iterable<QazaRecord> records,
  }) async {
    final entries = <QazaUndoEntry>[];
    final seen = <String>{};

    for (final record in records) {
      final completionId = record.completionId;
      if (record.id.isEmpty ||
          record.status != QazaStatus.completed ||
          completionId == null ||
          completionId.isEmpty ||
          !seen.add(record.id)) {
        continue;
      }
      entries.add(
        QazaUndoEntry(
          recordId: record.id,
          completionId: completionId,
          prayerType: record.prayerType,
          originalDate: record.originalDate,
        ),
      );
    }

    if (entries.isEmpty) return null;

    final batch = QazaUndoBatch(
      entries: List.unmodifiable(entries),
      expiresAt: _now().add(QazaUndoStore.window),
    );
    await _store.save(userId: userId, batch: batch);
    return batch;
  }

  Future<QazaUndoResult> undo({
    required String userId,
    required QazaService service,
    QazaUndoBatch? expectedBatch,
  }) async {
    try {
      final batch = await restore(userId: userId);
      if (batch == null) {
        throw const QazaUndoException(
          reason: QazaUndoFailureReason.expired,
        );
      }
      if (expectedBatch != null && !batch.matches(expectedBatch)) {
        await _store.clear(userId: userId);
        throw const QazaUndoException(
          reason: QazaUndoFailureReason.staleBatch,
        );
      }

      // Once the active action has been accepted for this tap, consume it
      // before the persistence call. Any target change, zero-count result, or
      // exception must remove the stale Undo action rather than leaving a
      // misleading retryable action behind.
      await _store.clear(userId: userId);

      final count = await service.undoCompletions(
        userId: userId,
        expectedCompletionIds: batch.completionIds,
        undoneAt: _now(),
      );

      await _store.clear(userId: userId);

      if (count == 0) {
        throw const QazaUndoException(
          reason: QazaUndoFailureReason.targetChanged,
        );
      }

      return QazaUndoResult(batch: batch, count: count);
    } catch (error, stack) {
      // Clearing the stale/consumed action is best-effort and must never mask
      // the original failure or its stack trace.
      try {
        await _store.clear(userId: userId);
      } catch (_) {}

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
