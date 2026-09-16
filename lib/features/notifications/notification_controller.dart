import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/providers.dart';
import '../../data/notifications/local_notification_service.dart';
import '../../domain/entities/qaza_record.dart';

const _defaultReminderHour = 20;
const _defaultReminderMinute = 0;

enum NotificationPermissionStatus {
  notRequested,
  granted,
  denied,
  unavailable,
  restricted,
}

enum NotificationScheduleStatus {
  disabled,
  permissionRequired,
  noPendingQaza,
  scheduled,
}

class NotificationSettingsState {
  const NotificationSettingsState({
    required this.enabled,
    required this.hour,
    required this.minute,
    required this.permissionStatus,
    required this.hasPendingQaza,
  });

  final bool enabled;
  final int hour;
  final int minute;
  final NotificationPermissionStatus permissionStatus;
  final bool hasPendingQaza;

  bool get canSendNotifications => permissionStatus == NotificationPermissionStatus.granted;

  NotificationScheduleStatus get scheduleStatus {
    if (!enabled) return NotificationScheduleStatus.disabled;
    if (!canSendNotifications) return NotificationScheduleStatus.permissionRequired;
    if (!hasPendingQaza) return NotificationScheduleStatus.noPendingQaza;
    return NotificationScheduleStatus.scheduled;
  }

  String get formattedTime {
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    final suffix = hour >= 12 ? 'PM' : 'AM';
    return '$displayHour:${minute.toString().padLeft(2, '0')} $suffix';
  }

  NotificationSettingsState copyWith({
    bool? enabled,
    int? hour,
    int? minute,
    NotificationPermissionStatus? permissionStatus,
    bool? hasPendingQaza,
  }) {
    return NotificationSettingsState(
      enabled: enabled ?? this.enabled,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      permissionStatus: permissionStatus ?? this.permissionStatus,
      hasPendingQaza: hasPendingQaza ?? this.hasPendingQaza,
    );
  }
}

class NotificationSettingsNotifier extends AsyncNotifier<NotificationSettingsState> {
  static const _enabledKey = 'qaza_daily_notification_enabled';
  static const _hourKey = 'qaza_daily_notification_hour';
  static const _minuteKey = 'qaza_daily_notification_minute';
  static const _permissionRequestedKey = 'qaza_notification_permission_requested';

  NotificationScheduler get _scheduler => ref.read(notificationSchedulerProvider);

  String _scopedKey(String baseKey) {
    final userId = ref.read(activeUserIdProvider);
    return '$baseKey:${userId ?? 'anonymous'}';
  }

  @override
  Future<NotificationSettingsState> build() async {
    ref.listen<AsyncValue<List<QazaRecord>>>(
      qazaRecordsProvider,
      (_, next) => _listenToQazaChanges(next),
      fireImmediately: true,
    );

    await _scheduler.initialize();
    final prefs = await SharedPreferences.getInstance();
    final requested = prefs.getBool(_permissionRequestedKey) ?? false;
    final permissionGranted = await _scheduler.isPermissionGranted();
    final records = await ref.read(qazaRecordsProvider.future);
    final hasPendingQaza = records.any((record) => record.status == QazaStatus.pending);

    final permissionStatus = permissionGranted
        ? NotificationPermissionStatus.granted
        : requested
            ? NotificationPermissionStatus.denied
            : NotificationPermissionStatus.notRequested;

    return NotificationSettingsState(
      enabled: prefs.getBool(_scopedKey(_enabledKey)) ?? false,
      hour: prefs.getInt(_scopedKey(_hourKey)) ?? _defaultReminderHour,
      minute: prefs.getInt(_scopedKey(_minuteKey)) ?? _defaultReminderMinute,
      permissionStatus: permissionStatus,
      hasPendingQaza: hasPendingQaza,
    );
  }

  Future<void> refreshPermissionStatus() async {
    final current = state.valueOrNull;
    if (current == null) return;
    try {
      final granted = await _scheduler.isPermissionGranted();
      final prefs = await SharedPreferences.getInstance();
      final requested = prefs.getBool(_permissionRequestedKey) ?? false;
      final permissionStatus = granted
          ? NotificationPermissionStatus.granted
          : requested
              ? NotificationPermissionStatus.denied
              : NotificationPermissionStatus.notRequested;
      final next = current.copyWith(permissionStatus: permissionStatus);
      state = AsyncData(next);
      await _reconcile(next);
    } catch (error, stack) {
      state = AsyncError(error, stack);
    }
  }

  Future<bool> setEnabled(bool enabled) async {
    final current = state.valueOrNull;
    if (current == null) return false;

    if (!enabled) {
      try {
        await _scheduler.cancelDaily();
        final next = current.copyWith(enabled: false);
        await _persist(next, permissionRequested: null);
        state = AsyncData(next);
        return true;
      } catch (error, stack) {
        state = AsyncError(error, stack);
        return false;
      }
    }

    if (current.enabled && current.canSendNotifications) {
      await _reconcile(current);
      return true;
    }

    try {
      final granted = current.canSendNotifications || await _scheduler.requestPermission();
      if (!granted) {
        final next = current.copyWith(
          enabled: false,
          permissionStatus: NotificationPermissionStatus.denied,
        );
        await _persist(next, permissionRequested: true);
        state = AsyncData(next);
        return false;
      }

      final next = current.copyWith(
        enabled: true,
        permissionStatus: NotificationPermissionStatus.granted,
      );
      await _persist(next, permissionRequested: true);
      state = AsyncData(next);
      await _reconcile(next);
      return true;
    } catch (error, stack) {
      state = AsyncError(error, stack);
      return false;
    }
  }

  Future<void> setTime(int hour, int minute) async {
    final current = state.valueOrNull;
    if (current == null) return;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      throw ArgumentError('Invalid reminder time.');
    }

    final next = current.copyWith(hour: hour, minute: minute);
    try {
      await _persist(next, permissionRequested: null);
      state = AsyncData(next);
      await _reconcile(next);
    } catch (error, stack) {
      state = AsyncError(error, stack);
    }
  }

  Future<void> sendTestNotification() async {
    final current = state.valueOrNull;
    if (current == null) throw StateError('Notification settings are not loaded.');
    if (!current.canSendNotifications) {
      throw StateError('Notification permission is required first.');
    }
    await _scheduler.showTestNotification();
  }

  void _listenToQazaChanges(AsyncValue<List<QazaRecord>> next) {
    final records = next.valueOrNull;
    final current = state.valueOrNull;
    if (records == null || current == null) return;

    final updated = current.copyWith(
      hasPendingQaza: records.any((record) => record.status == QazaStatus.pending),
    );
    state = AsyncData(updated);
    _reconcile(updated);
  }

  Future<void> _reconcile(NotificationSettingsState value) async {
    switch (value.scheduleStatus) {
      case NotificationScheduleStatus.disabled:
      case NotificationScheduleStatus.permissionRequired:
      case NotificationScheduleStatus.noPendingQaza:
        await _scheduler.cancelDaily();
        return;
      case NotificationScheduleStatus.scheduled:
        await _scheduler.scheduleDaily(hour: value.hour, minute: value.minute);
    }
  }

  Future<void> _persist(
    NotificationSettingsState value, {
    required bool? permissionRequested,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_scopedKey(_enabledKey), value.enabled);
    await prefs.setInt(_scopedKey(_hourKey), value.hour);
    await prefs.setInt(_scopedKey(_minuteKey), value.minute);
    if (permissionRequested != null) {
      await prefs.setBool(_permissionRequestedKey, permissionRequested);
    }
  }
}

final notificationSchedulerProvider = Provider<NotificationScheduler>(
  (ref) => LocalNotificationService(),
);

final notificationSettingsProvider = AsyncNotifierProvider<NotificationSettingsNotifier, NotificationSettingsState>(
  NotificationSettingsNotifier.new,
);
