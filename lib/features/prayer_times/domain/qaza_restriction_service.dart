import 'package:timezone/timezone.dart' as tz;

import '../../../core/constants/prayer_types.dart';
import 'prayer_schedule.dart';
import 'prayer_time_calculator.dart';
import 'prayer_times_models.dart';
import 'prayer_times_repository.dart';

enum RestrictionType {
  sunrise,
  zawal,
  sunset,
  otherConfiguredRestriction,
}

class QazaRestrictionPolicy {
  const QazaRestrictionPolicy({
    this.sunriseAfter = const Duration(minutes: 15),
    this.zawalBefore = const Duration(minutes: 5),
    this.zawalAfter = const Duration(minutes: 5),
    this.sunsetBefore = const Duration(minutes: 15),
    this.sunsetAfter = Duration.zero,
  });

  final Duration sunriseAfter;
  final Duration zawalBefore;
  final Duration zawalAfter;
  final Duration sunsetBefore;
  final Duration sunsetAfter;

  bool appliesTo(PrayerType prayer) => true;
}

class QazaRestrictionPeriod {
  const QazaRestrictionPeriod({
    required this.type,
    required this.start,
    required this.end,
  });

  final RestrictionType type;
  final DateTime start;
  final DateTime end;

  bool contains(DateTime instant) =>
      !instant.isBefore(start) && instant.isBefore(end);
}

class QazaRestrictionEvaluation {
  const QazaRestrictionEvaluation({
    required this.isRestricted,
    this.type,
    this.start,
    this.end,
    this.remaining = Duration.zero,
    this.nextAllowedTime,
  });

  const QazaRestrictionEvaluation.none()
      : isRestricted = false,
        type = null,
        start = null,
        end = null,
        remaining = Duration.zero,
        nextAllowedTime = null;

  final bool isRestricted;
  final RestrictionType? type;
  final DateTime? start;
  final DateTime? end;
  final Duration remaining;
  final DateTime? nextAllowedTime;
}

class QazaRestrictionService {
  const QazaRestrictionService({
    required PrayerTimesRepository repository,
    required DateTime Function() now,
    this.policy = const QazaRestrictionPolicy(),
  })  : _repository = repository,
        _now = now;

  final PrayerTimesRepository _repository;
  final DateTime Function() _now;
  final QazaRestrictionPolicy policy;

  Future<QazaRestrictionEvaluation> evaluateCurrent() async {
    final location = await _repository.getSavedLocation();
    if (location == null) return const QazaRestrictionEvaluation.none();

    final settings = await _repository.getSavedSettings();
    final instant = _now();
    final timezone = location.timezone;
    if (timezone == null || timezone.isEmpty) {
      return const QazaRestrictionEvaluation.none();
    }

    final localNow = PrayerSchedule.now(timezone, instant: instant);
    final localDate = DateTime(localNow.year, localNow.month, localNow.day);

    final day = await _repository.getPrayerTimes(
      latitude: location.latitude,
      longitude: location.longitude,
      date: localDate,
      method: settings.calculationMethod,
      asrMethod: settings.asrMethod,
      timezone: timezone,
    );

    final periods = _periods(day, timezone);
    for (final period in periods) {
      if (period.contains(localNow)) {
        final remaining = period.end.difference(localNow);
        return QazaRestrictionEvaluation(
          isRestricted: true,
          type: period.type,
          start: period.start,
          end: period.end,
          remaining: remaining.isNegative ? Duration.zero : remaining,
          nextAllowedTime: period.end,
        );
      }
    }

    return const QazaRestrictionEvaluation.none();
  }

  Future<Map<PrayerType, QazaRestrictionEvaluation>> evaluateForPrayers(
    Iterable<PrayerType> prayers,
  ) async {
    final evaluation = await evaluateCurrent();
    return <PrayerType, QazaRestrictionEvaluation>{
      for (final prayer in prayers)
        prayer: policy.appliesTo(prayer) ? evaluation : const QazaRestrictionEvaluation.none(),
    };
  }

  List<QazaRestrictionPeriod> _periods(
    PrayerDay day,
    String timezone,
  ) {
    final location = tz.getLocation(timezone);

    DateTime at(PrayerName prayer) {
      final time = day.times[prayer]!;
      return tz.TZDateTime(
        location,
        day.date.year,
        day.date.month,
        day.date.day,
        time.hour,
        time.minute,
      );
    }

    final sunrise = at(PrayerName.sunrise);
    final sunset = day.sunset;
    final solarNoon = day.solarNoon;
    if (sunset == null || solarNoon == null) {
      return const <QazaRestrictionPeriod>[];
    }

    tz.TZDateTime wall(DateTime value) => tz.TZDateTime(
          location,
          value.year,
          value.month,
          value.day,
          value.hour,
          value.minute,
          value.second,
        );

    return <QazaRestrictionPeriod>[
      QazaRestrictionPeriod(
        type: RestrictionType.sunrise,
        start: sunrise,
        end: sunrise.add(policy.sunriseAfter),
      ),
      QazaRestrictionPeriod(
        type: RestrictionType.zawal,
        start: wall(solarNoon).subtract(policy.zawalBefore),
        end: wall(solarNoon).add(policy.zawalAfter),
      ),
      QazaRestrictionPeriod(
        type: RestrictionType.sunset,
        start: wall(sunset).subtract(policy.sunsetBefore),
        end: wall(sunset).add(policy.sunsetAfter),
      ),
    ];
  }
}
