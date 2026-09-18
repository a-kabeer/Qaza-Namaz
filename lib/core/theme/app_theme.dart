import 'package:flutter/material.dart';

/// Central application theme.
///
/// The only source of Material styling for the application. Colour, type,
/// shape and elevation tokens are taken from the Stitch "Serene Sanctuary"
/// design export: deep slate-teal surfaces, luminous mint primaries, dawn
/// amber accents, and Noto Serif / Manrope typography.
class AppTheme {
  // --- Serene Sanctuary dark tokens (canonical export values) -------------
  static const Color darkBase = Color(0xFF091515);
  static const Color darkPrimary = Color(0xFFA0F0EF);
  static const Color darkOnPrimary = Color(0xFF003737);
  static const Color darkPrimaryContainer = Color(0xFF84D4D3);
  static const Color darkOnPrimaryContainer = Color(0xFF005C5C);
  static const Color amber = Color(0xFFFFB77D);
  static const Color mint = Color(0xFF70F8E8);
  static const Color kineticMint = Color(0xFF4FDBCC);

  /// Deep teal used for interactive fills in light mode.
  static const Color interactive = Color(0xFF0D6E6E);

  // Dark surface scale.
  static const Color darkSurfaceLowest = Color(0xFF051010);
  static const Color darkSurfaceLow = Color(0xFF121E1E);
  static const Color darkSurface = Color(0xFF162222);
  static const Color darkSurfaceHigh = Color(0xFF202C2C);
  static const Color darkSurfaceHighest = Color(0xFF2B3737);
  static const Color darkOnSurface = Color(0xFFD8E5E4);
  static const Color darkOnSurfaceVariant = Color(0xFFBEC9C8);
  static const Color darkOutline = Color(0xFF889392);
  static const Color darkOutlineVariant = Color(0xFF3E4948);

  // Light surface tokens.
  static const Color lightBase = Color(0xFFF8FAF9);
  static const Color lightSurfaceLow = Color(0xFFF0F4F2);
  static const Color lightBorder = Color(0xFFE2EAE6);
  static const Color lightOnSurface = Color(0xFF171D1C);
  static const Color lightSecondary = Color(0xFF9C4300);
  static const Color white = Color(0xFFFFFFFF);

  // Shared "fixed" tokens; these double as the light container pairs.
  static const Color primaryFixed = Color(0xFFA0F0EF);
  static const Color onPrimaryFixed = Color(0xFF002020);
  static const Color secondaryFixed = Color(0xFFFFDCC3);
  static const Color onSecondaryFixed = Color(0xFF2F1500);
  static const Color tertiaryFixed = Color(0xFF70F8E8);
  static const Color onTertiaryFixed = Color(0xFF00201D);

  static const String _serif = 'Noto Serif';
  static const String _sans = 'Manrope';

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

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: interactive,
      brightness: Brightness.light,
    ).copyWith(
      primary: interactive,
      onPrimary: white,
      primaryContainer: primaryFixed,
      onPrimaryContainer: onPrimaryFixed,
      secondary: lightSecondary,
      onSecondary: white,
      secondaryContainer: secondaryFixed,
      onSecondaryContainer: onSecondaryFixed,
      tertiaryContainer: tertiaryFixed,
      onTertiaryContainer: onTertiaryFixed,
      surface: lightBase,
      onSurface: lightOnSurface,
      surfaceContainerLowest: white,
      surfaceContainerLow: lightSurfaceLow,
      surfaceContainer: white,
      surfaceContainerHigh: lightSurfaceLow,
      surfaceContainerHighest: lightSurfaceLow,
      outlineVariant: lightBorder,
      surfaceTint: interactive,
    );
    return _base(scheme, Brightness.light);
  }

  static ThemeData dark() {
    const scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: darkPrimary,
      onPrimary: darkOnPrimary,
      primaryContainer: darkPrimaryContainer,
      onPrimaryContainer: darkOnPrimaryContainer,
      secondary: amber,
      onSecondary: Color(0xFF4D2600),
      secondaryContainer: Color(0xFF6E3D0D),
      onSecondaryContainer: Color(0xFFEFA971),
      tertiary: mint,
      onTertiary: Color(0xFF003732),
      tertiaryContainer: kineticMint,
      onTertiaryContainer: Color(0xFF005D55),
      error: Color(0xFFFFB4AB),
      onError: Color(0xFF690005),
      errorContainer: Color(0xFF93000A),
      onErrorContainer: Color(0xFFFFDAD6),
      surface: darkBase,
      onSurface: darkOnSurface,
      surfaceDim: darkBase,
      surfaceBright: Color(0xFF2F3B3B),
      surfaceContainerLowest: darkSurfaceLowest,
      surfaceContainerLow: darkSurfaceLow,
      surfaceContainer: darkSurface,
      surfaceContainerHigh: darkSurfaceHigh,
      surfaceContainerHighest: darkSurfaceHighest,
      onSurfaceVariant: darkOnSurfaceVariant,
      outline: darkOutline,
      outlineVariant: darkOutlineVariant,
      inverseSurface: darkOnSurface,
      onInverseSurface: Color(0xFF273332),
      inversePrimary: Color(0xFF006A69),
      surfaceTint: darkPrimaryContainer,
      primaryFixed: primaryFixed,
      primaryFixedDim: darkPrimaryContainer,
      onPrimaryFixed: onPrimaryFixed,
      onPrimaryFixedVariant: Color(0xFF00504F),
      secondaryFixed: secondaryFixed,
      secondaryFixedDim: amber,
      onSecondaryFixed: onSecondaryFixed,
      onSecondaryFixedVariant: Color(0xFF6B3B0A),
      tertiaryFixed: tertiaryFixed,
      tertiaryFixedDim: kineticMint,
      onTertiaryFixed: onTertiaryFixed,
      onTertiaryFixedVariant: Color(0xFF005049),
    );
    return _base(scheme, Brightness.dark);
  }

  /// The Serene Sanctuary type scale: Noto Serif for display/headline and the
  /// large title used by prayer names, Manrope for everything else.
  static TextTheme _textTheme(ColorScheme scheme) {
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

  static ThemeData _base(ColorScheme scheme, Brightness brightness) {
    final textTheme = _textTheme(scheme);

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
        color: scheme.tertiaryContainer,
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

enum AppThemeMode { system, light, dark }

extension AppThemeModeX on AppThemeMode {
  /// Maps the app's theme choice onto Flutter's [ThemeMode].
  ThemeMode get materialMode => switch (this) {
        AppThemeMode.system => ThemeMode.system,
        AppThemeMode.light => ThemeMode.light,
        AppThemeMode.dark => ThemeMode.dark,
      };
}
