import '../../core/constants/prayer_types.dart';

class QazaProgress {
  const QazaProgress({
    required this.pending,
    required this.completed,
  });

  final int pending;
  final int completed;

  int get total => pending + completed;

  double get percentage {
    if (total == 0) return 0;
    return completed / total;
  }
}

class PrayerProgress {
  const PrayerProgress({
    required this.prayerType,
    required this.progress,
  });

  final PrayerType prayerType;
  final QazaProgress progress;
}
