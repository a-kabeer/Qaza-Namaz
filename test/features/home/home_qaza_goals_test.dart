import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'package:qaza_namaz/domain/entities/qaza_activity.dart';
import 'package:qaza_namaz/features/home/providers/home_providers.dart';
import 'package:qaza_namaz/features/home/widgets/home_qaza_goals.dart';
import 'package:qaza_namaz/l10n/app_localizations.dart';

QazaActivityPeriod _period() {
  final start = DateTime(2026, 9, 24);
  final days = [
    for (var index = 0; index < 7; index++)
      QazaDailyActivity(
        date: DateTime(2026, 9, 24 + index),
        completed: index == 6 ? 2 : index,
        byPrayer: const {},
        target: 5,
        isFuture: false,
      ),
  ];
  return QazaActivityPeriod(
    from: start,
    toExclusive: DateTime(2026, 10, 1),
    today: DateTime(2026, 9, 30),
    days: days,
  );
}

Widget _buildWidget(QazaActivityPeriod period) {
  return ProviderScope(
    overrides: [
      homeQazaActivitySevenDaysProvider.overrideWith(
        (ref) => Future.value(period),
      ),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: Scaffold(
        body: HomeQazaGoals(onDetails: () {}),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'renders seven data-driven goal bars and target backgrounds',
    (tester) async {
      final period = _period();

      await tester.pumpWidget(_buildWidget(period));
      await tester.pump();

      final chart = tester.widget<BarChart>(
        find.byKey(const Key('home_qaza_goals_chart')),
      );

      expect(chart.data.barGroups, hasLength(7));
      expect(chart.data.barGroups.last.barRods.single.toY, 2);
      expect(
        chart.data.barGroups.last.barRods.single.backDrawRodData?.toY,
        5,
      );
      expect(chart.data.maxY, 5);

      expect(
        find.text(
          period.goalDays.toString() + '/' + period.days.length.toString(),
        ),
        findsOneWidget,
      );
      expect(find.text('Achieved'), findsOneWidget);
      expect(
        find.text(DateFormat.E('en').format(period.days.first.date)),
        findsOneWidget,
      );
      expect(
        find.text(DateFormat.E('en').format(period.days.last.date)),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'does not use the old scrolling or circular goal presentation',
    (tester) async {
      await tester.pumpWidget(_buildWidget(_period()));
      await tester.pump();

      expect(find.byType(SingleChildScrollView), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byKey(const Key('home_qaza_goals_chart')), findsOneWidget);
    },
  );
}
