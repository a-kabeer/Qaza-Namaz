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
import 'package:qaza_namaz/features/settings/notifications_screen.dart';

import 'support/test_app.dart';

class _FlakyScheduler implements NotificationScheduler {
  bool failInitialize = false;
  bool failPermissionCheck = false;
  bool failRequest = false;
  bool failCancel = false;

  int initializeCalls = 0;
  int scheduleCalls = 0;
  int cancelCalls = 0;
  int requestCalls = 0;
  int settingsCalls = 0;

  bool permissionGranted = true;
  bool permissionGrantedForStatus = true;
  bool canRequestPermission = true;
  bool permanentlyDeniedForStatus = false;
  bool settingsOpen = true;

  @override
  Future<void> initialize() async {
    initializeCalls++;
    if (failInitialize) throw StateError('timezone database unavailable');
  }

  @override
  Future<NotificationPermissionInfo> getPermissionInfo({
    required bool permissionRequested,
  }) async {
    if (failPermissionCheck) throw StateError('permission check failed');
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
  Future<bool> requestPermission() async {
    requestCalls++;
    if (failRequest) throw StateError('permission request failed');
    if (permissionGranted) permissionGrantedForStatus = true;
    return permissionGranted;
  }

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
  }

  @override
  Future<void> cancelDaily() async {
    cancelCalls++;
    if (failCancel) throw StateError('cancel failed');
  }

  @override
  Future<void> showTestNotification(NotificationContent content) async {}
}

QazaRecord _pending() {
  final now = DateTime(2026, 9, 18);
  return QazaRecord(
    id: 'pending-fajr',
    userId: 'u1',
    prayerType: PrayerType.fajr,
    originalDate: DateTime(2026, 1, 1),
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  late bool summaryFails;
  late List<QazaRecord> records;

  Future<void> pumpPage(
    WidgetTester tester,
    _FlakyScheduler scheduler, {
    bool ledgerFails = false,
    List<QazaRecord> ledger = const <QazaRecord>[],
  }) async {
    summaryFails = ledgerFails;
    records = ledger;
    tester.view.physicalSize = const Size(900, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationSchedulerProvider.overrideWithValue(scheduler),
          activeUserIdProvider.overrideWithValue('u1'),
          progressSummaryProvider.overrideWith((ref) async {
            if (summaryFails) throw StateError('ledger unavailable');
            return QazaProgressSummary.fromRecords(records);
          }),
        ],
        child: const TestApp(home: NotificationsScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder switchTile() => find.byKey(const Key('daily_notification_switch'));
  Finder errorState() => find.byKey(const Key('notifications_error_state'));
  Finder statusTile() => find.byKey(const Key('notification_schedule_status'));

  String statusText(WidgetTester tester) =>
      (tester.widget<ListTile>(statusTile()).subtitle! as Text).data!;

  testWidgets('not-requested state keeps Allow and enables test action',
      (tester) async {
    final scheduler = _FlakyScheduler()
      ..permissionGrantedForStatus = false
      ..permissionGranted = true;
    await pumpPage(tester, scheduler);

    expect(
      find.byKey(const Key('notification_permission_allow')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('test_notification_action')),
      findsOneWidget,
    );
  });

  testWidgets('denied state offers Retry, not system settings',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'qaza_notification_permission_requested:u1': true,
    });
    final scheduler = _FlakyScheduler()
      ..permissionGrantedForStatus = false
      ..permanentlyDeniedForStatus = false;
    await pumpPage(tester, scheduler);

    expect(
      find.byKey(const Key('notification_permission_retry')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('notification_open_settings')),
      findsNothing,
    );
  });

  testWidgets('permanently denied state offers system settings',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'qaza_notification_permission_requested:u1': true,
    });
    final scheduler = _FlakyScheduler()
      ..permissionGrantedForStatus = false
      ..permanentlyDeniedForStatus = true;
    await pumpPage(tester, scheduler);

    expect(
      find.byKey(const Key('notification_open_settings')),
      findsOneWidget,
    );
    expect(
      tester.widget<ListTile>(
        find.byKey(const Key('test_notification_action')),
      ).enabled,
      isFalse,
    );
  });

  group('normal load', () {
    testWidgets('shows the settings, not an error', (tester) async {
      await pumpPage(tester, _FlakyScheduler(), ledger: [_pending()]);

      expect(errorState(), findsNothing);
      expect(switchTile(), findsOneWidget);
      expect(
        find.byKey(const Key('reminder_time_tile')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('notification_permission_status')),
        findsOneWidget,
      );
    });

    testWidgets('an empty ledger reports nothing pending', (tester) async {
      SharedPreferences.setMockInitialValues({
        'qaza_daily_notification_enabled:u1': true,
        'qaza_notification_permission_requested:u1': true,
      });
      await pumpPage(tester, _FlakyScheduler());

      expect(
        statusText(tester),
        'No pending Qaza. No reminder is scheduled.',
      );
    });

    testWidgets('a pending ledger reports the scheduled time',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        'qaza_daily_notification_enabled:u1': true,
        'qaza_daily_notification_hour:u1': 6,
        'qaza_daily_notification_minute:u1': 30,
        'qaza_notification_permission_requested:u1': true,
      });
      final scheduler = _FlakyScheduler();
      await pumpPage(tester, scheduler, ledger: [_pending()]);

      expect(statusText(tester), contains('6:30 AM'));
      expect(scheduler.scheduleCalls, 1);
    });
  });

  group('the scheduler is unusable', () {
    testWidgets('the page still loads and reports it', (tester) async {
      final scheduler = _FlakyScheduler()..failInitialize = true;
      await pumpPage(tester, scheduler, ledger: [_pending()]);

      expect(errorState(), findsNothing);
      expect(find.text('Notifications unavailable'), findsOneWidget);
    });

    testWidgets('nothing is scheduled while it is down', (tester) async {
      SharedPreferences.setMockInitialValues({
        'qaza_daily_notification_enabled:u1': true,
        'qaza_notification_permission_requested:u1': true,
      });
      final scheduler = _FlakyScheduler()..failInitialize = true;
      await pumpPage(tester, scheduler, ledger: [_pending()]);

      expect(scheduler.scheduleCalls, 0);
      expect(
        statusText(tester),
        'Notifications are not available on this device.',
      );
    });

    testWidgets('a failing permission check is recoverable',
        (tester) async {
      final scheduler = _FlakyScheduler()..failPermissionCheck = true;
      await pumpPage(tester, scheduler);

      expect(errorState(), findsNothing);
      expect(find.text('Notifications unavailable'), findsOneWidget);
      expect(
        statusText(tester),
        'Notifications are not available on this device.',
      );
    });
  });

  group('enabling the daily reminder', () {
    testWidgets('granted permission enables and schedules it', (tester) async {
      final scheduler = _FlakyScheduler()..permissionGranted = true;
      await pumpPage(tester, scheduler, ledger: [_pending()]);

      await tester.tap(switchTile());
      await tester.pumpAndSettle();

      expect(
        tester.widget<SwitchListTile>(switchTile()).value,
        isTrue,
      );
      expect(scheduler.scheduleCalls, 1);
      expect(errorState(), findsNothing);
      expect(statusText(tester), contains('8:00 PM'));
    });

    testWidgets('a refused permission keeps the reader on the page',
        (tester) async {
      final scheduler = _FlakyScheduler()
        ..permissionGranted = false
        ..permissionGrantedForStatus = false;
      await pumpPage(tester, scheduler, ledger: [_pending()]);

      await tester.tap(switchTile());
      await tester.pumpAndSettle();

      expect(errorState(), findsNothing);
      expect(switchTile(), findsOneWidget);
      expect(
        tester.widget<SwitchListTile>(switchTile()).value,
        isFalse,
      );
      expect(find.text('Notifications blocked'), findsOneWidget);
      expect(scheduler.scheduleCalls, 0);
    });

    testWidgets('a request that throws is a recoverable failure',
        (tester) async {
      final scheduler = _FlakyScheduler()
        ..permissionGrantedForStatus = false
        ..failRequest = true;
      await pumpPage(tester, scheduler, ledger: [_pending()]);

      await tester.tap(switchTile());
      await tester.pumpAndSettle();

      expect(errorState(), findsNothing);
      expect(find.text('Notifications unavailable'), findsOneWidget);
    });
  });

  group('recovering from system settings', () {
    testWidgets('a permanently denied permission opens system settings',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        'qaza_notification_permission_requested:u1': true,
      });
      final scheduler = _FlakyScheduler()
        ..permissionGrantedForStatus = false
        ..permanentlyDeniedForStatus = true;
      await pumpPage(tester, scheduler, ledger: [_pending()]);

      await tester.tap(find.byKey(const Key('notification_open_settings')));
      await tester.pumpAndSettle();

      expect(scheduler.settingsCalls, 1);
    });

    testWidgets('a permission granted in settings is detected on return',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        'qaza_notification_permission_requested:u1': true,
        'qaza_daily_notification_enabled:u1': true,
      });
      final scheduler = _FlakyScheduler()
        ..permissionGrantedForStatus = false
        ..permanentlyDeniedForStatus = true;
      await pumpPage(tester, scheduler, ledger: [_pending()]);

      scheduler.permissionGrantedForStatus = true;
      scheduler.permanentlyDeniedForStatus = false;
      tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      );
      await tester.pumpAndSettle();

      expect(find.text('Notifications blocked'), findsNothing);
      expect(find.text('Notifications allowed'), findsOneWidget);
      expect(scheduler.scheduleCalls, greaterThanOrEqualTo(1));
    });
  });

  testWidgets('successful disable cancels the daily reminder',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'qaza_daily_notification_enabled:u1': true,
      'qaza_notification_permission_requested:u1': true,
    });
    final scheduler = _FlakyScheduler();
    await pumpPage(tester, scheduler, ledger: [_pending()]);

    await tester.tap(switchTile());
    await tester.pumpAndSettle();

    expect(
      tester.widget<SwitchListTile>(switchTile()).value,
      isFalse,
    );
    expect(scheduler.cancelCalls, greaterThanOrEqualTo(1));
  });

  testWidgets('failed disable keeps reminder enabled and reports unavailable',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'qaza_daily_notification_enabled:u1': true,
      'qaza_notification_permission_requested:u1': true,
    });
    final scheduler = _FlakyScheduler()..failCancel = true;
    await pumpPage(tester, scheduler, ledger: [_pending()]);

    await tester.tap(switchTile());
    await tester.pumpAndSettle();

    expect(
      tester.widget<SwitchListTile>(switchTile()).value,
      isTrue,
    );
    expect(scheduler.cancelCalls, greaterThanOrEqualTo(1));
    expect(
      find.text('Notifications are not available on this device.'),
      findsOneWidget,
    );
  });

  testWidgets('Send Test Notification requests permission before showing',
      (tester) async {
    final scheduler = _FlakyScheduler()
      ..permissionGrantedForStatus = false
      ..permissionGranted = true;
    await pumpPage(tester, scheduler);

    await tester.tap(find.byKey(const Key('test_notification_action')));
    await tester.pumpAndSettle();

    expect(scheduler.requestCalls, 1);
  });
}
