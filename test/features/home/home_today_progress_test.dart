import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:qaza_namaz/app/providers.dart';
import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/domain/entities/qaza_completion_result.dart';
import 'package:qaza_namaz/domain/entities/qaza_activity.dart';
import 'package:qaza_namaz/domain/entities/qaza_progress.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';
import 'package:qaza_namaz/domain/services/sahib_al_tartib_service.dart';
import 'package:qaza_namaz/features/home/home_state.dart';
import 'package:qaza_namaz/features/home/providers/home_providers.dart';
import 'package:qaza_namaz/features/home/widgets/home_today_progress.dart';
import 'package:qaza_namaz/features/qaza/completion/qaza_completion_controller.dart';
import 'package:qaza_namaz/features/qaza/qaza_tracker_controller.dart';
import 'package:qaza_namaz/features/shell/workspace_shell.dart';
import 'package:qaza_namaz/features/home/widgets/home_skeleton.dart';
import 'package:qaza_namaz/features/prayer_time/application/prayer_time_providers.dart';
import 'package:qaza_namaz/l10n/app_localizations.dart';
import 'package:qaza_namaz/core/widgets/skeleton.dart';

class _TestHomePrayerSelectionNotifier extends HomePrayerSelectionNotifier {
  _TestHomePrayerSelectionNotifier(this.initial);

  final HomePrayerSelectionState initial;

  @override
  HomePrayerSelectionState build() => initial;
}

class _RecordingSnackbarService extends AppSnackbarService {
  _RecordingSnackbarService(this.messages)
      : super(messengerKey: appScaffoldMessengerKey);

  final List<String> messages;

  @override
  void info(String message) => messages.add(message);
}

class _TestQazaCompletionController extends QazaCompletionController {
  @override
  Future<QazaCompletionReceipt> completeRecordWithReceipt({
    required String userId,
    required String recordId,
    required DateTime completedAt,
  }) async {
    return const QazaCompletionReceipt(
      result: QazaCompletionResult.alreadyCompleted,
    );
  }
}

QazaRecord _pendingRecord({
  required String id,
  required PrayerType prayer,
  required DateTime date,
}) =>
    QazaRecord(
      id: id,
      userId: 'u1',
      prayerType: prayer,
      originalDate: date,
      createdAt: date,
      updatedAt: date,
    );

QazaProgressSummary _summaryFor(QazaRecord record) =>
    QazaProgressSummary.fromRecords([record]);

Future<ProviderContainer> _containerFor({
  required HomePrayerSelectionState selection,
  required QazaRecord targetRecord,
  required void Function() onDailyProgressRead,
  Future<HomeDailyProgress> Function()? dailyProgress,
  bool useFixedTargetResolution = false,
  bool includeActiveUser = false,
  bool useTestCompletionController = false,
  Future<QazaRecord?> Function()? oldestPendingOverride,
}) async {
  return ProviderContainer(
    overrides: [
      homePrayerSelectionProvider.overrideWith(
        () => _TestHomePrayerSelectionNotifier(selection),
      ),
      progressSummaryProvider.overrideWith(
        (ref) => Future.value(_summaryFor(targetRecord)),
      ),
      sahibAlTartibProvider.overrideWith(
        (ref) async => const SahibAlTartibState(
          pendingFarzCount: 6,
          requiresOrder: false,
          nextPending: null,
        ),
      ),
      qazaCompletionRestrictedProvider.overrideWith((ref) => false),
      currentQazaPrayerTypeProvider.overrideWith(
        (ref) => targetRecord.prayerType,
      ),
      oldestPendingProvider(targetRecord.prayerType).overrideWith(
        (ref) => oldestPendingOverride?.call() ?? Future.value(targetRecord),
      ),
      if (includeActiveUser) activeUserIdProvider.overrideWithValue('u1'),
      if (useTestCompletionController)
        qazaCompletionControllerProvider.overrideWith(
          _TestQazaCompletionController.new,
        ),
      if (useFixedTargetResolution)
        homeSelectedPrayerProvider.overrideWith(
          (ref) => HomeSelectedPrayerState(
            mode: selection.mode,
            prayer: targetRecord.prayerType,
            source: switch (selection.mode) {
              HomePrayerSelectionMode.prayerTime =>
                HomePrayerSelectionSource.prayerTime,
              HomePrayerSelectionMode.autoSequence =>
                HomePrayerSelectionSource.autoSequence,
              HomePrayerSelectionMode.prayerSelection =>
                HomePrayerSelectionSource.prayerSelection,
            },
          ),
        ),
      homeDashboardActivityProvider.overrideWith(
        (ref) async {
          onDailyProgressRead();
          final value = await (dailyProgress?.call() ??
              Future.value(
                const HomeDailyProgress(completed: 2, target: 5),
              ));
          final today = DateTime(2026, 9, 30);
          final period = QazaActivityPeriod(
            from: today,
            toExclusive: today.add(const Duration(days: 1)),
            today: today,
            days: const [],
            dailyTarget: value.target,
          );
          return HomeDashboardActivity(
            dailyProgress: value,
            currentWeek: period,
            dailyGoals: period,
          );
        },
      ),
    ],
  );
}

Future<void> _pumpHomeTodayProgress(
  WidgetTester tester,
  ProviderContainer container,
  QazaRecord targetRecord,
) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(
          body: HomeTodayProgress(
            summary: _summaryFor(targetRecord),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Auto Sequence shows compact Today Progress and Next Qaza',
      (tester) async {
    final record = _pendingRecord(
      id: 'fajr',
      prayer: PrayerType.fajr,
      date: DateTime(2026, 9, 20),
    );
    var dailyReads = 0;
    final container = await _containerFor(
      selection: const HomePrayerSelectionState(),
      targetRecord: record,
      onDailyProgressRead: () => dailyReads++,
    );
    addTearDown(container.dispose);

    await _pumpHomeTodayProgress(tester, container, record);

    expect(find.byKey(const Key('home_today_progress')), findsOneWidget);
    expect(
      find.byKey(const Key('home_today_progress_bar')),
      findsOneWidget,
    );
    expect(
      find.byType(LinearProgressIndicator),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('home_today_progress_summary')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('home_today_donut')), findsNothing);
    expect(find.byKey(const Key('home_today_percent')), findsNothing);
    expect(find.byKey(const Key('home_today_count')), findsNothing);
    expect(find.byKey(const Key('home_today_date')), findsNothing);
    expect(find.byKey(const Key('home_today_date_hijri')), findsNothing);
    expect(find.text('2 / 5 completed • 40%'), findsOneWidget);
    expect(find.byKey(const Key('home_complete_oldest_qaza')), findsOneWidget);
    expect(find.byKey(const Key('home_estimated_completion')), findsOneWidget);
    expect(find.textContaining('5 per day'), findsNothing);
    expect(dailyReads, 1);
  });

  testWidgets(
      'Prayer Selection keeps Today Progress and targets the selected prayer',
      (tester) async {
    final record = _pendingRecord(
      id: 'zuhr',
      prayer: PrayerType.zuhr,
      date: DateTime(2026, 9, 21),
    );
    var dailyReads = 0;
    final container = await _containerFor(
      selection: const HomePrayerSelectionState(
        mode: HomePrayerSelectionMode.prayerSelection,
        selectedPrayer: PrayerType.zuhr,
      ),
      targetRecord: record,
      onDailyProgressRead: () => dailyReads++,
    );
    addTearDown(container.dispose);

    await _pumpHomeTodayProgress(tester, container, record);

    expect(find.byKey(const Key('home_today_progress_bar')), findsOneWidget);
    expect(find.byKey(const Key('home_today_donut')), findsNothing);
    expect(find.text('2 / 5 completed • 40%'), findsOneWidget);
    expect(find.text('Zuhr'), findsWidgets);
    expect(find.byKey(const Key('home_oldest_qaza_date')), findsOneWidget);
    expect(find.byKey(const Key('home_oldest_qaza_date_hijri')), findsOneWidget);
    expect(find.byKey(const Key('home_complete_oldest_qaza')), findsOneWidget);
    expect(find.byKey(const Key('home_today_date')), findsNothing);
    expect(find.byKey(const Key('home_today_date_hijri')), findsNothing);
    expect(dailyReads, 1);
  });

  testWidgets('Prayer Time keeps Today Progress and existing time targeting',
      (tester) async {
    final record = _pendingRecord(
      id: 'asr',
      prayer: PrayerType.asr,
      date: DateTime(2026, 9, 22),
    );
    var dailyReads = 0;
    final container = await _containerFor(
      selection: const HomePrayerSelectionState(
        mode: HomePrayerSelectionMode.prayerTime,
      ),
      targetRecord: record,
      onDailyProgressRead: () => dailyReads++,
    );
    addTearDown(container.dispose);

    await _pumpHomeTodayProgress(tester, container, record);

    expect(find.byKey(const Key('home_today_progress_bar')), findsOneWidget);
    expect(find.byKey(const Key('home_today_donut')), findsNothing);
    expect(find.byKey(const Key('home_complete_oldest_qaza')), findsOneWidget);
    expect(find.byKey(const Key('home_oldest_qaza_date')), findsOneWidget);
    expect(find.byKey(const Key('home_oldest_qaza_date_hijri')), findsOneWidget);
    expect(find.text('2 / 5 completed • 40%'), findsOneWidget);
    expect(find.text('Asr'), findsWidgets);
    expect(find.byKey(const Key('home_today_date')), findsNothing);
    expect(find.byKey(const Key('home_today_date_hijri')), findsNothing);
    expect(dailyReads, 1);
  });

  testWidgets('tapping Today Progress opens Completed Qaza workspace',
      (tester) async {
    final record = _pendingRecord(
      id: 'fajr',
      prayer: PrayerType.fajr,
      date: DateTime(2026, 9, 20),
    );
    final container = await _containerFor(
      selection: const HomePrayerSelectionState(),
      targetRecord: record,
      onDailyProgressRead: () {},
    );
    addTearDown(container.dispose);

    await _pumpHomeTodayProgress(tester, container, record);
    expect(
      container.read(workspaceDestinationProvider),
      WorkspaceDestination.home,
    );

    await tester.tap(find.byKey(const Key('home_today_progress_header')));
    await tester.pump();

    expect(
      container.read(workspaceDestinationProvider),
      WorkspaceDestination.qaza,
    );
    expect(
      container.read(qazaTrackerFilterRequestProvider)?.status,
      QazaStatusFilter.completed,
    );
  });

  testWidgets(
      'Today Progress child controls do not trigger workspace navigation',
      (tester) async {
    final record = _pendingRecord(
      id: 'fajr',
      prayer: PrayerType.fajr,
      date: DateTime(2026, 9, 20),
    );
    final container = await _containerFor(
      selection: const HomePrayerSelectionState(),
      targetRecord: record,
      onDailyProgressRead: () {},
      includeActiveUser: true,
      useTestCompletionController: true,
    );
    addTearDown(container.dispose);

    await _pumpHomeTodayProgress(tester, container, record);

    await tester.tap(find.byKey(const Key('home_qaza_prayer_selector')));
    await tester.pump();
    expect(
      container.read(workspaceDestinationProvider),
      WorkspaceDestination.home,
    );
    expect(
      container.read(qazaTrackerFilterRequestProvider),
      isNull,
    );
    Navigator.of(tester.element(find.byKey(const Key('home_today_progress'))))
        .pop();
    await tester.pump();

    await tester.tap(find.byKey(const Key('home_complete_oldest_qaza')));
    await tester.pump();
    expect(
      container.read(workspaceDestinationProvider),
      WorkspaceDestination.home,
    );
  });

  testWidgets('Qaza refresh keeps the cached Next Qaza footprint stable',
      (tester) async {
    final record = _pendingRecord(
      id: 'fajr',
      prayer: PrayerType.fajr,
      date: DateTime(2026, 9, 20),
    );
    var refreshing = false;
    final refreshCompleter = Completer<QazaRecord?>();
    final container = await _containerFor(
      selection: const HomePrayerSelectionState(),
      targetRecord: record,
      onDailyProgressRead: () {},
      oldestPendingOverride: () =>
          refreshing ? refreshCompleter.future : Future.value(record),
    );
    addTearDown(container.dispose);

    await _pumpHomeTodayProgress(tester, container, record);
    final before = tester.getSize(
      find.byKey(const Key('home_today_progress')),
    );

    refreshing = true;
    container.invalidate(oldestPendingProvider(record.prayerType));
    await tester.pump();

    final after = tester.getSize(
      find.byKey(const Key('home_today_progress')),
    );
    expect(after.height, closeTo(before.height, 0.1));
    expect(find.byType(HomeNextQazaSkeleton), findsNothing);

    refreshCompleter.complete(record);
    await tester.pumpAndSettle();
  });

  testWidgets(
    'Prayer Selection stale completion shows contextual no-pending message',
    (tester) async {
      final record = _pendingRecord(
        id: 'isha',
        prayer: PrayerType.isha,
        date: DateTime(2026, 9, 23),
      );
      final messages = <String>[];
      final container = await _containerFor(
        selection: const HomePrayerSelectionState(
          mode: HomePrayerSelectionMode.prayerSelection,
          selectedPrayer: PrayerType.isha,
        ),
        targetRecord: record,
        onDailyProgressRead: () {},
        useFixedTargetResolution: true,
        includeActiveUser: true,
        useTestCompletionController: true,
      );
      container.updateOverrides(
        [
          appSnackbarServiceProvider.overrideWithValue(
            _RecordingSnackbarService(messages),
          ),
        ],
      );
      addTearDown(container.dispose);

      await _pumpHomeTodayProgress(tester, container, record);

      await tester.tap(find.byKey(const Key('home_complete_oldest_qaza')));
      await tester.pumpAndSettle();

      expect(
        messages,
        contains('Isha has no pending Qaza. Select another prayer.'),
      );
      expect(
        messages,
        isNot(contains('No pending Qaza for this prayer.')),
      );
    },
  );

  testWidgets('daily progress loading never hides Next Qaza', (tester) async {
    final record = _pendingRecord(
      id: 'fajr',
      prayer: PrayerType.fajr,
      date: DateTime(2026, 9, 20),
    );
    final loading = Completer<HomeDailyProgress>();
    var dailyReads = 0;
    final container = await _containerFor(
      selection: const HomePrayerSelectionState(),
      targetRecord: record,
      onDailyProgressRead: () => dailyReads++,
      dailyProgress: () => loading.future,
      useFixedTargetResolution: true,
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Scaffold(
            body: HomeTodayProgress(summary: _summaryFor(record)),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(HomeTodayProgressSkeleton), findsOneWidget);
    expect(find.byType(SkeletonCircle), findsNothing);
    expect(find.byKey(const Key('home_complete_oldest_qaza')), findsOneWidget);
    expect(dailyReads, 1);

    loading.complete(const HomeDailyProgress(completed: 2, target: 5));
  });

  testWidgets('daily progress error never hides or disables Next Qaza',
      (tester) async {
    final record = _pendingRecord(
      id: 'fajr',
      prayer: PrayerType.fajr,
      date: DateTime(2026, 9, 20),
    );
    var dailyReads = 0;
    final container = await _containerFor(
      selection: const HomePrayerSelectionState(),
      targetRecord: record,
      onDailyProgressRead: () => dailyReads++,
      dailyProgress: () async => throw StateError('daily progress failed'),
    );
    addTearDown(container.dispose);

    await _pumpHomeTodayProgress(tester, container, record);

    expect(find.byKey(const Key('home_daily_progress_retry')), findsOneWidget);
    final complete = tester.widget<FilledButton>(
      find.byKey(const Key('home_complete_oldest_qaza')),
    );
    expect(complete.onPressed, isNotNull);
    expect(dailyReads, 1);
  });
}
