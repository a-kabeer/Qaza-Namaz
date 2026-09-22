import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../domain/prayer_schedule.dart';
import '../domain/prayer_times_models.dart';
import '../domain/qaza_restriction_service.dart';
import '../domain/prayer_times_repository.dart';

class PrayerTimesNotificationService {
  PrayerTimesNotificationService({
    required PrayerTimesRepository repository,
    required DateTime Function() now,
  })  : _repository = repository,
        _now = now;

  static const _prayerBaseId = 5000;
  static const _restrictionBaseId = 6000;
  static const _daysToSchedule = 14;

  final PrayerTimesRepository _repository;
  final DateTime Function() _now;
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;

    PrayerSchedule.ensureTimezoneDatabase();
    tz_data.initializeTimeZones();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwin = DarwinInitializationSettings();

    final initialized = await _plugin.initialize(
      const InitializationSettings(
        android: android,
        iOS: darwin,
        macOS: darwin,
      ),
    );

    if (initialized != true) {
      throw StateError('Unable to initialize local notifications.');
    }

    _initialized = true;
  }

  Future<bool> requestPermission() async {
    await _ensureInitialized();

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }

    final darwin = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (darwin != null) {
      return await darwin.requestPermissions(
            alert: true,
            badge: false,
            sound: true,
          ) ??
          false;
    }

    return true;
  }

  Future<void> sync({
    required PrayerLocation location,
    required PrayerSettings settings,
    required PrayerNotificationSettings notifications,
  }) async {
    await _ensureInitialized();
    await _cancelManagedNotifications();

    if (!notifications.anyEnabled ||
        location.timezone == null ||
        location.timezone!.isEmpty) {
      return;
    }

    final firstDate = PrayerSchedule.localDate(
      location.timezone!,
      instant: _now(),
    );

    for (var dayIndex = 0; dayIndex < _daysToSchedule; dayIndex++) {
      final date = DateTime(
        firstDate.year,
        firstDate.month,
        firstDate.day + dayIndex,
      );

      final day = await _repository.getPrayerTimes(
        latitude: location.latitude,
        longitude: location.longitude,
        date: date,
        method: settings.calculationMethod,
        asrMethod: settings.asrMethod,
        timezone: location.timezone,
      );

      for (final prayer in PrayerName.values.where((p) => p.isCyclePrayer)) {
        if (!notifications.enabledPrayers.contains(prayer)) continue;
        final time = PrayerSchedule.moment(day, prayer);
        await _schedule(
          id: _prayerBaseId + (dayIndex * 16) + prayer.index,
          title: '${_prayerLabel(prayer)} Prayer',
          body: 'Prayer time: ${_formatTime(time)}',
          when: time,
        );
      }

      final periods = QazaRestrictionService(
        repository: _repository,
        now: _now,
      ).periodsForDay(day);

      for (var restrictionIndex = 0;
          restrictionIndex < periods.length;
          restrictionIndex++) {
        final period = periods[restrictionIndex];
        if (!_restrictionEnabled(notifications, period.type)) continue;

        final notifyAt = period.start.subtract(
          Duration(minutes: notifications.restrictedLeadMinutes),
        );
        await _schedule(
          id: _restrictionBaseId +
              (dayIndex * 16) +
              restrictionIndex,
          title: '${_restrictionLabel(period.type)} Restriction',
          body:
              'Restricted time starts at ${_formatTime(period.start)} and lasts ${_durationMinutes(period.start, period.end)} min.',
          when: notifyAt,
        );
      }
    }
  }

  Future<void> cancelAllManaged() async {
    await _ensureInitialized();
    await _cancelManagedNotifications();
  }

  Future<void> _schedule({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime when,
  }) async {
    if (!when.isAfter(_now())) return;

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'prayer_times',
        'Prayer Times',
        channelDescription:
            'Prayer and restricted-time reminders for Qaza Namaz.',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
      iOS: DarwinNotificationDetails(),
      macOS: DarwinNotificationDetails(),
    );

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      when,
      details,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  Future<void> _cancelManagedNotifications() async {
    for (var day = 0; day < _daysToSchedule; day++) {
      for (var index = 0; index < 8; index++) {
        await _plugin.cancel(_prayerBaseId + (day * 16) + index);
        await _plugin.cancel(_restrictionBaseId + (day * 16) + index);
      }
    }
  }

  bool _restrictionEnabled(
    PrayerNotificationSettings settings,
    RestrictionType type,
  ) {
    return switch (type) {
      RestrictionType.sunrise => settings.sunrise,
      RestrictionType.zawal => settings.zawal,
      RestrictionType.sunset => settings.sunset,
      RestrictionType.otherConfiguredRestriction => false,
    };
  }

  String _prayerLabel(PrayerName prayer) => switch (prayer) {
        PrayerName.fajr => 'Fajr • فجر',
        PrayerName.dhuhr => 'Dhuhr • ظہر',
        PrayerName.asr => 'Asr • عصر',
        PrayerName.maghrib => 'Maghrib • مغرب',
        PrayerName.isha => 'Isha • عشاء',
        PrayerName.sunrise => 'Sunrise • طلوعِ آفتاب',
      };

  String _restrictionLabel(RestrictionType type) => switch (type) {
        RestrictionType.sunrise => 'Sunrise • طلوعِ آفتاب',
        RestrictionType.zawal => 'Zawal • زوال',
        RestrictionType.sunset => 'Sunset • غروبِ آفتاب',
        RestrictionType.otherConfiguredRestriction => 'Restriction',
      };

  String _formatTime(DateTime time) => DateFormat.jm().format(time);

  int _durationMinutes(DateTime start, DateTime end) =>
      end.difference(start).inMinutes;
}
