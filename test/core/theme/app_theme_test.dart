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
      expect(theme.cardTheme.clipBehavior, Clip.antiAlias);
      expect(theme.splashColor, scheme.primary.withAlpha(24));
      expect(theme.highlightColor, scheme.primary.withAlpha(12));
      expect(theme.hoverColor, scheme.primary.withAlpha(12));
      expect(theme.focusColor, scheme.primary.withAlpha(24));
      expect(theme.dialogTheme.backgroundColor, scheme.surfaceContainerHigh);
      expect(
        theme.bottomSheetTheme.backgroundColor,
        scheme.surfaceContainerHigh,
      );
      expect(
        theme.snackBarTheme.backgroundColor,
        scheme.surfaceContainerHigh,
      );
      expect(
        theme.snackBarTheme.backgroundColor,
        theme.brightness == Brightness.dark
            ? isNot(scheme.surface)
            : isNot(scheme.inverseSurface),
      );
      expect(
        theme.snackBarTheme.contentTextStyle?.color,
        scheme.onSurface,
      );
      expect(theme.snackBarTheme.actionTextColor, scheme.primary);
      expect(
        _contrastRatio(
          theme.snackBarTheme.contentTextStyle!.color!,
          theme.snackBarTheme.backgroundColor!,
        ),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrastRatio(
          theme.snackBarTheme.actionTextColor!,
          theme.snackBarTheme.backgroundColor!,
        ),
        greaterThanOrEqualTo(4.5),
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

  group('Teal palette contract', () {
    test('uses the approved neutral surfaces and brand colors', () {
      final light = AppTheme.light();
      final dark = AppTheme.dark();

      expect(light.scaffoldBackgroundColor, const Color(0xFFF7F8FA));
      expect(light.cardTheme.color, const Color(0xFFFFFFFF));
      expect(light.colorScheme.surface, const Color(0xFFF7F8FA));
      expect(light.colorScheme.primary, const Color(0xFF01485A));
      expect(light.colorScheme.secondary, const Color(0xFF2F7782));
      expect(light.colorScheme.primaryContainer, const Color(0xFFD6EBEE));
      expect(light.colorScheme.onPrimaryContainer, const Color(0xFF123F49));
      expect(light.colorScheme.secondaryContainer, const Color(0xFFDCEFF1));
      expect(light.colorScheme.onSecondaryContainer, const Color(0xFF174D56));
      expect(light.colorScheme.tertiary, const Color(0xFF386F78));
      expect(light.colorScheme.onTertiary, Colors.white);
      expect(light.colorScheme.tertiaryContainer, const Color(0xFFE6F3F4));
      expect(light.colorScheme.onTertiaryContainer, const Color(0xFF174D56));
      expect(light.colorScheme.onPrimary, Colors.white);
      expect(light.colorScheme.onSecondary, Colors.white);

      expect(dark.scaffoldBackgroundColor, const Color(0xFF09090B));
      expect(dark.cardTheme.color, const Color(0xFF18181B));
      expect(dark.colorScheme.surface, const Color(0xFF09090B));
      expect(dark.colorScheme.primary, const Color(0xFF78BCC5));
      expect(dark.colorScheme.secondary, const Color(0xFFB6DCE0));
      expect(dark.colorScheme.primaryContainer, const Color(0xFF16434B));
      expect(dark.colorScheme.onPrimaryContainer, const Color(0xFFD6EBEE));
      expect(dark.colorScheme.secondaryContainer, const Color(0xFF1B4147));
      expect(dark.colorScheme.onSecondaryContainer, const Color(0xFFDCEFF1));
      expect(dark.colorScheme.tertiary, const Color(0xFF91CDD4));
      expect(dark.colorScheme.onTertiary, const Color(0xFF0E3036));
      expect(dark.colorScheme.tertiaryContainer, const Color(0xFF20474D));
      expect(dark.colorScheme.onTertiaryContainer, const Color(0xFFE2F3F4));
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

      // Container and tertiary pairs also need readable normal-text contrast.
      for (final pair in <(Color, Color)>[
        (light.onPrimaryContainer, light.primaryContainer),
        (light.onSecondaryContainer, light.secondaryContainer),
        (light.onTertiary, light.tertiary),
        (light.onTertiaryContainer, light.tertiaryContainer),
        (dark.onPrimaryContainer, dark.primaryContainer),
        (dark.onSecondaryContainer, dark.secondaryContainer),
        (dark.onTertiary, dark.tertiary),
        (dark.onTertiaryContainer, dark.tertiaryContainer),
      ]) {
        expect(
          _contrastRatio(pair.$1, pair.$2),
          greaterThanOrEqualTo(4.5),
        );
      }
    });
  });

  group('Primary color palettes', () {
    test('provides eight choices with readable primary and secondary roles', () {
      expect(AppPrimaryColor.values, hasLength(8));
      expect(AppTheme.colorFor(AppPrimaryColor.teal), const Color(0xFF01485A));
      for (final color in AppPrimaryColor.values) {
        final light = AppTheme.light(primaryColor: color).colorScheme;
        final dark = AppTheme.dark(primaryColor: color).colorScheme;
        expect(
          _contrastRatio(light.onPrimary, light.primary),
          greaterThanOrEqualTo(4.5),
          reason: '${color.name} light primary',
        );
        expect(
          _contrastRatio(dark.onPrimary, dark.primary),
          greaterThanOrEqualTo(4.5),
          reason: '${color.name} dark primary',
        );
        expect(
          _contrastRatio(light.onSecondary, light.secondary),
          greaterThanOrEqualTo(4.5),
          reason: '${color.name} light secondary',
        );
        expect(
          _contrastRatio(dark.onSecondary, dark.secondary),
          greaterThanOrEqualTo(4.5),
          reason: '${color.name} dark secondary',
        );
      }
    });
  });

  group('AppTheme typography and mode', () {
    test('Urdu theme uses Nastaliq with role-specific metrics', () {
      final theme = AppTheme.light(locale: const Locale('ur'));
      final text = theme.textTheme;

      expect(text.bodyMedium!.fontFamily, AppTheme.urduFamily);
      expect(text.bodyMedium!.letterSpacing, 0);
      expect(text.bodyMedium!.fontSize, 15);
      expect(text.bodyMedium!.height, closeTo(27 / 15, 0.001));

      expect(text.labelSmall!.fontFamily, AppTheme.urduFamily);
      expect(text.labelSmall!.fontSize, 12);
      expect(text.labelSmall!.height, closeTo(21 / 12, 0.001));
      expect(text.labelSmall!.height, lessThan(text.bodyMedium!.height!));
      expect(text.bodyMedium!.height, lessThan(1.9));
    });

    test('Arabic theme uses Noto Sans Arabic with independent metrics', () {
      final arabic = AppTheme.light(locale: const Locale('ar')).textTheme;
      final urdu = AppTheme.light(locale: const Locale('ur')).textTheme;

      expect(arabic.bodyMedium!.fontFamily, AppTheme.arabicFamily);
      expect(arabic.bodyMedium!.fontSize, 14);
      expect(arabic.bodyMedium!.height, closeTo(20 / 14, 0.001));
      expect(arabic.labelSmall!.fontFamily, AppTheme.arabicFamily);
      expect(arabic.labelSmall!.height, closeTo(16 / 11, 0.001));
      expect(arabic.bodyMedium!.height, isNot(urdu.bodyMedium!.height));
      expect(arabic.labelSmall!.height, isNot(urdu.labelSmall!.height));
    });

    test('English theme keeps the existing Latin type scale', () {
      final text = AppTheme.light(locale: const Locale('en')).textTheme;

      expect(text.bodyMedium?.fontFamily, 'Manrope');
      expect(text.bodyMedium?.fontSize, 14);
      expect(text.bodyMedium?.height, closeTo(20 / 14, 0.001));
    });

    testWidgets(
      'script typography wraps on narrow screens with enlarged text',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(320, 720);
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        for (final locale in <Locale>[
          const Locale('ur'),
          const Locale('ar'),
        ]) {
          for (final brightness in Brightness.values) {
            final theme = brightness == Brightness.dark
                ? AppTheme.dark(locale: locale)
                : AppTheme.light(locale: locale);
            final sample = locale.languageCode == 'ur'
                ? 'قضا نماز کی ادائیگی کے لیے روزانہ کا ہدف مقرر کریں اور اپنی پیش رفت باقاعدگی سے دیکھیں۔'
                : 'قضاء الصلاة تحتاج إلى تنظيم يومي ومتابعة التقدم بوضوح وانتظام.';
            await tester.pumpWidget(
              MaterialApp(
                theme: theme,
                home: Builder(
                  builder: (context) => MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      textScaler: const TextScaler.linear(1.4),
                    ),
                    child: Directionality(
                      textDirection: TextDirection.rtl,
                      child: Scaffold(
                        body: ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            Text(sample, style: theme.textTheme.bodyMedium),
                            const SizedBox(height: 12),
                            Text(
                              sample,
                              style: theme.textTheme.labelSmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
            expect(
              tester.takeException(),
              isNull,
              reason:
                  '${locale.languageCode} typography should lay out in $brightness mode',
            );
          }
        }
      },
    );

    test('Roman Urdu uses Latin typography rather than Nastaleeq', () {
      const romanUrdu =
          Locale.fromSubtags(languageCode: 'ur', scriptCode: 'Latn');
      final light = AppTheme.light(locale: romanUrdu);
      final dark = AppTheme.dark(locale: romanUrdu);

      expect(AppTheme.isUrdu(romanUrdu), isFalse);
      expect(light.textTheme.bodyMedium?.fontFamily, 'Manrope');
      expect(dark.textTheme.bodyMedium?.fontFamily, 'Manrope');
      expect(
          light.textTheme.bodyMedium?.fontFamily, isNot(AppTheme.urduFamily));
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
