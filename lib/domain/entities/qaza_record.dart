import '../../core/constants/prayer_types.dart';

enum QazaStatus { pending, completed }

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

  QazaRecord copyWith({
    QazaStatus? status,
    DateTime? completedAt,
    DateTime? updatedAt,
  }) {
    return QazaRecord(
      id: id,
      userId: userId,
      prayerType: prayerType,
      originalDate: originalDate,
      status: status ?? this.status,
      completedAt: completedAt ?? this.completedAt,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
