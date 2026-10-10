import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/core/theme/app_theme.dart';
import 'package:qaza_namaz/core/widgets/progress_widgets.dart';
import 'package:qaza_namaz/domain/entities/qaza_progress.dart';
import 'package:qaza_namaz/features/home/widgets/home_overall_progress.dart';
import 'package:qaza_namaz/l10n/app_localizations.dart';

double _contrastRatio(Color foreground, Color background) {
  final foregroundLuminance = foreground.computeLuminance();
  final backgroundLuminance = background.computeLuminance();
  final lighter = foregroundLuminance > backgroundLuminance
      ? foregroundLuminance
      : backgroundLuminance;
  final darker = foregroundLuminance > backgroundLuminance
      ? backgroundLuminance
      : foregroundLuminance;
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  group('AppTheme semantic surfaces', () {
    void expectSemanticRoles(ThemeData theme) {
      final scheme = theme.colorScheme;

      expect(theme.scaffoldBackgroundColor, scheme.surface);
      expect(theme.cardTheme.color, scheme.surfaceContainerLow);
      expect(theme.dialogTheme.backgroundColor, scheme.surfaceContainerHigh);
      expect(
        theme.bottomSheetTheme.backgroundColor,
        scheme.surfaceContainerHigh,
      );
      expect(
        theme.navigationBarTheme.backgroundColor,
        scheme.surfaceContainerHigh,
      );
      expect(theme.inputDecorationTheme.fillColor, scheme.surfaceContainer);
      expect(theme.progressIndicatorTheme.color, scheme.primary);
      expect(theme.dividerTheme.color, scheme.outlineVariant);
    }

    test('light theme semantic roles resolve from one ColorScheme', () {
      expectSemanticRoles(AppTheme.light());
    });

    test('dark theme semantic roles resolve from one ColorScheme', () {
      expectSemanticRoles(AppTheme.dark());
    });
  });

  group('Blue-violet palette contract', () {
    test('uses the approved neutral surfaces and brand colors', () {
      final light = AppTheme.light();
      final dark = AppTheme.dark();

      expect(light.scaffoldBackgroundColor, const Color(0xFFF7F8FA));
      expect(light.cardTheme.color, const Color(0xFFFFFFFF));
      expect(light.colorScheme.surface, const Color(0xFFF7F8FA));
      expect(light.colorScheme.primary, const Color(0xFF2563EB));
      expect(light.colorScheme.secondary, const Color(0xFF7C3AED));
      expect(light.colorScheme.onPrimary, Colors.white);
      expect(light.colorScheme.onSecondary, Colors.white);

      expect(dark.scaffoldBackgroundColor, const Color(0xFF09090B));
      expect(dark.cardTheme.color, const Color(0xFF18181B));
      expect(dark.colorScheme.surface, const Color(0xFF09090B));
      expect(dark.colorScheme.primary, const Color(0xFF60A5FA));
      expect(dark.colorScheme.secondary, const Color(0xFFC4B5FD));
      expect(dark.colorScheme.onPrimary, const Color(0xFF09090B));
      expect(dark.colorScheme.onSecondary, const Color(0xFF09090B));
    });

    test('brand button foregrounds meet WCAG AA normal-text contrast', () {
      final light = AppTheme.light().colorScheme;
      final dark = AppTheme.dark().colorScheme;

      expect(_contrastRatio(light.onPrimary, light.primary),
          greaterThanOrEqualTo(4.5));
      expect(_contrastRatio(light.onSecondary, light.secondary),
          greaterThanOrEqualTo(4.5));
      expect(_contrastRatio(dark.onPrimary, dark.primary),
          greaterThanOrEqualTo(4.5));
      expect(_contrastRatio(dark.onSecondary, dark.secondary),
          greaterThanOrEqualTo(4.5));
    });
  });

  group('AppTheme typography and mode', () {
    test('Urdu theme keeps the bundled Nastaliq text scale', () {
      final theme = AppTheme.light(locale: const Locale('ur'));
      final body = theme.textTheme.bodyMedium!;

      expect(body.fontFamily, AppTheme.urduFamily);
      expect(body.letterSpacing, 0);
      expect(body.height, greaterThanOrEqualTo(1.9));
    });

    test('English theme uses the Latin type scale', () {
      final theme = AppTheme.light(locale: const Locale('en'));

      expect(theme.textTheme.bodyMedium?.fontFamily, 'Manrope');
    });

    test('theme mode mapping preserves system, light and dark choices', () {
      expect(AppThemeMode.system.materialMode, ThemeMode.system);
      expect(AppThemeMode.light.materialMode, ThemeMode.light);
      expect(AppThemeMode.dark.materialMode, ThemeMode.dark);
    });
  });

  group('Chart theme contract', () {
    test('prayer and status colors stay stable across brightness modes', () {
      final light = AppTheme.light().extension<AppChartColors>()!;
      final dark = AppTheme.dark().extension<AppChartColors>()!;

      expect(light.fajr, dark.fajr);
      expect(light.zuhr, dark.zuhr);
      expect(light.asr, dark.asr);
      expect(light.maghrib, dark.maghrib);
      expect(light.isha, dark.isha);
      expect(light.witr, dark.witr);
      expect(light.completed, dark.completed);
      expect(light.pending, dark.pending);
      expect(light.total, dark.total);
    });

    test('chart tracks remain theme-aware', () {
      final light = AppTheme.light().extension<AppChartColors>()!;
      final dark = AppTheme.dark().extension<AppChartColors>()!;

      expect(light.track, isNot(dark.track));
      expect(light.grid, isNot(dark.grid));
    });
  });

  for (final brightness in Brightness.values) {
    testWidgets(
      'progress ring uses ColorScheme.primary in $brightness mode',
      (tester) async {
        final theme =
            brightness == Brightness.dark ? AppTheme.dark() : AppTheme.light();

        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: const Scaffold(
              body: ProgressRing(progress: 0.5),
            ),
          ),
        );

        final indicator = tester.widget<CircularProgressIndicator>(
          find.byType(CircularProgressIndicator),
        );
        expect(indicator.color, theme.colorScheme.primary);
      },
    );
  }

  for (final brightness in Brightness.values) {
    testWidgets(
      'overall progress donut uses ColorScheme.primary in $brightness mode',
      (tester) async {
        final theme =
            brightness == Brightness.dark ? AppTheme.dark() : AppTheme.light();

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
            theme: theme,
            home: Scaffold(
              body: HomeOverallProgress(
                progress: const QazaProgress(pending: 5, completed: 5),
                onDetails: () {},
              ),
            ),
          ),
        );

        final chart = tester.widget<PieChart>(find.byType(PieChart));
        expect(chart.data.sections.first.color, theme.colorScheme.primary);
      },
    );
  }
}
