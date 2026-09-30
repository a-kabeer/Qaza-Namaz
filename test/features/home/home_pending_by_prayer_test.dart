import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/app/providers.dart';
import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/domain/entities/qaza_progress.dart';
import 'package:qaza_namaz/features/home/widgets/home_pending_by_prayer.dart';
import 'package:qaza_namaz/features/shell/workspace_shell.dart';
import 'package:qaza_namaz/features/qaza/qaza_tracker_controller.dart';
import 'package:qaza_namaz/l10n/app_localizations.dart';

QazaProgressSummary _summary() {
  return QazaProgressSummary(
    overall: const QazaProgress(pending: 3, completed: 0),
    byPrayer: {
      for (final prayer in PrayerType.values)
        prayer: PrayerProgress(
          prayerType: prayer,
          progress: QazaProgress(
            pending: prayer == PrayerType.fajr ? 2 : prayer == PrayerType.zuhr ? 1 : 0,
            completed: 0,
          ),
        ),
    },
  );
}

Widget _app({required Widget child, required ProviderContainer container}) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  testWidgets('whole Pending by Prayer card opens unfiltered Qaza workspace',
      (tester) async {
    final container = ProviderContainer(
      overrides: [
        enabledPrayerTypesProvider.overrideWithValue(
          const [PrayerType.fajr, PrayerType.zuhr],
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      _app(
        container: container,
        child: HomePendingByPrayer(summary: _summary()),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('home_pending_by_prayer_view_all')),
      findsNothing,
    );

    await tester.tap(find.byKey(const Key('home_pending_by_prayer_tap')));
    expect(
      container.read(workspaceDestinationProvider),
      WorkspaceDestination.qaza,
    );
    expect(container.read(qazaTrackerFilterRequestProvider), isNull);
  });

  testWidgets('tapping a prayer keeps the existing prayer and pending filter',
      (tester) async {
    final container = ProviderContainer(
      overrides: [
        enabledPrayerTypesProvider.overrideWithValue(
          const [PrayerType.fajr, PrayerType.zuhr],
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      _app(
        container: container,
        child: HomePendingByPrayer(summary: _summary()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('home_pending_prayer_fajr')));
    final request = container.read(qazaTrackerFilterRequestProvider);

    expect(container.read(workspaceDestinationProvider), WorkspaceDestination.qaza);
    expect(request?.prayer, PrayerType.fajr);
    expect(request?.status, QazaStatusFilter.pending);
  });
}
