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
    required this.ledgerDecision,
    this.previousProfileSnapshot = const {},
    this.changedFields = const [],
    this.addedRecords = 0,
    this.removedRecords = 0,
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

  /// The plan that the actual Qaza ledger currently represents.
  ///
  /// Existing Qaza records are never implicitly removed when a profile
  /// calculation changes. The ledger plan is the plan applied to new records.
  final DateTime ledgerPlanStartDate;
  final DateTime ledgerPlanEndDate;
  final int ledgerTotalDays;
  final bool ledgerIncludeWitr;
  final int ledgerTotalPrayers;
  final int ledgerTotalWithWitr;
  final String ledgerPlanFingerprint;

  final Map<String, dynamic> profileSnapshot;
  final QazaPlanLedgerDecision ledgerDecision;

  /// Immutable snapshot of the profile before this revision was applied.
  ///
  /// Empty for the initial plan because there is no previous profile.
  final Map<String, dynamic> previousProfileSnapshot;

  /// Profile fields that changed between [previousProfileSnapshot] and
  /// [profileSnapshot]. This is audit metadata only; it never drives ledger
  /// reconciliation.
  final List<String> changedFields;

  /// Number of Qaza records actually inserted by this revision.
  final int addedRecords;

  /// Number of pending profile-generated Qaza records actually removed by
  /// this revision. Protected completed, manual/Add-Qaza, and unattributed
  /// records are never included.
  final int removedRecords;

  factory QazaPlanRevision.fromPlan({
    required String revisionId,
    required String userId,
    required DateTime createdAt,
    required QazaPlan plan,
    required String planFingerprint,
    required Map<String, dynamic> profileSnapshot,
    required QazaPlanLedgerDecision ledgerDecision,
    required QazaPlan ledgerPlan,
    required String ledgerPlanFingerprint,
    Map<String, dynamic>? previousProfileSnapshot,
    List<String> changedFields = const [],
    int addedRecords = 0,
    int removedRecords = 0,
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
      ledgerDecision: ledgerDecision,
      previousProfileSnapshot: Map.unmodifiable({
        for (final entry in (previousProfileSnapshot ?? const <String, dynamic>{}).entries)
          entry.key: _freeze(entry.value),
      }),
      changedFields: List.unmodifiable(changedFields),
      addedRecords: addedRecords,
      removedRecords: removedRecords,
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
        'previousProfileSnapshot': previousProfileSnapshot,
        'changedFields': changedFields,
        'addedRecords': addedRecords,
        'removedRecords': removedRecords,
        'ledgerDecision': ledgerDecision.name,
      };

  factory QazaPlanRevision.fromJson(Map<String, dynamic> json) {
    final rawSnapshot = json['profileSnapshot'];
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
      previousProfileSnapshot: json['previousProfileSnapshot'] is Map
          ? Map.unmodifiable(
              Map<String, dynamic>.from(json['previousProfileSnapshot'] as Map),
            )
          : const {},
      changedFields: json['changedFields'] is List
          ? List<String>.unmodifiable(
              (json['changedFields'] as List).whereType<String>(),
            )
          : const [],
      addedRecords: (json['addedRecords'] as num?)?.toInt() ?? 0,
      removedRecords: (json['removedRecords'] as num?)?.toInt() ?? 0,
      ledgerDecision: QazaPlanLedgerDecision.values.firstWhere(
        (value) => value.name == json['ledgerDecision'],
        orElse: () => QazaPlanLedgerDecision.applied,
      ),
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
