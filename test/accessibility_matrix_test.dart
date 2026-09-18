import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/app/providers.dart';
import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/domain/entities/app_user.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';
import 'package:qaza_namaz/features/qaza/qaza_tracker_screen.dart';
import 'package:qaza_namaz/l10n/app_localizations_en.dart';
import 'package:qaza_namaz/l10n/app_localizations_ur.dart';
import 'support/in_memory_qaza_repository.dart';
import 'support/test_app.dart';

/// The accessibility rows of the V2 plan: semantic labels, touch targets,
/// readable text scaling, clear disabled states and screen-reader
/// descriptions.
///
/// Knowledge Base semantics and large-text rendering are covered separately in
/// `test/knowledge_base/knowledge_base_accessibility_test.dart`.
const _user = AppUser(id: 'test-user', email: 'test@example.com');

QazaRecord _record(
  PrayerType prayer,
  DateTime date, {
  QazaStatus status = QazaStatus.pending,
}) {
  final stamp = DateTime(2026, 1, 1);
  return QazaRecord(
    id: 'test-user_${prayer.name}_${date.year}-${date.month}-${date.day}',
    userId: 'test-user',
    prayerType: prayer,
    originalDate: date,
    status: status,
    completedAt: status == QazaStatus.completed ? stamp : null,
    createdAt: stamp,
    updatedAt: stamp,
  );
}

Future<void> _pumpTracker(
  WidgetTester tester,
  InMemoryQazaRepository repository, {
  Locale locale = const Locale('en'),
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = const Size(900, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        qazaRepositoryProvider.overrideWithValue(repository),
        activeUserIdProvider.overrideWithValue('test-user'),
        authStateProvider.overrideWith((ref) => Stream.value(_user)),
      ],
      child: TestApp(
        locale: locale,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const QazaTrackerScreen(),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump();
}

void main() {
  group('semantic labels', () {
    testWidgets('a ledger row announces date, prayer and status',
        (tester) async {
      final repository = InMemoryQazaRepository();
      await repository.addRecords([
        _record(PrayerType.fajr, DateTime(2025, 3, 4)),
      ]);
      await _pumpTracker(tester, repository);

      final handle = tester.ensureSemantics();
      final en = AppLocalizationsEn();
      final matching = find.bySemanticsLabel(
        RegExp('04 Mar 2025.*${en.prayerFajr}.*${en.statusPending}'),
      );
      expect(matching, findsOneWidget,
          reason: 'a screen reader must get the whole row, not just a date');
      handle.dispose();
    });

    testWidgets('row semantics follow the selected language', (tester) async {
      final repository = InMemoryQazaRepository();
      await repository.addRecords([
        _record(PrayerType.witr, DateTime(2025, 3, 4)),
      ]);
      await _pumpTracker(tester, repository, locale: const Locale('ur'));

      final handle = tester.ensureSemantics();
      final ur = AppLocalizationsUr();
      expect(
        find.bySemanticsLabel(RegExp(ur.prayerWitr)),
        findsWidgets,
        reason: 'screen-reader text must be localized, not only visible text',
      );
      expect(
        find.bySemanticsLabel(RegExp(AppLocalizationsEn().prayerWitr)),
        findsNothing,
        reason: 'the English name must not leak into Urdu semantics',
      );
      handle.dispose();
    });

    testWidgets('a completed row announces its completed status',
        (tester) async {
      final repository = InMemoryQazaRepository();
      await repository.addRecords([
        _record(PrayerType.asr, DateTime(2025, 3, 5),
            status: QazaStatus.completed),
      ]);
      await _pumpTracker(tester, repository);

      final controller = tester
          .element(find.byType(QazaTrackerScreen))
          .findAncestorWidgetOfExactType<ProviderScope>();
      expect(controller, isNotNull);

      final handle = tester.ensureSemantics();
      expect(
        find.bySemanticsLabel(RegExp(AppLocalizationsEn().statusCompleted)),
        findsWidgets,
      );
      handle.dispose();
    });
  });

  group('touch targets', () {
    testWidgets('interactive controls meet the 48dp minimum', (tester) async {
      final repository = InMemoryQazaRepository();
      await repository.addRecords([
        _record(PrayerType.fajr, DateTime(2025, 3, 4)),
      ]);
      await _pumpTracker(tester, repository);

      // Adding moved to the workspace action button, so the header carries
      // no actions of its own; the record checkbox is what remains here.
      for (final finder in <Finder>[
        find.byType(Checkbox).first,
      ]) {
        final size = tester.getSize(finder);
        expect(size.width, greaterThanOrEqualTo(48.0),
            reason: 'width of ${finder.description}');
        expect(size.height, greaterThanOrEqualTo(48.0),
            reason: 'height of ${finder.description}');
      }
    });

    testWidgets('the selection checkbox is reachable at a comfortable size',
        (tester) async {
      final repository = InMemoryQazaRepository();
      await repository.addRecords([
        _record(PrayerType.fajr, DateTime(2025, 3, 4)),
      ]);
      await _pumpTracker(tester, repository);

      final checkbox = find.byType(Checkbox).first;
      final size = tester.getSize(checkbox);
      expect(size.width, greaterThanOrEqualTo(40.0));
      expect(size.height, greaterThanOrEqualTo(40.0));
    });
  });

  group('text scaling', () {
    for (final scale in [1.3, 2.0]) {
      testWidgets('the Qaza workspace renders at ${scale}x text scale',
          (tester) async {
        final repository = InMemoryQazaRepository();
        await repository.addRecords([
          for (var day = 1; day <= 6; day++)
            _record(PrayerType.values[day % PrayerType.values.length],
                DateTime(2025, 3, day)),
        ]);
        await _pumpTracker(tester, repository, textScale: scale);

        expect(tester.takeException(), isNull,
            reason: 'large text must not overflow or throw');
        expect(find.byKey(const Key('qaza_tracker_list')), findsOneWidget);
      });
    }

    testWidgets('the empty state survives a large text scale', (tester) async {
      await _pumpTracker(tester, InMemoryQazaRepository(), textScale: 2.0);
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('qaza_tracker_empty')), findsOneWidget);
    });
  });

  group('disabled states', () {
    testWidgets('a completed record offers no selection control',
        (tester) async {
      final repository = InMemoryQazaRepository();
      await repository.addRecords([
        _record(PrayerType.asr, DateTime(2025, 3, 5),
            status: QazaStatus.completed),
      ]);
      await _pumpTracker(tester, repository);

      // Default filter is pending, so switch to All to see the completed row.
      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('qaza_tracker_status_filter')),
          matching: find.text(AppLocalizationsEn().filterAll),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      expect(find.byType(Checkbox), findsNothing,
          reason: 'only pending records are selectable');
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget,
          reason: 'a completed row states its state instead');
    });

    testWidgets('the bulk action appears only once something is selected',
        (tester) async {
      final repository = InMemoryQazaRepository();
      await repository.addRecords([
        _record(PrayerType.fajr, DateTime(2025, 3, 4)),
      ]);
      await _pumpTracker(tester, repository);

      expect(find.byKey(const Key('qaza_tracker_complete_selected')),
          findsNothing);
      await tester.tap(find.byType(Checkbox).first);
      await tester.pump();
      expect(find.byKey(const Key('qaza_tracker_complete_selected')),
          findsOneWidget);
    });
  });
}
