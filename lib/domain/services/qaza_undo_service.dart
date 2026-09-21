import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/services/qaza_service.dart';

/// One persisted undo opportunity.
///
/// The batch stores the completion timestamp for every record so an undo can
/// be conditional: a later edit, sync conflict, or other state change never
/// gets silently overwritten by an old undo action.
class QazaUndoBatch {
  const QazaUndoBatch({
    required this.completedAt,
    required this.expiresAt,
  });

  final Map<String, DateTime> completedAt;
  final DateTime expiresAt;

  List<String> get recordIds => completedAt.keys.toList(growable: false);

  bool isExpired(DateTime now) => !now.isBefore(expiresAt);

  bool matches(QazaUndoBatch other) {
    if (expiresAt != other.expiresAt || completedAt.length != other.completedAt.length) {
      return false;
    }
    for (final entry in completedAt.entries) {
      final otherTimestamp = other.completedAt[entry.key];
      if (otherTimestamp == null || !otherTimestamp.isAtSameMomentAs(entry.value)) {
        return false;
      }
    }
    return true;
  }

  Map<String, dynamic> toJson() => {
        'completedAt': {
          for (final entry in completedAt.entries)
            entry.key: entry.value.toIso8601String(),
        },
        'expiresAt': expiresAt.toIso8601String(),
      };

  factory QazaUndoBatch.fromJson(Map<String, dynamic> json) {
    final rawCompleted = json['completedAt'];
    final rawExpiresAt = json['expiresAt'];
    if (rawCompleted is! Map || rawExpiresAt is! String) {
      throw const FormatException('Invalid persisted Qaza undo batch.');
    }

    final completed = <String, DateTime>{};
    for (final entry in rawCompleted.entries) {
      if (entry.key is! String || entry.value is! String) {
        throw const FormatException('Invalid Qaza undo completion entry.');
      }
      final timestamp = DateTime.tryParse(entry.value as String);
      if (timestamp == null) {
        throw const FormatException('Invalid Qaza undo completion timestamp.');
      }
      completed[entry.key as String] = timestamp;
    }

    final expiresAt = DateTime.tryParse(rawExpiresAt);
    if (expiresAt == null || completed.isEmpty) {
      throw const FormatException('Invalid persisted Qaza undo batch.');
    }

    return QazaUndoBatch(
      completedAt: completed,
      expiresAt: expiresAt,
    );
  }
}

/// Small durable store for the currently active undo window.
///
/// Only the undo metadata is persisted. The Qaza records remain the source of
/// truth in Drift/SQLite and Firestore.
class QazaUndoStore {
  const QazaUndoStore();

  static const Duration window = Duration(seconds: 10);
  static const String _keyPrefix = 'qaza_undo_v1_';

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
    required Iterable<String> recordIds,
    required DateTime completedAt,
  }) async {
    final ids = recordIds.toSet().where((id) => id.isNotEmpty).toList();
    if (ids.isEmpty) return null;

    final batch = QazaUndoBatch(
      completedAt: {
        for (final id in ids) id: completedAt,
      },
      expiresAt: _now().add(QazaUndoStore.window),
    );
    await _store.save(userId: userId, batch: batch);
    return batch;
  }

  Future<int> undo({
    required String userId,
    required QazaService service,
    QazaUndoBatch? expectedBatch,
  }) async {
    final batch = await restore(userId: userId);
    if (batch == null) return 0;
    if (expectedBatch != null && !batch.matches(expectedBatch)) return 0;

    final undoneAt = _now();
    final count = await service.undoCompletions(
      userId: userId,
      expectedCompletedAt: batch.completedAt,
      undoneAt: undoneAt,
    );

    if (count > 0) {
      await _store.clear(userId: userId);
    } else {
      // The target changed or disappeared before the undo was used. Retiring
      // the stale action prevents an old snackbar/window from being reused.
      await _store.clear(userId: userId);
    }
    return count;
  }

  Future<void> clear({required String userId}) => _store.clear(userId: userId);
}
