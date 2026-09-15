import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qaza_namaz/features/notifications/notification_controller.dart';
import 'package:qaza_namaz/data/notifications/local_notification_service.dart';

class _FakeScheduler implements NotificationScheduler {
  int initializeCalls = 0;
  int permissionCalls = 0;
  int scheduleCalls = 0;
  int cancelCalls = 0;
  bool permissionGranted = true;
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
  Future<void> scheduleDaily({required int hour, required int minute}) async {
    scheduleCalls++;
    lastHour = hour;
    lastMinute = minute;
  }

  @override
  Future<void> cancelDaily() async => cancelCalls++;
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  ProviderContainer createContainer(_FakeScheduler scheduler) {
    final container = ProviderContainer(
      overrides: [notificationSchedulerProvider.overrideWithValue(scheduler)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('loads safe defaults and persists notification settings', () async {
    final scheduler = _FakeScheduler();
    final container = createContainer(scheduler);

    final state = await container.read(notificationSettingsProvider.future);
    expect(state.enabled, isFalse);
    expect(state.hour, 20);
    expect(state.minute, 0);
    expect(scheduler.initializeCalls, 1);
  });

  test('enabling requests permission and schedules one daily reminder', () async {
    final scheduler = _FakeScheduler();
    final container = createContainer(scheduler);
    final notifier = container.read(notificationSettingsProvider.notifier);
    await container.read(notificationSettingsProvider.future);

    expect(await notifier.setEnabled(true), isTrue);
    expect(scheduler.permissionCalls, 1);
    expect(scheduler.scheduleCalls, 1);
    expect(scheduler.lastHour, 20);
    expect(scheduler.lastMinute, 0);
    expect((await container.read(notificationSettingsProvider.future)).enabled, isTrue);
  });

  test('re-enabling an already enabled reminder does not duplicate scheduling', () async {
    final scheduler = _FakeScheduler();
    final container = createContainer(scheduler);
    final notifier = container.read(notificationSettingsProvider.notifier);
    await container.read(notificationSettingsProvider.future);

    await notifier.setEnabled(true);
    expect(await notifier.setEnabled(true), isTrue);
    expect(scheduler.permissionCalls, 1);
    expect(scheduler.scheduleCalls, 1);
  });

  test('changing reminder time reschedules with the selected time', () async {
    final scheduler = _FakeScheduler();
    final container = createContainer(scheduler);
    final notifier = container.read(notificationSettingsProvider.notifier);
    await container.read(notificationSettingsProvider.future);

    await notifier.setEnabled(true);
    await notifier.setTime(7, 45);

    expect(scheduler.scheduleCalls, 2);
    expect(scheduler.lastHour, 7);
    expect(scheduler.lastMinute, 45);
    expect((await container.read(notificationSettingsProvider.future)).formattedTime, '07:45 AM');
  });

  test('disabling cancels the daily reminder', () async {
    final scheduler = _FakeScheduler();
    final container = createContainer(scheduler);
    final notifier = container.read(notificationSettingsProvider.notifier);
    await container.read(notificationSettingsProvider.future);

    await notifier.setEnabled(true);
    expect(await notifier.setEnabled(false), isFalse);
    expect(scheduler.cancelCalls, 1);
    expect((await container.read(notificationSettingsProvider.future)).enabled, isFalse);
  });

  test('permission denial never leaves reminder enabled', () async {
    final scheduler = _FakeScheduler()..permissionGranted = false;
    final container = createContainer(scheduler);
    final notifier = container.read(notificationSettingsProvider.notifier);
    await container.read(notificationSettingsProvider.future);

    expect(await notifier.setEnabled(true), isFalse);
    final state = await container.read(notificationSettingsProvider.future);
    expect(state.enabled, isFalse);
    expect(scheduler.permissionCalls, 1);
    expect(scheduler.scheduleCalls, 0);
  });

  test('settings survive controller recreation', () async {
    final scheduler = _FakeScheduler();
    final first = createContainer(scheduler);
    await first.read(notificationSettingsProvider.future);
    await first.read(notificationSettingsProvider.notifier).setTime(6, 30);
    await first.read(notificationSettingsProvider.notifier).setEnabled(true);
    first.dispose();

    final secondScheduler = _FakeScheduler();
    final second = createContainer(secondScheduler);
    final restored = await second.read(notificationSettingsProvider.future);
    expect(restored.enabled, isTrue);
    expect(restored.hour, 6);
    expect(restored.minute, 30);
  });
}
