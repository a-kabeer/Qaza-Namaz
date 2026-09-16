import '../../core/constants/prayer_types.dart';
import 'qaza_progress.dart';

class QazaLedgerSummary {
  const QazaLedgerSummary({required this.total, required this.pending, required this.completed, required this.byPrayer});

  final int total;
  final int pending;
  final int completed;
  final Map<PrayerType, QazaProgress> byPrayer;
}
