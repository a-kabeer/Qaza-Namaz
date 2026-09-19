import '../../core/constants/prayer_types.dart';
import 'qaza_calculation.dart';

/// Expands the calculated period into the same date-only range used by the
/// tracker. The calculation's end date is exclusive, so the generated dates
/// always match [QazaCalculation.totalDays].
Iterable<DateTime> trackerDates(QazaCalculation calculation) sync* {
  for (var offset = 0; offset < calculation.totalDays; offset++) {
    yield calculation.startDate.add(Duration(days: offset));
  }
}

List<PrayerType> trackerPrayerTypes({required bool includeWitr}) => [
      ...PrayerType.values.where((prayer) => prayer != PrayerType.witr),
      if (includeWitr) PrayerType.witr,
    ];

int trackerRecordCount(QazaCalculation calculation) =>
    calculation.totalDays *
    trackerPrayerTypes(includeWitr: calculation.includeWitr).length;
