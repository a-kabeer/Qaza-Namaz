import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/app/providers.dart';
import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/core/theme/app_theme.dart';
import 'package:qaza_namaz/domain/entities/app_user.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';
import 'package:qaza_namaz/domain/entities/qaza_progress.dart';
import 'package:qaza_namaz/features/home/home_plan.dart';
import 'package:qaza_namaz/features/home/home_qaza_completion.dart';
import 'package:qaza_namaz/features/home/home_screen.dart';
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
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    final overrides = <Override>[
      qazaRepositoryProvider.overrideWithValue(repository),
      activeUserIdProvider.overrideWithValue('u1'),
      authStateProvider.overrideWith(
        (ref) => Stream.value(
          const AppUser(id: 'u1', email: 'u1@example.com'),
        ),
      ),
      if (currentPrayer)
        homeCurrentPrayerProvider.overrideWith(
          _TestHomeCurrentPrayerNotifier.new,
        ),
      if (restrictionEvaluation != null)
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

  group('reference dashboard layout', () {
    testWidgets('renders the reference sections in order', (tester) async {
      await pumpHome(tester, await ledger());

      expect(find.byKey(const Key('home_dashboard')), findsOneWidget);
      expect(find.byKey(const Key('home_today_progress')), findsOneWidget);
      expect(find.byKey(const Key('home_overall_qaza')), findsOneWidget);
      expect(find.byKey(const Key('home_pending_by_prayer')), findsOneWidget);
      expect(find.byKey(const Key('home_your_progress')), findsOneWidget);
      expect(find.byKey(const Key('home_detailed_statistics')), findsOneWidget);

      final today = tester.getRect(find.byKey(const Key('home_today_progress')));
      final overall = tester.getRect(find.byKey(const Key('home_overall_qaza')));
      final pending =
          tester.getRect(find.byKey(const Key('home_pending_by_prayer')));
      final chart = tester.getRect(find.byKey(const Key('home_your_progress')));
      final details =
          tester.getRect(find.byKey(const Key('home_detailed_statistics')));

      expect(today.bottom, lessThanOrEqualTo(overall.top));
      expect(overall.bottom, lessThanOrEqualTo(pending.top));
      expect(pending.bottom, lessThanOrEqualTo(chart.top));
      expect(chart.bottom, lessThanOrEqualTo(details.top));
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
    testWidgets('shows daily donut and current prayer oldest pending',
        (tester) async {
      await pumpHome(tester, await ledger());

      expect(find.byKey(const Key('home_today_donut')), findsOneWidget);
      expect(find.byKey(const Key('home_today_percent')), findsOneWidget);
      expect(find.byKey(const Key('home_today_count')), findsOneWidget);
      expect(find.text('Next Qaza (Current Prayer)'), findsOneWidget);
      expect(find.text('Fajr'), findsWidgets);
      expect(find.byKey(const Key('home_oldest_qaza_date')), findsOneWidget);
      expect(find.byKey(const Key('home_complete_oldest_qaza')), findsOneWidget);
      expect(find.byKey(const Key('home_qaza_plan_button')), findsOneWidget);

    
    testWidgets(
        'explains restricted time instead of showing Complete Qaza',
        (tester) async {
      const restriction = QazaRestrictionEvaluation(
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
      const restriction = QazaRestrictionEvaluation(
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

    testWidgets('handles missing current prayer without crashing',
        (tester) async {
      await pumpHome(
        tester,
        await ledger(),
        currentPrayer: false,
      );

      expect(
        find.byKey(const Key('home_qaza_prayer_time_unavailable')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('home prayer selection', () {
    testWidgets('allows selecting any prayer with pending Qaza', (tester) async {
      await pumpHome(tester, await ledger());

      await tester.tap(find.byKey(const Key('home_qaza_prayer_selector')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('home_qaza_prayer_option_auto')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('home_qaza_prayer_option_fajr')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('home_qaza_prayer_option_zuhr')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('home_qaza_prayer_option_asr')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('home_qaza_prayer_option_maghrib')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('home_qaza_prayer_option_isha')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('home_qaza_prayer_option_witr')),
        findsNothing,
      );

      await tester.tap(
        find.byKey(const Key('home_qaza_prayer_option_zuhr')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Next Qaza'), findsOneWidget);
      expect(find.text('Zuhr'), findsWidgets);
      expect(find.text('04 Jan 2026'), findsOneWidget);
    });
  });

  group('overall and prayer graphs', () {
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

    testWidgets('shows all six pending-by-prayer bars with counts',
        (tester) async {
      await pumpHome(tester, await ledger());

      for (final prayer in PrayerType.values) {
        expect(
          find.byKey(Key('home_pending_prayer_' + prayer.name)),
          findsOneWidget,
        );
        expect(
          find.byKey(Key('home_pending_bar_' + prayer.name)),
          findsOneWidget,
        );
      }

      expect(find.text('1').evaluate(), isNotEmpty);
      expect(find.byKey(const Key('home_pending_by_prayer_view_all')),
          findsOneWidget);
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

    testWidgets('graph has range controls and is data-driven', (tester) async {
      await pumpHome(tester, await ledger());

      expect(find.byKey(const Key('home_progress_range')), findsOneWidget);
      expect(find.text('7 Days'), findsOneWidget);
      expect(find.text('30 Days'), findsOneWidget);
      expect(find.text('Monthly'), findsOneWidget);
      expect(find.byKey(const Key('home_progress_chart')), findsOneWidget);

      await tester.tap(find.text('30 Days'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('home_progress_chart')), findsOneWidget);
    });
  });

  group('details and empty state', () {
    testWidgets('opens detailed statistics from the Home row', (tester) async {
      await pumpHome(tester, await ledger());

      await tester.tap(find.byKey(const Key('home_detailed_statistics')));
      await tester.pumpAndSettle();

      expect(find.text('View Detailed Statistics'), findsOneWidget);
      expect(find.text('Overall Qaza'), findsOneWidget);
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
