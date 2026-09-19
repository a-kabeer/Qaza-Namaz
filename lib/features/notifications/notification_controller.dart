import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/providers.dart';
import '../../data/notifications/local_notification_service.dart';
import '../../domain/entities/qaza_progress.dart';
import '../../l10n/app_localizations.dart';

const _defaultReminderHour = 20;
const _defaultReminderMinute = 0;

enum NotificationPermissionStatus {
  notRequested,
  granted,
  denied,
  permanentlyDenied,
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
    this.pendingCountKnown = true,
  });

  final bool enabled;
  final int hour;
  final int minute;
  final NotificationPermissionStatus permissionStatus;
  final bool hasPendingQaza;
  final bool pendingCountKnown;

  bool get canSendNotifications =>
      permissionStatus == NotificationPermissionStatus.granted;

  NotificationScheduleStatus get scheduleStatus {
    if (!enabled) return NotificationScheduleStatus.disabled;
    if (!canSendNotifications) {
      return NotificationScheduleStatus.permissionRequired;
    }
    if (!hasPendingQaza) return NotificationScheduleStatus.noPendingQaza;
    return NotificationScheduleStatus.scheduled;
  }

  String get formattedTime {
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    final suffix = hour >= 12 ? 'PM' : 'AM';
    return displayHour.toString() +
        ':' +
        minute.toString().padLeft(2, '0') +
        ' ' +
        suffix;
  }

  NotificationSettingsState copyWith({
    bool? enabled,
    int? hour,
    int? minute,
    NotificationPermissionStatus? permissionStatus,
    bool? hasPendingQaza,
    bool? pendingCountKnown,
  }) {
    return NotificationSettingsState(
      enabled: enabled ?? this.enabled,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      permissionStatus: permissionStatus ?? this.permissionStatus,
      hasPendingQaza: hasPendingQaza ?? this.hasPendingQaza,
      pendingCountKnown: pendingCountKnown ?? this.pendingCountKnown,
    );
  }
}

class NotificationSettingsNotifier
    extends AsyncNotifier<NotificationSettingsState> {
  static const _enabledKey = 'qaza_daily_notification_enabled';
  static const _hourKey = 'qaza_daily_notification_hour';
  static const _minuteKey = 'qaza_daily_notification_minute';
  static const _permissionRequestedKey =
      'qaza_notification_permission_requested';

  NotificationScheduler get _scheduler =>
      ref.read(notificationSchedulerProvider);

  NotificationContent _content({bool test = false}) {
    final l10n = lookupAppLocalizations(ref.read(localeProvider));
    return NotificationContent(
      title: test ? l10n.notificationTestTitle : l10n.notificationReminderTitle,
      body: test ? l10n.notificationTestBody : l10n.notificationReminderBody,
      channelName: l10n.notificationChannelName,
      channelDescription: l10n.notificationChannelDescription,
    );
  }

  String _scopedKey(String baseKey) {
    final userId = ref.read(activeUserIdProvider);
    return '$baseKey:' + (userId ?? 'anonymous');
  }

  @override
  Future<NotificationSettingsState> build() async {
    ref.listen<AsyncValue<QazaProgressSummary>>(
      progressSummaryProvider,
      (_, next) => _listenToQazaChanges(next),
    );

    final prefs = await SharedPreferences.getInstance();
    final requested =
        prefs.getBool(_scopedKey(_permissionRequestedKey)) ?? false;

    final schedulerReady = await _initializeScheduler();
    final permissionStatus = schedulerReady
        ? await _resolvePermissionStatus(requested: requested)
        : NotificationPermissionStatus.unavailable;

    final pending = await _readPendingQaza();

    final settings = NotificationSettingsState(
      enabled: prefs.getBool(_scopedKey(_enabledKey)) ?? false,
      hour: prefs.getInt(_scopedKey(_hourKey)) ?? _defaultReminderHour,
      minute: prefs.getInt(_scopedKey(_minuteKey)) ?? _defaultReminderMinute,
      permissionStatus: permissionStatus,
      hasPendingQaza: pending ?? false,
      pendingCountKnown: pending != null,
    );

    try {
      await _reconcile(settings);
    } catch (error, stack) {
      _logPlatformFailure('startup reconciliation', error, stack);
    }
    return settings;
  }

  Future<void> reload() async {
    state = const AsyncLoading();
    ref.invalidate(progressSummaryProvider);
    state = await AsyncValue.guard(build);
  }

  Future<bool> _initializeScheduler() async {
    try {
      await _scheduler.initialize();
      return true;
    } catch (error, stack) {
      _logPlatformFailure('initialization', error, stack);
      return false;
    }
  }

  Future<NotificationPermissionStatus> _resolvePermissionStatus({
    required bool requested,
  }) async {
    try {
      final info =
          await _scheduler.getPermissionInfo(permissionRequested: requested);
      if (!info.supported) return NotificationPermissionStatus.granted;
      if (info.granted) return NotificationPermissionStatus.granted;
      if (!requested) return NotificationPermissionStatus.notRequested;
      if (info.permanentlyDenied) {
        return NotificationPermissionStatus.permanentlyDenied;
      }
      return NotificationPermissionStatus.denied;
    } catch (error, stack) {
      _logPlatformFailure('permission status check', error, stack);
      return NotificationPermissionStatus.unavailable;
    }
  }

  Future<bool?> _readPendingQaza() async {
    try {
      final summary = await ref.read(progressSummaryProvider.future);
      return summary.overall.pending > 0;
    } catch (error, stack) {
      _logPlatformFailure('pending Qaza check', error, stack);
      return null;
    }
  }

  Future<void> refreshPermissionStatus() async {
    final current = state.valueOrNull;
    if (current == null) return;

    try {
      final requested = await _readPermissionRequestState();
      final permissionStatus =
          await _resolvePermissionStatus(requested: requested);
      final next = current.copyWith(permissionStatus: permissionStatus);
      state = AsyncData(next);

      try {
        await _reconcile(next);
      } catch (error, stack) {
        _logPlatformFailure('foreground reconciliation', error, stack);
      }
    } catch (error, stack) {
      _logPlatformFailure('foreground permission refresh', error, stack);
      state = AsyncData(
        current.copyWith(
          permissionStatus: NotificationPermissionStatus.unavailable,
        ),
      );
    }
  }

  Future<bool> setEnabled(bool enabled) async {
    final current = state.valueOrNull;
    if (current == null) return false;

    if (!enabled) {
      await _cancelQuietly();
      final next = current.copyWith(enabled: false);
      await _persist(next, permissionRequested: null);
      state = AsyncData(next);
      return true;
    }

    if (current.enabled && current.canSendNotifications) {
      try {
        await _reconcile(current);
        return true;
      } catch (error, stack) {
        _logPlatformFailure('existing reminder reconciliation', error, stack);
        state = AsyncData(
          current.copyWith(
            permissionStatus: NotificationPermissionStatus.unavailable,
          ),
        );
        return false;
      }
    }

    if (current.permissionStatus ==
        NotificationPermissionStatus.permanentlyDenied) {
      return false;
    }

    late final bool granted;
    try {
      granted = await _requestPermissionForAction();
    } catch (error, stack) {
      _logPlatformFailure('permission request', error, stack);
      state = AsyncData(
        current.copyWith(
          permissionStatus: NotificationPermissionStatus.unavailable,
        ),
      );
      return false;
    }

    if (!granted) {
      final requested = await _readPermissionRequestState();
      final status = await _resolvePermissionStatus(requested: requested);
      final next = current.copyWith(
        enabled: false,
        permissionStatus: status,
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

    try {
      await _reconcile(next);
      return true;
    } catch (error, stack) {
      _logPlatformFailure('enable reconciliation', error, stack);
      state = AsyncData(
        next.copyWith(
          enabled: false,
          permissionStatus: NotificationPermissionStatus.unavailable,
        ),
      );
      return false;
    }
  }

  Future<bool> _requestPermissionForAction() async {
    await _scheduler.initialize();
    try {
      final granted = await _scheduler.requestPermission();
      await _persistPermissionRequested(true);
      return granted;
    } catch (error, stack) {
      _logPlatformFailure('permission request', error, stack);
      rethrow;
    }
  }

  Future<void> _persistPermissionRequested(bool requested) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_scopedKey(_permissionRequestedKey), requested);
  }

  Future<bool> _readPermissionRequestState() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_scopedKey(_permissionRequestedKey)) ?? false;
  }

  Future<bool> openSystemSettings() async {
    try {
      return await _scheduler.openSystemNotificationSettings();
    } catch (error, stack) {
      _logPlatformFailure('open system settings', error, stack);
      return false;
    }
  }

  Future<void> _cancelQuietly() async {
    try {
      await _scheduler.cancelDaily();
    } catch (error, stack) {
      _logPlatformFailure('cancel daily reminder', error, stack);
    }
  }

  Future<void> setTime(int hour, int minute) async {
    final current = state.valueOrNull;
    if (current == null) return;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      throw ArgumentError('Invalid reminder time.');
    }

    final next = current.copyWith(hour: hour, minute: minute);
    await _persist(next, permissionRequested: null);
    state = AsyncData(next);

    try {
      await _reconcile(next);
    } catch (error, stack) {
      _logPlatformFailure('time-change reconciliation', error, stack);
      state = AsyncData(
        next.copyWith(
          permissionStatus: NotificationPermissionStatus.unavailable,
        ),
      );
    }
  }

  Future<void> sendTestNotification() async {
    final current = state.valueOrNull;
    if (current == null) {
      throw StateError('Notification settings are not loaded.');
    }

    var permissionStatus = current.permissionStatus;
    if (permissionStatus != NotificationPermissionStatus.granted) {
      if (permissionStatus ==
          NotificationPermissionStatus.permanentlyDenied) {
        throw StateError(
          'Notification permission is permanently denied. '
          'Open system notification settings and enable notifications.',
        );
      }

      try {
        final granted = await _requestPermissionForAction();
        if (!granted) {
          final requested = await _readPermissionRequestState();
          permissionStatus =
              await _resolvePermissionStatus(requested: requested);
          state =
              AsyncData(current.copyWith(permissionStatus: permissionStatus));
          throw StateError(
            permissionStatus ==
                    NotificationPermissionStatus.permanentlyDenied
                ? 'Notification permission is permanently denied. '
                    'Open system notification settings and enable notifications.'
                : 'Notification permission was not granted.',
          );
        }
      } catch (error, stack) {
        _logPlatformFailure('test permission request', error, stack);
        if (error is StateError) rethrow;
        state = AsyncData(
          current.copyWith(
            permissionStatus: NotificationPermissionStatus.unavailable,
          ),
        );
        rethrow;
      }

      state = AsyncData(
        current.copyWith(
          permissionStatus: NotificationPermissionStatus.granted,
        ),
      );
    }

    try {
      await _scheduler.showTestNotification(_content(test: true));
    } catch (error, stack) {
      _logPlatformFailure('test notification', error, stack);
      rethrow;
    }
  }

  void _listenToQazaChanges(AsyncValue<QazaProgressSummary> next) {
    final summary = next.valueOrNull;
    final current = state.valueOrNull;
    if (summary == null || current == null) return;

    final updated = current.copyWith(
      hasPendingQaza: summary.overall.pending > 0,
      pendingCountKnown: true,
    );
    state = AsyncData(updated);
    unawaited(_reconcileSafely(updated));
  }

  Future<void> _reconcileSafely(NotificationSettingsState value) async {
    try {
      await _reconcile(value);
    } catch (error, stack) {
      _logPlatformFailure('background reconciliation', error, stack);
    }
  }

  Future<void> _reconcile(NotificationSettingsState value) async {
    switch (value.scheduleStatus) {
      case NotificationScheduleStatus.disabled:
      case NotificationScheduleStatus.permissionRequired:
      case NotificationScheduleStatus.noPendingQaza:
        await _scheduler.cancelDaily();
        return;
      case NotificationScheduleStatus.scheduled:
        await _scheduler.scheduleDaily(
          hour: value.hour,
          minute: value.minute,
          content: _content(),
        );
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
      await prefs.setBool(
        _scopedKey(_permissionRequestedKey),
        permissionRequested,
      );
    }
  }

  void _logPlatformFailure(String operation, Object error, StackTrace stack) {
    if (kDebugMode) {
      debugPrint(
        '[notifications] $operation failed: ' +
            error.runtimeType.toString() +
            ': ' +
            error.toString(),
      );
      debugPrintStack(stackTrace: stack);
    }
  }
}

final notificationSchedulerProvider = Provider<NotificationScheduler>(
  (ref) => LocalNotificationService(),
);

final notificationSettingsProvider = AsyncNotifierProvider<
    NotificationSettingsNotifier, NotificationSettingsState>(
  NotificationSettingsNotifier.new,
);
