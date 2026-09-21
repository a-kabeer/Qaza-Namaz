import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../constants/prayer_types.dart';
import 'app_colors.dart';

/// Central application theme.
///
/// The only source of Material styling for the application. Colour, type,
/// shape and elevation tokens are taken from the Qaza Namaz "Serene Sanctuary"
/// palette: fresh greens, sage neutrals, a soft purple accent, semantic
/// feedback colors, and Noto Serif / Manrope typography.
class AppTheme {
  // Canonical palette aliases. Keep theme construction centralized while the
  // raw color values live in AppColors.
  static const Color darkBase = AppColors.darkBase;
  static const Color darkPrimary = AppColors.darkPrimary;
  static const Color darkOnPrimary = AppColors.darkOnPrimary;
  static const Color darkPrimaryContainer = AppColors.darkPrimaryContainer;
  static const Color darkOnPrimaryContainer = AppColors.darkOnPrimaryContainer;
  static const Color amber = AppColors.darkSecondary;
  static const Color mint = AppColors.darkTertiary;
  static const Color kineticMint = AppColors.darkTertiaryContainer;

  static const Color interactive = AppColors.lightPrimary;

  static const Color darkSurfaceLowest = AppColors.darkSurfaceLowest;
  static const Color darkSurfaceLow = AppColors.darkSurfaceLow;
  static const Color darkSurface = AppColors.darkSurface;
  static const Color darkSurfaceHigh = AppColors.darkSurfaceHigh;
  static const Color darkSurfaceHighest = AppColors.darkSurfaceHighest;
  static const Color darkOnSurface = AppColors.darkOnSurface;
  static const Color darkOnSurfaceVariant = AppColors.darkOnSurfaceVariant;
  static const Color darkOutline = AppColors.darkOutline;
  static const Color darkOutlineVariant = AppColors.darkOutlineVariant;

  static const Color lightBase = AppColors.lightBase;
  static const Color lightSurface = AppColors.lightSurface;
  static const Color lightSurfaceLow = AppColors.lightSurfaceLow;
  static const Color lightBorder = AppColors.lightBorder;
  static const Color lightOnSurface = AppColors.lightOnSurface;
  static const Color lightSecondary = AppColors.lightSecondary;
  static const Color white = AppColors.white;

  static const Color primaryFixed = AppColors.primaryFixed;
  static const Color onPrimaryFixed = AppColors.onPrimaryFixed;
  static const Color secondaryFixed = AppColors.secondaryFixed;
  static const Color onSecondaryFixed = AppColors.onSecondaryFixed;
  static const Color tertiaryFixed = AppColors.tertiaryFixed;
  static const Color onTertiaryFixed = AppColors.onTertiaryFixed;

  static const String _serif = 'Noto Serif';
  static const String _sans = 'Manrope';

  /// Bundled Nastaliq face used for every Urdu string in the app.
  ///
  /// Nastaliq, not Naskh: Urdu readers expect the cascading Nastaliq style,
  /// and the system default on most devices is a Naskh face. Arabic content
  /// keeps the platform face, which is Naskh and correct for it.
  static const String urduFamily = 'Noto Nastaliq Urdu';

  /// Nastaliq sets on a steep diagonal, so a line box sized for Manrope clips
  /// the cascade and collides with the line below. Every Latin style is
  /// derived into its Urdu counterpart with these factors rather than being
  /// written out twice, which keeps the two scales from drifting apart.
  static const double _urduSizeFactor = 1.08;
  static const double _urduHeightFactor = 1.7;

  /// Floor for the derived line height. Display styles are set tight in Latin;
  /// Nastaliq still needs room there, or the cascade of one line lands on the
  /// ascenders of the next.
  static const double _urduMinHeight = 1.9;

  /// Above this size the derived leading is capped: large text needs
  /// proportionally less of it, and a headline at 2.4 reads as two headlines.
  static const double _urduLargeSize = 24;
  static const double _urduLargeMaxHeight = 2.0;

  static bool isUrdu(Locale? locale) => locale?.languageCode == 'ur';

  /// Large tally counter; tabular so an incrementing count never shifts layout.
  static const TextStyle numericLarge = TextStyle(
    fontFamily: _sans,
    fontSize: 40,
    height: 48 / 40,
    fontWeight: FontWeight.w700,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Compact tally counter; tabular so an incrementing count never shifts layout.
  static const TextStyle numericMedium = TextStyle(
    fontFamily: _sans,
    fontSize: 24,
    height: 30 / 24,
    fontWeight: FontWeight.w700,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static ThemeData light({Locale? locale}) {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.lightPrimary,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.lightPrimary,
      onPrimary: AppColors.white,
      primaryContainer: AppColors.lightPrimaryContainer,
      onPrimaryContainer: AppColors.lightOnPrimaryContainer,
      secondary: AppColors.lightSecondary,
      onSecondary: AppColors.white,
      secondaryContainer: AppColors.lightSecondaryContainer,
      onSecondaryContainer: AppColors.lightOnSecondaryContainer,
      tertiary: AppColors.lightTertiary,
      onTertiary: AppColors.white,
      tertiaryContainer: AppColors.lightTertiaryContainer,
      onTertiaryContainer: AppColors.lightOnTertiaryContainer,
      error: AppColors.lightError,
      onError: AppColors.white,
      errorContainer: AppColors.lightError.withValues(alpha: 0.12),
      onErrorContainer: AppColors.lightError,
      surface: lightBase,
      onSurface: lightOnSurface,
      surfaceContainerLowest: white,
      surfaceContainerLow: lightSurfaceLow,
      surfaceContainer: lightSurface,
      surfaceContainerHigh: white,
      surfaceContainerHighest: lightSurfaceLow,
      outline: lightBorder,
      outlineVariant: lightBorder,
      surfaceTint: AppColors.lightPrimary,
    );
    return _base(scheme, Brightness.light, urdu: isUrdu(locale));
  }

  static ThemeData dark({Locale? locale}) {
    const scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: darkPrimary,
      onPrimary: darkOnPrimary,
      primaryContainer: darkPrimaryContainer,
      onPrimaryContainer: darkOnPrimaryContainer,
      secondary: AppColors.darkSecondary,
      onSecondary: AppColors.darkOnSecondary,
      secondaryContainer: AppColors.darkSecondaryContainer,
      onSecondaryContainer: AppColors.darkOnSecondaryContainer,
      tertiary: AppColors.darkTertiary,
      onTertiary: AppColors.darkOnTertiary,
      tertiaryContainer: AppColors.darkTertiaryContainer,
      onTertiaryContainer: AppColors.darkOnTertiaryContainer,
      error: AppColors.darkError,
      onError: AppColors.darkOnError,
      errorContainer: AppColors.darkErrorContainer,
      onErrorContainer: AppColors.darkOnErrorContainer,
      surface: darkBase,
      onSurface: darkOnSurface,
      surfaceDim: darkBase,
      surfaceBright: AppColors.darkSurfaceBright,
      surfaceContainerLowest: darkSurfaceLowest,
      surfaceContainerLow: darkSurfaceLow,
      surfaceContainer: darkSurface,
      surfaceContainerHigh: darkSurfaceHigh,
      surfaceContainerHighest: darkSurfaceHighest,
      onSurfaceVariant: darkOnSurfaceVariant,
      outline: darkOutline,
      outlineVariant: darkOutlineVariant,
      inverseSurface: darkOnSurface,
      onInverseSurface: AppColors.darkOnInverseSurface,
      inversePrimary: AppColors.lightPrimary,
      surfaceTint: AppColors.darkPrimaryContainer,
      primaryFixed: AppColors.primaryFixed,
      primaryFixedDim: AppColors.primaryFixedDim,
      onPrimaryFixed: AppColors.onPrimaryFixed,
      onPrimaryFixedVariant: AppColors.onPrimaryFixedVariant,
      secondaryFixed: AppColors.secondaryFixed,
      secondaryFixedDim: AppColors.secondaryFixedDim,
      onSecondaryFixed: AppColors.onSecondaryFixed,
      onSecondaryFixedVariant: AppColors.onSecondaryFixedVariant,
      tertiaryFixed: AppColors.tertiaryFixed,
      tertiaryFixedDim: AppColors.tertiaryFixedDim,
      onTertiaryFixed: AppColors.onTertiaryFixed,
      onTertiaryFixedVariant: AppColors.onTertiaryFixedVariant,
    );
    return _base(scheme, Brightness.dark, urdu: isUrdu(locale));
  }

  /// The Qaza Namaz type scale: Noto Serif for display/headline and the
  /// large title used by prayer names, Manrope for everything else.
  static TextTheme _latinTextTheme(ColorScheme scheme) {
    TextStyle serif(double size, double lineHeight, FontWeight weight) =>
        TextStyle(
          fontFamily: _serif,
          fontSize: size,
          height: lineHeight / size,
          fontWeight: weight,
          color: scheme.onSurface,
        );
    TextStyle sans(
      double size,
      double lineHeight,
      FontWeight weight, {
      double? letterSpacing,
      Color? color,
    }) =>
        TextStyle(
          fontFamily: _sans,
          fontSize: size,
          height: lineHeight / size,
          fontWeight: weight,
          letterSpacing: letterSpacing,
          color: color ?? scheme.onSurface,
        );

    return TextTheme(
      displayLarge: serif(48, 56, FontWeight.w400),
      displayMedium: serif(36, 44, FontWeight.w400),
      displaySmall: serif(30, 38, FontWeight.w500),
      headlineLarge: serif(30, 38, FontWeight.w500),
      headlineMedium: serif(24, 32, FontWeight.w500),
      headlineSmall: serif(20, 26, FontWeight.w500),
      titleLarge: serif(20, 26, FontWeight.w600),
      titleMedium: sans(16, 22, FontWeight.w600, letterSpacing: 0.15),
      titleSmall: sans(14, 20, FontWeight.w600, letterSpacing: 0.1),
      bodyLarge: sans(16, 24, FontWeight.w400, letterSpacing: 0.25),
      bodyMedium: sans(14, 20, FontWeight.w400, letterSpacing: 0.25),
      bodySmall: sans(12, 16, FontWeight.w400,
          letterSpacing: 0.4, color: scheme.onSurfaceVariant),
      labelLarge: sans(14, 20, FontWeight.w600, letterSpacing: 0.1),
      labelMedium: sans(12, 16, FontWeight.w600, letterSpacing: 0.5),
      labelSmall: sans(11, 14, FontWeight.w700, letterSpacing: 0.6),
    );
  }

  /// Derives the Urdu scale from the Latin one, slot for slot, so no slot can
  /// be forgotten and the two scales cannot drift apart.
  static TextTheme _urduTextTheme(ColorScheme scheme) {
    final latin = _latinTextTheme(scheme);
    return TextTheme(
      displayLarge: _toUrdu(latin.displayLarge!),
      displayMedium: _toUrdu(latin.displayMedium!),
      displaySmall: _toUrdu(latin.displaySmall!),
      headlineLarge: _toUrdu(latin.headlineLarge!),
      headlineMedium: _toUrdu(latin.headlineMedium!),
      headlineSmall: _toUrdu(latin.headlineSmall!),
      titleLarge: _toUrdu(latin.titleLarge!),
      titleMedium: _toUrdu(latin.titleMedium!),
      titleSmall: _toUrdu(latin.titleSmall!),
      bodyLarge: _toUrdu(latin.bodyLarge!),
      bodyMedium: _toUrdu(latin.bodyMedium!),
      bodySmall: _toUrdu(latin.bodySmall!),
      labelLarge: _toUrdu(latin.labelLarge!),
      labelMedium: _toUrdu(latin.labelMedium!),
      labelSmall: _toUrdu(latin.labelSmall!),
    );
  }

  /// One Latin style, restated for Nastaliq.
  ///
  /// The size grows a little (Nastaliq's letterforms read small at a nominal
  /// size), the line box grows a lot, and letter spacing goes to zero: spacing
  /// out Arabic-script letters breaks the cursive join between them.
  static TextStyle _toUrdu(TextStyle latin) {
    final size = (latin.fontSize ?? 14) * _urduSizeFactor;
    final scaled = (latin.height ?? 1.2) * _urduHeightFactor;
    final height = size >= _urduLargeSize
        ? scaled.clamp(_urduMinHeight, _urduLargeMaxHeight)
        : math.max(scaled, _urduMinHeight);
    final weight = latin.fontWeight ?? FontWeight.w400;
    return latin.copyWith(
      fontFamily: urduFamily,
      fontSize: size,
      height: height,
      letterSpacing: 0,
      wordSpacing: 0,
      // The bundled face is variable over wght 400-700; name the axis so the
      // weight is rendered rather than synthesized.
      fontVariations: [
        FontVariation.weight(weight.value.clamp(400, 700).toDouble()),
      ],
    );
  }

  static ThemeData _base(
    ColorScheme scheme,
    Brightness brightness, {
    required bool urdu,
  }) {
    final typography = AppTypography(
      latin: _latinTextTheme(scheme),
      urdu: _urduTextTheme(scheme),
    );
    final textTheme = typography.forScript(urduScript: urdu);

    // Shape scale: 12dp actions, 16dp cards, 24dp modals, pill chips.
    final buttonShape = WidgetStatePropertyAll<OutlinedBorder>(
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      textTheme: textTheme,
      // Both scales travel with the theme so bilingual content can ask for the
      // one matching the text it is about to draw, without naming a font.
      extensions: [
        typography,
        AppChartColors.forBrightness(brightness),
      ],
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLow,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 80,
        backgroundColor: scheme.surfaceContainerHigh,
        indicatorColor: scheme.surfaceContainerHighest,
        indicatorShape: const StadiumBorder(),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? textTheme.labelSmall?.copyWith(color: scheme.primary)
              : textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainer,
        labelStyle: textTheme.labelMedium,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          shape: buttonShape,
          minimumSize: const WidgetStatePropertyAll(Size(120, 48)),
          textStyle: WidgetStatePropertyAll(textTheme.labelLarge),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          shape: buttonShape,
          minimumSize: const WidgetStatePropertyAll(Size(64, 48)),
          textStyle: WidgetStatePropertyAll(textTheme.labelLarge),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          shape: buttonShape,
          textStyle: WidgetStatePropertyAll(textTheme.labelLarge),
        ),
      ),
      iconButtonTheme:
          IconButtonThemeData(style: ButtonStyle(shape: buttonShape)),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: scheme.surfaceContainerHigh,
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: scheme.inverseSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.surfaceContainerHighest,
        circularTrackColor: scheme.surfaceContainerHighest,
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant),
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
        side: BorderSide(color: scheme.outlineVariant),
        labelStyle: textTheme.labelLarge,
      ),
    );
  }
}

/// Both type scales, carried on the theme.
///
/// The app's locale picks which one becomes [ThemeData.textTheme]. Content
/// that knows its own language regardless of the locale — a Knowledge Base
/// article shown in Urdu while the interface is English, the Urdu wordmark —
/// resolves the other one through here instead of hardcoding a font family in
/// the widget.
@immutable
class AppTypography extends ThemeExtension<AppTypography> {
  const AppTypography({required this.latin, required this.urdu});

  final TextTheme latin;
  final TextTheme urdu;

  TextTheme forScript({required bool urduScript}) => urduScript ? urdu : latin;

  /// Body style for long-form article text, which sets looser than UI copy.
  ///
  /// Latin opens up to a 1.7 reading height; Nastaliq already carries a much
  /// taller line box from the scale and gains nothing from being stretched
  /// further.
  TextStyle? readingBody({required bool urduScript}) =>
      urduScript ? urdu.bodyLarge : latin.bodyLarge?.copyWith(height: 1.7);

  static AppTypography of(BuildContext context) =>
      Theme.of(context).extension<AppTypography>() ??
      AppTypography(
        latin: AppTheme._latinTextTheme(Theme.of(context).colorScheme),
        urdu: AppTheme._urduTextTheme(Theme.of(context).colorScheme),
      );

  @override
  AppTypography copyWith({TextTheme? latin, TextTheme? urdu}) =>
      AppTypography(latin: latin ?? this.latin, urdu: urdu ?? this.urdu);

  @override
  AppTypography lerp(ThemeExtension<AppTypography>? other, double t) {
    if (other is! AppTypography) return this;
    return AppTypography(
      latin: TextTheme.lerp(latin, other.latin, t),
      urdu: TextTheme.lerp(urdu, other.urdu, t),
    );
  }
}

@immutable
class AppChartColors extends ThemeExtension<AppChartColors> {
  const AppChartColors({
    required this.fajr,
    required this.zuhr,
    required this.asr,
    required this.maghrib,
    required this.isha,
    required this.witr,
    required this.completed,
    required this.pending,
    required this.total,
    required this.primary,
    required this.grid,
    required this.track,
  });

  final Color fajr;
  final Color zuhr;
  final Color asr;
  final Color maghrib;
  final Color isha;
  final Color witr;
  final Color completed;
  final Color pending;
  final Color total;
  final Color primary;
  final Color grid;
  final Color track;

  static AppChartColors forBrightness(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;

  static const light = AppChartColors(
    fajr: AppColors.chartFajr,
    zuhr: AppColors.chartZuhr,
    asr: AppColors.chartAsr,
    maghrib: AppColors.chartMaghrib,
    isha: AppColors.chartIsha,
    witr: AppColors.chartWitr,
    completed: AppColors.chartCompleted,
    pending: AppColors.chartPending,
    total: AppColors.chartTotal,
    primary: AppColors.lightChartPrimary,
    grid: AppColors.lightChartGrid,
    track: AppColors.lightChartTrack,
  );

  static const dark = AppChartColors(
    fajr: AppColors.chartFajr,
    zuhr: AppColors.chartZuhr,
    asr: AppColors.chartAsr,
    maghrib: AppColors.chartMaghrib,
    isha: AppColors.chartIsha,
    witr: AppColors.chartWitr,
    completed: AppColors.chartCompleted,
    pending: AppColors.chartPending,
    total: AppColors.chartTotal,
    primary: AppColors.darkChartPrimary,
    grid: AppColors.darkChartGrid,
    track: AppColors.darkChartTrack,
  );

  Color forPrayer(PrayerType prayer) => switch (prayer) {
        PrayerType.fajr => fajr,
        PrayerType.zuhr => zuhr,
        PrayerType.asr => asr,
        PrayerType.maghrib => maghrib,
        PrayerType.isha => isha,
        PrayerType.witr => witr,
      };

  static AppChartColors of(BuildContext context) =>
      Theme.of(context).extension<AppChartColors>() ??
      AppChartColors.forBrightness(Theme.of(context).brightness);

  @override
  AppChartColors copyWith({
    Color? fajr,
    Color? zuhr,
    Color? asr,
    Color? maghrib,
    Color? isha,
    Color? witr,
    Color? completed,
    Color? pending,
    Color? total,
    Color? primary,
    Color? grid,
    Color? track,
  }) =>
      AppChartColors(
        fajr: fajr ?? this.fajr,
        zuhr: zuhr ?? this.zuhr,
        asr: asr ?? this.asr,
        maghrib: maghrib ?? this.maghrib,
        isha: isha ?? this.isha,
        witr: witr ?? this.witr,
        completed: completed ?? this.completed,
        pending: pending ?? this.pending,
        total: total ?? this.total,
        primary: primary ?? this.primary,
        grid: grid ?? this.grid,
        track: track ?? this.track,
      );

  @override
  AppChartColors lerp(ThemeExtension<AppChartColors>? other, double t) {
    if (other is! AppChartColors) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;

    return AppChartColors(
      fajr: mix(fajr, other.fajr),
      zuhr: mix(zuhr, other.zuhr),
      asr: mix(asr, other.asr),
      maghrib: mix(maghrib, other.maghrib),
      isha: mix(isha, other.isha),
      witr: mix(witr, other.witr),
      completed: mix(completed, other.completed),
      pending: mix(pending, other.pending),
      total: mix(total, other.total),
      primary: mix(primary, other.primary),
      grid: mix(grid, other.grid),
      track: mix(track, other.track),
    );
  }
}

enum AppThemeMode { system, light, dark }

extension AppThemeModeX on AppThemeMode {
  /// Maps the app's theme choice onto Flutter's [ThemeMode].
  ThemeMode get materialMode => switch (this) {
        AppThemeMode.system => ThemeMode.system,
        AppThemeMode.light => ThemeMode.light,
        AppThemeMode.dark => ThemeMode.dark,
      };
}
