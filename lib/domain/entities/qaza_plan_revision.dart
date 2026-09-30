import '../services/qaza_plan_service.dart';
import '../../core/constants/prayer_types.dart';

enum QazaPlanLedgerDecision {
  applied,
  keptExisting,
}

class QazaPlanRevision {
  const QazaPlanRevision({
    required this.revisionId,
    required this.userId,
    required this.createdAt,
    required this.planStartDate,
    required this.planEndDate,
    required this.totalDays,
    required this.includeWitr,
    required this.totalPrayers,
    required this.totalWithWitr,
    required this.planFingerprint,
    required this.profileSnapshot,
    required this.generationOperationIds,
    required this.ledgerDecision,
    this.generatedOperationId,
  });

  final String revisionId;
  final String userId;
  final DateTime createdAt;
  final DateTime planStartDate;
  final DateTime planEndDate;
  final int totalDays;
  final bool includeWitr;
  final int totalPrayers;
  final int totalWithWitr;
  final String planFingerprint;
  final Map<String, dynamic> profileSnapshot;
  final List<String> generationOperationIds;
  final QazaPlanLedgerDecision ledgerDecision;

  /// The operation that directly created records for this revision, when any.
  final String? generatedOperationId;

  factory QazaPlanRevision.fromPlan({
    required String revisionId,
    required String userId,
    required DateTime createdAt,
    required QazaPlan plan,
    required String planFingerprint,
    required Map<String, dynamic> profileSnapshot,
    required Iterable<String> generationOperationIds,
    required QazaPlanLedgerDecision ledgerDecision,
    String? generatedOperationId,
  }) {
    return QazaPlanRevision(
      revisionId: revisionId,
      userId: userId,
      createdAt: createdAt,
      planStartDate: plan.startDate,
      planEndDate: plan.endDate,
      totalDays: plan.totalDays,
      includeWitr: plan.includeWitr,
      totalPrayers: plan.totalPrayers,
      totalWithWitr: plan.totalWithWitr,
      planFingerprint: planFingerprint,
      profileSnapshot: Map.unmodifiable({
        for (final entry in profileSnapshot.entries)
          entry.key: _freeze(entry.value),
      }),
      generationOperationIds:
          List.unmodifiable(generationOperationIds.toSet()),
      ledgerDecision: ledgerDecision,
      generatedOperationId: generatedOperationId,
    );
  }

  Map<String, dynamic> toJson() => {
        'revisionId': revisionId,
        'userId': userId,
        'createdAt': createdAt.toIso8601String(),
        'planStartDate': planStartDate.toIso8601String(),
        'planEndDate': planEndDate.toIso8601String(),
        'totalDays': totalDays,
        'includeWitr': includeWitr,
        'totalPrayers': totalPrayers,
        'totalWithWitr': totalWithWitr,
        'planFingerprint': planFingerprint,
        'profileSnapshot': profileSnapshot,
        'generationOperationIds': generationOperationIds,
        'ledgerDecision': ledgerDecision.name,
        'generatedOperationId': generatedOperationId,
      };

  factory QazaPlanRevision.fromJson(Map<String, dynamic> json) {
    final rawSnapshot = json['profileSnapshot'];
    final operationIds = json['generationOperationIds'];
    return QazaPlanRevision(
      revisionId: json['revisionId'] as String,
      userId: json['userId'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      planStartDate: DateTime.parse(json['planStartDate'] as String),
      planEndDate: DateTime.parse(json['planEndDate'] as String),
      totalDays: (json['totalDays'] as num?)?.toInt() ?? 0,
      includeWitr: json['includeWitr'] as bool? ?? false,
      totalPrayers: (json['totalPrayers'] as num?)?.toInt() ?? 0,
      totalWithWitr: (json['totalWithWitr'] as num?)?.toInt() ?? 0,
      planFingerprint: json['planFingerprint'] as String,
      profileSnapshot: rawSnapshot is Map
          ? Map.unmodifiable(Map<String, dynamic>.from(rawSnapshot))
          : const {},
      generationOperationIds: operationIds is Iterable
          ? List.unmodifiable(operationIds.whereType<String>())
          : const [],
      ledgerDecision: QazaPlanLedgerDecision.values.firstWhere(
        (value) => value.name == json['ledgerDecision'],
        orElse: () => QazaPlanLedgerDecision.applied,
      ),
      generatedOperationId: json['generatedOperationId'] as String?,
    );
  }

  static dynamic _freeze(dynamic value) {
    if (value is Map) {
      return Map.unmodifiable({
        for (final entry in value.entries)
          entry.key.toString(): _freeze(entry.value),
      });
    }
    if (value is Iterable) return List.unmodifiable(value.map(_freeze));
    return value;
  }
}
