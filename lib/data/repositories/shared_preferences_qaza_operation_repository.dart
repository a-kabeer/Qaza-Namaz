import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/qaza_operation.dart';
import '../../domain/repositories/qaza_operation_repository.dart';

class SharedPreferencesQazaOperationRepository
    implements QazaOperationRepository {
  static const String _prefix = 'qaza_operation_v1_';
  static const int _maxPerUser = 100;

  String _key(String userId, String operationId) =>
      '$_prefix${userId}_$operationId';

  @override
  Future<void> save(QazaOperation operation) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(operation.userId, operation.operationId),
        jsonEncode(operation.toJson()));
    final all = await listRecent(operation.userId, limit: _maxPerUser + 25);
    for (final stale in all.skip(_maxPerUser)) {
      await prefs.remove(_key(operation.userId, stale.operationId));
    }
  }

  @override
  Future<QazaOperation?> get(String userId, String operationId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(userId, operationId));
    if (raw == null) return null;
    try {
      return QazaOperation.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<QazaOperation>> listRecent(String userId,
      {int limit = 50}) async {
    final prefs = await SharedPreferences.getInstance();
    final prefix = '$_prefix${userId}_';
    final result = <QazaOperation>[];
    for (final key in prefs.getKeys()) {
      if (!key.startsWith(prefix)) continue;
      final raw = prefs.getString(key);
      if (raw == null) continue;
      try {
        final op =
            QazaOperation.fromJson(jsonDecode(raw) as Map<String, dynamic>);
        if (op.userId == userId) result.add(op);
      } catch (_) {
        // Ignore one damaged history item; other actions remain available.
      }
    }
    result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final safeLimit = limit.clamp(1, _maxPerUser).toInt();
    return result.take(safeLimit).toList(growable: false);
  }

  @override
  Future<void> delete(String userId, String operationId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(userId, operationId));
  }
}
