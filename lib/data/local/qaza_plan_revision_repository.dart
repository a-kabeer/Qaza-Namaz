import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/qaza_plan_revision.dart';
import '../../domain/repositories/qaza_plan_revision_repository.dart';

class SharedPreferencesQazaPlanRevisionRepository
    implements QazaPlanRevisionRepository {
  static const String _prefix = 'qaza_plan_revision_v1_';
  static const int _maxPerUser = 50;

  String _key(String userId, String revisionId) =>
      '$_prefix${userId}_${revisionId}';

  @override
  Future<QazaPlanRevision?> latest(String userId) async {
    final revisions = await _list(userId);
    return revisions.isEmpty ? null : revisions.first;
  }

  @override
  Future<void> save(QazaPlanRevision revision) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key(revision.userId, revision.revisionId),
      jsonEncode(revision.toJson()),
    );
    final revisions = await _list(revision.userId);
    for (final stale in revisions.skip(_maxPerUser)) {
      await prefs.remove(_key(revision.userId, stale.revisionId));
    }
  }

  Future<List<QazaPlanRevision>> _list(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final prefix = '$_prefix${userId}_';
    final result = <QazaPlanRevision>[];
    for (final key in prefs.getKeys()) {
      if (!key.startsWith(prefix)) continue;
      final raw = prefs.getString(key);
      if (raw == null) continue;
      try {
        final revision = QazaPlanRevision.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
        if (revision.userId == userId) result.add(revision);
      } catch (_) {
        // One damaged revision must not hide the rest of the profile history.
      }
    }
    result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return result.take(_maxPerUser).toList(growable: false);
  }
}
