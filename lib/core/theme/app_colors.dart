import 'package:flutter/material.dart';

/// Canonical Qaza Namaz color tokens.
///
/// Keep all brand, semantic, surface and chart colors here. Widgets should
/// consume Theme.of(context) / ColorScheme / AppChartColors rather than
/// introducing their own colors.
class AppColors {
  const AppColors._();

  // Light surfaces and text.
  static const lightBase = Color(0xFFFAFDF9);
  static const lightSurface = Color(0xFFF8FAFC);
  static const lightSurfaceLow = Color(0xFFF1F5F2);
  static const lightBorder = Color(0xFFE2E8F0);
  static const lightOnSurface = Color(0xFF0F172A);
  static const white = Color(0xFFFFFFFF);

  // Light brand.
  static const lightPrimary = Color(0xFF2E7D5B);
  static const lightOnPrimary = Color(0xFFFFFFFF);
  static const lightPrimaryContainer = Color(0xFFD8F0E4);
  static const lightOnPrimaryContainer = Color(0xFF0F5132);
  static const lightSecondary = Color(0xFF6B8576);
  static const lightOnSecondary = Color(0xFFFFFFFF);
  static const lightSecondaryContainer = Color(0xFFEAF5EE);
  static const lightOnSecondaryContainer = Color(0xFF2E7D5B);
  static const lightTertiary = Color(0xFFA78BFA);
  static const lightOnTertiary = Color(0xFF5B21B6);
  static const lightTertiaryContainer = Color(0xFFEDE9FE);
  static const lightOnTertiaryContainer = Color(0xFF5B21B6);

  // Dark surfaces and text.
  static const darkBase = Color(0xFF081612);
  static const darkSurfaceLowest = Color(0xFF06100D);
  static const darkSurfaceLow = Color(0xFF0D1D18);
  static const darkSurface = Color(0xFF10251E);
  static const darkSurfaceHigh = Color(0xFF163027);
  static const darkSurfaceHighest = Color(0xFF1D3A30);
  static const darkOnSurface = Color(0xFFF1F8F4);
  static const darkOnSurfaceVariant = Color(0xFFB9CDC4);
  static const darkOutline = Color(0xFF4E6A5D);
  static const darkOutlineVariant = Color(0xFF2F4940);

  // Dark brand.
  static const darkPrimary = Color(0xFF63D8A0);
  static const darkOnPrimary = Color(0xFF073B27);
  static const darkPrimaryContainer = Color(0xFF185B3F);
  static const darkOnPrimaryContainer = Color(0xFFB8F1D1);
  static const darkSecondary = Color(0xFF8FAF9F);
  static const darkOnSecondary = Color(0xFF10251E);
  static const darkSecondaryContainer = Color(0xFF29483B);
  static const darkOnSecondaryContainer = Color(0xFFD5E9DF);
  static const darkTertiary = Color(0xFFB59AFF);
  static const darkOnTertiary = Color(0xFF35116F);
  static const darkTertiaryContainer = Color(0xFF4B2A91);
  static const darkOnTertiaryContainer = Color(0xFFE8DEFF);

  // Semantic feedback.
  static const lightSuccess = Color(0xFF22C55E);
  static const darkSuccess = Color(0xFF4ADE80);
  static const lightWarning = Color(0xFFF59E0B);
  static const darkWarning = Color(0xFFFBBF24);
  static const lightError = Color(0xFFEF4444);
  static const darkError = Color(0xFFFF6B61);
  static const lightInfo = Color(0xFF3B82F6);
  static const darkInfo = Color(0xFF60A5FA);

  // Dark Material error support.
  static const darkOnError = Color(0xFF5A0000);
  static const darkErrorContainer = Color(0xFF7F1D1D);
  static const darkOnErrorContainer = Color(0xFFFFDAD6);
  static const darkSurfaceBright = Color(0xFF2A4439);
  static const darkOnInverseSurface = Color(0xFF10251E);

  // Stable Material fixed-pair tokens used across both themes.
  static const primaryFixed = Color(0xFFD8F0E4);
  static const primaryFixedDim = Color(0xFFB8DEC8);
  static const onPrimaryFixed = Color(0xFF0F5132);
  static const onPrimaryFixedVariant = Color(0xFF2E7D5B);
  static const secondaryFixed = Color(0xFFEAF5EE);
  static const secondaryFixedDim = Color(0xFFD2E5DA);
  static const onSecondaryFixed = Color(0xFF254C3B);
  static const onSecondaryFixedVariant = Color(0xFF4F6F61);
  static const tertiaryFixed = Color(0xFFEDE9FE);
  static const tertiaryFixedDim = Color(0xFFDCD2FB);
  static const onTertiaryFixed = Color(0xFF5B21B6);
  static const onTertiaryFixedVariant = Color(0xFF7446C1);

  // Chart / graph series colors. Keep these stable so the same series is
  // visually identifiable across light and dark themes.
  static const chartFajr = Color(0xFF39B982);
  static const chartZuhr = Color(0xFFFF9248);
  static const chartAsr = Color(0xFFFFC94D);
  static const chartMaghrib = Color(0xFF46C6B8);
  static const chartIsha = Color(0xFF4C9FF5);
  static const chartWitr = Color(0xFF9B5DE5);
  static const chartCompleted = Color(0xFF22C55E);
  static const chartPending = Color(0xFFEF4444);
  static const chartTotal = Color(0xFFCBD5E1);

  // Theme-specific chart surfaces.
  static const lightChartPrimary = Color(0xFF2E7D5B);
  static const darkChartPrimary = Color(0xFF63D8A0);
  static const lightChartGrid = Color(0xFFE2E8F0);
  static const darkChartGrid = Color(0xFF29423A);
  static const lightChartTrack = Color(0xFFE8EDF0);
  static const darkChartTrack = Color(0xFF20362E);
}
