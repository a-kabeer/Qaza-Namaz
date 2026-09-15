import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/notifications/local_notification_service.dart';

class NotificationSettingsState {
  const NotificationSettingsState({
    required this.enabled,
    required this.hour,
    required this.minute,
  });

  final bool enabled;
  final int hour;
  final int minute;

  NotificationSettingsState copyWith({
    bool? enabled,
    int? hour,
    int? minute,
  }) {
    return NotificationSettingsState(
      enabled: enabled ?? this.enabled,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
    );
  }

  String get formattedTime {
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    final suffix = hour >= 12 ? 'PM' : 'AM';
    return '${displayHour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $suffix';
  }
}

class NotificationSettingsNotifier
    extends AsyncNotifier<NotificationSettingsState> {
  static const _enabledKey = 'qaza_daily_notification_enabled';
  static const _hourKey = 'qaza_daily_notification_hour';
  static const _minuteKey = 'qaza_daily_notification_minute';

  NotificationScheduler get _scheduler => ref.read(notificationSchedulerProvider);

  @override
  Future<NotificationSettingsState> build() async {
    await _scheduler.initialize();
    final prefs = await SharedPreferences.getInstance();
    return NotificationSettingsState(
      enabled: prefs.getBool(_enabledKey) ?? false,
      hour: prefs.getInt(_hourKey) ?? 20,
      minute: prefs.getInt(_minuteKey) ?? 0,
    );
  }

  Future<bool> setEnabled(bool enabled) async {
    final current = state.valueOrNull;
    if (current == null) return false;
    if (current.enabled == enabled) return enabled;

    state = AsyncData(current.copyWith(enabled: enabled));
    try {
      if (enabled) {
        final granted = await _scheduler.requestPermission();
        if (!granted) {
          state = AsyncData(current.copyWith(enabled: false));
          await _persist(current.copyWith(enabled: false));
          return false;
        }
        await _scheduler.scheduleDaily(hour: current.hour, minute: current.minute);
      } else {
        await _scheduler.cancelDaily();
      }

      final next = current.copyWith(enabled: enabled);
      await _persist(next);
      state = AsyncData(next);
      return enabled;
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
    state = AsyncData(next);
    try {
      if (next.enabled) {
        await _scheduler.scheduleDaily(hour: hour, minute: minute);
      }
      await _persist(next);
    } catch (error, stack) {
      state = AsyncError(error, stack);
    }
  }

  Future<void> _persist(NotificationSettingsState value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, value.enabled);
    await prefs.setInt(_hourKey, value.hour);
    await prefs.setInt(_minuteKey, value.minute);
  }
}

final notificationSchedulerProvider = Provider<NotificationScheduler>(
  (ref) => LocalNotificationService(),
);

final notificationSettingsProvider =
    AsyncNotifierProvider<NotificationSettingsNotifier, NotificationSettingsState>(
  NotificationSettingsNotifier.new,
);
