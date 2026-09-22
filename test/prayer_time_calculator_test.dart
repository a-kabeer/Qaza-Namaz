import 'package:flutter_test/flutter_test.dart';

import '../lib/features/prayer_times/domain/prayer_time_calculator.dart';
import '../lib/features/prayer_times/domain/prayer_times_models.dart';

void main() {
  test('calculates a complete Karachi day offline', () {
    const calculator = PrayerTimeCalculator();

    final day = calculator.calculate(
      latitude: 24.8607,
      longitude: 67.0011,
      date: DateTime(2026, 9, 20),
      method: CalculationMethod.karachi,
      asrMethod: AsrMethod.hanafi,
      timezone: 'Asia/Karachi',
      countryCode: 'PK',
    );

    expect(day.timezone, 'Asia/Karachi');
    expect(day.hijriDate.day, greaterThan(0));
    expect(day.times[PrayerName.fajr], isNotNull);
    expect(day.times[PrayerName.sunrise], isNotNull);
    expect(day.times[PrayerName.dhuhr], isNotNull);
    expect(day.times[PrayerName.asr], isNotNull);
    expect(day.times[PrayerName.maghrib], isNotNull);
    expect(day.times[PrayerName.isha], isNotNull);
    expect(day.solarNoon, isNotNull);
    expect(day.sunset, isNotNull);
  });

  test('Hanafi and Standard produce distinct Asr results', () {
    const calculator = PrayerTimeCalculator();
    final standard = calculator.calculate(
      latitude: 24.8607,
      longitude: 67.0011,
      date: DateTime(2026, 9, 20),
      method: CalculationMethod.karachi,
      asrMethod: AsrMethod.standard,
      timezone: 'Asia/Karachi',
    );
    final hanafi = calculator.calculate(
      latitude: 24.8607,
      longitude: 67.0011,
      date: DateTime(2026, 9, 20),
      method: CalculationMethod.karachi,
      asrMethod: AsrMethod.hanafi,
      timezone: 'Asia/Karachi',
    );

    expect(
      hanafi.times[PrayerName.asr]!.formatted,
      isNot(standard.times[PrayerName.asr]!.formatted),
    );
  });

  test('resolves timezone locally when timezone is omitted', () {
    const calculator = PrayerTimeCalculator();
    final day = calculator.calculate(
      latitude: 51.5074,
      longitude: -0.1278,
      date: DateTime(2026, 9, 20),
      method: CalculationMethod.mwl,
      asrMethod: AsrMethod.standard,
      countryCode: 'GB',
    );

    expect(day.timezone, 'Europe/London');
  });
}
