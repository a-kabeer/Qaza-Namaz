import '../../core/constants/prayer_types.dart';
import '../services/qaza_plan_service.dart';

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
    required this.ledgerPlanStartDate,
    required this.ledgerPlanEndDate,
    required this.ledgerTotalDays,
    required this.ledgerIncludeWitr,
    required this.ledgerTotalPrayers,
    required this.ledgerTotalWithWitr,
    required this.ledgerPlanFingerprint,
    required this.profileSnapshot,
    required this.generationOperationIds,
    required this.retirementOperationIds,
    required this.ledgerDecision,
    this.generatedOperationId,
  });

  final String revisionId;
  final String userId;
  final DateTime createdAt;

  /// The plan calculated from the current profile snapshot.
  final DateTime planStartDate;
  final DateTime planEndDate;
  final int totalDays;
  final bool includeWitr;
  final int totalPrayers;
  final int totalWithWitr;
  final String planFingerprint;

  /// The plan that the actual Qaza ledger currently represents.
  ///
  /// This can differ from the current profile calculation after the user
  /// chooses “Keep existing Qaza records”.
  final DateTime ledgerPlanStartDate;
  final DateTime ledgerPlanEndDate;
  final int ledgerTotalDays;
  final bool ledgerIncludeWitr;
  final int ledgerTotalPrayers;
  final int ledgerTotalWithWitr;
  final String ledgerPlanFingerprint;

  final Map<String, dynamic> profileSnapshot;

  /// Operations that safely generated pending profile-owned Qaza records.
  final List<String> generationOperationIds;

  /// Profile reconciliation operations that retired generated records.
  final List<String> retirementOperationIds;

  final QazaPlanLedgerDecision ledgerDecision;

  /// The operation that directly created records for the current revision.
  final String? generatedOperationId;

  factory QazaPlanRevision.fromPlan({
    required String revisionId,
    required String userId,
    required DateTime createdAt,
    required QazaPlan plan,
    required String planFingerprint,
    required Map<String, dynamic> profileSnapshot,
    required Iterable<String> generationOperationIds,
    required Iterable<String> retirementOperationIds,
    required QazaPlanLedgerDecision ledgerDecision,
    required QazaPlan ledgerPlan,
    required String ledgerPlanFingerprint,
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
      ledgerPlanStartDate: ledgerPlan.startDate,
      ledgerPlanEndDate: ledgerPlan.endDate,
      ledgerTotalDays: ledgerPlan.totalDays,
      ledgerIncludeWitr: ledgerPlan.includeWitr,
      ledgerTotalPrayers: ledgerPlan.totalPrayers,
      ledgerTotalWithWitr: ledgerPlan.totalWithWitr,
      ledgerPlanFingerprint: ledgerPlanFingerprint,
      profileSnapshot: Map.unmodifiable({
        for (final entry in profileSnapshot.entries)
          entry.key: _freeze(entry.value),
      }),
      generationOperationIds:
          List.unmodifiable(generationOperationIds.toSet()),
      retirementOperationIds:
          List.unmodifiable(retirementOperationIds.toSet()),
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
        'ledgerPlanStartDate': ledgerPlanStartDate.toIso8601String(),
        'ledgerPlanEndDate': ledgerPlanEndDate.toIso8601String(),
        'ledgerTotalDays': ledgerTotalDays,
        'ledgerIncludeWitr': ledgerIncludeWitr,
        'ledgerTotalPrayers': ledgerTotalPrayers,
        'ledgerTotalWithWitr': ledgerTotalWithWitr,
        'ledgerPlanFingerprint': ledgerPlanFingerprint,
        'profileSnapshot': profileSnapshot,
        'generationOperationIds': generationOperationIds,
        'retirementOperationIds': retirementOperationIds,
        'ledgerDecision': ledgerDecision.name,
        'generatedOperationId': generatedOperationId,
      };

  factory QazaPlanRevision.fromJson(Map<String, dynamic> json) {
    final rawSnapshot = json['profileSnapshot'];
    final generationIds = json['generationOperationIds'];
    final retirementIds = json['retirementOperationIds'];
    final start = DateTime.parse(json['planStartDate'] as String);
    final end = DateTime.parse(json['planEndDate'] as String);
    final totalDays = (json['totalDays'] as num?)?.toInt() ?? 0;
    final includeWitr = json['includeWitr'] as bool? ?? false;
    final totalPrayers = (json['totalPrayers'] as num?)?.toInt() ?? 0;
    final totalWithWitr = (json['totalWithWitr'] as num?)?.toInt() ?? 0;
    return QazaPlanRevision(
      revisionId: json['revisionId'] as String,
      userId: json['userId'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      planStartDate: start,
      planEndDate: end,
      totalDays: totalDays,
      includeWitr: includeWitr,
      totalPrayers: totalPrayers,
      totalWithWitr: totalWithWitr,
      planFingerprint: json['planFingerprint'] as String,
      ledgerPlanStartDate:
          DateTime.tryParse(json['ledgerPlanStartDate'] as String? ?? '') ?? start,
      ledgerPlanEndDate:
          DateTime.tryParse(json['ledgerPlanEndDate'] as String? ?? '') ?? end,
      ledgerTotalDays:
          (json['ledgerTotalDays'] as num?)?.toInt() ?? totalDays,
      ledgerIncludeWitr:
          json['ledgerIncludeWitr'] as bool? ?? includeWitr,
      ledgerTotalPrayers:
          (json['ledgerTotalPrayers'] as num?)?.toInt() ?? totalPrayers,
      ledgerTotalWithWitr:
          (json['ledgerTotalWithWitr'] as num?)?.toInt() ?? totalWithWitr,
      ledgerPlanFingerprint:
          json['ledgerPlanFingerprint'] as String? ??
          json['planFingerprint'] as String,
      profileSnapshot: rawSnapshot is Map
          ? Map.unmodifiable(Map<String, dynamic>.from(rawSnapshot))
          : const {},
      generationOperationIds: generationIds is Iterable
          ? List.unmodifiable(generationIds.whereType<String>())
          : const [],
      retirementOperationIds: retirementIds is Iterable
          ? List.unmodifiable(retirementIds.whereType<String>())
          : const [],
      ledgerDecision: QazaPlanLedgerDecision.values.firstWhere(
        (value) => value.name == json['ledgerDecision'],
        orElse: () => QazaPlanLedgerDecision.applied,
      ),
      generatedOperationId: json['generatedOperationId'] as String?,
    );
  }

  QazaPlan get ledgerPlan => QazaPlan(
        startDate: ledgerPlanStartDate,
        endDate: ledgerPlanEndDate,
        totalDays: ledgerTotalDays,
        includeWitr: ledgerIncludeWitr,
        totalPrayers: ledgerTotalPrayers,
        prayerBreakdown: {
          for (final prayer in const [
            PrayerType.fajr,
            PrayerType.zuhr,
            PrayerType.asr,
            PrayerType.maghrib,
            PrayerType.isha,
          ])
            prayer: ledgerTotalDays,
        },
      );

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
