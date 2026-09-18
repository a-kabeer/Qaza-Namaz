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

/// A scheduler whose platform layer can be made to fail, the way a device with
/// an unusable timezone database or notification channel does.
class _FlakyScheduler implements NotificationScheduler {
  bool failInitialize = false;
  bool failPermissionCheck = false;
  int initializeCalls = 0;
  int scheduleCalls = 0;
  int cancelCalls = 0;

  /// What a request returns.
  bool permissionGranted = true;

  /// What a status check reports, which can differ from the request result:
  /// that is exactly the blocked-then-allowed case.
  bool permissionGrantedForStatus = true;

  @override
  Future<void> initialize() async {
    initializeCalls++;
    if (failInitialize) throw StateError('timezone database unavailable');
  }

  @override
  Future<bool> isPermissionGranted() async {
    if (failPermissionCheck) throw StateError('permission check failed');
    return permissionGrantedForStatus;
  }

  @override
  Future<bool> requestPermission() async {
    requestCalls++;
    if (failRequest) throw StateError('permission request failed');
    return permissionGranted;
  }

  int requestCalls = 0;
  bool failRequest = false;
  int settingsCalls = 0;
  bool settingsOpen = true;

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
  Future<void> cancelDaily() async => cancelCalls++;

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

  /// Controls what the Qaza aggregate does, so a failing ledger can be fixed
  /// between a failed load and a retry.
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
    await tester.pumpWidget(ProviderScope(
      overrides: [
        notificationSchedulerProvider.overrideWithValue(scheduler),
        activeUserIdProvider.overrideWithValue('u1'),
        progressSummaryProvider.overrideWith((ref) async {
          if (summaryFails) throw StateError('ledger unavailable');
          return QazaProgressSummary.fromRecords(records);
        }),
      ],
      child: const TestApp(home: NotificationsScreen()),
    ));
    await tester.pumpAndSettle();
  }

  Finder switchTile() => find.byKey(const Key('daily_notification_switch'));
  Finder errorState() => find.byKey(const Key('notifications_error_state'));
  Finder statusTile() => find.byKey(const Key('notification_schedule_status'));

  String statusText(WidgetTester tester) =>
      ((tester.widget<ListTile>(statusTile()).subtitle!) as Text).data!;

  group('normal load', () {
    testWidgets('shows the settings, not an error', (tester) async {
      await pumpPage(tester, _FlakyScheduler(), ledger: [_pending()]);

      expect(errorState(), findsNothing);
      expect(switchTile(), findsOneWidget);
      expect(find.byKey(const Key('reminder_time_tile')), findsOneWidget);
      expect(find.byKey(const Key('notification_permission_status')),
          findsOneWidget);
    });

    testWidgets('an empty ledger reports nothing pending', (tester) async {
      SharedPreferences.setMockInitialValues({
        'qaza_daily_notification_enabled:u1': true,
        'qaza_notification_permission_requested:u1': true,
      });
      await pumpPage(tester, _FlakyScheduler());

      expect(statusText(tester), 'No pending Qaza. No reminder is scheduled.');
    });

    testWidgets('a pending ledger reports the scheduled time', (tester) async {
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

      // Regression: this used to throw out of build() and leave the page dead.
      expect(errorState(), findsNothing);
      expect(switchTile(), findsOneWidget);
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
      expect(statusText(tester), 'Notification permission is required.');
    });

    testWidgets('a failing permission check is treated the same way',
        (tester) async {
      final scheduler = _FlakyScheduler()..failPermissionCheck = true;
      await pumpPage(tester, scheduler);

      expect(errorState(), findsNothing);
      expect(find.text('Notifications unavailable'), findsOneWidget);
    });
  });

  group('the ledger is unreadable', () {
    testWidgets('the page still loads', (tester) async {
      await pumpPage(tester, _FlakyScheduler(), ledgerFails: true);

      // Regression: a failed aggregate used to take the whole page down.
      expect(errorState(), findsNothing);
      expect(switchTile(), findsOneWidget);
    });

    testWidgets('it does not claim the ledger is empty', (tester) async {
      SharedPreferences.setMockInitialValues({
        'qaza_daily_notification_enabled:u1': true,
        'qaza_notification_permission_requested:u1': true,
      });
      await pumpPage(tester, _FlakyScheduler(), ledgerFails: true);

      expect(statusText(tester),
          'Pending Qaza could not be checked. Pull to retry.');
      expect(find.text('No pending Qaza. No reminder is scheduled.'),
          findsNothing);
    });

    testWidgets('nothing is scheduled on a guess', (tester) async {
      SharedPreferences.setMockInitialValues({
        'qaza_daily_notification_enabled:u1': true,
        'qaza_notification_permission_requested:u1': true,
      });
      final scheduler = _FlakyScheduler();
      await pumpPage(tester, scheduler, ledgerFails: true);

      expect(scheduler.scheduleCalls, 0);
    });
  });

  group('enabling the daily reminder', () {
    testWidgets('granted permission enables and schedules it', (tester) async {
      final scheduler = _FlakyScheduler()..permissionGranted = true;
      await pumpPage(tester, scheduler, ledger: [_pending()]);

      await tester.tap(switchTile());
      await tester.pumpAndSettle();

      expect(tester.widget<SwitchListTile>(switchTile()).value, isTrue);
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

      // Regression: this used to leave the whole page in an error state.
      expect(errorState(), findsNothing);
      expect(switchTile(), findsOneWidget);
      expect(tester.widget<SwitchListTile>(switchTile()).value, isFalse);
      expect(find.text('Notifications blocked'), findsOneWidget);
      expect(scheduler.scheduleCalls, 0);
    });

    testWidgets('a request that throws is a refusal, not a page error',
        (tester) async {
      final scheduler = _FlakyScheduler()
        ..permissionGrantedForStatus = false
        ..failRequest = true;
      await pumpPage(tester, scheduler, ledger: [_pending()]);

      await tester.tap(switchTile());
      await tester.pumpAndSettle();

      expect(errorState(), findsNothing);
      expect(find.text('Notifications blocked'), findsOneWidget);
    });
  });

  group('recovering from a blocked permission', () {
    Future<_FlakyScheduler> pumpBlocked(WidgetTester tester) async {
      final scheduler = _FlakyScheduler()
        ..permissionGranted = false
        ..permissionGrantedForStatus = false;
      await pumpPage(tester, scheduler, ledger: [_pending()]);
      await tester.tap(switchTile());
      await tester.pumpAndSettle();
      return scheduler;
    }

    testWidgets('the blocked card offers system settings, not another try',
        (tester) async {
      await pumpBlocked(tester);

      // Asking again would be refused without a prompt, so it is not offered.
      expect(
          find.byKey(const Key('notification_open_settings')), findsOneWidget);
      expect(
          find.byKey(const Key('notification_permission_allow')), findsNothing);
      expect(find.text('Open notification settings'), findsOneWidget);
    });

    testWidgets('it opens the system screen', (tester) async {
      final scheduler = await pumpBlocked(tester);

      await tester.tap(find.byKey(const Key('notification_open_settings')));
      await tester.pumpAndSettle();

      expect(scheduler.settingsCalls, 1);
    });

    testWidgets('a permission granted there takes effect on return',
        (tester) async {
      final scheduler = await pumpBlocked(tester);
      expect(find.text('Notifications blocked'), findsOneWidget);

      // The reader allows notifications in system settings and comes back.
      scheduler.permissionGrantedForStatus = true;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(find.text('Notifications blocked'), findsNothing);
      expect(find.text('Notifications allowed'), findsOneWidget);
      expect(errorState(), findsNothing);
    });

    testWidgets('enabling then works and schedules the reminder',
        (tester) async {
      final scheduler = await pumpBlocked(tester);
      scheduler.permissionGrantedForStatus = true;
      scheduler.permissionGranted = true;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      await tester.tap(switchTile());
      await tester.pumpAndSettle();

      expect(tester.widget<SwitchListTile>(switchTile()).value, isTrue);
      expect(scheduler.scheduleCalls, greaterThanOrEqualTo(1));
      expect(errorState(), findsNothing);
    });
  });

  group('error and retry', () {
    testWidgets('unreadable settings are a real error with a Retry',
        (tester) async {
      final scheduler = _FlakyScheduler();
      await tester.pumpWidget(ProviderScope(
        overrides: [
          notificationSchedulerProvider.overrideWithValue(scheduler),
          activeUserIdProvider.overrideWithValue('u1'),
          progressSummaryProvider
              .overrideWith((ref) async => QazaProgressSummary.empty()),
          notificationSettingsProvider.overrideWith(
              () => _FailingNotifier(StateError('preferences unreadable'))),
        ],
        child: const TestApp(home: NotificationsScreen()),
      ));
      await tester.pumpAndSettle();

      expect(errorState(), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('Retry reloads and recovers once the cause is fixed',
        (tester) async {
      final scheduler = _FlakyScheduler();
      await tester.pumpWidget(ProviderScope(
        overrides: [
          notificationSchedulerProvider.overrideWithValue(scheduler),
          activeUserIdProvider.overrideWithValue('u1'),
          progressSummaryProvider
              .overrideWith((ref) async => QazaProgressSummary.empty()),
          notificationSettingsProvider
              .overrideWith(() => _FailingNotifier(StateError('transient'))),
        ],
        child: const TestApp(home: NotificationsScreen()),
      ));
      await tester.pumpAndSettle();
      expect(errorState(), findsOneWidget);

      _FailingNotifier.failNext = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(errorState(), findsNothing);
      expect(switchTile(), findsOneWidget);
    });

    testWidgets('Retry re-runs the whole load, not just the notifier',
        (tester) async {
      final scheduler = _FlakyScheduler()..failInitialize = true;
      await pumpPage(tester, scheduler, ledgerFails: true);
      final initialCalls = scheduler.initializeCalls;

      // The original defect: the aggregate's cached failure survived a retry,
      // so the page could never come back. Fix both causes, then retry.
      scheduler.failInitialize = false;
      summaryFails = false;
      records = [_pending()];
      await tester
          .element(switchTile())
          .read(notificationSettingsProvider.notifier)
          .reload();
      await tester.pumpAndSettle();

      expect(scheduler.initializeCalls, greaterThan(initialCalls));
      expect(find.text('Notifications unavailable'), findsNothing);
      expect(statusText(tester), isNot(contains('could not be checked')));
    });
  });
}

/// Fails its first build, to exercise the page's real error path.
class _FailingNotifier extends NotificationSettingsNotifier {
  _FailingNotifier(this.error) {
    failNext = true;
  }

  static bool failNext = true;
  final Object error;

  @override
  Future<NotificationSettingsState> build() async {
    if (failNext) throw error;
    return super.build();
  }
}

extension on Element {
  T read<T>(ProviderListenable<T> provider) =>
      ProviderScope.containerOf(this).read(provider);
}
