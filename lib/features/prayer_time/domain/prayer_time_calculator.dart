import 'package:adhan_dart/adhan_dart.dart';

import 'prayer_location.dart';
import 'prayer_settings.dart';
import 'prayer_time.dart';

class PrayerTimeCalculator {
  const PrayerTimeCalculator();

  PrayerSchedule calculate({
    required PrayerLocation location,
    required PrayerSettings settings,
    required DateTime localDate,
  }) {
    final coordinates = Coordinates(location.latitude, location.longitude);
    final parameters = _parameters(settings, coordinates);
    final date = DateTime(localDate.year, localDate.month, localDate.day);
    final result = PrayerTimes(
      coordinates: coordinates,
      date: date,
      calculationParameters: parameters,
      precision: true,
    );

    return PrayerSchedule(
      date: date,
      timesUtc: Map.unmodifiable({
        PrayerSlot.fajr: result.fajr.toUtc(),
        PrayerSlot.sunrise: result.sunrise.toUtc(),
        PrayerSlot.dhuhr: result.dhuhr.toUtc(),
        PrayerSlot.asr: result.asr.toUtc(),
        PrayerSlot.maghrib: result.maghrib.toUtc(),
        PrayerSlot.isha: result.isha.toUtc(),
      }),
    );
  }

  CalculationParameters _parameters(
    PrayerSettings settings,
    Coordinates coordinates,
  ) {
    final parameters = switch (settings.calculationMethod) {
      PrayerCalculationMethod.karachi => CalculationMethodParameters.karachi(),
      PrayerCalculationMethod.muslimWorldLeague =>
        CalculationMethodParameters.muslimWorldLeague(),
      PrayerCalculationMethod.isna =>
        CalculationMethodParameters.northAmerica(),
      PrayerCalculationMethod.makkah =>
        CalculationMethodParameters.ummAlQura(),
      PrayerCalculationMethod.egypt =>
        CalculationMethodParameters.egyptian(),
      PrayerCalculationMethod.tehran =>
        CalculationMethodParameters.tehran(),
      PrayerCalculationMethod.custom => CalculationParameters(
          method: CalculationMethod.other,
          fajrAngle: settings.fajrAngle,
          ishaAngle: settings.ishaAngle,
        ),
    };

    parameters.madhab = settings.asrMethod == PrayerAsrMethod.hanafi
        ? Madhab.hanafi
        : Madhab.shafi;

    parameters.highLatitudeRule = switch (settings.highLatitudeRule) {
      PrayerHighLatitudeRule.automatic =>
        HighLatitudeRule.recommended(coordinates),
      PrayerHighLatitudeRule.middleOfTheNight =>
        HighLatitudeRule.middleOfTheNight,
      PrayerHighLatitudeRule.seventhOfTheNight =>
        HighLatitudeRule.seventhOfTheNight,
      PrayerHighLatitudeRule.twilightAngle =>
        HighLatitudeRule.twilightAngle,
    };

    final adjustments = <Prayer, int>{};
    for (final entry in settings.adjustments.entries) {
      final prayer = switch (entry.key) {
        'fajr' => Prayer.fajr,
        'sunrise' => Prayer.sunrise,
        'dhuhr' => Prayer.dhuhr,
        'asr' => Prayer.asr,
        'maghrib' => Prayer.maghrib,
        'isha' => Prayer.isha,
        _ => null,
      };
      if (prayer != null && entry.value != 0) {
        adjustments[prayer] = entry.value;
      }
    }
    parameters.adjustments.addAll(adjustments);
    return parameters;
  }
}
