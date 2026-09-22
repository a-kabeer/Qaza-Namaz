import 'package:flutter_test/flutter_test.dart';

import '../lib/features/prayer_times/domain/prayer_times_models.dart';
import '../lib/features/prayer_times/domain/prayer_times_repository.dart';
import '../lib/features/prayer_times/domain/qaza_restriction_service.dart';

class _Repo implements PrayerTimesRepository {
  const _Repo(this.location, this.settings, this.day);

  final PrayerLocation? location;
  final PrayerSettings settings;
  final PrayerDay day;

  @override
  Future<PrayerDay> getPrayerTimes({
    required double latitude,
    required double longitude,
    required DateTime date,
    required CalculationMethod method,
    required AsrMethod asrMethod,
    String? timezone,
  }) async => day;

  @override
  Future<PrayerLocation?> getSavedLocation() async => location;

  @override
  Future<void> saveLocation(PrayerLocation value) async {}

  @override
  Future<PrayerSettings> getSavedSettings() async => settings;

  @override
  Future<void> saveSettings(PrayerSettings value) async {}
}

PrayerDay _day() => PrayerDay(
      date: DateTime(2026, 9, 20),
      timezone: 'Asia/Karachi',
      times: const {
        PrayerName.fajr: PrayerTime(hour: 4, minute: 50),
        PrayerName.sunrise: PrayerTime(hour: 6, minute: 8),
        PrayerName.dhuhr: PrayerTime(hour: 12, minute: 20),
        PrayerName.asr: PrayerTime(hour: 16, minute: 45),
        PrayerName.maghrib: PrayerTime(hour: 18, minute: 28),
        PrayerName.isha: PrayerTime(hour: 19, minute: 44),
      },
      solarNoon: DateTime(2026, 9, 20, 12, 20),
      sunset: DateTime(2026, 9, 20, 18, 28),
      hijriDate: const HijriDate(day: 18, month: 'Rabi al-Thani', year: 1448),
      fetchedAt: DateTime.utc(2026, 9, 20),
    );

void main() {
  const location = PrayerLocation(
    latitude: 24.8607,
    longitude: 67.0011,
    country: 'Pakistan',
    city: 'Karachi',
    countryCode: 'PK',
    timezone: 'Asia/Karachi',
    source: LocationSource.manualCity,
  );

  test('blocks the configured sunrise restriction', () async {
    final service = QazaRestrictionService(
      repository: _Repo(location, const PrayerSettings(), _day()),
      now: () => DateTime.utc(2026, 9, 20, 1, 10),
    );

    final evaluation = await service.evaluateCurrent();

    expect(evaluation.isRestricted, isTrue);
    expect(evaluation.type, RestrictionType.sunrise);
    expect(evaluation.remaining, greaterThan(Duration.zero));
    expect(evaluation.nextAllowedTime, isNotNull);
  });

  test('blocks the configured zawal restriction', () async {
    final service = QazaRestrictionService(
      repository: _Repo(location, const PrayerSettings(), _day()),
      now: () => DateTime.utc(2026, 9, 20, 7, 15),
      policy: const QazaRestrictionPolicy(
        sunriseAfter: Duration.zero,
        zawalBefore: Duration(minutes: 5),
        zawalAfter: Duration(minutes: 5),
      ),
    );

    final evaluation = await service.evaluateCurrent();

    expect(evaluation.type, RestrictionType.zawal);
  });

  test('returns allowed outside restricted periods', () async {
    final service = QazaRestrictionService(
      repository: _Repo(location, const PrayerSettings(), _day()),
      calculator: const PrayerTimeCalculator(),
      now: () => DateTime.utc(2026, 9, 20, 8, 0),
      policy: const QazaRestrictionPolicy(
        sunriseAfter: Duration.zero,
        zawalBefore: Duration.zero,
        zawalAfter: Duration.zero,
        sunsetBefore: Duration(minutes: 15),
      ),
    );

    final evaluation = await service.evaluateCurrent();
    expect(evaluation.isRestricted, isFalse);
  });
}
