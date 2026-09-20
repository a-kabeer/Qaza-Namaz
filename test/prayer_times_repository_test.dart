import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../lib/features/prayer_times/data/prayer_times_cache.dart';
import '../lib/features/prayer_times/data/prayer_times_repository_impl.dart';
import '../lib/features/prayer_times/data/prayer_times_provider.dart';
import '../lib/features/prayer_times/domain/prayer_times_models.dart';

class _FakeProvider implements PrayerTimesProvider {
  int fetchCount = 0;

  @override
  Future<PrayerDay> fetch(PrayerTimesRequest request) async {
    fetchCount++;
    return PrayerDay(
      date: request.date,
      timezone: 'Asia/Karachi',
      times: const {
        PrayerName.fajr: PrayerTime(hour: 4, minute: 50),
        PrayerName.sunrise: PrayerTime(hour: 6, minute: 8),
        PrayerName.dhuhr: PrayerTime(hour: 12, minute: 20),
        PrayerName.asr: PrayerTime(hour: 16, minute: 45),
        PrayerName.maghrib: PrayerTime(hour: 18, minute: 28),
        PrayerName.isha: PrayerTime(hour: 19, minute: 44),
      },
      hijriDate: const HijriDate(
        day: 18,
        month: 'Rabi al-Thani',
        year: 1448,
      ),
      fetchedAt: DateTime.utc(2026, 9, 20),
    );
  }
}

void main() {
  test('repository caches by location, date and calculation settings', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final cache = PrayerTimesCache(Future.value(preferences));
    final provider = _FakeProvider();
    final repository = PrayerTimesRepositoryImpl(
      provider: provider,
      cache: cache,
    );

    final day = await repository.getPrayerTimes(
      latitude: 24.8607,
      longitude: 67.0011,
      date: DateTime(2026, 9, 20),
      method: CalculationMethod.karachi,
      asrMethod: AsrMethod.hanafi,
    );

    final exactCached = await repository.getCachedPrayerTimes(
      PrayerTimesRequest(
        latitude: 24.8607,
        longitude: 67.0011,
        date: DateTime(2026, 9, 20),
        method: CalculationMethod.karachi,
        asrMethod: AsrMethod.hanafi,
      ),
    );
    final differentSettings = await repository.getCachedPrayerTimes(
      PrayerTimesRequest(
        latitude: 24.8607,
        longitude: 67.0011,
        date: DateTime(2026, 9, 20),
        method: CalculationMethod.mwl,
        asrMethod: AsrMethod.hanafi,
      ),
    );

    expect(day.times[PrayerName.fajr]!.formatted, '04:50');
    expect(exactCached, isNotNull);
    expect(differentSettings, isNull);
    expect(provider.fetchCount, 1);
  });
}
