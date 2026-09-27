import 'package:timezone/timezone.dart' as tz;

import 'prayer_location.dart';
import 'prayer_settings.dart';

enum PrayerSlot {
  fajr,
  sunrise,
  dhuhr,
  asr,
  maghrib,
  isha,
}

extension PrayerSlotX on PrayerSlot {
  bool get isDailyPrayer => this != PrayerSlot.sunrise;
}

class PrayerSchedule {
  const PrayerSchedule({
    required this.date,
    required this.timesUtc,
    required this.astronomicalSunriseUtc,
    required this.astronomicalDhuhrUtc,
    required this.astronomicalSunsetUtc,
  });

  final DateTime date;
  final Map<PrayerSlot, DateTime> timesUtc;
  final DateTime astronomicalSunriseUtc;
  final DateTime astronomicalDhuhrUtc;
  final DateTime astronomicalSunsetUtc;

  DateTime utcFor(PrayerSlot prayer) => timesUtc[prayer]!;

  tz.TZDateTime localFor(PrayerSlot prayer, tz.Location location) =>
      tz.TZDateTime.from(utcFor(prayer), location);

  tz.TZDateTime localAstronomicalSunrise(tz.Location location) =>
      tz.TZDateTime.from(astronomicalSunriseUtc, location);

  tz.TZDateTime localAstronomicalDhuhr(tz.Location location) =>
      tz.TZDateTime.from(astronomicalDhuhrUtc, location);

  tz.TZDateTime localAstronomicalSunset(tz.Location location) =>
      tz.TZDateTime.from(astronomicalSunsetUtc, location);

  static String _dateKey(DateTime value) =>
      value.year.toString().padLeft(4, '0') +
      '-' +
      value.month.toString().padLeft(2, '0') +
      '-' +
      value.day.toString().padLeft(2, '0');

  Map<String, dynamic> toJson() => {
        'date': _dateKey(date),
        'timesUtc': {
          for (final entry in timesUtc.entries)
            entry.key.name: entry.value.toUtc().toIso8601String(),
        },
        'astronomicalSunriseUtc': astronomicalSunriseUtc.toUtc().toIso8601String(),
        'astronomicalDhuhrUtc': astronomicalDhuhrUtc.toUtc().toIso8601String(),
        'astronomicalSunsetUtc': astronomicalSunsetUtc.toUtc().toIso8601String(),
      };

  static PrayerSchedule? fromJson(Map<String, dynamic> json) {
    final dateRaw = json['date'];
    final timesRaw = json['timesUtc'];
    if (dateRaw is! String || timesRaw is! Map) return null;
    final date = DateTime.tryParse(dateRaw);
    if (date == null) return null;
    final times = <PrayerSlot, DateTime>{};
    for (final slot in PrayerSlot.values) {
      final raw = timesRaw[slot.name];
      if (raw is! String) return null;
      final parsed = DateTime.tryParse(raw);
      if (parsed == null) return null;
      times[slot] = parsed.toUtc();
    }
    final rawSunrise = DateTime.tryParse(
      json['astronomicalSunriseUtc'] as String? ?? '',
    );
    final rawDhuhr = DateTime.tryParse(
      json['astronomicalDhuhrUtc'] as String? ?? '',
    );
    final rawSunset = DateTime.tryParse(
      json['astronomicalSunsetUtc'] as String? ?? '',
    );
    return PrayerSchedule(
      date: DateTime(date.year, date.month, date.day),
      timesUtc: Map.unmodifiable(times),
      astronomicalSunriseUtc: (rawSunrise ?? times[PrayerSlot.sunrise]!).toUtc(),
      astronomicalDhuhrUtc: (rawDhuhr ?? times[PrayerSlot.dhuhr]!).toUtc(),
      astronomicalSunsetUtc: (rawSunset ?? times[PrayerSlot.maghrib]!).toUtc(),
    );
  }
}

class PrayerTimeSnapshot {
  const PrayerTimeSnapshot({
    required this.location,
    required this.settings,
    required this.today,
    required this.tomorrow,
    required this.updatedAt,
  });

  final PrayerLocation location;
  final PrayerSettings settings;
  final PrayerSchedule today;
  final PrayerSchedule tomorrow;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => {
        'location': location.toJson(),
        'settings': settings.toJson(),
        'today': today.toJson(),
        'tomorrow': tomorrow.toJson(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
      };

  static PrayerTimeSnapshot? fromJson(Map<String, dynamic> json) {
    final locationRaw = json['location'];
    final settingsRaw = json['settings'];
    final todayRaw = json['today'];
    final tomorrowRaw = json['tomorrow'];
    final updatedRaw = json['updatedAt'];
    if (locationRaw is! Map ||
        settingsRaw is! Map ||
        todayRaw is! Map ||
        tomorrowRaw is! Map ||
        updatedRaw is! String) {
      return null;
    }
    final location = PrayerLocation.fromJson(
      Map<String, dynamic>.from(locationRaw),
    );
    final settings = PrayerSettings.fromJson(
      Map<String, dynamic>.from(settingsRaw),
    );
    final today = PrayerSchedule.fromJson(
      Map<String, dynamic>.from(todayRaw),
    );
    final tomorrow = PrayerSchedule.fromJson(
      Map<String, dynamic>.from(tomorrowRaw),
    );
    final updatedAt = DateTime.tryParse(updatedRaw);
    if (location == null ||
        today == null ||
        tomorrow == null ||
        updatedAt == null) {
      return null;
    }
    return PrayerTimeSnapshot(
      location: location,
      settings: settings,
      today: today,
      tomorrow: tomorrow,
      updatedAt: updatedAt.toUtc(),
    );
  }
}
