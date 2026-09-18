import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/app/providers.dart';
import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/core/theme/app_theme.dart';
import 'package:qaza_namaz/domain/entities/app_user.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';
import 'package:qaza_namaz/features/home/home_screen.dart';
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
    testWidgets('shows total, pending, completed and the overall percentage',
        (tester) async {
      await pumpHome(tester, await ledger());

      expect(find.byKey(const Key('home_progress_overview')), findsOneWidget);
      expect(textOf(tester, const Key('home_pending_value')), '2');
      expect(find.text('Total'), findsOneWidget);
      expect(find.text('6'), findsOneWidget); // total
      expect(find.text('4'), findsWidgets); // completed
      // 4 of 6 completed.
      expect(find.text('67%'), findsOneWidget);
      expect(find.byKey(const Key('home_progress_ring')), findsOneWidget);
    });

    testWidgets('pending is the most prominent number', (tester) async {
      await pumpHome(tester, await ledger());

      final pending =
          tester.widget<Text>(find.byKey(const Key('home_pending_value')));
      final theme = Theme.of(tester.element(find.byType(HomeScreen)));
      expect(pending.style!.fontSize, theme.textTheme.displaySmall!.fontSize);
      expect(pending.style!.fontSize,
          greaterThan(theme.textTheme.titleLarge!.fontSize!));
    });

    testWidgets('an empty ledger reads zero rather than failing',
        (tester) async {
      await pumpHome(tester, InMemoryQazaRepository());

      expect(textOf(tester, const Key('home_pending_value')), '0');
      expect(find.text('0%'), findsWidgets);
      expect(find.byKey(const Key('home_prayer_row_witr')), findsOneWidget);
    });

    testWidgets('a fully completed ledger reads 100%', (tester) async {
      final repository = InMemoryQazaRepository();
      await repository.addRecords([
        _record(PrayerType.fajr, 1, QazaStatus.completed),
        _record(PrayerType.asr, 2, QazaStatus.completed),
      ]);
      await pumpHome(tester, repository);

      expect(textOf(tester, const Key('home_pending_value')), '0');
      expect(find.text('100%'), findsWidgets);
    });
  });

  group('actions', () {
    testWidgets('the two quick actions share a row at equal width',
        (tester) async {
      await pumpHome(tester, await ledger());

      final calculate =
          tester.getRect(find.byKey(const Key('home_calculate_qaza')));
      final add = tester.getRect(find.byKey(const Key('home_add_qaza')));

      expect(calculate.width, add.width);
      expect(calculate.top, add.top);
    });

    testWidgets('quick actions use secondary styling', (tester) async {
      await pumpHome(tester, await ledger());

      for (final key in const [
        Key('home_calculate_qaza'),
        Key('home_add_qaza')
      ]) {
        expect(
            find.descendant(
                of: find.byKey(key), matching: find.byType(OutlinedButton)),
            findsOneWidget);
      }
    });

    testWidgets('Complete Qaza is the shell action, not a Home button',
        (tester) async {
      await pumpHome(tester, await ledger(), home: const WorkspaceShell());

      // The action belongs to the shell so Home and Qaza share one button.
      expect(find.byKey(const Key('home_complete_qaza')), findsNothing);
      expect(find.byKey(const Key('complete_qaza_fab')), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.text('Complete Qaza'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline_rounded), findsOneWidget);
    });

    testWidgets('the action is absent when nothing is pending', (tester) async {
      final repository = InMemoryQazaRepository();
      await repository
          .addRecords([_record(PrayerType.fajr, 1, QazaStatus.completed)]);
      await pumpHome(tester, repository, home: const WorkspaceShell());

      expect(find.byKey(const Key('complete_qaza_fab')), findsNothing);
    });

    testWidgets('the action follows the user to the Qaza tab', (tester) async {
      final container =
          await pumpHome(tester, await ledger(), home: const WorkspaceShell());

      container.read(workspaceDestinationProvider.notifier).state =
          WorkspaceDestination.qaza;
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('complete_qaza_fab')), findsOneWidget);

      // Configuration screens do not carry it.
      container.read(workspaceDestinationProvider.notifier).state =
          WorkspaceDestination.settings;
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('complete_qaza_fab')), findsNothing);
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
      expect(find.text('Fajr'), findsOneWidget);
      expect(find.text('Witr'), findsOneWidget);
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

      expect(tester.takeException(), isNull);
    });
  });
}
