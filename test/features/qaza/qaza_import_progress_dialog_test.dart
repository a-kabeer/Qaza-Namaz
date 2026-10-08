import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/features/qaza/qaza_import_controller.dart';
import 'package:qaza_namaz/features/qaza/qaza_import_progress_dialog.dart';
import 'package:qaza_namaz/l10n/app_localizations.dart';

class _TestImportController extends QazaImportController {
  _TestImportController(this.initialState);

  final QazaImportTaskState initialState;

  @override
  QazaImportTaskState build() => initialState;

  bool retryCalled = false;

  void emit(QazaImportTaskState next) {
    state = next;
  }

  @override
  bool retry() {
    retryCalled = true;
    state = const QazaImportTaskState(
      phase: QazaImportTaskPhase.preparing,
    );
    return true;
  }
}

Widget _app(_TestImportController controller) {
  return ProviderScope(
    overrides: [
      qazaImportProvider.overrideWith(() => controller),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: FilledButton(
              key: const Key('open_progress'),
              onPressed: () => showDialog<void>(
                context: context,
                barrierDismissible: false,
                builder: (_) => const QazaImportProgressDialog(),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('open_progress')));
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('shows real import progress and counts', (tester) async {
    final controller = _TestImportController(const QazaImportTaskState(
      phase: QazaImportTaskPhase.importing,
      processed: 4000,
      total: 8000,
      added: 3950,
      skipped: 50,
    ));
    await tester.pumpWidget(_app(controller));
    await _open(tester);

    expect(find.text('50%'), findsOneWidget);
    expect(find.text('4000 / 8000'), findsOneWidget);
    expect(find.text('3950'), findsOneWidget);
    expect(find.text('50'), findsOneWidget);
    expect(find.text('Added'), findsOneWidget);
    expect(find.text('Skipped'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.byType(TextButton), findsNothing);
  });

  testWidgets('shows preparing state without a fake percentage',
      (tester) async {
    final controller = _TestImportController(const QazaImportTaskState(
      phase: QazaImportTaskPhase.preparing,
    ));
    await tester.pumpWidget(_app(controller));
    await _open(tester);

    expect(find.text('50%'), findsNothing);
    expect(find.text('Checking your ledger...'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });

  testWidgets('handles zero-total importing state safely', (tester) async {
    final controller = _TestImportController(const QazaImportTaskState(
      phase: QazaImportTaskPhase.importing,
      processed: 0,
      total: 0,
    ));
    await tester.pumpWidget(_app(controller));
    await _open(tester);

    expect(find.text('Checking your ledger...'), findsOneWidget);
    expect(find.textContaining('/ 0'), findsOneWidget);
  });

  testWidgets('keeps failure open and retries in place', (tester) async {
    final controller = _TestImportController(const QazaImportTaskState(
      phase: QazaImportTaskPhase.failed,
    ));
    await tester.pumpWidget(_app(controller));
    await _open(tester);

    expect(find.text('Retry'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pump();

    expect(controller.retryCalled, isTrue);
    expect(find.text('Checking your ledger...'), findsOneWidget);
  });

  testWidgets('closes when import completes', (tester) async {
    final controller = _TestImportController(const QazaImportTaskState(
      phase: QazaImportTaskPhase.importing,
      processed: 0,
      total: 8000,
    ));
    await tester.pumpWidget(_app(controller));
    await _open(tester);
    expect(find.text('Adding Qaza...'), findsOneWidget);

    controller.emit(const QazaImportTaskState(
      phase: QazaImportTaskPhase.completed,
      processed: 8000,
      total: 8000,
      added: 8000,
    ));
    await tester.pump();
    await tester.pump();

    expect(find.text('Adding Qaza...'), findsNothing);
  });
}
