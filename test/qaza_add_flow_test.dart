import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/test_app.dart';

import 'package:qaza_namaz/app/providers.dart';
import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';
import 'package:qaza_namaz/features/calendar/calendar_controller.dart';
import 'package:qaza_namaz/features/qaza/add_qaza_screen.dart';
import 'support/in_memory_qaza_repository.dart';

void main() {
  final today = DateTime(2026, 9, 14);
  late InMemoryQazaRepository repository;

  Future<void> pumpFlow(WidgetTester tester,
      {InMemoryQazaRepository? existing}) async {
    // Destroy any previous tree first so re-pumping never reuses a disposed
    // Navigator or stale element state between flows.
    await tester.pumpWidget(const SizedBox.shrink());
    repository = existing ?? InMemoryQazaRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          qazaRepositoryProvider.overrideWithValue(repository),
          activeUserIdProvider.overrideWithValue('test-user'),
          calendarTodayProvider.overrideWithValue(today),
        ],
        child: const TestApp(home: AddQazaScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    for (var attempt = 0;
        attempt < 10 && finder.evaluate().isEmpty;
        attempt++) {
      await tester.drag(find.byType(Scrollable).last, const Offset(0, -400));
      await tester.pumpAndSettle();
    }
    expect(finder, findsWidgets);
    await tester.ensureVisible(finder.first);
    await tester.pumpAndSettle();
  }

  String dayKey(DateTime date) =>
      'calendar_day_${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Future<void> tapDay(WidgetTester tester, DateTime date) async {
    await scrollTo(tester, find.byKey(Key(dayKey(date)), skipOffstage: false));
    await tester.tap(find.byKey(Key(dayKey(date))));
    await tester.pumpAndSettle();
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    await scrollTo(tester, find.text(text, skipOffstage: false));
    await tester.tap(find.text(text).last);
    await tester.pumpAndSettle();
  }

  /// Scrolls the current step list back to the top so top-of-list content is
  /// rebuilt and visible for assertions.
  Future<void> resetScroll(WidgetTester tester) async {
    await tester.drag(find.byType(Scrollable).last, const Offset(0, 4000));
    await tester.pumpAndSettle();
  }

  Future<void> continueToPrayers(WidgetTester tester) async {
    await scrollTo(tester,
        find.byKey(const Key('qaza_continue_button'), skipOffstage: false));
    await tester.tap(find.byKey(const Key('qaza_continue_button')));
    await tester.pumpAndSettle();
  }

  Future<void> continueToReview(WidgetTester tester) async {
    await scrollTo(tester,
        find.byKey(const Key('qaza_review_button'), skipOffstage: false));
    await tester.tap(find.byKey(const Key('qaza_review_button')));
    await tester.pumpAndSettle();
  }

  Future<void> confirmAdd(WidgetTester tester) async {
    await scrollTo(
        tester, find.byKey(const Key('qaza_add_button'), skipOffstage: false));
    await tester.tap(find.byKey(const Key('qaza_add_button')));
    await tester.pumpAndSettle();
    await scrollTo(tester, find.text('Done', skipOffstage: false));
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'Step 1 contains the mode selector and calendar together (no separate date-selection screen)',
      (tester) async {
    await pumpFlow(tester);
    expect(find.text('Step 1 of 3 • Select Dates'), findsOneWidget);
    expect(find.text('Add Qaza'), findsNWidgets(2)); // AppBar title + heading
    expect(find.textContaining('Range Setup'), findsNothing);
    expect(find.text('Step 2 of 3 • Date Selection'), findsNothing);
    expect(find.byKey(const Key('qaza_date_mode_selector')), findsOneWidget);
    expect(find.byKey(const Key('qaza_calendar_picker')), findsOneWidget);
    expect(find.byKey(const Key('calendar_month_header')), findsOneWidget);
    expect(find.byKey(const Key('calendar_hijri_month_label')), findsOneWidget);
    expect(find.text('Single'), findsOneWidget);
    expect(find.text('Range'), findsOneWidget);
    expect(find.text('Multiple'), findsOneWidget);
  });

  testWidgets('Continue requires a selected date and Step 2 receives the dates',
      (tester) async {
    await pumpFlow(tester);
    await scrollTo(tester,
        find.byKey(const Key('qaza_continue_button'), skipOffstage: false));
    await tester.tap(find.byKey(const Key('qaza_continue_button')));
    await tester.pumpAndSettle();
    await resetScroll(tester);
    expect(find.text('Step 1 of 3 • Select Dates'), findsOneWidget);

    await tapDay(tester, DateTime(2026, 9, 13));
    await continueToPrayers(tester);
    expect(find.text('Step 2 of 3 • Select Missed Prayers'), findsOneWidget);
    expect(find.textContaining('1 day selected'), findsOneWidget);
    for (final prayer in PrayerType.values) {
      await scrollTo(tester,
          find.byKey(Key('qaza_prayer_${prayer.name}'), skipOffstage: false));
      expect(find.byKey(Key('qaza_prayer_${prayer.name}')), findsOneWidget);
    }
  });

  testWidgets('Switching date modes preserves still-valid selected dates',
      (tester) async {
    await pumpFlow(tester);
    await tapDay(tester, DateTime(2026, 9, 13));
    await tapText(tester, 'Range');
    expect(find.byKey(const Key('calendar_selected_summary')), findsOneWidget);
    expect(find.textContaining('1 date selected'), findsOneWidget);

    // The preserved anchor restarts when an earlier date is tapped, then the
    // range completes and expands for storage.
    await tapDay(tester, DateTime(2026, 9, 10));
    await tapDay(tester, DateTime(2026, 9, 13));
    expect(find.textContaining('2 dates selected'), findsOneWidget);
    await continueToPrayers(tester);
    expect(find.textContaining('4 days selected'), findsOneWidget);
  });

  testWidgets('Select All excludes prayers unavailable on every selected date',
      (tester) async {
    await pumpFlow(tester);
    await repository.addRecord(QazaRecord(
      id: 'test-user_fajr_2026-09-13',
      userId: 'test-user',
      prayerType: PrayerType.fajr,
      originalDate: DateTime(2026, 9, 13),
      createdAt: today,
      updatedAt: today,
    ));
    await tapDay(tester, DateTime(2026, 9, 13));
    await continueToPrayers(tester);

    final fajrTile = tester.widget<CheckboxListTile>(
      find.byKey(const Key('qaza_prayer_fajr')),
    );
    expect(fajrTile.onChanged, isNull);

    await scrollTo(tester,
        find.byKey(const Key('qaza_select_all_button'), skipOffstage: false));
    await tester.tap(find.byKey(const Key('qaza_select_all_button')));
    await tester.pumpAndSettle();

    await scrollTo(
        tester, find.byKey(const Key('qaza_prayer_fajr'), skipOffstage: false));
    expect(
      tester
          .widget<CheckboxListTile>(find.byKey(const Key('qaza_prayer_fajr')))
          .value,
      isFalse,
    );
    await scrollTo(
        tester, find.byKey(const Key('qaza_prayer_witr'), skipOffstage: false));
    expect(
      tester
          .widget<CheckboxListTile>(find.byKey(const Key('qaza_prayer_witr')))
          .value,
      isTrue,
    );
  });

  testWidgets('Step 3 review previews counts and Add Qaza creates the records',
      (tester) async {
    await pumpFlow(tester);
    await tapDay(tester, DateTime(2026, 9, 13));
    await continueToPrayers(tester);
    await tapText(tester, 'Asr');
    await continueToReview(tester);
    expect(find.text('Step 3 of 3 • Review & Add'), findsOneWidget);
    expect(find.text('New Qaza records'), findsOneWidget);
    expect(find.text('1'), findsWidgets);

    await confirmAdd(tester);
    final records = await repository.getRecords(userId: 'test-user');
    expect(records, hasLength(1));
    expect(records.single.prayerType, PrayerType.asr);
    expect(records.single.status, QazaStatus.pending);
    expect(records.single.completedAt, isNull);
    expect(
      [
        records.single.originalDate.year,
        records.single.originalDate.month,
        records.single.originalDate.day
      ],
      [2026, 9, 13],
    );
  });

  testWidgets(
      'Replaying a recorded combination is unavailable while new combinations still work',
      (tester) async {
    await pumpFlow(tester);
    await tapDay(tester, DateTime(2026, 9, 13));
    await continueToPrayers(tester);
    await tapText(tester, 'Asr');
    await continueToReview(tester);
    await confirmAdd(tester);
    expect(await repository.getRecords(userId: 'test-user'), hasLength(1));

    // Replay against the same ledger: the recorded combination is unavailable
    // per date + prayer, so its tile is disabled and cannot be selected again.
    await pumpFlow(tester, existing: repository);
    await tapDay(tester, DateTime(2026, 9, 13));
    await continueToPrayers(tester);
    final asrTile = tester.widget<CheckboxListTile>(
      find.byKey(const Key('qaza_prayer_asr')),
    );
    expect(asrTile.onChanged, isNull);
    expect(
      find.textContaining('Already recorded or prayed on every selected date'),
      findsOneWidget,
    );

    // A different prayer on the same date remains fully eligible.
    await tapText(tester, 'Maghrib');
    await continueToReview(tester);
    expect(find.text('New Qaza records'), findsOneWidget);
    expect(find.text('1'), findsWidgets);
    await confirmAdd(tester);

    final records = await repository.getRecords(userId: 'test-user');
    expect(records, hasLength(2));
    expect(
      records.map((record) => record.prayerType),
      containsAll([PrayerType.asr, PrayerType.maghrib]),
    );
  });

  testWidgets(
      'Back navigation preserves dates and prayers across every transition',
      (tester) async {
    await pumpFlow(tester);
    await tapDay(tester, DateTime(2026, 9, 13));
    await continueToPrayers(tester);
    await tapText(tester, 'Asr');
    await continueToReview(tester);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.text('Step 2 of 3 • Select Missed Prayers'), findsOneWidget);
    await scrollTo(
        tester, find.byKey(const Key('qaza_prayer_asr'), skipOffstage: false));
    expect(
      tester
          .widget<CheckboxListTile>(find.byKey(const Key('qaza_prayer_asr')))
          .value,
      isTrue,
    );

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.text('Step 1 of 3 • Select Dates'), findsOneWidget);
    expect(find.textContaining('1 date selected'), findsOneWidget);
    await scrollTo(
        tester,
        find.byKey(const Key('calendar_selected_summary'),
            skipOffstage: false));
    expect(find.byKey(const Key('calendar_selected_summary')), findsOneWidget);
  });

  testWidgets('System Back preserves dates and prayers through all three steps',
      (tester) async {
    await pumpFlow(tester);
    await tapDay(tester, DateTime(2026, 9, 13));
    await continueToPrayers(tester);
    await tapText(tester, 'Asr');
    await continueToReview(tester);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Step 2 of 3 • Select Missed Prayers'), findsOneWidget);
    expect(
      tester
          .widget<CheckboxListTile>(find.byKey(const Key('qaza_prayer_asr')))
          .value,
      isTrue,
    );

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Step 1 of 3 • Select Dates'), findsOneWidget);
    expect(find.textContaining('1 date selected'), findsOneWidget);

    await continueToPrayers(tester);
    await continueToReview(tester);
    expect(find.text('Step 3 of 3 • Review & Add'), findsOneWidget);
    expect(await repository.getRecords(userId: 'test-user'), isEmpty);
  });

  testWidgets(
      'Range flow creates one independent record per date x prayer including Witr',
      (tester) async {
    await pumpFlow(tester);
    await tapText(tester, 'Range');
    await tapDay(tester, DateTime(2026, 9, 10));
    await tapDay(tester, DateTime(2026, 9, 13));
    await continueToPrayers(tester);
    expect(find.textContaining('4 days selected'), findsOneWidget);
    await scrollTo(tester,
        find.byKey(const Key('qaza_select_all_button'), skipOffstage: false));
    await tester.tap(find.byKey(const Key('qaza_select_all_button')));
    await tester.pumpAndSettle();
    await continueToReview(tester);
    expect(find.text('24'), findsOneWidget); // 4 days x 6 prayers

    await confirmAdd(tester);
    final records = await repository.getRecords(userId: 'test-user');
    expect(records, hasLength(24));
    final witr = records
        .where((record) => record.prayerType == PrayerType.witr)
        .toList();
    expect(witr, hasLength(4));
    expect(witr.every((record) => record.status == QazaStatus.pending), isTrue);
    expect(
      records.map((record) => record.originalDate).toSet().length,
      4,
    );
  });
}
