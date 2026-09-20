import '../domain/prayer_times_models.dart';

abstract class PrayerTimesProvider {
  Future<PrayerDay> fetch(PrayerTimesRequest request);
}

class PrayerApiException implements Exception {
  const PrayerApiException(this.message);

  final String message;

  @override
  String toString() => message;
}
