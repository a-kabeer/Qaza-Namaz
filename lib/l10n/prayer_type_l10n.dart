import '../core/constants/prayer_types.dart';
import '../domain/entities/qaza_record.dart';
import '../features/knowledge_base/domain/knowledge_category.dart';
import '../features/qaza/qaza_tracker_controller.dart';
import 'app_localizations.dart';

/// The single localized lookup for the six prayer names.
///
/// `PrayerTypeX.label` stays as the stable, non-localized identifier used by
/// storage-adjacent code and diagnostics; anything a user reads goes through
/// here so adding a language never means hunting down a `switch` in a widget.
extension PrayerTypeL10n on PrayerType {
  String localizedLabel(AppLocalizations l10n) => switch (this) {
        PrayerType.fajr => l10n.prayerFajr,
        PrayerType.zuhr => l10n.prayerZuhr,
        PrayerType.asr => l10n.prayerAsr,
        PrayerType.maghrib => l10n.prayerMaghrib,
        PrayerType.isha => l10n.prayerIsha,
        PrayerType.witr => l10n.prayerWitr,
      };
}

extension QazaStatusL10n on QazaStatus {
  String localizedLabel(AppLocalizations l10n) => switch (this) {
        QazaStatus.pending => l10n.statusPending,
        QazaStatus.completed => l10n.statusCompleted,
      };
}

/// Rakaat metadata shown beside a prayer name.
///
/// `PrayerTypeX.rakats` stays as the non-localized form for diagnostics; this
/// is what a user reads.
extension PrayerRakatsL10n on PrayerType {
  String localizedRakats(AppLocalizations l10n) => switch (this) {
        PrayerType.fajr => l10n.prayerRakatFajr,
        PrayerType.zuhr => l10n.prayerRakatZuhr,
        PrayerType.asr => l10n.prayerRakatAsr,
        PrayerType.maghrib => l10n.prayerRakatMaghrib,
        PrayerType.isha => l10n.prayerRakatIsha,
        PrayerType.witr => l10n.prayerRakatWitr,
      };
}

extension KnowledgeCategoryL10n on KnowledgeCategory {
  String localizedLabel(AppLocalizations l10n) => switch (this) {
        KnowledgeCategory.masail => l10n.knowledgeCategoryMasail,
        KnowledgeCategory.mugalat => l10n.knowledgeCategoryMugalat,
      };
}

extension QazaStatusFilterL10n on QazaStatusFilter {
  String localizedLabel(AppLocalizations l10n) => switch (this) {
        QazaStatusFilter.all => l10n.filterAll,
        QazaStatusFilter.pending => l10n.statusPending,
        QazaStatusFilter.completed => l10n.statusCompleted,
      };
}
