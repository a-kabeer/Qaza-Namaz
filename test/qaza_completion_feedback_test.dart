import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/core/theme/app_theme.dart';
import 'package:qaza_namaz/domain/services/qaza_undo_service.dart';
import 'package:qaza_namaz/features/qaza/qaza_completion_feedback.dart';
import 'support/test_app.dart';

void main() {
  const completionId = 'completion-test';
  final batch = QazaUndoBatch(
    entries: [
      QazaUndoEntry(
        recordId: 'r1',
        completionId: completionId,
        prayerType: PrayerType.fajr,
        originalDate: DateTime(2026, 1, 1),
      ),
    ],
    expiresAt: DateTime(2026, 1, 2),
  );

  testWidgets('English single completion and restore messages are exact',
      (tester) async {
    late String completed;
    late String restored;

    await tester.pumpWidget(
      TestApp(
        theme: AppTheme.light(locale: const Locale('en')),
        locale: const Locale('en'),
        home: Builder(
          builder: (context) {
            completed = qazaCompletionSuccessMessage(context, batch);
            restored = qazaUndoSuccessMessage(context, batch, 1);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(completed, 'Fajr Qaza for 01 Jan 2026 completed.');
    expect(restored, 'Fajr Qaza for 01 Jan 2026 restored.');
  });

  testWidgets('English bulk completion message is exact', (tester) async {
    final bulk = QazaUndoBatch(
      entries: [
        for (var index = 0; index < 3; index++)
          QazaUndoEntry(
            recordId: 'r$index',
            completionId: 'c$index',
            prayerType: PrayerType.fajr,
            originalDate: DateTime(2026, 1, index + 1),
          ),
      ],
      expiresAt: DateTime(2026, 1, 2),
    );

    late String message;
    await tester.pumpWidget(
      TestApp(
        theme: AppTheme.light(locale: const Locale('en')),
        locale: const Locale('en'),
        home: Builder(
          builder: (context) {
            message = qazaCompletionSuccessMessage(context, bulk);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(message, '3 Qaza completed.');
  });

  testWidgets('Urdu completion, restore, and stale messages are localized',
      (tester) async {
    late String completed;
    late String restored;
    late String stale;

    await tester.pumpWidget(
      TestApp(
        theme: AppTheme.light(locale: const Locale('ur')),
        locale: const Locale('ur'),
        home: Builder(
          builder: (context) {
            completed = qazaCompletionSuccessMessage(context, batch);
            restored = qazaUndoSuccessMessage(context, batch, 1);
            stale = qazaUndoFailureMessage(
              context,
              QazaUndoFailureReason.targetChanged,
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(completed, 'فجر کی قضا، 01 Jan 2026 مکمل ہو گئی۔');
    expect(restored, 'فجر کی قضا، 01 Jan 2026 دوبارہ باقی میں شامل ہو گئی۔');
    expect(stale, contains('واپس کرنے'));
    expect(stale, isNot(contains('Undo is no longer available')));
  });
}
