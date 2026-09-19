import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

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

class NotificationPermissionInfo {
  const NotificationPermissionInfo({
    required this.granted,
    required this.canRequest,
    required this.permanentlyDenied,
    required this.supported,
    required this.sdkInt,
    required this.shouldShowRationale,
  });

  final bool granted;
  final bool canRequest;
  final bool permanentlyDenied;
  final bool supported;
  final int sdkInt;
  final bool shouldShowRationale;
}

abstract interface class NotificationScheduler {
  Future<void> initialize();
  Future<bool> requestPermission();
  Future<NotificationPermissionInfo> getPermissionInfo({
    required bool permissionRequested,
  });
  Future<bool> isPermissionGranted();
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

  static const String _channelId = 'qaza_daily_reminder_v2';
  static const String _legacyChannelId = 'qaza_daily_reminder';
  static const String _channelName = 'Qaza daily reminder';
  static const String _channelDescription =
      'Daily reminder to continue completing Qaza prayers.';

  static const MethodChannel _settingsChannel =
      MethodChannel('qaza_namaz/notification_settings');

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  void _log(String message) {
    if (kDebugMode) debugPrint('[notifications] $message');
  }

  @override
  Future<void> initialize() async {
    if (_initialized) return;

    _log('initialize: starting');

    tz_data.initializeTimeZones();
    final timezone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timezone.identifier));
    _log('timezone=${timezone.identifier}');

    const android = AndroidInitializationSettings('@drawable/ic_stat_qaza');
    const settings = InitializationSettings(
      android: android,
      iOS: DarwinInitializationSettings(),
    );

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _handleNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await _ensureChannel(androidPlugin);
    }

    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp ?? false) {
      _log(
        'cold-start notification tap detected payload=${launchDetails?.notificationResponse?.payload ?? ''}',
      );
    }

    _initialized = true;
    _log('initialize: complete');
  }

  Future<void> _ensureChannel(
    AndroidFlutterLocalNotificationsPlugin androidPlugin,
  ) async {
    final existingChannels = await androidPlugin.getNotificationChannels() ??
        <AndroidNotificationChannel>[];

    AndroidNotificationChannel? current;
    AndroidNotificationChannel? legacy;
    for (final channel in existingChannels) {
      if (channel.id == _channelId) current = channel;
      if (channel.id == _legacyChannelId) legacy = channel;
    }

    if (current == null) {
      const channel = AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.defaultImportance,
      );
      await androidPlugin.createNotificationChannel(channel);
      _log(
        'channel created id=$_channelId importance=${Importance.defaultImportance.value}',
      );
    } else {
      _log(
        'channel exists id=$_channelId importance=${current.importance.value}',
      );
      if (current.importance == Importance.none) {
        throw StateError(
          'Notification channel "$_channelId" is blocked by Android. Open system notification settings '
              'and enable it.',
        );
      }
    }

    if (legacy != null) {
      _log(
        'legacy channel found id=$_legacyChannelId importance=${legacy.importance.value}; using $_channelId',
      );
    }
  }

  Future<void> _requireUsableChannel() async {
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin == null) return;
    await _ensureChannel(androidPlugin);
  }

  @override
  Future<bool> openSystemNotificationSettings() async {
    try {
      final opened =
          await _settingsChannel.invokeMethod<bool>('openNotificationSettings');
      _log('open notification settings result=$opened');
      return opened ?? false;
    } catch (error, stack) {
      _log('open notification settings failed: $error\n$stack');
      return false;
    }
  }

  @override
  Future<bool> requestPermission() async {
    await initialize();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return true;

    final granted = await android.requestNotificationsPermission() ?? false;
    _log('permission request result=$granted');
    return granted;
  }

  @override
  Future<NotificationPermissionInfo> getPermissionInfo({
    required bool permissionRequested,
  }) async {
    await initialize();

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) {
      return const NotificationPermissionInfo(
        granted: true,
        canRequest: false,
        permanentlyDenied: false,
        supported: false,
        sdkInt: -1,
        shouldShowRationale: false,
      );
    }

    final granted = await android.areNotificationsEnabled() ?? false;
    var sdkInt = -1;
    var runtimePermission = false;
    var shouldShowRationale = false;

    try {
      final result = await _settingsChannel
          .invokeMethod<Map<dynamic, dynamic>>('getNotificationPermissionState');
      sdkInt = (result?['sdkInt'] as num?)?.toInt() ?? -1;
      runtimePermission = result?['runtimePermission'] == true;
      shouldShowRationale = result?['shouldShowRationale'] == true;
    } catch (error) {
      _log('permission diagnostics unavailable: $error');
    }

    final permanentlyDenied = !granted &&
        permissionRequested &&
        (runtimePermission ? !shouldShowRationale : sdkInt >= 0);

    final info = NotificationPermissionInfo(
      granted: granted,
      canRequest: runtimePermission && !permanentlyDenied,
      permanentlyDenied: permanentlyDenied,
      supported: true,
      sdkInt: sdkInt,
      shouldShowRationale: shouldShowRationale,
    );

    _log(
      'permission status granted=${info.granted} requested=$permissionRequested canRequest=${info.canRequest} permanentlyDenied=${info.permanentlyDenied} sdk=${info.sdkInt} rationale=${info.shouldShowRationale}',
    );
    return info;
  }

  @override
  Future<bool> isPermissionGranted() async {
    final info = await getPermissionInfo(permissionRequested: true);
    return info.granted;
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
    await _requireUsableChannel();

    final permission =
        await getPermissionInfo(permissionRequested: true);
    if (!permission.granted) {
      throw StateError(
        'Cannot schedule notification: Android notification permission '
        'is not granted.',
      );
    }

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

    _log(
      'schedule id=$_notificationId next=$next mode=inexactAllowWhileIdle channel=$_channelId',
    );

    await _plugin.zonedSchedule(
      _notificationId,
      content.title,
      content.body,
      next,
      _detailsFor(content),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );

    final pending = await _plugin.pendingNotificationRequests();
    final exists = pending.any((request) => request.id == _notificationId);
    _log(
      'schedule result id=$_notificationId pendingConfirmed=$exists',
    );
    if (!exists) {
      throw StateError(
        'Android accepted the schedule call but did not report the '
        'daily reminder as pending.',
      );
    }
  }

  @override
  Future<void> cancelDaily() async {
    await initialize();
    await _plugin.cancel(_notificationId);

    final pending = await _plugin.pendingNotificationRequests();
    final stillPending =
        pending.any((request) => request.id == _notificationId);
    _log(
      'cancel id=$_notificationId pendingAfterCancel=$stillPending',
    );
    if (stillPending) {
      throw StateError('Failed to cancel the daily notification schedule.');
    }
  }

  @override
  Future<void> showTestNotification(NotificationContent content) async {
    await initialize();
    await _requireUsableChannel();

    final permission =
        await getPermissionInfo(permissionRequested: true);
    if (!permission.granted) {
      throw StateError(
        'Cannot post test notification: Android notification permission '
        'is not granted.',
      );
    }

    _log(
      'post test notification id=$_testNotificationId channel=$_channelId',
    );

    try {
      await _plugin.show(
        _testNotificationId,
        content.title,
        content.body,
        _detailsFor(content),
        payload: 'qaza://notification/test',
      );
    } on PlatformException catch (error, stack) {
      _log(
        'test notification failed id=$_testNotificationId code=${error.code} message=${error.message ?? ''}\n$stack',
      );
      rethrow;
    } catch (error, stack) {
      _log(
        'test notification failed id=$_testNotificationId type=${error.runtimeType} message=$error\n$stack',
      );
      rethrow;
    }

    _log(
      'test notification show() completed id=$_testNotificationId',
    );
  }

  void _handleNotificationResponse(NotificationResponse response) {
    _log(
      'notification tapped id=${response.id} payload=${response.payload ?? ''} action=${response.actionId ?? ''}',
    );
  }

  NotificationDetails _detailsFor(NotificationContent content) =>
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          icon: '@drawable/ic_stat_qaza',
        ),
        iOS: DarwinNotificationDetails(),
      );
}

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {
  if (kDebugMode) {
    debugPrint(
      '[notifications] background notification response id=${response.id} payload=${response.payload ?? ''}',
    );
  }
}
