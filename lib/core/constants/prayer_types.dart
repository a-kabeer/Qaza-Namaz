enum PrayerType {
  fajr,
  zuhr,
  asr,
  maghrib,
  isha,
  witr,
}

extension PrayerTypeX on PrayerType {
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
