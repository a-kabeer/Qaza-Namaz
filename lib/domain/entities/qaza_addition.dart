import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/core/utils/qaza_date.dart';
import 'qaza_record.dart';

enum QazaAdditionMode { single, range, multiple }

extension QazaAdditionModeX on QazaAdditionMode {
  static QazaAdditionMode fromName(String name) =>
      QazaAdditionMode.values.firstWhere(
        (value) => value.name == name,
        orElse: () => throw StateError(
          'Unknown Qaza addition mode "$name".',
        ),
      );
}

class QazaRecordKey {
  const QazaRecordKey({
    required this.date,
    required this.prayerType,
  });

  final DateTime date;
  final PrayerType prayerType;

  String get stable =>
      '${QazaDate.normalize(date).millisecondsSinceEpoch}:${prayerType.name}';

  @override
  bool operator ==(Object other) =>
      other is QazaRecordKey && other.stable == stable;

  @override
  int get hashCode => stable.hashCode;
}

class QazaAdditionInputSnapshot {
  const QazaAdditionInputSnapshot({
    required this.schemaVersion,
    required this.mode,
    required this.selectedDates,
    required this.selectedPrayers,
  });

  final int schemaVersion;
  final QazaAdditionMode mode;
  final List<DateTime> selectedDates;
  final List<PrayerType> selectedPrayers;

  List<DateTime> get expandedDates {
    if (mode != QazaAdditionMode.range || selectedDates.length != 2) {
      return List.unmodifiable(selectedDates.map(QazaDate.normalize));
    }

    final start = QazaDate.normalize(selectedDates.first);
    final end = QazaDate.normalize(selectedDates.last);
    if (end.isBefore(start)) return const <DateTime>[];

    return List.unmodifiable([
      for (var date = start;
          !date.isAfter(end);
          date = DateTime(date.year, date.month, date.day + 1))
        date,
    ]);
  }

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'mode': mode.name,
        'selectedDates': selectedDates
            .map(QazaDate.normalize)
            .map((date) => date.toIso8601String())
            .toList(growable: false),
        'selectedPrayers':
            selectedPrayers.map((prayer) => prayer.name).toList(growable: false),
      };

  factory QazaAdditionInputSnapshot.fromJson(Map<String, dynamic> json) {
    final rawDates = json['selectedDates'];
    final rawPrayers = json['selectedPrayers'];

    return QazaAdditionInputSnapshot(
      schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? 1,
      mode: QazaAdditionModeX.fromName(
        json['mode'] as String? ?? QazaAdditionMode.single.name,
      ),
      selectedDates: List.unmodifiable(
        (rawDates is List ? rawDates : const <dynamic>[]).map(
          (value) => QazaDate.normalize(
            DateTime.parse(value as String),
          ),
        ),
      ),
      selectedPrayers: List.unmodifiable(
        (rawPrayers is List ? rawPrayers : const <dynamic>[]).map(
          (value) => PrayerType.values.firstWhere(
            (prayer) => prayer.name == value,
            orElse: () => throw StateError('Unknown prayer type "$value".'),
          ),
        ),
      ),
    );
  }
}

class QazaAddition {
  const QazaAddition({
    required this.id,
    required this.userId,
    required this.mode,
    required this.currentInputSnapshot,
    required this.revision,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final QazaAdditionMode mode;
  final QazaAdditionInputSnapshot currentInputSnapshot;
  final int revision;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class QazaAdditionListItem {
  const QazaAdditionListItem({
    required this.addition,
    required this.activeCount,
    required this.pendingCount,
    required this.completedCount,
  });

  final QazaAddition addition;
  final int activeCount;
  final int pendingCount;
  final int completedCount;
}

class QazaAdditionDetail {
  const QazaAdditionDetail({
    required this.addition,
    required this.activeCount,
    required this.pendingCount,
    required this.completedCount,
    required this.isDeleted,
  });

  final QazaAddition addition;
  final int activeCount;
  final int pendingCount;
  final int completedCount;
  final bool isDeleted;
}

class QazaDeletionActionRecordSnapshot {
  const QazaDeletionActionRecordSnapshot({
    required this.deletionActionId,
    required this.recordId,
    required this.userId,
    required this.additionId,
    required this.prayerType,
    required this.originalDate,
    required this.status,
    required this.completedAt,
    required this.completionId,
    required this.createdAt,
    required this.updatedAt,
    required this.recordVersion,
  });

  final String deletionActionId;
  final String recordId;
  final String userId;
  final String additionId;
  final PrayerType prayerType;
  final DateTime originalDate;
  final QazaStatus status;
  final DateTime? completedAt;
  final String? completionId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int recordVersion;

  QazaRecord toRecord() => QazaRecord(
        id: recordId,
        userId: userId,
        additionId: additionId,
        prayerType: prayerType,
        originalDate: originalDate,
        status: status,
        completedAt: completedAt,
        completionId: completionId,
        createdAt: createdAt,
        updatedAt: updatedAt,
        recordVersion: recordVersion,
      );
}

class QazaDeletionActionListItem {
  const QazaDeletionActionListItem({
    required this.id,
    required this.userId,
    required this.additionId,
    required this.createdAt,
    required this.deletedCount,
    required this.firstOriginalDate,
    required this.lastOriginalDate,
  });

  final String id;
  final String userId;
  final String additionId;
  final DateTime createdAt;
  final int deletedCount;
  final DateTime? firstOriginalDate;
  final DateTime? lastOriginalDate;
}

class QazaAdditionListPage {
  const QazaAdditionListPage({
    required this.items,
    required this.hasMore,
  });

  final List<QazaAdditionListItem> items;
  final bool hasMore;

  DateTime? get nextCreatedAt =>
      items.isEmpty ? null : items.last.addition.createdAt;
  String? get nextId => items.isEmpty ? null : items.last.addition.id;
}

class QazaDeletionActionPage {
  const QazaDeletionActionPage({
    required this.items,
    required this.hasMore,
  });

  final List<QazaDeletionActionListItem> items;
  final bool hasMore;

  DateTime? get nextCreatedAt => items.isEmpty ? null : items.last.createdAt;
  String? get nextId => items.isEmpty ? null : items.last.id;
}

class QazaAdditionMutationResult {
  const QazaAdditionMutationResult({
    this.additionId,
    this.revision,
    this.addedCount = 0,
    this.removedCount = 0,
    this.protectedCount = 0,
    this.skippedCount = 0,
    this.insertedRecordIds = const <String>[],
    this.removedRecordIds = const <String>[],
    this.cancelled = false,
  });

  final String? additionId;
  final int? revision;
  final int addedCount;
  final int removedCount;
  final int protectedCount;
  final int skippedCount;
  final List<String> insertedRecordIds;
  final List<String> removedRecordIds;
  final bool cancelled;
}

class QazaDeletionResult {
  const QazaDeletionResult({
    required this.additionId,
    this.deletionActionId,
    this.deletedCount = 0,
    this.protectedCount = 0,
  });

  final String additionId;
  final String? deletionActionId;
  final int deletedCount;
  final int protectedCount;

  bool get createdAction => deletionActionId != null && deletedCount > 0;
}

class QazaRestoreResult {
  const QazaRestoreResult({
    required this.deletionActionId,
    this.restoredCount = 0,
    this.conflictCount = 0,
    this.alreadyResolved = false,
  });

  final String deletionActionId;
  final int restoredCount;
  final int conflictCount;
  final bool alreadyResolved;
}
