import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/test_app.dart';

import 'package:qaza_namaz/app/providers.dart';
import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/core/widgets/app_button.dart';
import 'package:qaza_namaz/domain/entities/app_user.dart';
import 'package:qaza_namaz/domain/entities/qaza_record.dart';
import 'package:qaza_namaz/domain/services/qaza_service.dart';
import 'support/complete_qaza_host.dart';
import 'support/in_memory_qaza_repository.dart';

QazaRecord record({required String id, required DateTime originalDate}) {
  final now = DateTime(2026, 9, 16, 10);
  return QazaRecord(
    id: id,
    userId: 'test-user',
    prayerType: PrayerType.fajr,
    originalDate: originalDate,
    createdAt: now,
    updatedAt: now,
  );
}

Widget scoped(Widget child, InMemoryQazaRepository repository) => ProviderScope(
      overrides: [
        qazaRepositoryProvider.overrideWithValue(repository),
        authStateProvider.overrideWith(
          (ref) => Stream.value(
            const AppUser(id: 'test-user', email: 'test@example.com'),
          ),
        ),
      ],
      child: TestApp(home: child),
    );

void main() {
  testWidgets('completion immediately advances to the next pending record',
      (tester) async {
    final repository = InMemoryQazaRepository();
    await repository.addRecords([
      record(id: 'fajr_old', originalDate: DateTime(2026, 9, 2)),
      record(id: 'fajr_next', originalDate: DateTime(2026, 9, 10)),
    ]);

    await tester.pumpWidget(scoped(const CompleteQazaHost(), repository));
    await tester.pumpAndSettle();
    // The page shows the latest pending record, so the newer date leads.
    expect(find.text('10 Sep 2026'), findsOneWidget);

    await tester.tap(find.byKey(const Key('complete_oldest_pending')));
    await tester.pump();

    expect(find.text('02 Sep 2026'), findsOneWidget);
    expect(find.text('Fajr Qaza completed • the next one is ready.'),
        findsOneWidget);

    final records = await repository.getRecords(userId: 'test-user');
    expect(records.singleWhere((r) => r.id == 'fajr_next').status,
        QazaStatus.completed);
    expect(records.singleWhere((r) => r.id == 'fajr_old').status,
        QazaStatus.pending);
  });

  testWidgets(
      'button becomes unavailable after the final pending record is completed',
      (tester) async {
    final repository = InMemoryQazaRepository();
    await repository
        .addRecord(record(id: 'fajr_old', originalDate: DateTime(2026, 9, 2)));

    await tester.pumpWidget(scoped(const CompleteQazaHost(), repository));
    await tester.pumpAndSettle();
    final button = find.byKey(const Key('complete_oldest_pending'));

    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(find.text('No pending Qaza for this prayer.'), findsOneWidget);
    expect(tester.widget<AppButton>(button).onPressed, isNull);
  });

  test('repeated completion of the same record is idempotent', () async {
    final repository = InMemoryQazaRepository();
    final service = QazaService(repository);
    await service.recordQaza(
      userId: 'test-user',
      prayerType: PrayerType.fajr,
      originalDate: DateTime(2026, 9, 2),
    );

    expect(
      await service.completeOldestPending(
        userId: 'test-user',
        prayerType: PrayerType.fajr,
        completedAt: DateTime(2026, 9, 16, 10),
      ),
      isTrue,
    );
    expect(
      await service.completeOldestPending(
        userId: 'test-user',
        prayerType: PrayerType.fajr,
        completedAt: DateTime(2026, 9, 16, 10, 1),
      ),
      isFalse,
    );

    final records = await repository.getRecords(userId: 'test-user');
    expect(records, hasLength(1));
    expect(records.single.status, QazaStatus.completed);
    expect(records.single.completedAt, DateTime(2026, 9, 16, 10));
  });
}
