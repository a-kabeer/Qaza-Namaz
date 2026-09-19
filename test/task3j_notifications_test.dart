import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qaza_namaz/app/providers.dart';
import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/data/notifications/local_notification_service.dart';
import 'package:qaza_namaz/domain/entities/qaza_progress.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';
import 'package:qaza_namaz/features/notifications/notification_controller.dart';
import 'package:qaza_namaz/l10n/app_localizations_en.dart';
import 'package:qaza_namaz/l10n/app_localizations_ur.dart';

class _FakeScheduler implements NotificationScheduler {
  int initializeCalls = 0;
  int permissionCalls = 0;
  int permissionStatusCalls = 0;
  int scheduleCalls = 0;
  int cancelCalls = 0;
  int testCalls = 0;
  int settingsCalls = 0;
  int activeDailySchedules = 0;

  bool permissionGranted = true;
  bool permissionGrantedForStatus = true;
  bool canRequestPermission = true;
  bool permanentlyDeniedForStatus = false;
  bool settingsOpen = true;

  int? lastHour;
  int? lastMinute;
  NotificationContent? lastContent;
  NotificationContent? lastTestContent;

  @override
  Future<void> initialize() async => initializeCalls++;

  @override
  Future<bool> requestPermission() async {
    permissionCalls++;
    if (permissionGranted) permissionGrantedForStatus = true;
    return permissionGranted;
  }

  @override
  Future<NotificationPermissionInfo> getPermissionInfo({
    required bool permissionRequested,
  }) async {
    permissionStatusCalls++;
    return NotificationPermissionInfo(
      granted: permissionGrantedForStatus,
      canRequest: canRequestPermission,
      permanentlyDenied:
          !permissionGrantedForStatus && permanentlyDeniedForStatus,
      supported: true,
      sdkInt: 35,
      shouldShowRationale:
          !permanentlyDeniedForStatus && !permissionGrantedForStatus,
    );
  }

  @override
  Future<bool> isPermissionGranted() async => permissionGrantedForStatus;

  @override
  Future<bool> openSystemNotificationSettings() async {
    settingsCalls++;
    return settingsOpen;
  }

  @override
  Future<void> scheduleDaily({
    required int hour,
    required int minute,
    required NotificationContent content,
  }) async {
    scheduleCalls++;
    activeDailySchedules = 1;
    lastHour = hour;
    lastMinute = minute;
    lastContent = content;
  }

  @override
  Future<void> cancelDaily() async {
    cancelCalls++;
    activeDailySchedules = 0;
  }

  @override
  Future<void> showTestNotification(NotificationContent content) async {
    testCalls++;
    lastTestContent = content;
  }
}

QazaRecord _pendingRecord() {
  final now = DateTime(2026, 9, 16);
  return QazaRecord(
    id: 'pending-fajr',
    userId: 'test-user',
    prayerType: PrayerType.fajr,
    originalDate: DateTime(2026, 1, 1),
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  ProviderContainer watch(
    _FakeScheduler scheduler, {
    List<QazaRecord> records = const <QazaRecord>[],
    String userId = 'test-user',
  }) {
    final container = ProviderContainer(
      overrides: [
        notificationSchedulerProvider.overrideWithValue(scheduler),
        activeUserIdProvider.overrideWithValue(userId),
        progressSummaryProvider.overrideWith(
          (ref) => QazaProgressSummary.fromRecords(records),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('loads safe defaults and permission status', () async {
    final scheduler = _FakeScheduler();
    final container = watch(scheduler);

    final state = await container.read(notificationSettingsProvider.future);

    expect(state.enabled, isFalse);
    expect(state.hour, 20);
    expect(state.minute, 0);
    expect(state.hasPendingQaza, isFalse);
    expect(state.permissionStatus, NotificationPermissionStatus.granted);
    expect(state.scheduleStatus, NotificationScheduleStatus.disabled);
    expect(scheduler.initializeCalls, 1);
    expect(scheduler.cancelCalls, 1);
  });

  test('distinguishes not-requested from permanently denied', () async {
    final firstScheduler = _FakeScheduler()
      ..permissionGrantedForStatus = false;
    SharedPreferences.setMockInitialValues({
      'qaza_notification_permission_requested:test-user': false,
    });
    final first = watch(firstScheduler);
    var state = await first.read(notificationSettingsProvider.future);
    expect(state.permissionStatus, NotificationPermissionStatus.notRequested);

    SharedPreferences.setMockInitialValues({
      'qaza_notification_permission_requested:test-user': true,
    });
    final secondScheduler = _FakeScheduler()
      ..permissionGrantedForStatus = false
      ..permanentlyDeniedForStatus = true;
    final second = watch(secondScheduler);
    state = await second.read(notificationSettingsProvider.future);
    expect(
      state.permissionStatus,
      NotificationPermissionStatus.permanentlyDenied,
    );
  });

  test('restores enabled reminder and schedules one daily notification',
      () async {
    SharedPreferences.setMockInitialValues({
      'qaza_daily_notification_enabled:restore-user': true,
      'qaza_daily_notification_hour:restore-user': 6,
      'qaza_daily_notification_minute:restore-user': 30,
      'qaza_notification_permission_requested:restore-user': true,
    });
    final scheduler = _FakeScheduler();
    final container = watch(
      scheduler,
      records: [_pendingRecord()],
      userId: 'restore-user',
    );

    final state = await container.read(notificationSettingsProvider.future);
    expect(state.enabled, isTrue);
    expect(state.hour, 6);
    expect(state.minute, 30);
    expect(state.scheduleStatus, NotificationScheduleStatus.scheduled);
    expect(scheduler.permissionStatusCalls, 1);
    expect(scheduler.scheduleCalls, 1);
    expect(scheduler.activeDailySchedules, 1);
  });

  test('startup cancels a restored reminder when there is no pending Qaza',
      () async {
    SharedPreferences.setMockInitialValues({
      'qaza_daily_notification_enabled:restore-user': true,
      'qaza_daily_notification_hour:restore-user': 6,
      'qaza_daily_notification_minute:restore-user': 30,
      'qaza_notification_permission_requested:restore-user': true,
    });
    final scheduler = _FakeScheduler();
    final container = watch(scheduler, userId: 'restore-user');

    final state = await container.read(notificationSettingsProvider.future);
    expect(state.scheduleStatus, NotificationScheduleStatus.noPendingQaza);
    expect(scheduler.scheduleCalls, 0);
    expect(scheduler.cancelCalls, 1);
    expect(scheduler.activeDailySchedules, 0);
  });

  test('permission revoked at runtime cancels without changing preference',
      () async {
    final scheduler = _FakeScheduler();
    final container = watch(
      scheduler,
      records: [_pendingRecord()],
    );
    final notifier = container.read(notificationSettingsProvider.notifier);
    await container.read(notificationSettingsProvider.future);

    await notifier.setEnabled(true);
    expect(scheduler.activeDailySchedules, 1);

    scheduler.permissionGrantedForStatus = false;
    scheduler.permanentlyDeniedForStatus = true;
    await notifier.refreshPermissionStatus();

    final state = container.read(notificationSettingsProvider).requireValue;
    expect(state.enabled, isTrue);
    expect(
      state.permissionStatus,
      NotificationPermissionStatus.permanentlyDenied,
    );
    expect(
      state.scheduleStatus,
      NotificationScheduleStatus.permissionRequired,
    );
    expect(scheduler.activeDailySchedules, 0);
  });

  test('re-enabling replaces rather than duplicates the daily schedule',
      () async {
    final scheduler = _FakeScheduler();
    final container = watch(
      scheduler,
      records: [_pendingRecord()],
    );
    final notifier = container.read(notificationSettingsProvider.notifier);
    await container.read(notificationSettingsProvider.future);

    await notifier.setEnabled(true);
    await notifier.setEnabled(true);

    expect(scheduler.scheduleCalls, 2);
    expect(scheduler.activeDailySchedules, 1);
  });

  test('enabling with pending Qaza requests permission and schedules',
      () async {
    final scheduler = _FakeScheduler()
      ..permissionGrantedForStatus = false
      ..permissionGranted = true;
    final container = watch(
      scheduler,
      records: [_pendingRecord()],
    );
    final notifier = container.read(notificationSettingsProvider.notifier);
    await container.read(notificationSettingsProvider.future);

    expect(await notifier.setEnabled(true), isTrue);
    expect(scheduler.permissionCalls, 1);
    expect(scheduler.scheduleCalls, 1);
    expect(scheduler.lastHour, 20);
    expect(scheduler.lastMinute, 0);
    expect(scheduler.activeDailySchedules, 1);
  });

  test('enabled reminder does not schedule when there is no pending Qaza',
      () async {
    final scheduler = _FakeScheduler();
    final container = watch(scheduler);
    final notifier = container.read(notificationSettingsProvider.notifier);
    await container.read(notificationSettingsProvider.future);

    expect(await notifier.setEnabled(true), isTrue);
    expect(scheduler.scheduleCalls, 0);
    expect(scheduler.activeDailySchedules, 0);
    expect(scheduler.cancelCalls, greaterThanOrEqualTo(2));
  });

  test('changing reminder time reschedules when pending exists', () async {
    final scheduler = _FakeScheduler();
    final container = watch(
      scheduler,
      records: [_pendingRecord()],
    );
    final notifier = container.read(notificationSettingsProvider.notifier);
    await container.read(notificationSettingsProvider.future);

    await notifier.setEnabled(true);
    await notifier.setTime(7, 45);

    expect(scheduler.scheduleCalls, 2);
    expect(scheduler.lastHour, 7);
    expect(scheduler.lastMinute, 45);
    expect(scheduler.activeDailySchedules, 1);
  });

  test('changing time while disabled persists without scheduling', () async {
    final scheduler = _FakeScheduler();
    final container = watch(
      scheduler,
      records: [_pendingRecord()],
    );
    final notifier = container.read(notificationSettingsProvider.notifier);
    await container.read(notificationSettingsProvider.future);

    final scheduleCallsBefore = scheduler.scheduleCalls;
    await notifier.setTime(6, 30);
    final state = container.read(notificationSettingsProvider).requireValue;

    expect(state.enabled, isFalse);
    expect(state.hour, 6);
    expect(state.minute, 30);
    expect(state.formattedTime, '6:30 AM');
    expect(scheduler.scheduleCalls, scheduleCallsBefore);
  });

  test('invalid reminder time is rejected', () async {
    final scheduler = _FakeScheduler();
    final container = watch(scheduler);
    final notifier = container.read(notificationSettingsProvider.notifier);
    await container.read(notificationSettingsProvider.future);

    expect(() => notifier.setTime(24, 0), throwsArgumentError);
    expect(() => notifier.setTime(20, 60), throwsArgumentError);
  });

  test('disabling cancels the daily reminder and preserves the selected time',
      () async {
    final scheduler = _FakeScheduler();
    final container = watch(
      scheduler,
      records: [_pendingRecord()],
    );
    final notifier = container.read(notificationSettingsProvider.notifier);
    await container.read(notificationSettingsProvider.future);

    await notifier.setEnabled(true);
    await notifier.setTime(6, 30);
    final cancelCallsBeforeDisable = scheduler.cancelCalls;

    expect(await notifier.setEnabled(false), isTrue);
    final state = container.read(notificationSettingsProvider).requireValue;
    expect(scheduler.cancelCalls, greaterThan(cancelCallsBeforeDisable));
    expect(state.enabled, isFalse);
    expect(state.hour, 6);
    expect(state.minute, 30);
    expect(state.formattedTime, '6:30 AM');
    expect(state.scheduleStatus, NotificationScheduleStatus.disabled);
    expect(scheduler.activeDailySchedules, 0);
  });

  test('denied permission can be retried', () async {
    final scheduler = _FakeScheduler()
      ..permissionGrantedForStatus = false
      ..permissionGranted = true
      ..permanentlyDeniedForStatus = false;
    SharedPreferences.setMockInitialValues({
      'qaza_notification_permission_requested:test-user': true,
    });
    final container = watch(
      scheduler,
      records: [_pendingRecord()],
    );
    final notifier = container.read(notificationSettingsProvider.notifier);
    final state = await container.read(notificationSettingsProvider.future);
    expect(state.permissionStatus, NotificationPermissionStatus.denied);

    expect(await notifier.setEnabled(true), isTrue);
    expect(scheduler.permissionCalls, 1);
    expect(
      container.read(notificationSettingsProvider).requireValue.permissionStatus,
      NotificationPermissionStatus.granted,
    );
  });

  test('permanently denied permission does not request again', () async {
    final scheduler = _FakeScheduler()
      ..permissionGrantedForStatus = false
      ..permanentlyDeniedForStatus = true;
    SharedPreferences.setMockInitialValues({
      'qaza_notification_permission_requested:test-user': true,
    });
    final container = watch(
      scheduler,
      records: [_pendingRecord()],
    );
    final notifier = container.read(notificationSettingsProvider.notifier);
    await container.read(notificationSettingsProvider.future);

    expect(await notifier.setEnabled(true), isFalse);
    expect(scheduler.permissionCalls, 0);
  });

  test('Send Test Notification requests permission before posting', () async {
    final scheduler = _FakeScheduler()
      ..permissionGrantedForStatus = false
      ..permissionGranted = true;
    final container = watch(scheduler);
    final notifier = container.read(notificationSettingsProvider.notifier);
    await container.read(notificationSettingsProvider.future);

    await notifier.sendTestNotification();

    expect(scheduler.permissionCalls, 1);
    expect(scheduler.testCalls, 1);
    expect(
      container.read(notificationSettingsProvider).requireValue.permissionStatus,
      NotificationPermissionStatus.granted,
    );
  });

  test('Send Test Notification does not post after permanent denial',
      () async {
    final scheduler = _FakeScheduler()
      ..permissionGrantedForStatus = false
      ..permanentlyDeniedForStatus = true;
    SharedPreferences.setMockInitialValues({
      'qaza_notification_permission_requested:test-user': true,
    });
    final container = watch(scheduler);
    final notifier = container.read(notificationSettingsProvider.notifier);
    await container.read(notificationSettingsProvider.future);

    expect(
      () => notifier.sendTestNotification(),
      throwsA(isA<StateError>()),
    );
    expect(scheduler.permissionCalls, 0);
    expect(scheduler.testCalls, 0);
  });

  test('test notification never alters the daily schedule', () async {
    final scheduler = _FakeScheduler();
    final container = watch(
      scheduler,
      records: [_pendingRecord()],
    );
    final notifier = container.read(notificationSettingsProvider.notifier);
    await container.read(notificationSettingsProvider.future);

    await notifier.setEnabled(true);
    final dailyScheduleCallsBeforeTest = scheduler.scheduleCalls;
    await notifier.sendTestNotification();

    expect(scheduler.testCalls, 1);
    expect(scheduler.scheduleCalls, dailyScheduleCallsBeforeTest);
    expect(scheduler.activeDailySchedules, 1);
  });

  test('settings return re-checks permission and reconciles', () async {
    final scheduler = _FakeScheduler()
      ..permissionGrantedForStatus = false
      ..permanentlyDeniedForStatus = true;
    SharedPreferences.setMockInitialValues({
      'qaza_notification_permission_requested:test-user': true,
      'qaza_daily_notification_enabled:test-user': true,
    });
    final container = watch(
      scheduler,
      records: [_pendingRecord()],
    );
    final notifier = container.read(notificationSettingsProvider.notifier);
    await container.read(notificationSettingsProvider.future);

    scheduler.permissionGrantedForStatus = true;
    scheduler.permanentlyDeniedForStatus = false;
    await notifier.refreshPermissionStatus();

    final state = container.read(notificationSettingsProvider).requireValue;
    expect(state.permissionStatus, NotificationPermissionStatus.granted);
    expect(state.scheduleStatus, NotificationScheduleStatus.scheduled);
    expect(scheduler.scheduleCalls, greaterThanOrEqualTo(1));
  });

  test('reminder text follows the selected language', () async {
    final scheduler = _FakeScheduler();
    final container = watch(
      scheduler,
      records: [_pendingRecord()],
    );
    final notifier = container.read(notificationSettingsProvider.notifier);
    await container.read(notificationSettingsProvider.future);
    await notifier.setEnabled(true);

    expect(
      scheduler.lastContent!.title,
      AppLocalizationsEn().notificationReminderTitle,
    );

    container.read(localeProvider.notifier).set(const Locale('ur'));
    await notifier.setTime(7, 15);

    expect(
      scheduler.lastContent!.title,
      AppLocalizationsUr().notificationReminderTitle,
    );
    expect(
      scheduler.lastContent!.channelDescription,
      AppLocalizationsUr().notificationChannelDescription,
    );
  });

  test('the test notification is localized too', () async {
    final scheduler = _FakeScheduler();
    final container = watch(scheduler);

    container.read(localeProvider.notifier).set(const Locale('ur'));
    await container
        .read(notificationSettingsProvider.notifier)
        .sendTestNotification();

    expect(scheduler.testCalls, 1);
    expect(
      scheduler.lastTestContent!.body,
      AppLocalizationsUr().notificationTestBody,
    );
  });
}
