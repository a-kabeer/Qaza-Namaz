import 'package:timezone/timezone.dart' as tz;

import '../../../core/constants/prayer_types.dart';
import '../../../domain/entities/user_profile.dart';
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

extension PrayerSlotQazaX on PrayerSlot {
  PrayerType? get qazaPrayerType => switch (this) {
        PrayerSlot.fajr => PrayerType.fajr,
        PrayerSlot.dhuhr => PrayerType.zuhr,
        PrayerSlot.asr => PrayerType.asr,
        PrayerSlot.maghrib => PrayerType.maghrib,
        PrayerSlot.isha => PrayerType.isha,
        PrayerSlot.sunrise => null,
      };
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
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

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
    this.calculationMadhab,
  });

  final PrayerLocation location;
  final PrayerSettings settings;
  final PrayerSchedule today;
  final PrayerSchedule tomorrow;
  final DateTime updatedAt;

  /// Cache metadata only; the Profile remains the runtime source of truth.
  /// Null means an older snapshot that must be recalculated.
  final Madhab? calculationMadhab;

  Map<String, dynamic> toJson() => {
        'location': location.toJson(),
        'settings': settings.toJson(),
        'calculationMadhab': calculationMadhab?.name,
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
        todayRaw is! Map ||
        tomorrowRaw is! Map ||
        updatedRaw is! String) {
      return null;
    }
    final location = PrayerLocation.fromJson(
      Map<String, dynamic>.from(locationRaw),
    );
    final settings = settingsRaw is Map
        ? PrayerSettings.fromJson(Map<String, dynamic>.from(settingsRaw))
        : const PrayerSettings();
    final today = PrayerSchedule.fromJson(
      Map<String, dynamic>.from(todayRaw),
    );
    final tomorrow = PrayerSchedule.fromJson(
      Map<String, dynamic>.from(tomorrowRaw),
    );
    final updatedAt = DateTime.tryParse(updatedRaw);
    final calculationMadhabName = json['calculationMadhab'];
    final calculationMadhab = calculationMadhabName is String
        ? Madhab.values.where((value) => value.name == calculationMadhabName).firstOrNull
        : null;
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
      calculationMadhab: calculationMadhab,
    );
  }
}
