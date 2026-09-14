import 'package:flutter/material.dart';

/// Central application theme.
///
/// This is the single source of truth for the Qaza Namaz visual system.
/// It preserves the Stitch palette direction (dark base #091515, teal primary
/// #84D4D3 / #0D6E6E, amber #FFB77D, mint #4FDBCC) and maps the Stitch surface
/// tokens onto Material 3 surface roles. Every screen derives its colors,
/// typography, button, card, navigation, dialog, input, chip, snackbar and
/// progress-indicator styling from the [ThemeData] produced here, so changing
/// the active [AppThemeMode] re-themes the entire application.
class AppTheme {
  // Stitch palette tokens.
  static const Color darkBase = Color(0xFF091515);
  static const Color darkPrimary = Color(0xFF84D4D3);
  static const Color interactive = Color(0xFF0D6E6E);
  static const Color amber = Color(0xFFFFB77D);
  static const Color mint = Color(0xFF4FDBCC);
  static const Color onDarkPrimary = Color(0xFF003737);

  // Stitch dark surface tokens.
  static const Color darkSurfaceLowest = Color(0xFF121E1E);
  static const Color darkSurfaceLow = Color(0xFF162222);
  static const Color darkSurface = Color(0xFF202C2C);
  static const Color darkSurfaceHigh = Color(0xFF2B3737);

  // Stitch light surface tokens.
  static const Color lightBase = Color(0xFFF8FAF9);
  static const Color lightSurfaceLow = Color(0xFFF0F4F2);
  static const Color lightSurface = Color(0xFFE2EAE6);

  static const Color white = Color(0xFFFFFFFF);

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: interactive,
      brightness: Brightness.light,
    ).copyWith(
      primary: interactive,
      secondary: amber,
      tertiary: mint,
      surface: lightBase,
      surfaceContainerLowest: white,
      surfaceContainerLow: lightSurfaceLow,
      surfaceContainer: lightSurface,
      surfaceContainerHigh: lightSurface,
      surfaceContainerHighest: lightSurface,
    );
    return _base(scheme, Brightness.light);
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: darkPrimary,
      brightness: Brightness.dark,
    ).copyWith(
      primary: darkPrimary,
      onPrimary: onDarkPrimary,
      secondary: amber,
      tertiary: mint,
      surface: darkBase,
      surfaceContainerLowest: darkSurfaceLowest,
      surfaceContainerLow: darkSurfaceLow,
      surfaceContainer: darkSurface,
      surfaceContainerHigh: darkSurfaceHigh,
      surfaceContainerHighest: darkSurfaceHigh,
    );
    return _base(scheme, Brightness.dark);
  }

  static ThemeData _base(ColorScheme scheme, Brightness brightness) {
    final base = Typography.material2021().black.apply(fontFamily: 'Manrope');
    final textTheme = base.copyWith(
      displayLarge: base.displayLarge?.copyWith(fontFamily: 'Noto Serif', color: scheme.onSurface),
      displayMedium: base.displayMedium?.copyWith(fontFamily: 'Noto Serif', color: scheme.onSurface),
      displaySmall: base.displaySmall?.copyWith(fontFamily: 'Noto Serif', color: scheme.onSurface),
      headlineLarge: base.headlineLarge?.copyWith(fontFamily: 'Noto Serif', color: scheme.onSurface),
      headlineMedium: base.headlineMedium?.copyWith(fontFamily: 'Noto Serif', color: scheme.onSurface),
      headlineSmall: base.headlineSmall?.copyWith(fontFamily: 'Noto Serif', color: scheme.onSurface),
      titleLarge: base.titleLarge?.copyWith(color: scheme.onSurface),
      titleMedium: base.titleMedium?.copyWith(color: scheme.onSurface),
      titleSmall: base.titleSmall?.copyWith(color: scheme.onSurface),
      bodyLarge: base.bodyLarge?.copyWith(color: scheme.onSurface),
      bodyMedium: base.bodyMedium?.copyWith(color: scheme.onSurface),
      bodySmall: base.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
    );

    final buttonShape = WidgetStatePropertyAll<OutlinedBorder>(
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    );
    final surfaceContainerLow = scheme.surfaceContainerLow;
    final surfaceContainerHigh = scheme.surfaceContainerHigh;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface.withOpacity(.92),
        foregroundColor: scheme.onSurface,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardTheme(
        color: surfaceContainerLow,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface.withOpacity(.96),
        indicatorColor: scheme.primary.withOpacity(.18),
        labelTextStyle: const WidgetStatePropertyAll(TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceContainerLow,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
      filledButtonTheme: FilledButtonThemeData(style: ButtonStyle(shape: buttonShape)),
      outlinedButtonTheme: OutlinedButtonThemeData(style: ButtonStyle(shape: buttonShape)),
      textButtonTheme: TextButtonThemeData(style: ButtonStyle(shape: buttonShape)),
      iconButtonTheme: IconButtonThemeData(style: ButtonStyle(shape: buttonShape)),
      dialogTheme: DialogTheme(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: surfaceContainerHigh,
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: scheme.inverseSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.surfaceContainerHighest,
        circularTrackColor: scheme.onPrimaryContainer.withOpacity(.25),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
    );
  }
}

enum AppThemeMode { system, light, dark }
