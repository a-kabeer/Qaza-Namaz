import '../../core/constants/prayer_types.dart';

enum QazaStatus { pending, completed, deleted }

class QazaRecord {
  const QazaRecord({
    required this.id,
    required this.userId,
    required this.prayerType,
    required this.originalDate,
    this.status = QazaStatus.pending,
    this.completedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final PrayerType prayerType;
  final DateTime originalDate;
  final QazaStatus status;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Stable originating operation for records created by an import/add action.
  /// Legacy records return null because they predate operation provenance.
  String? get operationId {
    const prefix = 'op_';
    if (!id.startsWith(prefix)) return null;
    final remainder = id.substring(prefix.length);
    final separator = remainder.indexOf('_');
    return separator <= 0 ? null : remainder.substring(0, separator);
  }

  bool get isDeleted => status == QazaStatus.deleted;

  QazaRecord copyWith({
    String? id,
    String? userId,
    PrayerType? prayerType,
    DateTime? originalDate,
    QazaStatus? status,
    DateTime? completedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return QazaRecord(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      prayerType: prayerType ?? this.prayerType,
      originalDate: originalDate ?? this.originalDate,
      status: status ?? this.status,
      completedAt: completedAt ?? this.completedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Serializes the record to a JSON map for local persistence (Task 3H).
  /// `prayerType` and `status` are stored by name so the on-disk format is
  /// stable across enum reordering and human-readable.
  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'prayerType': prayerType.name,
        'originalDate': originalDate.toIso8601String(),
        'status': status.name,
        'completedAt': completedAt?.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  /// Reconstructs a record from a JSON map (Task 3H local cache).
  factory QazaRecord.fromJson(Map<String, dynamic> json) => QazaRecord(
        id: json['id'] as String,
        userId: json['userId'] as String,
        prayerType: PrayerType.values
            .firstWhere((v) => v.name == (json['prayerType'] as String)),
        originalDate: DateTime.parse(json['originalDate'] as String),
        status: QazaStatus.values
            .firstWhere((v) => v.name == (json['status'] as String)),
        completedAt: json['completedAt'] == null
            ? null
            : DateTime.parse(json['completedAt'] as String),
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );
}
