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

  /// A compact visual identifier for prayer-selection rows.
  IconData get icon {
    switch (this) {
      case PrayerType.fajr:
        return Icons.nightlight_round;
      case PrayerType.zuhr:
        return Icons.wb_sunny_outlined;
      case PrayerType.asr:
        return Icons.wb_twilight_outlined;
      case PrayerType.maghrib:
        return Icons.brightness_4_outlined;
      case PrayerType.isha:
        return Icons.nights_stay_outlined;
      case PrayerType.witr:
        return Icons.star_outline_rounded;
    }
  }

  String get rakats {
    switch (this) {
      case PrayerType.fajr:
        return '2 rakats';
      case PrayerType.zuhr:
        return '4 rakats';
      case PrayerType.asr:
        return '4 rakats';
      case PrayerType.maghrib:
        return '3 rakats';
      case PrayerType.isha:
        return '4 rakats';
      case PrayerType.witr:
        return '3 rakats';
    }
  }
}

const allPrayerTypes = PrayerType.values;
