import 'package:flutter/material.dart';

/// Canonical Qaza Namaz color tokens.
///
/// Keep brand and semantic colors here. Widgets should consume Theme.of(context)
/// / ColorScheme rather than introducing their own colors.
class AppColors {
  const AppColors._();

  // Light surfaces and text.
  static const lightBase = Color(0xFFF7F9F7);
  static const lightSurfaceLow = Color(0xFFF0F4F1);
  static const lightBorder = Color(0xFFD5DED9);
  static const lightOnSurface = Color(0xFF17221D);
  static const white = Color(0xFFFFFFFF);

  // Light brand + semantic accents.
  static const lightPrimary = Color(0xFF1F6B4F);
  static const lightPrimaryContainer = Color(0xFFD7EBDD);
  static const lightOnPrimaryContainer = Color(0xFF164B37);
  static const lightSecondary = Color(0xFF8A6338);
  static const lightSecondaryContainer = Color(0xFFF2E6D5);
  static const lightOnSecondaryContainer = Color(0xFF5A3D1F);
  static const lightTertiary = Color(0xFF2E7D59);
  static const lightTertiaryContainer = Color(0xFFD7EBDD);
  static const lightOnTertiaryContainer = Color(0xFF174B35);

  // Dark surfaces and text.
  static const darkBase = Color(0xFF0D1512);
  static const darkSurfaceLowest = Color(0xFF08100D);
  static const darkSurfaceLow = Color(0xFF111A16);
  static const darkSurface = Color(0xFF141E19);
  static const darkSurfaceHigh = Color(0xFF1D2822);
  static const darkSurfaceHighest = Color(0xFF27332D);
  static const darkOnSurface = Color(0xFFEDF4F0);
  static const darkOnSurfaceVariant = Color(0xFFB9C7C0);
  static const darkOutline = Color(0xFF708078);
  static const darkOutlineVariant = Color(0xFF3A4A43);

  // Dark brand + semantic accents.
  static const darkPrimary = Color(0xFF7FD3A4);
  static const darkOnPrimary = Color(0xFF063B27);
  static const darkPrimaryContainer = Color(0xFF1E4C35);
  static const darkOnPrimaryContainer = Color(0xFFB7E8C9);
  static const darkSecondary = Color(0xFFE2B978);
  static const darkOnSecondary = Color(0xFF402A08);
  static const darkSecondaryContainer = Color(0xFF5A4528);
  static const darkOnSecondaryContainer = Color(0xFFF2D39A);
  static const darkTertiary = Color(0xFF70C995);
  static const darkOnTertiary = Color(0xFF073D27);
  static const darkTertiaryContainer = Color(0xFF1E4C35);
  static const darkOnTertiaryContainer = Color(0xFFB7E8C9);

  // Semantic feedback.
  static const lightSuccess = Color(0xFF2E7D59);
  static const darkSuccess = Color(0xFF70C995);
  static const lightWarning = Color(0xFF9A6A16);
  static const darkWarning = Color(0xFFE4B961);
  static const lightError = Color(0xFFC43D3D);
  static const darkError = Color(0xFFFF8A80);

  // Stable Material fixed-pair tokens used across both themes.
  static const primaryFixed = Color(0xFFD7EBDD);
  static const primaryFixedDim = Color(0xFFB7DCC4);
  static const onPrimaryFixed = Color(0xFF123A2A);
  static const onPrimaryFixedVariant = Color(0xFF2C654A);
  static const secondaryFixed = Color(0xFFF2E6D5);
  static const secondaryFixedDim = Color(0xFFE6D4B9);
  static const onSecondaryFixed = Color(0xFF38230D);
  static const onSecondaryFixedVariant = Color(0xFF654823);
  static const tertiaryFixed = Color(0xFFD9ECE7);
  static const tertiaryFixedDim = Color(0xFFBDDAD4);
  static const onTertiaryFixed = Color(0xFF173D38);
  static const onTertiaryFixedVariant = Color(0xFF3C625B);
}
