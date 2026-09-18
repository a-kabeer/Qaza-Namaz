import 'package:flutter/widgets.dart';
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
  bool permissionGranted = true;
  bool permissionGrantedForStatus = true;
  bool throwOnInitialize = false;
  bool throwOnPermissionStatus = false;
  int? lastHour;
  int? lastMinute;

  @override
  Future<void> initialize() async {
    initializeCalls++;
    if (throwOnInitialize) {
      throw StateError('notification platform unavailable');
    }
  }

  @override
  Future<bool> requestPermission() async {
    permissionCalls++;
    return permissionGranted;
  }

  @override
  Future<bool> isPermissionGranted() async {
    permissionStatusCalls++;
    if (throwOnPermissionStatus) {
      throw StateError('notification permission check failed');
    }
    return permissionGrantedForStatus;
  }

  NotificationContent? lastContent;
  NotificationContent? lastTestContent;

  @override
  Future<void> scheduleDaily({
    required int hour,
    required int minute,
    required NotificationContent content,
  }) async {
    scheduleCalls++;
    lastHour = hour;
    lastMinute = minute;
    lastContent = content;
  }

  @override
  Future<void> cancelDaily() async => cancelCalls++;

  @override
  Future<void> showTestNotification(NotificationContent content) async {
    testCalls++;
    lastTestContent = content;
  }
}

/// Backs the aggregate summary the notification controller reads. Reminders
/// only need to know whether anything is pending, so the test supplies records
/// and lets the production aggregate derive the counts.
class _FakeLedger {
  _FakeLedger(this.records);
  List<QazaRecord> records;

  QazaProgressSummary get summary => QazaProgressSummary.fromRecords(records);
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
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  late _FakeLedger ledger;

  ProviderContainer createContainer(
    _FakeScheduler scheduler, {
    List<QazaRecord> records = const <QazaRecord>[],
    String userId = 'test-user',
  }) {
    ledger = _FakeLedger(records);
    final container = ProviderContainer(
      overrides: [
        notificationSchedulerProvider.overrideWithValue(scheduler),
        activeUserIdProvider.overrideWithValue(userId),
        progressSummaryProvider.overrideWith((ref) async => ledger.summary),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test(
      'notification platform failure keeps settings in a recoverable data state',
      () async {
    final scheduler = _FakeScheduler()..throwOnInitialize = true;
    final container = createContainer(scheduler);

    final state = await container.read(notificationSettingsProvider.future);

    expect(state.enabled, isFalse);
    expect(state.permissionStatus, NotificationPermissionStatus.unavailable);
    expect(state.scheduleStatus, NotificationScheduleStatus.disabled);
  });

  test(
      'permission refresh converts platform failure into unavailable state',
      () async {
    final scheduler = _FakeScheduler();
    final container = createContainer(scheduler);
    final notifier = container.read(notificationSettingsProvider.notifier);
    await container.read(notificationSettingsProvider.future);

    scheduler.throwOnPermissionStatus = true;
    await notifier.refreshPermissionStatus();

    final state = container.read(notificationSettingsProvider).requireValue;
    expect(state.permissionStatus, NotificationPermissionStatus.unavailable);
  });

  test('loads safe defaults and permission status', () async {
    final scheduler = _FakeScheduler();
    final container = createContainer(scheduler);

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

  test('restores enabled reminder and reconciles the daily schedule on startup',
      () async {
    SharedPreferences.setMockInitialValues({
      'qaza_daily_notification_enabled:restore-user': true,
      'qaza_daily_notification_hour:restore-user': 6,
      'qaza_daily_notification_minute:restore-user': 30,
      'qaza_notification_permission_requested:restore-user': true,
    });
    final scheduler = _FakeScheduler();
    final container = createContainer(
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
    expect(scheduler.lastHour, 6);
    expect(scheduler.lastMinute, 30);
  });

  test(
      'startup reconciliation cancels a restored reminder when there is no pending Qaza',
      () async {
    SharedPreferences.setMockInitialValues({
      'qaza_daily_notification_enabled:restore-user': true,
      'qaza_daily_notification_hour:restore-user': 6,
      'qaza_daily_notification_minute:restore-user': 30,
      'qaza_notification_permission_requested:restore-user': true,
    });
    final scheduler = _FakeScheduler();
    final container = createContainer(scheduler, userId: 'restore-user');

    final state = await container.read(notificationSettingsProvider.future);
    expect(state.enabled, isTrue);
    expect(state.scheduleStatus, NotificationScheduleStatus.noPendingQaza);
    expect(scheduler.scheduleCalls, 0);
    expect(scheduler.cancelCalls, 1);
  });

  test(
      'permission revoked at runtime cancels the daily reminder without changing saved preference',
      () async {
    final scheduler = _FakeScheduler();
    final container = createContainer(scheduler, records: [_pendingRecord()]);
    final notifier = container.read(notificationSettingsProvider.notifier);
    await container.read(notificationSettingsProvider.future);

    await notifier.setEnabled(true);
    expect(scheduler.scheduleCalls, 1);

    scheduler.permissionGrantedForStatus = false;
    await notifier.refreshPermissionStatus();

    final state = container.read(notificationSettingsProvider).requireValue;
    expect(state.enabled, isTrue);
    expect(state.permissionStatus, NotificationPermissionStatus.denied);
    expect(state.scheduleStatus, NotificationScheduleStatus.permissionRequired);
    expect(scheduler.cancelCalls, greaterThanOrEqualTo(1));
  });

  test(
      'state derives schedule status from enablement, permission and pending Qaza',
      () async {
    final scheduler = _FakeScheduler();
    final container = createContainer(scheduler, records: [_pendingRecord()]);
    final notifier = container.read(notificationSettingsProvider.notifier);
    await container.read(notificationSettingsProvider.future);

    var state = container.read(notificationSettingsProvider).requireValue;
    expect(state.scheduleStatus, NotificationScheduleStatus.disabled);

    await notifier.setEnabled(true);
    state = container.read(notificationSettingsProvider).requireValue;
    expect(state.scheduleStatus, NotificationScheduleStatus.scheduled);
  });

  test(
      'enabling with pending Qaza requests permission and schedules one daily reminder',
      () async {
    final scheduler = _FakeScheduler()..permissionGrantedForStatus = false;
    final container = createContainer(scheduler, records: [_pendingRecord()]);
    final notifier = container.read(notificationSettingsProvider.notifier);
    await container.read(notificationSettingsProvider.future);

    expect(await notifier.setEnabled(true), isTrue);
    expect(scheduler.permissionCalls, 1);
    expect(scheduler.scheduleCalls, 1);
    expect(scheduler.lastHour, 20);
    expect(scheduler.lastMinute, 0);
  });

  test('enabled reminder does not schedule when there is no pending Qaza',
      () async {
    final scheduler = _FakeScheduler();
    final container = createContainer(scheduler);
    final notifier = container.read(notificationSettingsProvider.notifier);
    await container.read(notificationSettingsProvider.future);

    expect(await notifier.setEnabled(true), isTrue);
    expect(scheduler.scheduleCalls, 0);
    expect(scheduler.cancelCalls, greaterThanOrEqualTo(2));
  });

  test('pending-Qaza changes schedule and cancel the daily reminder', () async {
    final scheduler = _FakeScheduler();
    final container = createContainer(scheduler);
    final notifier = container.read(notificationSettingsProvider.notifier);
    await container.read(notificationSettingsProvider.future);

    await notifier.setEnabled(true);

    ledger.records = [_pendingRecord()];
    container.invalidate(progressSummaryProvider);
    await Future<void>.delayed(Duration.zero);
    expect(scheduler.scheduleCalls, 1);
    expect(
        container
            .read(notificationSettingsProvider)
            .requireValue
            .hasPendingQaza,
        isTrue);
    expect(
      container.read(notificationSettingsProvider).requireValue.scheduleStatus,
      NotificationScheduleStatus.scheduled,
    );

    final cancelCallsBeforeRemoval = scheduler.cancelCalls;
    ledger.records = const <QazaRecord>[];
    container.invalidate(progressSummaryProvider);
    await Future<void>.delayed(Duration.zero);
    expect(scheduler.cancelCalls, greaterThan(cancelCallsBeforeRemoval));
    expect(
        container
            .read(notificationSettingsProvider)
            .requireValue
            .hasPendingQaza,
        isFalse);
    expect(
      container.read(notificationSettingsProvider).requireValue.scheduleStatus,
      NotificationScheduleStatus.noPendingQaza,
    );
  });

  test(
      'changing reminder time reschedules with the selected time when pending exists',
      () async {
    final scheduler = _FakeScheduler();
    final container = createContainer(scheduler, records: [_pendingRecord()]);
    final notifier = container.read(notificationSettingsProvider.notifier);
    await container.read(notificationSettingsProvider.future);

    await notifier.setEnabled(true);
    await notifier.setTime(7, 45);

    expect(scheduler.scheduleCalls, 2);
    expect(scheduler.lastHour, 7);
    expect(scheduler.lastMinute, 45);
    expect(
      (await container.read(notificationSettingsProvider.future)).formattedTime,
      '7:45 AM',
    );
  });

  test('changing time while disabled persists without scheduling', () async {
    final scheduler = _FakeScheduler();
    final container = createContainer(scheduler, records: [_pendingRecord()]);
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
    final container = createContainer(scheduler);
    final notifier = container.read(notificationSettingsProvider.notifier);
    await container.read(notificationSettingsProvider.future);

    expect(() => notifier.setTime(24, 0), throwsArgumentError);
    expect(() => notifier.setTime(20, 60), throwsArgumentError);
  });

  test('disabling cancels the daily reminder and preserves the selected time',
      () async {
    final scheduler = _FakeScheduler();
    final container = createContainer(scheduler, records: [_pendingRecord()]);
    final notifier = container.read(notificationSettingsProvider.notifier);
    await container.read(notificationSettingsProvider.future);

    await notifier.setEnabled(true);
    await notifier.setTime(6, 30);
    final cancelCallsBeforeDisable = scheduler.cancelCalls;

    expect(await notifier.setEnabled(false), isTrue);
    final state = await container.read(notificationSettingsProvider.future);
    expect(scheduler.cancelCalls, greaterThan(cancelCallsBeforeDisable));
    expect(state.enabled, isFalse);
    expect(state.hour, 6);
    expect(state.minute, 30);
    expect(state.formattedTime, '6:30 AM');
    expect(state.scheduleStatus, NotificationScheduleStatus.disabled);
  });

  test('permission denial never leaves reminder enabled', () async {
    final scheduler = _FakeScheduler()
      ..permissionGranted = false
      ..permissionGrantedForStatus = false;
    final container = createContainer(scheduler, records: [_pendingRecord()]);
    final notifier = container.read(notificationSettingsProvider.notifier);
    await container.read(notificationSettingsProvider.future);

    expect(await notifier.setEnabled(true), isFalse);
    final state = await container.read(notificationSettingsProvider.future);
    expect(state.enabled, isFalse);
    expect(state.permissionStatus, NotificationPermissionStatus.denied);
    expect(state.scheduleStatus, NotificationScheduleStatus.disabled);
    expect(scheduler.scheduleCalls, 0);
  });

  test(
      'test notification requires permission and delegates without changing daily schedule',
      () async {
    final scheduler = _FakeScheduler();
    final container = createContainer(scheduler, records: [_pendingRecord()]);
    final notifier = container.read(notificationSettingsProvider.notifier);
    await container.read(notificationSettingsProvider.future);

    await notifier.setEnabled(true);
    final dailyScheduleCallsBeforeTest = scheduler.scheduleCalls;
    await notifier.sendTestNotification();

    expect(scheduler.testCalls, 1);
    expect(scheduler.scheduleCalls, dailyScheduleCallsBeforeTest);
  });

  test('test notification is rejected when permission is unavailable',
      () async {
    final scheduler = _FakeScheduler()..permissionGrantedForStatus = false;
    final container = createContainer(scheduler);
    final notifier = container.read(notificationSettingsProvider.notifier);
    await container.read(notificationSettingsProvider.future);

    expect(() => notifier.sendTestNotification(), throwsA(isA<StateError>()));
    expect(scheduler.testCalls, 0);
  });

  test('settings restore enabled state and selected time for the same account',
      () async {
    final firstScheduler = _FakeScheduler();
    final first = createContainer(
      firstScheduler,
      records: [_pendingRecord()],
      userId: 'restore-user',
    );
    await first.read(notificationSettingsProvider.future);
    await first.read(notificationSettingsProvider.notifier).setTime(6, 30);
    await first.read(notificationSettingsProvider.notifier).setEnabled(true);
    first.dispose();

    final secondScheduler = _FakeScheduler();
    final second = createContainer(
      secondScheduler,
      records: [_pendingRecord()],
      userId: 'restore-user',
    );
    final restored = await second.read(notificationSettingsProvider.future);
    expect(restored.enabled, isTrue);
    expect(restored.hour, 6);
    expect(restored.minute, 30);
  });

  test('reminder text follows the selected language', () async {
    final scheduler = _FakeScheduler();
    final container = createContainer(scheduler, records: [_pendingRecord()]);
    await container.read(notificationSettingsProvider.future);
    await container
        .read(notificationSettingsProvider.notifier)
        .setEnabled(true);

    final english = scheduler.lastContent;
    expect(english, isNotNull);
    expect(english!.title, AppLocalizationsEn().notificationReminderTitle);

    container.read(localeProvider.notifier).set(const Locale('ur'));
    await container.read(notificationSettingsProvider.notifier).setTime(7, 15);

    final urdu = scheduler.lastContent;
    expect(urdu!.title, AppLocalizationsUr().notificationReminderTitle);
    expect(urdu.title, isNot(english.title));
    expect(urdu.channelDescription,
        AppLocalizationsUr().notificationChannelDescription);
  });

  test('the test notification is localized too', () async {
    final scheduler = _FakeScheduler();
    final container = createContainer(scheduler, records: [_pendingRecord()]);
    await container.read(notificationSettingsProvider.future);

    container.read(localeProvider.notifier).set(const Locale('ur'));
    await container
        .read(notificationSettingsProvider.notifier)
        .sendTestNotification();

    expect(scheduler.testCalls, 1);
    expect(scheduler.lastTestContent!.body,
        AppLocalizationsUr().notificationTestBody);
  });

  test('notification settings are isolated between accounts', () async {
    final firstScheduler = _FakeScheduler();
    final first = createContainer(firstScheduler, userId: 'user-a');
    await first.read(notificationSettingsProvider.future);
    await first.read(notificationSettingsProvider.notifier).setTime(6, 30);
    await first.read(notificationSettingsProvider.notifier).setEnabled(true);
    first.dispose();

    final secondScheduler = _FakeScheduler();
    final second = createContainer(secondScheduler, userId: 'user-b');
    final state = await second.read(notificationSettingsProvider.future);
    expect(state.enabled, isFalse);
    expect(state.hour, 20);
    expect(state.minute, 0);
  });
}
