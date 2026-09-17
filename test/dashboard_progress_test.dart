import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/app/providers.dart';
import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/domain/entities/app_user.dart';
import 'package:qaza_namaz/domain/entities/qaza_progress.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';
import 'package:qaza_namaz/features/dashboard/dashboard_screen.dart';

import 'support/in_memory_qaza_repository.dart';

QazaRecord record({
  required String id,
  required PrayerType prayer,
  required QazaStatus status,
  required DateTime originalDate,
}) {
  final created = DateTime(2026, 9, 1);
  return QazaRecord(
    id: id,
    userId: 'test-user',
    prayerType: prayer,
    originalDate: originalDate,
    status: status,
    completedAt: status == QazaStatus.completed ? DateTime(2026, 9, 2) : null,
    createdAt: created,
    updatedAt: created,
  );
}

class _SummaryOnlyRepository extends InMemoryQazaRepository {
  bool getRecordsCalled = false;
  int progressSummaryCalls = 0;

  @override
  Future<List<QazaRecord>> getRecords({
    required String userId,
    PrayerType? prayerType,
    QazaStatus? status,
  }) async {
    getRecordsCalled = true;
    throw StateError('Dashboard must not load the complete ledger.');
  }

  @override
  Future<QazaProgressSummary> getProgressSummary({required String userId}) async {
    progressSummaryCalls++;
    return super.getProgressSummary(userId: userId);
  }
}

void main() {
  testWidgets('dashboard renders progress from aggregate summary without loading ledger', (tester) async {
    final repository = _SummaryOnlyRepository();
    await repository.addRecords([
      record(
        id: 'fajr-pending',
        prayer: PrayerType.fajr,
        status: QazaStatus.pending,
        originalDate: DateTime(2026, 8, 1),
      ),
      record(
        id: 'fajr-completed',
        prayer: PrayerType.fajr,
        status: QazaStatus.completed,
        originalDate: DateTime(2026, 8, 2),
      ),
      record(
        id: 'witr-pending',
        prayer: PrayerType.witr,
        status: QazaStatus.pending,
        originalDate: DateTime(2026, 8, 3),
      ),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          qazaRepositoryProvider.overrideWithValue(repository),
          authStateProvider.overrideWith(
            (ref) => Stream.value(
              const AppUser(id: 'test-user', email: 'test@example.com'),
            ),
          ),
        ],
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('2 pending'), findsWidgets);
    expect(find.text('1 fulfilled'), findsOneWidget);
    expect(find.text('3'), findsWidgets);

    await tester.scrollUntilVisible(
      find.text('1 pending • 1 completed'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('1 pending • 1 completed'), findsOneWidget);

    expect(repository.progressSummaryCalls, greaterThanOrEqualTo(1));
    expect(repository.getRecordsCalled, isFalse);
  });
}
