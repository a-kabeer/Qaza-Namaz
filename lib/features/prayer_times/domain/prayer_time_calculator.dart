import 'package:adhan_dart/adhan_dart.dart' as adhan;
import 'package:hijri/hijri_calendar.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone_country/timezone_country.dart';

import 'prayer_times_models.dart';

class PrayerTimeCalculator {
  const PrayerTimeCalculator();

  PrayerDay calculate({
    required double latitude,
    required double longitude,
    required DateTime date,
    required CalculationMethod method,
    required AsrMethod asrMethod,
    String? timezone,
    String? countryCode,
  }) {
    final coordinates = adhan.Coordinates(latitude, longitude);
    final resolvedTimezone =
        timezone == null || timezone.trim().isEmpty
            ? TimezoneConvert.nearestTimezone(
                latitude,
                longitude,
                countryCode: countryCode,
              )
            : timezone.trim();

    if (resolvedTimezone == null ||
        !TimezoneConvert.isKnownTimezone(resolvedTimezone)) {
      throw ArgumentError('Unable to resolve a valid IANA timezone.');
    }

    _ensureTimezoneData();
    final location = tz.getLocation(resolvedTimezone);
    final parameters = _parameters(method, asrMethod);

    final calculated = adhan.PrayerTimes(
      coordinates: coordinates,
      date: DateTime(date.year, date.month, date.day),
      calculationParameters: parameters,
      precision: false,
    );

    DateTime localize(DateTime value) => tz.TZDateTime.from(value, location);

    final hijri = HijriCalendar.fromDate(date);
    final solarNoonUtc = calculated.dhuhr.subtract(
      Duration(minutes: parameters.methodAdjustments[adhan.Prayer.dhuhr] ?? 0),
    );

    return PrayerDay(
      date: DateTime(date.year, date.month, date.day),
      timezone: resolvedTimezone,
      times: <PrayerName, PrayerTime>{
        PrayerName.fajr: _toPrayerTime(localize(calculated.fajr)),
        PrayerName.sunrise: _toPrayerTime(localize(calculated.sunrise)),
        PrayerName.dhuhr: _toPrayerTime(localize(calculated.dhuhr)),
        PrayerName.asr: _toPrayerTime(localize(calculated.asr)),
        PrayerName.maghrib: _toPrayerTime(localize(calculated.maghrib)),
        PrayerName.isha: _toPrayerTime(localize(calculated.isha)),
      },
      solarNoon: localize(solarNoonUtc),
      sunset: localize(calculated.sunset),
      hijriDate: HijriDate(
        day: hijri.hDay,
        month: hijri.getLongMonthName(),
        year: hijri.hYear,
      ),
      fetchedAt: DateTime.now().toUtc(),
      resolvedCalculationMethodName:
          method == CalculationMethod.recommended ? 'Automatic (Offline)' : null,
    );
  }

  adhan.CalculationParameters _parameters(
    CalculationMethod method,
    AsrMethod asrMethod,
  ) {
    final parameters = switch (method) {
      CalculationMethod.recommended =>
        adhan.CalculationMethodParameters.muslimWorldLeague(),
      CalculationMethod.jafari =>
        adhan.CalculationMethodParameters.jafari(),
      CalculationMethod.karachi =>
        adhan.CalculationMethodParameters.karachi(),
      CalculationMethod.isna =>
        adhan.CalculationMethodParameters.northAmerica(),
      CalculationMethod.mwl =>
        adhan.CalculationMethodParameters.muslimWorldLeague(),
      CalculationMethod.makkah =>
        adhan.CalculationMethodParameters.ummAlQura(),
      CalculationMethod.egyptian =>
        adhan.CalculationMethodParameters.egyptian(),
      CalculationMethod.tehran =>
        adhan.CalculationMethodParameters.tehran(),
      CalculationMethod.gulf =>
        adhan.CalculationMethodParameters.gulfRegion(),
      CalculationMethod.kuwait =>
        adhan.CalculationMethodParameters.kuwait(),
      CalculationMethod.qatar =>
        adhan.CalculationMethodParameters.qatar(),
      CalculationMethod.singapore =>
        adhan.CalculationMethodParameters.singapore(),
      CalculationMethod.france =>
        adhan.CalculationMethodParameters.france(),
      CalculationMethod.turkey =>
        adhan.CalculationMethodParameters.turkiye(),
      CalculationMethod.russia =>
        adhan.CalculationMethodParameters.russia(),
      CalculationMethod.moonsighting =>
        adhan.CalculationMethodParameters.moonsightingCommittee(),
      CalculationMethod.dubai =>
        adhan.CalculationMethodParameters.dubai(),
      CalculationMethod.jakim =>
        adhan.CalculationMethodParameters.singapore(),
      CalculationMethod.tunisia =>
        adhan.CalculationMethodParameters.tunisia(),
      CalculationMethod.algeria =>
        adhan.CalculationMethodParameters.algerian(),
      CalculationMethod.kemenag =>
        adhan.CalculationMethodParameters.indonesian(),
      CalculationMethod.morocco =>
        adhan.CalculationMethodParameters.morocco(),
      CalculationMethod.portugal =>
        adhan.CalculationMethodParameters.portugal(),
      CalculationMethod.jordan =>
        adhan.CalculationMethodParameters.jordan(),
    };

    parameters
      ..madhab = asrMethod == AsrMethod.hanafi
          ? adhan.Madhab.hanafi
          : adhan.Madhab.shafi
      ..highLatitudeRule = adhan.HighLatitudeRule.twilightAngle;

    return parameters;
  }

  PrayerTime _toPrayerTime(DateTime value) =>
      PrayerTime(hour: value.hour, minute: value.minute);

  static bool _timezoneInitialized = false;

  static void _ensureTimezoneData() {
    if (_timezoneInitialized) return;
    tz_data.initializeTimeZones();
    _timezoneInitialized = true;
  }
}
