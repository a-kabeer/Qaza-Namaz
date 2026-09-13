import 'package:flutter/material.dart';

class AppTheme {
  static const _teal = Color(0xFF0D6E6E);
  static const _mint = Color(0xFF14B8A6);
  static const _amber = Color(0xFFF59E0B);

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(seedColor: _teal, brightness: Brightness.light).copyWith(
      primary: _teal,
      secondary: _amber,
      tertiary: _mint,
      surface: const Color(0xFFF8FAF9),
    );
    return _base(scheme, Brightness.light);
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF84D4D3), brightness: Brightness.dark).copyWith(
      primary: const Color(0xFF84D4D3),
      onPrimary: const Color(0xFF003737),
      secondary: const Color(0xFFFFB77D),
      tertiary: const Color(0xFF4FDBCC),
      surface: const Color(0xFF091515),
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
        color: brightness == Brightness.dark ? const Color(0xFF162222) : const Color(0xFFFFFFFF),
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface.withOpacity(.96),
        indicatorColor: scheme.primary.withOpacity(.18),
        labelTextStyle: const MaterialStatePropertyAll(TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: brightness == Brightness.dark ? const Color(0xFF202C2C) : const Color(0xFFF0F4F2),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }
}

enum AppThemeMode { system, light, dark }
