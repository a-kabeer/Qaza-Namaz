import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/app/providers.dart';
import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/core/widgets/app_snackbar.dart';
import 'package:qaza_namaz/domain/entities/qaza_completion_result.dart';
import 'package:qaza_namaz/domain/services/qaza_undo_service.dart';
import 'package:qaza_namaz/features/qaza/qaza_undo_feedback.dart';
import 'package:qaza_namaz/l10n/app_localizations.dart';

class _FakeQazaUndoManager extends QazaUndoManager {
  _FakeQazaUndoManager(this.batch);

  final QazaUndoBatch batch;
  bool beganSelection = false;
  bool cancelled = false;

  @override
  Future<QazaUndoBatch?> registerEntries({
    required String userId,
    required Iterable<QazaCompletionEntry> entries,
  }) async {
    return batch;
  }

  @override
  Future<QazaUndoBatch> beginSelection({
    required String userId,
    required QazaUndoBatch expectedBatch,
  }) async {
    beganSelection = true;
    return batch;
  }

  @override
  Future<void> cancelSelection({
    required String userId,
    required QazaUndoBatch expectedBatch,
  }) async {
    cancelled = true;
  }
}

class _FeedbackHarness extends ConsumerStatefulWidget {
  const _FeedbackHarness({required this.batch});

  final QazaUndoBatch batch;

  @override
  ConsumerState<_FeedbackHarness> createState() => _FeedbackHarnessState();
}

class _FeedbackHarnessState extends ConsumerState<_FeedbackHarness> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showQazaUndoFeedback(
        context: context,
        ref: ref,
        userId: 'local',
        entries: widget.batch.entries.map(
          (entry) => QazaCompletionEntry(
            recordId: entry.recordId,
            completionId: entry.completionId,
            prayerType: entry.prayerType,
            originalDate: entry.originalDate,
            completedAt: entry.completedAt,
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}

QazaUndoBatch _batch() {
  final completedAt = DateTime(2026, 10, 2, 15);
  return QazaUndoBatch(
    sessionId: 'session-1',
    entries: [
      QazaUndoEntry(
        recordId: 'fajr',
        completionId: 'completion-fajr',
        prayerType: PrayerType.fajr,
        originalDate: DateTime(2026, 9, 1),
        completedAt: completedAt,
      ),
      QazaUndoEntry(
        recordId: 'zuhr',
        completionId: 'completion-zuhr',
        prayerType: PrayerType.zuhr,
        originalDate: DateTime(2026, 9, 2),
        completedAt: completedAt,
      ),
    ],
    expiresAt: completedAt.add(const Duration(seconds: 5)),
  );
}

void main() {
  testWidgets(
    'Batch Undo Snackbar opens the selection sheet and survives Snackbar expiry',
    (tester) async {
      final batch = _batch();
      final manager = _FakeQazaUndoManager(batch);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            qazaUndoManagerProvider.overrideWithValue(manager),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
            home: AppScaffoldMessenger(
              key: appScaffoldMessengerKey,
              child: Scaffold(
                body: _FeedbackHarness(batch: batch),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump();

      final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(snackBar.action, isNotNull);
      expect(snackBar.action!.label, 'Undo');
      snackBar.action!.onPressed();
      await tester.pumpAndSettle();

      expect(manager.beganSelection, isTrue);
      expect(find.text('Undo completions'), findsOneWidget);

      await tester.pump(const Duration(seconds: 6));
      expect(find.text('Undo completions'), findsOneWidget);

      final sheetContext = tester.element(find.text('Undo completions'));
      Navigator.of(sheetContext).pop();
      await tester.pumpAndSettle();
      expect(manager.cancelled, isTrue);
    },
  );
}
