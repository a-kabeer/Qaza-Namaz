import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/app/providers.dart';
import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/core/theme/app_theme.dart';
import 'package:qaza_namaz/domain/entities/app_user.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';
import 'package:qaza_namaz/features/calculator/calculator_screen.dart';
import 'package:qaza_namaz/features/home/home_screen.dart';
import 'package:qaza_namaz/features/home/home_plan.dart';
import 'package:qaza_namaz/features/qaza/add_qaza_screen.dart';
import 'package:qaza_namaz/features/settings/qaza_reset_controller.dart';
import 'package:qaza_namaz/features/qaza/qaza_tracker_controller.dart';
import 'package:qaza_namaz/features/shell/workspace_shell.dart';

import 'support/in_memory_qaza_repository.dart';
import 'support/test_app.dart';

final _stamp = DateTime(2026, 9, 18);

QazaRecord _record(PrayerType prayer, int day, QazaStatus status) => QazaRecord(
      id: '${prayer.name}_$day',
      userId: 'u1',
      prayerType: prayer,
      originalDate: DateTime(2026, 1, day),
      status: status,
      completedAt: status == QazaStatus.completed ? _stamp : null,
      createdAt: _stamp,
      updatedAt: _stamp,
    );

void main() {
  /// A ledger with a known shape: Fajr 1 pending + 4 completed (80%), Zuhr
  /// 1 pending, nothing for the other four prayers.
  Future<InMemoryQazaRepository> ledger() async {
    final repository = InMemoryQazaRepository();
    await repository.addRecords([
      _record(PrayerType.fajr, 1, QazaStatus.pending),
      for (var day = 2; day <= 5; day++)
        _record(PrayerType.fajr, day, QazaStatus.completed),
      _record(PrayerType.zuhr, 1, QazaStatus.pending),
    ]);
    return repository;
  }

  Future<ProviderContainer> pumpHome(
    WidgetTester tester,
    InMemoryQazaRepository repository, {
    Locale locale = const Locale('en'),
    ThemeMode themeMode = ThemeMode.light,
    Size size = const Size(900, 2000),
    Widget home = const HomeScreen(),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    final container = ProviderContainer(overrides: [
      qazaRepositoryProvider.overrideWithValue(repository),
      activeUserIdProvider.overrideWithValue('u1'),
      authStateProvider.overrideWith((ref) =>
          Stream.value(const AppUser(id: 'u1', email: 'u1@example.com'))),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: TestApp(
        theme: AppTheme.light(locale: locale),
        darkTheme: AppTheme.dark(locale: locale),
        themeMode: themeMode,
        locale: locale,
        home: home,
      ),
    ));
    await tester.pumpAndSettle();
    return container;
  }

  String textOf(WidgetTester tester, Key key) =>
      tester.widget<Text>(find.byKey(key)).data!;

  group('progress overview', () {
    testWidgets('shows the compact summary and horizontal progress bar',
        (tester) async {
      await pumpHome(tester, await ledger());

      expect(find.byKey(const Key('home_progress_overview')), findsOneWidget);
      expect(find.byKey(const Key('home_progress_summary')), findsOneWidget);
      expect(textOf(tester, const Key('home_progress_summary')),
          '4 of 6 completed · 67%');

      final bar = tester.widget<LinearProgressIndicator>(
        find.byKey(const Key('home_progress_bar')),
      );
      expect(bar.value, closeTo(4 / 6, 0.0001));
      expect(bar.minHeight, 6);
      expect(find.byKey(const Key('home_progress_ring')), findsNothing);
      expect(find.byKey(const Key('home_pending_value')), findsNothing);
      expect(find.text('Total'), findsNothing);

      final next = tester.getRect(find.byKey(const Key('home_next_qaza')));
      final overview =
          tester.getRect(find.byKey(const Key('home_progress_overview')));
      expect(next.bottom, lessThanOrEqualTo(overview.top));
    });

    testWidgets('summary sits above the horizontal bar', (tester) async {
      await pumpHome(tester, await ledger());

      final summary =
          tester.getRect(find.byKey(const Key('home_progress_summary')));
      final bar = tester.getRect(find.byKey(const Key('home_progress_bar')));

      expect(summary.bottom, lessThanOrEqualTo(bar.top));
      expect(bar.width, greaterThan(0));
    });

    testWidgets('a fully completed ledger reads 100%', (tester) async {
      final repository = InMemoryQazaRepository();
      await repository.addRecords([
        _record(PrayerType.fajr, 1, QazaStatus.completed),
        _record(PrayerType.asr, 2, QazaStatus.completed),
      ]);
      await pumpHome(tester, repository);

      expect(
        textOf(tester, const Key('home_progress_summary')),
        '2 of 2 completed · 100%',
      );
      final bar = tester.widget<LinearProgressIndicator>(
        find.byKey(const Key('home_progress_bar')),
      );
      expect(bar.value, 1);
    });
  });

  group('actions', () {
    testWidgets('Home with records keeps completion and shows AddActionsFab',
        (tester) async {
      await pumpHome(tester, await ledger(), home: const WorkspaceShell());

      expect(find.byKey(const Key('home_next_qaza')), findsOneWidget);
      expect(find.byKey(const Key('add_actions_fab')), findsOneWidget);
      expect(find.byKey(const Key('complete_qaza_fab')), findsNothing);
      expect(find.byKey(const Key('home_calculate_qaza')), findsNothing);
      expect(find.byKey(const Key('home_add_qaza')), findsNothing);
    });

    testWidgets('Home with records exposes AddActionsFab',
        (tester) async {
      await pumpHome(tester, await ledger(), home: const WorkspaceShell());

      expect(find.byKey(const Key('add_actions_fab')), findsOneWidget);
    });
  });

  group('empty ledger', () {
    testWidgets('shows the empty state instead of the dashboard',
        (tester) async {
      await pumpHome(tester, InMemoryQazaRepository());

      expect(find.byKey(const Key('home_empty_state')), findsOneWidget);
      expect(find.text('Start Your Qaza Journey'), findsOneWidget);
      expect(
          find.text("You haven't added any Qaza prayers yet."), findsOneWidget);
      expect(find.byKey(const Key('home_empty_calculate')), findsOneWidget);
      expect(find.byKey(const Key('home_empty_add')), findsOneWidget);
      expect(find.text('Calculate Qaza'), findsOneWidget);
      expect(find.text('Add Qaza Manually'), findsOneWidget);

      // The dashboard is not built at all.
      expect(find.byKey(const Key('home_progress_overview')), findsNothing);
      expect(find.byKey(const Key('home_next_qaza')), findsNothing);
      expect(find.byKey(const Key('home_prayer_row_fajr')), findsNothing);
    });

    testWidgets('the dashboard returns as soon as a record exists',
        (tester) async {
      await pumpHome(tester, await ledger());

      expect(find.byKey(const Key('home_empty_state')), findsNothing);
      expect(find.byKey(const Key('home_progress_overview')), findsOneWidget);
    });

    testWidgets('completed-only ledgers are not empty', (tester) async {
      final repository = InMemoryQazaRepository();
      await repository
          .addRecords([_record(PrayerType.fajr, 1, QazaStatus.completed)]);
      await pumpHome(tester, repository);

      expect(find.byKey(const Key('home_empty_state')), findsNothing);
      expect(find.byKey(const Key('home_progress_overview')), findsOneWidget);
    });

    testWidgets('empty Home keeps both actions and has no FAB', (tester) async {
      await pumpHome(tester, InMemoryQazaRepository(),
          home: const WorkspaceShell());

      expect(find.byKey(const Key('home_empty_state')), findsOneWidget);
      expect(find.byKey(const Key('home_empty_calculate')), findsOneWidget);
      expect(find.byKey(const Key('home_empty_add')), findsOneWidget);
      expect(find.byKey(const Key('add_actions_fab')), findsNothing);
      expect(find.byKey(const Key('complete_qaza_fab')), findsNothing);
    });

    testWidgets('Calculate Qaza opens the calculator', (tester) async {
      await pumpHome(tester, InMemoryQazaRepository());

      await tester.tap(find.byKey(const Key('home_empty_calculate')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(CalculatorScreen), findsWidgets);
    });

    testWidgets('Add Qaza Manually opens the Add Qaza screen', (tester) async {
      await pumpHome(tester, InMemoryQazaRepository());

      await tester.tap(find.byKey(const Key('home_empty_add')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(AddQazaScreen), findsOneWidget);
    });

    testWidgets('it appears after a reset, without a restart', (tester) async {
      final repository = await ledger();
      final container = await pumpHome(tester, repository);
      expect(find.byKey(const Key('home_progress_overview')), findsOneWidget);

      // The real reset path, not a hand-rolled one.
      final reset =
          await container.read(qazaResetControllerProvider.notifier).reset();
      expect(reset, isTrue);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('home_empty_state')), findsOneWidget);
      expect(find.text('Start Your Qaza Journey'), findsOneWidget);
    });

    testWidgets('it renders in Urdu and in dark', (tester) async {
      await pumpHome(tester, InMemoryQazaRepository(),
          locale: const Locale('ur'), themeMode: ThemeMode.dark);

      expect(find.byKey(const Key('home_empty_state')), findsOneWidget);
      expect(find.text('Start Your Qaza Journey'), findsNothing);
      expect(find.text('اپنا قضا سفر شروع کریں'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('daily Home experience', () {
    testWidgets('shows the next oldest pending Qaza across all prayers',
        (tester) async {
      final repository = InMemoryQazaRepository();
      await repository.addRecords([
        _record(PrayerType.zuhr, 10, QazaStatus.pending),
        _record(PrayerType.fajr, 2, QazaStatus.pending),
        _record(PrayerType.isha, 1, QazaStatus.pending),
        _record(PrayerType.asr, 3, QazaStatus.completed),
      ]);
      await pumpHome(tester, repository);

      expect(find.byKey(const Key('home_next_qaza')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('home_next_qaza')),
          matching: find.text('Isha'),
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('home_complete_next_qaza')),
          findsOneWidget);
      expect(find.text('01 Jan 2026'), findsOneWidget);
    });

    testWidgets('completion action is visible without scrolling',
        (tester) async {
      final repository = InMemoryQazaRepository();
      await repository.addRecords([
        _record(PrayerType.fajr, 1, QazaStatus.pending),
      ]);
      await pumpHome(
        tester,
        repository,
        home: const WorkspaceShell(),
        size: const Size(360, 800),
      );

      final action =
          tester.getRect(find.byKey(const Key('home_complete_next_qaza')));
      final navigation = tester.getRect(find.byType(NavigationBar));
      expect(action.bottom, lessThanOrEqualTo(navigation.top));
    });

    testWidgets('completing next Qaza advances to the next oldest record',
        (tester) async {
      final repository = InMemoryQazaRepository();
      await repository.addRecords([
        _record(PrayerType.fajr, 2, QazaStatus.pending),
        _record(PrayerType.zuhr, 5, QazaStatus.pending),
      ]);
      await pumpHome(tester, repository);

      expect(find.text('02 Jan 2026'), findsOneWidget);
      await tester.tap(find.byKey(const Key('home_complete_next_qaza')));
      await tester.pumpAndSettle();

      expect(find.text('05 Jan 2026'), findsOneWidget);
      expect(
        textOf(tester, const Key('home_progress_summary')),
        '1 of 2 completed · 50%',
      );
    });

    testWidgets('shows today completion progress using a persisted plan target',
        (tester) async {
      final now = DateTime.now();
      final repository = InMemoryQazaRepository();
      await repository.addRecords([
        _record(PrayerType.fajr, 1, QazaStatus.pending),
        _record(PrayerType.zuhr, 2, QazaStatus.pending),
        _record(PrayerType.asr, 3, QazaStatus.completed).copyWith(
          completedAt: now,
          updatedAt: now,
        ),
        _record(PrayerType.maghrib, 4, QazaStatus.completed).copyWith(
          completedAt: now,
          updatedAt: now,
        ),
      ]);
      final container = await pumpHome(tester, repository);
      await container
          .read(homeQazaPlanProvider.notifier)
          .setDailyTarget(5);
      container
          .read(homeDailyProgressProvider)
          .whenData((_) {});
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('home_today_progress')), findsOneWidget);
      expect(
        textOf(tester, const Key('home_daily_progress_summary')),
        '2 / 5 completed',
      );
      expect(
        textOf(tester, const Key('home_daily_remaining')),
        '3 remaining',
      );
    });

    testWidgets('shows plan target and completion estimate', (tester) async {
      final repository = InMemoryQazaRepository();
      await repository.addRecords([
        _record(PrayerType.fajr, 1, QazaStatus.pending),
        _record(PrayerType.zuhr, 2, QazaStatus.pending),
        _record(PrayerType.asr, 3, QazaStatus.pending),
        _record(PrayerType.maghrib, 4, QazaStatus.pending),
        _record(PrayerType.isha, 5, QazaStatus.pending),
      ]);
      await pumpHome(tester, repository);

      expect(find.byKey(const Key('home_qaza_plan')), findsOneWidget);
      expect(find.byKey(const Key('home_daily_target')), findsOneWidget);
      expect(find.byKey(const Key('home_estimated_completion')),
          findsOneWidget);
    });
  });

  group('prayer rows', () {
    testWidgets('every prayer has a row, in order', (tester) async {
      await pumpHome(tester, await ledger());

      for (final prayer in PrayerType.values) {
        expect(
            find.byKey(Key('home_prayer_row_${prayer.name}')), findsOneWidget);
        expect(
            find.byKey(Key('home_prayer_bar_${prayer.name}')), findsOneWidget);
      }
      // Prayer names now also appear as pills in the Complete Qaza section,
      // so the row's own label is what is asserted here.
      for (final name in const ['Fajr', 'Witr']) {
        expect(
            find.descendant(
                of: find.byKey(Key('home_prayer_row_${name.toLowerCase()}')),
                matching: find.text(name)),
            findsOneWidget);
      }
    });

    testWidgets('a row shows pending, completed and the percentage',
        (tester) async {
      await pumpHome(tester, await ledger());

      // Fajr: 1 pending, 4 completed, 80% complete.
      expect(textOf(tester, const Key('home_prayer_pending_fajr')), '1');
      expect(find.text('4 completed'), findsOneWidget);
      expect(textOf(tester, const Key('home_prayer_percent_fajr')), '80%');
      final bar = tester.widget<LinearProgressIndicator>(
          find.byKey(const Key('home_prayer_bar_fajr')));
      expect(bar.value, closeTo(0.8, 0.001));
    });

    testWidgets('a prayer with no records reads zero', (tester) async {
      await pumpHome(tester, await ledger());

      expect(textOf(tester, const Key('home_prayer_pending_isha')), '0');
      final bar = tester.widget<LinearProgressIndicator>(
          find.byKey(const Key('home_prayer_bar_isha')));
      expect(bar.value, 0);
    });

    testWidgets('the whole row is tappable', (tester) async {
      await pumpHome(tester, await ledger());

      expect(
          tester
              .widget<InkWell>(find.descendant(
                  of: find.byKey(const Key('home_prayer_row_fajr')),
                  matching: find.byType(InkWell)))
              .onTap,
          isNotNull);
    });
  });

  group('prayer navigation', () {
    for (final prayer in PrayerType.values) {
      testWidgets('${prayer.name} opens Qaza filtered to it and Pending',
          (tester) async {
        final container = await pumpHome(tester, await ledger(),
            home: const WorkspaceShell());
        expect(container.read(workspaceDestinationProvider),
            WorkspaceDestination.home);

        await tester.tap(find.byKey(Key('home_prayer_row_${prayer.name}')));
        await tester.pumpAndSettle();

        expect(container.read(workspaceDestinationProvider),
            WorkspaceDestination.qaza);
        // The tracker built from the hand-off, not from its own defaults.
        final tracker = container.read(qazaTrackerControllerProvider);
        expect(tracker.prayerFilter, prayer);
        expect(tracker.statusFilter, QazaStatusFilter.pending);
        expect(find.byKey(const Key('qaza_tracker_status_filter')),
            findsOneWidget);
      });
    }
  });

  group('repeated prayer selection', () {
    testWidgets('a second prayer replaces the first filter', (tester) async {
      final container =
          await pumpHome(tester, await ledger(), home: const WorkspaceShell());

      await tester.tap(find.byKey(const Key('home_prayer_row_fajr')));
      await tester.pumpAndSettle();
      expect(container.read(qazaTrackerControllerProvider).prayerFilter,
          PrayerType.fajr);

      // Back to Home and pick a different prayer. The Qaza tab stays mounted,
      // so this is the case that used to keep showing the first prayer.
      container.read(workspaceDestinationProvider.notifier).state =
          WorkspaceDestination.home;
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('home_prayer_row_asr')));
      await tester.pumpAndSettle();

      expect(container.read(workspaceDestinationProvider),
          WorkspaceDestination.qaza);
      final tracker = container.read(qazaTrackerControllerProvider);
      expect(tracker.prayerFilter, PrayerType.asr);
      expect(tracker.statusFilter, QazaStatusFilter.pending);
      // The hand-off is consumed, not left to replay later.
      expect(container.read(qazaTrackerFilterRequestProvider), isNull);
    });

    testWidgets('every prayer in turn lands on its own filter', (tester) async {
      final container =
          await pumpHome(tester, await ledger(), home: const WorkspaceShell());

      for (final prayer in PrayerType.values) {
        container.read(workspaceDestinationProvider.notifier).state =
            WorkspaceDestination.home;
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(Key('home_prayer_row_${prayer.name}')));
        await tester.pumpAndSettle();

        expect(
            container.read(qazaTrackerControllerProvider).prayerFilter, prayer,
            reason: prayer.name);
      }
    });

    testWidgets('a filter the user set by hand is not overwritten later',
        (tester) async {
      final container =
          await pumpHome(tester, await ledger(), home: const WorkspaceShell());

      await tester.tap(find.byKey(const Key('home_prayer_row_fajr')));
      await tester.pumpAndSettle();

      // Changing the filter inside the tracker must stick: no stale request
      // is left over to re-apply Fajr.
      container
          .read(qazaTrackerControllerProvider.notifier)
          .setPrayerFilter(PrayerType.isha);
      await tester.pumpAndSettle();

      expect(container.read(qazaTrackerControllerProvider).prayerFilter,
          PrayerType.isha);
    });
  });

  group('sync status', () {
    testWidgets('the sync card is not on Home', (tester) async {
      await pumpHome(tester, await ledger());

      // It stays available under Settings -> Backup & Data; Home leads with
      // progress instead.
      expect(find.byKey(const Key('sync_status_bar')), findsNothing);
      expect(find.textContaining('Your changes are saved on this device'),
          findsNothing);
    });
  });

  group('header', () {
    testWidgets('carries the title alone', (tester) async {
      await pumpHome(tester, await ledger());

      expect(find.text('Home'), findsOneWidget);
      expect(find.byIcon(Icons.person_outline_rounded), findsNothing);
      expect(find.byIcon(Icons.notifications_none_rounded), findsNothing);
    });
  });

  group('themes, languages and small screens', () {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('renders in ${mode.name} without overflow', (tester) async {
        await pumpHome(tester, await ledger(), themeMode: mode);

        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('home_progress_overview')), findsOneWidget);
      });
    }

    testWidgets('renders right to left in Urdu', (tester) async {
      await pumpHome(tester, await ledger(), locale: const Locale('ur'));

      expect(Directionality.of(tester.element(find.byType(HomeScreen))),
          TextDirection.rtl);
      expect(tester.takeException(), isNull);
      // The chevron points onward for the reading direction.
      expect(find.byIcon(Icons.chevron_left_rounded), findsWidgets);
      expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
    });

    testWidgets('survives a small screen', (tester) async {
      await pumpHome(tester, await ledger(), size: const Size(320, 640));

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('home_progress_overview')), findsOneWidget);
    });

    testWidgets('survives a small screen at double text scale', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      final repository = await ledger();

      await tester.pumpWidget(ProviderScope(
        overrides: [
          qazaRepositoryProvider.overrideWithValue(repository),
          activeUserIdProvider.overrideWithValue('u1'),
        ],
        child: const MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(2.0)),
          child: TestApp(home: HomeScreen()),
        ),
      ));
      await tester.pumpAndSettle();

      final exception = tester.takeException();
      debugPrint('TASK10_HOME_DOUBLE_SCALE_EXCEPTION: $exception');
      expect(exception, isNull);
    });
  });
}
