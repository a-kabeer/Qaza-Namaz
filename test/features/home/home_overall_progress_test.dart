import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/core/theme/app_theme.dart';
import 'package:qaza_namaz/core/utils/chart_animation_policy.dart';
import 'package:qaza_namaz/domain/entities/qaza_progress.dart';
import 'package:qaza_namaz/features/home/widgets/home_overall_progress.dart';
import 'package:qaza_namaz/l10n/app_localizations.dart';

void main() {
  Widget buildWidget(
    QazaProgress progress, {
    bool disableAnimations = false,
    Brightness brightness = Brightness.light,
  }) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: brightness,
        ),
        useMaterial3: true,
      ),
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: disableAnimations,
          ),
          child: Scaffold(
            body: SingleChildScrollView(
              child: HomeOverallProgress(
                progress: progress,
                onDetails: () {},
              ),
            ),
          ),
        ),
      ),
    );
  }

  PieChart chart(WidgetTester tester) {
    return tester.widget<PieChart>(
      find.descendant(
        of: find.byKey(const Key('home_overall_donut')),
        matching: find.byType(PieChart),
      ),
    );
  }

  testWidgets(
    'donut arc, displayed percentage and chart colors match progress',
    (tester) async {
      final scenarios = <({QazaProgress progress, String label, double done})>[
        (
          progress: const QazaProgress(pending: 0, completed: 0),
          label: '0%',
          done: 0,
        ),
        (
          progress: const QazaProgress(pending: 3, completed: 2),
          label: '40%',
          done: 0.4,
        ),
        (
          progress: const QazaProgress(pending: 0, completed: 5),
          label: '100%',
          done: 1,
        ),
      ];

      for (final scenario in scenarios) {
        await tester.pumpWidget(buildWidget(scenario.progress));
        await tester.pumpAndSettle();

        final current = chart(tester);
        expect(current.duration, ChartAnimationPolicy.duration);
        expect(current.curve, ChartAnimationPolicy.curve);
        expect(current.data.sections, hasLength(2));
        expect(current.data.sections[0].value, scenario.done);
        expect(current.data.sections[1].value, 1 - scenario.done);
        expect(
          tester
              .widget<Text>(
                find.byKey(const Key('home_overall_percent')),
              )
              .data,
          scenario.label,
        );

        final context = tester.element(
          find.byKey(const Key('home_overall_donut')),
        );
        final scheme = Theme.of(context).colorScheme;
        expect(current.data.sections[0].color, scheme.primary);
        expect(
          current.data.sections[1].color,
          AppChartColors.of(context).track,
        );
      }
    },
  );

  testWidgets(
    'donut animation respects the reduced-animation preference',
    (tester) async {
      await tester.pumpWidget(
        buildWidget(
          const QazaProgress(pending: 3, completed: 2),
          disableAnimations: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(chart(tester).duration, Duration.zero);
      expect(
        tester
            .widget<Text>(
              find.byKey(const Key('home_overall_percent')),
            )
            .data,
        '40%',
      );
    },
  );

  testWidgets(
    'donut arc and percentage update together when progress changes',
    (tester) async {
      var progress = const QazaProgress(pending: 8, completed: 2);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
            useMaterial3: true,
          ),
          home: StatefulBuilder(
            builder: (context, setState) => Scaffold(
              body: SingleChildScrollView(
                child: Column(
                  children: [
                    HomeOverallProgress(
                      progress: progress,
                      onDetails: () {},
                    ),
                    TextButton(
                      key: const Key('update_overall_progress'),
                      onPressed: () {
                        setState(() {
                          progress = const QazaProgress(
                            pending: 3,
                            completed: 7,
                          );
                        });
                      },
                      child: const Text('Update progress'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(chart(tester).data.sections[0].value, 0.2);
      expect(
        tester
            .widget<Text>(
              find.byKey(const Key('home_overall_percent')),
            )
            .data,
        '20%',
      );

      await tester.tap(find.byKey(const Key('update_overall_progress')));
      await tester.pump();

      expect(chart(tester).duration, ChartAnimationPolicy.duration);
      expect(chart(tester).curve, ChartAnimationPolicy.curve);
      expect(chart(tester).data.sections[0].value, 0.7);
      expect(chart(tester).data.sections[1].value, closeTo(0.3, 0.00001));
      expect(
        tester
            .widget<Text>(
              find.byKey(const Key('home_overall_percent')),
            )
            .data,
        '70%',
      );

      // Pump an intermediate frame to exercise the active chart transition.
      await tester.pump(const Duration(milliseconds: 120));
      expect(
        tester
            .widget<Text>(
              find.byKey(const Key('home_overall_percent')),
            )
            .data,
        '70%',
      );
      await tester.pumpAndSettle();
    },
  );

  testWidgets('donut chart colors adapt to both theme brightnesses', (
    tester,
  ) async {
    const progress = QazaProgress(pending: 3, completed: 2);

    for (final brightness in [Brightness.light, Brightness.dark]) {
      await tester.pumpWidget(
        buildWidget(progress, brightness: brightness),
      );
      await tester.pumpAndSettle();

      final current = chart(tester);
      final context = tester.element(
        find.byKey(const Key('home_overall_donut')),
      );
      final scheme = Theme.of(context).colorScheme;

      expect(current.data.sections[0].color, scheme.primary);
      expect(
        current.data.sections[1].color,
        AppChartColors.of(context).track,
      );
    }
  });
}
