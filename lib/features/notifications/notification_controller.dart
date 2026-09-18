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
    this.pendingCountKnown = true,
  });

  final bool enabled;
  final int hour;
  final int minute;
  final NotificationPermissionStatus permissionStatus;
  final bool hasPendingQaza;

  /// False when the Qaza aggregate could not be read this load.
  ///
  /// The reminder then behaves as if nothing is pending — scheduling on a
  /// guess would be worse — but the page says so rather than claiming the
  /// ledger is empty.
  final bool pendingCountKnown;

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

  /// Loads the page's data.
  ///
  /// The saved reminder settings are the only hard dependency: they are what
  /// the page exists to show, so failing to read them is a real error. The
  /// platform scheduler and the Qaza aggregate are both allowed to fail
  /// without taking the page down — a device where notifications are
  /// unavailable, or a ledger that cannot be read right now, still has
  /// settings worth displaying and an explanation worth giving.
  @override
  Future<NotificationSettingsState> build() async {
    ref.listen<AsyncValue<QazaProgressSummary>>(
      progressSummaryProvider,
      (_, next) => _listenToQazaChanges(next),
    );

    // Reading the stored preferences is the one step allowed to throw.
    final prefs = await SharedPreferences.getInstance();
    final requested =
        prefs.getBool(_scopedKey(_permissionRequestedKey)) ?? false;

    final schedulerReady = await _initializeScheduler();
    final permissionStatus = schedulerReady
        ? await _resolvePermissionStatus(requested: requested)
        // The platform layer never came up, so no permission state can be
        // trusted. This is the case the `unavailable` status exists for.
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

    await _reconcile(settings);
    return settings;
  }

  /// Reloads everything behind the page, for the Retry action.
  ///
  /// The failed dependency has to be invalidated too: a cached error in the
  /// Qaza aggregate would otherwise be replayed into every rebuild, which is
  /// what made Retry look like it did nothing.
  Future<void> reload() async {
    state = const AsyncLoading();
    ref.invalidate(progressSummaryProvider);
    state = await AsyncValue.guard(build);
  }

  Future<bool> _initializeScheduler() async {
    try {
      await _scheduler.initialize();
      return true;
    } catch (_) {
      // Timezone lookup and channel creation both fail on some devices.
      return false;
    }
  }

  Future<NotificationPermissionStatus> _resolvePermissionStatus({
    required bool requested,
  }) async {
    try {
      if (await _scheduler.isPermissionGranted()) {
        return NotificationPermissionStatus.granted;
      }
    } catch (_) {
      return NotificationPermissionStatus.unavailable;
    }
    return requested
        ? NotificationPermissionStatus.denied
        : NotificationPermissionStatus.notRequested;
  }

  /// Whether anything is pending, or null when the ledger could not be read.
  ///
  /// Aggregate-only: reminders need to know whether anything is pending, not
  /// what the pending records are, so this never reads the ledger itself.
  Future<bool?> _readPendingQaza() async {
    try {
      final summary = await ref.read(progressSummaryProvider.future);
      return summary.overall.pending > 0;
    } catch (_) {
      return null;
    }
  }

  Future<void> refreshPermissionStatus() async {
    final current = state.valueOrNull;
    if (current == null) return;
    try {
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
      pendingCountKnown: true,
    );
    state = AsyncData(updated);
    _reconcile(updated);
  }

  /// Brings the platform schedule in line with [value].
  ///
  /// Reconciliation is a side effect of loading, so it must not be able to
  /// fail the load: on a device where the scheduler is unavailable there is
  /// nothing to reconcile and nothing the reader can do about it here.
  Future<void> _reconcile(NotificationSettingsState value) async {
    try {
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
    } catch (_) {
      // Left as-is; the page already reports the scheduler as unavailable.
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
