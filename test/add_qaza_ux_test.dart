import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/app/providers.dart';
import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';
import 'package:qaza_namaz/domain/repositories/qaza_repository.dart';
import 'package:qaza_namaz/features/calendar/calendar_controller.dart';
import 'package:qaza_namaz/features/qaza/add_qaza_screen.dart';

import 'support/in_memory_qaza_repository.dart';
import 'support/test_app.dart';

/// Holds every read open until released, to catch the screen mid-check.
class _GatedRepository extends InMemoryQazaRepository {
  Completer<void>? readGate;

  @override
  Future<QazaHistoryPage> getHistoryPage({
    required String userId,
    int limit = 50,
    PrayerType? prayerType,
    QazaStatus? status,
    DateTime? from,
    DateTime? to,
    DateTime? beforeOriginalDate,
    String? beforeId,
  }) async {
    final gate = readGate;
    if (gate != null) await gate.future;
    return super.getHistoryPage(
      userId: userId,
      limit: limit,
      prayerType: prayerType,
      status: status,
      from: from,
      to: to,
      beforeOriginalDate: beforeOriginalDate,
      beforeId: beforeId,
    );
  }
}

/// What the three Add Qaza steps offer, and what they refuse.
void main() {
  final today = DateTime(2026, 9, 14);
  late InMemoryQazaRepository repository;

  Future<void> pumpFlow(WidgetTester tester,
      {InMemoryQazaRepository? existing, bool settle = true}) async {
    await tester.pumpWidget(const SizedBox.shrink());
    repository = existing ?? InMemoryQazaRepository();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        qazaRepositoryProvider.overrideWithValue(repository),
        activeUserIdProvider.overrideWithValue('test-user'),
        calendarTodayProvider.overrideWithValue(today),
      ],
      child: const TestApp(home: AddQazaScreen()),
    ));
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      // A running progress indicator never settles; pump it by hand.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }
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

  Future<void> tapKey(WidgetTester tester, String key) async {
    await scrollTo(tester, find.byKey(Key(key), skipOffstage: false));
    await tester.tap(find.byKey(Key(key)));
    await tester.pumpAndSettle();
  }

  String dayKey(DateTime date) => 'calendar_day_'
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  Future<void> tapDay(WidgetTester tester, DateTime date) =>
      tapKey(tester, dayKey(date));

  Future<void> tapText(WidgetTester tester, String text) async {
    await scrollTo(tester, find.text(text, skipOffstage: false));
    await tester.tap(find.text(text).last);
    await tester.pumpAndSettle();
  }

  Future<void> record(
      InMemoryQazaRepository into, PrayerType prayer, DateTime date) {
    final ymd = '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    return into.addRecord(QazaRecord(
      id: 'test-user_${prayer.name}_$ymd',
      userId: 'test-user',
      prayerType: prayer,
      originalDate: date,
      createdAt: today,
      updatedAt: today,
    ));
  }

  /// Scrolls without waiting for the tree to go still, for the moments when
  /// a progress indicator is running and never will.
  Future<T> busyWidgetOf<T extends Widget>(
      WidgetTester tester, String key) async {
    final finder = find.byKey(Key(key), skipOffstage: false);
    for (var attempt = 0;
        attempt < 12 && finder.evaluate().isEmpty;
        attempt++) {
      await tester.drag(find.byType(Scrollable).last, const Offset(0, -400));
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(finder, findsWidgets);
    return tester.widget<T>(finder.first);
  }

  /// The widget behind [key], brought into view first.
  Future<T> widgetOf<T extends Widget>(WidgetTester tester, String key) async {
    await scrollTo(tester, find.byKey(Key(key), skipOffstage: false));
    return tester.widget<T>(find.byKey(Key(key)));
  }

  String subtitleOf(WidgetTester tester, PrayerType prayer) => tester
      .widget<Text>(find.byKey(Key('qaza_prayer_subtitle_${prayer.name}')))
      .data!;

  group('Step 1 — dates', () {
    testWidgets('a day cannot be chosen while its month is still loading',
        (tester) async {
      final gated = _GatedRepository()..readGate = Completer<void>();
      await pumpFlow(tester, existing: gated, settle: false);

      final key = dayKey(DateTime(2026, 9, 13));
      expect((await busyWidgetOf<InkWell>(tester, key)).onTap, isNull,
          reason: 'availability is not known yet');
      expect(find.byType(LinearProgressIndicator), findsWidgets);

      gated.readGate!.complete();
      await tester.pumpAndSettle();

      expect((await widgetOf<InkWell>(tester, key)).onTap, isNotNull);
    });

    testWidgets('Continue waits for a date', (tester) async {
      await pumpFlow(tester);

      expect(
        (await widgetOf<FilledButton>(tester, 'qaza_continue_button'))
            .onPressed,
        isNull,
      );

      await tapDay(tester, DateTime(2026, 9, 13));
      expect(
        (await widgetOf<FilledButton>(tester, 'qaza_continue_button'))
            .onPressed,
        isNotNull,
      );
    });
  });

  group('Step 2 — prayers', () {
    testWidgets('partial availability is spelled out per prayer',
        (tester) async {
      final ledger = InMemoryQazaRepository();
      await record(ledger, PrayerType.fajr, DateTime(2026, 9, 13));
      await pumpFlow(tester, existing: ledger);

      await tapText(tester, 'Multiple');
      await tapDay(tester, DateTime(2026, 9, 12));
      await tapDay(tester, DateTime(2026, 9, 13));
      await tapKey(tester, 'qaza_continue_button');

      await scrollTo(
          tester,
          find.byKey(const Key('qaza_prayer_subtitle_fajr'),
              skipOffstage: false));
      expect(subtitleOf(tester, PrayerType.fajr),
          contains('Available on 1 of 2 dates'));
      // A prayer available everywhere says nothing extra.
      expect(
          subtitleOf(tester, PrayerType.asr), isNot(contains('Available on')));
      // And it is still selectable, because one date remains eligible.
      expect(
        (await widgetOf<CheckboxListTile>(tester, 'qaza_prayer_fajr'))
            .onChanged,
        isNotNull,
      );
    });

    testWidgets('the eligibility rule is stated on the step', (tester) async {
      await pumpFlow(tester);
      await tapDay(tester, DateTime(2026, 9, 13));
      await tapKey(tester, 'qaza_continue_button');

      expect(
        find.textContaining('Only eligible date + prayer combinations'),
        findsOneWidget,
      );
    });

    testWidgets('the step carries Back and Review', (tester) async {
      await pumpFlow(tester);
      await tapDay(tester, DateTime(2026, 9, 13));
      await tapKey(tester, 'qaza_continue_button');

      expect(
        (await widgetOf<FilledButton>(tester, 'qaza_review_button')).onPressed,
        isNull,
        reason: 'no prayer is selected yet',
      );
      expect(find.byKey(const Key('qaza_back_button')), findsOneWidget);

      await tapText(tester, 'Asr');
      expect(
        (await widgetOf<FilledButton>(tester, 'qaza_review_button')).onPressed,
        isNotNull,
      );

      await tapKey(tester, 'qaza_back_button');
      expect(find.text('Step 1 of 3 • Select Dates'), findsOneWidget);
      // The selection survived the trip.
      expect(find.textContaining('1 date selected'), findsOneWidget);
    });

    testWidgets('live counts follow the selection', (tester) async {
      final ledger = InMemoryQazaRepository();
      await record(ledger, PrayerType.fajr, DateTime(2026, 9, 13));
      await pumpFlow(tester, existing: ledger);

      await tapDay(tester, DateTime(2026, 9, 13));
      await tapKey(tester, 'qaza_continue_button');
      await tapKey(tester, 'qaza_select_all_button');

      await scrollTo(tester,
          find.byKey(const Key('qaza_review_button'), skipOffstage: false));
      expect(find.text('New records'), findsOneWidget);
      // Fajr is excluded by Select All, so five of the six are new.
      expect(find.text('5'), findsWidgets);
    });
  });

  group('Step 3 — review', () {
    Future<void> reachReview(WidgetTester tester) async {
      await tapDay(tester, DateTime(2026, 9, 13));
      await tapKey(tester, 'qaza_continue_button');
      await tapText(tester, 'Asr');
      await tapText(tester, 'Maghrib');
      await tapKey(tester, 'qaza_review_button');
    }

    testWidgets('the action names the count it will add', (tester) async {
      await pumpFlow(tester);
      await reachReview(tester);

      await scrollTo(tester,
          find.byKey(const Key('qaza_add_button'), skipOffstage: false));
      expect(
        tester
            .widget<Text>(find.descendant(
              of: find.byKey(const Key('qaza_add_button')),
              matching: find.byType(Text),
            ))
            .data,
        'Add 2 Qaza',
      );
      expect(find.byKey(const Key('qaza_back_button')), findsOneWidget);
    });

    testWidgets('Add is refused when there is nothing new', (tester) async {
      final ledger = InMemoryQazaRepository();
      await record(ledger, PrayerType.asr, DateTime(2026, 9, 13));
      await pumpFlow(tester, existing: ledger);

      await tapDay(tester, DateTime(2026, 9, 13));
      await tapKey(tester, 'qaza_continue_button');
      // Asr is already recorded on the only date, so it cannot be chosen;
      // pick it through nothing and the review step stays shut.
      expect(
        (await widgetOf<CheckboxListTile>(tester, 'qaza_prayer_asr')).onChanged,
        isNull,
      );
      expect(
        (await widgetOf<FilledButton>(tester, 'qaza_review_button')).onPressed,
        isNull,
      );
    });

    testWidgets('the success message counts what was actually written',
        (tester) async {
      await pumpFlow(tester);
      await reachReview(tester);

      // One of the two is recorded elsewhere between the preview and the tap.
      await record(repository, PrayerType.asr, DateTime(2026, 9, 13));

      await tapKey(tester, 'qaza_add_button');
      expect(find.text('Qaza records created'), findsOneWidget);
      expect(find.textContaining('1 record was added'), findsOneWidget);

      await tapText(tester, 'Done');
      expect(await repository.getRecords(userId: 'test-user'), hasLength(2));
    });

    testWidgets('a save that finds nothing new says so', (tester) async {
      await pumpFlow(tester);
      await reachReview(tester);

      await record(repository, PrayerType.asr, DateTime(2026, 9, 13));
      await record(repository, PrayerType.maghrib, DateTime(2026, 9, 13));

      await tapKey(tester, 'qaza_add_button');

      expect(find.text('Qaza records created'), findsNothing);
      expect(find.textContaining('Nothing new to add'), findsOneWidget);
      expect(await repository.getRecords(userId: 'test-user'), hasLength(2));
    });
  });

  group('the step indicator', () {
    testWidgets('offers only the steps that are ready', (tester) async {
      await pumpFlow(tester);

      expect(
          (await widgetOf<InkWell>(tester, 'qaza_step_tab_1')).onTap, isNull);
      expect(
          (await widgetOf<InkWell>(tester, 'qaza_step_tab_2')).onTap, isNull);

      await tapDay(tester, DateTime(2026, 9, 13));
      await tester.pumpAndSettle();
      expect((await widgetOf<InkWell>(tester, 'qaza_step_tab_1')).onTap,
          isNotNull);
      expect((await widgetOf<InkWell>(tester, 'qaza_step_tab_2')).onTap, isNull,
          reason: 'no prayers chosen yet');

      await tapKey(tester, 'qaza_step_tab_1');
      expect(find.text('Step 2 of 3 • Select Missed Prayers'), findsOneWidget);

      await tapText(tester, 'Asr');
      await tapKey(tester, 'qaza_step_tab_2');
      expect(find.text('Step 3 of 3 • Review & Add'), findsOneWidget);

      // And back again, with the selection intact.
      await tapKey(tester, 'qaza_step_tab_0');
      expect(find.text('Step 1 of 3 • Select Dates'), findsOneWidget);
      expect(find.textContaining('1 date selected'), findsOneWidget);
    });
  });
}
