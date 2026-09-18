import 'dart:math' as math;

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
    return _base(scheme, Brightness.light, urdu: isUrdu(locale));
  }

  static ThemeData dark({Locale? locale}) {
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
    return _base(scheme, Brightness.dark, urdu: isUrdu(locale));
  }

  /// The Serene Sanctuary type scale: Noto Serif for display/headline and the
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
      extensions: [typography],
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

enum AppThemeMode { system, light, dark }

extension AppThemeModeX on AppThemeMode {
  /// Maps the app's theme choice onto Flutter's [ThemeMode].
  ThemeMode get materialMode => switch (this) {
        AppThemeMode.system => ThemeMode.system,
        AppThemeMode.light => ThemeMode.light,
        AppThemeMode.dark => ThemeMode.dark,
      };
}
