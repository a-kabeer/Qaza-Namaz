import 'package:flutter/material.dart';

class AppTheme {
  static const _teal = Color(0xFF0D6E6E);
  static const _mint = Color(0xFF14B8A6);
  static const _amber = Color(0xFFF59E0B);

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: _teal,
      brightness: Brightness.light,
    ).copyWith(
      primary: _teal,
      secondary: _amber,
      tertiary: _mint,
      surface: const Color(0xFFF8FAF9),
    );
    return _base(scheme, Brightness.light);
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF84D4D3),
      brightness: Brightness.dark,
    ).copyWith(
      primary: const Color(0xFF84D4D3),
      onPrimary: const Color(0xFF003737),
      secondary: const Color(0xFFFFB77D),
      tertiary: const Color(0xFF4FDBCC),
      surface: const Color(0xFF091515),
    );
    return _base(scheme, Brightness.dark);
  }

  static ThemeData _base(ColorScheme scheme, Brightness brightness) {
    final textTheme = Typography.material2021().black.apply(
          fontFamily: 'Manrope',
        );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      textTheme: textTheme.copyWith(
        displayLarge: textTheme.displayLarge?.copyWith(fontFamily: 'Noto Serif'),
        displayMedium: textTheme.displayMedium?.copyWith(fontFamily: 'Noto Serif'),
        displaySmall: textTheme.displaySmall?.copyWith(fontFamily: 'Noto Serif'),
        headlineLarge: textTheme.headlineLarge?.copyWith(fontFamily: 'Noto Serif'),
        headlineMedium: textTheme.headlineMedium?.copyWith(fontFamily: 'Noto Serif'),
        headlineSmall: textTheme.headlineSmall?.copyWith(fontFamily: 'Noto Serif'),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface.withValues(alpha: .92),
        foregroundColor: scheme.onSurface,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: brightness == Brightness.dark
            ? const Color(0xFF162222)
            : const Color(0xFFFFFFFF),
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface.withValues(alpha: .96),
        indicatorColor: scheme.primary.withValues(alpha: .18),
        labelTextStyle: WidgetStatePropertyAll(
          const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: brightness == Brightness.dark
            ? const Color(0xFF202C2C)
            : const Color(0xFFF0F4F2),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

enum AppThemeMode { system, light, dark }
