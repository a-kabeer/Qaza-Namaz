import 'package:flutter/material.dart';

/// Chart-only colors that are intentionally outside Material's semantic
/// ColorScheme because each prayer series must remain visually stable across
/// light and dark themes.
///
/// Generic progress accents such as rings and overall-progress charts should
/// read `ColorScheme.primary` instead of duplicating primary tokens here.
class AppColors {
  const AppColors._();

  static const chartFajr = Color(0xFF39B982);
  static const chartZuhr = Color(0xFFFF9248);
  static const chartAsr = Color(0xFFFFC94D);
  static const chartMaghrib = Color(0xFF46C6B8);
  static const chartIsha = Color(0xFF4C9FF5);
  static const chartWitr = Color(0xFF9B5DE5);
  static const chartCompleted = Color(0xFF22C55E);
  static const chartPending = Color(0xFFEF4444);
  static const chartTotal = Color(0xFFCBD5E1);
  static const lightChartGrid = Color(0xFFE2E8F0);
  static const darkChartGrid = Color(0xFF29423A);
  static const lightChartTrack = Color(0xFFE8EDF0);
  static const darkChartTrack = Color(0xFF20362E);
}
