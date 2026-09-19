import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qaza_namaz/app/providers.dart';
import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';
import 'package:qaza_namaz/domain/repositories/qaza_repository.dart';
import 'package:qaza_namaz/features/calculator/calculator_controller.dart';
import 'package:qaza_namaz/features/calculator/calculator_screen.dart';

import 'support/in_memory_qaza_repository.dart';
import 'support/test_app.dart';

/// Holds a read or a write open until released, to catch the screen mid-work.
class _GatedRepository extends InMemoryQazaRepository {
  Completer<void>? readGate;
  Completer<void>? writeGate;

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

  @override
  Future<void> addRecords(List<QazaRecord> records) async {
    final gate = writeGate;
    if (gate != null) await gate.future;
    return super.addRecords(records);
  }
}

/// Step 3 offers exactly two things: a way back, and the add itself.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  ProviderContainer container(InMemoryQazaRepository repository) {
    final result = ProviderContainer(overrides: [
      qazaRepositoryProvider.overrideWithValue(repository),
      activeUserIdProvider.overrideWithValue('u1'),
    ]);
    addTearDown(result.dispose);
    return result;
  }

  Future<CalculatorController> ready(ProviderContainer scope) async {
    scope.listen(calculatorControllerProvider, (_, __) {});
    final controller = scope.read(calculatorControllerProvider.notifier);
    await controller.restore();
    return controller;
  }

  /// A finished calculation of [days] days across the five daily prayers.
  Future<CalculatorController> withEstimate(
    ProviderContainer scope, {
    required int days,
  }) async {
    final controller = await ready(scope);
    controller.setDob(DateTime(1990, 1, 1));
    controller.setBalighMode(BalighInputMode.exactDate);
    controller.setBalighDate(DateTime(2002, 1, 1));
    controller.setPrayerStartMode(PrayerStartInputMode.exactDate);
    controller
        .setPrayerStartDate(DateTime(2002, 1, 1).add(Duration(days: days)));
    controller.calculate();
    return controller;
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();
  }

  Future<void> pump(WidgetTester tester, ProviderContainer scope) async {
    await tester.pumpWidget(UncontrolledProviderScope(
      container: scope,
      child: const TestApp(home: CalculatorScreen()),
    ));
    await settle(tester);
  }

  String addButtonLabel(WidgetTester tester) => tester
      .widget<Text>(find.descendant(
        of: find.byKey(const Key('calculator_add_to_tracker')),
        matching: find.byType(Text),
      ))
      .data!;

  VoidCallback? addButtonAction(WidgetTester tester) => tester
      .widget<FilledButton>(find.byKey(const Key('calculator_add_to_tracker')))
      .onPressed;

  testWidgets('the step offers only Back and the add action', (tester) async {
    final scope = container(InMemoryQazaRepository());
    await withEstimate(scope, days: 10);
    await pump(tester, scope);

    expect(find.byKey(const Key('calculator_back')), findsOneWidget);
    expect(find.byKey(const Key('calculator_add_to_tracker')), findsOneWidget);
    expect(find.byKey(const Key('calculator_edit_about')), findsNothing);
    expect(
        find.byKey(const Key('calculator_edit_prayer_history')), findsNothing);
    // The result itself is untouched.
    expect(find.text('Prayer breakdown'), findsOneWidget);
  });

  testWidgets('the add action is named for the records it will add',
      (tester) async {
    // 365 days x 5 prayers.
    final scope = container(InMemoryQazaRepository());
    await withEstimate(scope, days: 365);
    await pump(tester, scope);

    expect(scope.read(calculatorControllerProvider).preflight?.newCount, 1825);
    expect(addButtonLabel(tester), 'Add 1,825 Qaza');
  });

  testWidgets('the count is what is new, not what was calculated',
      (tester) async {
    final repository = InMemoryQazaRepository();
    // Ten of the fifty are already on the ledger.
    await repository.addRecords([
      for (var i = 0; i < 2; i++)
        for (final prayer
            in PrayerType.values.where((p) => p != PrayerType.witr))
          QazaRecord(
            id: 'existing_${i}_${prayer.name}',
            userId: 'u1',
            prayerType: prayer,
            originalDate: DateTime(2002, 1, 1).add(Duration(days: i)),
            createdAt: DateTime(2020, 1, 1),
            updatedAt: DateTime(2020, 1, 1),
          ),
    ]);
    final scope = container(repository);
    await withEstimate(scope, days: 10);
    await pump(tester, scope);

    expect(addButtonLabel(tester), 'Add 40 Qaza');
  });

  testWidgets('the action is disabled while the check is running',
      (tester) async {
    final repository = _GatedRepository()..readGate = Completer<void>();
    final scope = container(repository);
    await withEstimate(scope, days: 10);
    await pump(tester, scope);

    expect(scope.read(calculatorControllerProvider).loadingPreflight, isTrue);
    expect(addButtonAction(tester), isNull);
    // Until the count is known the action keeps its plain name.
    expect(addButtonLabel(tester), 'Add to Tracker');

    repository.readGate!.complete();
    await settle(tester);

    expect(addButtonAction(tester), isNotNull);
    expect(addButtonLabel(tester), 'Add 50 Qaza');
  });

  testWidgets('the action is disabled while saving', (tester) async {
    final repository = _GatedRepository()..writeGate = Completer<void>();
    final scope = container(repository);
    final controller = await withEstimate(scope, days: 10);
    await pump(tester, scope);

    final adding = controller.addToTracker();
    await tester.pump();

    expect(scope.read(calculatorControllerProvider).addingToTracker, isTrue);
    expect(addButtonAction(tester), isNull);

    repository.writeGate!.complete();
    await adding;
    await settle(tester);
    // The estimate has landed, and the step has moved on to its result.
    expect(find.byKey(const Key('calculator_add_to_tracker')), findsNothing);
    expect(find.byKey(const Key('calc_add_success')), findsOneWidget);
  });

  testWidgets('Back returns to Step 2 with everything still entered',
      (tester) async {
    final scope = container(InMemoryQazaRepository());
    await withEstimate(scope, days: 10);
    await pump(tester, scope);

    await tester.tap(find.byKey(const Key('calculator_back')));
    await settle(tester);

    final state = scope.read(calculatorControllerProvider);
    expect(state.step, 1);
    expect(find.text('Step 2 of 3'), findsOneWidget);
    expect(state.dob, DateTime(1990, 1, 1));
    expect(state.balighDate, DateTime(2002, 1, 1));
    expect(state.prayerStartDate, DateTime(2002, 1, 11));
    // The result survives the visit, so Step 3 is still open.
    expect(state.calculation, isNotNull);
    expect(state.canOpenStep(2), isTrue);
  });
}
