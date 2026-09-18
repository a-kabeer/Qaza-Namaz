import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/providers.dart';
import '../../data/notifications/local_notification_service.dart';
import '../../l10n/app_localizations.dart';
import '../../domain/entities/qaza_progress.dart';

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

  bool get canSendNotifications =>
      permissionStatus == NotificationPermissionStatus.granted;

  NotificationScheduleStatus get scheduleStatus {
    if (!enabled) return NotificationScheduleStatus.disabled;
    if (!canSendNotifications)
      return NotificationScheduleStatus.permissionRequired;
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

class NotificationSettingsNotifier
    extends AsyncNotifier<NotificationSettingsState> {
  static const _enabledKey = 'qaza_daily_notification_enabled';
  static const _hourKey = 'qaza_daily_notification_hour';
  static const _minuteKey = 'qaza_daily_notification_minute';
  static const _permissionRequestedKey =
      'qaza_notification_permission_requested';

  NotificationScheduler get _scheduler =>
      ref.read(notificationSchedulerProvider);

  /// Notification text for the language the user has chosen.
  ///
  /// The scheduler runs without a widget tree, so the strings are resolved here
  /// from the same generated resources the UI uses.
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
    return '$baseKey:${userId ?? 'anonymous'}';
  }

  @override
  Future<NotificationSettingsState> build() async {
    ref.listen<AsyncValue<QazaProgressSummary>>(
      progressSummaryProvider,
      (_, next) => _listenToQazaChanges(next),
    );

    final prefs = await SharedPreferences.getInstance();

    NotificationPermissionStatus permissionStatus;
    try {
      await _scheduler.initialize();
      final requested =
          prefs.getBool(_scopedKey(_permissionRequestedKey)) ?? false;
      final permissionGranted = await _scheduler.isPermissionGranted();

      permissionStatus = permissionGranted
          ? NotificationPermissionStatus.granted
          : requested
              ? NotificationPermissionStatus.denied
              : NotificationPermissionStatus.notRequested;
    } catch (_) {
      // Platform notification failures must not blank the settings screen.
      // Keep the page usable and expose a recoverable unavailable state.
      permissionStatus = NotificationPermissionStatus.unavailable;
    }

    // Aggregate-only: reminders need to know whether anything is pending, not
    // what the pending records are, so this never reads the ledger.
    // The notification settings page must remain usable even if the optional
    // Qaza summary read fails; the listener will reconcile again when it recovers.
    var hasPendingQaza = false;
    try {
      final summary = await ref.read(progressSummaryProvider.future);
      hasPendingQaza = summary.overall.pending > 0;
    } catch (_) {
      hasPendingQaza = false;
    }

    final settings = NotificationSettingsState(
      enabled: prefs.getBool(_scopedKey(_enabledKey)) ?? false,
      hour: prefs.getInt(_scopedKey(_hourKey)) ?? _defaultReminderHour,
      minute: prefs.getInt(_scopedKey(_minuteKey)) ?? _defaultReminderMinute,
      permissionStatus: permissionStatus,
      hasPendingQaza: hasPendingQaza,
    );

    if (permissionStatus == NotificationPermissionStatus.unavailable) {
      return settings;
    }

    try {
      await _reconcile(settings);
    } catch (_) {
      return settings.copyWith(
        permissionStatus: NotificationPermissionStatus.unavailable,
      );
    }

    return settings;
  }

  Future<void> refreshPermissionStatus() async {
    final current = state.valueOrNull;
    if (current == null) return;
    try {
      await _scheduler.initialize();
      final granted = await _scheduler.isPermissionGranted();
      final prefs = await SharedPreferences.getInstance();
      final requested =
          prefs.getBool(_scopedKey(_permissionRequestedKey)) ?? false;
      final permissionStatus = granted
          ? NotificationPermissionStatus.granted
          : requested
              ? NotificationPermissionStatus.denied
              : NotificationPermissionStatus.notRequested;
      final next = current.copyWith(permissionStatus: permissionStatus);
      state = AsyncData(next);

      try {
        await _reconcile(next);
      } catch (_) {
        state = AsyncData(
          next.copyWith(
            permissionStatus: NotificationPermissionStatus.unavailable,
          ),
        );
      }
    } catch (_) {
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
      try {
        await _scheduler.cancelDaily();
        final next = current.copyWith(enabled: false);
        await _persist(next, permissionRequested: null);
        state = AsyncData(next);
        return true;
      } catch (_) {
        final next = current.copyWith(
          enabled: false,
          permissionStatus: NotificationPermissionStatus.unavailable,
        );
        try {
          await _persist(next, permissionRequested: null);
        } catch (_) {}
        state = AsyncData(next);
        return false;
      }
    }

    if (current.enabled && current.canSendNotifications) {
      try {
        await _reconcile(current);
        return true;
      } catch (_) {
        final next = current.copyWith(
          enabled: false,
          permissionStatus: NotificationPermissionStatus.unavailable,
        );
        try {
          await _persist(next, permissionRequested: null);
        } catch (_) {}
        state = AsyncData(next);
        return false;
      }
    }

    try {
      await _scheduler.initialize();
      final granted =
          current.canSendNotifications || await _scheduler.requestPermission();
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
      try {
        await _reconcile(next);
      } catch (_) {
        final unavailable = next.copyWith(
          enabled: false,
          permissionStatus: NotificationPermissionStatus.unavailable,
        );
        await _persist(unavailable, permissionRequested: true);
        state = AsyncData(unavailable);
        return false;
      }

      return true;
    } catch (_) {
      final unavailable = current.copyWith(
        enabled: false,
        permissionStatus: NotificationPermissionStatus.unavailable,
      );
      try {
        await _persist(unavailable, permissionRequested: true);
      } catch (_) {}
      state = AsyncData(unavailable);
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
      try {
        await _reconcile(next);
      } catch (_) {
        state = AsyncData(
          next.copyWith(
            permissionStatus: NotificationPermissionStatus.unavailable,
          ),
        );
      }
    } catch (_) {
      state = AsyncData(
        current.copyWith(
          permissionStatus: NotificationPermissionStatus.unavailable,
        ),
      );
    }
  }

  Future<void> sendTestNotification() async {
    final current = state.valueOrNull;
    if (current == null)
      throw StateError('Notification settings are not loaded.');
    if (!current.canSendNotifications) {
      throw StateError('Notification permission is required first.');
    }
    await _scheduler.showTestNotification(_content(test: true));
  }

  void _listenToQazaChanges(AsyncValue<QazaProgressSummary> next) {
    final summary = next.valueOrNull;
    final current = state.valueOrNull;
    if (summary == null || current == null) return;

    final updated = current.copyWith(
      hasPendingQaza: summary.overall.pending > 0,
    );
    state = AsyncData(updated);
    unawaited(_reconcileSafely(updated));
  }

  Future<void> _reconcileSafely(NotificationSettingsState value) async {
    try {
      await _reconcile(value);
    } catch (_) {
      final current = state.valueOrNull;
      if (current == null) return;
      state = AsyncData(
        current.copyWith(
          permissionStatus: NotificationPermissionStatus.unavailable,
        ),
      );
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
            hour: value.hour, minute: value.minute, content: _content());
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
          _scopedKey(_permissionRequestedKey), permissionRequested);
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
