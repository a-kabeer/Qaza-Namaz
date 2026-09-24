import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/app/providers.dart';
import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/core/diagnostics/diagnostics.dart';
import 'package:qaza_namaz/core/theme/app_theme.dart';
import 'package:qaza_namaz/domain/entities/app_user.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';
import 'package:qaza_namaz/domain/entities/qaza_completion_result.dart';
import 'package:qaza_namaz/domain/entities/qaza_progress.dart';
import 'package:qaza_namaz/features/home/home_screen.dart';
import 'package:qaza_namaz/features/home/home_state.dart';
import 'package:qaza_namaz/features/home/providers/home_providers.dart';
import 'package:qaza_namaz/features/prayer_times/domain/qaza_restriction_service.dart';
import 'package:qaza_namaz/features/prayer_times/prayer_times_providers.dart';
import 'package:qaza_namaz/features/qaza/add_qaza_screen.dart';
import 'package:qaza_namaz/features/calculator/calculator_screen.dart';

import 'support/in_memory_qaza_repository.dart';
import 'support/test_app.dart';

final _stamp = DateTime(2026, 9, 22);

QazaRecord _record(
  String id,
  PrayerType prayer,
  DateTime originalDate,
  QazaStatus status, {
  DateTime? completedAt,
}) =>
    QazaRecord(
      id: id,
      userId: 'u1',
      prayerType: prayer,
      originalDate: originalDate,
      status: status,
      completedAt: completedAt,
      createdAt: _stamp,
      updatedAt: completedAt ?? _stamp,
    );


class _TestHomeCurrentPrayerNotifier extends HomeCurrentPrayerNotifier {
  @override
  HomeCurrentPrayerState build() =>
      const HomeCurrentPrayerState(prayer: PrayerType.fajr);
}

void main() {
  Future<InMemoryQazaRepository> ledger() async {
    final repository = InMemoryQazaRepository();
    await repository.addRecords([
      _record(
        'f1',
        PrayerType.fajr,
        DateTime(2026, 1, 1),
        QazaStatus.pending,
      ),
      _record(
        'f2',
        PrayerType.fajr,
        DateTime(2026, 1, 2),
        QazaStatus.completed,
        completedAt: _stamp,
      ),
      _record(
        'f3',
        PrayerType.fajr,
        DateTime(2026, 1, 3),
        QazaStatus.completed,
        completedAt: _stamp.subtract(const Duration(days: 1)),
      ),
      _record(
        'z1',
        PrayerType.zuhr,
        DateTime(2026, 1, 4),
        QazaStatus.pending,
      ),
      _record(
        'a1',
        PrayerType.asr,
        DateTime(2026, 1, 5),
        QazaStatus.completed,
        completedAt: _stamp,
      ),
    ]);
    return repository;
  }

  Future<ProviderContainer> pumpHome(
    WidgetTester tester,
    InMemoryQazaRepository repository, {
    Locale locale = const Locale('en'),
    ThemeMode themeMode = ThemeMode.light,
    Size size = const Size(900, 2000),
    bool currentPrayer = true,
    QazaRestrictionEvaluation? restrictionEvaluation,
    bool restrictionEvaluationFails = false,
    DateTime? now,
    DiagnosticsService? diagnostics,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    final overrides = <Override>[
      qazaRepositoryProvider.overrideWithValue(repository),
      activeUserIdProvider.overrideWithValue('u1'),
      if (diagnostics != null) diagnosticsProvider.overrideWithValue(diagnostics),
      if (now != null) homeNowProvider.overrideWithValue(now),
      authStateProvider.overrideWith(
        (ref) => Stream.value(
          const AppUser(id: 'u1', email: 'u1@example.com'),
        ),
      ),
      if (currentPrayer)
        homeCurrentPrayerProvider.overrideWith(
          _TestHomeCurrentPrayerNotifier.new,
        ),
      if (restrictionEvaluationFails)
        qazaRestrictionEvaluationProvider.overrideWith(
          (ref) => Future<QazaRestrictionEvaluation>.error(
            StateError('restriction lookup failed'),
          ),
        )
      else if (restrictionEvaluation != null)
        qazaRestrictionEvaluationProvider.overrideWith(
          (ref) async => restrictionEvaluation,
        ),
    ];

    final container = ProviderContainer(overrides: overrides);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: TestApp(
          theme: AppTheme.light(locale: locale),
          darkTheme: AppTheme.dark(locale: locale),
          themeMode: themeMode,
          locale: locale,
          home: const HomeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  String textOf(WidgetTester tester, Key key) {
    final finder = find.descendant(
      of: find.byKey(key),
      matching: find.byType(Text),
    );
    return tester.widget<Text>(finder.last).data!;
  }

  String firstTextOf(WidgetTester tester, Key key) {
    final finder = find.descendant(
      of: find.byKey(key),
      matching: find.byType(Text),
    );
    return tester.widget<Text>(finder.first).data!;
  }

  group('reference dashboard layout', () {
    testWidgets('renders the reference sections in order', (tester) async {
      await pumpHome(tester, await ledger());

      expect(find.byKey(const Key('home_dashboard')), findsOneWidget);
      expect(find.byKey(const Key('sync_status_bar')), findsNothing);
      expect(find.byKey(const Key('sync_retry_button')), findsNothing);
      expect(find.byKey(const Key('home_today_progress')), findsOneWidget);
      expect(find.byKey(const Key('home_overall_qaza')), findsOneWidget);
      expect(find.byKey(const Key('home_pending_by_prayer')), findsOneWidget);
      expect(find.byKey(const Key('home_your_progress')), findsOneWidget);
      expect(find.byKey(const Key('home_detailed_statistics')), findsNothing);

      final today = tester.getRect(find.byKey(const Key('home_today_progress')));
      final overall = tester.getRect(find.byKey(const Key('home_overall_qaza')));
      final pending =
          tester.getRect(find.byKey(const Key('home_pending_by_prayer')));
      final chart = tester.getRect(find.byKey(const Key('home_your_progress')));

      expect(today.bottom, lessThanOrEqualTo(overall.top));
      expect(overall.bottom, lessThanOrEqualTo(pending.top));
      expect(pending.bottom, lessThanOrEqualTo(chart.top));
    });

    testWidgets('does not add the removed slogan or Quranic content',
        (tester) async {
      await pumpHome(tester, await ledger());

      expect(find.text('Small steps, a lighter tomorrow'), findsNothing);
      expect(find.text('Consistent effort today, a brighter tomorrow.'), findsNothing);
      expect(find.text('And establish prayer for My remembrance.'), findsNothing);
      expect(find.text('Alhamdulillah!'), findsNothing);
    });
  });

  group('today progress and next Qaza', () {
    testWidgets('shows daily donut and Sahib required Qaza', (tester) async {
      await pumpHome(tester, await ledger());

      expect(find.byKey(const Key('home_today_donut')), findsOneWidget);
      expect(find.byKey(const Key('home_today_percent')), findsOneWidget);
      expect(find.byKey(const Key('home_today_count')), findsOneWidget);
      expect(find.text('Next Qaza'), findsOneWidget);
      expect(find.byKey(const Key('home_current_prayer')), findsOneWidget);
      expect(find.text('Fajr'), findsWidgets);
      expect(find.byKey(const Key('home_oldest_qaza_date')), findsOneWidget);
      expect(find.byKey(const Key('home_complete_oldest_qaza')), findsOneWidget);
      expect(find.byKey(const Key('home_qaza_plan_button')), findsOneWidget);
      expect(find.byKey(const Key('home_estimated_completion')), findsOneWidget);
    });

    testWidgets(
        'explains restricted time instead of showing Complete Qaza',
        (tester) async {
      final restriction = QazaRestrictionEvaluation(
        isRestricted: true,
        type: RestrictionType.sunrise,
        remaining: Duration(minutes: 12),
        nextAllowedTime: DateTime(2026, 9, 22, 18, 42),
      );

      await pumpHome(
        tester,
        await ledger(),
        restrictionEvaluation: restriction,
      );

      expect(
        find.byKey(const Key('home_qaza_restricted_state')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('home_complete_oldest_qaza')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('home_qaza_restricted_title')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('home_qaza_restricted_reason')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('home_qaza_restricted_remaining')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('home_qaza_restricted_available_at')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('home_qaza_view_all')),
        findsOneWidget,
      );
    });

    testWidgets('restricted Home state uses Urdu localization', (tester) async {
      final restriction = QazaRestrictionEvaluation(
        isRestricted: true,
        type: RestrictionType.zawal,
        remaining: Duration(minutes: 5),
        nextAllowedTime: DateTime(2026, 9, 22, 18, 55),
      );

      await pumpHome(
        tester,
        await ledger(),
        locale: const Locale('ur'),
        restrictionEvaluation: restriction,
      );

      expect(find.text('قضا عارضی طور پر دستیاب نہیں'), findsOneWidget);
      expect(
        find.byKey(const Key('home_qaza_restricted_available_at')),
        findsOneWidget,
      );
      expect(find.text('تمام قضا دیکھیں'), findsOneWidget);
    });

    testWidgets(
        'completion still works when the restriction lookup provider fails',
        (tester) async {
      final repository = InMemoryQazaRepository();
      await repository.addRecords([
        _record(
          'f1',
          PrayerType.fajr,
          DateTime(2026, 1, 1),
          QazaStatus.pending,
        ),
        _record(
          'f2',
          PrayerType.fajr,
          DateTime(2026, 1, 2),
          QazaStatus.pending,
        ),
      ]);

      await pumpHome(
        tester,
        repository,
        restrictionEvaluationFails: true,
      );
      expect(find.text('01 Jan 2026'), findsOneWidget);

      await tester.tap(find.byKey(const Key('home_complete_oldest_qaza')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        find.text('Qaza cannot be completed, please try again'),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });



    testWidgets(
        'stale displayed Qaza does not show false completion or undo UI',
        (tester) async {
      final repository = await ledger();
      final diagnostics = BufferedDiagnostics();

      await pumpHome(
        tester,
        repository,
        diagnostics: diagnostics,
      );

      final staleAt = DateTime(2026, 9, 23, 12);
      final staleResult = await repository.completeRecord(
        userId: 'u1',
        recordId: 'f1',
        completedAt: staleAt,
      );
      expect(staleResult, QazaCompletionResult.completed);

      await tester.tap(find.byKey(const Key('home_complete_oldest_qaza')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('qaza_undo_banner')), findsNothing);
      expect(find.text('Qaza cannot be completed, please try again'), findsNothing);
      expect(tester.takeException(), isNull);
      expect(
        diagnostics.events.where((event) => event.code == 'completion_failed'),
        isEmpty,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('completing the displayed oldest Qaza updates Home',
        (tester) async {
      final repository = InMemoryQazaRepository();
      await repository.addRecords([
        _record(
          'f1',
          PrayerType.fajr,
          DateTime(2026, 1, 1),
          QazaStatus.pending,
        ),
        _record(
          'f2',
          PrayerType.fajr,
          DateTime(2026, 1, 2),
          QazaStatus.pending,
        ),
      ]);

      await pumpHome(tester, repository);
      expect(find.text('01 Jan 2026'), findsOneWidget);

      await tester.tap(find.byKey(const Key('home_complete_oldest_qaza')));
      await tester.pumpAndSettle();

      expect(find.text('02 Jan 2026'), findsOneWidget);
    });

    testWidgets('handles missing current prayer in non-Sahib mode without crashing',
        (tester) async {
      final repository = await ledger();
      await repository.addRecords([
        _record('f4', PrayerType.fajr, DateTime(2026, 1, 10), QazaStatus.pending),
        _record('f5', PrayerType.fajr, DateTime(2026, 1, 11), QazaStatus.pending),
        _record('f6', PrayerType.fajr, DateTime(2026, 1, 12), QazaStatus.pending),
        _record('f7', PrayerType.fajr, DateTime(2026, 1, 13), QazaStatus.pending),
      ]);
      await pumpHome(
        tester,
        repository,
        currentPrayer: false,
      );

      expect(
        find.byKey(const Key('home_qaza_prayer_time_setup')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('home_setup_prayer_times')), findsOneWidget);
      expect(find.text('Fajr'), findsWidgets);
      expect(find.text('01 Jan 2026'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('home prayer selection', () {
    testWidgets('disables non-required Fard under Sahib al-Tartib', (tester) async {
      await pumpHome(tester, await ledger());

      await tester.tap(find.byKey(const Key('home_qaza_prayer_selector')));
      await tester.pumpAndSettle();

      final fajr = tester.widget<PopupMenuItem<String>>(
        find.byKey(const Key('home_qaza_prayer_option_fajr')),
      );
      final zuhr = tester.widget<PopupMenuItem<String>>(
        find.byKey(const Key('home_qaza_prayer_option_zuhr')),
      );

      expect(fajr.enabled, isTrue);
      expect(zuhr.enabled, isFalse);
      expect(
        find.byIcon(Icons.lock_outline_rounded),
        findsOneWidget,
      );
    });

    testWidgets('keeps Witr independently selectable', (tester) async {
      final repository = InMemoryQazaRepository();
      await repository.addRecords([
        _record(
          'w1',
          PrayerType.witr,
          DateTime(2026, 1, 4),
          QazaStatus.pending,
        ),
      ]);

      await pumpHome(tester, repository);

      await tester.tap(find.byKey(const Key('home_qaza_prayer_selector')));
      await tester.pumpAndSettle();

      final witr = tester.widget<PopupMenuItem<String>>(
        find.byKey(const Key('home_qaza_prayer_option_witr')),
      );
      expect(witr.enabled, isTrue);

      await tester.tap(find.byKey(const Key('home_qaza_prayer_option_witr')));
      await tester.pumpAndSettle();

      expect(find.text('Witr'), findsWidgets);
      expect(find.text('04 Jan 2026'), findsOneWidget);
    });
  });

  group('overall and prayer graphs', () {
    testWidgets('renders 0% donut for an all-pending ledger', (tester) async {
      final repository = InMemoryQazaRepository();
      await repository.addRecords([
        _record(
          'f1',
          PrayerType.fajr,
          DateTime(2026, 1, 1),
          QazaStatus.pending,
        ),
      ]);

      await pumpHome(tester, repository);

      expect(find.byKey(const Key('home_overall_donut')), findsOneWidget);
      final overallPercent = tester.widget<Text>(
        find.byKey(const Key('home_overall_percent')),
      );
      expect(overallPercent.data, '0%');
    });

    testWidgets('shows completed, pending and total with donut', (tester) async {
      await pumpHome(tester, await ledger());

      expect(
        textOf(tester, const Key('home_completed_value')),
        '3',
      );
      expect(
        textOf(tester, const Key('home_pending_value')),
        '2',
      );
      expect(
        textOf(tester, const Key('home_total_value')),
        '5',
      );
      expect(find.byKey(const Key('home_overall_donut')), findsOneWidget);
      expect(find.byKey(const Key('home_overall_percent')), findsOneWidget);
    });

    testWidgets('shows only pending prayers with prayer-specific pending ratios and counts',
        (tester) async {
      await pumpHome(tester, await ledger());

      for (final prayer in [PrayerType.fajr, PrayerType.zuhr]) {
        expect(
          find.byKey(Key('home_pending_prayer_' + prayer.name)),
          findsOneWidget,
        );
        expect(
          find.byKey(Key('home_pending_bar_' + prayer.name)),
          findsOneWidget,
        );
      }

      for (final prayer in [
        PrayerType.asr,
        PrayerType.maghrib,
        PrayerType.isha,
        PrayerType.witr,
      ]) {
        expect(
          find.byKey(Key('home_pending_prayer_' + prayer.name)),
          findsNothing,
        );
        expect(
          find.byKey(Key('home_pending_bar_' + prayer.name)),
          findsNothing,
        );
      }

      final fajrBar = tester.widget<LinearProgressIndicator>(
        find.byKey(const Key('home_pending_bar_fajr')),
      );
      final zuhrBar = tester.widget<LinearProgressIndicator>(
        find.byKey(const Key('home_pending_bar_zuhr')),
      );
      expect(fajrBar.value, closeTo(1 / 3, 0.0001));
      expect(zuhrBar.value, closeTo(1.0, 0.0001));
      expect(find.text('1').evaluate(), isNotEmpty);
      expect(
        find.byKey(const Key('home_pending_by_prayer_view_all')),
        findsOneWidget,
      );
    });

    testWidgets('uses each prayer total independently for pending bars', (tester) async {
      final repository = InMemoryQazaRepository();
      final records = <QazaRecord>[];

      for (var i = 0; i < 10; i++) {
        records.add(_record(
          'f-p-$i',
          PrayerType.fajr,
          DateTime(2020, 1, 1 + i),
          QazaStatus.pending,
        ));
        records.add(_record(
          'f-c-$i',
          PrayerType.fajr,
          DateTime(2020, 2, 1 + i),
          QazaStatus.completed,
          completedAt: _stamp,
        ));
      }

      for (var i = 0; i < 5; i++) {
        records.add(_record(
          'z-p-$i',
          PrayerType.zuhr,
          DateTime(2021, 1, 1 + i),
          QazaStatus.pending,
        ));
      }

      for (var i = 0; i < 2; i++) {
        records.add(_record(
          'a-p-$i',
          PrayerType.asr,
          DateTime(2022, 1, 1 + i),
          QazaStatus.pending,
        ));
      }
      for (var i = 0; i < 18; i++) {
        records.add(_record(
          'a-c-$i',
          PrayerType.asr,
          DateTime(2022, 2, 1 + i),
          QazaStatus.completed,
          completedAt: _stamp,
        ));
      }

      await repository.addRecords(records);
      await pumpHome(tester, repository);

      final fajrBar = tester.widget<LinearProgressIndicator>(
        find.byKey(const Key('home_pending_bar_fajr')),
      );
      final zuhrBar = tester.widget<LinearProgressIndicator>(
        find.byKey(const Key('home_pending_bar_zuhr')),
      );
      final asrBar = tester.widget<LinearProgressIndicator>(
        find.byKey(const Key('home_pending_bar_asr')),
      );

      expect(fajrBar.value, closeTo(0.5, 0.0001));
      expect(zuhrBar.value, closeTo(1.0, 0.0001));
      expect(asrBar.value, closeTo(0.1, 0.0001));
    });

    testWidgets('shows dedicated all-completed state and keeps 100% donut',
        (tester) async {
      final repository = InMemoryQazaRepository();
      await repository.addRecords([
        _record(
          'f1',
          PrayerType.fajr,
          DateTime(2026, 1, 1),
          QazaStatus.completed,
          completedAt: _stamp,
        ),
      ]);

      await pumpHome(tester, repository);

      expect(find.byKey(const Key('home_all_completed_state')), findsOneWidget);
      expect(find.byKey(const Key('sync_status_bar')), findsNothing);
      expect(find.byKey(const Key('sync_retry_button')), findsNothing);
      expect(
        find.byKey(const Key('home_overall_donut')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('home_overall_percent')),
        findsOneWidget,
      );
      expect(find.text('100%'), findsOneWidget);
      expect(
        find.byKey(const Key('home_pending_by_prayer')),
        findsNothing,
      );
      expect(find.byKey(const Key('home_all_completed_add')), findsOneWidget);
      expect(
        find.byKey(const Key('home_all_completed_calculate')),
        findsOneWidget,
      );
    });

    testWidgets('opens the existing Qaza workspace from View all',
        (tester) async {
      await pumpHome(tester, await ledger());

      await tester.tap(
        find.byKey(const Key('home_pending_by_prayer_view_all')),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('home_pending_by_prayer')), findsOneWidget);
    });

    testWidgets('graph supports 1-day and 3-day daily completed history',
        (tester) async {
      final repository = InMemoryQazaRepository();
      await repository.addRecords([
        _record(
          'sep20',
          PrayerType.fajr,
          DateTime(2026, 9, 1),
          QazaStatus.completed,
          completedAt: DateTime(2026, 9, 20),
        ),
        _record(
          'sep21',
          PrayerType.zuhr,
          DateTime(2026, 9, 2),
          QazaStatus.completed,
          completedAt: DateTime(2026, 9, 21),
        ),
        _record(
          'sep22a',
          PrayerType.asr,
          DateTime(2026, 9, 3),
          QazaStatus.completed,
          completedAt: DateTime(2026, 9, 22),
        ),
        _record(
          'sep22b',
          PrayerType.isha,
          DateTime(2026, 9, 4),
          QazaStatus.completed,
          completedAt: DateTime(2026, 9, 22),
        ),
      ]);

      final container = await pumpHome(
        tester,
        repository,
        now: DateTime(2026, 9, 22),
      );

      expect(find.byKey(const Key('home_progress_range')), findsOneWidget);
      expect(find.text('1 Day'), findsOneWidget);
      expect(find.text('3 Days'), findsOneWidget);
      expect(find.text('7 Days'), findsOneWidget);
      expect(find.text('30 Days'), findsOneWidget);
      expect(find.text('Monthly'), findsOneWidget);

      final oneDay = await container
          .read(homeProgressHistoryProvider(HomeProgressRange.oneDay).future);
      expect(oneDay.length, 1);
      expect(oneDay.single.start, DateTime(2026, 9, 22));
      expect(oneDay.single.count, 2);

      await tester.tap(find.text('3 Days'));
      await tester.pumpAndSettle();

      final threeDays = await container
          .read(homeProgressHistoryProvider(HomeProgressRange.threeDays).future);
      expect(threeDays.length, 3);
      expect(
        threeDays.map((point) => point.start),
        [
          DateTime(2026, 9, 20),
          DateTime(2026, 9, 21),
          DateTime(2026, 9, 22),
        ],
      );
      expect(
        threeDays.map((point) => point.count),
        [1, 1, 2],
      );

      final chart = tester.widget<LineChart>(
        find.descendant(
          of: find.byKey(const Key('home_progress_chart')),
          matching: find.byType(LineChart),
        ),
      );
      final tooltipItems = chart.data.lineTouchData.touchTooltipData
          .getTooltipItems!([
        LineBarSpot(
          chart.data.lineBarsData.first,
          0,
          const FlSpot(2, 2),
        ),
      ]);
      expect(tooltipItems.single!.text, contains('22 Sep 2026'));
      expect(tooltipItems.single!.text, contains('2 completed'));
      expect(
        tooltipItems.single!.textStyle.color,
        Theme.of(tester.element(find.byKey(const Key('home_progress_chart'))))
            .colorScheme
            .onInverseSurface,
      );
    });
  });

  group('details and empty state', () {
    testWidgets('opens detailed statistics from Overall Qaza View details',
        (tester) async {
      await pumpHome(tester, await ledger());

      await tester.tap(find.byKey(const Key('home_overall_view_details')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('detailed_statistics_screen')), findsOneWidget);
      expect(find.byKey(const Key('detailed_overall_statistics')), findsOneWidget);
      expect(find.text('View Detailed Statistics'), findsOneWidget);
      expect(find.text('Overall Qaza'), findsOneWidget);
    });

    testWidgets('detailed statistics stays in sync with the current provider',
        (tester) async {
      final repository = await ledger();
      final container = await pumpHome(tester, repository);

      await tester.tap(find.byKey(const Key('home_overall_view_details')));
      await tester.pumpAndSettle();

      expect(
        textOf(tester, const Key('detailed_overall_completed')),
        '3',
      );
      expect(
        textOf(tester, const Key('detailed_overall_total')),
        '5',
      );

      await repository.addRecords([
        _record(
          'z2',
          PrayerType.zuhr,
          DateTime(2026, 1, 6),
          QazaStatus.completed,
          completedAt: _stamp,
        ),
      ]);
      container.invalidate(progressSummaryProvider);
      await tester.pumpAndSettle();

      expect(
        textOf(tester, const Key('detailed_overall_completed')),
        '4',
      );
      expect(
        textOf(tester, const Key('detailed_overall_total')),
        '6',
      );
      expect(
        firstTextOf(tester, const Key('detailed_prayer_completed_zuhr')),
        '1',
      );
      expect(
        firstTextOf(tester, const Key('detailed_prayer_total_zuhr')),
        '2',
      );
    });

    testWidgets('shows complete prayer-wise statistics', (tester) async {
      await pumpHome(tester, await ledger());

      await tester.tap(find.byKey(const Key('home_overall_view_details')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('detailed_prayer_breakdown')), findsOneWidget);

      for (final prayer in PrayerType.values) {
        expect(
          find.byKey(Key('detailed_prayer_progress_' + prayer.name)),
          findsOneWidget,
        );
        expect(
          find.byKey(Key('detailed_prayer_completed_' + prayer.name)),
          findsOneWidget,
        );
        expect(
          find.byKey(Key('detailed_prayer_pending_' + prayer.name)),
          findsOneWidget,
        );
        expect(
          find.byKey(Key('detailed_prayer_total_' + prayer.name)),
          findsOneWidget,
        );
      }

      expect(
        firstTextOf(tester, const Key('detailed_prayer_completed_fajr')),
        '2',
      );
      expect(
        firstTextOf(tester, const Key('detailed_prayer_pending_fajr')),
        '1',
      );
      expect(
        firstTextOf(tester, const Key('detailed_prayer_total_fajr')),
        '3',
      );
    });

    testWidgets('keeps existing empty ledger actions', (tester) async {
      await pumpHome(tester, InMemoryQazaRepository());

      expect(find.byKey(const Key('home_empty_state')), findsOneWidget);
      expect(find.byKey(const Key('home_empty_calculate')), findsOneWidget);
      expect(find.byKey(const Key('home_empty_add')), findsOneWidget);
      expect(find.byKey(const Key('home_today_progress')), findsNothing);
      expect(find.byKey(const Key('home_your_progress')), findsNothing);

      await tester.tap(find.byKey(const Key('home_empty_calculate')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(CalculatorScreen), findsWidgets);
    });

    testWidgets('supports Urdu and dark theme', (tester) async {
      await pumpHome(
        tester,
        await ledger(),
        locale: const Locale('ur'),
        themeMode: ThemeMode.dark,
      );

      expect(find.text('مجموعی قضا'), findsOneWidget);
      expect(find.text('نماز کے لحاظ سے باقی'), findsOneWidget);
      expect(find.text('آپ کی پیش رفت'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('survives a small screen and large text', (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);

      final repository = await ledger();
      final container = ProviderContainer(overrides: [
        qazaRepositoryProvider.overrideWithValue(repository),
        activeUserIdProvider.overrideWithValue('u1'),
        authStateProvider.overrideWith(
          (ref) => Stream.value(
            const AppUser(id: 'u1', email: 'u1@example.com'),
          ),
        ),
        homeCurrentPrayerProvider.overrideWith(
          _TestHomeCurrentPrayerNotifier.new,
        ),
      ]);
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MediaQuery(
            data: const MediaQueryData(
              textScaler: TextScaler.linear(1.8),
            ),
            child: TestApp(
              theme: AppTheme.light(),
              home: const HomeScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
