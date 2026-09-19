import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// What the platform layer needs in order to show a notification.
///
/// Notification text is resolved by the caller for the active locale and
/// passed in: the scheduler runs without a widget tree, so it must never
/// build user-facing strings of its own.
class NotificationContent {
  const NotificationContent({
    required this.title,
    required this.body,
    required this.channelName,
    required this.channelDescription,
  });

  final String title;
  final String body;
  final String channelName;
  final String channelDescription;
}

abstract interface class NotificationScheduler {
  Future<void> initialize();
  Future<bool> requestPermission();
  Future<bool> isPermissionGranted();

  /// Opens the platform's notification settings for this app.
  ///
  /// Once notifications are blocked the app can no longer ask for them, so
  /// this is the only way back; returns false when the screen cannot be
  /// opened.
  Future<bool> openSystemNotificationSettings();
  Future<void> scheduleDaily({
    required int hour,
    required int minute,
    required NotificationContent content,
  });
  Future<void> cancelDaily();
  Future<void> showTestNotification(NotificationContent content);
}

class LocalNotificationService implements NotificationScheduler {
  LocalNotificationService({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const int _notificationId = 3001;
  static const int _testNotificationId = 3002;
  static const String _channelId = 'qaza_daily_reminder';
  static const String _channelName = 'Qaza daily reminder';
  static const String _channelDescription =
      'Daily reminder to continue completing Qaza prayers.';

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  @override
  Future<void> initialize() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();
    // The IANA identifier is what the timezone database is keyed by; the
    // localized name this also carries is for display, not lookup.
    final timezone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timezone.identifier));

    const android = AndroidInitializationSettings('@drawable/ic_stat_qaza');
    const settings = InitializationSettings(
      android: android,
      iOS: DarwinInitializationSettings(),
    );
    await _plugin.initialize(settings);

    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.defaultImportance,
    );
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(channel);

    _initialized = true;
  }

  static const MethodChannel _settingsChannel =
      MethodChannel('qaza_namaz/notification_settings');

  @override
  Future<bool> openSystemNotificationSettings() async {
    try {
      final opened =
          await _settingsChannel.invokeMethod<bool>('openNotificationSettings');
      return opened ?? false;
    } catch (_) {
      // No channel on this platform; the caller falls back to explaining.
      return false;
    }
  }

  @override
  Future<bool> requestPermission() async {
    await initialize();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final granted = await android?.requestNotificationsPermission();
    return granted ?? true;
  }

  @override
  Future<bool> isPermissionGranted() async {
    await initialize();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final granted = await android?.areNotificationsEnabled();
    return granted ?? true;
  }

  @override
  Future<void> scheduleDaily({
    required int hour,
    required int minute,
    required NotificationContent content,
  }) async {
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      throw ArgumentError('Invalid reminder time.');
    }
    await initialize();
    await _plugin.cancel(_notificationId);

    final now = tz.TZDateTime.now(tz.local);
    var next = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (!next.isAfter(now)) {
      next = next.add(const Duration(days: 1));
    }

    final details = _detailsFor(content);

    await _plugin.zonedSchedule(
      _notificationId,
      content.title,
      content.body,
      next,
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  @override
  Future<void> cancelDaily() async {
    await initialize();
    await _plugin.cancel(_notificationId);
  }

  @override
  Future<void> showTestNotification(NotificationContent content) async {
    await initialize();
    await _plugin.show(
      _testNotificationId,
      content.title,
      content.body,
      _detailsFor(content),
    );
  }

  NotificationDetails _detailsFor(NotificationContent content) =>
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          content.channelName,
          channelDescription: content.channelDescription,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          icon: '@drawable/ic_stat_qaza',
        ),
        iOS: const DarwinNotificationDetails(),
      );
}
