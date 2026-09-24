import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/app/providers.dart';
import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/core/diagnostics/diagnostics.dart';
import 'package:qaza_namaz/core/theme/app_theme.dart';
import 'package:qaza_namaz/domain/entities/app_user.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';
import 'package:qaza_namaz/domain/services/qaza_undo_service.dart';
import 'package:qaza_namaz/features/home/home_controller.dart';
import 'package:qaza_namaz/features/home/home_screen.dart';
import 'package:qaza_namaz/features/home/home_state.dart';
import 'package:qaza_namaz/features/home/providers/home_providers.dart';

import 'support/complete_qaza_host.dart';
import 'support/in_memory_qaza_repository.dart';
import 'support/test_app.dart';

/// What Home does after the record has actually been saved.
///
/// The bug this covers: everything from the local write through the refresh,
/// the haptic and the undo snackbar sat inside one try/catch, so a failure in
/// any of the optional steps was reported as "Qaza could not be completed"
/// even though the Qaza had been completed. Only a persistence failure may
/// show that message.
const _failureMessage = 'Qaza could not be completed. Please try again.';

final _stamp = DateTime(2026, 9, 22);

QazaRecord _record(String id, PrayerType prayer, int day, QazaStatus status) =>
    QazaRecord(
      id: id,
      userId: 'u1',
      prayerType: prayer,
      originalDate: DateTime(2026, 1, day),
      status: status,
      completedAt: status == QazaStatus.completed ? _stamp : null,
      createdAt: _stamp,
      updatedAt: _stamp,
    );

class _TestHomeCurrentPrayerNotifier extends HomeCurrentPrayerNotifier {
  @override
  HomeCurrentPrayerState build() =>
      const HomeCurrentPrayerState(prayer: PrayerType.fajr);
}

/// A dashboard refresh that blows up after the completion is durable.
class _BrokenHomeController extends HomeController {
  const _BrokenHomeController(super.ref);

  @override
  void afterCompletion({required int pendingBefore}) =>
      throw StateError('dashboard refresh failed');
}

/// Undo registration that fails after the completion is durable.
class _BrokenUndoManager extends QazaUndoManager {
  @override
  Future<QazaUndoBatch?> register({
    required String userId,
    required Iterable<QazaRecord> records,
  }) async =>
      throw StateError('undo registration failed');
}

void main() {
  late BufferedDiagnostics diagnostics;

  setUp(() => diagnostics = BufferedDiagnostics(capacity: 100));

  Future<InMemoryQazaRepository> ledger() async {
    final repository = InMemoryQazaRepository();
    await repository.addRecords([
      _record('f1', PrayerType.fajr, 1, QazaStatus.pending),
      _record('f2', PrayerType.fajr, 2, QazaStatus.pending),
      _record('z1', PrayerType.zuhr, 4, QazaStatus.pending),
    ]);
    return repository;
  }

  Future<ProviderContainer> pumpHome(
    WidgetTester tester,
    InMemoryQazaRepository repository, {
    List<Override> overrides = const [],
  }) async {
    tester.view.physicalSize = const Size(900, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    final container = ProviderContainer(overrides: [
      qazaRepositoryProvider.overrideWithValue(repository),
      activeUserIdProvider.overrideWithValue('u1'),
      diagnosticsProvider.overrideWithValue(diagnostics),
      authStateProvider.overrideWith(
        (ref) => Stream.value(const AppUser(id: 'u1', email: 'u1@e.com')),
      ),
      homeCurrentPrayerProvider.overrideWith(
        _TestHomeCurrentPrayerNotifier.new,
      ),
      ...overrides,
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: TestApp(
        theme: AppTheme.light(locale: const Locale('en')),
        locale: const Locale('en'),
        home: const HomeScreen(),
      ),
    ));
    await tester.pumpAndSettle();
    return container;
  }

  Future<void> tapComplete(WidgetTester tester) async {
    final button = find.byKey(const Key('home_complete_oldest_qaza'));
    expect(button, findsOneWidget);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  List<String> codes() => diagnostics.events.map((e) => e.code).toList();

  testWidgets('a completion that works shows no error and moves on',
      (tester) async {
    final repository = await ledger();
    await pumpHome(tester, repository);

    await tapComplete(tester);

    expect(find.text(_failureMessage), findsNothing);
    expect(find.text('Fajr Qaza for 01 Jan 2026 completed.'), findsOneWidget);
    final summary = await repository.getProgressSummary(userId: 'u1');
    expect(summary.overall.completed, 1);
    expect(summary.overall.pending, 2);
    expect(codes(), contains('completion_start'));
    expect(codes(), contains('completion_succeeded'));

    // The next pending Qaza has taken its place.
    final next = await repository.getOldestPending(
      userId: 'u1',
      prayerType: PrayerType.fajr,
    );
    expect(next!.id, 'f2');
    expect(find.byKey(const Key('home_oldest_qaza_date')), findsOneWidget);
  });

  testWidgets('a dashboard refresh failure is not a completion failure',
      (tester) async {
    final repository = await ledger();
    await pumpHome(tester, repository, overrides: [
      homeControllerProvider.overrideWith(_BrokenHomeController.new),
    ]);

    await tapComplete(tester);

    expect(find.text(_failureMessage), findsNothing,
        reason: 'the Qaza was saved; the refresh is what failed');
    expect(codes(), contains('completion_succeeded'));
    expect(codes(), contains('post_completion_refresh_failed'));
    final summary = await repository.getProgressSummary(userId: 'u1');
    expect(summary.overall.completed, 1);
  });

  testWidgets('an undo registration failure is not a completion failure',
      (tester) async {
    final repository = await ledger();
    await pumpHome(tester, repository, overrides: [
      qazaUndoManagerProvider.overrideWithValue(_BrokenUndoManager()),
    ]);

    await tapComplete(tester);

    expect(find.text(_failureMessage), findsNothing,
        reason: 'undo is optional recovery UI, not part of completing');
    expect(codes(), contains('completion_succeeded'));
    expect(codes(), contains('undo_ui_failed'));
    final summary = await repository.getProgressSummary(userId: 'u1');
    expect(summary.overall.completed, 1,
        reason: 'the completion stands even though undo could not register');
  });

  testWidgets('a persistence failure is the one case that shows the message',
      (tester) async {
    final repository = await ledger();
    repository.completionFailure = StateError('drift: database is locked');
    await pumpHome(tester, repository);

    await tapComplete(tester);

    expect(find.text(_failureMessage), findsOneWidget);
    expect(codes(), contains('completion_failed'));
    expect(codes(), isNot(contains('completion_succeeded')));
    final summary = await repository.getProgressSummary(userId: 'u1');
    expect(summary.overall.completed, 0);
  });

  /// The Complete Qaza section used to carry its own completion code, with
  /// persistence, refresh, haptics and undo inside a single try/catch. It now
  /// routes through the same controller Home uses, so the same rule holds:
  /// only persistence may produce the failure message.
  group('the deduplicated Complete Qaza section', () {
    Future<ProviderContainer> pumpSection(
      WidgetTester tester,
      InMemoryQazaRepository repository, {
      List<Override> overrides = const [],
    }) async {
      tester.view.physicalSize = const Size(900, 2200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);

      final container = ProviderContainer(overrides: [
        qazaRepositoryProvider.overrideWithValue(repository),
        activeUserIdProvider.overrideWithValue('u1'),
        diagnosticsProvider.overrideWithValue(diagnostics),
        authStateProvider.overrideWith(
          (ref) => Stream.value(const AppUser(id: 'u1', email: 'u1@e.com')),
        ),
        ...overrides,
      ]);
      addTearDown(container.dispose);

      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: TestApp(
          theme: AppTheme.light(locale: const Locale('en')),
          locale: const Locale('en'),
          home: const CompleteQazaHost(),
        ),
      ));
      await tester.pumpAndSettle();
      return container;
    }

    Future<void> tapSectionComplete(WidgetTester tester) async {
      final button = find.byKey(const Key('complete_oldest_pending'));
      expect(button, findsOneWidget);
      await tester.tap(button);
      await tester.pumpAndSettle();
    }

    testWidgets('completes through the shared controller', (tester) async {
      final repository = await ledger();
      await pumpSection(tester, repository);

      await tapSectionComplete(tester);

      expect(find.text(_failureMessage), findsNothing);
      expect(codes(), contains('completion_start'));
      expect(codes(), contains('completion_succeeded'));
      final summary = await repository.getProgressSummary(userId: 'u1');
      expect(summary.overall.completed, 1);
    });

    testWidgets('an undo failure is not reported as a completion failure',
        (tester) async {
      final repository = await ledger();
      await pumpSection(tester, repository, overrides: [
        qazaUndoManagerProvider.overrideWithValue(_BrokenUndoManager()),
      ]);

      await tapSectionComplete(tester);

      expect(find.text(_failureMessage), findsNothing,
          reason: 'the old single try/catch showed this message here');
      expect(codes(), contains('undo_ui_failed'));
      final summary = await repository.getProgressSummary(userId: 'u1');
      expect(summary.overall.completed, 1);
    });

    testWidgets('a persistence failure still shows the message',
        (tester) async {
      final repository = await ledger();
      repository.completionFailure = StateError('drift: database is locked');
      await pumpSection(tester, repository);

      await tapSectionComplete(tester);

      expect(find.text(_failureMessage), findsOneWidget);
      expect(codes(), contains('completion_failed'));
      final summary = await repository.getProgressSummary(userId: 'u1');
      expect(summary.overall.completed, 0);
    });
  });
}
