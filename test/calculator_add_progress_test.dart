import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qaza_namaz/app/providers.dart';
import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';
import 'package:qaza_namaz/domain/services/qaza_service.dart';
import 'package:qaza_namaz/features/calculator/calculator_controller.dart';

import 'support/in_memory_qaza_repository.dart';

/// Fails a chosen write, to exercise the error path.
class _FailingRepository extends InMemoryQazaRepository {
  int addCalls = 0;
  int failOnCall = -1;

  @override
  Future<void> addRecords(List<QazaRecord> records) async {
    addCalls++;
    if (addCalls == failOnCall) throw StateError('database is full');
    return super.addRecords(records);
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  List<DateTime> days(int count) => [
        for (var i = 0; i < count; i++)
          DateTime(2020, 1, 1).add(Duration(days: i))
      ];

  ProviderContainer container(InMemoryQazaRepository repository) {
    final result = ProviderContainer(overrides: [
      qazaRepositoryProvider.overrideWithValue(repository),
      activeUserIdProvider.overrideWithValue('u1'),
    ]);
    addTearDown(result.dispose);
    return result;
  }

  group('the service reports progress', () {
    test('a small insert finishes in one batch', () async {
      final repository = InMemoryQazaRepository();
      final service = QazaService(repository);
      final reports = <(int, int)>[];

      final added = await service.recordQazaForDates(
        userId: 'u1',
        dates: days(2),
        prayerTypes: [PrayerType.fajr],
        onProgress: (processed, total) => reports.add((processed, total)),
      );

      expect(added, 2);
      // Opens with the real total, then one report per batch.
      expect(reports, [(0, 2), (2, 2)]);
    });

    test('a large insert is written in bounded batches', () async {
      final repository = InMemoryQazaRepository();
      final service = QazaService(repository);
      final reports = <(int, int)>[];

      // 400 days x 5 prayers = 2,000 records.
      final added = await service.recordQazaForDates(
        userId: 'u1',
        dates: days(400),
        prayerTypes: PrayerType.values.where((p) => p != PrayerType.witr),
        batchSize: 500,
        onProgress: (processed, total) => reports.add((processed, total)),
      );

      expect(added, 2000);
      expect(reports.first, (0, 2000));
      expect(reports.last, (2000, 2000));
      // Four batches after the opening report, and it only ever moves forward.
      expect(reports, hasLength(5));
      for (var i = 1; i < reports.length; i++) {
        expect(reports[i].$1, greaterThan(reports[i - 1].$1));
        expect(reports[i].$2, 2000);
      }
      expect(await repository.getRecords(userId: 'u1'), hasLength(2000));
    });

    test('duplicates are excluded from the total before any write', () async {
      final repository = InMemoryQazaRepository();
      final service = QazaService(repository);
      await service.recordQazaForDates(
          userId: 'u1', dates: days(3), prayerTypes: [PrayerType.fajr]);
      final reports = <(int, int)>[];

      // The same three days again, plus two new ones.
      final added = await service.recordQazaForDates(
        userId: 'u1',
        dates: days(5),
        prayerTypes: [PrayerType.fajr],
        onProgress: (processed, total) => reports.add((processed, total)),
      );

      expect(added, 2);
      expect(reports.first, (0, 2));
      expect(await repository.getRecords(userId: 'u1'), hasLength(5));
    });

    test('a request with nothing to add reports a zero total', () async {
      final repository = InMemoryQazaRepository();
      final service = QazaService(repository);
      await service.recordQazaForDates(
          userId: 'u1', dates: days(2), prayerTypes: [PrayerType.fajr]);
      final reports = <(int, int)>[];

      final added = await service.recordQazaForDates(
        userId: 'u1',
        dates: days(2),
        prayerTypes: [PrayerType.fajr],
        onProgress: (processed, total) => reports.add((processed, total)),
      );

      expect(added, 0);
      expect(reports, [(0, 0)]);
    });

    test('an invalid batch size is rejected', () async {
      final service = QazaService(InMemoryQazaRepository());

      expect(
        () => service.recordQazaForDates(
            userId: 'u1',
            dates: days(1),
            prayerTypes: [PrayerType.fajr],
            batchSize: 0),
        throwsArgumentError,
      );
    });
  });

  group('the calculator state', () {
    Future<CalculatorController> ready(ProviderContainer scope) async {
      scope.listen(calculatorControllerProvider, (_, __) {});
      final controller = scope.read(calculatorControllerProvider.notifier);
      await controller.restore();
      return controller;
    }

    /// Drives the calculator to a finished estimate.
    Future<CalculatorController> withEstimate(
      ProviderContainer scope, {
      required DateTime prayerStart,
    }) async {
      final controller = await ready(scope);
      controller.setDob(DateTime(1990, 1, 1));
      controller.setBalighDate(DateTime(2002, 1, 1));
      controller.setPrayerStartDate(prayerStart);
      controller.calculate();
      expect(scope.read(calculatorControllerProvider).calculation, isNotNull);
      return controller;
    }

    test('progress starts at zero and is determinate', () {
      const state = CalculatorState();

      expect(state.addProgress, 0);
      expect(state.hasAddResult, isFalse);

      const running = CalculatorState(addProcessed: 21, addTotal: 50);
      expect(running.addProgress, closeTo(0.42, 0.0001));
    });

    test('a completed insert reports how many were added', () async {
      final repository = InMemoryQazaRepository();
      final scope = container(repository);
      final controller =
          await withEstimate(scope, prayerStart: DateTime(2002, 1, 11));

      final ok = await controller.addToTracker();
      final state = scope.read(calculatorControllerProvider);

      expect(ok, isTrue);
      expect(state.addingToTracker, isFalse);
      expect(state.hasAddResult, isTrue);
      expect(state.addedCount, greaterThan(0));
      expect(state.addProcessed, state.addTotal);
      expect(state.addProgress, 1);
      expect(state.error, isNull);
    });

    test('adding twice adds nothing the second time', () async {
      final repository = InMemoryQazaRepository();
      final scope = container(repository);
      final controller =
          await withEstimate(scope, prayerStart: DateTime(2002, 1, 11));

      await controller.addToTracker();
      final first = scope.read(calculatorControllerProvider).addedCount;
      controller.calculate();
      await controller.addToTracker();
      final second = scope.read(calculatorControllerProvider).addedCount;

      expect(first, greaterThan(0));
      // Duplicate detection is unchanged: the second run finds nothing new.
      expect(second, 0);
      expect(await repository.getRecords(userId: 'u1'), hasLength(first!));
    });

    test('a failed insert leaves an error and no result', () async {
      final repository = _FailingRepository()..failOnCall = 1;
      final scope = container(repository);
      final controller =
          await withEstimate(scope, prayerStart: DateTime(2002, 1, 11));

      final ok = await controller.addToTracker();
      final state = scope.read(calculatorControllerProvider);

      expect(ok, isFalse);
      expect(state.addingToTracker, isFalse);
      expect(state.hasAddResult, isFalse);
      expect(state.error, contains('database is full'));
    });

    test('retrying after a failure succeeds', () async {
      final repository = _FailingRepository()..failOnCall = 1;
      final scope = container(repository);
      final controller =
          await withEstimate(scope, prayerStart: DateTime(2002, 1, 11));
      await controller.addToTracker();
      expect(scope.read(calculatorControllerProvider).error, isNotNull);

      controller.calculate();
      final ok = await controller.addToTracker();
      final state = scope.read(calculatorControllerProvider);

      expect(ok, isTrue);
      expect(state.error, isNull);
      expect(state.addedCount, greaterThan(0));
    });

    test('a second tap while running is refused', () async {
      final repository = InMemoryQazaRepository();
      final scope = container(repository);
      final controller =
          await withEstimate(scope, prayerStart: DateTime(2002, 1, 11));

      final first = controller.addToTracker();
      final second = await controller.addToTracker();
      await first;

      expect(second, isFalse);
      expect(
          scope.read(calculatorControllerProvider).addedCount,
          await repository
              .getRecords(userId: 'u1')
              .then((records) => records.length));
    });

    test('the result is left behind by starting over', () async {
      final scope = container(InMemoryQazaRepository());
      final controller =
          await withEstimate(scope, prayerStart: DateTime(2002, 1, 11));
      await controller.addToTracker();
      expect(scope.read(calculatorControllerProvider).hasAddResult, isTrue);

      controller.startNewCalculation();

      expect(scope.read(calculatorControllerProvider).hasAddResult, isFalse);
    });
  });
}
