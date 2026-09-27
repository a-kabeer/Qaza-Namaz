enum PrayerType {
  fajr,
  zuhr,
  asr,
  maghrib,
  isha,
  witr,
}

extension PrayerTypeX on PrayerType {
  /// Returns the next prayer in the canonical Qaza completion sequence.
  ///
  /// The order is intentionally defined by this enum rather than by any UI,
  /// database, or filtered list ordering.
  PrayerType get nextInQazaSequence =>
      PrayerType.values[(index + 1) % PrayerType.values.length];

  String get label {
    switch (this) {
      case PrayerType.fajr:
        return 'Fajr';
      case PrayerType.zuhr:
        return 'Zuhr';
      case PrayerType.asr:
        return 'Asr';
      case PrayerType.maghrib:
        return 'Maghrib';
      case PrayerType.isha:
        return 'Isha';
      case PrayerType.witr:
        return 'Witr';
    }
  }
}

const allPrayerTypes = PrayerType.values;
