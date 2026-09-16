import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qaza_namaz/app/providers.dart';
import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/data/notifications/local_notification_service.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';
import 'package:qaza_namaz/features/notifications/notification_controller.dart';

class _FakeScheduler implements NotificationScheduler {
  int initializeCalls = 0;
  int permissionCalls = 0;
  int permissionStatusCalls = 0;
  int scheduleCalls = 0;
  int cancelCalls = 0;
  int testCalls = 0;
  bool permissionGranted = true;
  bool permissionGrantedForStatus = true;
  int? lastHour;
  int? lastMinute;

  @override
  Future<void> initialize() async => initializeCalls++;

  @override
  Future<bool> requestPermission() async {
    permissionCalls++;
    return permissionGranted;
  }

  @override
  Future<bool> isPermissionGranted() async {
    permissionStatusCalls++;
    return permissionGrantedForStatus;
  }

  @override
  Future<void> scheduleDaily({required int hour, required int minute}) async {
    scheduleCalls++;
    lastHour = hour;
    lastMinute = minute;
  }

  @override
  Future<void> cancelDaily() async => cancelCalls++;

  @override
  Future<void> showTestNotification() async => testCalls++;
}

class _FakeQazaRecordsNotifier extends QazaRecordsNotifier {
  _FakeQazaRecordsNotifier(this.records);
  List<QazaRecord> records;

  @override
  Future<List<QazaRecord>> build() async => records;

  void setRecords(List<QazaRecord> next) {
    records = next;
    state = AsyncData(next);
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
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  ProviderContainer createContainer(
    _FakeScheduler scheduler, {
    List<QazaRecord> records = const <QazaRecord>[],
  }) {
    final container = ProviderContainer(
      overrides: [
        notificationSchedulerProvider.overrideWithValue(scheduler),
        qazaRecordsProvider.overrideWith(
          () => _FakeQazaRecordsNotifier(records),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

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
  });

  test('state derives schedule status from enablement, permission and pending Qaza', () async {
    final scheduler = _FakeScheduler();
    final container = createContainer(scheduler, records: [_pendingRecord()]);
    final notifier = container.read(notificationSettingsProvider.notifier);
    await container.read(notificationSettingsProvider.future);

    var state = container.read(notificationSettingsProvider).requireValue;
    expect(state.scheduleStatus, NotificationScheduleStatus.disabled);

    await notifier.setEnabled(true);
    state = container.read(notificationSettingsProvider).requireValue;
    expect(state.scheduleStatus, NotificationScheduleStatus.scheduled);

    final deniedScheduler = _FakeScheduler()..permissionGrantedForStatus = false;
    final deniedContainer = createContainer(
      deniedScheduler,
      records: [_pendingRecord()],
    );
    final deniedNotifier = deniedContainer.read(notificationSettingsProvider.notifier);
    await deniedContainer.read(notificationSettingsProvider.future);
    await deniedNotifier.setEnabled(true);
    final deniedState = deniedContainer.read(notificationSettingsProvider).requireValue;
    expect(deniedState.scheduleStatus, NotificationScheduleStatus.scheduled);
  });

  test('enabling with pending Qaza requests permission and schedules one daily reminder', () async {
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

  test('enabled reminder does not schedule when there is no pending Qaza', () async {
    final scheduler = _FakeScheduler();
    final container = createContainer(scheduler);
    final notifier = container.read(notificationSettingsProvider.notifier);
    await container.read(notificationSettingsProvider.future);

    expect(await notifier.setEnabled(true), isTrue);
    expect(scheduler.scheduleCalls, 0);
    expect(scheduler.cancelCalls, greaterThanOrEqualTo(1));
  });

  test('pending-Qaza changes schedule and cancel the daily reminder', () async {
    final scheduler = _FakeScheduler();
    final container = createContainer(scheduler);
    final notifier = container.read(notificationSettingsProvider.notifier);
    await container.read(notificationSettingsProvider.future);

    await notifier.setEnabled(true);
    final recordsNotifier =
        container.read(qazaRecordsProvider.notifier) as _FakeQazaRecordsNotifier;

    recordsNotifier.setRecords([_pendingRecord()]);
    await Future<void>.delayed(Duration.zero);
    expect(scheduler.scheduleCalls, 1);
    expect(container.read(notificationSettingsProvider).requireValue.hasPendingQaza, isTrue);
    expect(
      container.read(notificationSettingsProvider).requireValue.scheduleStatus,
      NotificationScheduleStatus.scheduled,
    );

    final cancelCallsBeforeRemoval = scheduler.cancelCalls;
    recordsNotifier.setRecords(const <QazaRecord>[]);
    await Future<void>.delayed(Duration.zero);
    expect(scheduler.cancelCalls, greaterThan(cancelCallsBeforeRemoval));
    expect(container.read(notificationSettingsProvider).requireValue.hasPendingQaza, isFalse);
    expect(
      container.read(notificationSettingsProvider).requireValue.scheduleStatus,
      NotificationScheduleStatus.noPendingQaza,
    );
  });

  test('changing reminder time reschedules with the selected time when pending exists', () async {
    final scheduler = _FakeScheduler();
    final container = createContainer(scheduler, records: [_pendingRecord()]);
    final notifier = container.read(notificationSettingsProvider.notifier);
    await container.read(notificationSettingsProvider.future);

    await notifier.setEnabled(true);
    await notifier.setTime(7, 45);

    expect(scheduler.scheduleCalls, 2);
    expect(scheduler.lastHour, 7);
    expect(scheduler.lastMinute, 45);
    expect((await container.read(notificationSettingsProvider.future)).formattedTime, '7:45 AM');
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

  test('disabling cancels the daily reminder and preserves the selected time', () async {
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

  test('test notification requires permission and delegates to scheduler', () async {
    final scheduler = _FakeScheduler();
    final container = createContainer(scheduler);
    final notifier = container.read(notificationSettingsProvider.notifier);
    await container.read(notificationSettingsProvider.future);

    await notifier.sendTestNotification();
    expect(scheduler.testCalls, 1);
  });

  test('settings survive controller recreation', () async {
    final firstScheduler = _FakeScheduler();
    final first = createContainer(firstScheduler, records: [_pendingRecord()]);
    await first.read(notificationSettingsProvider.future);
    await first.read(notificationSettingsProvider.notifier).setTime(6, 30);
    first.dispose();

    final secondScheduler = _FakeScheduler();
    final second = createContainer(secondScheduler, records: [_pendingRecord()]);
    final restored = await second.read(notificationSettingsProvider.future);
    expect(restored.enabled, isFalse);
    expect(restored.hour, 6);
    expect(restored.minute, 30);
  });
}
