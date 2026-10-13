import 'dart:math' as math;

import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';

import '../constants/prayer_types.dart';
import 'app_colors.dart';

/// Central application theme.
///
/// The only source of Material styling for the application. Color, type,
/// shape and elevation tokens use neutral surfaces, a teal primary and
/// complementary teal secondary accents, semantic feedback colors, and Noto
/// Serif / Manrope typography.
class AppTheme {
  static const _subThemesData = FlexSubThemesData(
    defaultRadius: 12,
    cardRadius: 16,
    cardElevation: 0,
    cardBackgroundSchemeColor: SchemeColor.surfaceContainerLow,
    cardBorderSchemeColor: SchemeColor.outlineVariant,
    cardBorderWidth: 1,
  );

  static const String _serif = 'Noto Serif';
  static const String _sans = 'Manrope';

  /// Bundled Nastaliq face used for every Urdu string in the app.
  ///
  /// Nastaliq, not Naskh: Urdu readers expect the cascading Nastaliq style,
  /// and the system default on most devices is a Naskh face. Arabic content
  /// keeps the platform face, which is Naskh and correct for it.
  static const String urduFamily = 'Noto Nastaliq Urdu';
  static const String arabicFamily = 'Noto Sans Arabic';
  static bool isArabic(Locale? locale) => locale?.languageCode == 'ar';

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

  static ThemeData light({Locale? locale, String? assetPackage}) {
    return _base(
      FlexThemeData.light(
        primary: _lightPrimary,
        onPrimary: Colors.white,
        primaryContainer: _lightPrimaryContainer,
        onPrimaryContainer: _lightOnPrimaryContainer,
        secondary: _lightSecondary,
        onSecondary: Colors.white,
        secondaryContainer: _lightSecondaryContainer,
        onSecondaryContainer: _lightOnSecondaryContainer,
        tertiary: _lightTertiary,
        onTertiary: _lightOnTertiary,
        tertiaryContainer: _lightTertiaryContainer,
        onTertiaryContainer: _lightOnTertiaryContainer,
        error: _lightError,
        onError: Colors.white,
        errorContainer: _lightErrorContainer,
        onErrorContainer: _lightError,
        surface: _lightSurface,
        onSurface: _lightOnSurface,
        scaffoldBackground: _lightSurface,
        subThemesData: _subThemesData,
      ),
      Brightness.light,
      urdu: isUrdu(locale),
      arabic: isArabic(locale),
      assetPackage: assetPackage,
    );
  }

  static ThemeData dark({Locale? locale, String? assetPackage}) {
    return _base(
      FlexThemeData.dark(
        primary: _darkPrimary,
        onPrimary: _darkOnPrimary,
        primaryContainer: _darkPrimaryContainer,
        onPrimaryContainer: _darkOnPrimaryContainer,
        secondary: _darkSecondary,
        onSecondary: _darkOnSecondary,
        secondaryContainer: _darkSecondaryContainer,
        onSecondaryContainer: _darkOnSecondaryContainer,
        tertiary: _darkTertiary,
        onTertiary: _darkOnTertiary,
        tertiaryContainer: _darkTertiaryContainer,
        onTertiaryContainer: _darkOnTertiaryContainer,
        error: _darkError,
        onError: _darkOnError,
        errorContainer: _darkErrorContainer,
        onErrorContainer: _darkOnErrorContainer,
        surface: _darkSurface,
        onSurface: _darkOnSurface,
        scaffoldBackground: _darkSurface,
        subThemesData: _subThemesData,
      ),
      Brightness.dark,
      urdu: isUrdu(locale),
      arabic: isArabic(locale),
      assetPackage: assetPackage,
    );
  }

  // Neutral light surfaces.
  static const _lightSurface = Color(0xFFF7F8FA);
  static const _lightCard = Color(0xFFFFFFFF);
  static const _lightOnSurface = Color(0xFF111827);
  static const _lightOnSurfaceVariant = Color(0xFF6B7280);
  static const _lightSurfaceContainer = Color(0xFFF3F4F6);
  static const _lightSurfaceContainerHigh = Color(0xFFEFF1F5);
  static const _lightSurfaceContainerHighest = Color(0xFFE5E7EB);
  static const _lightOutline = Color(0xFFD1D5DB);
  static const _lightOutlineVariant = Color(0xFFE5E7EB);

  // Brand and container roles.
  static const _lightPrimary = Color(0xFF01485A);
  static const _lightPrimaryContainer = Color(0xFFD6EBEE);
  static const _lightOnPrimaryContainer = Color(0xFF123F49);
  static const _lightSecondary = Color(0xFF2F7782);
  static const _lightSecondaryContainer = Color(0xFFDCEFF1);
  static const _lightOnSecondaryContainer = Color(0xFF174D56);
  static const _lightTertiary = Color(0xFF386F78);
  static const _lightOnTertiary = Color(0xFFFFFFFF);
  static const _lightTertiaryContainer = Color(0xFFE6F3F4);
  static const _lightOnTertiaryContainer = Color(0xFF174D56);
  static const _lightError = Color(0xFFEF4444);
  static const _lightErrorContainer = Color(0x1FEF4444);

  // Neutral dark surfaces.
  static const _darkSurface = Color(0xFF09090B);
  static const _darkCard = Color(0xFF18181B);
  static const _darkOnSurface = Color(0xFFFAFAFA);
  static const _darkOnSurfaceVariant = Color(0xFFA1A1AA);
  static const _darkSurfaceContainer = Color(0xFF1F1F23);
  static const _darkSurfaceContainerHigh = Color(0xFF27272A);
  static const _darkSurfaceContainerHighest = Color(0xFF3F3F46);
  static const _darkOutline = Color(0xFF52525B);
  static const _darkOutlineVariant = Color(0xFF27272A);

  // Brand and container roles.
  static const _darkPrimary = Color(0xFF78BCC5);
  static const _darkOnPrimary = Color(0xFF09090B);
  static const _darkPrimaryContainer = Color(0xFF16434B);
  static const _darkOnPrimaryContainer = Color(0xFFD6EBEE);
  static const _darkSecondary = Color(0xFFB6DCE0);
  static const _darkOnSecondary = Color(0xFF09090B);
  static const _darkSecondaryContainer = Color(0xFF1B4147);
  static const _darkOnSecondaryContainer = Color(0xFFDCEFF1);
  static const _darkTertiary = Color(0xFF91CDD4);
  static const _darkOnTertiary = Color(0xFF0E3036);
  static const _darkTertiaryContainer = Color(0xFF20474D);
  static const _darkOnTertiaryContainer = Color(0xFFE2F3F4);
  static const _darkError = Color(0xFFFF6B61);
  static const _darkOnError = Color(0xFF5A0000);
  static const _darkErrorContainer = Color(0xFF7F1D1D);
  static const _darkOnErrorContainer = Color(0xFFFFDAD6);

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
  static TextTheme _urduTextTheme(ColorScheme scheme, {String? assetPackage}) {
    final latin = _latinTextTheme(scheme);
    return TextTheme(
      displayLarge: _toUrdu(latin.displayLarge!, assetPackage: assetPackage),
      displayMedium: _toUrdu(latin.displayMedium!, assetPackage: assetPackage),
      displaySmall: _toUrdu(latin.displaySmall!, assetPackage: assetPackage),
      headlineLarge: _toUrdu(latin.headlineLarge!, assetPackage: assetPackage),
      headlineMedium:
          _toUrdu(latin.headlineMedium!, assetPackage: assetPackage),
      headlineSmall: _toUrdu(latin.headlineSmall!, assetPackage: assetPackage),
      titleLarge: _toUrdu(latin.titleLarge!, assetPackage: assetPackage),
      titleMedium: _toUrdu(latin.titleMedium!, assetPackage: assetPackage),
      titleSmall: _toUrdu(latin.titleSmall!, assetPackage: assetPackage),
      bodyLarge: _toUrdu(latin.bodyLarge!, assetPackage: assetPackage),
      bodyMedium: _toUrdu(latin.bodyMedium!, assetPackage: assetPackage),
      bodySmall: _toUrdu(latin.bodySmall!, assetPackage: assetPackage),
      labelLarge: _toUrdu(latin.labelLarge!, assetPackage: assetPackage),
      labelMedium: _toUrdu(latin.labelMedium!, assetPackage: assetPackage),
      labelSmall: _toUrdu(latin.labelSmall!, assetPackage: assetPackage),
    );
  }

  /// Arabic interface typography uses the bundled Noto Sans Arabic face.
  /// Unlike Nastaliq, Arabic UI text does not need Urdu-specific leading.
  static TextTheme _arabicTextTheme(ColorScheme scheme, {String? assetPackage}) {
    final latin = _latinTextTheme(scheme);
    TextStyle arabic(TextStyle style) => _toArabic(style, assetPackage: assetPackage);
    return TextTheme(
      displayLarge: arabic(latin.displayLarge!),
      displayMedium: arabic(latin.displayMedium!),
      displaySmall: arabic(latin.displaySmall!),
      headlineLarge: arabic(latin.headlineLarge!),
      headlineMedium: arabic(latin.headlineMedium!),
      headlineSmall: arabic(latin.headlineSmall!),
      titleLarge: arabic(latin.titleLarge!),
      titleMedium: arabic(latin.titleMedium!),
      titleSmall: arabic(latin.titleSmall!),
      bodyLarge: arabic(latin.bodyLarge!),
      bodyMedium: arabic(latin.bodyMedium!),
      bodySmall: arabic(latin.bodySmall!),
      labelLarge: arabic(latin.labelLarge!),
      labelMedium: arabic(latin.labelMedium!),
      labelSmall: arabic(latin.labelSmall!),
    );
  }

  static TextStyle _toArabic(TextStyle latin, {String? assetPackage}) {
    final weight = latin.fontWeight ?? FontWeight.w400;
    return latin.copyWith(
      fontFamily: assetPackage == null ? arabicFamily : 'packages/$assetPackage/$arabicFamily',
      height: math.max(latin.height ?? 1.2, 1.4),
      letterSpacing: 0,
      wordSpacing: 0,
      fontVariations: [FontVariation.weight(weight.value.clamp(100, 900).toDouble())],
    );
  }

  /// One Latin style, restated for Nastaliq.
  ///
  /// The size grows a little (Nastaliq's letterforms read small at a nominal
  /// size), the line box grows a lot, and letter spacing goes to zero: spacing
  /// out Arabic-script letters breaks the cursive join between them.
  static TextStyle _toUrdu(TextStyle latin, {String? assetPackage}) {
    final size = (latin.fontSize ?? 14) * _urduSizeFactor;
    final scaled = (latin.height ?? 1.2) * _urduHeightFactor;
    final height = size >= _urduLargeSize
        ? scaled.clamp(_urduMinHeight, _urduLargeMaxHeight)
        : math.max(scaled, _urduMinHeight);
    final weight = latin.fontWeight ?? FontWeight.w400;
    return latin.copyWith(
      fontFamily: assetPackage == null
          ? urduFamily
          : 'packages/$assetPackage/$urduFamily',
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

  /// Replaces generated surface roles with stable app-owned design tokens.
  static ColorScheme _withSurfaceTokens(
    ColorScheme scheme,
    Brightness brightness,
  ) {
    final isDark = brightness == Brightness.dark;
    return scheme.copyWith(
      surface: isDark ? _darkSurface : _lightSurface,
      onSurface: isDark ? _darkOnSurface : _lightOnSurface,
      onSurfaceVariant: isDark ? _darkOnSurfaceVariant : _lightOnSurfaceVariant,
      surfaceContainerLowest: isDark ? _darkSurface : _lightCard,
      surfaceContainerLow: isDark ? _darkCard : _lightCard,
      surfaceContainer: isDark ? _darkSurfaceContainer : _lightSurfaceContainer,
      surfaceContainerHigh:
          isDark ? _darkSurfaceContainerHigh : _lightSurfaceContainerHigh,
      surfaceContainerHighest:
          isDark ? _darkSurfaceContainerHighest : _lightSurfaceContainerHighest,
      outline: isDark ? _darkOutline : _lightOutline,
      outlineVariant: isDark ? _darkOutlineVariant : _lightOutlineVariant,
    );
  }

  static ThemeData _base(
    ThemeData baseTheme,
    Brightness brightness, {
    required bool urdu,
    required bool arabic,
    String? assetPackage,
  }) {
    final scheme = _withSurfaceTokens(baseTheme.colorScheme, brightness);
    final typography = AppTypography(
      latin: _latinTextTheme(scheme),
      urdu: _urduTextTheme(scheme, assetPackage: assetPackage),
      arabic: _arabicTextTheme(scheme, assetPackage: assetPackage),
    );
    final textTheme = arabic
        ? typography.arabic
        : typography.forScript(urduScript: urdu);

    return baseTheme.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      // Keep custom ink reactions visible and consistent across the app while
      // deriving their hue from the active light/dark color scheme.
      splashColor: scheme.primary.withAlpha(24),
      highlightColor: scheme.primary.withAlpha(12),
      hoverColor: scheme.primary.withAlpha(12),
      focusColor: scheme.primary.withAlpha(24),
      cardTheme: baseTheme.cardTheme.copyWith(
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
      ),
      textTheme: textTheme,
      appBarTheme: baseTheme.appBarTheme.copyWith(
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 80,
        backgroundColor: scheme.surfaceContainerHigh,
        indicatorColor: scheme.surfaceContainerHighest,
        indicatorShape: const StadiumBorder(),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? textTheme.labelSmall?.copyWith(color: scheme.primary)
              : textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
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
      dialogTheme: baseTheme.dialogTheme.copyWith(
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
        backgroundColor: scheme.surfaceContainerHigh,
      ),
      bottomSheetTheme: baseTheme.bottomSheetTheme.copyWith(
        backgroundColor: scheme.surfaceContainerHigh,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      snackBarTheme: baseTheme.snackBarTheme.copyWith(
        // Snackbar surfaces follow the selected app theme rather than using
        // inverse colors, so light mode stays light and dark mode stays dark.
        backgroundColor: scheme.surfaceContainerHigh,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurface,
        ),
        actionTextColor: scheme.primary,
        disabledActionTextColor: scheme.primary.withAlpha(128),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      progressIndicatorTheme: baseTheme.progressIndicatorTheme.copyWith(
        color: scheme.primary,
        linearTrackColor: scheme.surfaceContainerHighest,
        circularTrackColor: scheme.surfaceContainerHighest,
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant),
      chipTheme: baseTheme.chipTheme.copyWith(
        shape: const StadiumBorder(),
        side: BorderSide(color: scheme.outlineVariant),
        labelStyle: textTheme.labelLarge,
      ),
      extensions: <ThemeExtension<dynamic>>[
        typography,
        AppChartColors.forBrightness(brightness),
      ],
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
  const AppTypography({required this.latin, required this.urdu, required this.arabic});

  final TextTheme latin;
  final TextTheme urdu;
  final TextTheme arabic;

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
        arabic: AppTheme._arabicTextTheme(Theme.of(context).colorScheme),
      );

  @override
  AppTypography copyWith({TextTheme? latin, TextTheme? urdu, TextTheme? arabic}) =>
      AppTypography(latin: latin ?? this.latin, urdu: urdu ?? this.urdu, arabic: arabic ?? this.arabic);

  @override
  AppTypography lerp(ThemeExtension<AppTypography>? other, double t) {
    if (other is! AppTypography) return this;
    return AppTypography(
      latin: TextTheme.lerp(latin, other.latin, t),
      urdu: TextTheme.lerp(urdu, other.urdu, t),
      arabic: TextTheme.lerp(arabic, other.arabic, t),
    );
  }
}

/// Chart-specific roles for prayer-series identity, status, grid and track.
///
/// Generic accents are intentionally not duplicated here: progress indicators
/// and the overall-progress chart use the active `ColorScheme.primary`.
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
