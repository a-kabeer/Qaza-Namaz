import 'package:flutter/material.dart';

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

  IconData get icon {
    switch (this) {
      case PrayerType.fajr:
        return Icons.brightness_5_rounded;
      case PrayerType.zuhr:
        return Icons.wb_sunny_rounded;
      case PrayerType.asr:
        return Icons.wb_twilight_rounded;
      case PrayerType.maghrib:
        return Icons.nights_stay_rounded;
      case PrayerType.isha:
        return Icons.nightlight_round;
      case PrayerType.witr:
        return Icons.star_rounded;
    }
  }

  String get rakats {
    switch (this) {
      case PrayerType.fajr:
        return '2 rakats';
      case PrayerType.zuhr:
      case PrayerType.asr:
      case PrayerType.isha:
        return '4 rakats';
      case PrayerType.maghrib:
      case PrayerType.witr:
        return '3 rakats';
    }
  }
}

const allPrayerTypes = PrayerType.values;
