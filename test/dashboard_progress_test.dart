import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/app/providers.dart';
import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/core/widgets/progress_widgets.dart';
import 'package:qaza_namaz/domain/entities/app_user.dart';
import 'package:qaza_namaz/domain/entities/qaza_progress.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';
import 'package:qaza_namaz/features/dashboard/dashboard_screen.dart';

import 'support/in_memory_qaza_repository.dart';

QazaRecord record({required String id, required PrayerType prayer, required QazaStatus status}) {
  final created = DateTime(2026, 9, 1);
  return QazaRecord(
    id: id,
    userId: 'test-user',
    prayerType: prayer,
    originalDate: DateTime(2026, 8, 1),
    status: status,
    completedAt: status == QazaStatus.completed ? DateTime(2026, 9, 2) : null,
    createdAt: created,
    updatedAt: created,
  );
}

class _SummaryOnlyRepository extends InMemoryQazaRepository {
  bool getRecordsCalled = false;

  @override
  Future<List<QazaRecord>> getRecords({required String userId, PrayerType? prayerType, QazaStatus? status}) async {
    getRecordsCalled = true;
    throw StateError('Dashboard must not load the complete ledger.');
  }

  @override
  Future<QazaProgressSummary> getProgressSummary({required String userId}) async {
    return super.getProgressSummary(userId: userId);
  }
}

void main() {
  testWidgets('dashboard renders progress from aggregate summary without loading ledger', (tester) async {
    final repository = _SummaryOnlyRepository();
    await repository.addRecords([
      record(id: 'fajr-pending', prayer: PrayerType.fajr, status: QazaStatus.pending),
      record(id: 'fajr-completed', prayer: PrayerType.fajr, status: QazaStatus.completed),
      record(id: 'witr-pending', prayer: PrayerType.witr, status: QazaStatus.pending),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          qazaRepositoryProvider.overrideWithValue(repository),
          authStateProvider.overrideWith((ref) => Stream.value(const AppUser(id: 'test-user', email: 'test@example.com'))),
        ],
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('2 pending'), findsWidgets);
    final fulfilledChips = find.byType(StatusChip).evaluate().where(
          (element) => (element.widget as StatusChip).label == '1 fulfilled',
        );
    expect(fulfilledChips, hasLength(1));
    expect(find.text('3'), findsWidgets);
    expect(find.text('1 pending • 1 completed'), findsOneWidget);
    expect(find.text('1 pending'), findsWidgets);
    expect(repository.getRecordsCalled, isFalse);
  });
}
